import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Everything that stands between the user and a signed-in session, in
// order: the daemon is missing, the daemon is not running, sign in, waiting
// for the browser. Hidden entirely once signed in.
Column {
  id: root
  property var service: null
  property color fg: Color.foreground
  property string fontFamily: Style.font.family
  property bool usePassword: false
  property bool busy: false
  property string errorText: ""

  readonly property bool active: service && !service.loggedIn
  readonly property bool hasTextFocus: hsField.activeFocus || userField.activeFocus || pwField.activeFocus
  visible: active
  spacing: Style.space(8)

  function focusFirst() {
    if (hsField.visible) hsField.forceActiveFocus()
  }

  // Daemon missing: show the command, never fetch a binary.
  Column {
    width: parent.width
    spacing: Style.space(8)
    visible: root.service && root.service.checked && !root.service.installed

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      text: "Yapper needs the omarchy-yapperd daemon. It is built from source on your machine with makepkg — read the PKGBUILD first if you like. The first build takes a few minutes."
      color: root.fg
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }
    Text {
      width: parent.width
      wrapMode: Text.WrapAnywhere
      text: root.service ? root.service.installCommand : ""
      color: Color.accent
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
    Flow {
      width: parent.width
      spacing: Style.spacing.controlGap
      Button { text: "Copy command"; bordered: true; onClicked: root.service.copyText(root.service.installCommand) }
      Button { text: "Open in terminal"; iconText: "󰆍"; bordered: true; onClicked: root.service.openInstallTerminal() }
      Button { text: "Check again"; bordered: true; onClicked: root.service.checkInstalled() }
    }
  }

  // Installed but not running
  Column {
    width: parent.width
    spacing: Style.space(8)
    visible: root.service && root.service.checked && root.service.installed && !root.service.connected

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      text: root.service && root.service.starting ? "Starting omarchy-yapperd…" : "The daemon is installed but not running."
      color: root.fg
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }
    Button {
      text: root.service && root.service.starting ? "Starting…" : "Start daemon"
      iconText: "󰐊"
      bordered: true
      enabled: !(root.service && root.service.starting)
      onClicked: root.service.startDaemon()
    }
    Text {
      width: parent.width
      visible: root.service && root.service.startError !== ""
      wrapMode: Text.WordWrap
      text: root.service ? root.service.startError : ""
      color: Color.urgent
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  // Signed out: browser sign-in first, password as the fallback
  Column {
    width: parent.width
    spacing: Style.space(8)
    visible: root.service && root.service.connected && !root.service.loggedIn && !root.service.pendingLogin

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      text: root.usePassword
        ? "The password goes only to the local daemon, which keeps an access token and never the password."
        : "Sign in with a Matrix account. Your browser opens on the homeserver's own sign-in page — Google, GitHub or a password there — and nothing but the resulting token reaches this machine."
      color: root.fg
      opacity: 0.85
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }
    TextField {
      id: hsField
      width: parent.width
      maximumLength: 256
      text: root.service ? root.service.defaultHomeserver : ""
      placeholderText: "Homeserver, e.g. matrix.org"
      enabled: !root.busy
      onAccepted: { if (root.usePassword) userField.forceActiveFocus(); else root.startOauth() }
    }
    TextField {
      id: userField
      width: parent.width
      visible: root.usePassword
      maximumLength: 256
      placeholderText: "Username"
      enabled: !root.busy
      onAccepted: pwField.forceActiveFocus()
    }
    TextField {
      id: pwField
      width: parent.width
      visible: root.usePassword
      maximumLength: 1024
      password: true
      placeholderText: "Password"
      enabled: !root.busy
      onAccepted: root.startPassword()
    }
    Flow {
      width: parent.width
      spacing: Style.spacing.controlGap
      Button {
        visible: !root.usePassword
        text: root.busy ? "Starting…" : "Sign in with browser"
        iconText: "󰖟"
        bordered: true
        enabled: !root.busy
        onClicked: root.startOauth()
      }
      Button {
        visible: root.usePassword
        text: root.busy ? "Signing in…" : "Sign in"
        iconText: "󰍂"
        bordered: true
        enabled: !root.busy
        onClicked: root.startPassword()
      }
      Button {
        text: root.usePassword ? "Use the browser instead" : "Use a password instead"
        enabled: !root.busy
        onClicked: { root.usePassword = !root.usePassword; root.errorText = "" }
      }
    }
  }

  // Browser sign-in in progress
  Column {
    width: parent.width
    spacing: Style.space(8)
    visible: root.service && root.service.pendingLogin

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      text: "Finish signing in in your browser. This updates by itself when the homeserver sends you back."
      color: root.fg
      opacity: 0.85
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }
    Button { text: "Cancel"; bordered: true; onClicked: root.service.loginCancel() }
  }

  Text {
    width: parent.width
    wrapMode: Text.WordWrap
    visible: root.errorText !== ""
    text: root.errorText
    color: Color.urgent
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  function startOauth() {
    if (root.busy) return
    root.busy = true
    root.errorText = ""
    root.service.loginOauth(hsField.text, function(r) {
      root.busy = false
      if (!r.ok) root.errorText = r.error || "Could not start browser sign-in"
    })
  }

  function startPassword() {
    if (root.busy) return
    root.busy = true
    root.errorText = ""
    root.service.login(hsField.text, userField.text, pwField.text, function(r) {
      root.busy = false
      if (!r.ok) root.errorText = r.error || "Login failed"
      else pwField.text = ""
    })
  }

  function clearSecrets() { pwField.text = "" }
}
