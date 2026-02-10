use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc, Mutex,
};

use steel_derive::Steel;

use crate::github;

// ---------------------------------------------------------------------------
// GhPr — a single pull request, exposed to Steel
// ---------------------------------------------------------------------------

#[derive(Clone, Debug, Steel, PartialEq)]
pub struct GhPr {
    number: usize,
    title: String,
    author: String,
    state: String,
    branch: String,
    additions: usize,
    deletions: usize,
    updated_at: String,
}

impl GhPr {
    pub fn number(&self) -> usize {
        self.number
    }
    pub fn title(&self) -> String {
        self.title.clone()
    }
    pub fn author(&self) -> String {
        self.author.clone()
    }
    pub fn state(&self) -> String {
        self.state.clone()
    }
    pub fn branch(&self) -> String {
        self.branch.clone()
    }
    pub fn additions(&self) -> usize {
        self.additions
    }
    pub fn deletions(&self) -> usize {
        self.deletions
    }
    pub fn updated_at(&self) -> String {
        self.updated_at.clone()
    }
}

impl From<github::GhPrRaw> for GhPr {
    fn from(raw: github::GhPrRaw) -> Self {
        Self {
            number: raw.number as usize,
            title: raw.title,
            author: raw.author.login,
            state: raw.state,
            branch: raw.head_ref_name,
            additions: raw.additions as usize,
            deletions: raw.deletions as usize,
            updated_at: raw.updated_at,
        }
    }
}

// ---------------------------------------------------------------------------
// PrHub — main plugin state, exposed to Steel
// ---------------------------------------------------------------------------

#[derive(Clone, Debug, Steel)]
pub struct PrHub {
    prs: Arc<Mutex<Vec<GhPr>>>,
    error: Arc<Mutex<Option<String>>>,
    fetch_done: Arc<AtomicBool>,
    cancel: Arc<AtomicBool>,
    // Diff state
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

    /// Kick off a background thread to fetch PRs.
    pub fn start_fetch(&self) {
        self.fetch_done.store(false, Ordering::SeqCst);
        self.cancel.store(false, Ordering::SeqCst);
        *self.error.lock().unwrap() = None;
        self.prs.lock().unwrap().clear();

        let prs = Arc::clone(&self.prs);
        let error = Arc::clone(&self.error);
        let done = Arc::clone(&self.fetch_done);
        let cancel = Arc::clone(&self.cancel);

        std::thread::spawn(move || {
            if cancel.load(Ordering::SeqCst) {
                return;
            }
            match github::list_prs() {
                Ok(raw_prs) => {
                    let converted: Vec<GhPr> = raw_prs.into_iter().map(GhPr::from).collect();
                    *prs.lock().unwrap() = converted;
                }
                Err(e) => {
                    *error.lock().unwrap() = Some(e);
                }
            }
            done.store(true, Ordering::SeqCst);
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

    // -- Diff fetching --

    pub fn start_diff_fetch(&mut self, pr_number: usize) {
        self.diff_done.store(false, Ordering::SeqCst);
        self.diff_lines.lock().unwrap().clear();
        *self.error.lock().unwrap() = None;

        let lines = Arc::clone(&self.diff_lines);
        let error = Arc::clone(&self.error);
        let done = Arc::clone(&self.diff_done);

        std::thread::spawn(move || {
            match github::fetch_diff(pr_number) {
                Ok(diff) => {
                    *lines.lock().unwrap() = diff.lines().map(String::from).collect();
                }
                Err(e) => {
                    *error.lock().unwrap() = Some(e);
                }
            }
            done.store(true, Ordering::SeqCst);
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
