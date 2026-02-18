(require (prefix-in helix. "helix/commands.scm"))
(require "helix/components.scm")
(require "../toast.scm")
(require "./core.scm")
(require "./delete.scm")
(require "./input.scm")
(require "./search.scm")

(provide file-tree-event-handler
         file-tree-render)

(define (starts-with? value prefix)
  (if (< (string-length value) (string-length prefix))
      #f
      (equal? (substring value 0 (string-length prefix)) prefix)))

(define (tree-for-each-index func lst index)
  (if (null? lst)
      void
      (begin
        (func index (car lst))
        (tree-for-each-index func (cdr lst) (+ index 1)))))

(define (tree-center-cursor-window! state)
  (define entries (unbox (FileTreeState-entries state)))
  (define count (length entries))
  (when (> count 0)
    (define visible (max 1 (unbox (FileTreeState-max-length state))))
    (define cursor (unbox (FileTreeState-cursor state)))
    (define max-window-start (max 0 (- count visible)))
    (define half-visible (quotient visible 2))
    (set-box! (FileTreeState-window-start state)
              (tree-clamp (- cursor half-visible) 0 max-window-start))))

(define (tree-move-cursor-wrap! state delta)
  (define entries (unbox (FileTreeState-entries state)))
  (define count (length entries))
  (when (> count 0)
    (define cursor-box (FileTreeState-cursor state))
    (set-box! cursor-box (modulo (+ (unbox cursor-box) delta count) count))
    (tree-ensure-window! state)))

(define (tree-move-cursor-clamped! state delta)
  (define entries (unbox (FileTreeState-entries state)))
  (define count (length entries))
  (when (> count 0)
    (define cursor-box (FileTreeState-cursor state))
    (set-box! cursor-box (tree-clamp (+ (unbox cursor-box) delta) 0 (- count 1)))
    (tree-ensure-window! state)))

(define (tree-quarter-page-size state)
  (max 1 (quotient (max 1 (unbox (FileTreeState-max-length state))) 4)))

(define (tree-set-directory-folded! state directory folded?)
  (define directories-box (FileTreeState-directories state))
  (set-box! directories-box (hash-insert (unbox directories-box) directory folded?)))

(define (tree-open-selection! state)
  (define entry (tree-current-entry state))
  (if (not entry)
      event-result/consume
      (let ([target (TreeEntry-path entry)])
        (helix.open target)
        event-result/close)))

