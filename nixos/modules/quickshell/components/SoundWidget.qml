import Quickshell
import Quickshell.Services.Pipewire
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
  implicitWidth: 28
  implicitHeight: 22

  property int forcedSinkId: -1
  property real volumeValue: 0
  property bool volumeMuted: false
  property bool volumeDragging: false
  readonly property var allNodes: Pipewire.nodes.values
  readonly property var trackedObjects: [...root.sinks(), ...root.streams()]
  readonly property var sink: Pipewire.defaultAudioSink

  function setVolumeFromPosition(mouseX, width) {
    if (width <= 0) return;
    var value = Math.max(0, Math.min(1, mouseX / width));
    volumeValue = value;
    setMasterVolume(value);
  }

  function isBluetoothSink(node) {
    if (!node) return false;

    var name = node.name || "";
    if (name.indexOf("bluez_output") !== -1) return true;

    if (node.properties) {
      if (node.properties["api.bluez5.address"]) return true;
      if (node.properties["device.bus"] === "bluetooth") return true;
    }

    return false;
  }

  function currentVolumeCurve() {
    var activeSink = sink || currentSink();
    return isBluetoothSink(activeSink) ? 0.35 : 1.0;
  }

  function toSystemVolume(uiVolume) {
    var clamped = Math.max(0, Math.min(1, uiVolume));
    var curve = currentVolumeCurve();
    return curve === 1.0 ? clamped : Math.pow(clamped, curve);
  }

  function toUiVolume(systemVolume) {
    var clamped = Math.max(0, Math.min(1, systemVolume));
    var curve = currentVolumeCurve();
    return curve === 1.0 ? clamped : Math.pow(clamped, 1.0 / curve);
  }

  function refreshVolume() {
    readVolumeProcess.exec(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]);
  }

  function sinks() {
    return [...Pipewire.nodes.values].filter(function(node) {
      return !!(node && node.audio && node.isSink && !node.isStream);
    });
  }

  function streams() {
    return [...Pipewire.nodes.values].filter(function(node) {
      return !!(node && node.audio && node.isStream && !node.isSink);
    });
  }

  function currentSink() {
    var candidates = sinks();

    if (forcedSinkId >= 0) {
      for (var i = 0; i < candidates.length; i++) {
        if (candidates[i].id === forcedSinkId) {
          return candidates[i];
        }
      }
    }

    return Pipewire.preferredDefaultAudioSink || Pipewire.defaultAudioSink || null;
  }

  function sinkName(node) {
    if (!node) return "unknown output";
    return node.description || node.nickname || node.name || "unknown output";
  }

  function volume() {
    return Math.max(0, Math.min(1, volumeValue));
  }

  function volumePercent() {
    return Math.round(volume() * 100);
  }

  function isMuted() {
    return !!volumeMuted;
  }

  function volumeIcon() {
    if (isMuted()) return "󰖁";

    var v = volume();
    if (v >= 0.6) return "";
    if (v > 0) return "";
    return "";
  }

  function setMasterVolume(v) {
    var uiVolume = Math.max(0, Math.min(1, v));
    volumeValue = uiVolume;
    volumeMuted = false;

    var systemVolume = toSystemVolume(uiVolume);

    var activeSink = sink || currentSink();
    if (activeSink && activeSink.ready && activeSink.audio) {
      activeSink.audio.muted = false;
      activeSink.audio.volume = systemVolume;
    }

    volumeProcess.exec({ command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", Math.round(systemVolume * 100) + "%"] });
    unmuteProcess.exec({ command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"] });
  }

  function selectSink(node) {
    if (!node) return;

    forcedSinkId = node.id;
    Pipewire.preferredDefaultAudioSink = node;
    enforceRouting();
    refreshVolumeTimer.restart();
  }

  function enforceRouting() {
    var target = currentSink();
    if (!target) return;

    Pipewire.preferredDefaultAudioSink = target;

    var outputStreams = streams();
    if (outputStreams.length === 0) return;

    var cmd = "wpctl set-default " + target.id;
    for (var i = 0; i < outputStreams.length; i++) {
      cmd += "; wpctl move-node " + outputStreams[i].id + " " + target.id;
    }

    routeProcess.exec({ command: ["sh", "-c", cmd] });
  }

  function isCurrentSink(node) {
    var current = currentSink();
    return !!(current && node && current.id === node.id);
  }

  Component.onCompleted: {
    var sink = currentSink();
    if (sink) {
      forcedSinkId = sink.id;
      Qt.callLater(enforceRouting);
    }

    refreshVolume();
  }

  onSinkChanged: {
    if (!volumeDragging) refreshVolumeTimer.restart();
  }

  onAllNodesChanged: {
    Qt.callLater(enforceRouting);
    if (!volumeDragging) refreshVolumeTimer.restart();
  }

  Timer {
    interval: 3500
    repeat: true
    running: true
    onTriggered: root.enforceRouting()
  }

  Timer {
    interval: 1200
    repeat: true
    running: true
    onTriggered: {
      if (!root.volumeDragging) root.refreshVolume();
    }
  }

  Timer {
    id: refreshVolumeTimer
    interval: 140
    repeat: false
    onTriggered: root.refreshVolume()
  }

  Process {
    id: routeProcess
  }

  Process {
    id: volumeProcess
  }

  Process {
    id: unmuteProcess
  }

  Process {
    id: readVolumeProcess

    stdout: StdioCollector {
      onStreamFinished: {
        var text = this.text || "";
        var match = text.match(/([0-9]*\.?[0-9]+)/);

        if (match && match[1] && match[1].length > 0) {
          var parsed = Number(match[1]);
          if (parsed === parsed && parsed !== Infinity && parsed !== -Infinity) {
            root.volumeValue = root.toUiVolume(parsed);
          }
        }

        root.volumeMuted = text.indexOf("MUTED") !== -1;
      }
    }
  }

  PwObjectTracker {
    objects: root.trackedObjects
  }

  Text {
    anchors.centerIn: parent
    text: root.volumeIcon()
    color: root.isMuted() ? theme.base03 : theme.fg
    font.family: theme.emojiFont
    font.pixelSize: theme.fontSize
  }

  MouseArea {
    anchors.fill: parent
    onClicked: {
      popupState.activePopup = popupState.activePopup === "sound" ? "" : "sound";
    }
  }

  PopupWindow {
    id: popup

    anchor.window: panelWindow
    anchor.rect.x: 0
    anchor.rect.y: panelWindow.implicitHeight

    visible: popupState.activePopup === "sound"
    color: "transparent"

    implicitWidth: screen.width
    implicitHeight: Math.max(1, screen.height - panelWindow.implicitHeight)

    Rectangle {
      anchors.fill: parent
      color: "transparent"

      MouseArea {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: menu.top
        onClicked: popupState.activePopup = ""
      }

      MouseArea {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: menu.bottom
        anchors.bottom: parent.bottom
        onClicked: popupState.activePopup = ""
      }

      MouseArea {
        anchors.left: parent.left
        anchors.right: menu.left
        anchors.top: menu.top
        anchors.bottom: menu.bottom
        onClicked: popupState.activePopup = ""
      }

      MouseArea {
        anchors.left: menu.right
        anchors.right: parent.right
        anchors.top: menu.top
        anchors.bottom: menu.bottom
        onClicked: popupState.activePopup = ""
      }

      Rectangle {
        id: menu
        anchors.top: parent.top
        anchors.topMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 10
        width: 320
        implicitHeight: content.implicitHeight + 16
        radius: theme.radius
        color: theme.widgetBg
        border.color: theme.widgetBorder
        border.width: 1
        clip: true

        Column {
          id: content
          anchors.fill: parent
          anchors.margins: 8
          spacing: 6

          Text {
            text: "sound"
            color: theme.fg
            font.family: theme.monospaceFont
            font.pixelSize: theme.fontSize
          }

          Rectangle {
            width: content.width
            implicitHeight: 1
            color: theme.widgetBorder
          }

          Repeater {
            model: ScriptModel {
              values: root.sinks()
            }

            Rectangle {
              required property var modelData
              property var sink: modelData

              width: content.width
              implicitHeight: 30
              radius: theme.radius
              color: "transparent"
              border.width: 1
              border.color: root.isCurrentSink(sink) ? theme.base0C : theme.widgetBorder

              Text {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: root.sinkName(sink)
                color: root.isCurrentSink(sink) ? theme.base0C : theme.fg
                font.family: theme.monospaceFont
                font.pixelSize: theme.fontSize
              }

              TapHandler {
                onTapped: root.selectSink(sink)
              }
            }
          }

          Rectangle {
            width: content.width
            implicitHeight: 1
            color: theme.widgetBorder
          }

          RowLayout {
            width: content.width

            Text {
              text: root.volumePercent() + "%"
              color: theme.fg
              font.family: theme.monospaceFont
              font.pixelSize: theme.fontSize
            }

            Item {
              id: volumeSlider
              Layout.fillWidth: true
              implicitHeight: 20

              Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 4
                radius: 2
                color: theme.widgetBorder
              }

              Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * root.volumeValue
                height: 4
                radius: 2
                color: theme.base0C
              }

              Rectangle {
                width: 12
                height: 12
                radius: 6
                x: root.volumeValue * (parent.width - width)
                y: (parent.height - height) / 2
                color: theme.base0C
                border.width: 1
                border.color: theme.widgetBg
              }

              MouseArea {
                anchors.fill: parent
                onPressed: mouse => {
                  root.volumeDragging = true;
                  root.setVolumeFromPosition(mouse.x, width);
                }
                onPositionChanged: mouse => {
                  if (pressed) root.setVolumeFromPosition(mouse.x, width);
                }
                onReleased: {
                  root.volumeDragging = false;
                  refreshVolumeTimer.restart();
                }
                onCanceled: {
                  root.volumeDragging = false;
                  refreshVolumeTimer.restart();
                }
              }
            }
          }
        }
      }
    }
  }
}
