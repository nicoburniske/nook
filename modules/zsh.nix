{...}: let
  mkZshCommon = {
    config,
    pkgs,
  }: let
    configHome = config.lib.sumi.paths.config;
  in {
    enable = true;

    interactiveShellInit = ''
      WORDCHARS=''${WORDCHARS//[\/]}

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

    promptInit = ''
      bindkey '^I' complete-word
      bindkey '^[[Z' autosuggest-accept
      source "${pkgs.fzf}/share/fzf/key-bindings.zsh"
      eval "$(${pkgs.oh-my-posh}/bin/oh-my-posh init zsh --config "${configHome}/ohmyposh/config.json")"
    '';
  };

  direnv = {
    enable = true;
    nix-direnv.enable = true;
    settings = {
      global = {
        hide_env_diff = true;
        log_filter = "^$";
      };
    };
  };
in {
  flake.modules.nixos.zsh = {
    config,
    pkgs,
    ...
  }: let
    common = mkZshCommon {inherit config pkgs;};
  in {
    programs.direnv = direnv;

    programs.zoxide = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
    };

    programs.zsh =
      common
      // {
        histFile = "$HOME/.zsh_history";
        histSize = 999999999;
        enableCompletion = true;
        setOptions = [
          "HIST_IGNORE_DUPS"
          "HIST_FCNTL_LOCK"
        ];

        shellAliases = {
          lg = "lazygit";
        };

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
          ];
        };
      };
  };

  flake.modules.darwin.zsh = {
    config,
    pkgs,
    ...
  }: let
    common = mkZshCommon {inherit config pkgs;};
  in {
    programs.direnv = direnv;

    environment.systemPackages = [pkgs.zoxide];

    programs.zsh =
      common
      // {
        histFile = "$HOME/.zsh_history";
        histSize = 999999999;
        enableCompletion = true;
        enableAutosuggestions = true;
        enableSyntaxHighlighting = true;
        interactiveShellInit =
          common.interactiveShellInit
          + ''
            eval "$(${pkgs.zoxide}/bin/zoxide init zsh)"
            alias lg='lazygit'
          '';
      };
  };
}
