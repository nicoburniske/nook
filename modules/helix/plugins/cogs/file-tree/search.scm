(require "helix/components.scm")
(require "./core.scm")

(provide tree-search-input-visible?
         tree-search-input-focused?
         tree-search-open!
         tree-search-clear!
         tree-search-jump!
         tree-search-input-event-handler
         tree-search-match-path?
         tree-search-render-overlay!)

(define (string-downcase* value)
  (list->string (map char-downcase (string->list value))))

(define (tree-search-focus-active! state)
  (define matches (unbox (FileTreeState-search-matches state)))
  (define active-index (unbox (FileTreeState-search-active-index state)))
  (when (and (>= active-index 0) (< active-index (length matches)))
    (define focus-path (list-ref matches active-index))
    (define entries (unbox (FileTreeState-entries state)))
    (define cursor-index (tree-list-index-of-path entries focus-path))
    (when (number? cursor-index)
      (set-box! (FileTreeState-cursor state) cursor-index)
      (tree-ensure-window! state))))

(define (tree-search-commit! state)
  (define query-lower (string-downcase* (unbox (FileTreeState-search-query state))))
  (define entries (unbox (FileTreeState-entries state)))
  (define matches
    (transduce entries
               (filtering (lambda (entry)
                            (and (not (equal? query-lower ""))
                                 (string-contains? (string-downcase* (file-name (TreeEntry-path entry)))
                                                   query-lower))))
               (mapping TreeEntry-path)
               (into-list)))
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

(define (tree-search-input-event-handler state event)
  (define query-box (FileTreeState-search-query state))
  (define cursor-box (FileTreeState-search-cursor state))
  (cond
   [(key-event-enter? event)
    (tree-search-commit! state)
    event-result/consume]

   [else (tree-text-event-handler query-box cursor-box event)]))

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
    (define search-prefix "/ ")
    (define inner-width (max 1 (- overlay-width 2)))
    (define search-status (tree-search-ratio state))
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
