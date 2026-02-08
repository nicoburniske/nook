fmt:
    nix run nixpkgs#alejandra -- .

clean:
    nix-collect-garbage -d

darwin:
    sudo darwin-rebuild switch --flake .#fuji

darwin-check:
    sudo darwin-rebuild build --flake .#fuji --dry-run

nixos:
    @if [ -n "$(git status --porcelain)" ]; then \
        echo "error: pending git changes"; \
        exit 1; \
    fi
    sudo nixos-rebuild switch --flake .#snowflake

nixos-test:
    sudo nixos-rebuild test --flake .#snowflake

nixos-check:
    sudo nixos-rebuild dry-build --flake .#snowflake

update:
    nix flake update

quickshell-dev:
    systemctl --user stop quickshell.service || true
    qs -p "$HOME/.config/quickshell/shell.qml" -n -d -v

quickshell-service:
    systemctl --user restart quickshell.service

quickshell-prod:
    pkill -f '/bin/qs( |$)' || true
    systemctl --user reset-failed quickshell.service || true
    systemctl --user restart quickshell.service
    systemctl --user status quickshell.service --no-pager -l
