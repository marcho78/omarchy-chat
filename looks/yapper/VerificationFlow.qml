import QtQuick
import "../../shared"
import "../../shared/Palettes.js" as Palettes

// Device verification and recovery, in the Yapper look. Three ways in:
// confirm from another device (seven emoji on both screens), type the
// recovery key, or set encryption up from scratch. Also shows a fresh
// recovery key once and offers to reset it. Used inline in Settings and
// inside the verification modal.
Item {
  id: root
  property var c: Palettes.fallback()
  property var tips: null
  property var service: null
  property bool compact: false
  signal finished()
  Ui { id: ui }

  readonly property var flow: service ? service.activeFlow : null
  readonly property string flowState: flow ? String(flow.state) : ""
  readonly property bool inFlow: flowState !== "" && flowState !== "done" && flowState !== "cancelled"
  readonly property var status: service ? service.verification : null
  readonly property bool verified: service ? service.deviceVerified : false
  readonly property bool hasIdentity: status ? status.cross_signing === true : false
  readonly property int otherDevices: status && status.other_devices ? status.other_devices.length : 0
  readonly property bool hasTextFocus: keyField.hasFocus

  // menu | waiting | emoji | recovery | key | done | cancelled
  property string mode: "menu"
  property string recoveryKey: ""
  property bool busy: false
  property string errorText: ""
  property bool confirmReset: false

  onFlowStateChanged: {
    if (flowState === "emoji") mode = "emoji"
    else if (flowState === "ready" || flowState === "requested") { if (mode === "menu" || mode === "waiting") mode = "waiting" }
    else if (flowState === "done") { mode = "done"; if (service) service.refreshVerification() }
    else if (flowState === "cancelled") mode = "cancelled"
  }
  function reset() { mode = "menu"; errorText = ""; busy = false; confirmReset = false; if (service) service.dismissFlow() }
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
  function cancel() { if (flow) service.verifyCancel(flow.flow_id); reset() }
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

  implicitHeight: column.implicitHeight

  Column {
    id: column
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: ui.px(12)

    // Header
    Row {
      width: parent.width
      spacing: ui.px(12)
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: ui.px(40); height: ui.px(40); radius: ui.px(11)
        color: root.mode === "done" || (root.verified && root.mode === "menu") ? root.c.sel : (root.mode === "key" ? root.c.chip : root.c.chip)
        Icon {
          anchors.centerIn: parent
          name: root.mode === "done" || (root.verified && root.mode === "menu") ? "shield-check" : root.mode === "key" ? "key" : root.mode === "emoji" ? "smiley-wink" : "shield-warning"
          weight: root.mode === "emoji" || root.mode === "key" ? "regular" : "fill"
          size: ui.px(20)
          color: root.mode === "done" || (root.verified && root.mode === "menu") ? root.c.ok : root.mode === "key" ? root.c.warn : root.mode === "emoji" ? root.c.accent : root.c.bad
        }
      }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - ui.px(52)
        spacing: ui.px(2)
        Text {
          width: parent.width
          wrapMode: Text.Wrap
          text: {
            switch (root.mode) {
              case "waiting": return root.flow && !root.flow.outgoing ? "Verification request" : "Waiting for your other device"
              case "emoji": return "Do these match?"
              case "recovery": return "Enter your recovery key"
              case "key": return "Your recovery key"
              case "done": return "This device is verified"
              case "cancelled": return "Verification cancelled"
              default: return root.verified ? "This device is verified" : "Verify this device"
            }
          }
          color: root.c.fg
          font.family: ui.sans; font.pixelSize: ui.f14; font.weight: Font.DemiBold
        }
        Text {
          width: parent.width
          wrapMode: Text.Wrap
          lineHeight: 1.3
          text: {
            switch (root.mode) {
              case "waiting": return root.flow && !root.flow.outgoing && root.flowState === "requested"
                ? "Another of your devices" + (root.flow.other_device_name ? " (" + root.flow.other_device_name + ")" : "") + " wants to verify with this one."
                : "Accept the request on your other device. The same seven emoji will appear on both screens."
              case "emoji": return "Both screens should show the same seven emoji, in the same order."
              case "recovery": return "The key you saved when you set up encryption — 48 characters in groups of four."
              case "key": return "Save it somewhere safe before you close this. It cannot be shown again."
              case "done": return "Other people's clients now trust it, and encrypted history is backed up."
              case "cancelled": return "Nothing changed. Start again whenever you like."
              default: return root.verified
                ? "Encrypted history is backed up" + (root.status ? " · " + root.otherDevices + " other device" + (root.otherDevices === 1 ? "" : "s") : "") + "."
                : (root.hasIdentity
                    ? (root.otherDevices > 0 ? "Confirm from a device that is already verified, or type the recovery key you saved." : "No other devices are signed in. Type the recovery key you saved when you set up encryption.")
                    : "This account has no encryption identity yet. Setting it up creates your cross-signing keys and a recovery key, and turns on key backup.")
            }
          }
          color: root.c.muted
          font.family: ui.sans; font.pixelSize: ui.px(12.5)
        }
      }
    }

    // Menu
    Flow {
      width: parent.width
      spacing: ui.px(8)
      visible: root.mode === "menu" && !root.verified
      PillButton { c: root.c; visible: root.hasIdentity && root.otherDevices > 0; label: root.busy ? "Sending…" : "Use another device"; icon: "devices"; primary: true; enabled: !root.busy; onClicked: root.startRequest() }
      PillButton { c: root.c; visible: root.hasIdentity; label: "Use recovery key"; icon: "key"; primary: !(root.otherDevices > 0); onClicked: { root.errorText = ""; root.mode = "recovery"; Qt.callLater(function() { keyField.forceActiveFocus() }) } }
      PillButton { c: root.c; visible: !root.hasIdentity; label: root.busy ? "Setting up…" : "Set up encryption"; icon: "lock-simple"; primary: true; enabled: !root.busy; onClicked: root.doSetup() }
    }
    // Verified: recovery key management
    Column {
      width: parent.width
      spacing: ui.px(8)
      visible: root.mode === "menu" && root.verified
      Text {
        width: parent.width
        wrapMode: Text.Wrap
        lineHeight: 1.3
        text: root.confirmReset
          ? "A new key replaces the old one, which stops working. Nothing else changes; this device stays verified."
          : "Your recovery key was shown once when you set it up. If it is lost, make a new one."
        color: root.c.muted
        font.family: ui.sans; font.pixelSize: ui.f12
      }
      Row {
        spacing: ui.px(8)
        PillButton { c: root.c; visible: !root.confirmReset; label: "Reset recovery key"; icon: "key"; onClicked: root.confirmReset = true }
        PillButton { c: root.c; visible: root.confirmReset; label: root.busy ? "Creating…" : "Yes, make a new key"; danger: true; enabled: !root.busy; onClicked: root.doReset() }
        PillButton { c: root.c; visible: root.confirmReset; label: "Cancel"; onClicked: root.confirmReset = false }
      }
    }

    // Waiting / incoming request
    Row {
      spacing: ui.px(8)
      visible: root.mode === "waiting"
      PillButton { c: root.c; visible: root.flow && !root.flow.outgoing && root.flowState === "requested"; label: "Accept"; primary: true; onClicked: root.accept() }
      PillButton { c: root.c; label: root.flow && !root.flow.outgoing && root.flowState === "requested" ? "Decline" : "Cancel"; onClicked: root.cancel() }
    }

    // Emoji comparison
    Column {
      width: parent.width
      spacing: ui.px(12)
      visible: root.mode === "emoji"
      Grid {
        width: parent.width
        columns: root.compact ? 4 : 7
        columnSpacing: ui.px(8)
        rowSpacing: ui.px(8)
        Repeater {
          model: root.flow && root.flow.emojis ? root.flow.emojis : []
          delegate: Column {
            required property var modelData
            width: (parent.width - (parent.columns - 1) * parent.columnSpacing) / parent.columns
            spacing: ui.px(5)
            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              width: Math.min(parent.width, ui.px(62)); height: width; radius: ui.px(12)
              color: root.c.surface
              border.width: 1
              border.color: root.c.line
              Text { anchors.centerIn: parent; text: modelData.symbol; font.pixelSize: parent.width * 0.5 }
            }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: modelData.description; color: root.c.muted; elide: Text.ElideRight; font.family: ui.sans; font.pixelSize: ui.f11 }
          }
        }
      }
      Row {
        spacing: ui.px(8)
        PillButton { c: root.c; label: root.busy ? "…" : "They match"; icon: "check"; iconWeight: "bold"; primary: true; enabled: !root.busy; onClicked: root.confirm() }
        PillButton { c: root.c; label: "They don't match"; danger: true; onClicked: root.cancel() }
      }
    }

    // Recovery key entry
    Column {
      width: parent.width
      spacing: ui.px(8)
      visible: root.mode === "recovery"
      Field {
        id: keyField
        c: root.c
        width: parent.width
        placeholder: "EsTc XXXX XXXX XXXX …"
        maximumLength: 80
        onAccepted: root.doRecover()
        onEscaped: root.reset()
      }
      Row {
        spacing: ui.px(8)
        PillButton { c: root.c; label: root.busy ? "Checking…" : "Verify"; primary: true; enabled: !root.busy; onClicked: root.doRecover() }
        PillButton { c: root.c; label: "Back"; onClicked: root.reset() }
      }
    }

    // A new key, shown once
    Column {
      width: parent.width
      spacing: ui.px(8)
      visible: root.mode === "key"
      Rectangle {
        width: parent.width
        height: keyText.implicitHeight + ui.px(24)
        radius: ui.px(8)
        color: root.c.bg
        border.width: 1
        border.color: root.c.warn
        Text {
          id: keyText
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: ui.px(12)
          anchors.verticalCenter: parent.verticalCenter
          text: root.recoveryKey
          color: root.c.fg
          wrapMode: Text.Wrap
          font.family: ui.mono; font.pixelSize: ui.f13; font.letterSpacing: 1
        }
      }
      Row {
        spacing: ui.px(8)
        PillButton { c: root.c; label: "Copy"; icon: "copy"; onClicked: root.service.copyText(root.recoveryKey) }
        PillButton { c: root.c; label: "I have saved it"; primary: true; onClicked: { root.recoveryKey = ""; root.mode = root.verified ? "menu" : "done"; root.service.refreshVerification() } }
      }
    }

    // Done / cancelled
    Row {
      spacing: ui.px(8)
      visible: root.mode === "done" || root.mode === "cancelled"
      PillButton { c: root.c; label: root.mode === "done" ? "Done" : "Back"; primary: root.mode === "done"; onClicked: { root.reset(); root.finished() } }
    }

    Text {
      width: parent.width
      visible: root.errorText !== ""
      wrapMode: Text.Wrap
      text: root.errorText
      color: root.c.bad
      font.family: ui.sans; font.pixelSize: ui.f11
    }
  }
}
