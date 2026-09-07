(require (prefix-in helix. "helix/commands.scm"))
(require "helix/components.scm")
(require "../toast.scm")
(require "./core.scm")
(require "./delete.scm")
(require "./input.scm")
(require "./search.scm")

(provide file-tree-event-handler
         file-tree-render)

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
    (tree-search-jump! state 1)
    event-result/consume]

   [(and (char? char)
         (equal? char #\N)
         (tree-search-input-visible? state)
         (not (null? (unbox (FileTreeState-search-matches state)))) )
    (tree-search-jump! state -1)
    event-result/consume]

   [(and (char? char) (equal? char #\q)) event-result/close]

   [(key-event-down? event)
    (tree-move-cursor! state 1)
    event-result/consume]

   [(key-event-up? event)
    (tree-move-cursor! state -1)
    event-result/consume]

   [(and (char? char) (equal? char #\j))
    (tree-move-cursor! state 1 #:wrap #t)
    event-result/consume]

   [(and (char? char) (equal? char #\k))
    (tree-move-cursor! state -1 #:wrap #t)
    event-result/consume]

   [(or (key-event-page-down? event)
        (and (equal? modifier key-modifier-ctrl) (equal? char #\d)))
    (tree-move-cursor! state (tree-quarter-page-size state))
    event-result/consume]

   [(or (key-event-page-up? event)
        (and (equal? modifier key-modifier-ctrl) (equal? char #\u)))
    (tree-move-cursor! state (- (tree-quarter-page-size state)))
    event-result/consume]

   [(or (equal? char #\h) (key-event-left? event))
    (tree-go-parent! state)]

   [(or (equal? char #\l) (key-event-right? event))
    (tree-open-or-enter-selection! state)]

   [(key-event-tab? event)
    (if (equal? (key-event-modifier event) key-modifier-shift)
        (tree-move-cursor! state -1)
        (tree-move-cursor! state 1))
    event-result/consume]

   [(key-event-enter? event)
    (tree-open-selection! state)]

   [(and (char? char) (equal? char #\a))
    (tree-open-create-input! state)]

   [(and (char? char) (equal? char #\r))
    (tree-open-rename-input! state)]

   [(and (char? char) (equal? char #\y))
    (tree-select-transfer! state 'copy)]

   [(and (char? char) (equal? char #\x))
    (tree-select-transfer! state 'move)]

   [(and (char? char) (equal? char #\p))
    (tree-paste-transfer! state)]

   [(and (char? char) (equal? char #\d))
    (tree-open-delete-confirm! state)]

   [(and (char? char) (equal? char #\s))
    (tree-search-selected-directory! state)]

   [(and (char? char) (equal? char #\.))
    (define current-entry (tree-current-entry state))
    (define focus-path (if current-entry (TreeEntry-path current-entry) #f))
    (define flag (FileTreeState-show-all state))
    (set-box! flag (not (unbox flag)))
    (tree-refresh! state focus-path)
    event-result/consume]

   [(and (char? char) (equal? char #\F))
    (tree-set-all-folded! state #t)]

   [(and (char? char) (equal? char #\E))
    (tree-set-all-folded! state #f)]

   [else event-result/consume-without-rerender]))

(define (file-tree-render state rect frame)
  (define tree-area (tree-popup-area rect))
  (define tree-width (area-width tree-area))
  (define tree-height (area-height tree-area))
  (define x (area-x tree-area))
  (define y (area-y tree-area))
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
      (let loop ([rest visible-entries] [index 0])
       (unless (null? rest)
         (define entry (car rest))
         (define row (+ content-start-y index))
         (define selected? (= index selected-index))
         (define match? (tree-search-match-path? state (TreeEntry-path entry)))
         (define transfer-kind (tree-transfer-kind-for-entry state (TreeEntry-path entry)))
         (define row-style-base (if selected? selected-style row-style))
         (define row-style*
           (cond
            [(and match? (not selected?)) match-style]
            [(equal? transfer-kind 'move) (style-with-bold (style-fg row-style-base Color/LightCyan))]
            [(equal? transfer-kind 'copy) (style-with-bold (style-fg row-style-base Color/LightYellow))]
            [else row-style-base]))
         (define text (tree-truncate (TreeEntry-display entry) content-width))
         (when (or selected? match?)
           (frame-set-string! frame content-x row blank-line row-style*))
         (frame-set-string! frame content-x row text row-style*)
         (loop (cdr rest) (+ index 1)))))

  (tree-search-render-overlay! state frame content-x content-y content-width row-style tree-style)

  (define transfer-kind
    (if (tree-transfer-active? state)
        (unbox (FileTreeState-transfer-kind state))
        #f))
  (define ribbon-text
    (cond
     [(equal? transfer-kind 'copy) " COPY "]
     [(equal? transfer-kind 'move) " MOVE "]
     [(not (unbox (FileTreeState-show-all state))) " FILTERED "]
     [else #f]))
  (define ribbon-style
    (cond
     [(equal? transfer-kind 'copy) copy-ribbon-style]
     [(equal? transfer-kind 'move) move-ribbon-style]
     [else tree-style]))

  (frame-set-string! frame content-x ribbon-y blank-line tree-style)
  (when ribbon-text
    (define centered-text (tree-truncate ribbon-text content-width))
    (define ribbon-x (tree-center-x content-x content-width (string-length centered-text)))
    (frame-set-string! frame content-x ribbon-y blank-line ribbon-style)
    (frame-set-string! frame ribbon-x ribbon-y centered-text ribbon-style)))

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

(define (tree-move-cursor! state delta #:wrap [wrap? #f])
  (define entries (unbox (FileTreeState-entries state)))
  (define count (length entries))
  (when (> count 0)
    (define cursor-box (FileTreeState-cursor state))
    (define next (+ (unbox cursor-box) delta))
    (set-box! cursor-box
              (if wrap? (modulo (+ next count) count) (tree-clamp next 0 (- count 1))))
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

(define (tree-open-or-enter-selection! state)
  (define entry (tree-current-entry state))
  (cond
   [(not entry) event-result/consume]
   [(TreeEntry-directory entry)
    (let ([target (TreeEntry-path entry)])
      (when (tree-directory-folded? state target)
        (tree-set-directory-folded! state target #f))
      (tree-refresh! state target)
      event-result/consume)]
   [else
    (helix.open (TreeEntry-path entry))
    event-result/close]))

(define (tree-reroot-to-parent! state focus-path)
  (define root-box (FileTreeState-root state))
  (define root (unbox root-box))
  (define parent-root (path-parent root))
  (define directories-box (FileTreeState-directories state))
  (if (and (string? parent-root)
           (not (path=? parent-root root)))
      (begin
        (set-box! root-box parent-root)
        (set-box! directories-box
                  (tree-unfold-path-to-target
                   (unbox directories-box)
                   parent-root
                   focus-path))
        (tree-refresh! state focus-path)
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
            (let* ([parent (if directory? (path-parent target) (file-directory target))]
                   [root (unbox (FileTreeState-root state))])
              (cond
               [(or (not (string? parent)) (path=? parent target)) event-result/consume]
               [(path=? parent root)
                (tree-reroot-to-parent! state target)]
               [else
                (tree-refresh! state parent)
                event-result/consume]))))))

(define (tree-search-selected-directory! state)
  (define entry (tree-current-entry state))
  (if (and entry (TreeEntry-directory entry))
      (begin
        (helix.search-in-directory (TreeEntry-path entry))
        event-result/close)
      event-result/consume))

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

(define (tree-transfer-valid? source transfer-kind)
  (and (string? source)
       (symbol? transfer-kind)
       (path-exists? source)))

(define (tree-paste-destination-directory state)
  (define destination-base (tree-selected-base-path state))
  (cond
   [(and (string? destination-base) (is-dir? destination-base)) destination-base]
   [(string? destination-base) (file-directory destination-base)]
   [else (unbox (FileTreeState-root state))]))

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
             (unbox (FileTreeState-root state))
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

(define (tree-set-all-folded! state folded?)
  (set-box! (FileTreeState-directories state)
            (transduce (unbox (FileTreeState-directories state))
                       (mapping (lambda (x) (list (list-ref x 0) folded?)))
                       (into-hashmap)))
  (tree-refresh! state #f)
  event-result/consume)
