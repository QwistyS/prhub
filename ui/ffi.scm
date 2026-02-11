(require-builtin steel/ffi)

(#%require-dylib "libprhub"
  (only-in PrHub-new
           PrHub-start-fetch
           PrHub-fetch-complete?
           PrHub-cancel-fetch
           PrHub-error
           PrHub-pr-count
           PrHub-pr-at
           PrHub-start-diff-fetch
           PrHub-diff-fetch-complete?
           PrHub-diff-lines
           PrHub-diff-line-count
           PrHub-start-files-fetch
           PrHub-files-fetch-complete?
           PrHub-file-count
           PrHub-file-at
           PrHub-set-file-diff
           PrHub-file-diff-lines
           PrHub-file-diff-line-count
           GhPr-repo-name
           GhPr-number
           GhPr-title
           GhPr-author
           GhPr-additions
           GhPr-deletions
           GhChangedFile-filename
           GhChangedFile-status
           GhChangedFile-additions
           GhChangedFile-deletions
           GhChangedFile-patch))

(provide PrHub-new
         PrHub-start-fetch
         PrHub-fetch-complete?
         PrHub-cancel-fetch
         PrHub-error
         PrHub-pr-count
         PrHub-pr-at
         PrHub-start-diff-fetch
         PrHub-diff-fetch-complete?
         PrHub-diff-lines
         PrHub-diff-line-count
         PrHub-start-files-fetch
         PrHub-files-fetch-complete?
         PrHub-file-count
         PrHub-file-at
         PrHub-set-file-diff
         PrHub-file-diff-lines
         PrHub-file-diff-line-count
         GhPr-repo-name
         GhPr-number
         GhPr-title
         GhPr-author
         GhPr-additions
         GhPr-deletions
         GhChangedFile-filename
         GhChangedFile-status
         GhChangedFile-additions
         GhChangedFile-deletions
         GhChangedFile-patch)
