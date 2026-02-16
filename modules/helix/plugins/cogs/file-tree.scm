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
         delete-path
         rename-path
         create-path
         fold-all
         FILE-TREE
         FILE-TREE-KEYBINDINGS
         create-file-tree
         file-tree-set-side!)

;; labelled buffers ->
(require (only-in "labelled-buffers.scm"
                  make-new-labelled-buffer!
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
              "q"
              ':buffer-close!
              "o"
              'no_op
              "O"
              'no_op
               "d"
               ':delete-path
               "r"
               ':rename-path
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
              ':create-path
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

(define (ends-with? value suffix)
  (if (< (string-length value) (string-length suffix))
      #f
      (equal? (substring value
                         (- (string-length value) (string-length suffix))
                         (string-length value))
              suffix)))

(define (path=? left right)
  (equal? (path-clean left) (path-clean right)))

(define (set-normal-mode!)
  (define normal-mode (string->editor-mode "normal"))
  (when normal-mode
    (editor-set-mode! normal-mode)))

(define (focus-line-near-top!)
  (with-handler (lambda (_) void)
                (helix.static.align_view_center)))

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

(define (current-tree-entry)
  (define idx (helix.static.get-current-line-number))
  (if (and (>= idx 0) (< idx (length *file-tree*)))
      (list-ref *file-tree* idx)
      #f))

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

(define *extension-map* (hash
  "rs" " "
  "scm" "󰘧 "
  "nix" " "
  "md" " "
  ))

(define (path->symbol path)
  (let ([extension (path->extension path)])
    (if (not (void? extension))
        (begin
          (define lookup (hash-try-get *extension-map* (path->extension path)))
          (if lookup lookup " "))

        " ")))

(define (entry-name path)
  (file-name path))

(define (path-sort<? left right)
  (define left-dir? (is-dir? left))
  (define right-dir? (is-dir? right))
  (cond
    [(and left-dir? (not right-dir?)) #t]
    [(and (not left-dir?) right-dir?) #f]
    [else (string<? (entry-name left) (entry-name right))]))

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
                                 (merge-sort (read-dir path) #:comparator path-sort<?)))))]
            [else void]))))

  ;; Do not render the root itself as an entry. Start from its children.
  (if (is-dir? p)
      (flatten (map (fn (x) (tree-rec x "")) (merge-sort (read-dir p) #:comparator path-sort<?)))
      (flatten (tree-rec p ""))))

;;@doc
;; Open the currently selected line
(define (open-file-from-picker)
  (when (currently-in-labelled-buffer? FILE-TREE)
    (define file-to-open (current-tree-entry))
    (when (string? file-to-open)
      ;; Close tree buffer so normal buffer navigation does not keep returning here.
      (helix.buffer-close!)
      (helix.open file-to-open)
      (set-normal-mode!))))

(define (shell-escape path)
  (define (escape-char ch)
    (cond
      [(char=? ch #\\) "\\\\"]
      [(char=? ch #\") "\\\""]
      [(char=? ch #\$) "\\$"]
      [(char=? ch #\`) "\\`"]
      [else (string ch)]))
  (apply string-append (map escape-char (string->list path))))

(define (refresh-when target predicate)
  (define max-attempts 40)
  (define (loop attempts)
    (if (or (<= attempts 0)
            (predicate target))
        (refresh-file-tree)
        (enqueue-thread-local-callback-with-delay
         50
         (lambda ()
           (loop (- attempts 1))))))
  (loop max-attempts))

(define (refresh-when-path-exists target)
  (refresh-when target path-exists?))

(define (refresh-when-path-missing target)
  (refresh-when target (lambda (path) (not (path-exists? path)))))

;;@doc
;; Delete selected file or directory.
(define (delete-path)
  (when (currently-in-labelled-buffer? FILE-TREE)
    (define target (current-tree-entry))
    (when (string? target)
      (helix-prompt!
       (string-append "Delete " (file-name target) "? [y/N] ")
       (lambda (answer)
         (when (or (equal? answer "y") (equal? answer "Y"))
           (define quoted (string-append "\"" (shell-escape target) "\""))
            (if (is-dir? target)
                (helix.run-shell-command (string-append "rm -rf -- " quoted))
                (helix.run-shell-command (string-append "rm -f -- " quoted)))
             (refresh-when-path-missing target)))))))

;;@doc
;; Rename selected file or directory.
(define (rename-path)
  (when (currently-in-labelled-buffer? FILE-TREE)
    (define source (current-tree-entry))
    (when (string? source)
      (define source-name (file-name source))
      (define source-parent (path-parent source))
      (helix-prompt!
       (string-append "Rename " source-name " to: ")
       (lambda (answer)
         (when (and (string? answer)
                    (not (equal? answer ""))
                    (not (equal? answer source-name)))
           (define destination
             (if (and (> (string-length answer) 0)
                      (equal? (substring answer 0 1) "/"))
                 (path-clean answer)
                 (path-clean (string-append source-parent "/" answer))))
           (when (and (string? destination)
                      (not (equal? destination ""))
                      (not (path=? destination source)))
             (define quoted-source (string-append "\"" (shell-escape source) "\""))
             (define quoted-destination (string-append "\"" (shell-escape destination) "\""))
             (helix.run-shell-command (string-append "mv -- " quoted-source " " quoted-destination))
             (set! *file-tree-target-path* destination)
             (unfold-path-to-target! *file-tree-root* destination)
             (refresh-when destination
                           (lambda (path)
                             (and (path-exists? path)
                                  (not (path-exists? source))))))))))))

;; Initialize all roots to be flat so that we don't blow things up, recursion only goes in to things
;; that are expanded
(define (current-doc-id)
  (let* ([focus (editor-focus)])
    (editor->doc-id focus)))

(define (create-file-tree-buffer-if-needed)
  (when (or (not (maybe-fetch-doc-id FILE-TREE))
            (not (editor-doc-exists? (fetch-doc-id FILE-TREE))))
    (make-new-labelled-buffer! #:label FILE-TREE #:display-name "_hidden_tree")))

(define (render-file-tree)
  (define root (or *file-tree-root* (helix-find-workspace)))
  (define moved-to-target? #f)

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
      (helix.static.goto_line_start)
      (focus-line-near-top!)
      (set! moved-to-target? #t))
    (set! *file-tree-target-path* #f))

  (unless moved-to-target?
    (when (> (length *file-tree*) 0)
      (helix.goto-line 1)
      (helix.static.goto_line_start)))

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
    (define directory-to-fold (current-tree-entry))
    (when (and (string? directory-to-fold) (is-dir? directory-to-fold))
      (begin
        ;; If its already folded, unfold it
        (if (hash-try-get *directories* directory-to-fold)
            (unfold! directory-to-fold)
            (fold! directory-to-fold))

        (update-file-tree)))))

;;@doc
;; Create a file or directory under wherever we are.
;; If input ends with '/', a directory is created.
(define (create-path)
  (when (currently-in-labelled-buffer? FILE-TREE)
    (define currently-selected (current-tree-entry))
    (define prompt
      (if (and (string? currently-selected) (is-dir? currently-selected))
          (string-append "New path: " currently-selected "/")
          (if (string? currently-selected)
              (string-append "New path: "
                             (trim-end-matches currently-selected (file-name currently-selected)))
              (string-append "New path: " (or *file-tree-root* (helix-find-workspace)) "/"))))

    (helix-prompt!
     prompt
     (lambda (result)
       (when (and (string? result) (not (equal? result "")))
         (define path-name (string-append (trim-start-matches prompt "New path: ") result))
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

           (refresh-when-path-exists target-path)))))))

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
  (when (editor-doc-exists? (fetch-doc-id FILE-TREE))
    (editor-switch-action! (fetch-doc-id FILE-TREE) (Action/Replace))
    (update-file-tree)))

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
