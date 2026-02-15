import QtQuick

Item {
  id: root

  property color fillColor: "transparent"
  property color strokeColor: "transparent"
  property real strokeWidth: 1
  property real slant: 7
  property bool slantRight: true
  property real horizontalPadding: Math.ceil(root.slant + root.strokeWidth)
  property real verticalPadding: Math.ceil(root.strokeWidth)

  implicitWidth: content.implicitWidth + (root.horizontalPadding * 2)
  implicitHeight: content.implicitHeight + (root.verticalPadding * 2)

  default property alias contentData: content.data

  Canvas {
    id: canvas
    anchors.fill: parent

    onPaint: {
      var ctx = getContext("2d");
      var w = width;
      var h = height;
      var bw = Math.max(0, root.strokeWidth);
      var half = bw / 2;
      var s = Math.max(0, Math.min(root.slant, w - bw));

      ctx.clearRect(0, 0, w, h);
      ctx.beginPath();

      if (root.slantRight) {
        ctx.moveTo(s, half);
        ctx.lineTo(w - half, half);
        ctx.lineTo(w - s, h - half);
        ctx.lineTo(half, h - half);
      } else {
        ctx.moveTo(half, half);
        ctx.lineTo(w - s, half);
        ctx.lineTo(w - half, h - half);
        ctx.lineTo(s, h - half);
      }

      ctx.closePath();
      ctx.fillStyle = root.fillColor;
      ctx.fill();

      if (bw > 0) {
        ctx.strokeStyle = root.strokeColor;
        ctx.lineWidth = bw;
        ctx.stroke();
      }
    }
  }

  Item {
    id: content
    anchors.fill: parent
    anchors.leftMargin: root.horizontalPadding
    anchors.rightMargin: root.horizontalPadding
    anchors.topMargin: root.verticalPadding
    anchors.bottomMargin: root.verticalPadding

    implicitWidth: childrenRect.width
    implicitHeight: childrenRect.height
  }

  function redraw() {
    canvas.requestPaint();
  }

  onWidthChanged: redraw()
  onHeightChanged: redraw()
  onFillColorChanged: redraw()
  onStrokeColorChanged: redraw()
  onStrokeWidthChanged: redraw()
  onSlantChanged: redraw()
  onSlantRightChanged: redraw()
}
