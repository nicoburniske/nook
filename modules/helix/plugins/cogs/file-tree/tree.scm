(require (prefix-in helix. "helix/commands.scm"))
(require "helix/components.scm")
(require "helix/ext.scm")
(require "steel/result")
(require-builtin steel/process)
(require "../toast.scm")
(require "./core.scm")
(require "./delete.scm")
(require "./input.scm")
(require "./search.scm")

(provide file-tree-event-handler
         file-tree-render)

(define *sort-labels*
  (hash #\n " NATURAL ↑ " #\N " NATURAL ↓ " #\m " TIME ↑ " #\M " TIME ↓ "))

(define (file-tree-event-handler state event)
  (define char (key-event-char event))
  (define modifier (key-event-modifier event))

  (cond
   [(unbox (FileTreeState-sort-pending state))
    (set-box! (FileTreeState-sort-pending state) #f)
    (when (member char '(#\n #\N #\m #\M))
      (define entry (tree-current-entry state))
      (set-box! (FileTreeState-sort-key state) char)
      (tree-refresh! state (if entry (TreeEntry-path entry) #f))
      (define matches (unbox (FileTreeState-search-matches state)))
      (define active (unbox (FileTreeState-search-active-index state)))
      (define active-path (if (and (>= active 0) (< active (length matches)))
                              (list-ref matches active)
                              #f))
      (define matching-entries
        (filter (lambda (entry) (member (TreeEntry-path entry) matches))
                (unbox (FileTreeState-entries state))))
      (set-box! (FileTreeState-search-matches state) (map TreeEntry-path matching-entries))
      (set-box! (FileTreeState-search-active-index state)
                (or (tree-list-index-of-path matching-entries active-path) -1)))
    event-result/consume]

   [(key-event-escape? event)
    (cond
     [(tree-search-input-visible? state)
      (tree-search-clear! state)
      event-result/consume]
     [(not (null? (unbox (FileTreeState-selected-paths state))))
      (set-box! (FileTreeState-selected-paths state) '())
      event-result/consume]
     [(tree-transfer-active? state)
      (tree-clear-transfer! state)
      event-result/consume]
     [else event-result/close])]

   [(and (char? char) (equal? char #\/))
    (tree-search-open! state)
    event-result/consume]

   [(tree-search-input-focused? state)
    (tree-search-input-event-handler state event)]

   [(and (char? char) (equal? char #\,))
    (set-box! (FileTreeState-sort-pending state) #t)
    event-result/consume]

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
    (tree-move-cursor! state (if (equal? modifier key-modifier-shift) -1 1))
    event-result/consume]

   [(key-event-enter? event)
    (tree-open-selection! state)]

   [(and (char? char) (equal? char #\c))
    (tree-open-create-input! state)]

   [(and (char? char) (equal? char #\a))
    (define paths (map TreeEntry-path (unbox (FileTreeState-entries state))))
    (define selected-box (FileTreeState-selected-paths state))
    (define selected (unbox selected-box))
    (set-box! selected-box
              (if (findf (lambda (path) (not (member path selected))) paths)
                  paths
                  '()))
    event-result/consume]

   [(and (char? char) (equal? char #\r))
    (tree-open-rename-input! state)]

   [(and (char? char) (equal? char #\y))
    (tree-select-transfer! state 'copy)]

   [(and (char? char) (equal? char #\space))
    (define entry (tree-current-entry state))
    (when entry
      (define path (TreeEntry-path entry))
      (define selected-box (FileTreeState-selected-paths state))
      (define selected (unbox selected-box))
      (set-box! selected-box
                (if (member path selected)
                    (filter (lambda (item) (not (path=? item path))) selected)
                    (append selected (list path)))))
    event-result/consume]

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
         (define marked? (member (TreeEntry-path entry) (unbox (FileTreeState-selected-paths state))))
         (define match? (tree-search-match-path? state (TreeEntry-path entry)))
         (define transfer-kind
           (if (member (TreeEntry-path entry) (unbox (FileTreeState-transfer-paths state)))
               (unbox (FileTreeState-transfer-kind state))
               #f))
         (define row-style-base (if selected? selected-style row-style))
         (define row-style*
           (let ([base
                  (cond
                   [(and match? (not selected?)) match-style]
                   [(equal? transfer-kind 'move) (style-with-bold (style-fg row-style-base Color/LightCyan))]
                   [(equal? transfer-kind 'copy) (style-with-bold (style-fg row-style-base Color/LightYellow))]
                   [else row-style-base])])
             (if marked? (style-with-reversed base) base)))
         (define text (tree-truncate (TreeEntry-display entry) content-width))
         (when (or selected? marked? match?)
           (frame-set-string! frame content-x row blank-line row-style*))
         (frame-set-string! frame content-x row text row-style*)
         (loop (cdr rest) (+ index 1)))))

  (tree-search-render-overlay! state frame content-x content-y content-width row-style tree-style)

  (define transfer-kind
    (if (tree-transfer-active? state)
        (unbox (FileTreeState-transfer-kind state))
        #f))
  (define ribbon-text
    (if (unbox (FileTreeState-sort-pending state))
        " n natural ↑  N natural ↓  m time ↑  M time ↓ "
        (string-append
         (hash-get *sort-labels* (unbox (FileTreeState-sort-key state)))
         (if (null? (unbox (FileTreeState-selected-paths state)))
             ""
             (string-append " SELECTED "
                            (number->string (length (unbox (FileTreeState-selected-paths state))))
                            " "))
         (if transfer-kind
             (string-append (if (equal? transfer-kind 'copy) " COPY " " MOVE ")
                            (number->string (length (unbox (FileTreeState-transfer-paths state))))
                            " ")
             "")
         (if (unbox (FileTreeState-show-all state)) "" " FILTERED "))))
  (define ribbon-style
    (cond
     [(equal? transfer-kind 'copy) copy-ribbon-style]
     [(equal? transfer-kind 'move) move-ribbon-style]
     [else tree-style]))

  (define centered-text (tree-truncate ribbon-text content-width))
  (define ribbon-x (tree-center-x content-x content-width (string-length centered-text)))
  (frame-set-string! frame content-x ribbon-y blank-line ribbon-style)
  (frame-set-string! frame ribbon-x ribbon-y centered-text ribbon-style))

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
  (set-box! (FileTreeState-transfer-paths state) '())
  (set-box! (FileTreeState-transfer-kind state) #f))

(define (tree-transfer-active? state)
  (not (null? (unbox (FileTreeState-transfer-paths state)))))

(define (tree-select-transfer! state transfer-kind)
  (define entry (tree-current-entry state))
  (define selected (unbox (FileTreeState-selected-paths state)))
  (define paths (if (null? selected) (if entry (list (TreeEntry-path entry)) '()) selected))
  (unless (null? paths)
    (set-box! (FileTreeState-transfer-paths state)
              (filter
               (lambda (path)
                 (not (findf (lambda (parent)
                               (and (not (path=? path parent))
                                    (path-descendant-or-same? path parent)))
                             paths)))
               paths))
    (set-box! (FileTreeState-transfer-kind state) transfer-kind)
    (set-box! (FileTreeState-selected-paths state) '()))
  event-result/consume)

(define (tree-paste-transfer! state)
  (when (tree-transfer-active? state)
    (define sources (unbox (FileTreeState-transfer-paths state)))
    (define transfer-kind (unbox (FileTreeState-transfer-kind state)))
    (define destination (tree-selected-base-path state))
    (define target-path (string-append destination "/" (file-name (car sources))))
    (tree-clear-transfer! state)
    (spawn-native-thread
     (lambda ()
       (define diagnostic
         (with-handler (lambda (err) (to-string err))
           (define destination-real (canonicalize-path destination))
           (unless (is-dir? destination-real) (error "Invalid paste destination"))
           (define sources-normalized
             (map (lambda (source)
                    (string-append (trim-end-matches (canonicalize-path (path-parent source)) "/")
                                   "/" (file-name source)))
                  sources))
           (define sources-real (map canonicalize-path sources-normalized))
           (define protected-sources (append sources-normalized sources-real))
           (define targets
             (map (lambda (source)
                    (string-append (trim-end-matches destination-real "/") "/" (file-name source)))
                  sources))
           (for-each
            (lambda (source)
              (when (and (is-dir? source) (path-descendant-or-same? destination-real source))
                (error (string-append "Cannot paste a directory into itself: " source))))
            sources-real)
           (for-each
            (lambda (target)
              (when (findf (lambda (source) (path-descendant-or-same? source target))
                           protected-sources)
                (error (string-append "Cannot replace a transfer source: " target))))
            targets)
           (let loop ([sources sources-normalized] [targets targets])
             (unless (null? sources)
               (tree-run-command! "rm" (list "-rf" "--" (car targets)))
               (tree-run-command! (if (equal? transfer-kind 'move) "mv" "cp")
                                  (list (if (equal? transfer-kind 'move) "-T" "-aT")
                                        "--" (car sources) (car targets)))
               (loop (cdr sources) (cdr targets))))
           ""))
       (hx.with-context
        (lambda ()
          (set-box! (FileTreeState-directories state)
                    (tree-unfold-path-to-target
                     (unbox (FileTreeState-directories state))
                     (unbox (FileTreeState-root state))
                     target-path))
          (tree-refresh! state target-path)
          (unless (equal? diagnostic "")
            (log::error! diagnostic)
            (toast-error diagnostic)))))))
  event-result/consume)

(define (tree-run-command! executable args)
  (define child (unwrap-ok (spawn-process (with-stderr-piped (command executable args)))))
  (define diagnostic (read-port-to-string (child-stderr child)))
  (unless (equal? (unwrap-ok (wait child)) 0)
    (error (if (equal? diagnostic "") (string-append executable " failed") diagnostic))))

(define (tree-set-all-folded! state folded?)
  (set-box! (FileTreeState-directories state)
            (transduce (unbox (FileTreeState-directories state))
                       (mapping (lambda (x) (list (list-ref x 0) folded?)))
                       (into-hashmap)))
  (tree-refresh! state #f)
  event-result/consume)
