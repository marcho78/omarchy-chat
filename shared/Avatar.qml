import QtQuick
import QtQuick.Effects
import qs.Commons
import "Format.js" as Format

// A round avatar: the user's or room's picture when the daemon has it,
// otherwise an initial in a stable per-id colour.
Item {
  id: root
  property string userId: ""
  property string name: ""
  property string mxc: ""          // avatar URL; resolved through the service
  property var service: null
  property real size: Style.space(32)
  property string fontFamily: Style.font.family
  // Round by default; a look can square it off (rooms vs people).
  property real radius: size / 2
  // The initial's tile and ink when there is no picture.
  property color fallbackColor: Qt.hsla(Format.hueFor(root.userId || root.name) / 360, 0.45, 0.42, 1)
  property color initialColor: "#ffffff"

  readonly property string path: (service && mxc !== "" && service.avatars[mxc]) ? service.avatars[mxc] : ""
  onMxcChanged: if (service && mxc !== "") service.resolveAvatar(mxc)
  onServiceChanged: if (service && mxc !== "") service.resolveAvatar(mxc)
  Component.onCompleted: if (service && mxc !== "") service.resolveAvatar(mxc)

  width: size
  height: size

  Rectangle {
    anchors.fill: parent
    radius: root.radius
    color: root.fallbackColor
    visible: image.status !== Image.Ready
    Text {
      anchors.centerIn: parent
      text: Format.initial(root.name || root.userId)
      color: root.initialColor
      font.family: root.fontFamily
      font.pixelSize: root.size * 0.48
      font.bold: true
    }
  }
  Image {
    id: image
    anchors.fill: parent
    source: root.path !== "" ? "file://" + root.path : ""
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    sourceSize.width: 192
    sourceSize.height: 192
    visible: false
  }
  Rectangle {
    id: mask
    anchors.fill: parent
    radius: root.radius
    visible: false
    layer.enabled: true
  }
  MultiEffect {
    anchors.fill: parent
    source: image
    maskEnabled: true
    maskSource: mask
    visible: image.status === Image.Ready
  }
}
