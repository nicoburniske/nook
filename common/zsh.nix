{config, ...}: {
  programs.zsh = {
    enable = true;

    enableCompletion = true;
    autosuggestion = {
      enable = true;
    };
    syntaxHighlighting = {
      enable = true;
    };

    oh-my-zsh = {
      enable = true;
      plugins = [
        "gh"
        "zoxide"
        "bun"
        "docker"
        "docker-compose"
      ];
    };

    history = {
      size = 999999999;
      save = 999999999;
      path = "${config.home.homeDirectory}/.zsh_history";
      ignoreDups = true;
      share = false;
    };

    initContent = ''
      WORDCHARS=''${WORDCHARS//[\/]}

      bindkey '^I'   complete-word
      bindkey '^[[Z' autosuggest-accept

      export PATH=~/.cargo/bin:$PATH

      function yy() {
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
        yazi "$@" --cwd-file="$tmp"
        if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
          cd -- "$cwd"
        fi
        rm -f -- "$tmp"
      }

      alias nix-shell='nix-shell --run $SHELL'
      nix() {
        if [[ $1 == "develop" ]]; then
          shift
          command nix develop -c $SHELL "$@"
        else
          command nix "$@"
        fi
      }
    '';

    shellAliases = {
      lg = "lazygit";
    };
  };
}
