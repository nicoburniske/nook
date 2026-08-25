{
  nixosModules.coolercontrol = {
    lib,
    pkgs,
    ...
  }: let
    profileUid = name: builtins.hashString "sha256" "coolercontrol-profile:${name}";
    profile.case = profileUid "quiet case";
    nct6799Uid = "00a4da18625f56275c89e2fcd25a83c08c5ad3326452fa7e252fcc8a89c92493";
    cpuUid = "9378f45b621719636560170d30c952878cd910cc15c883d07647dd9f96577a54";
    gpuUid = "97910386cac9bfce54b2c224e4aaef42cd953440cb57f1ff5ff46ac183bf338e";
    customSensorsUid = "19e098e312e1b1b39163a343ea22b6ea17f18ec1a803ffe0ce44f5bacd6076ee";
    inherit (lib.toml) inlineTable;

    quietCaseProfile = {
      uid = profile.case;
      name = "quiet case";
      p_type = "Graph";
      function_uid = "0";
      member_profile_uids = [];
      offset_profile = [];
      speed_profile = [
        [0.0 0]
        [30.0 15]
        [50.0 30]
        [70.0 50]
        [85.0 70]
        [100.0 100]
      ];
      temp_min = 0.0;
      temp_max = 100.0;
      temp_source = inlineTable {
        device_uid = customSensorsUid;
        temp_name = "case_temp";
      };
    };

    settings = {
      devices = {
        ${nct6799Uid} = "nct6799";
        ${cpuUid} = "AMD Ryzen 9 7900 12-Core Processor";
        ${gpuUid} = "Navi 48 [Radeon RX 9070/9070 XT/9070 GRE]";
        ${customSensorsUid} = "Custom Sensors";
      };

      custom_sensors = [
        {
          id = "case_temp";
          cs_type = "Mix";
          mix_function = "WeightedAvg";
          sources = [
            {
              temp_source = inlineTable {
                device_uid = cpuUid;
                temp_name = "temp1";
              };
              weight = 75;
            }
            {
              temp_source = inlineTable {
                device_uid = gpuUid;
                temp_name = "temp1";
              };
              weight = 25;
            }
          ];
        }
      ];

      legacy690 = {};

      device-settings.${nct6799Uid} = {
        fan2 = inlineTable {profile_uid = profile.case;};
        fan7 = inlineTable {speed_fixed = 100;};
      };

      profiles = [
        {
          uid = "0";
          name = "Unmanaged";
          p_type = "Default";
          function_uid = "0";
          member_profile_uids = [];
        }
        quietCaseProfile
      ];

      functions = [
        {
          uid = "0";
          name = "Default Function";
          f_type = "Identity";
        }
      ];

      settings = {
        apply_on_boot = true;
        liquidctl_integration = false;
        hide_duplicate_devices = true;
        no_init = false;
        startup_delay = 2;
        thinkpad_full_speed = false;
        compress_payload = true;
        drivetemp_suspend = false;
        sensors_auto_detect = true;
        device_listener_enabled = true;
      };
    };

    configFile =
      pkgs.writeText "coolercontrol-config.toml"
      (lib.toml.toTOML settings);
  in {
    boot.kernelModules = ["nct6775"];

    programs.coolercontrol.enable = true;

    systemd.services.coolercontrold.preStart = ''
      ${pkgs.coreutils}/bin/install -D -m 0644 ${configFile} /etc/coolercontrol/config.toml
    '';
  };
}
