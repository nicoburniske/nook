{
  nixosModules.opencode-remote = {
    config,
    host,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.nook.opencodeRemote;
    opencode = lib.getExe pkgs.opencode;
    opencodeRemote = pkgs.writeNuScriptBin "opencode-remote" {
      runtimeInputs = [
        pkgs.coreutils
        pkgs.openssh
      ];
      source = ''
        def --wrapped main [ssh_host: string, ...opencode_args: string] {
          let local_port = ($env.OPENCODE_REMOTE_PORT? | default "4096")
          let server_port = ($env.OPENCODE_REMOTE_SERVER_PORT? | default "4096")
          let remote_dir = ($env.OPENCODE_REMOTE_DIR? | default $env.PWD)
          let runtime_root = ($env.XDG_RUNTIME_DIR? | default "/tmp")
          let runtime_dir = (^mktemp -d $"($runtime_root)/opencode-remote.XXXXXX" | str trim)
          let control_socket = ($runtime_dir | path join "ssh")

          ^ssh ...[
            "-fNTM"
            "-S" $control_socket
            "-o" "BatchMode=yes"
            "-o" "ExitOnForwardFailure=yes"
            "-o" "ServerAliveInterval=15"
            "-o" "ServerAliveCountMax=3"
            "-L" $"($local_port):127.0.0.1:($server_port)"
            $ssh_host
          ]
          let tunnel_exit = $env.LAST_EXIT_CODE

          if $tunnel_exit != 0 {
            ^rmdir $runtime_dir
            exit $tunnel_exit
          }

          ^${opencode} attach $"http://127.0.0.1:($local_port)" --dir $remote_dir ...$opencode_args
          let opencode_exit = $env.LAST_EXIT_CODE
          ^ssh -S $control_socket -O exit $ssh_host | complete | ignore
          ^rmdir $runtime_dir | complete | ignore
          exit $opencode_exit
        }
      '';
    };
  in {
    options.nook.opencodeRemote = {
      server = {
        enable = lib.mkEnableOption "the OpenCode backend";
        port = lib.mkOption {
          type = lib.types.port;
          default = 4096;
          description = "Port on which the OpenCode backend listens";
        };
      };
      client.enable = lib.mkEnableOption "an OpenCode client for a remote backend";
    };
    config = {
      environment.systemPackages =
        lib.optional cfg.server.enable pkgs.opencode
        ++ lib.optionals cfg.client.enable [
          pkgs.opencode
          opencodeRemote
        ];
      systemd.services.opencode = lib.mkIf cfg.server.enable {
        description = "OpenCode backend";
        wantedBy = ["multi-user.target"];
        after = ["network-online.target"];
        wants = ["network-online.target"];
        environment.HOME = host.homeDirectory;
        serviceConfig = {
          User = host.user;
          WorkingDirectory = host.homeDirectory;
          ExecStart = "${opencode} serve --hostname 127.0.0.1 --port ${toString cfg.server.port}";
          Restart = "on-failure";
          RestartSec = 2;
          UMask = "0077";
        };
      };
    };
  };
}
