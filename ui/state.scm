(provide PrHubWindow
         PrHubWindow?
         PrHubWindow-screen
         PrHubWindow-cursor-index
         PrHubWindow-scroll-offset
         PrHubWindow-engine
         PrHubWindow-diff-scroll
         PrHubWindow-file-cursor
         PrHubWindow-file-scroll
         PrHubWindow-file-diff-scroll
         PrHubWindow-current-repo
         PrHubWindow-current-pr-number
         set-PrHubWindow-screen!
         set-PrHubWindow-cursor-index!
         set-PrHubWindow-scroll-offset!
         set-PrHubWindow-engine!
         set-PrHubWindow-diff-scroll!
         set-PrHubWindow-file-cursor!
         set-PrHubWindow-file-scroll!
         set-PrHubWindow-file-diff-scroll!
         set-PrHubWindow-current-repo!
         set-PrHubWindow-current-pr-number!)

;; screen: 'pr-list | 'diff-view | 'file-list | 'file-diff
;; engine: PrHub instance from Rust
(struct PrHubWindow (screen cursor-index scroll-offset engine diff-scroll
                     file-cursor file-scroll file-diff-scroll
                     current-repo current-pr-number) #:mutable)
