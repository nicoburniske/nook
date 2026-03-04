(require (prefix-in helix.static. "helix/static.scm"))
(require "helix/components.scm")
(require "helix/misc.scm")
(require "helix/editor.scm")
(require "./core.scm")
(require "./tree.scm")

(provide create-file-tree)

(define (current-doc-id)
  (let* ([focus (editor-focus)])
    (editor->doc-id focus)))

(define (current-doc-path)
  (path-clean (editor-document->path (current-doc-id))))

(define (starts-with? value prefix)
  (if (< (string-length value) (string-length prefix))
      #f
      (equal? (substring value 0 (string-length prefix)) prefix)))

(define (path-descendant-or-same? maybe-child maybe-parent)
  (if (and (string? maybe-child) (string? maybe-parent))
      (let ([child (path-clean maybe-child)]
            [parent (path-clean maybe-parent)])
        (or (path=? child parent)
            (starts-with? child (string-append parent "/"))))
      #f))

(define (resolve-workspace-root)
  (define workspace (helix-find-workspace))
  (if (and (string? workspace) (not (equal? workspace "")))
      (path-clean workspace)
      (path-clean (helix.static.get-helix-cwd))))

(define (directory-has-marker? directory marker)
  (path-exists? (string-append (path-clean directory) "/" marker)))

(define (find-project-root-upward start-directory)
  (define markers (list "Cargo.toml" ".git"))

  (define (has-marker? directory)
    (let loop ([rest markers])
      (if (null? rest)
          #f
          (if (directory-has-marker? directory (car rest))
              #t
              (loop (cdr rest))))))

  (let loop ([directory (path-clean start-directory)])
    (if (or (not (string? directory)) (equal? directory ""))
        #f
        (if (has-marker? directory)
            directory
            (let ([parent (path-parent directory)])
              (if (path=? parent directory)
                  #f
                  (loop parent)))))))

(define (resolve-tree-root target-path)
  (define workspace-root (resolve-workspace-root))
  (define target-directory (file-directory target-path))
  (cond
    [(path-descendant-or-same? target-path workspace-root) workspace-root]
    [(string? target-directory)
     (or (find-project-root-upward target-directory)
         target-directory)]
    [else workspace-root]))

(define (create-file-tree)
  (define target-path (current-doc-path))
  (define root (resolve-tree-root target-path))
  (define directories (tree-unfold-path-to-target (hash) root target-path))
  (define state
    (FileTreeState (box root)
                   (box '())
                   (box directories)
                   (box 0)
                   (box 0)
                   (box 1)
                   (box #t)
                   (box #f)
                   (box #f)
                   (box #f)
                   (box #f)
                   (box #f)
                   (box #f)
                   (box "")
                   (box 0)
                   (box '())
                   (box -1)))

  (tree-refresh! state target-path)

  (push-component!
   (new-component! "file-tree"
                   state
                   file-tree-render
                   (hash "handle_event" file-tree-event-handler))))
