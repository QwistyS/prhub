(provide UIStyles
         UIStyles-text
         UIStyles-popup
         UIStyles-active
         UIStyles-dim
         UIStyles-status
         UIStyles-added
         UIStyles-removed
         UIStyles-info
         UIStyles-error
         UIStyles-fg
         UIStyles-bg
         ui-styles)

(struct UIStyles (text popup active dim status added removed info error fg bg))

(define (ui-styles)
  (UIStyles
   (theme-scope *helix.cx* "ui.text")
   (theme-scope *helix.cx* "ui.popup")
   (style-with-bold (theme-scope *helix.cx* "ui.text") #t)
   (theme-scope *helix.cx* "ui.text.inactive")
   (theme-scope *helix.cx* "ui.statusline")
   (theme-scope *helix.cx* "diff.plus")
   (theme-scope *helix.cx* "diff.minus")
   (theme-scope *helix.cx* "info")
   (theme-scope *helix.cx* "error")
   (theme-scope *helix.cx* "ui.text")
   (theme-scope *helix.cx* "ui.background")))
