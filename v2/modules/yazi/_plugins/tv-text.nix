{
  lib,
  mkYaziPlugin,
}:
mkYaziPlugin {
  pname = "tv-text.yazi";
  version = "0-unstable-2025-10-19";

  src = ./_tv-text;

  meta = {
    description = "Launch Television 'text' search from Yazi and open results";
    homepage = "https://github.com/alexpasmantier/television";
    license = lib.licenses.mit;
  };
}
