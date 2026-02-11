use octocrab::Octocrab;

fn github_token() -> Result<String, String> {
    std::env::var("GITHUB_TOKEN")
        .or_else(|_| std::env::var("GH_TOKEN"))
        .map_err(|_| "GITHUB_TOKEN not set (or GH_TOKEN fallback)".to_string())
}

fn format_octocrab_error(err: octocrab::Error) -> String {
    match err {
        octocrab::Error::GitHub { source, .. } => {
            let mut msg = format!("GitHub API error ({}): {}", source.status_code, source.message);
            if let Some(url) = source.documentation_url {
                msg.push_str(&format!(" | Docs: {url}"));
            }
            if let Some(errors) = source.errors {
                if !errors.is_empty() {
                    msg.push_str(" | Errors:");
                    for error in errors {
                        msg.push_str(&format!(" {error}"));
                    }
                }
            }
            msg
        }
        other => other.to_string(),
    }
}

async fn current_login(octo: &Octocrab) -> Result<String, String> {
    let user = octo.current().user().await.map_err(format_octocrab_error)?;
    Ok(user.login)
}

pub async fn list_general_prs_native() -> Result<Vec<octocrab::models::issues::Issue>, String> {
    let token = github_token()?;
    let octo = Octocrab::builder()
        .personal_token(token)
        .build()
        .map_err(format_octocrab_error)?;

    let login = current_login(&octo).await?;

    // GitHub search API doesn't support parenthesized OR with qualifiers,
    // so we run separate queries and merge results.
    // - author: PRs the user created
    // - review-requested: PRs with a pending direct review request
    // - reviewed-by: PRs the user has already reviewed (still open)
    let queries = [
        format!("is:pr is:open author:{login}"),
        format!("is:pr is:open review-requested:{login}"),
        format!("is:pr is:open reviewed-by:{login}"),
    ];

    let mut seen = std::collections::HashSet::new();
    let mut results = Vec::new();

    for query in &queries {
        let page = octo
            .search()
            .issues_and_pull_requests(query)
            .send()
            .await
            .map_err(|e| {
                format!(
                    "Octocrab search failed for `{}`: {}",
                    query,
                    format_octocrab_error(e)
                )
            })?;

        for item in page.items {
            if seen.insert(item.id) {
                results.push(item);
            }
        }
    }

    Ok(results)
}

pub async fn fetch_changed_files(
    repo: &str,
    pr_number: usize,
) -> Result<(Vec<octocrab::models::repos::DiffEntry>, String), String> {
    let (owner, repo_name) = repo
        .split_once('/')
        .ok_or_else(|| "Invalid repo name (expected owner/repo)".to_string())?;
    let token = github_token()?;
    let octo = Octocrab::builder()
        .personal_token(token)
        .build()
        .map_err(format_octocrab_error)?;

    let pr = octo
        .pulls(owner, repo_name)
        .get(pr_number as u64)
        .await
        .map_err(|e| format!("get PR failed: {}", format_octocrab_error(e)))?;
    let head_sha = pr.head.sha;

    let page = octo
        .pulls(owner, repo_name)
        .list_files(pr_number as u64)
        .await
        .map_err(|e| format!("list_files failed: {}", format_octocrab_error(e)))?;

    let mut all_files = page.items;
    let mut next = page.next;

    while next.is_some() {
        let next_page = octo
            .get_page::<octocrab::models::repos::DiffEntry>(&next)
            .await
            .map_err(|e| format!("list_files pagination failed: {}", format_octocrab_error(e)))?;

        let Some(next_page) = next_page else {
            break;
        };

        all_files.extend(next_page.items);
        next = next_page.next;
    }

    Ok((all_files, head_sha))
}

pub async fn fetch_diff(repo: &str, pr_number: usize) -> Result<String, String> {
    let (owner, repo_name) = repo
        .split_once('/')
        .ok_or_else(|| "Invalid repo name (expected owner/repo)".to_string())?;
    let token = github_token()?;
    let octo = Octocrab::builder()
        .personal_token(token)
        .build()
        .map_err(format_octocrab_error)?;

    octo.pulls(owner, repo_name)
        .get_diff(pr_number as u64)
        .await
        .map_err(|e| format!("Octocrab get_diff failed: {}", format_octocrab_error(e)))
}
