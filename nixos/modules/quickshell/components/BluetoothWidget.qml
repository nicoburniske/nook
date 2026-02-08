import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

Rectangle {
  id: root

  required property var panelWindow
  required property var theme

  color: "transparent"
  radius: theme.radius
  implicitWidth: 26
  implicitHeight: 22

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

  Text {
    anchors.centerIn: parent
    color: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? theme.fg : theme.base03
    font.family: theme.emojiFont
    font.pixelSize: theme.fontSize
    text: root.iconText()
  }

  MouseArea {
    anchors.fill: parent
    onClicked: btPopup.visible = !btPopup.visible
  }

  PopupWindow {
    id: btPopup

    anchor.window: panelWindow
    anchor.rect.x: 0
    anchor.rect.y: panelWindow.implicitHeight

    visible: false
    color: "transparent"

    implicitWidth: screen.width
    implicitHeight: Math.max(1, screen.height - panelWindow.implicitHeight)

    Rectangle {
      anchors.fill: parent
      color: "transparent"

      MouseArea {
        anchors.fill: parent
        onClicked: btPopup.visible = false
      }

      Rectangle {
        id: menu
        anchors.top: parent.top
        anchors.topMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 10
        width: 300
        implicitHeight: content.implicitHeight + 16
        radius: theme.radius
        color: theme.widgetBg
        border.color: theme.widgetBorder
        border.width: 1
        clip: true

        MouseArea {
          anchors.fill: parent
        }

        Column {
          id: content
          anchors.fill: parent
          anchors.margins: 8
          spacing: 6

          RowLayout {
            width: parent.width

            Text {
              text: "bluetooth"
              color: theme.fg
              font.family: theme.monospaceFont
              font.pixelSize: theme.fontSize
            }

            Item {
              Layout.fillWidth: true
            }

            Rectangle {
              color: "transparent"
              radius: theme.radius
              border.width: 1
              border.color: theme.widgetBorder
              implicitWidth: enabledLabel.implicitWidth + 10
              implicitHeight: enabledLabel.implicitHeight + 6

              Text {
                id: enabledLabel
                anchors.centerIn: parent
                text: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? "on" : "off"
                color: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? theme.base0C : theme.base03
                font.family: theme.monospaceFont
                font.pixelSize: theme.fontSize
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

          Repeater {
            model: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.devices : []

            Rectangle {
              required property var modelData
              property var device: modelData

              width: content.width
              implicitHeight: 30
              radius: theme.radius
              color: "transparent"
              border.color: theme.widgetBorder
              border.width: 1

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8

                Text {
                  Layout.fillWidth: true
                  elide: Text.ElideRight
                  text: device.name && device.name.length > 0 ? device.name : device.deviceName
                  color: theme.fg
                  font.family: theme.monospaceFont
                  font.pixelSize: theme.fontSize
                }

                Text {
                  text: device.connected ? "connected" : "disconnected"
                  color: device.connected ? theme.base0C : theme.base03
                  font.family: theme.monospaceFont
                  font.pixelSize: theme.fontSize
                }
              }

              MouseArea {
                anchors.fill: parent
                onClicked: {
                  if (!Bluetooth.defaultAdapter || !Bluetooth.defaultAdapter.enabled) return;

                  if (device.connected) {
                    device.disconnect();
                  } else if (device.paired || device.bonded) {
                    device.connect();
                  } else {
                    device.pair();
                  }
                }
              }
            }
          }

          Rectangle {
            visible: !Bluetooth.defaultAdapter || Bluetooth.defaultAdapter.devices.values.length === 0
            width: content.width
            implicitHeight: 30
            radius: theme.radius
            color: "transparent"
            border.color: theme.widgetBorder
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: Bluetooth.defaultAdapter ? "no bluetooth devices" : "no bluetooth adapter"
              color: theme.base03
              font.family: theme.monospaceFont
              font.pixelSize: theme.fontSize
            }
          }
        }
      }
    }
  }
}
