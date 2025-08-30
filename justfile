# Unified justfile for NixOS and macOS configurations

# Common recipes
fmt:
    nix run nixpkgs#alejandra -- .

clean:
    nix-collect-garbage -d

# Home-manager recipes (work on both platforms)
home:
    #!/usr/bin/env bash
    if [[ "$(uname)" == "Darwin" ]]; then
        home-manager switch --flake .#nico@macos
    else
        home-manager switch --flake .#nico@nixos
    fi

home-build:
    #!/usr/bin/env bash
    if [[ "$(uname)" == "Darwin" ]]; then
        home-manager build --flake .#nico@macos
    else
        home-manager build --flake .#nico@nixos
    fi

# System-specific recipes (detect platform automatically)
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

test:
    #!/usr/bin/env bash
    if [[ "$(uname)" == "Darwin" ]]; then
        darwin-rebuild build --flake .#fuji
    else
        nixos-rebuild test --flake .#snowflake
    fi

# macOS-specific recipes
darwin:
    darwin-rebuild switch --flake .#fuji

darwin-check:
    darwin-rebuild build --flake .#fuji --dry-run

# NixOS-specific recipes  
nixos:
    nixos-rebuild switch --flake .#snowflake

nixos-check:
    nixos-rebuild build --flake .#snowflake --dry-run

# Utility recipes
update:
    nix flake update

# Show current system info
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