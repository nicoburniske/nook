;; Dropping the builtin, in lieu of something that uses the global context?
(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix.static. "helix/static.scm"))
(require "helix/misc.scm")
(require "helix/editor.scm")
(require "helix/components.scm")
; (require "steel/sorting/merge-sort.scm")

;;; -----------------------------------------------------------------
;;; Merge two lists of numbers which are already in increasing order

(define merge-lists
  (lambda (l1 l2 comparator)
    (if (null? l1)
        l2
        (if (null? l2)
            l1
            (if (comparator (car l1) (car l2))
                (cons (car l1) (merge-lists (cdr l1) l2 comparator))
                (cons (car l2) (merge-lists (cdr l2) l1 comparator)))))))

;;; -------------------------------------------------------------------
;;; Given list l, output those tokens of l which are in even positions

(define even-numbers
  (lambda (l)
    (if (null? l) '() (if (null? (cdr l)) '() (cons (car (cdr l)) (even-numbers (cdr (cdr l))))))))

;;; -------------------------------------------------------------------
;;; Given list l, output those tokens of l which are in odd positions

(define odd-numbers
  (lambda (l)
    (if (null? l)
        '()
        (if (null? (cdr l)) (list (car l)) (cons (car l) (odd-numbers (cdr (cdr l))))))))

;;; ---------------------------------------------------------------------
;;; Use the procedures above to create a simple and efficient merge-sort

