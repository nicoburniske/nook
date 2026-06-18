(require (prefix-in helix. "helix/commands.scm"))
(require "helix/components.scm")
(require "helix/misc.scm")
(require "./core.scm")

(provide tree-open-create-input!
         tree-open-rename-input!)

(define (ends-with? value suffix)
  (if (< (string-length value) (string-length suffix))
      #f
      (equal? (substring value
                         (- (string-length value) (string-length suffix))
                         (string-length value))
              suffix)))

(define (ensure-trailing-slash path)
  (if (and (string? path) (not (ends-with? path "/")))
      (string-append path "/")
      path))

(struct FileTreeInputModalState
        (tree-state
         kind
         title
         prefix
         input
         cursor
         source-path))

(define (tree-open-input-modal! state kind title prefix initial-input source-path initial-cursor)
  (define input-value (if (string? initial-input) initial-input ""))
  (define cursor-value
    (if (number? initial-cursor)
        (tree-clamp initial-cursor 0 (string-length input-value))
        (string-length input-value)))
  (set-box! (FileTreeState-delete-confirm-path state) #f)

  (push-component!
   (new-component! "file-tree-input-modal"
                   (FileTreeInputModalState state
                                            kind
                                            title
                                            prefix
                                            (box input-value)
                                            (box cursor-value)
                                            source-path)
                   file-tree-input-modal-render
                   (hash "handle_event" file-tree-input-modal-event-handler)))

  event-result/consume)

(define (tree-input-modal-action-label modal)
  (if (equal? (FileTreeInputModalState-kind modal) 'rename)
      "rename"
      "create"))

(define (tree-open-create-input! state)
  (define base-path (tree-selected-base-path state))
  (tree-open-input-modal! state 'create "create" (ensure-trailing-slash base-path) "" #f #f))

(define (tree-open-rename-input! state)
  (define entry (tree-current-entry state))
  (if entry
      (let* ([source (TreeEntry-path entry)]
             [source-name (file-name source)]
             [source-parent (path-parent source)]
             [prefix (ensure-trailing-slash source-parent)]
             [name-length (string-length source-name)]
             [last-dot-index
              (let loop ([chars (string->list source-name)] [idx 0] [last-dot #f])
                (if (null? chars)
                    last-dot
                    (loop (cdr chars)
                          (+ idx 1)
                          (if (char=? (car chars) #\.) idx last-dot))))]
             [rename-cursor
              (if (and last-dot-index (> last-dot-index 0) (< last-dot-index (- name-length 1)))
                  last-dot-index
                  name-length)])
        (tree-open-input-modal! state
                                 'rename
                                 "rename"
                                 prefix
                                 source-name
                                 source
                                 rename-cursor))
      event-result/consume))

(define (tree-submit-create-input! state modal)
  (define result (unbox (FileTreeInputModalState-input modal)))
  (define prefix (FileTreeInputModalState-prefix modal))
  (when (and (string? result) (not (equal? result "")))
    (define path-name (string-append prefix result))
    (define target-path
      (if (ends-with? path-name "/")
          (trim-end-matches path-name "/")
          path-name))
    (when (not (equal? target-path ""))
      (if (ends-with? path-name "/")
          (hx.create-directory target-path)
          (let ([quoted (string-append "\"" (shell-escape target-path) "\"")])
            (hx.create-directory (file-directory target-path))
            (helix.run-shell-command (string-append "touch -- " quoted))))

      (set-box! (FileTreeState-directories state)
                (tree-unfold-path-to-target
                 (unbox (FileTreeState-directories state))
                 (unbox (FileTreeState-root state))
                 target-path))
      (tree-refresh-when state target-path path-exists? target-path))))

(define (tree-submit-rename-input! state modal)
  (define source (FileTreeInputModalState-source-path modal))
  (define answer (unbox (FileTreeInputModalState-input modal)))
  (define prefix (FileTreeInputModalState-prefix modal))

  (when (and (string? source)
             (string? answer)
             (not (equal? answer "")))
    (define source-name (file-name source))
    (define destination
      (if (and (> (string-length answer) 0)
               (equal? (substring answer 0 1) "/"))
          (path-clean answer)
          (path-clean (string-append prefix answer))))

    (when (and (string? destination)
               (not (equal? destination ""))
               (not (equal? answer source-name))
               (not (path=? destination source)))
      (define quoted-source (string-append "\"" (shell-escape source) "\""))
      (define quoted-destination (string-append "\"" (shell-escape destination) "\""))
      (helix.run-shell-command (string-append "mv -- " quoted-source " " quoted-destination))
      (set-box! (FileTreeState-directories state)
                (tree-unfold-path-to-target
                 (unbox (FileTreeState-directories state))
                 (unbox (FileTreeState-root state))
                 destination))
      (tree-refresh-when state
                           destination
                           (lambda (path)
                            (and (path-exists? path)
                                 (not (path-exists? source))))
                          destination))))

(define (tree-submit-input-modal! modal)
  (define state (FileTreeInputModalState-tree-state modal))
  (if (equal? (FileTreeInputModalState-kind modal) 'rename)
      (tree-submit-rename-input! state modal)
      (tree-submit-create-input! state modal)))

(define (file-tree-input-modal-event-handler modal event)
  (define char (key-event-char event))
  (define input-box (FileTreeInputModalState-input modal))
  (define cursor-box (FileTreeInputModalState-cursor modal))
  (cond
    [(key-event-escape? event)
     event-result/close]

    [(key-event-enter? event)
     (tree-submit-input-modal! modal)
     event-result/close]

    [(key-event-backspace? event)
     (tree-text-backspace! input-box cursor-box)
     event-result/consume]

    [(key-event-delete? event)
     (tree-text-delete-forward! input-box cursor-box)
     event-result/consume]

    [(key-event-left? event)
     (tree-text-move-cursor! input-box cursor-box -1)
     event-result/consume]

    [(key-event-right? event)
     (tree-text-move-cursor! input-box cursor-box 1)
     event-result/consume]

    [(key-event-home? event)
     (set-box! cursor-box 0)
     event-result/consume]

    [(key-event-end? event)
     (set-box! cursor-box (string-length (unbox input-box)))
     event-result/consume]

    [(tree-event-plain-char? event)
     (tree-text-append-char! input-box cursor-box char)
     event-result/consume]

    [else event-result/consume-without-rerender]))

(define (file-tree-input-modal-render modal rect frame)
  (define tree-area (tree-popup-area rect))
  (define tree-width (area-width tree-area))
  (define modal-width (max 32 (min (- tree-width 4) 42)))
  (define modal-height 5)
  (define modal-x (tree-center-x (area-x tree-area) tree-width modal-width))
  (define modal-y (+ (area-y tree-area) 1))
  (define modal-area (area modal-x modal-y modal-width modal-height))
  (define inner-width (max 1 (- modal-width 2)))
  (define row-style (theme-scope "ui.text"))
  (define focused-border-style (style-with-bold (style-fg row-style Color/LightBlue)))
  (define label-style (style-with-bold row-style))
  (define tree-style (style))
  (define input-text-style row-style)
  (define input-cursor-style (style-with-reversed row-style))
  (define input-title
    (tree-truncate (FileTreeInputModalState-title modal)
                    (max 1 (- inner-width 8))))
  (define action (tree-input-modal-action-label modal))
  (define footer-text (tree-truncate (string-append "[Enter] " action " [Esc] cancel") inner-width))
  (define input-box-x (+ modal-x 2))
  (define input-box-y (+ modal-y 1))
  (define input-box-width (max 6 (- modal-width 4)))
  (define input-box-height 3)
  (define input-box-area (area input-box-x input-box-y input-box-width input-box-height))
  (define input-width (max 1 (- input-box-width 2)))
  (define modal-input-box (FileTreeInputModalState-input modal))
  (define modal-cursor-box (FileTreeInputModalState-cursor modal))
  (define input-state (tree-text-visible-state modal-input-box modal-cursor-box input-width))
  (define input-content (list-ref input-state 0))
  (define cursor-col (list-ref input-state 1))
  (define input-x (+ input-box-x 1))
  (define input-y (+ input-box-y 1))
  (define input-row-blank (make-string input-width #\space))
  (define cursor-glyph
    (if (< cursor-col (string-length input-content))
        (substring input-content cursor-col (+ cursor-col 1))
        " "))
  (define titled-border (tree-truncate (string-append " " input-title " ")
                                        (max 1 (- input-box-width 4))))
  (define border-title-x (+ input-box-x 2))
  (define (centered-col text)
    (tree-center-x (+ modal-x 1) inner-width (string-length text)))

  (buffer/clear-with frame modal-area tree-style)

  (block/render frame input-box-area (make-block tree-style focused-border-style "all" "plain"))
  (frame-set-string! frame border-title-x input-box-y titled-border label-style)
  (frame-set-string! frame input-x input-y input-row-blank tree-style)
  (frame-set-string! frame input-x input-y input-content input-text-style)
  (frame-set-string! frame (+ input-x cursor-col) input-y cursor-glyph input-cursor-style)

  (frame-set-string! frame (centered-col footer-text) (+ modal-y 4) footer-text row-style))
