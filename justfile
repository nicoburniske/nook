set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

age_key := "/etc/age/identity.txt"
host := `hostname -s`
system := `uname -s`
nix_run := "nix run --no-warn-dirty --inputs-from ."
nix_shell := "nix shell --no-warn-dirty --inputs-from ."

gen:
    nix run .#gen-flake

fmt: fmt-nix fmt-scm fmt-nu

fmt-nix:
    {{ nix_run }} .#nix-tidy -- .

fmt-nu:
    {{ nix_run }} .#{{ host }}.nufmt -- .

fmt-scm:
    #! /usr/bin/env -S {{ nix_shell }} nixpkgs#emacs-nox -c nu
    let files = glob modules/helix/plugins/**/*.scm
    for file in $files {
        emacs --batch $file --eval '(let ((inhibit-message t)) (indent-region (point-min) (point-max)))' -f save-buffer
    }

clean:
    nix-collect-garbage -d

age-key-create:
    if [ -e "{{ age_key }}" ]; then \
        echo "error: {{ age_key }} already exists"; \
        exit 1; \
    fi
    sudo install -d -m 0700 -o root -g root "$(dirname "{{ age_key }}")"
    sudo age-keygen -pq -o "{{ age_key }}"
    sudo chmod 0400 "{{ age_key }}"
    sudo chown root:root "{{ age_key }}"
    sudo age-keygen -y "{{ age_key }}"

age-key-public:
    sudo age-keygen -y "{{ age_key }}"

agenix-encrypt file:
    pub="$(sudo age-keygen -y "{{ age_key }}")"; \
    tmp="$(mktemp "{{ file }}.tmp.XXXXXX")"; \
    age -r "$pub" -o "$tmp" "{{ file }}"; \
    mv "$tmp" "{{ file }}"

agenix-edit file:
    sudo env XDG_CONFIG_HOME="$HOME/.config" EDITOR="hx" RULES=./secrets.nix agenix -e "{{ file }}" -i "{{ age_key }}"
    sudo chown "$(id -un):$(id -gn)" "{{ file }}"

switch target=host: (_rebuild "switch" target)

test target=host: (_rebuild "test" target)

boot target=host: (_rebuild "boot" target)

check target=host: (_rebuild "check" target)

_rebuild action target:
    #! /usr/bin/env nu
    let system = "{{ system }}"
    let action = "{{ action }}"
    let flake = ".#{{ target }}"
    let ssh_auth_sock = $"SSH_AUTH_SOCK=($env.SSH_AUTH_SOCK? | default '')"

    let run_rebuild = {|| match [$system $action] {
        [Darwin, switch] => {
            sudo darwin-rebuild switch --flake $flake
        }
        [Darwin, check] => {
            sudo darwin-rebuild build --flake $flake --dry-run
        }
        [Darwin, _] => {
            error make {msg: $"($action) is not supported by darwin-rebuild"}
        }
        [Linux, switch] => {
            let pending = git status --porcelain --untracked-files=no
            if not ($pending | is-empty) {
                error make {msg: "pending git changes"}
            }
            sudo env $ssh_auth_sock nixos-rebuild switch --flake $flake
        }
        [Linux, test] => {
            sudo env $ssh_auth_sock nixos-rebuild test --flake $flake
        }
        [Linux, boot] => {
            sudo env $ssh_auth_sock nixos-rebuild boot --flake $flake
        }
        [Linux, check] => {
            sudo env $ssh_auth_sock nixos-rebuild dry-build --flake $flake
        }
        [_, _] => {
            error make {msg: $"unsupported system: ($system)"}
        }
    }}

    let elapsed = timeit { do $run_rebuild }
    let elapsed_ms = ($elapsed / 1ms | math floor)
    print $"took ($elapsed_ms // 1000)sec ($elapsed_ms mod 1000)ms"

update:
    nix flake update
