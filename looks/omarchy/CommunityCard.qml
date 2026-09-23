import QtQuick
import qs.Commons
import qs.Ui
import "../../shared"

// The one-time offer to join the Omarchy community, shown in the sidebar
// until the user joins or says "Not now". Joining is the only automatic
// thing; being listed to others is a separate choice in Settings.
Rectangle {
  id: root
  property var service: null
  property color fg: Color.foreground
  property string fontFamily: Style.font.family
  property bool busy: false
  property string errorText: ""

  readonly property var community: service ? service.community : null
  visible: service && service.loggedIn && service.communityPrompt && community && community.exists && !community.joined

  width: parent ? parent.width : 300
  implicitHeight: visible ? col.implicitHeight + Style.space(24) : 0
  radius: Style.space(10)
  color: Util.alpha(service ? service.accent : Color.accent, 0.08)
  border.width: 1
  border.color: Util.alpha(service ? service.accent : Color.accent, 0.4)

  Column {
    id: col
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.space(12)
    spacing: Style.space(8)
    Row {
      spacing: Style.space(8)
      Text { textFormat: Text.PlainText; text: "󰀏"; color: root.service ? root.service.accent : Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.title }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "Join the Omarchy community?"
        color: root.fg
        font.family: root.fontFamily; font.pixelSize: Style.font.subtitle; font.bold: true
      }
    }
    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      text: (root.community && root.community.member_count > 1 ? root.community.member_count + " people in " : "")
        + "a public space for Omarchy users — "
        + (root.community && root.community.rooms.length ? root.community.rooms.map(function(r) { return r.name }).join(", ") : "General, Help, Showcase, Plugins")
        + ". Joining adds the rooms to your list; whether other members can see you is a separate switch in Settings."
      color: root.fg; opacity: 0.85
      font.family: root.fontFamily; font.pixelSize: Style.font.caption
    }
    Text {
      textFormat: Text.PlainText
      width: parent.width
      visible: root.errorText !== ""
      wrapMode: Text.WordWrap
      text: root.errorText
      color: Color.urgent
      font.family: root.fontFamily; font.pixelSize: Style.font.caption
    }
    Row {
      spacing: Style.spacing.controlGap
      Button {
        text: root.busy ? "Joining…" : "Join"
        iconText: "󰜘"
        bordered: true
        enabled: !root.busy
        onClicked: {
          root.busy = true; root.errorText = ""
          root.service.communityJoin(function(r) { root.busy = false; if (!r.ok) root.errorText = r.error || "Could not join" })
        }
      }
      Button { text: "Not now"; enabled: !root.busy; onClicked: root.service.set("communityPrompt", false) }
    }
  }
}
