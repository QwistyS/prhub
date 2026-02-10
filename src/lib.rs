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
        .register_fn("GhPr-number", |pr: &pr::GhPr| pr.number())
        .register_fn("GhPr-title", |pr: &pr::GhPr| pr.title())
        .register_fn("GhPr-author", |pr: &pr::GhPr| pr.author())
        .register_fn("GhPr-state", |pr: &pr::GhPr| pr.state())
        .register_fn("GhPr-branch", |pr: &pr::GhPr| pr.branch())
        .register_fn("GhPr-additions", |pr: &pr::GhPr| pr.additions())
        .register_fn("GhPr-deletions", |pr: &pr::GhPr| pr.deletions())
        .register_fn("GhPr-updated-at", |pr: &pr::GhPr| pr.updated_at())
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