(define (merge-sort l #:comparator [comparator <])
  (if (null? l)
      l
      (if (null? (cdr l))
          l
          (merge-lists (merge-sort (odd-numbers l) #:comparator comparator)
                       (merge-sort (even-numbers l) #:comparator comparator)
                       comparator))))

(provide create-file-tree
         create-file-tree-popup)

(define *ignore-set* (hashset "target"))

(define *extension-map*
  (hash "rs" " "
        "scm" "󰘧 "
        "nix" " "
        "md" " "))

(define (current-doc-id)
  (let* ([focus (editor-focus)])
    (editor->doc-id focus)))

(define (path-clean path)
  (if (and (string? path)
           (> (string-length path) 1)
           (equal? (substring path (- (string-length path) 1) (string-length path)) "/"))
      (substring path 0 (- (string-length path) 1))
      path))

(define (ends-with? value suffix)
  (if (< (string-length value) (string-length suffix))
      #f
      (equal? (substring value
                         (- (string-length value) (string-length suffix))
                         (string-length value))
              suffix)))

(define (path=? left right)
  (equal? (path-clean left) (path-clean right)))

(define (current-doc-path)
  (path-clean (editor-document->path (current-doc-id))))

(define (file-directory path)
  (if (and (string? path) (not (is-dir? path)))
      (path-clean (trim-end-matches path (file-name path)))
      (path-clean path)))

(define (resolve-tree-root target-path)
  (define workspace (helix-find-workspace))
  (cond
    [(and (string? workspace) (not (equal? workspace "/"))) (path-clean workspace)]
    [(string? target-path) (file-directory target-path)]
    [else (path-clean (helix.static.get-helix-cwd))]))

(define (path-parent path)
  (if (not (string? path))
      path
      (let* ([clean (path-clean path)]
             [name (file-name clean)])
        (if (or (equal? clean "/") (equal? name "") (equal? name clean))
            clean
            (path-clean (trim-end-matches clean name))))))

(define (entry-name path)
  (file-name path))

(define (path-sort<? left right)
  (define left-dir? (is-dir? left))
  (define right-dir? (is-dir? right))
  (cond
    [(and left-dir? (not right-dir?)) #t]
    [(and (not left-dir?) right-dir?) #f]
    [else (string<? (entry-name left) (entry-name right))]))

(define (path->symbol path)
  (let ([extension (path->extension path)])
    (if (not (void? extension))
        (let ([lookup (hash-try-get *extension-map* extension)])
          (if lookup lookup " "))
        " ")))

(define (shell-escape path)
  (define (escape-char ch)
    (cond
      [(char=? ch #\\) "\\\\"]
      [(char=? ch #\") "\\\""]
      [(char=? ch #\$) "\\$"]
      [(char=? ch #\`) "\\`"]
      [else (string ch)]))
  (apply string-append (map escape-char (string->list path))))

(struct FileTreePopupState
        (root
         entries
         directories
         cursor
         window-start
         max-length
         center-next-render
         show-hidden-directories
         delete-confirm-path))

(struct FileTreeInputModalState
        (tree-state
         kind
         title
         prefix
         input
         cursor
         source-path))

(define (popup-for-each-index func lst index)
  (if (null? lst)
      void
      (begin
        (func index (car lst))
        (popup-for-each-index func (cdr lst) (+ index 1)))))

(define (popup-entry path directory? display)
  (list path directory? display))

(define (popup-entry-path entry)
  (list-ref entry 0))

(define (popup-entry-directory? entry)
  (list-ref entry 1))

(define (popup-entry-display entry)
  (list-ref entry 2))

(define (popup-valid-entry? entry)
  (and (list? entry)
       (= (length entry) 3)
       (string? (list-ref entry 0))
       (boolean? (list-ref entry 1))
       (string? (list-ref entry 2))))

(define (popup-truncate text max-length)
  (if (<= max-length 0)
      ""
      (if (> (string-length text) max-length)
          (substring text 0 max-length)
          text)))

(define (string-insert-at value index fragment)
  (define clamped-index (popup-clamp index 0 (string-length value)))
  (string-append (substring value 0 clamped-index)
                 fragment
                 (substring value clamped-index (string-length value))))

(define (string-remove-at value index)
  (if (or (< index 0) (>= index (string-length value)))
      value
      (string-append (substring value 0 index)
                     (substring value (+ index 1) (string-length value)))))

(define (ensure-trailing-slash path)
  (if (and (string? path) (not (ends-with? path "/")))
      (string-append path "/")
      path))

(define (popup-clamp value lower upper)
  (max lower (min upper value)))

(define (popup-directory-folded? state directory)
  (define directories-box (FileTreePopupState-directories state))
  (define directories (unbox directories-box))
  (if (hash-contains? directories directory)
      (hash-try-get directories directory)
      (begin
        (set-box! directories-box (hash-insert directories directory #t))
        #t)))

(define (popup-format-dir state directory)
  (if (popup-directory-folded? state directory)
      ">  "
      "v  "))

(define (hidden-directory-name? name)
  (and (string? name)
       (> (string-length name) 0)
       (equal? (substring name 0 1) ".")
       (not (equal? name "."))
       (not (equal? name ".."))))

(define (popup-concat-map func lst)
  (if (null? lst)
      '()
      (append (func (car lst))
              (popup-concat-map func (cdr lst)))))

(define (popup-tree state root)
  (define (tree-rec path padding)
    (define name (file-name path))

    (if (or (hashset-contains? *ignore-set* name)
            (and (is-dir? path)
                 (not (unbox (FileTreePopupState-show-hidden-directories state)))
                 (hidden-directory-name? name)))
        '()
        (cond
          [(is-file? path)
           (list (popup-entry path #f (string-append padding (path->symbol path) name)))]
          [(is-dir? path)
           (define folded? (popup-directory-folded? state path))
           (define entry (popup-entry path #t (string-append padding (popup-format-dir state path) name)))
           (if folded?
               (list entry)
               (cons entry
                     (popup-concat-map
                      (fn (x) (tree-rec x (string-append padding "    ")))
                      (merge-sort (read-dir path) #:comparator path-sort<?))))]
          [else '()])))

  (if (is-dir? root)
      (popup-concat-map
       (fn (x) (tree-rec x ""))
       (merge-sort (read-dir root) #:comparator path-sort<?))
      (tree-rec root "")))

(define (popup-list-index-of-path entries path)
  (if (not (string? path))
      #f
      (let ([target (path-clean path)])
        (define (loop idx rest)
          (cond
            [(null? rest) #f]
            [(path=? (popup-entry-path (car rest)) target) idx]
            [else (loop (+ idx 1) (cdr rest))]))
        (loop 0 entries))))

(define (popup-ensure-window! state)
  (define entries (unbox (FileTreePopupState-entries state)))
  (define count (length entries))
  (define cursor-box (FileTreePopupState-cursor state))
  (define window-start-box (FileTreePopupState-window-start state))

  (if (= count 0)
      (begin
        (set-box! cursor-box 0)
        (set-box! window-start-box 0))
      (begin
        (define visible (max 1 (unbox (FileTreePopupState-max-length state))))
        (set-box! cursor-box (popup-clamp (unbox cursor-box) 0 (- count 1)))

        (define max-window-start (max 0 (- count visible)))
        (set-box! window-start-box (popup-clamp (unbox window-start-box) 0 max-window-start))

        (when (< (unbox cursor-box) (unbox window-start-box))
          (set-box! window-start-box (unbox cursor-box)))

        (when (> (unbox cursor-box) (+ (unbox window-start-box) (- visible 1)))
          (set-box! window-start-box
                    (popup-clamp (- (unbox cursor-box) (- visible 1))
                                 0
                                 max-window-start))))))

(define (popup-center-cursor-window! state)
  (define entries (unbox (FileTreePopupState-entries state)))
  (define count (length entries))
  (when (> count 0)
    (define visible (max 1 (unbox (FileTreePopupState-max-length state))))
    (define cursor (unbox (FileTreePopupState-cursor state)))
    (define max-window-start (max 0 (- count visible)))
    (define half-visible (quotient visible 2))
    (set-box! (FileTreePopupState-window-start state)
              (popup-clamp (- cursor half-visible) 0 max-window-start))))

(define (popup-refresh! state focus-path)
  (define root (FileTreePopupState-root state))
  (define raw-entries
    (if (and (string? root) (path-exists? root))
        (popup-tree state root)
        '()))

  (define entries (filter popup-valid-entry? raw-entries))

  (set-box! (FileTreePopupState-entries state) entries)

  (if (null? entries)
      (begin
        (set-box! (FileTreePopupState-cursor state) 0)
        (set-box! (FileTreePopupState-window-start state) 0))
      (begin
        (define idx (popup-list-index-of-path entries focus-path))
        (when idx
          (set-box! (FileTreePopupState-cursor state) idx))
        (popup-ensure-window! state))))

(define (popup-move-cursor-wrap! state delta)
  (define entries (unbox (FileTreePopupState-entries state)))
  (define count (length entries))
  (when (> count 0)
    (define cursor-box (FileTreePopupState-cursor state))
    (set-box! cursor-box (modulo (+ (unbox cursor-box) delta count) count))
    (popup-ensure-window! state)))

(define (popup-move-cursor-clamped! state delta)
  (define entries (unbox (FileTreePopupState-entries state)))
  (define count (length entries))
  (when (> count 0)
    (define cursor-box (FileTreePopupState-cursor state))
    (set-box! cursor-box (popup-clamp (+ (unbox cursor-box) delta) 0 (- count 1)))
    (popup-ensure-window! state)))

(define (popup-quarter-page-size state)
  (max 1 (quotient (max 1 (unbox (FileTreePopupState-max-length state))) 4)))

(define (popup-current-entry state)
  (define entries (unbox (FileTreePopupState-entries state)))
  (define idx (unbox (FileTreePopupState-cursor state)))
  (if (and (>= idx 0) (< idx (length entries)))
      (list-ref entries idx)
      #f))

(define (popup-set-directory-folded! state directory folded?)
  (define directories-box (FileTreePopupState-directories state))
  (set-box! directories-box (hash-insert (unbox directories-box) directory folded?)))

(define (popup-toggle-directory! state directory)
  (define directories (unbox (FileTreePopupState-directories state)))
  (define folded?
    (if (hash-contains? directories directory)
        (hash-try-get directories directory)
        #t))
  (popup-set-directory-folded! state directory (not folded?)))

(define (popup-unfold-path-to-target directories root target)
  (if (and (string? root) (string? target))
      (let* ([root-path (path-clean root)]
             [target-path (path-clean target)]
             [start (file-directory target-path)])
        (define (loop path acc)
          (if (and (string? path) (not (equal? path "")))
              (let ([next (hash-insert acc path #f)])
                (if (path=? path root-path)
                    next
                    (let ([parent (path-parent path)])
                      (if (path=? parent path)
                          next
                          (loop parent next)))))
              acc))
        (loop start directories))
      directories))

(define (popup-refresh-when state target predicate focus-path)
  (define max-attempts 40)
  (define (loop attempts)
    (if (or (<= attempts 0) (predicate target))
        (popup-refresh! state focus-path)
        (enqueue-thread-local-callback-with-delay
         50
         (lambda ()
           (loop (- attempts 1))))))
  (loop max-attempts))

(define (popup-selected-base-path state)
  (define entry (popup-current-entry state))
  (define root (FileTreePopupState-root state))
  (cond
    [(and entry (popup-entry-directory? entry)) (popup-entry-path entry)]
    [(and entry (string? (popup-entry-path entry))) (file-directory (popup-entry-path entry))]
    [else root]))

(define (popup-open-selection! state)
  (define entry (popup-current-entry state))
  (if (not entry)
      event-result/consume
      (let ([target (popup-entry-path entry)])
        (helix.open target)
        event-result/close)))

(define (popup-enter-directory! state)
  (define entry (popup-current-entry state))
  (if (and entry (popup-entry-directory? entry))
      (let ([target (popup-entry-path entry)])
        (when (popup-directory-folded? state target)
          (popup-set-directory-folded! state target #f))
        (popup-refresh! state target)
        event-result/consume)
      event-result/consume))

(define (popup-go-parent! state)
  (define entry (popup-current-entry state))
  (if (not entry)
      event-result/consume
      (let* ([target (popup-entry-path entry)]
             [directory? (popup-entry-directory? entry)])
        (if (and directory? (not (popup-directory-folded? state target)))
            (begin
              (popup-set-directory-folded! state target #t)
              (popup-refresh! state target)
              event-result/consume)
            (let ([parent (if directory? (path-parent target) (file-directory target))])
              (if (and (string? parent) (not (path=? parent target)))
                  (begin
                    (popup-refresh! state parent)
                    event-result/consume)
                  event-result/consume))))))

(define (popup-search-selected-directory! state)
  (define entry (popup-current-entry state))
  (if (and entry (popup-entry-directory? entry))
      (begin
        (helix.search-in-directory (popup-entry-path entry))
        event-result/close)
      event-result/consume))

(define (popup-toggle-hidden-directories! state)
  (define current-entry (popup-current-entry state))
  (define focus-path (if current-entry (popup-entry-path current-entry) #f))
  (define show-hidden-box (FileTreePopupState-show-hidden-directories state))
  (set-box! show-hidden-box (not (unbox show-hidden-box)))
  (popup-refresh! state focus-path)
  event-result/consume)

(define (popup-delete-confirm-open? state)
  (string? (unbox (FileTreePopupState-delete-confirm-path state))))

(define (popup-open-delete-confirm! state)
  (define entry (popup-current-entry state))
  (when entry
    (set-box! (FileTreePopupState-delete-confirm-path state) (popup-entry-path entry)))
  event-result/consume)

(define (popup-close-delete-confirm! state)
  (set-box! (FileTreePopupState-delete-confirm-path state) #f)
  event-result/consume)

(define (popup-confirm-delete! state)
  (define target (unbox (FileTreePopupState-delete-confirm-path state)))
  (popup-close-delete-confirm! state)
  (when (and (string? target) (not (equal? target "")))
    (define fallback-focus (path-parent target))
    (define quoted (string-append "\"" (shell-escape target) "\""))
    (if (is-dir? target)
        (helix.run-shell-command (string-append "rm -rf -- " quoted))
        (helix.run-shell-command (string-append "rm -f -- " quoted)))
    (set-box! (FileTreePopupState-directories state)
              (popup-unfold-path-to-target
               (unbox (FileTreePopupState-directories state))
               (FileTreePopupState-root state)
               fallback-focus))
    (popup-refresh-when state target (lambda (path) (not (path-exists? path))) fallback-focus))
  event-result/consume)

(define (popup-delete-confirm-event-handler state event)
  (define char (key-event-char event))
  (cond
    [(key-event-escape? event)
     (popup-close-delete-confirm! state)]

    [(and (char? char)
          (or (equal? char #\n)
              (equal? char #\N)))
     (popup-close-delete-confirm! state)]

    [(key-event-enter? event)
     (popup-confirm-delete! state)]

    [(and (char? char)
          (or (equal? char #\y)
              (equal? char #\Y)))
     (popup-confirm-delete! state)]

    [else event-result/consume-without-rerender]))

(define (popup-delete-confirm-render state popup-area popup-style border-style row-style frame)
  (define target (unbox (FileTreePopupState-delete-confirm-path state)))
  (when (string? target)
    (define popup-width (area-width popup-area))
    (define popup-height (area-height popup-area))
    (define modal-width (max 40 (min (- popup-width 4) 96)))
    (define modal-height 7)
    (define modal-x (+ (area-x popup-area) (max 0 (exact (round (/ (- popup-width modal-width) 2))))))
    (define modal-y (+ (area-y popup-area) (max 0 (exact (round (/ (- popup-height modal-height) 2))))))
    (define modal-area (area modal-x modal-y modal-width modal-height))
    (define inner-width (max 1 (- modal-width 2)))
    (define title-text (popup-truncate "delete file" inner-width))
    (define target-name (file-name target))
    (define target-text
      (popup-truncate
       (if (and (string? target-name) (not (equal? target-name "")))
           target-name
           target)
       inner-width))
    (define footer-yes "[Y]es")
    (define footer-no "[N]o")
    (define footer-gap " ")
    (define footer-text (popup-truncate (string-append footer-yes footer-gap footer-no) inner-width))
    (define blank-line (make-string inner-width #\space))
    (define yes-style (style-fg row-style Color/Green))
    (define no-style (style-fg row-style Color/Red))
    (define (centered-col text)
      (+ modal-x 1 (max 0 (exact (round (/ (- inner-width (string-length text)) 2))))))

    (buffer/clear-with frame modal-area popup-style)
    (block/render frame modal-area (make-block popup-style border-style "all" "rounded"))
    (frame-set-string! frame (+ modal-x 1) (+ modal-y 1) blank-line popup-style)
    (frame-set-string! frame (centered-col title-text) (+ modal-y 1) title-text row-style)
    (frame-set-string! frame (+ modal-x 1) (+ modal-y 3) blank-line popup-style)
    (frame-set-string! frame (+ modal-x 1) (+ modal-y 3) target-text row-style)
    (frame-set-string! frame (+ modal-x 1) (+ modal-y 5) blank-line popup-style)
    (define footer-x (centered-col footer-text))
    (frame-set-string! frame footer-x (+ modal-y 5) footer-yes yes-style)
    (frame-set-string! frame (+ footer-x (string-length footer-yes)) (+ modal-y 5) footer-gap row-style)
    (frame-set-string! frame
                       (+ footer-x (string-length footer-yes) (string-length footer-gap))
                       (+ modal-y 5)
                       footer-no
                       no-style)))

(define (popup-open-input-modal! state kind title prefix initial-input source-path)
  (define input-value (if (string? initial-input) initial-input ""))
  (set-box! (FileTreePopupState-delete-confirm-path state) #f)

  (push-component!
   (new-component! "file-tree-input-modal"
                   (FileTreeInputModalState state
                                            kind
                                            title
                                            prefix
                                            (box input-value)
                                            (box (string-length input-value))
                                            source-path)
                   file-tree-input-modal-render
                   (hash "handle_event" file-tree-input-modal-event-handler)))

  event-result/consume)

(define (popup-input-modal-action-label modal)
  (if (equal? (FileTreeInputModalState-kind modal) 'rename)
      "rename"
      "create"))

(define (popup-open-create-input! state)
  (define base-path (popup-selected-base-path state))
  (popup-open-input-modal! state 'create "create path" (ensure-trailing-slash base-path) "" #f))

(define (popup-open-rename-input! state)
  (define entry (popup-current-entry state))
  (if entry
      (let* ([source (popup-entry-path entry)]
             [source-name (file-name source)]
             [source-parent (path-parent source)]
             [prefix (ensure-trailing-slash source-parent)])
        (popup-open-input-modal! state 'rename "rename path" prefix source-name source))
      event-result/consume))

(define (popup-submit-create-input! state modal)
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

      (set-box! (FileTreePopupState-directories state)
                (popup-unfold-path-to-target
                 (unbox (FileTreePopupState-directories state))
                 (FileTreePopupState-root state)
                 target-path))
      (popup-refresh-when state target-path path-exists? target-path))))

(define (popup-submit-rename-input! state modal)
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
      (set-box! (FileTreePopupState-directories state)
                (popup-unfold-path-to-target
                 (unbox (FileTreePopupState-directories state))
                 (FileTreePopupState-root state)
                 destination))
      (popup-refresh-when state
                          destination
                          (lambda (path)
                            (and (path-exists? path)
                                 (not (path-exists? source))))
                          destination))))

(define (popup-submit-input-modal! modal)
  (define state (FileTreeInputModalState-tree-state modal))
  (if (equal? (FileTreeInputModalState-kind modal) 'rename)
      (popup-submit-rename-input! state modal)
      (popup-submit-create-input! state modal)))

(define (popup-input-modal-cursor-clamped modal)
  (popup-clamp (unbox (FileTreeInputModalState-cursor modal))
               0
               (string-length (unbox (FileTreeInputModalState-input modal)))))

(define (popup-input-modal-backspace! modal)
  (define cursor-box (FileTreeInputModalState-cursor modal))
  (define input-box (FileTreeInputModalState-input modal))
  (define input (unbox input-box))
  (define cursor (popup-input-modal-cursor-clamped modal))
  (set-box! cursor-box cursor)
  (when (> cursor 0)
    (set-box! input-box (string-remove-at input (- cursor 1)))
    (set-box! cursor-box (- cursor 1))))

(define (popup-input-modal-delete-forward! modal)
  (define cursor-box (FileTreeInputModalState-cursor modal))
  (define input-box (FileTreeInputModalState-input modal))
  (define input (unbox input-box))
  (define cursor (popup-input-modal-cursor-clamped modal))
  (set-box! cursor-box cursor)
  (when (< cursor (string-length input))
    (set-box! input-box (string-remove-at input cursor))))

(define (popup-input-modal-append-char! modal ch)
  (define cursor-box (FileTreeInputModalState-cursor modal))
  (define input-box (FileTreeInputModalState-input modal))
  (define input (unbox input-box))
  (define cursor (popup-input-modal-cursor-clamped modal))
  (set-box! cursor-box cursor)
  (set-box! input-box (string-insert-at input cursor (string ch)))
  (set-box! cursor-box (+ cursor 1)))

(define (popup-input-modal-move-cursor! modal delta)
  (define cursor-box (FileTreeInputModalState-cursor modal))
  (define cursor (popup-input-modal-cursor-clamped modal))
  (define max-cursor (string-length (unbox (FileTreeInputModalState-input modal))))
  (set-box! cursor-box (popup-clamp (+ cursor delta) 0 max-cursor)))

(define (popup-input-modal-move-home! modal)
  (set-box! (FileTreeInputModalState-cursor modal) 0))

(define (popup-input-modal-move-end! modal)
  (set-box! (FileTreeInputModalState-cursor modal)
            (string-length (unbox (FileTreeInputModalState-input modal)))))

(define (popup-input-modal-visible-state modal max-width)
  (if (<= max-width 0)
      (list "" 0)
      (let* ([input (unbox (FileTreeInputModalState-input modal))]
             [cursor (popup-input-modal-cursor-clamped modal)]
             [text-room (max 0 (- max-width 1))]
             [max-start (max 0 (- (string-length input) text-room))]
             [window-start (popup-clamp (- cursor (quotient text-room 2)) 0 max-start)]
             [window-end (min (string-length input) (+ window-start text-room))]
             [visible-text (substring input window-start window-end)]
             [cursor-col (popup-clamp (- cursor window-start)
                                      0
                                      (string-length visible-text))])
        (list visible-text cursor-col))))

(define (file-tree-input-modal-event-handler modal event)
  (define char (key-event-char event))
  (define modifier (key-event-modifier event))
  (cond
    [(key-event-escape? event)
     event-result/close]

    [(key-event-enter? event)
     (popup-submit-input-modal! modal)
     event-result/close]

    [(key-event-backspace? event)
     (popup-input-modal-backspace! modal)
     event-result/consume]

    [(key-event-delete? event)
     (popup-input-modal-delete-forward! modal)
     event-result/consume]

    [(key-event-left? event)
     (popup-input-modal-move-cursor! modal -1)
     event-result/consume]

    [(key-event-right? event)
     (popup-input-modal-move-cursor! modal 1)
     event-result/consume]

    [(key-event-home? event)
     (popup-input-modal-move-home! modal)
     event-result/consume]

    [(key-event-end? event)
     (popup-input-modal-move-end! modal)
     event-result/consume]

    [(and (char? char)
          (not (equal? modifier key-modifier-ctrl))
          (not (equal? modifier key-modifier-alt))
          (not (equal? modifier key-modifier-super)))
     (popup-input-modal-append-char! modal char)
     event-result/consume]

    [else event-result/consume-without-rerender]))

(define (file-tree-input-modal-render modal rect frame)
  (define width (area-width rect))
  (define height (area-height rect))
  (define modal-width (max 48 (min (- width 8) 112)))
  (define modal-height 7)
  (define modal-x (+ (area-x rect) (max 0 (exact (round (/ (- width modal-width) 2))))))
  (define modal-y (+ (area-y rect) (max 0 (exact (round (/ (- height modal-height) 2))))))
  (define modal-area (area modal-x modal-y modal-width modal-height))
  (define inner-width (max 1 (- modal-width 2)))
  (define row-style (theme-scope "ui.text"))
  (define border-style row-style)
  (define popup-style (style))
  (define title-text (popup-truncate (FileTreeInputModalState-title modal) inner-width))
  (define action (popup-input-modal-action-label modal))
  (define footer-text (popup-truncate (string-append "[Enter] " action " [Esc] cancel") inner-width))
  (define blank-line (make-string inner-width #\space))
  (define input-state (popup-input-modal-visible-state modal inner-width))
  (define input-content (list-ref input-state 0))
  (define cursor-col (list-ref input-state 1))
  (define cursor-style (style-with-reversed row-style))
  (define cursor-glyph
    (if (< cursor-col (string-length input-content))
        (substring input-content cursor-col (+ cursor-col 1))
        " "))
  (define (centered-col text)
    (+ modal-x 1 (max 0 (exact (round (/ (- inner-width (string-length text)) 2))))))

  (buffer/clear-with frame modal-area popup-style)
  (block/render frame modal-area (make-block popup-style border-style "all" "rounded"))
  (frame-set-string! frame (+ modal-x 1) (+ modal-y 1) blank-line popup-style)
  (frame-set-string! frame (centered-col title-text) (+ modal-y 1) title-text row-style)
  (frame-set-string! frame (+ modal-x 1) (+ modal-y 3) blank-line popup-style)
  (define input-x (centered-col input-content))
  (frame-set-string! frame input-x (+ modal-y 3) input-content row-style)
  (frame-set-string! frame (+ input-x cursor-col) (+ modal-y 3) cursor-glyph cursor-style)
  (frame-set-string! frame (+ modal-x 1) (+ modal-y 5) blank-line popup-style)
  (frame-set-string! frame (centered-col footer-text) (+ modal-y 5) footer-text row-style))

(define (popup-fold-all! state)
  (set-box! (FileTreePopupState-directories state)
            (transduce (unbox (FileTreePopupState-directories state))
                       (mapping (lambda (x) (list (list-ref x 0) #t)))
                       (into-hashmap)))
  (popup-refresh! state #f)
  event-result/consume)

(define (popup-unfold-all-one-level! state)
  (set-box! (FileTreePopupState-directories state)
            (transduce (unbox (FileTreePopupState-directories state))
                       (mapping (lambda (x) (list (list-ref x 0) #f)))
                       (into-hashmap)))
  (popup-refresh! state #f)
  event-result/consume)

(define (file-tree-popup-event-handler state event)
  (define char (key-event-char event))
  (define modifier (key-event-modifier event))

  (cond
    [(popup-delete-confirm-open? state)
     (popup-delete-confirm-event-handler state event)]

    [(key-event-escape? event) event-result/close]
    [(and (char? char) (equal? char #\q)) event-result/close]

    [(key-event-down? event)
     (popup-move-cursor-clamped! state 1)
     event-result/consume]

    [(key-event-up? event)
     (popup-move-cursor-clamped! state -1)
     event-result/consume]

    [(and (char? char) (equal? char #\j))
     (popup-move-cursor-wrap! state 1)
     event-result/consume]

    [(and (char? char) (equal? char #\k))
     (popup-move-cursor-wrap! state -1)
     event-result/consume]

    [(key-event-page-down? event)
     (popup-move-cursor-clamped! state (popup-quarter-page-size state))
     event-result/consume]

    [(key-event-page-up? event)
     (popup-move-cursor-clamped! state (- (popup-quarter-page-size state)))
     event-result/consume]

    [(and (char? char)
          (equal? modifier key-modifier-ctrl)
          (equal? char #\d))
     (popup-move-cursor-clamped! state (popup-quarter-page-size state))
     event-result/consume]

    [(and (char? char)
          (equal? modifier key-modifier-ctrl)
          (equal? char #\u))
     (popup-move-cursor-clamped! state (- (popup-quarter-page-size state)))
     event-result/consume]

    [(and (char? char) (equal? char #\h))
     (popup-go-parent! state)]

    [(and (char? char) (equal? char #\l))
     (popup-enter-directory! state)]

    [(key-event-left? event)
     (popup-go-parent! state)]

    [(key-event-right? event)
     (popup-enter-directory! state)]

    [(key-event-tab? event)
     (if (equal? (key-event-modifier event) key-modifier-shift)
         (popup-move-cursor-clamped! state -1)
         (popup-move-cursor-clamped! state 1))
     event-result/consume]

    [(key-event-enter? event)
     (popup-open-selection! state)]

    [(and (char? char) (equal? char #\a))
     (popup-open-create-input! state)]

    [(and (char? char) (equal? char #\r))
     (popup-open-rename-input! state)]

    [(and (char? char) (equal? char #\d))
     (popup-open-delete-confirm! state)]

    [(and (char? char) (equal? char #\s))
     (popup-search-selected-directory! state)]

    [(and (char? char) (equal? char #\.))
     (popup-toggle-hidden-directories! state)]

    [(and (char? char) (equal? char #\F))
     (popup-fold-all! state)]

    [(and (char? char) (equal? char #\E))
     (popup-unfold-all-one-level! state)]

    [else event-result/consume-without-rerender]))

(define (file-tree-popup-render state rect frame)
  (define width (area-width rect))
  (define height (area-height rect))

  (define popup-width (max 56 (min 120 (- width 6))))
  (define popup-height-target (exact (round (/ (* height 2) 3))))
  (define popup-height (popup-clamp popup-height-target 8 (max 8 (- height 2))))

  (define x (max 0 (exact (round (/ (- width popup-width) 2)))))
  (define y (max 0 (exact (round (/ (- height popup-height) 2)))))

  (define popup-area (area x y popup-width popup-height))
  (define content-x (+ x 2))
  (define content-y (+ y 1))
  (define content-width (max 1 (- popup-width 4)))

  (define visible-count (max 1 (- popup-height 2)))
  (when (not (= (unbox (FileTreePopupState-max-length state)) visible-count))
    (set-box! (FileTreePopupState-max-length state) visible-count)
    (popup-ensure-window! state))

  (when (unbox (FileTreePopupState-center-next-render state))
    (popup-center-cursor-window! state)
    (set-box! (FileTreePopupState-center-next-render state) #f)
    (popup-ensure-window! state))

  (define row-style (theme-scope "ui.text"))
  (define border-style row-style)
  (define selected-style (style-with-bold (theme-scope "ui.menu.selected")))
  (define popup-style (style))

  (buffer/clear-with frame popup-area popup-style)
  (block/render frame popup-area (make-block popup-style border-style "all" "rounded"))

  (define entries (unbox (FileTreePopupState-entries state)))
  (define start (unbox (FileTreePopupState-window-start state)))
  (define cursor (unbox (FileTreePopupState-cursor state)))
  (define visible-entries (slice entries start visible-count))
  (define selected-index (- cursor start))
  (define blank-line (make-string content-width #\space))

  (if (null? entries)
      (frame-set-string! frame content-x content-y "(empty)" row-style)
        (popup-for-each-index
        (lambda (index entry)
          (define row (+ content-y index))
          (define selected? (= index selected-index))
          (define style (if selected? selected-style row-style))
          (define text (popup-truncate (popup-entry-display entry) content-width))
          (when selected?
            (frame-set-string! frame content-x row blank-line selected-style))
          (frame-set-string! frame content-x row text style))
        visible-entries
        0))

  (popup-delete-confirm-render state popup-area popup-style border-style row-style frame))

(define (create-file-tree-popup)
  (define target-path (current-doc-path))
  (define root (resolve-tree-root target-path))
  (define directories (popup-unfold-path-to-target (hash) root target-path))
  (define state
    (FileTreePopupState root
                        (box '())
                        (box directories)
                        (box 0)
                        (box 0)
                        (box 1)
                        (box #t)
                        (box #f)
                        (box #f)))

  (popup-refresh! state target-path)

  (push-component!
   (new-component! "file-tree-popup"
                   state
                   file-tree-popup-render
                   (hash "handle_event" file-tree-popup-event-handler))))

(define (create-file-tree)
  (create-file-tree-popup))
