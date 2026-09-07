(require "helix/components.scm")
(require "helix/misc.scm")
(require-builtin steel/time)
(require-builtin helix/core/misc as fs.)

(provide FileTreeState
         FileTreeState?
         FileTreeState-root
         FileTreeState-entries
         FileTreeState-directories
         FileTreeState-cursor
         FileTreeState-window-start
         FileTreeState-max-length
         FileTreeState-center-next-render
         FileTreeState-show-all
         FileTreeState-sort-key
         FileTreeState-sort-pending
         FileTreeState-delete-confirm-path
         FileTreeState-selected-paths
         FileTreeState-transfer-paths
         FileTreeState-transfer-kind
         FileTreeState-search-visible
         FileTreeState-search-focused
         FileTreeState-search-query
         FileTreeState-search-cursor
         FileTreeState-search-matches
         FileTreeState-search-active-index
         TreeEntry
         TreeEntry?
         TreeEntry-path
         TreeEntry-directory
         TreeEntry-display
         tree-unfold-path-to-target
         tree-refresh!
         tree-clamp
         tree-truncate
         tree-center-x
         tree-popup-area
         tree-directory-folded?
         tree-ensure-window!
         tree-current-entry
         tree-list-index-of-path
         tree-selected-base-path
         tree-refresh-when
         path-descendant-or-same?
         tree-text-cursor-clamped
         tree-text-event-handler
         tree-text-visible-state
         shell-escape
         path-parent
         file-directory
         path-clean
         path=?)

(struct FileTreeState
        (root
         entries
         directories
         cursor
         window-start
         max-length
         center-next-render
         show-all
         delete-confirm-path
         selected-paths
         transfer-paths
         transfer-kind
         search-visible
         search-focused
         search-query
         search-cursor
         search-matches
         search-active-index
         sort-key
         sort-pending))

(struct TreeEntry
        (path
         directory
         display))

(define *extension-map*
  (hash "bash" " "
        "c" " "
        "css" " "
        "go" " "
        "html" " "
        "js" " "
        "json" " "
        "lock" " "
        "lua" " "
        "md" " "
        "nix" " "
        "nu" " "
        "nuon" " "
        "py" " "
        "rs" " "
        "scm" "󰘧 "
        "sh" " "
        "svg" "󰜡 "
        "toml" " "
        "ts" " "
        "txt" "󰈙 "
        "yaml" " "
        "yml" " "
        "zsh" " "))

(define (path-clean path)
  (if (and (string? path)
           (> (string-length path) 1)
           (equal? (substring path (- (string-length path) 1) (string-length path)) "/"))
      (substring path 0 (- (string-length path) 1))
      path))

(define (path=? left right)
  (equal? (path-clean left) (path-clean right)))

(define (file-directory path)
  (if (and (string? path) (not (is-dir? path)))
      (path-clean (trim-end-matches path (file-name path)))
      (path-clean path)))

(define (path-parent path)
  (if (not (string? path))
      path
      (let* ([clean (path-clean path)]
             [name (file-name clean)])
        (if (or (equal? clean "/") (equal? name "") (equal? name clean))
            clean
            (path-clean (trim-end-matches clean name))))))

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

(define (tree-truncate text max-length)
  (if (<= max-length 0)
      ""
      (if (> (string-length text) max-length)
          (substring text 0 max-length)
          text)))

(define (tree-clamp value lower upper)
  (max lower (min upper value)))

