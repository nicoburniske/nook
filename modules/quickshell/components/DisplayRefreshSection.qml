import Quickshell
import Quickshell.Io
import QtQuick

Column {
  id: root

  required property var theme
  property real sectionWidth: 0
  property bool active: false

  width: sectionWidth
  spacing: 6

  readonly property var preferredMonitor: root.pickPreferredMonitor(root.hyprMonitors)
  readonly property var refreshRateOptions: root.refreshRateEntries(root.preferredMonitor)

  property var hyprMonitors: []
  property bool refreshApplying: false
  property real pendingRefreshRate: -1
  property string refreshError: ""

  function numberText(value, maxDecimals) {
    var numeric = Number(value);
    if (numeric !== numeric || numeric === Infinity || numeric === -Infinity) return "0";

    var rounded = Math.round(numeric);
    if (Math.abs(numeric - rounded) < 0.01) return rounded.toString();

    var text = numeric.toFixed(maxDecimals);
    return text.replace(/\.?0+$/, "");
  }

  function parseModeRate(modeText, width, height) {
    var match = String(modeText || "").match(/^([0-9]+)x([0-9]+)@([0-9]+(?:\.[0-9]+)?)Hz$/i);
    if (!match) return NaN;

    if (Number(match[1]) !== width || Number(match[2]) !== height) return NaN;
    return Number(match[3]);
  }

  function normalizeMonitor(rawMonitor) {
    if (!rawMonitor || !rawMonitor.name) return null;

    return {
      name: String(rawMonitor.name),
      width: Number(rawMonitor.width) || 0,
      height: Number(rawMonitor.height) || 0,
      x: Number(rawMonitor.x) || 0,
      y: Number(rawMonitor.y) || 0,
      scale: Number(rawMonitor.scale) || 1,
      focused: !!rawMonitor.focused,
      refreshRate: Number(rawMonitor.refreshRate) || 0,
      availableModes: rawMonitor.availableModes ? [...rawMonitor.availableModes] : []
    };
  }

  function parseMonitorsOutput(text) {
    var raw = [];

    try {
      raw = JSON.parse(text || "[]");
    } catch (_) {
      root.hyprMonitors = [];
      root.refreshError = "unable to read monitor data";
      return;
    }

    var monitors = [];
    for (var i = 0; i < raw.length; i++) {
      var normalized = normalizeMonitor(raw[i]);
      if (normalized) monitors.push(normalized);
    }

    root.hyprMonitors = monitors;
    root.refreshError = monitors.length > 0 ? "" : "no active monitors";
  }

  function pickPreferredMonitor(monitors) {
    if (!monitors || monitors.length === 0) return null;

    for (var i = 0; i < monitors.length; i++) {
      if (monitors[i].focused) return monitors[i];
    }

    for (var j = 0; j < monitors.length; j++) {
      if (String(monitors[j].name).toLowerCase().indexOf("edp") === 0) return monitors[j];
    }

    return monitors[0];
  }

  function refreshRateEntries(monitor) {
    if (!monitor) return [];

    var rates = [];
    var modes = monitor.availableModes || [];

    for (var i = 0; i < modes.length; i++) {
      var rate = parseModeRate(modes[i], monitor.width, monitor.height);
      if (rate !== rate) continue;

      var roundedRate = Math.round(rate);
      if (Math.abs(rate - roundedRate) > 0.01) continue;

      rates.push(roundedRate);
    }

    if (rates.length === 0 && monitor.refreshRate > 0) {
      var activeRoundedRate = Math.round(monitor.refreshRate);
      if (Math.abs(monitor.refreshRate - activeRoundedRate) <= 0.01) {
        rates.push(activeRoundedRate);
      }
    }

    rates.sort(function(a, b) {
      return b - a;
    });

    return rates.map(function(rate) {
      return {
        rate: rate,
        label: numberText(rate, 0) + " hz"
      };
    });
  }

  function isSameRate(left, right) {
    return Math.abs(Number(left) - Number(right)) < 0.06;
  }

  function isRateActive(rate) {
    if (!root.preferredMonitor) return false;
    return isSameRate(root.preferredMonitor.refreshRate, rate);
  }

  function isRatePending(rate) {
    if (!root.refreshApplying || root.pendingRefreshRate < 0) return false;
    return isSameRate(root.pendingRefreshRate, rate);
  }

  function isRateSelected(rate) {
    return isRateActive(rate) || isRatePending(rate);
  }

  function monitorSummary() {
    if (!root.preferredMonitor) return "monitor unavailable";

    var monitor = root.preferredMonitor;
    return monitor.name
      + "  " + monitor.width + "x" + monitor.height
      + "  " + numberText(monitor.refreshRate, 2) + " hz";
  }

  function monitorKeyword(rate) {
    if (!root.preferredMonitor) return "";

    var monitor = root.preferredMonitor;
    return monitor.name
      + ", " + monitor.width + "x" + monitor.height + "@" + numberText(rate, 0)
      + ", " + monitor.x + "x" + monitor.y
      + ", " + numberText(monitor.scale, 2);
  }

  function refreshMonitorState() {
    if (!root.active) return;
    monitorSnapshotProcess.exec(["hyprctl", "monitors", "-j"]);
  }

  function applyRefreshRate(rate) {
    var keywordValue = monitorKeyword(rate);
    if (keywordValue.length === 0) return;

    root.refreshApplying = true;
    root.pendingRefreshRate = rate;
    root.refreshError = "";
    applyTimeoutTimer.restart();

    applyRefreshProcess.exec(["hyprctl", "keyword", "monitor", keywordValue]);
  }

  onActiveChanged: {
    if (root.active) root.refreshMonitorState();
  }

  Timer {
    interval: 5000
    repeat: true
    running: root.active
    onTriggered: root.refreshMonitorState()
  }

  Timer {
    id: refreshAfterApplyTimer
    interval: 180
    repeat: false
    onTriggered: root.refreshMonitorState()
  }

  Timer {
    id: applyTimeoutTimer
    interval: 1200
    repeat: false
    onTriggered: {
      root.refreshApplying = false;
      root.pendingRefreshRate = -1;
      root.refreshMonitorState();
    }
  }

  Process {
    id: monitorSnapshotProcess

    stdout: StdioCollector {
      onStreamFinished: {
        root.parseMonitorsOutput(this.text || "");
      }
    }
  }

  Process {
    id: applyRefreshProcess

    stdout: StdioCollector {
      onStreamFinished: {
        var output = (this.text || "").trim();
        var lowered = output.toLowerCase();

        applyTimeoutTimer.stop();
        root.refreshApplying = false;
        root.pendingRefreshRate = -1;

        if (lowered.indexOf("error") !== -1 || lowered.indexOf("invalid") !== -1) {
          root.refreshError = output;
        }

        refreshAfterApplyTimer.restart();
      }
    }
  }

  Text {
    text: "display"
    color: theme.fg
    font.family: theme.monospaceFont
    font.pixelSize: theme.fontSize
  }

  Text {
    text: root.monitorSummary()
    color: theme.base03
    font.family: theme.monospaceFont
    font.pixelSize: theme.fontSize
  }

  Flow {
    visible: root.refreshRateOptions.length > 0
    width: root.width
    spacing: 4

    Repeater {
      model: ScriptModel {
        values: root.refreshRateOptions
      }

      Rectangle {
        required property var modelData

        implicitWidth: Math.max(58, rateLabel.implicitWidth + 16)
        implicitHeight: 28
        radius: theme.radius
        color: "transparent"
        border.width: 1
        border.color: root.isRateSelected(modelData.rate) ? theme.base0C : theme.widgetBorder
        opacity: root.refreshApplying && !root.isRatePending(modelData.rate) ? 0.7 : 1

        Text {
          id: rateLabel
          anchors.centerIn: parent
          text: modelData.label
          color: root.isRateSelected(modelData.rate) ? theme.base0C : theme.fg
          font.family: theme.monospaceFont
          font.pixelSize: theme.fontSize
        }

        TapHandler {
          enabled: !root.refreshApplying
          onTapped: root.applyRefreshRate(modelData.rate)
        }
      }
    }
  }

  Text {
    visible: root.refreshRateOptions.length === 0
    text: "no refresh rates available"
    color: theme.base03
    font.family: theme.monospaceFont
    font.pixelSize: theme.fontSize
  }

  Text {
    visible: root.refreshError.length > 0
    text: root.refreshError
    color: theme.danger
    font.family: theme.monospaceFont
    font.pixelSize: theme.fontSize
    wrapMode: Text.WordWrap
    width: root.width
  }
}