(define (tree-enter-directory! state)
  (define entry (tree-current-entry state))
  (if (and entry (TreeEntry-directory entry))
      (let ([target (TreeEntry-path entry)])
        (when (tree-directory-folded? state target)
          (tree-set-directory-folded! state target #f))
        (tree-refresh! state target)
        event-result/consume)
      event-result/consume))

(define (tree-go-parent! state)
  (define entry (tree-current-entry state))
  (if (not entry)
      event-result/consume
      (let* ([target (TreeEntry-path entry)]
             [directory? (TreeEntry-directory entry)])
        (if (and directory? (not (tree-directory-folded? state target)))
            (begin
              (tree-set-directory-folded! state target #t)
              (tree-refresh! state target)
              event-result/consume)
            (let ([parent (if directory? (path-parent target) (file-directory target))])
              (if (and (string? parent) (not (path=? parent target)))
                  (begin
                    (tree-refresh! state parent)
                    event-result/consume)
                  event-result/consume))))))

(define (tree-search-selected-directory! state)
  (define entry (tree-current-entry state))
  (if (and entry (TreeEntry-directory entry))
      (begin
        (helix.search-in-directory (TreeEntry-path entry))
        event-result/close)
      event-result/consume))

(define (tree-toggle-hidden-directories! state)
  (define current-entry (tree-current-entry state))
  (define focus-path (if current-entry (TreeEntry-path current-entry) #f))
  (define show-hidden-box (FileTreeState-show-hidden-directories state))
  (set-box! show-hidden-box (not (unbox show-hidden-box)))
  (tree-refresh! state focus-path)
  event-result/consume)

(define (path-descendant-or-same? maybe-child maybe-parent)
  (if (and (string? maybe-child) (string? maybe-parent))
      (let ([child (path-clean maybe-child)]
            [parent (path-clean maybe-parent)])
        (or (path=? child parent)
            (starts-with? child (string-append parent "/"))))
      #f))

(define (tree-clear-transfer! state)
  (set-box! (FileTreeState-transfer-path state) #f)
  (set-box! (FileTreeState-transfer-kind state) #f))

(define (tree-transfer-active? state)
  (and (string? (unbox (FileTreeState-transfer-path state)))
       (symbol? (unbox (FileTreeState-transfer-kind state)))))

(define (tree-transfer-kind-for-entry state entry-path)
  (define transfer-path (unbox (FileTreeState-transfer-path state)))
  (define transfer-kind (unbox (FileTreeState-transfer-kind state)))
  (if (and (string? transfer-path)
           (symbol? transfer-kind)
           (path=? transfer-path entry-path))
      transfer-kind
      #f))

(define (tree-select-transfer! state transfer-kind)
  (define entry (tree-current-entry state))
  (when entry
    (set-box! (FileTreeState-transfer-path state) (TreeEntry-path entry))
    (set-box! (FileTreeState-transfer-kind state) transfer-kind))
  event-result/consume)

(define (tree-select-copy! state)
  (tree-select-transfer! state 'copy))

(define (tree-select-move! state)
  (tree-select-transfer! state 'move))

(define (tree-transfer-style-kind transfer-kind)
  (cond
    [(equal? transfer-kind 'move) 'move]
    [(equal? transfer-kind 'copy) 'copy]
    [else #f]))

(define (tree-transfer-styles row-style selected-style transfer-kind)
  (cond
    [(equal? transfer-kind 'move)
     (list (style-with-bold (style-fg row-style Color/LightCyan))
           (style-with-bold (style-fg selected-style Color/LightCyan)))]
    [(equal? transfer-kind 'copy)
     (list (style-with-bold (style-fg row-style Color/LightYellow))
           (style-with-bold (style-fg selected-style Color/LightYellow)))]
    [else (list row-style selected-style)]))

(define (tree-row-style row-style selected-style transfer-kind selected?)
  (define styles (tree-transfer-styles row-style selected-style (tree-transfer-style-kind transfer-kind)))
  (define non-selected-style (list-ref styles 0))
  (define selected-style* (list-ref styles 1))
  (if selected? selected-style* non-selected-style))

(define (tree-transfer-row? transfer-kind)
  (or (equal? transfer-kind 'copy)
      (equal? transfer-kind 'move)))

(define (tree-transfer-row-style row-style selected-style transfer-kind selected?)
  (if (tree-transfer-row? transfer-kind)
      (tree-row-style row-style selected-style transfer-kind selected?)
      (if selected? selected-style row-style)))

(define (tree-transfer-valid? source transfer-kind)
  (and (string? source)
       (symbol? transfer-kind)
       (path-exists? source)))

(define (tree-paste-destination-directory state)
  (define destination-base (tree-selected-base-path state))
  (cond
    [(and (string? destination-base) (is-dir? destination-base)) destination-base]
    [(string? destination-base) (file-directory destination-base)]
    [else (FileTreeState-root state)]))

(define (tree-run-transfer! transfer-kind source destination)
  (define quoted-source (string-append "\"" (shell-escape source) "\""))
  (define quoted-destination (string-append "\"" (shell-escape destination) "\""))
  (if (equal? transfer-kind 'move)
      (helix.run-shell-command (string-append "mv " quoted-source " " quoted-destination))
      (if (is-dir? source)
          (helix.run-shell-command (string-append "cp -R " quoted-source " " quoted-destination))
          (helix.run-shell-command (string-append "cp " quoted-source " " quoted-destination)))))

(define (tree-post-transfer-refresh! state transfer-kind source target-path)
  (set-box! (FileTreeState-directories state)
            (tree-unfold-path-to-target
             (unbox (FileTreeState-directories state))
             (FileTreeState-root state)
             target-path))

  (tree-clear-transfer! state)

  (if (equal? transfer-kind 'move)
      (tree-refresh-when state
                         source
                         (lambda (path)
                           (and (not (path-exists? path))
                                (path-exists? target-path)))
                         target-path)
      (tree-refresh-when state target-path path-exists? target-path)))

(define (tree-paste-transfer! state)
  (define source (unbox (FileTreeState-transfer-path state)))
  (define transfer-kind (unbox (FileTreeState-transfer-kind state)))

  (if (not (tree-transfer-valid? source transfer-kind))
      (begin
        (tree-clear-transfer! state)
        (toast-error "Transfer source is no longer available")
        event-result/consume)
      (let* ([source-clean (path-clean source)]
             [destination (tree-paste-destination-directory state)]
             [target-path (path-clean (string-append destination "/" (file-name source-clean)))])

        (cond
          [(not (and (string? destination) (is-dir? destination)))
           (toast-error "Invalid paste destination")
           event-result/consume]

          [(and (is-dir? source-clean)
                (path-descendant-or-same? destination source-clean))
           (toast-error "Cannot paste a directory into itself")
           event-result/consume]

          [(path-exists? target-path)
           (toast-error "Paste target already exists")
           event-result/consume]

          [(path=? target-path source-clean)
           event-result/consume]

          [else
           (tree-run-transfer! transfer-kind source-clean destination)
           (tree-post-transfer-refresh! state transfer-kind source-clean target-path)
           event-result/consume]))))

(define (tree-fold-all! state)
  (set-box! (FileTreeState-directories state)
            (transduce (unbox (FileTreeState-directories state))
                       (mapping (lambda (x) (list (list-ref x 0) #t)))
                       (into-hashmap)))
  (tree-refresh! state #f)
  event-result/consume)

(define (tree-unfold-all-one-level! state)
  (set-box! (FileTreeState-directories state)
            (transduce (unbox (FileTreeState-directories state))
                       (mapping (lambda (x) (list (list-ref x 0) #f)))
                       (into-hashmap)))
  (tree-refresh! state #f)
  event-result/consume)

(define (file-tree-event-handler state event)
  (define char (key-event-char event))
  (define modifier (key-event-modifier event))

  (cond
    [(key-event-escape? event)
     (if (tree-search-input-visible? state)
         (begin
           (tree-search-clear! state)
           (tree-clear-transfer! state)
           event-result/consume)
         (if (tree-transfer-active? state)
             (begin
               (tree-clear-transfer! state)
               event-result/consume)
             event-result/close))]

    [(and (char? char) (equal? char #\/))
     (tree-search-open! state)
     event-result/consume]

    [(tree-search-input-focused? state)
     (tree-search-input-event-handler state event)]

    [(and (char? char)
          (equal? char #\n)
          (tree-search-input-visible? state)
          (not (null? (unbox (FileTreeState-search-matches state)))) )
     (tree-search-jump-next! state)
     event-result/consume]

    [(and (char? char)
          (equal? char #\N)
          (tree-search-input-visible? state)
          (not (null? (unbox (FileTreeState-search-matches state)))) )
     (tree-search-jump-prev! state)
     event-result/consume]

    [(and (char? char) (equal? char #\q)) event-result/close]

    [(key-event-down? event)
     (tree-move-cursor-clamped! state 1)
     event-result/consume]

    [(key-event-up? event)
     (tree-move-cursor-clamped! state -1)
     event-result/consume]

    [(and (char? char) (equal? char #\j))
     (tree-move-cursor-wrap! state 1)
     event-result/consume]

    [(and (char? char) (equal? char #\k))
     (tree-move-cursor-wrap! state -1)
     event-result/consume]

    [(key-event-page-down? event)
     (tree-move-cursor-clamped! state (tree-quarter-page-size state))
     event-result/consume]

    [(key-event-page-up? event)
     (tree-move-cursor-clamped! state (- (tree-quarter-page-size state)))
     event-result/consume]

    [(and (char? char)
          (equal? modifier key-modifier-ctrl)
          (equal? char #\d))
     (tree-move-cursor-clamped! state (tree-quarter-page-size state))
     event-result/consume]

    [(and (char? char)
          (equal? modifier key-modifier-ctrl)
          (equal? char #\u))
     (tree-move-cursor-clamped! state (- (tree-quarter-page-size state)))
     event-result/consume]

    [(and (char? char) (equal? char #\h))
     (tree-go-parent! state)]

    [(and (char? char) (equal? char #\l))
     (tree-enter-directory! state)]

    [(key-event-left? event)
     (tree-go-parent! state)]

    [(key-event-right? event)
     (tree-enter-directory! state)]

    [(key-event-tab? event)
     (if (equal? (key-event-modifier event) key-modifier-shift)
         (tree-move-cursor-clamped! state -1)
         (tree-move-cursor-clamped! state 1))
     event-result/consume]

    [(key-event-enter? event)
     (tree-open-selection! state)]

    [(and (char? char) (equal? char #\a))
     (tree-open-create-input! state)]

    [(and (char? char) (equal? char #\r))
     (tree-open-rename-input! state)]

    [(and (char? char) (equal? char #\y))
     (tree-select-copy! state)]

    [(and (char? char) (equal? char #\x))
     (tree-select-move! state)]

    [(and (char? char) (equal? char #\p))
     (tree-paste-transfer! state)]

    [(and (char? char) (equal? char #\d))
     (tree-open-delete-confirm! state)]

    [(and (char? char) (equal? char #\s))
     (tree-search-selected-directory! state)]

    [(and (char? char) (equal? char #\.))
     (tree-toggle-hidden-directories! state)]

    [(and (char? char) (equal? char #\F))
     (tree-fold-all! state)]

    [(and (char? char) (equal? char #\E))
     (tree-unfold-all-one-level! state)]

    [else event-result/consume-without-rerender]))

(define (file-tree-render state rect frame)
  (define width (area-width rect))
  (define height (area-height rect))

  (define tree-width (max 56 (min 120 (- width 6))))
  (define tree-height-target (exact (round (/ (* height 2) 3))))
  (define tree-height (tree-clamp tree-height-target 8 (max 8 (- height 2))))

  (define x (max 0 (exact (round (/ (- width tree-width) 2)))))
  (define y (max 0 (exact (round (/ (- height tree-height) 2)))))

  (define tree-area (area x y tree-width tree-height))
  (define content-x (+ x 2))
  (define content-y (+ y 1))
  (define ribbon-y (+ y (- tree-height 2)))
  (define content-width (max 1 (- tree-width 4)))

  (define visible-count (max 1 (- tree-height 3)))
  (when (not (= (unbox (FileTreeState-max-length state)) visible-count))
    (set-box! (FileTreeState-max-length state) visible-count)
    (tree-ensure-window! state))

  (when (unbox (FileTreeState-center-next-render state))
    (tree-center-cursor-window! state)
    (set-box! (FileTreeState-center-next-render state) #f)
    (tree-ensure-window! state))

  (define row-style (theme-scope "ui.text"))
  (define border-style row-style)
  (define selected-style (theme-scope "ui.menu.selected"))
  (define match-style (theme-scope "ui.menu"))
  (define tree-style (style))
  (define copy-ribbon-style
    (style-with-bold (style-bg (style-fg row-style Color/Black) Color/LightYellow)))
  (define move-ribbon-style
    (style-with-bold (style-bg (style-fg row-style Color/Black) Color/LightCyan)))

  (buffer/clear-with frame tree-area tree-style)
  (block/render frame tree-area (make-block tree-style border-style "all" "rounded"))

  (define entries (unbox (FileTreeState-entries state)))
  (define start (unbox (FileTreeState-window-start state)))
  (define cursor (unbox (FileTreeState-cursor state)))
  (define visible-entries (slice entries start visible-count))
  (define selected-index (- cursor start))
  (define blank-line (make-string content-width #\space))
  (define content-start-y content-y)

  (if (null? entries)
      (frame-set-string! frame content-x content-start-y "(empty)" row-style)
      (tree-for-each-index
       (lambda (index entry)
         (define row (+ content-start-y index))
         (define selected? (= index selected-index))
         (define match? (tree-search-match-path? state (TreeEntry-path entry)))
         (define transfer-kind (tree-transfer-kind-for-entry state (TreeEntry-path entry)))
         (define row-style-base (tree-transfer-row-style row-style selected-style transfer-kind selected?))
         (define row-style*
           (if (and match? (not selected?))
               match-style
               row-style-base))
         (define text (tree-truncate (TreeEntry-display entry) content-width))
         (when (or selected? match?)
            (frame-set-string! frame content-x row blank-line row-style*))
         (frame-set-string! frame content-x row text row-style*))
       visible-entries
       0))

  (tree-search-render-overlay! state frame content-x content-y content-width row-style tree-style)

  (define transfer-kind
    (if (tree-transfer-active? state)
        (unbox (FileTreeState-transfer-kind state))
        #f))
  (define ribbon-text
    (cond
      [(equal? transfer-kind 'copy) " COPY "]
      [(equal? transfer-kind 'move) " MOVE "]
      [else #f]))
  (define ribbon-style
    (cond
      [(equal? transfer-kind 'copy) copy-ribbon-style]
      [(equal? transfer-kind 'move) move-ribbon-style]
      [else tree-style]))

  (frame-set-string! frame content-x ribbon-y blank-line tree-style)
  (when ribbon-text
    (define centered-text (tree-truncate ribbon-text content-width))
    (define ribbon-x
      (+ content-x
         (max 0 (exact (round (/ (- content-width (string-length centered-text)) 2))))))
    (frame-set-string! frame content-x ribbon-y blank-line ribbon-style)
    (frame-set-string! frame ribbon-x ribbon-y centered-text ribbon-style)))
