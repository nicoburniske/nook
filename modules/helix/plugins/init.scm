(require "splash.scm")
(require "cogs/keymaps.scm")
(require "helix/editor.scm")

(keymap (global)
        (normal (C-f ":create-file-tree")
                (C-g ":sh kitty @ launch --copy-env --type=overlay --cwd=current --window-title=current lazygit >/dev/null")
                (space
                  (l
                    (a ":copy-absolute-location")
                    (r ":copy-location")
                    (s ":copy-location-snippet")
                    (u ":copy-location-url"))))
        (select
          (space
            (l
              (a ":copy-absolute-location")
              (r ":copy-location")
              (s ":copy-location-snippet")
              (u ":copy-location-url")))))

(define (plain-launch?)
  (let ([argv (command-line)])
    (or (null? argv)
        (= (length argv) 1))))

(define (initial-launch?)
  (null? (editor-all-documents)))

(when (and (plain-launch?) (initial-launch?))
  (show-splash))
