(provide create-prhub-window
         cancel-session!
         prhub-render
         prhub-event-handler
         prhub-cursor-handler)

(require "helix/components.scm")
(require "helix/misc.scm")

(require "ui/drawing.scm")
(require "ui/styles.scm")
(require "ui/ffi.scm")
(require "ui/state.scm")
(require "ui/diff_view.scm")

;; ---------------------------------------------------------------------------
;; State
;; ---------------------------------------------------------------------------

;; screen: 'pr-list | 'diff-view
;; engine: PrHub instance from Rust

(define (create-prhub-window)
  (let ([engine (PrHub-new)])
    (PrHub-start-fetch engine)
    (PrHubWindow 'pr-list 0 0 engine 0)))

(define (cancel-session! state)
  (PrHub-cancel-fetch (PrHubWindow-engine state)))

;; ---------------------------------------------------------------------------
;; Render dispatch
;; ---------------------------------------------------------------------------

(define (prhub-render state rect frame)
  (let ([styles (ui-styles)])
    (case (PrHubWindow-screen state)
      [(pr-list)   (render-pr-list state rect frame styles)]
      [(diff-view) (render-diff-view state rect frame styles)])))

(define (prhub-cursor-handler state)
  #f)

;; ---------------------------------------------------------------------------
;; PR list rendering
;; ---------------------------------------------------------------------------

(define (render-pr-list state rect frame styles)
  (let* ([rx (area-x rect)]
         [ry (area-y rect)]
         [rw (area-width rect)]
         [rh (area-height rect)]
         ;; Center a box taking 80% of space
         [box-w (min (- rw 4) 100)]
         [box-h (min (- rh 4) 30)]
         [layout (centered-rect rx ry rw rh box-w box-h)]
         [bx (car layout)]
         [by (cadr layout)]
         [bw (caddr layout)]
         [bh (cadddr layout)]
         [engine (PrHubWindow-engine state)]
         [popup-style (UIStyles-popup styles)])

    ;; Draw the outer box
    (draw-box! frame bx by bw bh popup-style "prhub - PR Review")

    ;; Content area (inside the box)
    (let ([cx (+ bx 2)]
          [cy (+ by 1)]
          [cw (- bw 4)]
          [ch (- bh 2)])

      (cond
        ;; Still loading
        [(not (PrHub-fetch-complete? engine))
         (draw-text-line! frame cx cy "Loading PRs..." (UIStyles-info styles))]

        ;; Error
        [(> (string-length (PrHub-error engine)) 0)
         (draw-text-line! frame cx cy
                          (string-append "Error: " (PrHub-error engine))
                          (UIStyles-error styles))]

        ;; No PRs
        [(= (PrHub-pr-count engine) 0)
         (draw-text-line! frame cx cy "No open PRs found." (UIStyles-dim styles))]

        ;; Render PR list
        [else
         (let ([cursor (PrHubWindow-cursor-index state)]
               [offset (PrHubWindow-scroll-offset state)]
               [count (PrHub-pr-count engine)]
               [visible-rows (- ch 1)])

           ;; Status line
           (draw-text-line! frame cx cy
                            (string-append "PRs (" (number->string count)
                                           ") | j/k:navigate | Enter:view diff | q:quit")
                            (UIStyles-status styles) cw)

           ;; PR rows
           (let loop ([i 0])
             (when (and (< i visible-rows)
                        (< (+ offset i) count))
               (let* ([pr-idx (+ offset i)]
                      [pr (PrHub-pr-at engine pr-idx)]
                      [selected? (= pr-idx cursor)]
                      [style (if selected?
                                 (UIStyles-active styles)
                                 (UIStyles-text styles))]
                      [line (format-pr-line pr cw)])
                 (draw-text-line! frame cx (+ cy 1 i) line style cw))
               (loop (+ i 1)))))]))))

(define (format-pr-line pr max-width)
  (let* ([num (number->string (GhPr-number pr))]
         [prefix (string-append "#" num " ")]
         [author (string-append " @" (GhPr-author pr))]
         [stats (string-append " +" (number->string (GhPr-additions pr))
                               "/-" (number->string (GhPr-deletions pr)))]
         [title-space (max 10 (- max-width
                                 (string-length prefix)
                                 (string-length author)
                                 (string-length stats)))]
         [title (let ([t (GhPr-title pr)])
                  (if (> (string-length t) title-space)
                      (string-append (substring t 0 (- title-space 1)) "~")
                      t))])
    (string-append prefix title author stats)))

;; ---------------------------------------------------------------------------
;; Event handling
;; ---------------------------------------------------------------------------

(define (prhub-event-handler state event)
  (case (PrHubWindow-screen state)
    [(pr-list)   (handle-pr-list-event state event)]
    [(diff-view) (handle-diff-view-event state event)]))

(define (handle-pr-list-event state event)
  (let ([engine (PrHubWindow-engine state)]
        [ch (key-event-char event)])
    (cond
      ;; q to quit
      [(and ch (equal? ch #\q))
       'destroy-and-close]

      ;; j / down — move cursor down
      [(and ch (equal? ch #\j))
       (move-cursor state 1)
       event-result/consume]

      ;; k / up — move cursor up
      [(and ch (equal? ch #\k))
       (move-cursor state -1)
       event-result/consume]

      ;; Enter — open diff view
      [(key-event-enter? event)
       (when (> (PrHub-pr-count engine) 0)
         (let ([pr (PrHub-pr-at engine (PrHubWindow-cursor-index state))])
           (when pr
             (PrHub-start-diff-fetch engine (GhPr-number pr))
             (set-PrHubWindow-diff-scroll! state 0)
             (set-PrHubWindow-screen! state 'diff-view))))
       event-result/consume]

      ;; r — refresh
      [(and ch (equal? ch #\r))
       (PrHub-start-fetch engine)
       (set-PrHubWindow-cursor-index! state 0)
       (set-PrHubWindow-scroll-offset! state 0)
       event-result/consume]

      [else event-result/consume])))

(define (move-cursor state delta)
  (let* ([engine (PrHubWindow-engine state)]
         [count (PrHub-pr-count engine)]
         [new-cursor (max 0 (min (- count 1)
                                 (+ (PrHubWindow-cursor-index state) delta)))])
    (set-PrHubWindow-cursor-index! state new-cursor)
    ;; Adjust scroll if cursor goes out of view (assume ~20 visible rows)
    (let ([offset (PrHubWindow-scroll-offset state)])
      (when (< new-cursor offset)
        (set-PrHubWindow-scroll-offset! state new-cursor))
      (when (>= new-cursor (+ offset 20))
        (set-PrHubWindow-scroll-offset! state (- new-cursor 19))))))
