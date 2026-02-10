(provide draw-box!
         draw-text-line!
         draw-horizontal-line!
         centered-rect
         BORDER-TOP-LEFT
         BORDER-TOP-RIGHT
         BORDER-BOTTOM-LEFT
         BORDER-BOTTOM-RIGHT
         BORDER-HORIZONTAL
         BORDER-VERTICAL)

(require "helix/components.scm")
(require "ui/styles.scm")

;; Box-drawing characters
(define BORDER-TOP-LEFT "╭")
(define BORDER-TOP-RIGHT "╮")
(define BORDER-BOTTOM-LEFT "╰")
(define BORDER-BOTTOM-RIGHT "╯")
(define BORDER-HORIZONTAL "─")
(define BORDER-VERTICAL "│")

;; Calculate a centered rectangle given parent dimensions and desired size
(define (centered-rect parent-x parent-y parent-w parent-h w h)
  (let ([x (+ parent-x (quotient (- parent-w w) 2))]
        [y (+ parent-y (quotient (- parent-h h) 2))])
    (list x y (min w parent-w) (min h parent-h))))

;; Draw a bordered box with optional title
(define (draw-box! frame x y w h style . title)
  (let ([title-str (if (null? title) "" (car title))])
    ;; Top border
    (let ([top-line (string-append
                     BORDER-TOP-LEFT
                     (if (> (string-length title-str) 0)
                         (string-append " " title-str " "
                                        (make-string (max 0 (- w 4
                                                              (string-length title-str)))
                                                     (string-ref BORDER-HORIZONTAL 0)))
                         (make-string (- w 2) (string-ref BORDER-HORIZONTAL 0)))
                     BORDER-TOP-RIGHT)])
      (frame-set-string! frame x y top-line style))
    ;; Sides
    (let loop ([row 1])
      (when (< row (- h 1))
        (frame-set-string! frame x (+ y row) BORDER-VERTICAL style)
        (frame-set-string! frame (+ x w -1) (+ y row) BORDER-VERTICAL style)
        (loop (+ row 1))))
    ;; Bottom border
    (let ([bottom-line (string-append
                        BORDER-BOTTOM-LEFT
                        (make-string (- w 2) (string-ref BORDER-HORIZONTAL 0))
                        BORDER-BOTTOM-RIGHT)])
      (frame-set-string! frame x (+ y h -1) bottom-line style))))

;; Draw a single line of text at position
(define (draw-text-line! frame x y text style . max-width)
  (let ([truncated (if (and (not (null? max-width))
                            (> (string-length text) (car max-width)))
                       (substring text 0 (car max-width))
                       text)])
    (frame-set-string! frame x y truncated style)))

;; Draw a horizontal line
(define (draw-horizontal-line! frame x y width style)
  (frame-set-string! frame x y
                     (make-string width (string-ref BORDER-HORIZONTAL 0))
                     style))
