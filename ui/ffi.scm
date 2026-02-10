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
           GhPr-number
           GhPr-title
           GhPr-author
           GhPr-additions
           GhPr-deletions))

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
         GhPr-number
         GhPr-title
         GhPr-author
         GhPr-additions
         GhPr-deletions)
