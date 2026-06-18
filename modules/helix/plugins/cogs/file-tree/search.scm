(require "helix/components.scm")
(require "./core.scm")

(provide tree-search-input-visible?
         tree-search-input-focused?
         tree-search-open!
         tree-search-clear!
         tree-search-jump-next!
         tree-search-jump-prev!
         tree-search-input-event-handler
         tree-search-match-path?
         tree-search-render-overlay!)

(define (string-downcase* value)
  (list->string (map char-downcase (string->list value))))

(define (string-contains? haystack needle)
  (define haystack-length (string-length haystack))
  (define needle-length (string-length needle))
  (cond
    [(= needle-length 0) #t]
    [(< haystack-length needle-length) #f]
    [else
     (let loop ([index 0])
       (if (> (+ index needle-length) haystack-length)
           #f
           (if (equal? (substring haystack index (+ index needle-length)) needle)
               #t
               (loop (+ index 1)))))]))

(define (tree-search-entry-matches? entry query-lower)
  (if (= (string-length query-lower) 0)
      #f
      (let* ([entry-name (file-name (TreeEntry-path entry))]
             [name-lower (string-downcase* entry-name)])
        (string-contains? name-lower query-lower))))

(define (tree-search-list-index-of-path paths target-path)
  (define (loop index rest)
    (cond
      [(null? rest) #f]
      [(path=? (car rest) target-path) index]
      [else (loop (+ index 1) (cdr rest))]))
  (if (string? target-path)
      (loop 0 paths)
      #f))

(define (tree-search-focus-active! state)
  (define matches (unbox (FileTreeState-search-matches state)))
  (define active-index (unbox (FileTreeState-search-active-index state)))
  (when (and (>= active-index 0) (< active-index (length matches)))
    (define focus-path (list-ref matches active-index))
    (define entries (unbox (FileTreeState-entries state)))
    (define entry-paths (map TreeEntry-path entries))
    (define cursor-index (tree-search-list-index-of-path entry-paths focus-path))
    (when (number? cursor-index)
      (set-box! (FileTreeState-cursor state) cursor-index)
      (tree-ensure-window! state))))

(define (tree-search-commit! state)
  (define query-lower (string-downcase* (unbox (FileTreeState-search-query state))))
  (define entries (unbox (FileTreeState-entries state)))
  (define matches-reversed
    (let loop ([rest entries] [acc '()])
      (if (null? rest)
          acc
          (let ([entry (car rest)])
            (if (tree-search-entry-matches? entry query-lower)
                (loop (cdr rest) (cons (TreeEntry-path entry) acc))
                (loop (cdr rest) acc))))))
  (define matches (reverse matches-reversed))
  (set-box! (FileTreeState-search-matches state) matches)
  (if (null? matches)
      (set-box! (FileTreeState-search-active-index state) -1)
      (set-box! (FileTreeState-search-active-index state) 0))
  (set-box! (FileTreeState-search-focused state) #f)
  (tree-search-focus-active! state))

(define (tree-search-jump! state delta)
  (define matches (unbox (FileTreeState-search-matches state)))
  (define count (length matches))
  (when (> count 0)
    (define active (unbox (FileTreeState-search-active-index state)))
    (define start-index (if (and (>= active 0) (< active count)) active 0))
    (set-box! (FileTreeState-search-active-index state)
              (modulo (+ start-index delta count) count))
    (tree-search-focus-active! state)))

(define (tree-search-ratio state)
  (define matches (unbox (FileTreeState-search-matches state)))
  (define count (length matches))
  (define active-index (unbox (FileTreeState-search-active-index state)))
  (define active
    (if (and (> count 0) (>= active-index 0) (< active-index count))
        (+ active-index 1)
        0))
  (string-append "[" (number->string active) "/" (number->string count) "]"))

(define (tree-search-input-visible? state)
  (unbox (FileTreeState-search-visible state)))

(define (tree-search-input-focused? state)
  (unbox (FileTreeState-search-focused state)))

(define (tree-search-open! state)
  (define query-box (FileTreeState-search-query state))
  (define cursor-box (FileTreeState-search-cursor state))
  (set-box! (FileTreeState-search-visible state) #t)
  (set-box! (FileTreeState-search-focused state) #t)
  (set-box! cursor-box (tree-text-cursor-clamped query-box cursor-box)))

(define (tree-search-clear! state)
  (set-box! (FileTreeState-search-visible state) #f)
  (set-box! (FileTreeState-search-focused state) #f)
  (set-box! (FileTreeState-search-query state) "")
  (set-box! (FileTreeState-search-cursor state) 0)
  (set-box! (FileTreeState-search-matches state) '())
  (set-box! (FileTreeState-search-active-index state) -1))

(define (tree-search-jump-next! state)
  (tree-search-jump! state 1))

(define (tree-search-jump-prev! state)
  (tree-search-jump! state -1))

(define (tree-search-input-event-handler state event)
  (define char (key-event-char event))
  (define query-box (FileTreeState-search-query state))
  (define cursor-box (FileTreeState-search-cursor state))
  (cond
    [(key-event-enter? event)
     (tree-search-commit! state)
     event-result/consume]

    [(key-event-backspace? event)
     (tree-text-backspace! query-box cursor-box)
     event-result/consume]

    [(key-event-delete? event)
     (tree-text-delete-forward! query-box cursor-box)
     event-result/consume]

    [(key-event-left? event)
     (tree-text-move-cursor! query-box cursor-box -1)
     event-result/consume]

    [(key-event-right? event)
     (tree-text-move-cursor! query-box cursor-box 1)
     event-result/consume]

    [(key-event-home? event)
     (set-box! cursor-box 0)
     event-result/consume]

    [(key-event-end? event)
     (set-box! cursor-box (string-length (unbox query-box)))
     event-result/consume]

    [(tree-event-plain-char? event)
     (tree-text-append-char! query-box cursor-box char)
     event-result/consume]

    [else event-result/consume-without-rerender]))

(define (tree-search-match-path? state path)
  (define matches (unbox (FileTreeState-search-matches state)))
  (define (loop rest)
    (cond
      [(null? rest) #f]
      [(path=? (car rest) path) #t]
      [else (loop (cdr rest))]))
  (loop matches))

(define (tree-search-render-overlay! state frame content-x content-y content-width row-style tree-style)
  (when (tree-search-input-visible? state)
    (define overlay-width (max 18 (quotient content-width 2)))
    (define overlay-height 3)
    (define overlay-x (+ content-x (max 0 (quotient (- content-width overlay-width) 2))))
    (define overlay-y (+ content-y 1))
    (define overlay-area (area overlay-x overlay-y overlay-width overlay-height))
    (define border-style
      (if (tree-search-input-focused? state)
          (style-with-bold (style-fg row-style Color/LightBlue))
          row-style))
    (define search-ratio (tree-search-ratio state))
    (define search-prefix "/ ")
    (define inner-width (max 1 (- overlay-width 2)))
    (define search-status search-ratio)
    (define query-width (max 1 (- inner-width (string-length search-prefix) (string-length search-status) 1)))
    (define query-box (FileTreeState-search-query state))
    (define cursor-box (FileTreeState-search-cursor state))
    (define query-state (tree-text-visible-state query-box cursor-box query-width))
    (define query-visible (list-ref query-state 0))
    (define query-cursor-col (list-ref query-state 1))
    (define line-y (+ overlay-y 1))
    (define line-x (+ overlay-x 1))
    (define status-x (+ line-x (- inner-width (string-length search-status))))
    (define query-x (+ line-x (string-length search-prefix)))
    (define blank-line (make-string inner-width #\space))
    (define cursor-glyph
      (if (< query-cursor-col (string-length query-visible))
          (substring query-visible query-cursor-col (+ query-cursor-col 1))
          " "))

    (block/render frame overlay-area (make-block tree-style border-style "all" "plain"))
    (frame-set-string! frame line-x line-y blank-line tree-style)
    (frame-set-string! frame line-x line-y search-prefix (style-with-bold row-style))
    (frame-set-string! frame query-x line-y (tree-truncate query-visible query-width) row-style)
    (frame-set-string! frame status-x line-y search-status (style-with-bold row-style))

    (when (tree-search-input-focused? state)
      (frame-set-string! frame (+ query-x query-cursor-col) line-y cursor-glyph (style-with-reversed row-style)))))
