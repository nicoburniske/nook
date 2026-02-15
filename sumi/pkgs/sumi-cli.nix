{
  bash,
  nushell,
  util-linux,
  writeShellApplication,
}:
writeShellApplication {
  name = "sumi";

  runtimeInputs = [
    bash
    nushell
    util-linux
  ];

  text = ''
    exec ${nushell}/bin/nu ${./sumi-cli.nu} "$@"
  '';
}
