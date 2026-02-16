;; Dropping the builtin, in lieu of something that uses the global context?
(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix.static. "helix/static.scm"))
(require "helix/misc.scm")
(require "helix/editor.scm")
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

(provide fold-directory
         unfold-all-one-level
         open-file-from-picker
         create-file
         create-directory
         fold-all
         FILE-TREE
         FILE-TREE-KEYBINDINGS
         create-file-tree
         file-tree-set-side!)

;; labelled buffers ->
(require (only-in "labelled-buffers.scm"
                  make-new-labelled-buffer!
                  temporarily-switch-focus
                  currently-in-labelled-buffer?
                  maybe-fetch-doc-id
                  fetch-doc-id))

;; TODO: This should be moved to a shared module somewhere, once the component API is cleaned up
(define (helix-prompt! prompt-str thunk)
  (push-component! (prompt prompt-str thunk)))

;; TODO: Prefix function names to keep them separate
;; File Tree keybindings
(define FILE-TREE-KEYBINDINGS
  (hash "normal"
        (hash "i"
              'no_op
              "v"
              'no_op
              "|"
              'no_op
              "!"
              'no_op
              "A-!"
              'no_op
              "$"
              'no_op
              "C-a"
              'no_op
              "C-x"
              'no_op
              "C-f"
              'no_op
              "a"
              'no_op
              "I"
              'no_op
              "o"
              'no_op
              "O"
              'no_op
              "d"
              'no_op
              "A-d"
              'no_op
              "F"
              'no_op
              "tab"
              ':fold-directory
              "E"
              ':unfold-all-one-level
              "o"
              ':open-file-from-picker
              "n"
              (hash "f" ':create-file "d" ':create-directory)
              "F"
              ':fold-all)))

;; This needs to be globally unique
(define FILE-TREE "github.com/mattwparas/helix-config/file-tree")

(define (file-tree-set-side! _)
  (void))

(define *file-tree* '())
(define *directories* (hash))
(define *ignore-set* (hashset "target" ".git"))
(define *file-tree-target-path* #f)
(define *file-tree-root* #f)

(define (path-clean path)
  (if (and (string? path)
           (> (string-length path) 1)
           (equal? (substring path (- (string-length path) 1) (string-length path)) "/"))
      (substring path 0 (- (string-length path) 1))
      path))

(define (path=? left right)
  (equal? (path-clean left) (path-clean right)))

(define (set-normal-mode!)
  (define normal-mode (string->editor-mode "normal"))
  (when normal-mode
    (editor-set-mode! normal-mode)))

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

(define (unfold-path-to-target! root target)
  (when (and (string? root) (string? target))
    (define root-path (path-clean root))
    (define target-path (path-clean target))
    (define start (file-directory target-path))
    (define (loop path)
      (when (and (string? path) (not (equal? path "")))
        (set! *directories* (hash-insert *directories* path #f))
        (unless (path=? path root-path)
          (define parent (path-parent path))
          (unless (path=? parent path)
            (loop parent)))))
    (loop start)))

(define (list-index-of-path entries path)
  (define target (path-clean path))
  (define (loop idx rest)
    (cond
      [(null? rest) #f]
      [(path=? (car rest) target) idx]
      [else (loop (+ idx 1) (cdr rest))]))
  (loop 0 entries))

(define (fold! directory)
  (set! *directories* (hash-insert *directories* directory #t)))

(define (unfold! directory)
  (set! *directories* (hash-insert *directories* directory #f)))

(define (flatten x)
  (cond
    [(null? x) '()]
    [(not (list? x)) (list x)]
    [else (append (flatten (car x)) (flatten (cdr x)))]))

(define (format-dir path)
  (if (hash-contains? *directories* path)
      (if (hash-try-get *directories* path) ">  " "v  ")
      ">  " ;; First time we're visiting, mark as closed
      ))

(define *extension-map* (hash "rs" " " "scm" "󰘧 "))

(define (path->symbol path)
  (let ([extension (path->extension path)])
    (if (not (void? extension))
        (begin
          (define lookup (hash-try-get *extension-map* (path->extension path)))
          (if lookup lookup " "))

        " ")))

;; Simple tree implementation
;; Walks the file structure and prints without much fancy formatting
;; Returns a list of the visited files for convenience
(define (tree p writer-thunk)
  (define (tree-rec path padding)
    (define name (file-name path))

    (if (hashset-contains? *ignore-set* name)
        '()
        (begin
          (writer-thunk
           (string-append padding
                          (if (is-dir? path)
                              (format-dir path)
                              (path->symbol path))
                          name))
          (cond
            [(is-file? path) path]
            [(is-dir? path)
             ;; If we're not supposed to see this path (i.e. its been folded),
             ;; then we're going to ignore it
             ;; Also - if it doesn't exist in the set, default it to folded
             (if (not (hash-contains? *directories* path))
                 (begin
                   (set! *directories* (hash-insert *directories* path #t))
                   (list path))
                 (if (hash-try-get *directories* path)
                     (list path)

                     (cons path
                           (map (fn (x) (tree-rec x (string-append padding "    ")))
                                (merge-sort (read-dir path) #:comparator string<?)))))]
            [else void]))))
  (flatten (tree-rec p "")))

;;@doc
;; Open the currently selected line
(define (open-file-from-picker)
  (when (currently-in-labelled-buffer? FILE-TREE)
    (define file-to-open (list-ref *file-tree* (helix.static.get-current-line-number)))
    (helix.open file-to-open)
    (set-normal-mode!)))

;; Initialize all roots to be flat so that we don't blow things up, recursion only goes in to things
;; that are expanded
(define (current-doc-id)
  (let* ([focus (editor-focus)])
    (editor->doc-id focus)))

(define (create-file-tree-buffer-if-needed)

  ;; The doc id, or #false if it is not in the map
  (define doc-id (maybe-fetch-doc-id FILE-TREE))

  (unless doc-id
    (make-new-labelled-buffer! #:label FILE-TREE))

  (unless (editor-doc-exists? (fetch-doc-id FILE-TREE))
    (make-new-labelled-buffer! #:label FILE-TREE)))

(define (render-file-tree)
  (define root (or *file-tree-root* (helix-find-workspace)))

  (helix.static.select_all)
  (helix.static.delete_selection)

  ;; Update the current file tree value
  (set! *file-tree*
        (tree root
              (lambda (str)
                (helix.static.insert_string str)
                (helix.static.open_below)
                (helix.static.goto_line_start))))

  (when (and *file-tree-target-path* (string? *file-tree-target-path*))
    (define idx (list-index-of-path *file-tree* *file-tree-target-path*))
    (when idx
      (helix.goto-line (+ idx 1))
      (helix.static.goto_line_start))
    (set! *file-tree-target-path* #f))

  (set-normal-mode!))

(define (create-file-tree)
  (if (currently-in-labelled-buffer? FILE-TREE)
      (void)
      (begin
        (set! *file-tree-target-path* (current-doc-path))
        (set! *file-tree-root* (resolve-tree-root *file-tree-target-path*))
        (unfold-path-to-target! *file-tree-root* *file-tree-target-path*)
        (create-file-tree-buffer-if-needed)
        (editor-switch-action! (fetch-doc-id FILE-TREE) (Action/Replace))
        (render-file-tree))))

;;@doc
;; Fold the directory that we're currently hovering over
(define (fold-directory)
  (when (currently-in-labelled-buffer? FILE-TREE)
    (define directory-to-fold (list-ref *file-tree* (helix.static.get-current-line-number)))
    (when (is-dir? directory-to-fold)
      (begin
        ;; If its already folded, unfold it
        (if (hash-try-get *directories* directory-to-fold)
            (unfold! directory-to-fold)
            (fold! directory-to-fold))

        (update-file-tree)))))

;;@doc
;; Create a file under wherever we are
(define (create-file)
  (when (currently-in-labelled-buffer? FILE-TREE)
    (define currently-selected (list-ref *file-tree* (helix.static.get-current-line-number)))
    (define prompt
      (if (is-dir? currently-selected)
          (string-append "New file: " currently-selected "/")
          (string-append "New file: "
                         (trim-end-matches currently-selected (file-name currently-selected)))))

    (helix-prompt!
     prompt
     (lambda (result)
       (define file-name (string-append (trim-start-matches prompt "New file: ") result))
       (temporarily-switch-focus (lambda ()
                                   (helix.new)
                                   (helix.open file-name)
                                   (helix.write file-name)
                                   (helix.quit)))

       ;; TODO:
       ;; This is happening before the write is finished, so its not working. We will have to manually insert
       ;; the new file into the right spot in the tree, which would require rewriting this to have a proper sorted
       ;; tree representation in memory, which we don't yet have. For now, we can just do this I guess
       (enqueue-thread-local-callback refresh-file-tree)))))

(define (update-file-tree)

  (define current-selection (helix.static.current-selection-object))
  ; (define line-number (helix.static.get-current-line-number))

  (render-file-tree)

  ;; Set it BACK to where we were previously!
  ;; TODO: Currently the following bug exists:
  ;; Open helix, open file tree, run SPC-b to open the file tree
  ;; buffer (there should now be two of them). Press TAB, then F.
  ;; Helix will crash. One way to fix it is to not update the selection,
  ;; however that makes the file tree experience way worse. A better
  ;; way for now is to just disallow that command in the file tree
  ;; buffer since I haven't yet figured out how to get it working.
  (helix.static.set-current-selection-object! current-selection)
  (set-normal-mode!))

(define (refresh-file-tree)
  (temporarily-switch-focus (lambda ()
                              (editor-switch-action! (fetch-doc-id FILE-TREE) (Action/Replace))
                              (update-file-tree))))

;;@doc
;; Create a new directory
(define (create-directory)
  (when (currently-in-labelled-buffer? FILE-TREE)
    (define currently-selected (list-ref *file-tree* (helix.static.get-current-line-number)))
    (define prompt
      (if (is-dir? currently-selected)
          (string-append "New directory: " currently-selected "/")
          (string-append "New directory: "
                         (trim-end-matches currently-selected (file-name currently-selected)))))

    (helix-prompt! prompt
                   (lambda (result)
                     (define directory-name
                       (string-append (trim-start-matches prompt "New directory: ") result))
                     (hx.create-directory directory-name)
                     (enqueue-thread-local-callback refresh-file-tree)))))

;;@doc
;; Fold all of the directories
(define (fold-all)
  (when (currently-in-labelled-buffer? FILE-TREE)

    (set! *directories*
          (transduce *directories* (mapping (lambda (x) (list (list-ref x 0) #t))) (into-hashmap)))

    (helix.static.goto_file_start)

    (refresh-file-tree)))

;;@doc
;; Unfold all of the currently open directories one level.
(define (unfold-all-one-level)
  (when (currently-in-labelled-buffer? FILE-TREE)

    (set! *directories*
          (transduce *directories* (mapping (lambda (x) (list (list-ref x 0) #f))) (into-hashmap)))

    (refresh-file-tree)))
