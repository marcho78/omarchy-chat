import QtQuick
import "../../shared"
import "../../shared/Palettes.js" as Palettes

// One dialog for every way the daemon gets installed: first install, update,
// reinstall. Two choices, one button. The install itself runs in a terminal
// window; the panel's progress card takes over from there.
Modal {
  id: root
  property var service: null
  property bool update: false
  property string kind: "bin"
  readonly property string version: update && service && service.daemonLatest !== "" ? service.daemonLatest : (service ? service.daemonPinVersion : "")
  icon: update ? "arrow-circle-up" : "download-simple"
  iconWeight: "fill"
  title: (update ? "Update to " : "Install the daemon ") + root.version
  description: "omarchy-yapperd is installed as a pacman package. Pick how; pacman asks for your password in a terminal."
  dialogWidth: ui.px(500)
  Ui { id: ui }
  onOpenChanged: if (open && service) kind = service.installKind

  component Choice: Rectangle {
    id: choice
    property string value: ""
    property string icon: ""
    property string heading: ""
    property string detail: ""
    property string time: ""
    readonly property bool on: root.kind === choice.value
    width: parent.width
    height: choiceColumn.implicitHeight + ui.px(28)
    radius: ui.px(10)
    color: choice.on ? root.c.sel : (choiceMouse.containsMouse ? root.c.hover : root.c.bg)
    border.width: choice.on ? 1.5 : 1
    border.color: choice.on ? root.c.accent : root.c.line
    Behavior on color { ColorAnimation { duration: 120 } }
    Rectangle {
      id: dot
      anchors.left: parent.left
      anchors.leftMargin: ui.px(14)
      anchors.top: parent.top
      anchors.topMargin: ui.px(16)
      width: ui.px(18); height: ui.px(18); radius: ui.px(9)
      color: "transparent"
      border.width: 1.5
      border.color: choice.on ? root.c.accent : root.c.muted
      Rectangle { anchors.centerIn: parent; width: ui.px(9); height: ui.px(9); radius: ui.px(4.5); color: root.c.accent; visible: choice.on }
    }
    Column {
      id: choiceColumn
      anchors.left: dot.right
      anchors.leftMargin: ui.px(12)
      anchors.right: parent.right
      anchors.rightMargin: ui.px(14)
      anchors.top: parent.top
      anchors.topMargin: ui.px(14)
      spacing: ui.px(4)
      Row {
        width: parent.width
        spacing: ui.px(8)
        Icon { anchors.verticalCenter: parent.verticalCenter; name: choice.icon; weight: "fill"; size: ui.px(15); color: choice.on ? root.c.accent : root.c.muted }
        Text { anchors.verticalCenter: parent.verticalCenter; text: choice.heading; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.f13; font.weight: Font.DemiBold }
        Item { width: parent.width - ui.px(23) - headingText.implicitWidth - timeText.implicitWidth - ui.px(16); height: 1; Text { id: headingText; visible: false; text: choice.heading; font.family: ui.sans; font.pixelSize: ui.f13; font.weight: Font.DemiBold } }
        Text { id: timeText; anchors.verticalCenter: parent.verticalCenter; text: choice.time; color: root.c.muted; font.family: ui.mono; font.pixelSize: ui.f11 }
      }
      Text { width: parent.width; wrapMode: Text.Wrap; lineHeight: 1.35; text: choice.detail; color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.f12 }
    }
    MouseArea { id: choiceMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.kind = choice.value }
  }

  Column {
    width: parent.width
    spacing: ui.px(8)
    Choice {
      value: "bin"; icon: "download-simple"; heading: "Prebuilt"; time: "about a minute"
      detail: "The binary that the daemon's GitHub Actions workflow built for this release, checked against the sha256 in its PKGBUILD. No compiler on this machine."
    }
    Choice {
      value: "source"; icon: "hammer"; heading: "Build from source"; time: "10–25 minutes"
      detail: "Compiles the daemon here with cargo. makepkg installs rust and git first if they are missing. You can keep using the desktop while it builds."
    }
  }
  Row {
    width: parent.width
    spacing: ui.px(10)
    PillButton {
      c: root.c; primary: true; round: true; icon: "terminal-window"
      label: root.update ? "Update in a terminal" : "Install in a terminal"
      onClicked: { root.service.installDaemon(root.kind, root.update); root.close() }
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: copyMouse.containsMouse ? "Copy the command instead" : "or copy the command"
      color: copyMouse.containsMouse ? root.c.accent : root.c.muted
      font.family: ui.sans; font.pixelSize: ui.f12
      font.underline: copyMouse.containsMouse
      MouseArea { id: copyMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.service.copyText(root.service.installCommand(root.kind, root.update)); root.close() } }
    }
  }
  Text {
    width: parent.width
    wrapMode: Text.Wrap
    lineHeight: 1.35
    text: "Both fetch github.com/marcho78/omarchy-yapperd at one fixed commit into ~/.cache/omarchy-yapper and run makepkg -si. The daemon restarts afterwards; your session stays signed in."
    color: root.c.muted
    font.family: ui.sans; font.pixelSize: ui.f11
  }
}
