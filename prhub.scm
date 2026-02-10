(require "helix/components.scm")
(require "helix/misc.scm")

(require-builtin steel/ffi)

(require "ui/pr_list.scm")
(require "ui/diff_view.scm")

(provide prhub)

(define *prhub-session* #f)

(define (destroy-session)
  (when *prhub-session*
    (cancel-session! *prhub-session*))
  (set! *prhub-session* #f))

(define (create-new-session)
  (set! *prhub-session* (create-prhub-window))
  (resume-session))

(define (resume-session)
  (push-component!
   (new-component!
    "prhub-window"
    *prhub-session*
    prhub-render
    (hash "handle_event" (make-prhub-event-handler)
          "cursor" prhub-cursor-handler))))

(define (make-prhub-event-handler)
  (lambda (state event)
    (cond
      ;; Escape hides the window (session persists)
      [(key-event-escape? event) event-result/close]
      ;; Ctrl+C destroys session entirely
      [(and (key-event-char event)
            (equal? (key-event-char event) #\c)
            (equal? (key-event-modifier event) key-modifier-ctrl))
       (enqueue-thread-local-callback (lambda () (destroy-session)))
       event-result/close]
      [else
       (let ([result (prhub-event-handler state event)])
         (if (equal? result 'destroy-and-close)
             (begin
               (enqueue-thread-local-callback (lambda () (destroy-session)))
               event-result/close)
             result))])))

;;@doc
;; Open PR review hub. Resume session if one exists, otherwise fetch PRs.
(define (prhub)
  (if *prhub-session*
      (resume-session)
      (create-new-session)))
