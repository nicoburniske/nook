{barFontScale}: {
  barType = "floating";
  showCapsule = true;
  capsuleOpacity = 1;
  capsuleColorKey = "none";
  density = "default";
  showOutline = true;
  widgetSpacing = 7;
  contentPadding = 14;
  fontScale = barFontScale;
  backgroundOpacity = 0;
  useSeparateOpacity = true;
  marginHorizontal = 4;
  marginVertical = 8;
  frameRadius = 2;
  outerCorners = false;
  middleClickAction = "none";
  rightClickAction = "none";
  mouseWheelAction = "none";
  widgets = {
    left = [
      {
        id = "Workspace";
        labelMode = "index";
        showApplications = false;
        showApplicationsHover = false;
        hideUnoccupied = false;
        enableScrollWheel = true;
        focusedColor = "primary";
        occupiedColor = "secondary";
        emptyColor = "secondary";
        fontWeight = "semibold";
        groupedBorderOpacity = 1;
        iconScale = 0.8;
        pillSize = 0.7;
        showBadge = true;
        unfocusedIconsOpacity = 1;
      }
    ];
    center = [];
    right = [
      {id = "Tray";}
      {id = "NotificationHistory";}
      {id = "Battery";}
      {
        id = "Volume";
        displayMode = "alwaysHide";
      }
      {
        id = "Bluetooth";
        displayMode = "alwaysHide";
      }
      {
        id = "Brightness";
        displayMode = "alwaysHide";
      }
      {
        id = "Clock";
        clockColor = "none";
        formatHorizontal = "HH:mm";
        tooltipFormat = "HH:mm ddd, MMM dd";
        useCustomFont = false;
      }
      {id = "ControlCenter";}
    ];
  };
}
