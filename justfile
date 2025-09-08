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

