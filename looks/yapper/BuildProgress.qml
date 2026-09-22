import QtQuick
import "../../shared"
import "../../shared/Palettes.js" as Palettes
import "../../shared/Format.js" as Format

// The daemon build as it runs: phase, a bar from crates compiled, elapsed
// time, and the note that the first build takes a while. Shown by the
// gate, the update card and Settings › Daemon.
Rectangle {
  id: root
  property var c: Palettes.fallback()
  property var service: null
  Ui { id: ui }

  readonly property string phase: service ? service.buildPhase : ""
  readonly property bool failed: phase === "error"
  readonly property bool finished: phase === "done"
  readonly property real fraction: service && service.buildTotal > 0 ? Math.min(1, service.buildDone / service.buildTotal) : 0
  readonly property string phaseLabel: phase === "fetch" ? "Fetching the source" : phase === "build" ? "Compiling" : phase === "install" ? "Installing" : phase === "start" ? "Starting the daemon" : phase === "done" ? "Installed and running" : phase === "error" ? "The build stopped" : "Preparing"

  implicitHeight: column.implicitHeight + ui.px(32)
  radius: ui.px(10)
  color: root.c.bg2
  border.width: 1
  border.color: failed ? root.c.bad : finished ? root.c.ok : root.c.accent

  Column {
    id: column
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: ui.px(16)
    spacing: ui.px(10)
    Row {
      width: parent.width
      spacing: ui.px(10)
      Icon { anchors.verticalCenter: parent.verticalCenter; name: root.failed ? "warning-circle" : root.finished ? "check-circle" : "gear"; weight: "fill"; size: ui.px(18); color: root.failed ? root.c.bad : root.finished ? root.c.ok : root.c.accent }
      Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - ui.px(100); elide: Text.ElideRight; text: "Yapper daemon " + (root.service ? root.service.buildTarget : "") + " — " + root.phaseLabel; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.f13; font.weight: Font.DemiBold }
      Text { anchors.verticalCenter: parent.verticalCenter; text: root.service ? Format.clock(root.service.buildElapsed) : ""; color: root.c.muted; font.family: ui.mono; font.pixelSize: ui.f11 }
    }
    // The bar: known progress while compiling, a sweep otherwise
    Rectangle {
      width: parent.width
      height: ui.px(8)
      radius: ui.px(4)
      color: root.c.surface
      clip: true
      Rectangle {
        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
        radius: ui.px(4)
        width: root.finished ? parent.width : root.phase === "build" ? parent.width * root.fraction : 0
        color: root.failed ? root.c.bad : root.finished ? root.c.ok : root.c.accent
        Behavior on width { NumberAnimation { duration: 250 } }
      }
      Rectangle {
        visible: !root.failed && !root.finished && root.phase !== "build"
        width: parent.width * 0.25
        anchors.top: parent.top; anchors.bottom: parent.bottom
        radius: ui.px(4)
        color: root.c.accent
        opacity: 0.7
        SequentialAnimation on x {
          loops: Animation.Infinite
          running: visible
          NumberAnimation { from: -width; to: parent.width; duration: 1400; easing.type: Easing.InOutSine }
        }
      }
    }
    Text {
      width: parent.width
      elide: Text.ElideRight
      text: root.failed ? "" : root.phase === "build" && root.service && root.service.buildTotal > 0
        ? root.service.buildDone + " of " + root.service.buildTotal + " crates" + (root.service.buildMessage ? " · " + root.service.buildMessage : "")
        : (root.service ? root.service.buildMessage : "")
      visible: text !== ""
      color: root.c.muted
      font.family: ui.mono; font.pixelSize: ui.f11
    }
    Text {
      width: parent.width
      visible: root.failed
      wrapMode: Text.Wrap
      text: root.service ? root.service.buildError : ""
      color: root.c.bad
      font.family: ui.mono; font.pixelSize: ui.f11
    }
    Text {
      width: parent.width
      visible: !root.failed && !root.finished
      wrapMode: Text.Wrap
      lineHeight: 1.35
      text: "The first build compiles matrix-rust-sdk and takes a while — roughly 10 to 25 minutes depending on the machine. Updates reuse what was built and are much faster. You can keep using the desktop; this card updates by itself."
      color: root.c.muted
      font.family: ui.sans; font.pixelSize: ui.f11
    }
    Flow {
      width: parent.width
      spacing: ui.px(8)
      PillButton { c: root.c; visible: root.failed; label: "Try again"; primary: true; round: true; onClicked: root.service.installDaemon(root.service.daemonLatestCommit !== "" && root.service.buildTarget === root.service.daemonLatest) }
      PillButton { c: root.c; visible: !root.failed && !root.finished; label: "Cancel"; round: true; onClicked: root.service.cancelBuild() }
      PillButton { c: root.c; label: "Show log"; icon: "terminal-window"; round: true; enabled: root.service && root.service.buildLogPath !== ""; onClicked: root.service.showBuildLog() }
    }
  }
}
