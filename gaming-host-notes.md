# Gaming Host Notes

Notes for adding a new x86_64 NixOS desktop/gaming host to this repo using
Jovian-NixOS, a dedicated Steam user, and a separate programming user.

## Goal

- New desktop PC host, separate from `snowflake` laptop.
- Boot straight into Steam/GameScope Gaming Mode.
- Run Steam as a dedicated low-privilege user, likely `steam`.
- Keep the work/programming setup on the real user, likely `nico`.
- Use Plasma for Steam Desktop Mode because it is more plug-and-play for couch/TV use.
- Keep Niri for `nico`.

## Important Constraints

Jovian's autostart path owns the display manager:

```nix
jovian.steam.autoStart = true;
```

That enables SDDM autologin and sets the default session to `gamescope-wayland`.
This conflicts conceptually with this repo's current `greetd`/`regreet` module.
For the gaming host, either do not import `greet`, or gate `greetd` off when
`config.jovian.steam.autoStart` is true.

Jovian's `Switch to Desktop` launches `jovian.steam.desktopSession` as the same
user that runs Steam. It does not switch users. So if Steam runs as `steam`,
then `desktopSession = "plasma"` launches Plasma as `steam`, not `nico`.

That suggests two modes:

- Gaming mode: autologin to Steam as `steam`; Desktop Mode is Plasma as `steam`.
- Dev mode: login as `nico`; use Niri and the usual development config.

## Recommended Shape

Use a new x86_64 host, for example:

```nix
# flake.nix
systems = [
  "aarch64-linux"
  "aarch64-darwin"
  "x86_64-linux"
];
```

Then add a new host under `hosts/<name>`, with its own generated
`hardware-configuration.nix`.

Base gaming pieces:

```nix
{
  imports = [
    inputs.jovian.nixosModules.default
  ];

  services.desktopManager.plasma6.enable = true;

  users.users.steam = {
    isNormalUser = true;
    home = "/home/steam";
    createHome = true;
    hashedPassword = "!";
    extraGroups = [
      "audio"
      "video"
      "render"
      "input"
      "networkmanager"
      "users"
    ];
  };

  jovian.steam = {
    enable = true;
    autoStart = true;
    user = "steam";
    desktopSession = "plasma";
  };

  # Start conservative on desktop hardware.
  jovian.devices.steamdeck.enable = false;
  jovian.steamos.useSteamOSConfig = false;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  programs.gamemode.enable = true;
}
```

If the desktop uses an AMD GPU:

```nix
{
  jovian.hardware.has.amd.gpu = true;
}
```

## Specialisations

NixOS specialisations are a good fit for this host:

- default or `gaming`: Jovian autostart, Steam user, Plasma Desktop Mode.
- `dev`: no Jovian autostart, greetd/Niri for `nico`.

Example sketch:

```nix
{
  specialisation.dev.configuration = {
    system.nixos.tags = [ "dev" ];

    jovian.steam.autoStart = false;

    # Re-enable the normal login path here, or import the repo's greet module
    # only in this specialisation.
    services.greetd.enable = true;
    programs.niri.enable = true;
  };
}
```

Specialisations appear in the boot menu. They can also be switched live:

```sh
sudo /nix/var/nix/profiles/system/specialisation/dev/bin/switch-to-configuration switch
sudo /nix/var/nix/profiles/system/specialisation/gaming/bin/switch-to-configuration switch
```

For this use case, rebooting into the desired specialisation is cleaner because
display managers, autologin, Steam/GameScope sessions, and user services are
stateful.

## Greetd Gating Pattern

One public config gates greetd when Jovian autostart is active. Same idea could
be used in this repo's `modules/greet/default.nix` if we want `greet` imported
unconditionally.

```nix
{
  services.greetd = {
    enable = true;
    settings.default_session =
      lib.mkIf (!(config.jovian.steam.autoStart or false)) {
        command = "...";
        user = "greeter";
      };
  };
}
```

