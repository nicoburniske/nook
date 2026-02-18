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

(define (resolve-tree-root)
  (path-clean (helix.static.get-helix-cwd)))

(define (create-file-tree)
  (define target-path (current-doc-path))
  (define root (resolve-tree-root))
  (define directories (tree-unfold-path-to-target (hash) root target-path))
  (define state
    (FileTreeState root
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
