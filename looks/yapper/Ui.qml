import QtQuick
import qs.Commons

// Design tokens for the Yapper look: the mock's pixel sizes, scaled with
// the shell's font size so the look grows with the rest of the desktop.
// Every component keeps one of these as `ui`.
QtObject {
  readonly property real k: Style.font.baseSize / 12
  function px(n) { return Math.max(1, Math.round(n * k)) }

  // Text: a sans face for reading, the shell's (mono) face for ids, times
  // and counts — what the design uses JetBrains Mono for.
  readonly property string sans: "Adwaita Sans"
  readonly property string mono: Style.font.family
  readonly property int f10: px(10)
  readonly property int f11: px(11.5)
  readonly property int f12: px(12)
  readonly property int f13: px(13)
  readonly property int f14: px(14)
  readonly property int f15: px(15)
  readonly property int f18: px(18)

  readonly property int radius: px(8)
  readonly property int titleHeight: px(30)
  readonly property int railWidth: px(56)
  readonly property int sidebarWidth: px(296)
  readonly property int headerHeight: px(54)
}
