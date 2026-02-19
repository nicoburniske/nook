import Quickshell
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

Rectangle {
  id: root

  required property var panelWindow
  required property var theme
  required property var popupState
  property bool isHyprland: false

  color: "transparent"
  radius: theme.radius
  implicitHeight: 22
  implicitWidth: indicatorLabel.implicitWidth + 8

  readonly property var device: UPower.displayDevice

  function clampPercent(value) {
    return Math.max(0, Math.min(100, Math.round(value)));
  }

  function percentage() {
    if (!device || !device.ready || !device.isPresent) return 0;

    var energy = Number(device.energy);
    var capacity = Number(device.energyCapacity);
    if (capacity > 0 && energy === energy && capacity === capacity) {
      return clampPercent((energy / capacity) * 100);
    }

    var raw = Number(device.percentage);
    if (raw !== raw) return 0;

    if (raw >= 0 && raw <= 1) {
      return clampPercent(raw * 100);
    }

    return clampPercent(raw);
  }

  function chargingLike() {
    if (!device || !device.ready || !device.isPresent) return false;
    if (UPower.onBattery) return false;
    return percentage() < 99;
  }

  function batteryIcon() {
    if (!device || !device.ready || !device.isPresent) return "󰂑";

    var pct = percentage();
    if (pct >= 100) return "󰂅";
    if (chargingLike()) return "󰂄";

    var icons = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
    var index = Math.min(9, Math.floor(Math.max(0, Math.min(99, pct)) / 10));
    return icons[index];
  }

  function indicatorText() {
    if (!device || !device.ready || !device.isPresent) return batteryIcon();
    return batteryIcon() + " " + percentage() + "%";
  }

  function statusText() {
    if (!device || !device.ready) return "initializing";
    if (!device.isPresent) return "battery missing";

    if (UPower.onBattery) return "discharging";
    if (percentage() >= 99 && device.timeToFull <= 0) return "full";
    if (device.timeToFull > 0 || device.changeRate > 0.05) return "charging";
    return "plugged";
  }

  function formatDuration(seconds) {
    var value = Math.round(seconds || 0);
    if (value <= 0) return "";

    var hours = Math.floor(value / 3600);
    var minutes = Math.floor((value % 3600) / 60);

    if (hours > 0) return hours + "h " + minutes + "m";
    return minutes + "m";
  }

  function powerText() {
    if (!device || !device.ready || !device.isPresent) return "";

    var rate = Number(device.changeRate);
    if (rate !== rate) return "";

    var absRate = Math.abs(rate);
    if (absRate < 0.05) return "";
    return absRate.toFixed(1) + "W" + (UPower.onBattery ? "↓" : "↑");
  }

  function etaText() {
    if (!device || !device.ready || !device.isPresent) return "";

    if (UPower.onBattery && device.timeToEmpty > 0) return formatDuration(device.timeToEmpty) + " left";
    if (!UPower.onBattery && device.timeToFull > 0) return formatDuration(device.timeToFull) + " to full";
    return "";
  }

  function detailsText() {
    var parts = [];

    var power = powerText();
    if (power.length > 0) parts.push(power);

    var eta = etaText();
    if (eta.length > 0) parts.push(eta);

    return parts.join("  •  ");
  }

  function profileEntries() {
    var values = [
      {
        label: "saver",
        profile: PowerProfile.PowerSaver
      },
      {
        label: "balanced",
        profile: PowerProfile.Balanced
      }
    ];

    if (PowerProfiles.hasPerformanceProfile) {
      values.push({
        label: "performance",
        profile: PowerProfile.Performance
      });
    }

    return values;
  }

  function degradationText() {
    if (PowerProfiles.degradationReason === PerformanceDegradationReason.None) return "";
    return PerformanceDegradationReason.toString(PowerProfiles.degradationReason).toLowerCase();
  }

  Text {
    id: indicatorLabel
    anchors.centerIn: parent
    text: root.indicatorText()
    color: UPower.onBattery && root.percentage() <= 20 ? theme.danger : theme.fg
    font.family: theme.monospaceFont
    font.pixelSize: theme.fontSize
  }

  MouseArea {
    anchors.fill: parent
    onClicked: {
      popupState.activePopup = popupState.activePopup === "battery" ? "" : "battery";
    }
  }

  PopupMenu {
    id: popup

    panelWindow: root.panelWindow
    popupState: root.popupState
    popupId: "battery"
    triggerItem: root
    theme: root.theme
    menuWidth: 320

    Column {
      id: content
      width: parent.width
      spacing: 6

      Text {
        text: "battery"
        color: theme.fg
        font.family: theme.monospaceFont
        font.pixelSize: theme.fontSize
      }

      Rectangle {
        width: content.width
        implicitHeight: 44
        radius: theme.radius
        color: "transparent"
        border.color: UPower.onBattery && root.percentage() <= 20 ? theme.danger : theme.widgetBorder
        border.width: 1

        Column {
          anchors.fill: parent
          anchors.leftMargin: 8
          anchors.rightMargin: 8
          anchors.topMargin: 4
          anchors.bottomMargin: 4
          spacing: 2

          Text {
            text: root.percentage() + "% " + root.batteryIcon() + "  " + root.statusText()
            color: UPower.onBattery && root.percentage() <= 20 ? theme.danger : theme.fg
            font.family: theme.monospaceFont
            font.pixelSize: theme.fontSize
          }

          Text {
            text: root.detailsText().length > 0 ? root.detailsText() : "no power estimate"
            color: theme.base03
            font.family: theme.monospaceFont
            font.pixelSize: theme.fontSize
          }
        }
      }

      Text {
        text: "power profile"
        color: theme.fg
        font.family: theme.monospaceFont
        font.pixelSize: theme.fontSize
      }

      RowLayout {
        width: content.width
        spacing: 4

        Repeater {
          model: ScriptModel {
            values: root.profileEntries()
          }

          Rectangle {
            required property var modelData

            Layout.fillWidth: true
            implicitHeight: 28
            radius: theme.radius
            color: "transparent"
            border.width: 1
            border.color: PowerProfiles.profile === modelData.profile ? theme.base0C : theme.widgetBorder

            Text {
              anchors.centerIn: parent
              text: modelData.label
              color: PowerProfiles.profile === modelData.profile ? theme.base0C : theme.fg
              font.family: theme.monospaceFont
              font.pixelSize: theme.fontSize
            }

            TapHandler {
              onTapped: PowerProfiles.profile = modelData.profile
            }
          }
        }
      }

      Loader {
        active: root.isHyprland
        sourceComponent: Component {
          DisplayRefreshSection {
            theme: root.theme
            sectionWidth: content.width
            active: root.popupState.activePopup === "battery"
          }
        }
      }

      Text {
        visible: root.degradationText().length > 0
        text: "degraded: " + root.degradationText()
        color: theme.danger
        font.family: theme.monospaceFont
        font.pixelSize: theme.fontSize
      }
    }
  }
}
