import QtQuick
import "../../shared"
import "../../shared/Palettes.js" as Palettes
import "../../shared/Format.js" as Format

// The install as the helper reports it from the terminal: phase, a bar with
// a percentage while cargo compiles, the clock, and the outcome.
Rectangle {
  id: root
  property var c: Palettes.fallback()
  property var service: null
  Ui { id: ui }

  readonly property var st: service ? service.installState : null
  readonly property string phase: st ? String(st.phase) : ""
  readonly property bool stale: service ? service.installStale : false
  readonly property bool failed: phase === "error" || stale
  readonly property bool finished: phase === "done"
  readonly property bool compiling: phase === "build" && st && Number(st.total) > 0
  readonly property real fraction: compiling ? Math.min(1, Number(st.done) / Number(st.total)) : 0
  readonly property string kindLabel: st && st.kind === "source" ? "from source" : "prebuilt"
  readonly property string phaseLabel: stale ? "No news from the terminal for a while" : phase === "fetch" ? "Fetching the repository" : phase === "deps" ? "Installing build tools" : phase === "download" ? "Downloading the release" : phase === "verify" ? "Checking the download" : phase === "prepare" ? "Fetching crates" : phase === "build" ? "Compiling" : phase === "package" ? "Packaging" : phase === "install" ? "Installing with pacman" : phase === "start" ? "Starting the daemon" : phase === "done" ? "Installed and running" : phase === "error" ? "Did not finish" : "Starting"
  readonly property string clock: service ? Format.clock(service.installElapsed) : ""

  implicitHeight: column.implicitHeight + ui.px(30)
  radius: ui.px(10)
  color: root.c.bg2
  border.width: 1
  border.color: failed ? root.c.bad : finished ? root.c.ok : root.c.accent

  Column {
    id: column
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: ui.px(15)
    spacing: ui.px(9)
    Row {
      width: parent.width
      spacing: ui.px(10)
      Icon { anchors.verticalCenter: parent.verticalCenter; name: root.failed ? "warning-circle" : root.finished ? "check-circle" : "spinner"; weight: "fill"; size: ui.px(18); color: root.failed ? root.c.bad : root.finished ? root.c.ok : root.c.accent
        RotationAnimation on rotation { from: 0; to: 360; duration: 1400; loops: Animation.Infinite; running: !root.failed && !root.finished && root.visible } }
      Column {
        width: parent.width - ui.px(28) - clockText.implicitWidth - ui.px(20)
        spacing: ui.px(2)
        Text { width: parent.width; elide: Text.ElideRight; text: "omarchy-yapperd " + (root.st ? root.st.version : "") + " " + root.kindLabel + " — " + root.phaseLabel; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.f13; font.weight: Font.DemiBold }
        Text { textFormat: Text.PlainText; width: parent.width; elide: Text.ElideRight; visible: text !== ""; text: root.finished ? "Took " + root.clock + ". Your session is signed in again." : root.failed ? (root.stale ? "The terminal may have been closed. Open it again from Install, or check pacman." : (root.st ? String(root.st.error) : "")) : root.compiling ? root.st.done + " of " + root.st.total + " crates · " + Math.round(root.fraction * 100) + "%" : (root.phase === "build" ? "cargo is starting" : "watch the terminal window for prompts"); color: root.failed ? root.c.bad : root.c.muted; font.family: ui.mono; font.pixelSize: ui.f11 }
      }
      Text { id: clockText; anchors.verticalCenter: parent.verticalCenter; text: root.clock; color: root.c.muted; font.family: ui.mono; font.pixelSize: ui.f12 }
    }
    // The bar: exact while compiling, a sweep otherwise
    Rectangle {
      width: parent.width
      height: ui.px(7)
      radius: ui.px(3.5)
      color: root.c.surface
      clip: true
      Rectangle {
        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
        radius: ui.px(3.5)
        width: root.finished || root.failed ? parent.width : root.compiling ? parent.width * root.fraction : 0
        color: root.failed ? root.c.bad : root.finished ? root.c.ok : root.c.accent
        Behavior on width { NumberAnimation { duration: 250 } }
      }
      Rectangle {
        visible: !root.failed && !root.finished && !root.compiling
        width: parent.width * 0.22
        anchors.top: parent.top; anchors.bottom: parent.bottom
        radius: ui.px(3.5)
        color: root.c.accent
        opacity: 0.6
        SequentialAnimation on x { loops: Animation.Infinite; running: visible; NumberAnimation { from: -width; to: parent.width; duration: 1500; easing.type: Easing.InOutSine } }
      }
    }
    Row {
      spacing: ui.px(8)
      visible: root.finished || root.failed
      PillButton { c: root.c; visible: root.failed; label: "Try again"; icon: "arrow-clockwise"; primary: true; round: true; onClicked: root.service.installDaemon(root.st && root.st.kind === "source" ? "source" : "bin") }
      PillButton { c: root.c; label: root.finished ? "Done" : "Dismiss"; round: true; onClicked: root.service.dismissInstall() }
    }
  }
}
