use steel::{
    declare_module,
    steel_vm::ffi::{FFIModule, RegisterFFIFn},
};

mod github;
mod pr;

declare_module!(create_module);

fn create_module() -> FFIModule {
    let mut module = FFIModule::new("steel/prhub");

    module
        // PrHub lifecycle
        .register_fn("PrHub-new", pr::PrHub::new)
        .register_fn("PrHub-start-fetch", pr::PrHub::start_fetch)
        .register_fn("PrHub-fetch-complete?", pr::PrHub::fetch_complete)
        .register_fn("PrHub-cancel-fetch", pr::PrHub::cancel_fetch)
        .register_fn("PrHub-error", pr::PrHub::error)
        // PR list access
        .register_fn("PrHub-pr-count", pr::PrHub::pr_count)
        .register_fn("PrHub-pr-at", pr::PrHub::pr_at)
        // PR diff
        .register_fn("PrHub-start-diff-fetch", pr::PrHub::start_diff_fetch)
        .register_fn("PrHub-diff-fetch-complete?", pr::PrHub::diff_fetch_complete)
        .register_fn("PrHub-diff-lines", pr::PrHub::diff_lines)
        .register_fn("PrHub-diff-line-count", pr::PrHub::diff_line_count)
        // GhPr accessors — use closures to adapt &self methods for Steel FFI
        .register_fn("GhPr-repo-name", |pr: &pr::GhPr| pr.repo_name())
        .register_fn("GhPr-number", |pr: &pr::GhPr| pr.number())
        .register_fn("GhPr-title", |pr: &pr::GhPr| pr.title())
        .register_fn("GhPr-author", |pr: &pr::GhPr| pr.author())
        .register_fn("GhPr-state", |pr: &pr::GhPr| pr.state())
        .register_fn("GhPr-branch", |pr: &pr::GhPr| pr.branch())
        .register_fn("GhPr-additions", |pr: &pr::GhPr| pr.additions())
        .register_fn("GhPr-deletions", |pr: &pr::GhPr| pr.deletions())
        .register_fn("GhPr-updated-at", |pr: &pr::GhPr| pr.updated_at())
        // Changed files
        .register_fn("PrHub-start-files-fetch", pr::PrHub::start_files_fetch)
        .register_fn("PrHub-files-fetch-complete?", pr::PrHub::files_fetch_complete)
        .register_fn("PrHub-file-count", pr::PrHub::file_count)
        .register_fn("PrHub-file-at", pr::PrHub::file_at)
        .register_fn("PrHub-set-file-diff", pr::PrHub::set_file_diff)
        .register_fn("PrHub-file-diff-lines", pr::PrHub::file_diff_lines)
        .register_fn("PrHub-file-diff-line-count", pr::PrHub::file_diff_line_count)
        // GhChangedFile accessors
        .register_fn("GhChangedFile-filename", |f: &pr::GhChangedFile| f.filename())
        .register_fn("GhChangedFile-status", |f: &pr::GhChangedFile| f.status())
        .register_fn("GhChangedFile-additions", |f: &pr::GhChangedFile| f.additions())
        .register_fn("GhChangedFile-deletions", |f: &pr::GhChangedFile| f.deletions())
        .register_fn("GhChangedFile-review-comments", |f: &pr::GhChangedFile| f.review_comments())
        .register_fn("GhChangedFile-patch", |f: &pr::GhChangedFile| f.patch())
        // Unicode helpers
        .register_fn("unicode-display-width", unicode_display_width)
        .register_fn("unicode-truncate-to-width", unicode_truncate_to_width);

    module
}

fn unicode_display_width(s: String) -> usize {
    unicode_width::UnicodeWidthStr::width(s.as_str())
}

fn unicode_truncate_to_width(s: String, max_width: usize) -> String {
    use unicode_width::UnicodeWidthChar;
    let mut width = 0;
    let mut result = String::new();
    for c in s.chars() {
        let w = c.width().unwrap_or(0);
        if width + w > max_width {
            break;
        }
        width += w;
        result.push(c);
    }
    result
}
