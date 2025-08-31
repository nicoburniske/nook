
fmt:
    nix run nixpkgs#alejandra -- .

clean:
    nix-collect-garbage -d

home:
    #!/usr/bin/env bash
    if [[ "$(uname)" == "Darwin" ]]; then
        nix run home-manager -- switch --flake .#nico@macos
    else
        nix run home-manager -- switch --flake .#nico@nixos
    fi

system:
    #!/usr/bin/env bash
    if [[ "$(uname)" == "Darwin" ]]; then
        darwin-rebuild switch --flake .#fuji
    else
        nixos-rebuild switch --flake .#snowflake
    fi

check:
    #!/usr/bin/env bash
    if [[ "$(uname)" == "Darwin" ]]; then
        darwin-rebuild build --flake .#fuji --dry-run
    else
        nixos-rebuild build --flake .#snowflake --dry-run
    fi

darwin:
    darwin-rebuild switch --flake .#fuji

darwin-check:
    darwin-rebuild build --flake .#fuji --dry-run

nixos:
    nixos-rebuild switch --flake .#snowflake

nixos-check:
    nixos-rebuild build --flake .#snowflake --dry-run

update:
    nix flake update

info:
    #!/usr/bin/env bash
    echo "Operating System: $(uname)"
    echo "Hostname: $(hostname)"
    if [[ "$(uname)" == "Darwin" ]]; then
        echo "Configuration: darwinConfigurations.fuji"
        echo "Home Manager: homeConfigurations.nico@macos"
    else
        echo "Configuration: nixosConfigurations.snowflake"
        echo "Home Manager: homeConfigurations.nico@nixos"
    fi
