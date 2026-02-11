(provide render-file-list
         handle-file-list-event
         render-file-diff
         handle-file-diff-event)

(require "helix/components.scm")
(require "helix/misc.scm")

(require "ui/drawing.scm")
(require "ui/styles.scm")
(require "ui/ffi.scm")
(require "ui/state.scm")

;; ---------------------------------------------------------------------------
;; File list rendering
;; ---------------------------------------------------------------------------

(define (render-file-list state rect frame styles)
  (let* ([rx (area-x rect)]
         [ry (area-y rect)]
         [rw (area-width rect)]
         [rh (area-height rect)]
         [box-w (min (- rw 4) 100)]
         [box-h (min (- rh 4) 30)]
         [layout (centered-rect rx ry rw rh box-w box-h)]
         [bx (car layout)]
         [by (cadr layout)]
         [bw (caddr layout)]
         [bh (cadddr layout)]
         [engine (PrHubWindow-engine state)]
         [popup-style (UIStyles-popup styles)])

    (draw-box! frame bx by bw bh popup-style "Changed Files")

    (let ([cx (+ bx 2)]
          [cy (+ by 1)]
          [cw (- bw 4)]
          [ch (- bh 2)])

      (cond
        ;; Still loading
        [(not (PrHub-files-fetch-complete? engine))
         (draw-text-line! frame cx cy "Loading files..." (UIStyles-info styles))]

        ;; Error
        [(> (string-length (PrHub-error engine)) 0)
         (draw-text-line! frame cx cy
                          (string-append "Error: " (PrHub-error engine))
                          (UIStyles-error styles))]

        ;; No files
        [(= (PrHub-file-count engine) 0)
         (draw-text-line! frame cx cy "No changed files." (UIStyles-dim styles))]

        ;; Render file list
        [else
         (let ([cursor (PrHubWindow-file-cursor state)]
               [offset (PrHubWindow-file-scroll state)]
               [count (PrHub-file-count engine)]
               [visible-rows (- ch 1)])

           ;; Status line
           (draw-text-line! frame cx cy
                            (string-append "Files (" (number->string count)
                                           ") | j/k:navigate | Enter:diff | Esc:back")
                            (UIStyles-status styles) cw)

           ;; File rows
           (let loop ([i 0])
             (when (and (< i visible-rows)
                        (< (+ offset i) count))
               (let* ([f-idx (+ offset i)]
                      [file (PrHub-file-at engine f-idx)]
                      [selected? (= f-idx cursor)]
                      [style (if selected?
                                 (UIStyles-active styles)
                                 (UIStyles-text styles))]
                      [line (format-file-line file cw)])
                 (draw-text-line! frame cx (+ cy 1 i) line style cw))
               (loop (+ i 1)))))]))))

(define (format-file-line file max-width)
  (let* ([status (GhChangedFile-status file)]
         [flag (cond
                 [(equal? status "added")    "A"]
                 [(equal? status "removed")  "D"]
                 [(equal? status "modified") "M"]
                 [(equal? status "renamed")  "R"]
                 [else "?"])]
         [stats (string-append " +" (number->string (GhChangedFile-additions file))
                               "/-" (number->string (GhChangedFile-deletions file)))]
         [prefix (string-append flag " ")]
         [name-space (max 10 (- max-width
                                (string-length prefix)
                                (string-length stats)))]
         [name (let ([n (GhChangedFile-filename file)])
                 (if (> (string-length n) name-space)
                     (string-append "~" (substring n (- (string-length n) (- name-space 1))
                                                     (string-length n)))
                     n))])
    (string-append prefix name stats)))

;; ---------------------------------------------------------------------------
;; File list event handling
;; ---------------------------------------------------------------------------

