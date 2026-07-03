set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

age_key := "/etc/age/identity.txt"
host := `hostname -s`
system := `uname -s`
# pass ssh agent through sudo for git lfs
nixos_rebuild := 'sudo env SSH_AUTH_SOCK="${SSH_AUTH_SOCK:-}" nixos-rebuild'

gen:
    nix run .#gen-flake

fmt: fmt-nix fmt-scm

fmt-nix:
    nix run .#nix-tidy -- .
    nix run nixpkgs#alejandra -- -q .

fmt-scm:
    nix shell nixpkgs#emacs-nox nixpkgs#fd -c \
        fd '\.scm$' modules/helix/plugins \
            -x emacs --batch {} \
                --eval '(indent-region (point-min) (point-max))' \
                -f save-buffer

clean:
    nix-collect-garbage -d

age-key-create:
    if [ -e "{{age_key}}" ]; then \
        echo "error: {{age_key}} already exists"; \
        exit 1; \
    fi
    sudo install -d -m 0700 -o root -g root "$(dirname "{{age_key}}")"
    sudo age-keygen -pq -o "{{age_key}}"
    sudo chmod 0400 "{{age_key}}"
    sudo chown root:root "{{age_key}}"
    sudo age-keygen -y "{{age_key}}"

age-key-public:
    sudo age-keygen -y "{{age_key}}"

agenix-encrypt file:
    pub="$(sudo age-keygen -y "{{age_key}}")"; \
    tmp="$(mktemp "{{file}}.tmp.XXXXXX")"; \
    age -r "$pub" -o "$tmp" "{{file}}"; \
    mv "$tmp" "{{file}}"

agenix-edit file:
    sudo env XDG_CONFIG_HOME="$HOME/.config" EDITOR="hx" RULES=./secrets.nix agenix -e "{{file}}" -i "{{age_key}}"
    sudo chown "$(id -un):$(id -gn)" "{{file}}"

switch target=host: (_rebuild "switch" target)

test target=host: (_rebuild "test" target)

boot target=host: (_rebuild "boot" target)

check target=host: (_rebuild "check" target)

_rebuild action target:
    #!/usr/bin/env bash
    set -euo pipefail

    case "{{system}}:{{action}}" in
        Darwin:switch)
            sudo darwin-rebuild switch --flake ".#{{target}}"
            ;;
        Darwin:check)
            sudo darwin-rebuild build --flake ".#{{target}}" --dry-run
            ;;
        Darwin:*)
            echo "error: '{{action}}' is not supported by darwin-rebuild"
            exit 1
            ;;
        Linux:switch)
            if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
                echo "error: pending git changes"
                exit 1
            fi
            {{nixos_rebuild}} switch --flake ".#{{target}}"
            ;;
        Linux:test)
            {{nixos_rebuild}} test --flake ".#{{target}}"
            ;;
        Linux:boot)
            {{nixos_rebuild}} boot --flake ".#{{target}}"
            ;;
        Linux:check)
            {{nixos_rebuild}} dry-build --flake ".#{{target}}"
            ;;
        *)
            echo "error: unsupported system: {{system}}"
            exit 1
            ;;
    esac

update:
    nix flake update
