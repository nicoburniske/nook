import Quickshell
import QtQuick
import QtQuick.Layouts

Scope {
  id: bar

  required property var theme

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

          Rectangle {
            radius: theme.radius
            color: theme.widgetBg
            border.color: theme.widgetBorder
            border.width: 1
            implicitHeight: 26
            implicitWidth: rightRow.implicitWidth + 8

            RowLayout {
              id: rightRow
              anchors.fill: parent
              anchors.leftMargin: 4
              anchors.rightMargin: 4
              spacing: 2

              BluetoothWidget {
                panelWindow: panel
                theme: bar.theme
              }

              Rectangle {
                color: "transparent"
                implicitWidth: clockLabel.implicitWidth + 8
                implicitHeight: 22

                Text {
                  id: clockLabel
                  anchors.centerIn: parent
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
    }
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }
}
