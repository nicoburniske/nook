{pkgs}:
pkgs.writeScriptBin "chromium-profile" ''
  #!${pkgs.python3}/bin/python
  import json
  import os
  import subprocess
  import sys
  from pathlib import Path

  chromium = "${pkgs.ungoogled-chromium}/bin/chromium"
  rofi = "${pkgs.rofi}/bin/rofi"
  data_dir = Path.home() / ".config" / "chromium"

  if not (data_dir / "Local State").exists():
      sys.exit("Chromium profile data not found.")

  with (data_dir / "Local State").open("r", encoding="utf-8") as handle:
      state = json.load(handle)

  profiles = sorted(
      [
          (data.get("name") or directory, directory)
          for directory, data in state.get("profile", {}).get("info_cache", {}).items()
          if directory != "System Profile" and (data.get("name") or directory) != "Your Chromium"
      ],
      key=lambda item: item[0].lower(),
  )

  if not profiles:
      sys.exit("No Chromium profiles found.")

  menu = "\n".join(name for name, _ in profiles)
  selection = subprocess.run(
      [rofi, "-dmenu", "-i", "-p", "Chromium profile"],
      input=menu,
      text=True,
      capture_output=True,
  ).stdout.strip()

  if not selection:
      sys.exit(0)

  directory = next((dir_name for name, dir_name in profiles if name == selection), None)
  if not directory:
      sys.exit(0)

  os.execv(chromium, [chromium, f"--user-data-dir={data_dir}", f"--profile-directory={directory}"])
''
