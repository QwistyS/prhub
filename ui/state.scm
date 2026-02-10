(provide PrHubWindow
         PrHubWindow?
         PrHubWindow-screen
         PrHubWindow-cursor-index
         PrHubWindow-scroll-offset
         PrHubWindow-engine
         PrHubWindow-diff-scroll
         set-PrHubWindow-screen!
         set-PrHubWindow-cursor-index!
         set-PrHubWindow-scroll-offset!
         set-PrHubWindow-engine!
         set-PrHubWindow-diff-scroll!)

;; screen: 'pr-list | 'diff-view
;; engine: PrHub instance from Rust
(struct PrHubWindow (screen cursor-index scroll-offset engine diff-scroll) #:mutable)
