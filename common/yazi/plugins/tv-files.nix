{
  lib,
  mkYaziPlugin,
}:
mkYaziPlugin {
  pname = "tv-files.yazi";
  version = "0-unstable-2025-10-19";

  src = ./tv-files;

  meta = {
    description = "Launch Television 'files' search from Yazi and open results";
    homepage = "https://github.com/alexpasmantier/television";
    license = lib.licenses.mit;
  };
}