(define (path-descendant-or-same? maybe-child maybe-parent)
  (if (and (string? maybe-child) (string? maybe-parent))
      (let ([child (path-clean maybe-child)]
            [parent (path-clean maybe-parent)])
        (define child-prefix (string-append parent "/"))
        (or (path=? child parent)
            (and (>= (string-length child) (string-length child-prefix))
                 (equal? (substring child 0 (string-length child-prefix)) child-prefix))))
      #f))

(define (tree-text-cursor-clamped input-box cursor-box)
  (tree-clamp (unbox cursor-box) 0 (string-length (unbox input-box))))

(define (tree-text-event-handler input-box cursor-box event)
  (define input (unbox input-box))
  (define cursor (tree-text-cursor-clamped input-box cursor-box))
  (define char (key-event-char event))
  (define modifier (key-event-modifier event))
  (cond
   [(or (key-event-backspace? event) (key-event-delete? event))
    (define index (if (key-event-backspace? event) (- cursor 1) cursor))
    (when (and (>= index 0) (< index (string-length input)))
      (set-box! input-box
                (string-append (substring input 0 index)
                               (substring input (+ index 1) (string-length input)))))
    (set-box! cursor-box (max 0 index))
    event-result/consume]
   [(or (key-event-left? event) (key-event-right? event)
        (key-event-home? event) (key-event-end? event))
    (set-box! cursor-box
              (tree-clamp (cond
                           [(key-event-left? event) (- cursor 1)]
                           [(key-event-right? event) (+ cursor 1)]
                           [(key-event-home? event) 0]
                           [else (string-length input)])
                          0
                          (string-length input)))
    event-result/consume]
   [(and (char? char)
         (not (equal? modifier key-modifier-ctrl))
         (not (equal? modifier key-modifier-alt))
         (not (equal? modifier key-modifier-super)))
    (set-box! input-box
              (string-append (substring input 0 cursor)
                             (string char)
                             (substring input cursor (string-length input))))
    (set-box! cursor-box (+ cursor 1))
    event-result/consume]
   [else event-result/consume-without-rerender]))

(define (tree-text-visible-state input-box cursor-box max-width)
  (if (<= max-width 0)
      (list "" 0)
      (let* ([input (unbox input-box)]
             [cursor (tree-text-cursor-clamped input-box cursor-box)]
             [text-room (max 0 (- max-width 1))]
             [max-start (max 0 (- (string-length input) text-room))]
             [window-start (if (< cursor text-room)
                               0
                               (- cursor (- text-room 1)))]
             [window-start (tree-clamp window-start 0 max-start)]
             [window-end (min (string-length input) (+ window-start text-room))]
             [visible-text (substring input window-start window-end)]
             [cursor-col (tree-clamp (- cursor window-start)
                                     0
                                     (max 0 (- max-width 1)))])
        (list visible-text cursor-col))))

(define (tree-center-offset outer-size inner-size)
  (max 0 (exact (round (/ (- outer-size inner-size) 2)))))

(define (tree-center-x outer-x outer-width inner-width)
  (+ outer-x (tree-center-offset outer-width inner-width)))

(define (tree-popup-area rect)
  (define width (area-width rect))
  (define height (area-height rect))
  (define tree-width (max 56 (min 120 (- width 6))))
  (define tree-height-target (exact (round (/ (* height 2) 3))))
  (define tree-height (tree-clamp tree-height-target 8 (max 8 (- height 2))))
  (define tree-x (tree-center-x (area-x rect) width tree-width))
  (define tree-y (+ (area-y rect) (tree-center-offset height tree-height)))
  (area tree-x tree-y tree-width tree-height))

(define (tree-directory-folded? state directory)
  (define directories-box (FileTreeState-directories state))
  (define directories (unbox directories-box))
  (if (hash-contains? directories directory)
      (hash-try-get directories directory)
      (begin
        (set-box! directories-box (hash-insert directories directory #t))
        #t)))

(define (tree-concat-map func lst)
  (if (null? lst)
      '()
      (append (func (car lst))
              (tree-concat-map func (cdr lst)))))

(define (tree-build state root)
  (define filtered? (not (unbox (FileTreeState-show-all state))))
  (define sort-key (unbox (FileTreeState-sort-key state)))
  (define by-time? (member sort-key '(#\m #\M)))
  (define descending? (member sort-key '(#\N #\M)))
  (define (directory-entries path)
    (sort
     (map (lambda (entry)
            (append entry
                    (list (if by-time?
                              (fs-metadata-modified (file-metadata (car entry)))
                              (let loop ([chars (string->list (string-downcase (file-name (car entry))))]
                                         [number #f]
                                         [parts '()])
                                (cond
                                 [(null? chars) (reverse (if number (cons number parts) parts))]
                                 [(and (char>=? (car chars) #\0) (char<=? (car chars) #\9))
                                  (loop (cdr chars)
                                        (+ (* (or number 0) 10) (- (char->integer (car chars)) 48))
                                        parts)]
                                 [else
                                  (loop (cdr chars) #f
                                        (cons (string (car chars))
                                              (if number (cons number parts) parts)))]))))))
          (fs.directory-entries path filtered?))
     (lambda (left right)
       (if (not (equal? (list-ref left 1) (list-ref right 1)))
           (list-ref left 1)
           (let* ([a (if descending? right left)]
                  [b (if descending? left right)]
                  [a-key (list-ref a 2)]
                  [b-key (list-ref b 2)])
             (cond
              [(equal? a-key b-key) (string<? (car a) (car b))]
              [by-time? (system-time<? a-key b-key)]
              [else
               (let loop ([a a-key] [b b-key])
                 (cond
                  [(null? a) (not (null? b))]
                  [(null? b) #f]
                  [(equal? (car a) (car b)) (loop (cdr a) (cdr b))]
                  [(and (number? (car a)) (number? (car b))) (< (car a) (car b))]
                  [else (string<? (if (number? (car a)) "0" (car a))
                                  (if (number? (car b)) "0" (car b)))]))]))))))
  (define (tree-rec item padding)
    (define path (list-ref item 0))
    (define directory? (list-ref item 1))
    (define name (file-name path))

    (if (and filtered?
             (> (string-length name) 0)
             (equal? (substring name 0 1) "."))
        '()
        (cond
         [(not directory?)
          (list (TreeEntry path #f (string-append padding (path->symbol path) name)))]
         [else
          (define folded? (tree-directory-folded? state path))
          (define entry (TreeEntry path #t (string-append padding (if folded? " " " ") name)))
          (if folded?
              (list entry)
              (cons entry
                    (tree-concat-map
                     (fn (x) (tree-rec x (string-append padding "    ")))
                     (directory-entries path))))])))

  (if (is-dir? root)
      (tree-concat-map
       (fn (x) (tree-rec x ""))
       (directory-entries root))
      (if (is-file? root) (tree-rec (list root #f) "") '())))

(define (tree-list-index-of-path entries path)
  (if (not (string? path))
      #f
      (let ([target (path-clean path)])
        (define (loop idx rest)
          (cond
           [(null? rest) #f]
           [(path=? (TreeEntry-path (car rest)) target) idx]
           [else (loop (+ idx 1) (cdr rest))]))
        (loop 0 entries))))

(define (tree-ensure-window! state)
  (define entries (unbox (FileTreeState-entries state)))
  (define count (length entries))
  (define cursor-box (FileTreeState-cursor state))
  (define window-start-box (FileTreeState-window-start state))

  (if (= count 0)
      (begin
        (set-box! cursor-box 0)
        (set-box! window-start-box 0))
      (begin
        (define visible (max 1 (unbox (FileTreeState-max-length state))))
        (set-box! cursor-box (tree-clamp (unbox cursor-box) 0 (- count 1)))

        (define max-window-start (max 0 (- count visible)))
        (set-box! window-start-box (tree-clamp (unbox window-start-box) 0 max-window-start))

        (when (< (unbox cursor-box) (unbox window-start-box))
          (set-box! window-start-box (unbox cursor-box)))

        (when (> (unbox cursor-box) (+ (unbox window-start-box) (- visible 1)))
          (set-box! window-start-box
                    (tree-clamp (- (unbox cursor-box) (- visible 1))
                                0
                                max-window-start))))))

(define (tree-refresh! state focus-path)
  (define root (unbox (FileTreeState-root state)))
  (define entries
    (if (and (string? root) (path-exists? root))
        (tree-build state root)
        '()))

  (set-box! (FileTreeState-entries state) entries)

  (define idx (tree-list-index-of-path entries focus-path))
  (when idx
    (set-box! (FileTreeState-cursor state) idx))
  (tree-ensure-window! state))

(define (tree-current-entry state)
  (define entries (unbox (FileTreeState-entries state)))
  (define idx (unbox (FileTreeState-cursor state)))
  (if (and (>= idx 0) (< idx (length entries)))
      (list-ref entries idx)
      #f))

(define (tree-unfold-path-to-target directories root target)
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

(define (tree-refresh-when state target predicate focus-path)
  (define max-attempts 40)
  (define (loop attempts)
    (if (or (<= attempts 0) (predicate target))
        (tree-refresh! state focus-path)
        (enqueue-thread-local-callback-with-delay
         50
         (lambda ()
           (loop (- attempts 1))))))
  (loop max-attempts))

(define (tree-selected-base-path state)
  (define entry (tree-current-entry state))
  (define root (unbox (FileTreeState-root state)))
  (cond
   [(and entry (TreeEntry-directory entry)) (TreeEntry-path entry)]
   [(and entry (string? (TreeEntry-path entry))) (file-directory (TreeEntry-path entry))]
   [else root]))
