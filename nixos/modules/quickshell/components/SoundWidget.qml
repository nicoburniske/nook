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

  Process {
    id: openPavucontrol
    command: ["pavucontrol"]
  }

  QtObject {
    id: audio

    property int forcedSinkId: -1
    property real volumeValue: 0
    property bool volumeMuted: false
    property bool volumeDragging: false

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var nodeValues: Pipewire.nodes.values
    readonly property var trackedObjects: [...audio.sinks(), ...audio.streams()]

    function clamp01(value) {
      return Math.max(0, Math.min(1, value));
    }

    function setVolumeFromPosition(mouseX, width) {
      if (width <= 0) return;

      var value = clamp01(mouseX / width);
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
      var curve = currentVolumeCurve();
      var clamped = clamp01(uiVolume);
      return curve === 1.0 ? clamped : Math.pow(clamped, curve);
    }

    function toUiVolume(systemVolume) {
      var curve = currentVolumeCurve();
      var clamped = clamp01(systemVolume);
      return curve === 1.0 ? clamped : Math.pow(clamped, 1.0 / curve);
    }

    function refreshVolume() {
      readVolumeProcess.exec(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]);
    }

    function scheduleVolumeRefresh() {
      refreshVolumeTimer.restart();
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
      return clamp01(volumeValue);
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
      var uiVolume = clamp01(v);
      volumeValue = uiVolume;
      volumeMuted = false;

      var systemVolume = toSystemVolume(uiVolume);
      var activeSink = sink || currentSink();

      if (activeSink && activeSink.ready && activeSink.audio) {
        activeSink.audio.muted = false;
        activeSink.audio.volume = systemVolume;
      }

      volumeProcess.exec({
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", Math.round(systemVolume * 100) + "%"]
      });
      unmuteProcess.exec({ command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"] });
    }

    function selectSink(node) {
      if (!node) return;

      forcedSinkId = node.id;
      Pipewire.preferredDefaultAudioSink = node;
      enforceRouting();
      scheduleVolumeRefresh();
    }

    function enforceRouting() {
      var target = currentSink();
      if (!target) return;

      Pipewire.preferredDefaultAudioSink = target;

      var cmd = "wpctl set-default " + target.id;
      var outputStreams = streams();
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
      var current = currentSink();
      if (current) {
        forcedSinkId = current.id;
        Qt.callLater(enforceRouting);
      }

      refreshVolume();
    }

    onSinkChanged: {
      if (!volumeDragging) scheduleVolumeRefresh();
    }

    onNodeValuesChanged: {
      Qt.callLater(enforceRouting);
      if (!volumeDragging) scheduleVolumeRefresh();
    }

  }

  Timer {
    interval: 3500
    repeat: true
    running: true
    onTriggered: audio.enforceRouting()
  }

  Timer {
    interval: 1200
    repeat: true
    running: true
    onTriggered: {
      if (!audio.volumeDragging) audio.refreshVolume();
    }
  }

  Timer {
    id: refreshVolumeTimer
    interval: 140
    repeat: false
    onTriggered: audio.refreshVolume()
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
            audio.volumeValue = audio.toUiVolume(parsed);
          }
        }

        audio.volumeMuted = text.indexOf("MUTED") !== -1;
      }
    }
  }

  PwObjectTracker {
    objects: audio.trackedObjects
  }

  component SinkRow: Rectangle {
    required property var sinkNode
    required property real rowWidth

    width: rowWidth
    implicitHeight: 30
    radius: root.theme.radius
    color: "transparent"
    border.width: 1
    border.color: audio.isCurrentSink(sinkNode) ? root.theme.base0C : root.theme.widgetBorder

    Text {
      anchors.left: parent.left
      anchors.leftMargin: 8
      anchors.right: parent.right
      anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      elide: Text.ElideRight
      text: audio.sinkName(sinkNode)
      color: audio.isCurrentSink(sinkNode) ? root.theme.base0C : root.theme.fg
      font.family: root.theme.monospaceFont
      font.pixelSize: root.theme.fontSize
    }

    TapHandler {
      onTapped: audio.selectSink(sinkNode)
    }
  }

  Text {
    anchors.centerIn: parent
    text: audio.volumeIcon()
    color: audio.isMuted() ? theme.base03 : theme.fg
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

          Item {
            width: content.width
            implicitHeight: headerRow.implicitHeight

            RowLayout {
              id: headerRow
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: 6

              Text {
                text: "sound"
                color: theme.fg
                font.family: theme.monospaceFont
                font.pixelSize: theme.fontSize
              }

              Text {
                text: "󰒓"
                color: theme.fg
                font.family: theme.emojiFont
                font.pixelSize: theme.fontSize
              }
            }

            MouseArea {
              anchors.fill: parent
              onClicked: {
                popupState.activePopup = "";
                openPavucontrol.startDetached();
              }
            }
          }

          Repeater {
            model: ScriptModel {
              values: audio.sinks()
            }

            SinkRow {
              required property var modelData
              sinkNode: modelData
              rowWidth: content.width
            }
          }

          RowLayout {
            width: content.width

            Text {
              text: audio.volumePercent() + "%"
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
                width: parent.width * audio.volumeValue
                height: 4
                radius: 2
                color: theme.base0C
              }

              Rectangle {
                width: 12
                height: 12
                radius: 6
                x: audio.volumeValue * (parent.width - width)
                y: (parent.height - height) / 2
                color: theme.base0C
                border.width: 1
                border.color: theme.widgetBg
              }

              MouseArea {
                anchors.fill: parent
                onPressed: mouse => {
                  audio.volumeDragging = true;
                  audio.setVolumeFromPosition(mouse.x, width);
                }
                onPositionChanged: mouse => {
                  if (pressed) audio.setVolumeFromPosition(mouse.x, width);
                }
                onReleased: {
                  audio.volumeDragging = false;
                  audio.scheduleVolumeRefresh();
                }
                onCanceled: {
                  audio.volumeDragging = false;
                  audio.scheduleVolumeRefresh();
                }
              }
            }
          }
        }
      }
    }
  }
}