(define (handle-file-list-event state event)
  (let ([engine (PrHubWindow-engine state)]
        [ch (key-event-char event)])
    (cond
      ;; Esc or q — back to PR list
      [(key-event-escape? event)
       (set-PrHubWindow-screen! state 'pr-list)
       event-result/consume]

      [(and ch (equal? ch #\q))
       (set-PrHubWindow-screen! state 'pr-list)
       event-result/consume]

      ;; j — move cursor down
      [(and ch (equal? ch #\j))
       (move-file-cursor state 1)
       event-result/consume]

      ;; k — move cursor up
      [(and ch (equal? ch #\k))
       (move-file-cursor state -1)
       event-result/consume]

      ;; Enter — open file-scoped diff
      [(key-event-enter? event)
       (when (> (PrHub-file-count engine) 0)
         (PrHub-set-file-diff engine (PrHubWindow-file-cursor state))
         (set-PrHubWindow-file-diff-scroll! state 0)
         (set-PrHubWindow-screen! state 'file-diff))
       event-result/consume]

      ;; D — view full PR diff
      [(and ch (equal? ch #\D))
       (let ([repo (PrHubWindow-current-repo state)]
             [num  (PrHubWindow-current-pr-number state)])
         (PrHub-start-diff-fetch engine repo num)
         (set-PrHubWindow-diff-scroll! state 0)
         (set-PrHubWindow-screen! state 'diff-view))
       event-result/consume]

      [else event-result/consume])))

(define (move-file-cursor state delta)
  (let* ([engine (PrHubWindow-engine state)]
         [count (PrHub-file-count engine)]
         [new-cursor (max 0 (min (- count 1)
                                 (+ (PrHubWindow-file-cursor state) delta)))])
    (set-PrHubWindow-file-cursor! state new-cursor)
    (let ([offset (PrHubWindow-file-scroll state)])
      (when (< new-cursor offset)
        (set-PrHubWindow-file-scroll! state new-cursor))
      (when (>= new-cursor (+ offset 20))
        (set-PrHubWindow-file-scroll! state (- new-cursor 19))))))

;; ---------------------------------------------------------------------------
;; File-scoped diff rendering
;; ---------------------------------------------------------------------------

(define (render-file-diff state rect frame styles)
  (let* ([rx (area-x rect)]
         [ry (area-y rect)]
         [rw (area-width rect)]
         [rh (area-height rect)]
         [engine (PrHubWindow-engine state)]
         [popup-style (UIStyles-popup styles)]
         ;; Show filename in title
         [file-idx (PrHubWindow-file-cursor state)]
         [title (if (> (PrHub-file-count engine) 0)
                    (string-append "Diff: "
                                   (GhChangedFile-filename
                                    (PrHub-file-at engine file-idx)))
                    "Diff")])

    (draw-box! frame rx ry rw rh popup-style title)

    (let ([cx (+ rx 1)]
          [cy (+ ry 1)]
          [cw (- rw 2)]
          [ch (- rh 2)]
          [scroll (PrHubWindow-file-diff-scroll state)])

      (let ([total (PrHub-file-diff-line-count engine)])
        (if (= total 0)
            (draw-text-line! frame cx cy "No diff content (binary file?)"
                             (UIStyles-dim styles))
            (let ([lines (PrHub-file-diff-lines engine scroll ch)])
              (let loop ([i 0] [remaining lines])
                (when (and (< i ch) (not (null? remaining)))
                  (let* ([line (car remaining)]
                         [style (file-diff-line-style line styles)])
                    (draw-text-line! frame cx (+ cy i) line style cw))
                  (loop (+ i 1) (cdr remaining))))))))))

(define (file-diff-line-style line styles)
  (cond
    [(= (string-length line) 0) (UIStyles-text styles)]
    [(equal? (string-ref line 0) #\+) (UIStyles-added styles)]
    [(equal? (string-ref line 0) #\-) (UIStyles-removed styles)]
    [(equal? (string-ref line 0) #\@) (UIStyles-info styles)]
    [else (UIStyles-text styles)]))

;; ---------------------------------------------------------------------------
;; File-scoped diff event handling
;; ---------------------------------------------------------------------------

(define (handle-file-diff-event state event)
  (let ([ch (key-event-char event)]
        [engine (PrHubWindow-engine state)])
    (cond
      ;; Esc — back to file list
      [(key-event-escape? event)
       (set-PrHubWindow-screen! state 'file-list)
       event-result/consume]

      ;; q — back to file list
      [(and ch (equal? ch #\q))
       (set-PrHubWindow-screen! state 'file-list)
       event-result/consume]

      ;; j — scroll down
      [(and ch (equal? ch #\j))
       (scroll-file-diff state 1)
       event-result/consume]

      ;; k — scroll up
      [(and ch (equal? ch #\k))
       (scroll-file-diff state -1)
       event-result/consume]

      ;; d — half page down
      [(and ch (equal? ch #\d))
       (scroll-file-diff state 15)
       event-result/consume]

      ;; u — half page up
      [(and ch (equal? ch #\u))
       (scroll-file-diff state -15)
       event-result/consume]

      [else event-result/consume])))

(define (scroll-file-diff state delta)
  (let* ([engine (PrHubWindow-engine state)]
         [total (PrHub-file-diff-line-count engine)]
         [current (PrHubWindow-file-diff-scroll state)]
         [new-scroll (max 0 (min (- total 1) (+ current delta)))])
    (set-PrHubWindow-file-diff-scroll! state new-scroll)))
