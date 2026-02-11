(provide render-diff-view
         handle-diff-view-event)

(require "helix/components.scm")
(require "helix/misc.scm")

(require "ui/drawing.scm")
(require "ui/styles.scm")
(require "ui/ffi.scm")
(require "ui/state.scm")

;; ---------------------------------------------------------------------------
;; Diff view rendering
;; ---------------------------------------------------------------------------

(define (render-diff-view state rect frame styles)
  (let* ([rx (area-x rect)]
         [ry (area-y rect)]
         [rw (area-width rect)]
         [rh (area-height rect)]
         [engine (PrHubWindow-engine state)]
         [popup-style (UIStyles-popup styles)])

    ;; Use the full area for diff
    (draw-box! frame rx ry rw rh popup-style "Full Diff (Esc:back, j/k:scroll)")

    (let ([cx (+ rx 1)]
          [cy (+ ry 1)]
          [cw (- rw 2)]
          [ch (- rh 2)]
          [scroll (PrHubWindow-diff-scroll state)])

      (cond
        ;; Still loading
        [(not (PrHub-diff-fetch-complete? engine))
         (draw-text-line! frame cx cy "Loading diff..."
                          (UIStyles-info styles))]

        ;; Error
        [(> (string-length (PrHub-error engine)) 0)
         (draw-text-line! frame cx cy
                          (string-append "Error: " (PrHub-error engine))
                          (UIStyles-error styles))]

        ;; Render diff lines
        [else
         (let ([lines (PrHub-diff-lines engine scroll ch)]
               [total (PrHub-diff-line-count engine)])

           ;; Diff lines with syntax coloring
           (let loop ([i 0] [remaining lines])
             (when (and (< i ch) (not (null? remaining)))
               (let* ([line (car remaining)]
                      [style (diff-line-style line styles)])
                 (draw-text-line! frame cx (+ cy i) line style cw))
               (loop (+ i 1) (cdr remaining)))))]))))

;; Pick style based on diff line prefix
(define (diff-line-style line styles)
  (cond
    [(= (string-length line) 0) (UIStyles-text styles)]
    [(equal? (string-ref line 0) #\+) (UIStyles-added styles)]
    [(equal? (string-ref line 0) #\-) (UIStyles-removed styles)]
    [(equal? (string-ref line 0) #\@) (UIStyles-info styles)]
    [else (UIStyles-text styles)]))

;; ---------------------------------------------------------------------------
;; Diff view event handling
;; ---------------------------------------------------------------------------

(define (handle-diff-view-event state event)
  (let ([ch (key-event-char event)]
        [engine (PrHubWindow-engine state)])
    (cond
      ;; Escape — back to file list
      [(key-event-escape? event)
       (set-PrHubWindow-screen! state 'file-list)
       event-result/consume]

      ;; j / down — scroll down
      [(and ch (equal? ch #\j))
       (scroll-diff state 1)
       event-result/consume]

      ;; k / up — scroll up
      [(and ch (equal? ch #\k))
       (scroll-diff state -1)
       event-result/consume]

      ;; d — half page down
      [(and ch (equal? ch #\d))
       (scroll-diff state 15)
       event-result/consume]

      ;; u — half page up
      [(and ch (equal? ch #\u))
       (scroll-diff state -15)
       event-result/consume]

      ;; q — back to file list
      [(and ch (equal? ch #\q))
       (set-PrHubWindow-screen! state 'file-list)
       event-result/consume]

      [else event-result/consume])))

(define (scroll-diff state delta)
  (let* ([engine (PrHubWindow-engine state)]
         [total (PrHub-diff-line-count engine)]
         [current (PrHubWindow-diff-scroll state)]
         [new-scroll (max 0 (min (- total 1) (+ current delta)))])
    (set-PrHubWindow-diff-scroll! state new-scroll)))
