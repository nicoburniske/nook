{
  config,
  pkgs,
  ...
}: {
  stylix.targets.zen-browser = {
    enable = true;
    profileNames = ["nico"];
  };

  programs.zen-browser = {
    enable = true;

    profiles = {
      nico = {
        name = "nico";
        isDefault = true;
        settings = {
          "zen.tabs.vertical" = true;
          "zen.tabs.vertical.right-side" = true;
        };

        containersForce = true;
        containers = {
          Personal = {
            color = "blue";
            icon = "fingerprint";
            id = 1;
          };
          Foundation = {
            color = "orange";
            icon = "briefcase";
            id = 2;
          };
        };

        spacesForce = true;
        spaces = {
          personal = {
            name = "personal";
            id = "6f9e2a05-60d9-4528-816d-20bb72246f05";
            position = 1;
            icon = "🏠";
            container = 1;
          };
          foundation = {
            name = "foundation";
            id = "a1b2c3d4-e5f6-7890-abcd-ef1234567890";
            position = 2;
            icon = "💼";
            container = 2;
          };
        };
      };
    };

    policies = {
      DisableAppUpdate = true;
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DontCheckDefaultBrowser = true;
      NoDefaultBookmarks = true;
      OfferToSaveLogins = false;
      SkipTermsOfUse = true;

      PictureInPicture = {
        Value = false;
        Locked = true;
      };

      Homepage = {
        StartPage = "previous-session";
        Locked = true;
      };

      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };
    };
  };
}
