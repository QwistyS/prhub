
use crate::github;
use steel_derive::Steel;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};

impl From<octocrab::models::issues::Issue> for GhPr {
    fn from(issue: octocrab::models::issues::Issue) -> Self {
        // Extract repo: "https://api.github.com/repos/owner/repo" -> "owner/repo"
        let repo_name = issue.repository_url.path()
            .split('/').skip(3).take(2).collect::<Vec<_>>().join("/");

        let state = match issue.state {
            octocrab::models::IssueState::Open => "open",
            octocrab::models::IssueState::Closed => "closed",
            _ => "unknown",
        };

        Self {
            repo_name,
            number: issue.number as usize,
            title: issue.title,
            author: issue.user.login,
            state: state.to_string(),
            updated_at: issue.updated_at.to_rfc3339(), // Octocrab uses chrono
            // These stay empty until the user selects the PR for a detailed fetch
            branch: String::new(),
            additions: 0,
            deletions: 0,
        }
    }
}

#[derive(Clone, Debug, Steel, PartialEq)]
pub struct GhPr {
    pub repo_name: String,
    pub number: usize,
    pub title: String,
    pub author: String,
    pub state: String,
    pub branch: String,
    pub additions: usize,
    pub deletions: usize,
    pub updated_at: String,
}

// Add the getter for Steel to use
impl GhPr {
    pub fn repo_name(&self) -> String { self.repo_name.clone() }
    pub fn number(&self) -> usize { self.number }
    pub fn title(&self) -> String { self.title.clone() }
    pub fn author(&self) -> String { self.author.clone() }
    pub fn state(&self) -> String { self.state.clone() }
    pub fn branch(&self) -> String { self.branch.clone() }
    pub fn additions(&self) -> usize { self.additions }
    pub fn deletions(&self) -> usize { self.deletions }
    pub fn updated_at(&self) -> String { self.updated_at.clone() }
}

#[derive(Clone, Debug, Steel)]
pub struct PrHub {
    prs: Arc<Mutex<Vec<GhPr>>>,
    error: Arc<Mutex<Option<String>>>,
    fetch_done: Arc<AtomicBool>,
    cancel: Arc<AtomicBool>,
    diff_lines: Arc<Mutex<Vec<String>>>,
    diff_done: Arc<AtomicBool>,
}

impl PartialEq for PrHub {
    fn eq(&self, other: &Self) -> bool {
        Arc::ptr_eq(&self.prs, &other.prs)
    }
}

impl PrHub {
    pub fn new() -> Self {
        Self {
            prs: Arc::new(Mutex::new(Vec::new())),
            error: Arc::new(Mutex::new(None)),
            fetch_done: Arc::new(AtomicBool::new(false)),
            cancel: Arc::new(AtomicBool::new(false)),
            diff_lines: Arc::new(Mutex::new(Vec::new())),
            diff_done: Arc::new(AtomicBool::new(false)),
        }
    }
    
    pub fn start_fetch(&self) {
        // 1. Mark as "In Progress" using an Atomic
        self.fetch_done.store(false, Ordering::SeqCst);
    
        let prs = Arc::clone(&self.prs);
        let done = Arc::clone(&self.fetch_done);
        let error = Arc::clone(&self.error);

        std::thread::spawn(move || {
            // 2. Start the isolated Async runtime
            let rt = tokio::runtime::Runtime::new().unwrap();
            rt.block_on(async {
                // 3. Do the heavy lifting WITHOUT any locks
                match github::list_general_prs_native().await {
                    Ok(raw_prs) => {
                        let converted: Vec<GhPr> = raw_prs.into_iter().map(GhPr::from).collect();
                    
                        // 4. THE ONLY LOCK: Swap the pointer and drop it
                        if let Ok(mut guard) = prs.lock() {
                            *guard = converted;
                        }
                    }
                    Err(e) => {
                        if let Ok(mut err_guard) = error.lock() {
                            *err_guard = Some(e.to_string());
                        }
                    }
                }
                // 5. Signal the UI that it's safe to read now
                done.store(true, Ordering::SeqCst);
            });
        });
    }

    pub fn fetch_complete(&self) -> bool {
        self.fetch_done.load(Ordering::SeqCst)
    }

    pub fn cancel_fetch(&self) {
        self.cancel.store(true, Ordering::SeqCst);
    }

    pub fn error(&self) -> String {
        self.error
            .lock()
            .unwrap()
            .clone()
            .unwrap_or_default()
    }

    pub fn pr_count(&self) -> usize {
        self.prs.lock().unwrap().len()
    }

    pub fn pr_at(&self, index: usize) -> GhPr {
        self.prs.lock().unwrap()[index].clone()
    }

    pub fn start_diff_fetch(&mut self, repo: String, pr_number: usize) {
        self.diff_done.store(false, Ordering::SeqCst);
        self.diff_lines.lock().unwrap().clear();
        *self.error.lock().unwrap() = None;

        let lines = Arc::clone(&self.diff_lines);
        let error = Arc::clone(&self.error);
        let done = Arc::clone(&self.diff_done);

        std::thread::spawn(move || {
            let rt = tokio::runtime::Runtime::new().unwrap();
            rt.block_on(async {
                match github::fetch_diff(&repo, pr_number).await {
                    Ok(diff) => {
                        *lines.lock().unwrap() = diff.lines().map(String::from).collect();
                    }
                    Err(e) => {
                        *error.lock().unwrap() = Some(e);
                    }
                }
                done.store(true, Ordering::SeqCst);
            });
        });
    }

    pub fn diff_fetch_complete(&self) -> bool {
        self.diff_done.load(Ordering::SeqCst)
    }

    pub fn diff_lines(&self, offset: usize, count: usize) -> Vec<String> {
        let lines = self.diff_lines.lock().unwrap();
        lines
            .iter()
            .skip(offset)
            .take(count)
            .cloned()
            .collect()
    }

    pub fn diff_line_count(&self) -> usize {
        self.diff_lines.lock().unwrap().len()
    }
}
