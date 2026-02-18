import Quickshell
import QtQuick

PopupWindow {
  id: root

  required property var panelWindow
  required property var popupState
  required property string popupId
  required property var triggerItem
  required property var theme

  property int menuWidth: 320
  property int horizontalMargin: 10
  property int verticalOffset: 6
  property int contentMargin: 8

  default property alias menuData: menuContent.data

  function closePopup() {
    popupState.activePopup = "";
  }

  function centeredMenuX(popupContainer, menuWidth) {
    var safeMargin = root.horizontalMargin;
    var centerX = root.triggerItem ? root.triggerItem.width / 2 : 0;

    if (root.triggerItem && popupContainer && root.triggerItem.mapToGlobal && popupContainer.mapToGlobal) {
      var triggerGlobal = root.triggerItem.mapToGlobal(root.triggerItem.width / 2, 0);
      var popupGlobal = popupContainer.mapToGlobal(0, 0);
      centerX = triggerGlobal.x - popupGlobal.x;
    }

    var desired = centerX - (menuWidth / 2);
    var maxX = Math.max(safeMargin, popupContainer.width - menuWidth - safeMargin);
    return Math.max(safeMargin, Math.min(maxX, desired));
  }

  anchor.window: panelWindow
  anchor.rect.x: 0
  anchor.rect.y: panelWindow.implicitHeight

  visible: popupState.activePopup === popupId
  color: "transparent"

  implicitWidth: Math.max(1, panelWindow.width)
  implicitHeight: Math.max(1, screen.height - panelWindow.implicitHeight)

  Rectangle {
    anchors.fill: parent
    color: "transparent"

    MouseArea {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: menu.top
      onClicked: root.closePopup()
    }

    MouseArea {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: menu.bottom
      anchors.bottom: parent.bottom
      onClicked: root.closePopup()
    }

    MouseArea {
      anchors.left: parent.left
      anchors.right: menu.left
      anchors.top: menu.top
      anchors.bottom: menu.bottom
      onClicked: root.closePopup()
    }

    MouseArea {
      anchors.left: menu.right
      anchors.right: parent.right
      anchors.top: menu.top
      anchors.bottom: menu.bottom
      onClicked: root.closePopup()
    }

    Rectangle {
      id: menu
      anchors.top: parent.top
      anchors.topMargin: root.verticalOffset
      width: root.menuWidth
      x: root.centeredMenuX(parent, width)
      implicitHeight: menuContent.implicitHeight + (root.contentMargin * 2)
      radius: root.theme.radius
      color: root.theme.widgetBg
      border.color: root.theme.widgetBorder
      border.width: 1
      clip: true

      Item {
        id: menuContent
        x: root.contentMargin
        y: root.contentMargin
        width: menu.width - (root.contentMargin * 2)
        implicitHeight: childrenRect.height
      }
    }
  }
}
