(require "helix/editor.scm")
(require "helix/misc.scm")
(require (prefix-in helix. "helix/commands.scm"))

(provide lazygit-stash
         lazygit-blame-current-file)

(define (current-path)
  (let* ([focus (editor-focus)]
         [focus-doc-id (editor->doc-id focus)])
    (editor-document->path focus-doc-id)))

(define (shell-quote value)
  (string-append "'" (string-join (split-many value "'") "'\\''") "'"))

(define (lazygit-command . args)
  (string-append
   "kitten @ kitten --match id:\"$KITTY_WINDOW_ID\" workspace.py 2 --replace -- "
   (string-join args " ")
   " >/dev/null 2>&1 &"))

;;@doc
;; stash
(define (lazygit-stash)
  (helix.run-shell-command (lazygit-command "stash")))

;;@doc
;; blame
(define (lazygit-blame-current-file)
  (define path (current-path))
  (if (string? path)
      (helix.run-shell-command (lazygit-command "-f" (shell-quote path)))
      (set-status! "lazygit blame requires a file-backed buffer")))
