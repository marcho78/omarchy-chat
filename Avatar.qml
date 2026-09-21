import QtQuick
import qs.Commons
import "Format.js" as Format

// A round initial in a stable per-user colour.
Rectangle {
  id: root
  property string userId: ""
  property string name: ""
  property real size: Style.space(32)
  property string fontFamily: Style.font.family

  width: size
  height: size
  radius: size / 2
  color: Qt.hsla(Format.hueFor(userId) / 360, 0.45, 0.42, 1)

  Text {
    anchors.centerIn: parent
    text: Format.initial(root.name || root.userId)
    color: "#ffffff"
    font.family: root.fontFamily
    font.pixelSize: root.size * 0.48
    font.bold: true
  }
}
