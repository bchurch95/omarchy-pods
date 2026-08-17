import QtQuick
import qs.Commons

// Drawn rather than shipped as an SVG: at bar size the stems are lost to rasterisation.
Item {
  id: root

  property real iconSize: 16
  property color color: Color.foreground

  implicitWidth: iconSize
  implicitHeight: iconSize

  readonly property real headSize: iconSize * 0.44
  readonly property real stemWidth: iconSize * 0.17
  readonly property real stemHeight: iconSize * 0.42

  Row {
    anchors.centerIn: parent
    spacing: root.iconSize * 0.14

    Pod { head: root.headSize; stemW: root.stemWidth; stemH: root.stemHeight; ink: root.color }
    Pod { head: root.headSize; stemW: root.stemWidth; stemH: root.stemHeight; ink: root.color }
  }

  component Pod: Item {
    id: pod
    property real head: 0
    property real stemW: 0
    property real stemH: 0
    property color ink: Color.foreground

    width: head
    height: head + stemH

    Rectangle {
      width: pod.head
      height: pod.head
      radius: width / 2
      color: pod.ink
    }

    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      // Overlap the head slightly so the two shapes read as one earbud.
      y: pod.head * 0.82
      width: pod.stemW
      height: pod.stemH
      radius: width / 2
      color: pod.ink
    }
  }
}
