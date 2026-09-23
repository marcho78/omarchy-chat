import QtQuick
import "../../shared"
import "../../shared/Palettes.js" as Palettes
import "../../shared/Format.js" as Format

// The community: what joining gives you, and the join itself.
Modal {
  id: root
  property var service: null
  icon: "users-three"
  title: "Join the Omarchy community?"
  description: (service ? service.communityAlias : "") + " — " + (community && community.rooms ? community.rooms.length : 0) + " rooms under one space."
  dialogWidth: ui.px(520)
  ring: root.c.accent
  Ui { id: ui }

  readonly property var community: service ? service.community : null
  readonly property bool joined: community !== null && community.joined === true
  property bool busy: false
  property string errorText: ""
  onOpenChanged: if (open && service) { errorText = ""; service.refreshCommunity() }

  Grid {
    width: parent.width
    columns: 2
    columnSpacing: ui.px(8)
    rowSpacing: ui.px(8)
    Repeater {
      model: root.community && root.community.rooms ? root.community.rooms : []
      delegate: Rectangle {
        required property var modelData
        width: (parent.width - parent.columnSpacing) / 2
        height: ui.px(84)
        radius: ui.px(9)
        color: root.c.bg
        border.width: 1
        border.color: root.c.line
        Column {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: ui.px(12)
          spacing: ui.px(4)
          Row {
            spacing: ui.px(7)
            Icon { anchors.verticalCenter: parent.verticalCenter; name: "hash"; size: ui.px(12); color: root.c.muted }
            Text { textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter; text: modelData.name; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.px(12.5); font.weight: Font.DemiBold }
          }
          Text { textFormat: Text.PlainText; width: parent.width; text: modelData.topic ? Format.oneLine(modelData.topic) : ""; color: root.c.muted; elide: Text.ElideRight; maximumLineCount: 1; font.family: ui.sans; font.pixelSize: ui.f11 }
          Text { textFormat: Text.PlainText; text: modelData.members + (modelData.members === 1 ? " member" : " members") + (modelData.joined ? " · joined" : ""); color: root.c.muted; font.family: ui.mono; font.pixelSize: ui.px(10.5) }
        }
      }
    }
  }
  Row {
    width: parent.width
    spacing: ui.px(10)
    Icon { name: "info"; size: ui.px(14); color: root.c.muted }
    Text { width: parent.width - ui.px(24); wrapMode: Text.Wrap; lineHeight: 1.35; text: "Joining lists you in nothing. A card with your name and a line of bio is published only if you write one in Settings › Community."; color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.f11 }
  }
  Text { textFormat: Text.PlainText; width: parent.width; visible: root.errorText !== ""; wrapMode: Text.Wrap; text: root.errorText; color: root.c.bad; font.family: ui.sans; font.pixelSize: ui.f11 }
  Row {
    width: parent.width
    spacing: ui.px(9)
    PillButton { c: root.c; width: parent.width - ui.px(110) - parent.spacing; label: root.joined ? "You are a member" : (root.busy ? "Joining…" : "Join the community"); primary: !root.joined; enabled: !root.busy && !root.joined && !!(root.community && root.community.exists); onClicked: { root.busy = true; root.errorText = ""; root.service.communityJoin(function(r) { root.busy = false; if (!r.ok) { root.errorText = r.error || "Could not join"; return } root.close() }) } }
    PillButton { c: root.c; width: ui.px(110); label: root.joined ? "Close" : "Not now"; enabled: !root.busy; onClicked: { if (!root.joined && root.service) root.service.set("communityPrompt", false); root.close() } }
  }
}
