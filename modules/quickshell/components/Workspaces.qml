import Quickshell.Hyprland
import QtQuick

Item {
  id: root

  required property var screen
  required property var theme

  property int sideInset: 7
  property real indicatorX: sideInset
  property bool indicatorReady: false

  implicitHeight: 26
  implicitWidth: workspaceRow.implicitWidth + (sideInset * 2) + 2

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

  function workspaceLabel(id) {
    return id.toString();
  }

  function workspaceIds() {
    var ids = [1, 2, 3, 4];
    var monitor = Hyprland.monitorFor(screen);
    if (!monitor) return ids;

    for (var i = 0; i < Hyprland.workspaces.values.length; i++) {
      var ws = Hyprland.workspaces.values[i];
      if (!ws || !ws.monitor || ws.monitor.id !== monitor.id || ws.id <= 0) continue;
      if (ids.indexOf(ws.id) === -1) ids.push(ws.id);
    }

    ids.sort(function(a, b) { return a - b; });
    return ids;
  }

  function setIndicatorFrom(item) {
    if (!item) return;

    var position = item.mapToItem(root, 0, 0);
    indicatorX = position.x + ((item.width - activeIndicator.width) / 2);
    indicatorReady = true;
  }

  SlantRect {
    anchors.fill: parent
    slant: root.sideInset
    fillColor: theme.widgetBg
    strokeColor: theme.widgetBorder
    strokeWidth: 1
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
    anchors.leftMargin: root.sideInset + 1
    spacing: 2

    Repeater {
      model: root.workspaceIds()

      Rectangle {
        id: workspaceButton

        property var ws: root.workspaceFor(modelData)
        readonly property bool active: !!(ws && ws.active)

        color: "transparent"
        radius: theme.radius
        implicitWidth: 26
        implicitHeight: 22

        Rectangle {
          anchors.fill: parent
          anchors.margins: 1
          radius: theme.radius - 1
          color: workspaceButton.active
            ? Qt.alpha(theme.base05, 0.14)
            : (workspaceMouse.containsMouse ? Qt.alpha(theme.base03, 0.24) : "transparent")
          border.width: workspaceButton.active ? 1 : 0
          border.color: Qt.alpha(theme.base05, 0.65)

          Behavior on color {
            ColorAnimation {
              duration: 140
            }
          }
        }

        Text {
          anchors.centerIn: parent
          color: theme.base05
          font.family: theme.monospaceFont
          font.pixelSize: theme.fontSize
          text: root.workspaceLabel(modelData)
        }

        MouseArea {
          id: workspaceMouse
          anchors.fill: parent
          hoverEnabled: true
          onClicked: {
            if (workspaceButton.ws) {
              workspaceButton.ws.activate();
            } else {
              Hyprland.dispatch("workspace " + modelData);
            }
          }
        }

        onActiveChanged: if (active) root.setIndicatorFrom(workspaceButton)
        onXChanged: if (active) root.setIndicatorFrom(workspaceButton)
        Component.onCompleted: if (active) Qt.callLater(function() { root.setIndicatorFrom(workspaceButton); })
      }
    }
  }

  Rectangle {
    id: activeIndicator
    width: 18
    height: 2
    radius: 2
    x: root.indicatorX
    y: root.height - 4
    color: theme.base05
    opacity: root.indicatorReady ? 1 : 0

    Behavior on x {
      NumberAnimation {
        duration: 180
        easing.type: Easing.OutCubic
      }
    }
  }
}
