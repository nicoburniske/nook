import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Rectangle {
  id: root

  required property var theme

  color: "transparent"
  implicitHeight: 22
  implicitWidth: row.implicitWidth + 2

  QtObject {
    id: stats

    property int cpuPercent: 0
    property int memPercent: 0

    property real previousTotal: -1
    property real previousIdle: -1

    function clampPercent(value) {
      return Math.max(0, Math.min(100, Math.round(value)));
    }

    function formatPercent(value) {
      return value < 10 ? "0" + value : value.toString();
    }

    function parseCpuStat(text) {
      var firstLine = (text || "").split("\n")[0] || "";
      var values = firstLine.trim().split(/\s+/);
      if (values.length < 5 || values[0] !== "cpu") return;

      var total = 0;
      for (var i = 1; i < values.length; i++) {
        var parsed = Number(values[i]);
        if (parsed === parsed) total += parsed;
      }

      var idle = Number(values[4]) || 0;
      var iowait = values.length > 5 ? (Number(values[5]) || 0) : 0;
      var idleTotal = idle + iowait;

      if (previousTotal >= 0 && total > previousTotal) {
        var deltaTotal = total - previousTotal;
        var deltaIdle = idleTotal - previousIdle;
        var active = deltaTotal - deltaIdle;

        if (deltaTotal > 0) {
          cpuPercent = clampPercent((active * 100) / deltaTotal);
        }
      }

      previousTotal = total;
      previousIdle = idleTotal;
    }

    function parseMemInfo(text) {
      var lines = (text || "").split("\n");
      var memTotal = 0;
      var memAvailable = 0;

      for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        if (line.indexOf("MemTotal:") === 0) {
          memTotal = Number(line.replace(/[^0-9]/g, ""));
        } else if (line.indexOf("MemAvailable:") === 0) {
          memAvailable = Number(line.replace(/[^0-9]/g, ""));
        }

        if (memTotal > 0 && memAvailable > 0) break;
      }

      if (memTotal > 0) {
        memPercent = clampPercent(((memTotal - memAvailable) * 100) / memTotal);
      }
    }

    function refresh() {
      cpuSnapshotProcess.exec({command: ["cat", "/proc/stat"]});
      memSnapshotProcess.exec({command: ["cat", "/proc/meminfo"]});
    }
  }

  Timer {
    interval: 2000
    repeat: true
    running: true
    onTriggered: stats.refresh()
  }

  Process {
    id: cpuSnapshotProcess

    stdout: StdioCollector {
      onStreamFinished: stats.parseCpuStat(this.text)
    }
  }

  Process {
    id: memSnapshotProcess

    stdout: StdioCollector {
      onStreamFinished: stats.parseMemInfo(this.text)
    }
  }

  Component.onCompleted: stats.refresh()

  RowLayout {
    id: row
    anchors.fill: parent
    spacing: 8

    Text {
      text: " " + stats.formatPercent(stats.cpuPercent) + "%"
      color: root.theme.fg
      font.family: root.theme.monospaceFont
      font.pixelSize: root.theme.fontSize
      Layout.alignment: Qt.AlignVCenter
    }

    Text {
      text: " " + stats.formatPercent(stats.memPercent) + "%"
      color: root.theme.fg
      font.family: root.theme.monospaceFont
      font.pixelSize: root.theme.fontSize
      Layout.alignment: Qt.AlignVCenter
    }
  }
}
