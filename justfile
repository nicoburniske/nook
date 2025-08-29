fmt:
    nix run nixpkgs#alejandra -- .

build:
    sudo nixos-rebuild build --flake .#nixos

test:
    sudo nixos-rebuild test --flake .#nixos

check:
    sudo nixos-rebuild build --flake .#nixos --dry-run

switch:
    sudo nixos-rebuild switch --flake .#nixos

clean:
    sudo nix-collect-garbage -d