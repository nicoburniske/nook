{...}: {
  flake.modules.nixos.coolercontrol = {
    lib,
    pkgs,
    ...
  }: let
    profileUid = name: builtins.hashString "sha256" "coolercontrol-profile:${name}";
    profile = {
      case = profileUid "quiet case";
      caseCpu = profileUid "quiet case cpu";
      caseGpu = profileUid "quiet case gpu";
      cpu = profileUid "quiet cpu";
    };
    nct6799Uid = "00a4da18625f56275c89e2fcd25a83c08c5ad3326452fa7e252fcc8a89c92493";
    cpuUid = "9378f45b621719636560170d30c952878cd910cc15c883d07647dd9f96577a54";
    gpuUid = "97910386cac9bfce54b2c224e4aaef42cd953440cb57f1ff5ff46ac183bf338e";

    tomlValue = value:
      if builtins.isString value
      then builtins.toJSON value
      else if builtins.isBool value
      then lib.boolToString value
      else if builtins.isInt value || builtins.isFloat value
      then toString value
      else if builtins.isList value
      then "[${lib.concatMapStringsSep ", " tomlValue value}]"
      else if builtins.isAttrs value
      then inlineTable value
      else throw "Unsupported CoolerControl TOML value: ${builtins.typeOf value}";

    inlineTable = attrs: let
      renderPair = key: "${key} = ${tomlValue attrs.${key}}";
    in "{ ${lib.concatMapStringsSep ", " renderPair (builtins.attrNames attrs)} }";

    renderAttrs = attrs: let
      renderPair = key: "${key} = ${tomlValue attrs.${key}}";
    in
      lib.concatMapStringsSep "\n" renderPair (builtins.attrNames attrs);

    renderTable = name: attrs: ''
      [${name}]
      ${renderAttrs attrs}
    '';

    renderArrayTable = name: attrs: ''
      [[${name}]]
      ${renderAttrs attrs}
    '';

    quietCaseProfile = {
      uid = profile.case;
      name = "quiet case";
      p_type = "Mix";
      function_uid = "0";
      member_profile_uids = [
        profile.caseCpu
        profile.caseGpu
      ];
      mix_function_type = "Avg";
    };

    quietCaseCpuProfile = {
      uid = profile.caseCpu;
      name = "quiet case cpu";
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
      temp_source = {
        device_uid = cpuUid;
        temp_name = "temp1";
      };
    };

    quietCaseGpuProfile = {
      uid = profile.caseGpu;
      name = "quiet case gpu";
      p_type = "Graph";
      function_uid = "0";
      member_profile_uids = [];
      offset_profile = [];
      speed_profile = [
        [30.0 15]
        [50.0 25]
        [65.0 40]
        [80.0 65]
        [95.0 100]
      ];
      temp_min = 30.0;
      temp_max = 95.0;
      temp_source = {
        device_uid = gpuUid;
        temp_name = "temp1";
      };
    };

    quietCpuProfile = {
      uid = profile.cpu;
      name = "quiet cpu";
      p_type = "Graph";
      function_uid = "0";
      member_profile_uids = [];
      offset_profile = [];
      speed_profile = [
        [30.0 22]
        [60.0 34]
        [75.0 50]
        [90.0 78]
        [100.0 100]
      ];
      temp_min = 30.0;
      temp_max = 100.0;
      temp_source = {
        device_uid = cpuUid;
        temp_name = "temp1";
      };
    };

    configSections = [
      (renderTable "devices" {
        ${nct6799Uid} = "nct6799";
        ${cpuUid} = "AMD Ryzen 9 7900 12-Core Processor";
        ${gpuUid} = "Navi 48 [Radeon RX 9070/9070 XT/9070 GRE]";
      })

      (renderTable "legacy690" {})

      (renderTable "device-settings.${nct6799Uid}" {
        fan1 = {profile_uid = profile.case;};
        fan2 = {profile_uid = profile.cpu;};
        fan6 = {profile_uid = profile.case;};
      })

      (renderArrayTable "profiles" {
        uid = "0";
        name = "Unmanaged";
        p_type = "Default";
        function_uid = "0";
        member_profile_uids = [];
      })

      (renderArrayTable "profiles" quietCaseProfile)

      (renderArrayTable "profiles" quietCaseCpuProfile)

      (renderArrayTable "profiles" quietCaseGpuProfile)

      (renderArrayTable "profiles" quietCpuProfile)

      (renderArrayTable "functions" {
        uid = "0";
        name = "Default Function";
        f_type = "Identity";
      })

      (renderTable "settings" {
        apply_on_boot = true;
        liquidctl_integration = true;
        hide_duplicate_devices = true;
        no_init = false;
        startup_delay = 2;
        thinkpad_full_speed = false;
        compress_payload = true;
        drivetemp_suspend = false;
        sensors_auto_detect = true;
        device_listener_enabled = true;
      })
    ];

    configFile =
      pkgs.writeText "coolercontrol-config.toml"
      (lib.concatStringsSep "\n" configSections);
  in {
    boot.kernelModules = ["nct6775"];

    programs.coolercontrol.enable = true;

    systemd.services.coolercontrold.preStart = ''
      ${pkgs.coreutils}/bin/install -D -m 0644 ${configFile} /etc/coolercontrol/config.toml
    '';
  };
}