Source:
[bdsqqq/dots system/login.nix](https://github.com/bdsqqq/dots/blob/774a61545012a3c8ed4373fb4e67c454003a2808/system/login.nix)

## Decky Loader

Decky Loader is a plugin system for Steam Deck/Gaming Mode. Jovian can enable it:

```nix
{
  jovian.decky-loader.enable = true;
}
```

Do not enable this first. Get Steam/GameScope working, then add Decky only if
Gaming Mode plugins are wanted. It adds a privileged service and plugin surface.

## Public Config References

### Custom PC / HTPC Setups

- [ErikBPF/desktop-nixos: `modules/hosts/orion/jovian.nix`](https://github.com/ErikBPF/desktop-nixos/blob/f9d9804333b2e6e789e453a64e66d25502e4da24/modules/hosts/orion/jovian.nix)
  - Desktop/HTPC setup with AMD GPU.
  - `jovian.steam.autoStart = true`.
  - `jovian.steam.desktopSession = "hyprland"`.
  - Includes important desktop-PC fixes:
    - strips Jovian's `-steamdeck` Steam wrapper behavior;
    - shims GameScope for 4K HDMI instead of Deck-style `eDP-1`.

- [Azelphur/nixfiles: `modules/nixos/roles/htpc.nix`](https://github.com/Azelphur/nixfiles/blob/70f4802918d35fbfd27af1d922f4408f222b1dbc/modules/nixos/roles/htpc.nix)
  - Clean HTPC role.
  - Enables Plasma 6.
  - `jovian.steam.autoStart = true`.
  - `jovian.steam.desktopSession = "plasma"`.
  - Adds CEC daemon integration for TV remote use.

- [jasonboukheir/dotfiles: `hosts/thebeast/specialisations/gaming/jovian.nix`](https://github.com/jasonboukheir/dotfiles/blob/ed7b2c161b36e9c74fecf48c3383fd10e5c73637/hosts/thebeast/specialisations/gaming/jovian.nix)
  - Best multi-user reference.
  - Sets `gaming.user = "gamer"`.
  - Runs Jovian as `gamer`.
  - Uses Plasma for Steam Desktop Mode.
  - Disables Steam Deck hardware config:
    `jovian.devices.steamdeck.enable = false`.
  - Disables broad SteamOS config:
    `jovian.steamos.useSteamOSConfig = false`.

- [jasonboukheir/dotfiles: `hosts/thebeast/users.nix`](https://github.com/jasonboukheir/dotfiles/blob/ed7b2c161b36e9c74fecf48c3383fd10e5c73637/hosts/thebeast/users.nix)
  - Defines dedicated `gamer` user.
  - Keeps normal user `jasonbk` separate.
  - Adds gaming-related groups conditionally.

- [jasonboukheir/dotfiles: dev specialisation](https://github.com/jasonboukheir/dotfiles/blob/ed7b2c161b36e9c74fecf48c3383fd10e5c73637/hosts/thebeast/specialisations/default.nix)
  - `specialisation.dev.configuration` disables gaming.
  - Dev imports enable greetd and Omarchy/Hyprland.
  - This is the closest model for gaming specialisation plus separate dev desktop.

- [JeremyEudy/nixos-configs: `jovian.nix`](https://github.com/JeremyEudy/nixos-configs/blob/2b3deb164fff7be8df5647ce6d79a14071e6342c/jovian.nix)
  - Defines a dedicated `tv` user.
  - Enables Jovian without Steam Deck hardware.
  - Starts `start-gamescope-session` via a custom systemd service on `tty7`.
  - Useful reference for a manual/non-autostart dedicated gaming user flow.

- [radioaddition/nixos-config: `base/gaming.nix`](https://github.com/radioaddition/nixos-config/blob/6647caa684c088cb0e5a8e82a5cd8498e9085053/base/gaming.nix)
  - Generic gaming module with Jovian.
  - Steam Deck hardware disabled.
  - Uses a `gaming-mode` specialisation that enables Jovian autostart.
  - Also enables normal Steam/GameScope support and AMD graphics.

- [nocoolnametom/nix-config: `hosts/common/optional/jovian.nix`](https://github.com/nocoolnametom/nix-config/blob/39891dd51f5d84310daa585a36d476df32569c2f/hosts/common/optional/jovian.nix)
  - Reusable optional Jovian module.
  - Plasma 6 Desktop Mode.
  - Adds Steam environment handling for VR/compat tools.

### Less Direct / Steam Deck-Oriented

These are less relevant for a custom desktop because they enable
`jovian.devices.steamdeck.enable = true` or are clearly Deck hosts:

- `alistairporter/nixos-config: khazaddum`
- `Moe1369/nix-fleet`
- most hosts named `steamdeck`, `deck`, `nixdeck`, or `jupiter`

## Practical Recommendation

For this repo, the likely design is:

1. Add `x86_64-linux` to `flake.nix`.
2. Add a new host under `hosts/<desktop-name>`.
3. Add Jovian as a flake input instead of relying on the local untracked checkout.
4. Create a host-specific gaming module:
   - `steam` normal user;
   - Jovian autostart as `steam`;
   - Plasma 6 Desktop Mode;
   - Steam Deck hardware disabled.
5. Add a `dev` specialisation:
   - Jovian autostart disabled;
   - `greet`/Niri enabled;
   - `nico` development modules enabled.
6. Do not enable Decky Loader initially.
