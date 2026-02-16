(require "splash.scm")
(require "cogs/keymaps.scm")

(define file-tree-base (deep-copy-global-keybindings))
(merge-keybindings file-tree-base FILE-TREE-KEYBINDINGS)
(set-global-buffer-or-extension-keymap (hash FILE-TREE file-tree-base))

(keymap (global)
        (normal (C-f ":create-file-tree")))

(when (equal? (command-line) '("hx"))
  (show-splash))
