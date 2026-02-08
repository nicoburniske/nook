import Quickshell.Hyprland
import QtQuick

Rectangle {
  id: root

  required property var screen
  required property var theme

  radius: theme.radius
  color: theme.widgetBg
  border.color: theme.widgetBorder
  border.width: 1
  implicitHeight: 26
  implicitWidth: workspaceRow.implicitWidth + 10

  function workspaceFor(id) {
    var monitor = Hyprland.monitorFor(screen);
    if (!monitor) return null;

    for (var i = 0; i < Hyprland.workspaces.values.length; i++) {
      var ws = Hyprland.workspaces.values[i];
      if (ws.id === id && ws.monitor && ws.monitor.id === monitor.id) {
        return ws;
      }
    }

    return null;
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    onWheel: wheel => {
      if (wheel.angleDelta.y > 0) {
        Hyprland.dispatch("workspace e+1");
      } else if (wheel.angleDelta.y < 0) {
        Hyprland.dispatch("workspace e-1");
      }
      wheel.accepted = true;
    }
  }

  Row {
    id: workspaceRow
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.leftMargin: 5
    spacing: 2

    Repeater {
      model: [1, 2, 3, 4]

      Rectangle {
        id: workspaceButton

        property var ws: root.workspaceFor(modelData)

        color: "transparent"
        radius: theme.radius
        implicitWidth: 24
        implicitHeight: 22

        Text {
          anchors.centerIn: parent
          color: ws && ws.urgent ? theme.danger : theme.base05
          font.family: theme.monospaceFont
          font.pixelSize: theme.fontSize
          text: modelData.toString()
        }

        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          width: parent.width - 10
          height: 2
          radius: 1
          color: theme.base05
          visible: ws && ws.active
        }

        MouseArea {
          anchors.fill: parent
          onClicked: {
            if (workspaceButton.ws) {
              workspaceButton.ws.activate();
            } else {
              Hyprland.dispatch("workspace " + modelData);
            }
          }
        }
      }
    }
  }
}
