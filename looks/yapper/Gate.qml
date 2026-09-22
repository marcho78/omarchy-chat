import QtQuick
import Quickshell
import "../../shared"
import "../../shared/Palettes.js" as Palettes

// Before there is a session: the daemon is missing, stopped, or has no
// account yet — build it, start it, sign in (browser first, password as
// the fallback), wait for the browser, or unlock a saved session.
Item {
  id: root
  property var c: Palettes.fallback()
  property var tips: null
  property var service: null
  Ui { id: ui }

  readonly property bool checked: service ? service.checked : false
  readonly property bool installed: service ? service.installed : false
  readonly property bool connected: service ? service.connected : false
  readonly property bool pendingLogin: service ? service.pendingLogin : false
  readonly property bool savedSession: service ? service.savedSession : false
  readonly property string state: !checked ? "checking" : !installed ? "missing" : !connected ? "stopped" : pendingLogin ? "browser" : savedSession ? "locked" : "signin"
  readonly property bool hasTextFocus: homeserverField.hasFocus || userField.hasFocus || passwordField.hasFocus
  property bool usePassword: false
  property bool busy: false
  property string errorText: ""
  property string copied: ""   // which card's command was copied
  property bool confirmForget: false
  signal installRequested()
  function focusFirst() { if (root.state === "signin") homeserverField.forceActiveFocus() }
  function clearSecrets() { passwordField.text = "" }
  Timer { id: copiedReset; interval: 1600; onTriggered: root.copied = "" }
  component Note: Text { width: parent.width; wrapMode: Text.Wrap; lineHeight: 1.35; color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.f12 }

  function startOauth() {
    if (root.busy) return
    root.busy = true; root.errorText = ""
    root.service.loginOauth(homeserverField.text, function(r) { root.busy = false; if (!r.ok) root.errorText = r.error || "Could not start browser sign-in" })
  }
  function startPassword() {
    if (root.busy) return
    root.busy = true; root.errorText = ""
    root.service.login(homeserverField.text, userField.text, passwordField.text, function(r) {
      root.busy = false
      if (!r.ok) root.errorText = r.error || "Sign-in failed"; else passwordField.text = ""
    })
  }

  Flickable {
    anchors.fill: parent
    contentHeight: column.implicitHeight + ui.px(60)
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    Column {
      id: column
      anchors.horizontalCenter: parent.horizontalCenter
      y: Math.max(ui.px(30), (root.height - implicitHeight) / 2)
      width: Math.min(root.width - ui.px(60), ui.px(520))
      spacing: ui.px(22)

      // Icon, title, body
      Column {
        width: parent.width
        spacing: ui.px(13)
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          width: ui.px(54); height: ui.px(54); radius: ui.px(15)
          color: root.state === "signin" || root.state === "browser" ? root.c.sel : root.c.chip
          Icon {
            anchors.centerIn: parent
            name: root.state === "missing" ? "terminal-window" : root.state === "stopped" ? "plugs" : root.state === "browser" ? "globe" : root.state === "locked" ? "key" : root.state === "checking" ? "circle-notch" : "lock-simple"
            weight: root.state === "signin" ? "fill" : "regular"
            size: ui.px(28)
            color: root.state === "signin" || root.state === "browser" ? root.c.accent : root.c.warn
          }
        }
        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
          text: root.state === "missing" ? "The daemon is not installed" : root.state === "stopped" ? "The daemon is installed but not running" : root.state === "browser" ? "Waiting for the browser" : root.state === "locked" ? "Your saved session could not be opened" : root.state === "checking" ? "Looking for the daemon…" : "Sign in to Matrix"
          color: root.c.fg
          font.family: ui.sans; font.pixelSize: ui.px(19); font.weight: Font.DemiBold; font.letterSpacing: -0.3
        }
        Text {
          width: Math.min(parent.width, ui.px(420))
          anchors.horizontalCenter: parent.horizontalCenter
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
          lineHeight: 1.35
          text: root.state === "missing" ? "Yapper is QML only — everything that touches keys or the network lives in a small daemon you build from source. No binary is downloaded, ever."
            : root.state === "stopped" ? "Start it once and Yapper keeps it running from here on."
            : root.state === "browser" ? ""
            : root.state === "locked" ? (root.service ? root.service.daemonError.replace(/^Could not read the saved session: /, "") : "") + ". Its secrets are in your keyring; unlocking it brings the session back without signing in again."
            : root.state === "checking" ? ""
            : "Any homeserver works. Sign in with the browser — Google, GitHub, whatever yours offers — or with a password."
          color: root.c.muted
          font.family: ui.sans; font.pixelSize: ui.f13
          visible: text !== ""
        }
      }

      // Missing: one card, one button; the dialog asks prebuilt or source
      Column {
        width: parent.width
        visible: root.state === "missing"
        spacing: ui.px(12)
        Rectangle {
          width: parent.width
          visible: !(root.service && root.service.installState !== null)
          height: missingColumn.implicitHeight + ui.px(32)
          radius: ui.px(10)
          color: root.c.bg2
          border.width: 1
          border.color: root.c.line
          Column {
            id: missingColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: ui.px(16)
            spacing: ui.px(10)
            Text { text: "Install the daemon"; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.f13; font.weight: Font.DemiBold }
            Note { text: "Yapper talks to omarchy-yapperd, a small daemon that holds your Matrix session and keys. It installs as a pacman package, prebuilt in about a minute or compiled here from source, from a fixed commit of github.com/marcho78/omarchy-yapperd." }
            Flow {
              width: parent.width
              spacing: ui.px(8)
              PillButton { c: root.c; label: "Install omarchy-yapperd " + (root.service ? root.service.daemonPinVersion : ""); icon: "download-simple"; iconWeight: "fill"; primary: true; round: true; onClicked: root.installRequested() }
              PillButton { c: root.c; label: "Check again"; icon: "arrows-clockwise"; round: true; onClicked: root.service.checkInstalled() }
            }
          }
        }
        InstallProgress { width: parent.width; visible: root.service && root.service.installState !== null; c: root.c; service: root.service }
      }

      // Stopped: the unit
      Rectangle {
        width: parent.width
        visible: root.state === "stopped"
        height: stoppedColumn.implicitHeight + ui.px(32)
        radius: ui.px(10)
        color: root.c.bg2
        border.width: 1
        border.color: root.c.line
        Column {
          id: stoppedColumn
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: ui.px(16)
          spacing: ui.px(12)
          Row {
            width: parent.width
            spacing: ui.px(11)
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: ui.px(9); height: ui.px(9); radius: ui.px(5); color: root.service && root.service.starting ? root.c.accent : root.c.warn }
            Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - ui.px(140); text: "omarchy-yapperd.service"; color: root.c.fg; font.family: ui.mono; font.pixelSize: ui.f11 }
            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: unitState.implicitWidth + ui.px(20); height: ui.px(22); radius: height / 2
              color: root.c.chip
              Text { id: unitState; anchors.centerIn: parent; text: root.service && root.service.starting ? "starting" : "inactive (dead)"; color: root.service && root.service.starting ? root.c.accent : root.c.warn; font.family: ui.sans; font.pixelSize: ui.f11 }
            }
          }
          Rectangle {
            width: parent.width
            height: ui.px(38)
            radius: ui.px(7)
            color: root.c.bg
            border.width: 1
            border.color: root.c.line
            Text { anchors.left: parent.left; anchors.leftMargin: ui.px(12); anchors.verticalCenter: parent.verticalCenter; text: "systemctl --user start omarchy-yapperd"; color: root.c.muted; font.family: ui.mono; font.pixelSize: ui.f11 }
          }
          Text { visible: root.service && root.service.startError !== ""; width: parent.width; wrapMode: Text.Wrap; text: root.service ? root.service.startError : ""; color: root.c.bad; font.family: ui.sans; font.pixelSize: ui.f11 }
          Row {
            spacing: ui.px(8)
            PillButton { c: root.c; label: root.service && root.service.starting ? "Starting…" : "Start the daemon"; primary: true; round: true; enabled: !(root.service && root.service.starting); onClicked: root.service.startDaemon() }
            PillButton { c: root.c; label: "View logs"; round: true; onClicked: Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "journalctl --user -u omarchy-yapperd -n 200 -f"]) }
          }
        }
      }

      // Locked: a saved session the keyring would not open
      Column {
        width: parent.width
        visible: root.state === "locked"
        spacing: ui.px(10)
        Flow {
          width: parent.width
          spacing: ui.px(8)
          visible: !root.confirmForget
          PillButton { c: root.c; label: root.busy ? "Opening…" : "Unlock and continue"; icon: "lock-simple-open"; primary: true; round: true; enabled: !root.busy; onClicked: { root.busy = true; root.errorText = ""; root.service.retrySession(function(r) { root.busy = false; if (!r.ok) root.errorText = r.error || "Could not open the session" }) } }
          PillButton { c: root.c; label: "Forget this session"; round: true; enabled: !root.busy; onClicked: root.confirmForget = true }
        }
        Column {
          width: parent.width
          visible: root.confirmForget
          spacing: ui.px(8)
          Text { width: parent.width; wrapMode: Text.Wrap; text: "Forget it? Encrypted history on this device is lost unless you have your recovery key."; color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.f12 }
          Row {
            spacing: ui.px(8)
            PillButton { c: root.c; label: "Forget"; danger: true; round: true; onClicked: { root.confirmForget = false; root.service.forgetSession(function(r) { if (!r.ok) root.errorText = r.error || "Could not forget the session" }) } }
            PillButton { c: root.c; label: "Keep"; round: true; onClicked: root.confirmForget = false }
          }
        }
      }

      // Sign in
      Rectangle {
        width: parent.width
        visible: root.state === "signin"
        height: signinColumn.implicitHeight + ui.px(40)
        radius: ui.px(11)
        color: root.c.bg2
        border.width: 1
        border.color: root.c.line
        Column {
          id: signinColumn
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: ui.px(20)
          spacing: ui.px(14)
          Column {
            width: parent.width
            spacing: ui.px(6)
            Text { text: "Homeserver"; color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.f11; font.weight: Font.Medium }
            Field {
              id: homeserverField
              c: root.c
              width: parent.width
              height: ui.px(40)
              icon: "globe-simple"
              text: root.service ? root.service.defaultHomeserver : "https://matrix.org"
              maximumLength: 256
              onAccepted: { if (root.usePassword) userField.forceActiveFocus(); else root.startOauth() }
            }
          }
          Rectangle {
            width: parent.width
            height: ui.px(44)
            radius: ui.px(9)
            color: ssoMouse.containsMouse ? Qt.lighter(root.c.accent, 1.1) : root.c.accent
            opacity: root.busy ? 0.6 : 1
            Row {
              anchors.centerIn: parent
              spacing: ui.px(9)
              Icon { anchors.verticalCenter: parent.verticalCenter; name: "browser"; size: ui.px(17); color: root.c.bg2 }
              Text { anchors.verticalCenter: parent.verticalCenter; text: root.busy && !root.usePassword ? "Opening the browser…" : "Sign in with the browser"; color: root.c.bg2; font.family: ui.sans; font.pixelSize: ui.px(13.5); font.weight: Font.DemiBold }
            }
            MouseArea { id: ssoMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: !root.busy; onClicked: root.startOauth() }
          }
          Row {
            width: parent.width
            spacing: ui.px(11)
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: (parent.width - orText.implicitWidth - ui.px(22)) / 2; height: 1; color: root.c.line }
            Text { id: orText; anchors.verticalCenter: parent.verticalCenter; text: "or sign in with a password"; color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.f11 }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: (parent.width - orText.implicitWidth - ui.px(22)) / 2; height: 1; color: root.c.line }
          }
          Column {
            width: parent.width
            spacing: ui.px(9)
            Field { id: userField; c: root.c; width: parent.width; height: ui.px(40); icon: "at"; placeholder: "username"; maximumLength: 256; onAccepted: passwordField.forceActiveFocus() }
            Field { id: passwordField; c: root.c; width: parent.width; height: ui.px(40); icon: "key"; placeholder: "password"; maximumLength: 1024; echoMode: TextInput.Password; onAccepted: root.startPassword() }
            Rectangle {
              width: parent.width
              height: ui.px(40)
              radius: ui.px(9)
              color: pwMouse.containsMouse ? root.c.hover : "transparent"
              border.width: 1
              border.color: root.c.line
              opacity: root.busy ? 0.6 : 1
              Text { anchors.centerIn: parent; text: root.busy && root.usePassword ? "Signing in…" : "Sign in"; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.f13 }
              MouseArea { id: pwMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: !root.busy; onClicked: { root.usePassword = true; root.startPassword() } }
            }
          }
          Rectangle { width: parent.width; height: 1; color: root.c.line }
          Row {
            width: parent.width
            spacing: ui.px(9)
            Icon { name: "shield-check"; weight: "fill"; size: ui.px(14); color: root.c.ok }
            Text { width: parent.width - ui.px(23); wrapMode: Text.Wrap; lineHeight: 1.35; text: "The password goes straight to the daemon's socket and the field is cleared. The shell never stores it."; color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.f11 }
          }
        }
      }

      // Browser sign-in in progress
      Rectangle {
        width: parent.width
        visible: root.state === "browser"
        height: browserColumn.implicitHeight + ui.px(44)
        radius: ui.px(11)
        color: root.c.bg2
        border.width: 1
        border.color: root.c.line
        Column {
          id: browserColumn
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.top
          anchors.topMargin: ui.px(22)
          width: parent.width - ui.px(44)
          spacing: ui.px(15)
          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: ui.px(6)
            Repeater {
              model: 3
              delegate: Rectangle {
                required property int index
                width: ui.px(9); height: ui.px(9); radius: ui.px(5)
                color: root.c.accent
                SequentialAnimation on opacity {
                  loops: Animation.Infinite
                  running: root.state === "browser"
                  PauseAnimation { duration: index * 200 }
                  NumberAnimation { to: 1; duration: 400 }
                  NumberAnimation { to: 0.3; duration: 400 }
                  PauseAnimation { duration: (2 - index) * 200 }
                }
              }
            }
          }
          Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; lineHeight: 1.35; textFormat: Text.StyledText; text: "Finish signing in to <font face=\"" + ui.mono + "\" color=\"" + root.c.fg + "\">" + (root.service ? root.service.defaultHomeserver.replace(/^https?:\/\//, "") : "") + "</font> in the browser window that just opened. Yapper picks it up from here."; color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.px(12.5) }
          PillButton { c: root.c; anchors.horizontalCenter: parent.horizontalCenter; label: "Cancel"; round: true; onClicked: root.service.loginCancel() }
        }
      }

      Text {
        width: parent.width
        visible: root.errorText !== ""
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: root.errorText
        color: root.c.bad
        font.family: ui.sans; font.pixelSize: ui.f12
      }
    }
  }
}
