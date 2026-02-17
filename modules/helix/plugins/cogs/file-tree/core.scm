;; Shared state + behavior for file-tree components.

(require "helix/misc.scm")

(provide FileTreeState
         FileTreeState?
         FileTreeState-root
         FileTreeState-entries
         FileTreeState-directories
         FileTreeState-cursor
         FileTreeState-window-start
         FileTreeState-max-length
         FileTreeState-center-next-render
         FileTreeState-show-hidden-directories
         FileTreeState-delete-confirm-path
         FileTreeState-transfer-path
         FileTreeState-transfer-kind
         tree-unfold-path-to-target
         tree-refresh!
         tree-clamp
         tree-truncate
         tree-entry-path
         tree-directory-folded?
         tree-ensure-window!
         tree-current-entry
         tree-selected-base-path
         tree-refresh-when
         shell-escape
         path-parent
         file-directory
         path-clean
         path=?)

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

(define *ignore-set* (hashset "target"))

(define *extension-map*
  (hash "rs" " "
        "scm" "󰘧 "
        "nix" " "
        "md" " "))

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

(struct FileTreeState
        (root
         entries
         directories
         cursor
         window-start
         max-length
         center-next-render
         show-hidden-directories
         delete-confirm-path
         transfer-path
         transfer-kind))

(define (tree-entry path directory? display)
  (list path directory? display))

(define (tree-entry-path entry)
  (list-ref entry 0))

(define (tree-valid-entry? entry)
  (and (list? entry)
       (= (length entry) 3)
       (string? (list-ref entry 0))
       (boolean? (list-ref entry 1))
       (string? (list-ref entry 2))))

(define (tree-truncate text max-length)
  (if (<= max-length 0)
      ""
      (if (> (string-length text) max-length)
          (substring text 0 max-length)
          text)))

(define (tree-clamp value lower upper)
  (max lower (min upper value)))

(define (tree-directory-folded? state directory)
  (define directories-box (FileTreeState-directories state))
  (define directories (unbox directories-box))
  (if (hash-contains? directories directory)
      (hash-try-get directories directory)
      (begin
        (set-box! directories-box (hash-insert directories directory #t))
        #t)))

(define (tree-format-dir state directory)
  (if (tree-directory-folded? state directory)
      ">  "
      "v  "))

(define (hidden-directory-name? name)
  (and (string? name)
       (> (string-length name) 0)
       (equal? (substring name 0 1) ".")
       (not (equal? name "."))
       (not (equal? name ".."))))

(define (tree-concat-map func lst)
  (if (null? lst)
      '()
      (append (func (car lst))
              (tree-concat-map func (cdr lst)))))

(define (tree-build state root)
  (define (tree-rec path padding)
    (define name (file-name path))

    (if (or (hashset-contains? *ignore-set* name)
            (and (is-dir? path)
                 (not (unbox (FileTreeState-show-hidden-directories state)))
                 (hidden-directory-name? name)))
        '()
        (cond
          [(is-file? path)
           (list (tree-entry path #f (string-append padding (path->symbol path) name)))]
          [(is-dir? path)
           (define folded? (tree-directory-folded? state path))
           (define entry (tree-entry path #t (string-append padding (tree-format-dir state path) name)))
           (if folded?
               (list entry)
               (cons entry
                     (tree-concat-map
                      (fn (x) (tree-rec x (string-append padding "    ")))
                      (merge-sort (read-dir path) #:comparator path-sort<?))))]
          [else '()])))

  (if (is-dir? root)
      (tree-concat-map
       (fn (x) (tree-rec x ""))
       (merge-sort (read-dir root) #:comparator path-sort<?))
      (tree-rec root "")))

(define (tree-list-index-of-path entries path)
  (if (not (string? path))
      #f
      (let ([target (path-clean path)])
        (define (loop idx rest)
          (cond
            [(null? rest) #f]
            [(path=? (tree-entry-path (car rest)) target) idx]
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
  (define root (FileTreeState-root state))
  (define raw-entries
    (if (and (string? root) (path-exists? root))
        (tree-build state root)
        '()))

  (define entries (filter tree-valid-entry? raw-entries))

  (set-box! (FileTreeState-entries state) entries)

  (if (null? entries)
      (begin
        (set-box! (FileTreeState-cursor state) 0)
        (set-box! (FileTreeState-window-start state) 0))
      (begin
        (define idx (tree-list-index-of-path entries focus-path))
        (when idx
          (set-box! (FileTreeState-cursor state) idx))
        (tree-ensure-window! state))))

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
  (define root (FileTreeState-root state))
  (cond
    [(and entry (list-ref entry 1)) (tree-entry-path entry)]
    [(and entry (string? (tree-entry-path entry))) (file-directory (tree-entry-path entry))]
    [else root]))
