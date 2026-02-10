use serde::Deserialize;
use std::process::Command;

/// Raw PR data from `gh pr list --json`.
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GhPrRaw {
    pub number: i64,
    pub title: String,
    pub author: AuthorRaw,
    pub state: String,
    pub head_ref_name: String,
    pub additions: i64,
    pub deletions: i64,
    pub updated_at: String,
}

#[derive(Debug, Deserialize)]
pub struct AuthorRaw {
    pub login: String,
}

/// Fetch open PRs for the current repo via `gh` CLI.
pub fn list_prs() -> Result<Vec<GhPrRaw>, String> {
    let output = Command::new("gh")
        .args([
            "pr",
            "list",
            "--json",
            "number,title,author,state,headRefName,additions,deletions,updatedAt",
            "--limit",
            "50",
        ])
        .output()
        .map_err(|e| format!("Failed to run gh: {e}"))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("gh pr list failed: {stderr}"));
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    serde_json::from_str(&stdout).map_err(|e| format!("Failed to parse gh output: {e}"))
}

/// Fetch diff for a specific PR via `gh` CLI.
pub fn fetch_diff(pr_number: usize) -> Result<String, String> {
    let output = Command::new("gh")
        .args(["pr", "diff", &pr_number.to_string()])
        .output()
        .map_err(|e| format!("Failed to run gh: {e}"))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("gh pr diff failed: {stderr}"));
    }

    Ok(String::from_utf8_lossy(&output.stdout).into_owned())
}
