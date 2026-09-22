import QtQuick
import "Icons.js" as Icons

// One Phosphor icon by name (https://phosphoricons.com). The families are
// registered once by Service.qml, so this is a plain Text.
//
//   Icon { name: "paper-plane-tilt"; size: 18; color: palette.accent }
//
// `weight` picks the regular, bold or fill face.
Text {
  id: icon
  property string name: ""
  property string weight: "regular"   // regular | bold | fill
  property real size: 16

  text: Icons.glyph(name)
  font.family: weight === "bold" ? "Phosphor-Bold" : weight === "fill" ? "Phosphor-Fill" : "Phosphor"
  font.pixelSize: size
  horizontalAlignment: Text.AlignHCenter
  verticalAlignment: Text.AlignVCenter
  renderType: Text.NativeRendering
}
