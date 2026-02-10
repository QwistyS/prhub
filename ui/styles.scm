(require "helix/components.scm")

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
   (theme-scope "ui.text")
   (theme-scope "ui.popup")
   (style-with-bold (theme-scope "ui.text"))
   (theme-scope "ui.text.inactive")
   (theme-scope "ui.statusline")
   (theme-scope "diff.plus")
   (theme-scope "diff.minus")
   (theme-scope "info")
   (theme-scope "error")
   (theme-scope "ui.text")
   (theme-scope "ui.background")))
