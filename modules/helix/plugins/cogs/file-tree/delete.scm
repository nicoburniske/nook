(require (prefix-in helix. "helix/commands.scm"))
(require "helix/components.scm")
(require "helix/misc.scm")
(require "./core.scm")

(provide tree-open-delete-confirm!)

(define (tree-close-delete-confirm! state)
  (set-box! (FileTreeState-delete-confirm-path state) #f))

(define (tree-confirm-delete! state)
  (define target (unbox (FileTreeState-delete-confirm-path state)))
  (tree-close-delete-confirm! state)
  (when (and (string? target) (not (equal? target "")))
    (define fallback-focus (path-parent target))
    (define quoted (string-append "\"" (shell-escape target) "\""))
    (if (is-dir? target)
        (helix.run-shell-command (string-append "rm -rf -- " quoted))
        (helix.run-shell-command (string-append "rm -f -- " quoted)))
    (set-box! (FileTreeState-directories state)
              (tree-unfold-path-to-target
               (unbox (FileTreeState-directories state))
               (FileTreeState-root state)
               fallback-focus))
    (tree-refresh-when state target (lambda (path) (not (path-exists? path))) fallback-focus)))

(define (tree-delete-confirm-event-handler state event)
  (define char (key-event-char event))
  (cond
    [(key-event-escape? event)
     (tree-close-delete-confirm! state)
     event-result/close]

    [(and (char? char)
          (or (equal? char #\n)
              (equal? char #\N)))
     (tree-close-delete-confirm! state)
     event-result/close]

    [(key-event-enter? event)
     (tree-confirm-delete! state)
     event-result/close]

    [(and (char? char)
          (or (equal? char #\y)
              (equal? char #\Y)))
     (tree-confirm-delete! state)
     event-result/close]

    [else event-result/consume-without-rerender]))

(define (tree-delete-confirm-render state rect frame)
  (define target (unbox (FileTreeState-delete-confirm-path state)))
  (when (string? target)
    (define width (area-width rect))
    (define height (area-height rect))
    (define tree-width (max 56 (min 120 (- width 6))))
    (define tree-height-target (exact (round (/ (* height 2) 3))))
    (define tree-height (tree-clamp tree-height-target 8 (max 8 (- height 2))))
    (define tree-x (max 0 (exact (round (/ (- width tree-width) 2)))))
    (define tree-y (max 0 (exact (round (/ (- height tree-height) 2)))))
    (define tree-area (area tree-x tree-y tree-width tree-height))

    (define modal-width (max 32 (min (- tree-width 4) 42)))
    (define modal-height 7)
    (define modal-x (+ (area-x tree-area) (max 0 (exact (round (/ (- tree-width modal-width) 2))))))
    (define modal-y (+ (area-y tree-area) (max 0 (exact (round (/ (- tree-height modal-height) 2))))))
    (define modal-area (area modal-x modal-y modal-width modal-height))
    (define inner-width (max 1 (- modal-width 2)))
    (define row-style (theme-scope "ui.text"))
    (define border-style row-style)
    (define tree-style (style))
    (define title-text (tree-truncate "delete file" inner-width))
    (define target-name (file-name target))
    (define target-text
      (tree-truncate
       (if (and (string? target-name) (not (equal? target-name "")))
           target-name
           target)
       inner-width))
    (define footer-yes "[Y]es")
    (define footer-no "[N]o")
    (define footer-gap " ")
    (define footer-text (tree-truncate (string-append footer-yes footer-gap footer-no) inner-width))
    (define blank-line (make-string inner-width #\space))
    (define yes-style (style-fg row-style Color/Green))
    (define no-style (style-fg row-style Color/Red))
    (define (centered-col text)
      (+ modal-x 1 (max 0 (exact (round (/ (- inner-width (string-length text)) 2))))))

    (buffer/clear-with frame modal-area tree-style)
    (block/render frame modal-area (make-block tree-style border-style "all" "rounded"))
    (frame-set-string! frame (+ modal-x 1) (+ modal-y 1) blank-line tree-style)
    (frame-set-string! frame (centered-col title-text) (+ modal-y 1) title-text row-style)
    (frame-set-string! frame (+ modal-x 1) (+ modal-y 3) blank-line tree-style)
    (frame-set-string! frame (+ modal-x 1) (+ modal-y 3) target-text row-style)
    (frame-set-string! frame (+ modal-x 1) (+ modal-y 5) blank-line tree-style)
    (define footer-x (centered-col footer-text))
    (frame-set-string! frame footer-x (+ modal-y 5) footer-yes yes-style)
    (frame-set-string! frame (+ footer-x (string-length footer-yes)) (+ modal-y 5) footer-gap row-style)
    (frame-set-string! frame
                       (+ footer-x (string-length footer-yes) (string-length footer-gap))
                       (+ modal-y 5)
                       footer-no
                       no-style)))

(define (tree-open-delete-confirm! state)
  (define entry (tree-current-entry state))
  (when entry
    (set-box! (FileTreeState-delete-confirm-path state) (tree-entry-path entry))
    (push-component!
     (new-component! "file-tree-delete-confirm"
                     state
                     tree-delete-confirm-render
                     (hash "handle_event" tree-delete-confirm-event-handler))))
  event-result/consume)
