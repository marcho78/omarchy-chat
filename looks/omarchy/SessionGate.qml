import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "../../shared"
import "../../shared/Format.js" as Format

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

  // Daemon missing: prebuilt or from source, both through pacman in a terminal.
  Column {
    id: missing
    width: parent.width
    spacing: Style.space(8)
    visible: root.service && root.service.checked && !root.service.installed
    readonly property var st: root.service ? root.service.installState : null
    property string kind: root.service ? root.service.installKind : "bin"

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      text: "Yapper needs the omarchy-yapperd daemon, release " + (root.service ? root.service.daemonPinVersion : "") + ", installed as a pacman package from a fixed commit of github.com/marcho78/omarchy-yapperd. pacman asks for your password in a terminal."
      color: root.fg
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }
    Flow {
      width: parent.width
      spacing: Style.spacing.controlGap
      visible: !missing.st
      Button { text: "Prebuilt · about a minute"; bordered: missing.kind === "bin"; onClicked: missing.kind = "bin" }
      Button { text: "From source · 10–25 min"; bordered: missing.kind === "source"; onClicked: missing.kind = "source" }
    }
    Flow {
      width: parent.width
      spacing: Style.spacing.controlGap
      visible: !missing.st
      Button { text: "Install in a terminal"; iconText: "󰆍"; bordered: true; onClicked: root.service.installDaemon(missing.kind) }
      Button { text: "Copy the command"; onClicked: root.service.copyText(root.service.installCommand(missing.kind)) }
      Button { text: "Check again"; onClicked: root.service.checkInstalled() }
    }
    // The install as the helper reports it
    Column {
      width: parent.width
      visible: !!missing.st
      spacing: Style.space(6)
      readonly property bool compiling: missing.st && missing.st.phase === "build" && Number(missing.st.total) > 0
      readonly property bool failed: missing.st && (missing.st.phase === "error" || root.service.installStale)
      readonly property bool finished: missing.st && missing.st.phase === "done"
      Text {
        textFormat: Text.PlainText
        width: parent.width
        wrapMode: Text.WordWrap
        text: missing.st ? ("omarchy-yapperd " + missing.st.version + " — " + (parent.finished ? "installed in " + Format.clock(root.service.installElapsed) : parent.failed ? "did not finish: " + (root.service.installStale ? "no news from the terminal" : missing.st.error) : parent.compiling ? "compiling " + missing.st.done + " of " + missing.st.total + " crates, " + Math.round(100 * missing.st.done / missing.st.total) + "%" : missing.st.phase) + "  ·  " + Format.clock(root.service.installElapsed)) : ""
        color: parent.failed ? Color.urgent : root.fg
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }
      Rectangle {
        width: parent.width
        height: Style.space(6)
        radius: Style.space(3)
        color: Util.alpha(root.fg, 0.15)
        Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; radius: Style.space(3); color: parent.parent.failed ? Color.urgent : Color.accent; width: parent.parent.finished || parent.parent.failed ? parent.width : parent.parent.compiling ? parent.width * Math.min(1, missing.st.done / missing.st.total) : 0 }
      }
      Flow {
        width: parent.width
        spacing: Style.spacing.controlGap
        visible: parent.finished || parent.failed
        Button { visible: parent.parent.failed; text: "Try again"; bordered: true; onClicked: root.service.installDaemon(missing.st && missing.st.kind === "source" ? "source" : "bin") }
        Button { text: "Dismiss"; onClicked: root.service.dismissInstall() }
      }
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

  // A saved session the daemon could not open: the keyring is locked or
  // its entry is gone. Offer to try again (with the unlock prompt) or to
  // drop it and sign in afresh.
  Column {
    width: parent.width
    spacing: Style.space(8)
    visible: root.service && root.service.savedSession && !root.service.pendingLogin
    property bool busy: false
    property bool confirmForget: false

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      text: "Your saved session could not be opened."
      color: root.fg
      font.family: root.fontFamily; font.pixelSize: Style.font.subtitle; font.bold: true
    }
    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      text: (root.service ? root.service.daemonError.replace(/^Could not read the saved session: /, "") : "")
        + ". Its secrets are in your keyring; unlocking it brings the session back without signing in again."
      color: root.fg; opacity: 0.8
      font.family: root.fontFamily; font.pixelSize: Style.font.body
    }
    Flow {
      id: savedActions
      width: parent.width
      spacing: Style.spacing.controlGap
      visible: !parent.confirmForget
      Button {
        text: parent.parent.busy ? "Opening…" : "Unlock and continue"
        iconText: "󰌾"
        bordered: true
        enabled: !parent.parent.busy
        onClicked: {
          var card = parent.parent
          card.busy = true; root.errorText = ""
          root.service.retrySession(function(r) { card.busy = false; if (!r.ok) root.errorText = r.error || "Could not open the session" })
        }
      }
      Button { text: "Forget this session"; enabled: !parent.parent.busy; onClicked: parent.parent.confirmForget = true }
    }
    Column {
      id: forgetConfirm
      width: parent.width
      spacing: Style.space(6)
      visible: parent.confirmForget
      readonly property var card: parent
      Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Forget it? Encrypted history on this device is lost unless you have your recovery key."
        color: root.fg; opacity: 0.8
        font.family: root.fontFamily; font.pixelSize: Style.font.caption
      }
      Row {
        spacing: Style.spacing.controlGap
        Button { text: "Forget"; bordered: true; onClicked: { forgetConfirm.card.confirmForget = false; root.service.forgetSession(function(r) { if (!r.ok) root.errorText = r.error || "Could not forget the session" }) } }
        Button { text: "Keep"; onClicked: forgetConfirm.card.confirmForget = false }
      }
    }
  }

  // Signed out: browser sign-in first, password as the fallback
  Column {
    width: parent.width
    spacing: Style.space(8)
    visible: root.service && root.service.connected && !root.service.loggedIn && !root.service.pendingLogin && !root.service.savedSession

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
      textFormat: Text.PlainText
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
    textFormat: Text.PlainText
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
