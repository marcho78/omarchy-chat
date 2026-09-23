import QtQuick
import qs.Commons
import qs.Ui
import "../../shared"

// Verify this device. Three ways in, one state machine out:
//   another device  → request → wait → 7 emoji → match? → done
//   recovery key    → type it → done
//   first device    → set up → recovery key shown once → done
// Incoming requests from our other devices land here too (Accept / Decline).
Rectangle {
  id: root
  property var service: null
  property color fg: Color.foreground
  readonly property color accent: service ? service.accent : Color.accent
  property string fontFamily: Style.font.family
  property bool compact: false           // popup: fewer words
  property bool inSettings: false        // always visible; offers key reset when verified
  property bool confirmReset: false

  readonly property var flow: service ? service.activeFlow : null
  readonly property string flowState: flow ? String(flow.state) : ""
  readonly property bool inFlow: flowState !== "" && flowState !== "done" && flowState !== "cancelled"
  readonly property var status: service ? service.verification : null
  readonly property bool hasIdentity: status ? status.cross_signing === true : false
  readonly property int otherDevices: status && status.other_devices ? status.other_devices.length : 0

  // "menu" | "waiting" | "emoji" | "recovery" | "setup" | "key" | "done" | "cancelled"
  property string mode: "menu"
  property string recoveryKey: ""      // shown once after setup
  property bool busy: false
  property string errorText: ""

  signal finished()

  visible: service && (inSettings || service.needsVerification || flow !== null || mode === "key")
  implicitHeight: visible ? column.implicitHeight + Style.space(28) : 0
  radius: Style.space(8)
  readonly property bool verified: service ? service.deviceVerified : false
  color: Util.alpha(Color.urgent, verified ? 0 : 0.08)
  border.width: 1
  border.color: verified ? Util.alpha(root.fg, 0.25) : Color.urgent

  readonly property bool hasTextFocus: keyField.activeFocus

  onFlowStateChanged: {
    if (flowState === "emoji") mode = "emoji"
    else if (flowState === "ready" || flowState === "requested") { if (mode === "menu" || mode === "waiting") mode = "waiting" }
    else if (flowState === "done") mode = "done"
    else if (flowState === "cancelled") mode = "cancelled"
  }

  function reset() { mode = "menu"; errorText = ""; busy = false; if (service) service.dismissFlow() }

  function startRequest() {
    if (busy) return
    busy = true; errorText = ""
    service.verifyRequest(function(r) {
      busy = false
      if (!r.ok) { errorText = r.error || "Could not send the request"; return }
      mode = "waiting"
    })
  }
  function accept() {
    if (!flow) return
    service.verifyAccept(flow.flow_id, function(r) { if (!r.ok) errorText = r.error || "Could not accept" })
    mode = "waiting"
  }
  function confirm() {
    if (!flow || busy) return
    busy = true
    service.verifyConfirm(flow.flow_id, function(r) { busy = false; if (!r.ok) errorText = r.error || "Could not confirm" })
  }
  function cancel() {
    if (flow) service.verifyCancel(flow.flow_id)
    reset()
  }
  function doRecover() {
    var k = keyField.text.trim()
    if (k === "" || busy) return
    busy = true; errorText = ""
    service.recover(k, function(r) {
      busy = false
      if (!r.ok) { errorText = r.error || "That key did not work"; return }
      keyField.text = ""
      mode = "done"
    })
  }
  function doReset() {
    if (busy) return
    busy = true; errorText = ""
    service.resetRecoveryKey(function(r) {
      busy = false; confirmReset = false
      if (!r.ok) { errorText = r.error || "Could not reset the key"; return }
      recoveryKey = String(r.result.recovery_key)
      mode = "key"
    })
  }
  function doSetup() {
    if (busy) return
    busy = true; errorText = ""
    service.setupRecovery(function(r) {
      busy = false
      if (!r.ok) { errorText = r.error || "Could not set up recovery"; return }
      recoveryKey = String(r.result.recovery_key)
      mode = "key"
    })
  }

  Column {
    id: column
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.space(14)
    spacing: Style.space(10)

    // Header
    Row {
      id: header
      width: parent.width
      spacing: Style.space(10)
      Text {
        id: headerIcon
        text: root.mode === "done" || (root.verified && root.mode === "menu") ? "󰄬" : (root.mode === "key" ? "󰌆" : "󰌾")
        color: root.mode === "done" || root.verified ? root.accent : Color.urgent
        font.family: root.fontFamily
        font.pixelSize: Style.font.iconLarge
        anchors.verticalCenter: parent.verticalCenter
      }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        width: header.width - headerIcon.width - header.spacing
        spacing: Style.space(1)
        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          text: {
            switch (root.mode) {
              case "waiting": return root.flow && !root.flow.outgoing ? "Verification request" : "Waiting for your other device"
              case "emoji": return "Compare the emoji"
              case "recovery": return "Enter your recovery key"
              case "setup": return "Set up encryption for this account"
              case "key": return "Your recovery key"
              case "done": return "This device is verified"
              case "cancelled": return "Verification cancelled"
              default: return root.verified ? "This device is verified" : "Verify this device"
            }
          }
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }
        Text {
          visible: root.mode === "menu"
          width: parent.width
          wrapMode: Text.WordWrap
          text: (root.verified
            ? "Encrypted history is backed up" + (root.status ? " · " + root.otherDevices + " other device" + (root.otherDevices === 1 ? "" : "s") : "")
            : "Other people's clients show it as untrusted until you do.")
            + (root.inSettings && root.service && root.service.secretsBackend === "keyring" ? " · Session secrets in your keyring"
               : root.inSettings && root.service && root.service.secretsBackend === "file" ? " · Session secrets in session.json (no keyring found)" : "")
          color: root.fg; opacity: 0.7
          font.family: root.fontFamily; font.pixelSize: Style.font.caption
        }
      }
    }

    // Verified (settings): recovery key management
    Column {
      width: parent.width
      spacing: Style.space(8)
      visible: root.mode === "menu" && root.verified

      Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: root.confirmReset
          ? "A new key replaces the old one, which stops working. Nothing else changes; this device stays verified."
          : "Your recovery key was shown once when you set it up. It cannot be shown again — if it is lost, make a new one."
        color: root.fg; opacity: 0.8
        font.family: root.fontFamily; font.pixelSize: Style.font.body
      }
      Row {
        spacing: Style.spacing.controlGap
        Button {
          visible: !root.confirmReset
          text: "Reset recovery key"; iconText: "󰌆"; bordered: true
          onClicked: root.confirmReset = true
        }
        Button {
          visible: root.confirmReset
          text: root.busy ? "Creating…" : "Yes, make a new key"; bordered: true
          enabled: !root.busy
          onClicked: root.doReset()
        }
        Button { visible: root.confirmReset; text: "Cancel"; onClicked: root.confirmReset = false }
      }
    }

    // Menu
    Column {
      width: parent.width
      spacing: Style.space(8)
      visible: root.mode === "menu" && !root.verified

      Text {
        width: parent.width
        wrapMode: Text.WordWrap
        visible: !root.compact
        text: root.hasIdentity
          ? (root.otherDevices > 0
              ? "Confirm from a device that is already verified — Element on your phone, for example — or type the recovery key you saved when you set up encryption."
              : "No other devices are signed in. Type the recovery key you saved when you set up encryption.")
          : "This account has no encryption identity yet. Setting it up creates your cross-signing keys and a recovery key, and turns on key backup."
        color: root.fg; opacity: 0.8
        font.family: root.fontFamily; font.pixelSize: Style.font.body
      }
      Flow {
        width: parent.width
        spacing: Style.spacing.controlGap
        Button {
          visible: root.hasIdentity && root.otherDevices > 0
          text: root.busy ? "Sending…" : "Use another device"
          iconText: "󰄛"
          bordered: true
          enabled: !root.busy
          onClicked: root.startRequest()
        }
        Button {
          visible: root.hasIdentity
          text: "Use recovery key"
          iconText: "󰌆"
          bordered: true
          onClicked: { root.mode = "recovery"; Qt.callLater(function() { keyField.forceActiveFocus() }) }
        }
        Button {
          visible: !root.hasIdentity
          text: root.busy ? "Setting up…" : "Set up encryption"
          iconText: "󰌾"
          bordered: true
          enabled: !root.busy
          onClicked: root.doSetup()
        }
      }
    }

    // Waiting / incoming
    Column {
      width: parent.width
      spacing: Style.space(8)
      visible: root.mode === "waiting"
      Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: root.flow && !root.flow.outgoing && root.flowState === "requested"
          ? "Another of your devices" + (root.flow.other_device_name ? " (" + root.flow.other_device_name + ")" : "") + " wants to verify with this one."
          : "Accept the request on your other device. The same seven emoji will appear on both screens."
        color: root.fg; opacity: 0.8
        font.family: root.fontFamily; font.pixelSize: Style.font.body
      }
      Row {
        spacing: Style.spacing.controlGap
        Button {
          visible: root.flow && !root.flow.outgoing && root.flowState === "requested"
          text: "Accept"; bordered: true
          onClicked: root.accept()
        }
        Button { text: root.flow && !root.flow.outgoing && root.flowState === "requested" ? "Decline" : "Cancel"; onClicked: root.cancel() }
      }
    }

    // Emoji
    Column {
      width: parent.width
      spacing: Style.space(10)
      visible: root.mode === "emoji"
      Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Check that both devices show these, in this order."
        color: root.fg; opacity: 0.8
        font.family: root.fontFamily; font.pixelSize: Style.font.body
      }
      Grid {
        width: parent.width
        columns: root.compact ? 4 : 7
        columnSpacing: Style.space(6)
        rowSpacing: Style.space(8)
        Repeater {
          model: root.flow && root.flow.emojis ? root.flow.emojis : []
          delegate: Column {
            required property var modelData
            width: (parent.width - (parent.columns - 1) * parent.columnSpacing) / parent.columns
            spacing: Style.space(4)
            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              width: Math.min(parent.width, Style.space(64))
              height: width
              radius: Style.space(10)
              color: Util.alpha(root.fg, 0.08)
              Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                text: modelData.symbol
                font.pixelSize: parent.width * 0.55
              }
            }
            Text {
              textFormat: Text.PlainText
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: modelData.description
              color: root.fg; opacity: 0.8
              font.family: root.fontFamily; font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }
        }
      }
      Row {
        spacing: Style.spacing.controlGap
        Button { text: root.busy ? "…" : "They match"; iconText: "󰄬"; bordered: true; enabled: !root.busy; onClicked: root.confirm() }
        Button { text: "They don't match"; onClicked: root.cancel() }
      }
    }

    // Recovery key
    Column {
      width: parent.width
      spacing: Style.space(8)
      visible: root.mode === "recovery"
      TextField {
        id: keyField
        width: parent.width
        maximumLength: 128
        placeholderText: "EsTc XXXX XXXX … (the 48-character key)"
        enabled: !root.busy
        onAccepted: root.doRecover()
      }
      Row {
        spacing: Style.spacing.controlGap
        Button { text: root.busy ? "Checking…" : "Recover"; bordered: true; enabled: !root.busy; onClicked: root.doRecover() }
        Button { text: "Back"; enabled: !root.busy; onClicked: { keyField.text = ""; root.reset() } }
      }
    }

    // Recovery key shown once
    Column {
      width: parent.width
      spacing: Style.space(8)
      visible: root.mode === "key"
      Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Save this somewhere safe. It is the only way to read your encrypted history on a new device if none of your others are around. It is shown once."
        color: root.fg; opacity: 0.85
        font.family: root.fontFamily; font.pixelSize: Style.font.body
      }
      Rectangle {
        width: parent.width
        implicitHeight: keyText.implicitHeight + Style.space(20)
        radius: Style.space(8)
        color: Util.alpha(root.fg, 0.06)
        Text {
          id: keyText
          anchors.centerIn: parent
          width: parent.width - Style.space(20)
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WrapAnywhere
          text: root.recoveryKey
          color: root.accent
          font.family: root.fontFamily; font.pixelSize: Style.font.subtitle
        }
      }
      Row {
        spacing: Style.spacing.controlGap
        Button { text: "Copy"; iconText: "󰆏"; bordered: true; onClicked: root.service.copyText(root.recoveryKey) }
        Button { text: "I saved it"; bordered: true; onClicked: { root.recoveryKey = ""; root.mode = root.inSettings ? "menu" : "done" } }
      }
    }

    // Done / cancelled
    Column {
      width: parent.width
      spacing: Style.space(8)
      visible: root.mode === "done" || root.mode === "cancelled"
      Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: root.mode === "done"
          ? "Your other devices now trust this one, and encrypted history will fill in from backup."
          : ((root.flow && root.flow.reason) ? String(root.flow.reason) : "Nothing was changed.")
        color: root.fg; opacity: 0.85
        font.family: root.fontFamily; font.pixelSize: Style.font.body
      }
      Button {
        text: root.mode === "done" ? "Close" : "Try again"
        bordered: true
        onClicked: { var done = root.mode === "done"; root.reset(); if (done) root.finished() }
      }
    }

    Text {
      textFormat: Text.PlainText
      width: parent.width
      wrapMode: Text.WordWrap
      visible: root.errorText !== ""
      text: root.errorText
      color: Color.urgent
      font.family: root.fontFamily; font.pixelSize: Style.font.caption
    }
  }
}
