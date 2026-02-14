{...}: {
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    settings = {
      global = {
        hide_env_diff = true;
        log_filter = "^$";
      };
    };
  };

  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;

    autosuggestions = {
      enable = true;
      highlightStyle = "fg=242";
    };

    syntaxHighlighting.enable = true;

    ohMyZsh = {
      enable = true;
      preLoaded = ''
        DISABLE_AUTO_TITLE=true
      '';
      plugins = [
        "gh"
        "zoxide"
        "bun"
        "docker"
        "docker-compose"
      ];
    };

    histSize = 999999999;
    histFile = "$HOME/.zsh_history";
    setOptions = [
      "HIST_IGNORE_DUPS"
      "HIST_FCNTL_LOCK"
    ];

    interactiveShellInit = ''
      WORDCHARS=''${WORDCHARS//[\/]}

      bindkey '^I' complete-word
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

      function set_terminal_title_precmd() {
        local dir="''${PWD##*/}"
        [[ "$dir" == "" ]] && dir="/"
        [[ "$HOME" == "$PWD" ]] && dir="~"
        echo -ne "\033]0;''${dir}\007"
      }

      function set_terminal_title_preexec() {
        local dir="''${PWD##*/}"
        [[ "$dir" == "" ]] && dir="/"
        [[ "$HOME" == "$PWD" ]] && dir="~"
        local cmd="''${1%% *}"
        echo -ne "\033]0;''${dir} [''${cmd}]\007"
      }

      autoload -Uz add-zsh-hook
      add-zsh-hook precmd set_terminal_title_precmd
      add-zsh-hook preexec set_terminal_title_preexec
    '';

    shellAliases = {
      lg = "lazygit";
      oc = "opencode";
    };
  };
}
