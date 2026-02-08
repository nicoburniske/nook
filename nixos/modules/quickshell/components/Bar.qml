import Quickshell
import QtQuick
import QtQuick.Layouts

Scope {
  id: bar

  required property var theme
  property string activePopup: ""
  property int segmentSlant: 6

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      screen: modelData
      color: "transparent"

      anchors {
        top: true
        left: true
        right: true
      }

      implicitHeight: theme.barHeight

      Rectangle {
        id: barSurface
        anchors.fill: parent
        color: "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 10
          anchors.rightMargin: 10
          spacing: 6

          Workspaces {
            screen: panel.screen
            theme: bar.theme
          }

          Item {
            Layout.fillWidth: true
          }

          SlantRect {
            fillColor: theme.widgetBg
            strokeColor: theme.widgetBorder
            strokeWidth: 1
            slant: bar.segmentSlant
            implicitHeight: 26

            RowLayout {
              id: indicatorRow
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: 2

              SoundWidget {
                panelWindow: panel
                theme: bar.theme
                popupState: bar
              }

              BluetoothWidget {
                panelWindow: panel
                theme: bar.theme
                popupState: bar
              }
            }
          }

          SlantRect {
            fillColor: theme.widgetBg
            strokeColor: theme.widgetBorder
            strokeWidth: 1
            slant: bar.segmentSlant
            implicitHeight: 26

            RowLayout {
              id: statsRow
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: 2

              SystemStatsWidget {
                theme: bar.theme
              }
            }
          }

          SlantRect {
            fillColor: theme.widgetBg
            strokeColor: theme.widgetBorder
            strokeWidth: 1
            slant: bar.segmentSlant
            implicitHeight: 26

            RowLayout {
              id: batteryRow
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: 2

              BatteryWidget {
                panelWindow: panel
                theme: bar.theme
                popupState: bar
              }
            }
          }

          SlantRect {
            fillColor: theme.widgetBg
            strokeColor: theme.widgetBorder
            strokeWidth: 1
            slant: bar.segmentSlant
            implicitHeight: 26

            Text {
              id: clockLabel
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              color: theme.fg
              font.family: theme.monospaceFont
              font.pixelSize: theme.fontSize
              text: Qt.formatDateTime(clock.date, "ddd MMM dd hh:mm").toLowerCase()
            }
          }
        }
      }
    }
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }
}
