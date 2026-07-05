{
  commonModules.zsh = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.nook.zsh;
    aliases =
      config.sumi.zsh.aliases
      |> lib.mapAttrsToList (name: value: "alias -- ${lib.escapeShellArg name}=${lib.escapeShellArg value}")
      |> lib.concatStringsSep "\n";
    optionalDarwin = lib.optionalString pkgs.stdenv.isDarwin;
    optionalLinux = lib.optionalString pkgs.stdenv.isLinux;
  in {
    options = {
      nook.zsh = {
        interactiveShellInit = lib.mkOption {
          type = lib.types.lines;
          default = "";
        };
        promptInit = lib.mkOption {
          type = lib.types.lines;
          default = "";
        };
      };
      sumi.zsh.aliases = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
      };
    };
    config = {
      environment.systemPackages = with pkgs; [
        oh-my-zsh
        zoxide
        zsh-autosuggestions
        zsh-syntax-highlighting
      ];
      sumi = {
        zsh.aliases =
          {
            l = "ls -alh";
            ll = "ls -l";
            nix-shell = "nix-shell --run $SHELL";
          }
          // lib.optionalAttrs pkgs.stdenv.isLinux {
            ls = "ls --color=tty";
          };
        homeFile = {
          ".zshenv".value = ''
            setopt no_global_rcs
          '';
          ".zshrc".value = ''
            ${optionalLinux ''
              HOST=$(hostname --fqdn)
              [[ -r /etc/zinputrc ]] && . /etc/zinputrc
            ''}

            ${optionalDarwin ''
              HOST=$(hostname)
            ''}

            WORDCHARS=''${WORDCHARS//[\/]}
            export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=242"
            export ZSH_AUTOSUGGEST_STRATEGY=(history)

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

            export ZSH="${pkgs.oh-my-zsh}/share/oh-my-zsh"
            ZSH_CUSTOM="${pkgs.zsh-autosuggestions}/share/zsh"
            DISABLE_AUTO_TITLE=true
            plugins=(gh zsh-autosuggestions)
            mkdir -p "$HOME/.cache/oh-my-zsh"
            ZSH_CACHE_DIR="$HOME/.cache/oh-my-zsh"
            source "$ZSH/oh-my-zsh.sh"

            HISTFILE="$HOME/.zsh_history"
            HISTSIZE=999999999
            SAVEHIST=999999999
            setopt HIST_IGNORE_DUPS HIST_FCNTL_LOCK

            eval "$(${pkgs.zoxide}/bin/zoxide init --cmd ''${ZOXIDE_CMD_OVERRIDE:-z} zsh)"
            eval "$(${config.programs.direnv.package}/bin/direnv hook zsh)"

            ${cfg.interactiveShellInit}

            ${optionalLinux ''
              eval "$(${pkgs.coreutils}/bin/dircolors -b)"
            ''}

            ${aliases}

            bindkey '^I' complete-word
            bindkey '^[[Z' autosuggest-accept

            ${cfg.promptInit}

            source "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
            ZSH_HIGHLIGHT_HIGHLIGHTERS=(main)

            if [ "$TERM" = dumb ]; then
              unsetopt zle prompt_cr prompt_subst
              unset RPS1 RPROMPT
              PS1='$ '
              PROMPT='$ '
            fi
          '';
        };
      };
      programs = {
        direnv = {
          enable = true;
          enableZshIntegration = false;
          nix-direnv.enable = true;
          settings.global = {
            hide_env_diff = true;
            log_filter = "^$";
          };
        };
        zsh = {
          enable = true;
          promptInit = "";
        };
      };
    };
  };
}
