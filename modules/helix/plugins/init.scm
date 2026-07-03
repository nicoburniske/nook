(require "splash.scm")
(require "cogs/keymaps.scm")
(require "cogs/file-tree/init.scm")
(require "cogs/lazygit.scm")
(require "cogs/copy.scm")
(require "helix/editor.scm")

(keymap (global)
        (normal (C-f create-file-tree)
                (C-g lazygit)
                (space
                 (g
                  (g lazygit)
                  (s lazygit-stash)
                  (b lazygit-blame-current-file))
                 (l
                  (a copy-absolute-location)
                  (r copy-location)
                  (s copy-location-snippet)
                  (u copy-location-url))))
        (select
         (space
          (l
           (a copy-absolute-location)
           (r copy-location)
           (s copy-location-snippet)
           (u copy-location-url)))))

(let ([argv (command-line)])
  (when (and (or (null? argv) (= (length argv) 1))
             (null? (editor-all-documents)))
    (show-splash)))
