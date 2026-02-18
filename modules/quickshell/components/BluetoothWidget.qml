import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Rectangle {
  id: root

  required property var panelWindow
  required property var theme
  required property var popupState

  color: "transparent"
  radius: theme.radius
  implicitWidth: 26
  implicitHeight: 22
  property bool showDebugState: true

  Process {
    id: openBtui
    command: ["kitty", "--class", "bluetui", "bluetui"]
  }

  function connectedCount() {
    if (!Bluetooth.defaultAdapter) return 0;

    var count = 0;
    var devices = Bluetooth.defaultAdapter.devices.values;
    for (var i = 0; i < devices.length; i++) {
      if (devices[i].connected) count += 1;
    }

    return count;
  }

  function iconText() {
    var adapter = Bluetooth.defaultAdapter;
    if (!adapter || !adapter.enabled) return "󰂲";
    return connectedCount() > 0 ? "" : "󰂯";
  }

  function sortDevices(values) {
    values.sort(function(a, b) {
      if ((b.connected ? 1 : 0) !== (a.connected ? 1 : 0)) {
        return (b.connected ? 1 : 0) - (a.connected ? 1 : 0);
      }

      if ((b.paired ? 1 : 0) !== (a.paired ? 1 : 0)) {
        return (b.paired ? 1 : 0) - (a.paired ? 1 : 0);
      }

      var aName = (a.name && a.name.length > 0) ? a.name : (a.deviceName || "");
      var bName = (b.name && b.name.length > 0) ? b.name : (b.deviceName || "");
      return aName.localeCompare(bName);
    });

    return values;
  }

  function isKnownDevice(device) {
    return !!(device.connected || device.paired || device.bonded);
  }

  function knownDevices() {
    var values = [...Bluetooth.devices.values].filter(function(device) {
      return root.isKnownDevice(device) && !device.connected;
    });

    return sortDevices(values);
  }

  function connectedDevices() {
    var values = [...Bluetooth.devices.values].filter(function(device) {
      return !!device.connected;
    });

    return sortDevices(values);
  }

  function deviceName(device) {
    return device.name && device.name.length > 0 ? device.name : device.deviceName;
  }

  function deviceDebugState(device) {
    return "s=" + device.state + " p=" + device.paired + " b=" + device.bonded + " t=" + device.trusted;
  }

  function isLoading(device) {
    return !!(device && (device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting));
  }

  component DeviceRow: Rectangle {
    id: row

    required property var device
    required property bool connectedSection

    readonly property bool loading: root.isLoading(device)

    width: content.width
    implicitHeight: root.showDebugState ? 42 : 30
    radius: theme.radius
    color: "transparent"
    border.color: connectedSection ? theme.base0C : theme.widgetBorder
    border.width: 1

    Column {
      anchors.fill: parent
      anchors.leftMargin: 8
      anchors.rightMargin: 8
      anchors.topMargin: 4
      anchors.bottomMargin: 4
      spacing: 2

      RowLayout {
        width: parent.width

        Text {
          Layout.fillWidth: true
          elide: Text.ElideRight
          text: root.deviceName(device)
          color: theme.fg
          font.family: theme.monospaceFont
          font.pixelSize: theme.fontSize
        }

        Text {
          text: connectedSection ? (loading ? "disconnecting" : "connected") : (loading ? "connecting" : "disconnected")
          color: (connectedSection || loading) ? theme.base0C : theme.base03
          font.family: theme.monospaceFont
          font.pixelSize: theme.fontSize
        }
      }

      Text {
        visible: root.showDebugState
        text: root.deviceDebugState(device)
        color: theme.base03
        font.family: theme.monospaceFont
        font.pixelSize: theme.fontSize
        elide: Text.ElideRight
        width: parent.width
      }
    }

    TapHandler {
      enabled: !row.loading
      onTapped: {
        if (!Bluetooth.defaultAdapter || !Bluetooth.defaultAdapter.enabled) return;
        if (row.loading) return;
        device.connected = !row.connectedSection;
      }
    }
  }

  Text {
    anchors.centerIn: parent
    color: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? theme.fg : theme.base03
    font.family: theme.emojiFont
    font.pixelSize: theme.fontSize
    text: root.iconText()
  }

  MouseArea {
    anchors.fill: parent
    onClicked: {
      popupState.activePopup = popupState.activePopup === "bluetooth" ? "" : "bluetooth";
    }
  }

  PopupMenu {
    id: btPopup

    panelWindow: root.panelWindow
    popupState: root.popupState
    popupId: "bluetooth"
    triggerItem: root
    theme: root.theme
    menuWidth: 300

    Column {
      id: content
      width: parent.width
      spacing: 6

      RowLayout {
        width: parent.width

        Item {
          implicitWidth: launchBtuiRow.implicitWidth
          implicitHeight: 22

          RowLayout {
            id: launchBtuiRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Text {
              id: btLabel
              text: "bluetooth"
              color: theme.fg
              font.family: theme.monospaceFont
              font.pixelSize: theme.fontSize
              Layout.alignment: Qt.AlignVCenter
            }

            Text {
              id: btCog
              text: "󰒓"
              color: theme.fg
              font.family: theme.emojiFont
              font.pixelSize: theme.fontSize
              Layout.alignment: Qt.AlignVCenter
            }
          }

          MouseArea {
            anchors.fill: parent
            onClicked: {
              popupState.activePopup = "";
              openBtui.startDetached();
            }
          }
        }

        Item {
          Layout.fillWidth: true
        }

        Rectangle {
          color: "transparent"
          implicitWidth: 34
          implicitHeight: 22
          Layout.alignment: Qt.AlignRight

          Rectangle {
            id: powerSwitch
            anchors.centerIn: parent
            width: 34
            height: 18
            radius: 9
            border.width: 1
            border.color: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? theme.base0C : theme.widgetBorder
            color: Qt.rgba(0, 0, 0, 0)

            Rectangle {
              width: 12
              height: 12
              radius: 6
              y: 3
              x: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? 18 : 4
              color: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? theme.base0C : theme.base03

              Behavior on x {
                NumberAnimation { duration: 120 }
              }
            }

            MouseArea {
              anchors.fill: parent
              onClicked: {
                if (Bluetooth.defaultAdapter) {
                  Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
                }
              }
            }
          }
        }
      }

      RowLayout {
        visible: root.connectedDevices().length > 0
        width: content.width
        spacing: 8

        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 1
          color: theme.widgetBorder
        }

        Text {
          text: "connected"
          color: theme.fg
          font.family: theme.monospaceFont
          font.pixelSize: theme.fontSize
        }

        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 1
          color: theme.widgetBorder
        }
      }

      Repeater {
        model: ScriptModel {
          values: root.connectedDevices()
        }

        DeviceRow {
          required property var modelData
          device: modelData
          connectedSection: true
        }
      }

      Repeater {
        model: ScriptModel {
          values: root.knownDevices()
        }

        DeviceRow {
          required property var modelData
          device: modelData
          connectedSection: false
        }
      }

      Rectangle {
        visible: !Bluetooth.defaultAdapter || (root.connectedDevices().length === 0 && root.knownDevices().length === 0)
        width: content.width
        implicitHeight: 30
        radius: theme.radius
        color: "transparent"
        border.color: theme.widgetBorder
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: !Bluetooth.defaultAdapter ? "no bluetooth adapter" : "no saved devices"
          color: theme.base03
          font.family: theme.monospaceFont
          font.pixelSize: theme.fontSize
        }
      }
    }
  }
}
