import QtQuick
import "../../shared"
import "../../shared/Palettes.js" as Palettes

// Device verification as a dialog: opened from the rail's shield, and by
// itself when another of your devices asks.
Modal {
  id: root
  property var service: null
  readonly property bool verified: service ? service.deviceVerified : false
  readonly property bool hasTextFocus: flow.hasTextFocus
  icon: flow.mode === "emoji" ? "smiley-wink" : flow.mode === "key" ? "key" : (verified && flow.mode === "menu") || flow.mode === "done" ? "shield-check" : "shield-warning"
  iconWeight: flow.mode === "emoji" || flow.mode === "key" ? "regular" : "fill"
  tone: flow.mode === "emoji" ? root.c.accent : flow.mode === "key" ? root.c.warn : (verified && flow.mode === "menu") || flow.mode === "done" ? root.c.ok : root.c.bad
  iconBg: flow.mode === "emoji" ? root.c.sel : root.c.chip
  ring: flow.mode === "emoji" ? root.c.accent : flow.mode === "key" ? root.c.warn : (verified && flow.mode === "menu") || flow.mode === "done" ? root.c.line : root.c.bad
  title: flow.mode === "emoji" ? "Do these match?" : flow.mode === "key" ? "Your recovery key" : flow.mode === "recovery" ? "Enter your recovery key" : flow.mode === "waiting" ? (flow.flow && !flow.flow.outgoing ? "Verification request" : "Waiting for your other device") : flow.mode === "done" ? "This device is verified" : verified ? "Encryption" : "Verify this device"
  description: flow.mode === "emoji" ? "Both screens should show the same seven emoji, in the same order." : flow.mode === "key" ? "Save it somewhere safe before you close this." : verified && flow.mode === "menu" ? "This device is verified; manage the recovery key here." : "Three ways in. Nothing is accepted for you."
  dialogWidth: flow.mode === "emoji" ? ui.px(520) : ui.px(480)
  Ui { id: ui }
  onOpenChanged: if (!open) flow.reset()

  VerificationFlow { id: flow; c: root.c; tips: root.tips; service: root.service; width: parent.width; onFinished: root.close() }
  Row {
    width: parent.width
    spacing: ui.px(10)
    visible: !root.verified && flow.mode === "menu"
    Icon { name: "warning"; size: ui.px(14); color: root.c.warn }
    Text { width: parent.width - ui.px(24); wrapMode: Text.Wrap; lineHeight: 1.35; text: "Until this device is verified, other people's clients show it as untrusted and history from before you signed in stays unreadable."; color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.f11 }
  }
}
