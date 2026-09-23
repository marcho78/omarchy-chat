import QtQuick
import QtQuick.Controls
import "../../shared"
import "../../shared/Palettes.js" as Palettes

// The community directory: members of the space who published a card —
// name, bio, their Omarchy theme, whether they take direct messages.
Item {
  id: root
  property var c: Palettes.fallback()
  property var tips: null
  property var service: null
  property string query: ""
  signal messageRequested(string userId)
  signal closeRequested()
  Ui { id: ui }

  property var people: []
  property bool loading: false
  property string errorText: ""
  property string confirmBlock: ""      // user id awaiting confirmation
  readonly property bool hasTextFocus: field.hasFocus
  function focusField() { field.forceActiveFocus(); field.selectAll() }
  onQueryChanged: { if (field.text !== query) field.text = query; debounce.restart() }
  onVisibleChanged: if (visible) root.load()
  Timer { id: debounce; interval: 300; onTriggered: root.load() }

  function load() {
    if (!root.service) return
    root.loading = true; root.errorText = ""
    var q = field.text.trim()
    root.service.people(q, function(r) {
      root.loading = false
      if (field.text.trim() !== q) return
      if (!r.ok) { root.errorText = r.error || "Could not load people"; return }
      root.people = r.result
    })
  }
  function block(userId) {
    root.service.ignore(userId, function(r) {
      root.confirmBlock = ""
      if (!r.ok) { root.errorText = r.error || "Could not block"; return }
      root.people = root.people.filter(function(p) { return p.user_id !== userId })
    })
  }
  // The color of a theme's dot: our palette's accent when the names
  // match, otherwise a stable hue from the name.
  function themeColor(name) {
    var key = String(name || "").toLowerCase().replace(/[^a-z]/g, "")
    var map = { tokyonight: "tokyonight", catppuccin: "catppuccin", catppuccinlatte: "latte", gruvbox: "gruvbox", everforest: "everforest", rosepine: "rosepine", matteblack: "matte" }
    if (map[key]) return Palettes.themes[map[key]].v.accent
    return Palettes.colorOf(key, root.c.light)
  }

  Item {
    id: header
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    // As tall as its text needs: the description wraps in narrow columns.
    height: field.y + field.height + ui.px(14)
    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: root.c.line }
    Row {
      id: titleRow
      anchors.left: parent.left
      anchors.leftMargin: ui.px(24)
      anchors.top: parent.top
      anchors.topMargin: ui.px(18)
      spacing: ui.px(10)
      Icon { anchors.verticalCenter: parent.verticalCenter; name: "address-book"; size: ui.px(19); color: root.c.accent }
      Text { anchors.verticalCenter: parent.verticalCenter; text: "People"; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.f18; font.weight: Font.DemiBold; font.letterSpacing: -0.3 }
    }
    IconButton { anchors.right: parent.right; anchors.rightMargin: ui.px(16); anchors.top: parent.top; anchors.topMargin: ui.px(14); c: root.c; tips: root.tips; icon: "x"; size: ui.px(32); iconSize: ui.px(16); tooltip: "Back to chat (Esc)"; onClicked: root.closeRequested() }
    Text {
      id: blurb
      anchors.left: parent.left
      anchors.leftMargin: ui.px(24)
      anchors.top: titleRow.bottom
      anchors.topMargin: ui.px(5)
      width: Math.min(parent.width - ui.px(48) - ui.px(40), ui.px(620))
      wrapMode: Text.Wrap
      textFormat: Text.StyledText
      text: "Members of <font face=\"" + ui.mono + "\">" + (root.service ? root.service.communityAlias : "") + "</font> who chose to publish a card. Nobody is listed without doing it themselves, and you can withdraw yours at any time."
      color: root.c.muted
      lineHeight: 1.3
      font.family: ui.sans; font.pixelSize: ui.px(12.5)
    }
    Field {
      id: field
      c: root.c
      anchors.left: parent.left
      anchors.leftMargin: ui.px(24)
      anchors.top: blurb.bottom
      anchors.topMargin: ui.px(10)
      width: Math.min(parent.width - ui.px(48), ui.px(320))
      height: ui.px(32)
      color: root.c.bg2
      icon: "magnifying-glass"
      placeholder: "Find someone by name or id"
      maximumLength: 80
      onTextChanged: debounce.restart()
      onAccepted: { debounce.stop(); root.load() }
      onEscaped: { if (text !== "") text = ""; else root.closeRequested() }
    }
  }

  Flickable {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: header.bottom
    anchors.bottom: parent.bottom
    anchors.margins: ui.px(16)
    anchors.topMargin: ui.px(16)
    contentHeight: grid.implicitHeight + ui.px(16)
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
    Grid {
      id: grid
      width: parent.width
      columns: Math.max(1, Math.floor((width + ui.px(10)) / (ui.px(268) + ui.px(10))))
      columnSpacing: ui.px(10)
      rowSpacing: ui.px(10)
      readonly property real cardWidth: (width - (columns - 1) * columnSpacing) / columns
      Repeater {
        model: root.people
        delegate: Rectangle {
          id: card
          required property var modelData
          readonly property bool open: modelData.open_to_dm === true
          readonly property bool me: root.service && modelData.user_id === root.service.userId
          readonly property bool confirming: root.confirmBlock === modelData.user_id
          width: grid.cardWidth
          height: cardColumn.implicitHeight + ui.px(30)
          radius: ui.px(10)
          color: root.c.bg2
          border.width: 1
          border.color: cardMouse.containsMouse ? root.c.accent : root.c.line
          MouseArea { id: cardMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
          Column {
            id: cardColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: ui.px(15)
            spacing: ui.px(11)
            Row {
              width: parent.width
              spacing: ui.px(11)
              Avatar { anchors.verticalCenter: parent.verticalCenter; service: root.service; mxc: card.modelData.avatar || ""; name: card.modelData.name || card.modelData.user_id; userId: card.modelData.user_id; size: ui.px(40); fallbackColor: Palettes.colorOf(card.modelData.user_id, root.c.light); initialColor: root.c.bg2; fontFamily: ui.sans }
              Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - ui.px(51)
                spacing: ui.px(1)
                Text { textFormat: Text.PlainText; width: parent.width; text: card.modelData.name || card.modelData.user_id; color: root.c.fg; elide: Text.ElideRight; font.family: ui.sans; font.pixelSize: ui.px(13.5); font.weight: Font.DemiBold }
                Text { textFormat: Text.PlainText; width: parent.width; text: card.modelData.user_id; color: root.c.muted; elide: Text.ElideMiddle; font.family: ui.mono; font.pixelSize: ui.px(10.5) }
              }
            }
            Text {
              textFormat: Text.PlainText
              width: parent.width
              height: Math.max(implicitHeight, ui.px(38))
              text: card.modelData.bio && card.modelData.bio !== "" ? card.modelData.bio : "No bio."
              color: card.modelData.bio ? root.c.fg : root.c.muted
              wrapMode: Text.Wrap
              maximumLineCount: 3
              elide: Text.ElideRight
              lineHeight: 1.3
              font.family: ui.sans; font.pixelSize: ui.px(12.5)
            }
            Flow {
              width: parent.width
              spacing: ui.px(6)
              Rectangle {
                visible: !!card.modelData.theme
                width: themeRow.implicitWidth + ui.px(18); height: ui.px(22); radius: height / 2
                color: root.c.chip
                Row {
                  id: themeRow
                  anchors.centerIn: parent
                  spacing: ui.px(6)
                  Rectangle { anchors.verticalCenter: parent.verticalCenter; width: ui.px(8); height: ui.px(8); radius: ui.px(3); color: root.themeColor(card.modelData.theme) }
                  Text { textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter; text: card.modelData.theme || ""; color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.px(10.5) }
                }
              }
              Rectangle {
                width: dmText.implicitWidth + ui.px(18); height: ui.px(22); radius: height / 2
                color: root.c.chip
                Text { id: dmText; anchors.centerIn: parent; text: card.open ? "Open to DMs" : "DMs closed"; color: card.open ? root.c.ok : root.c.muted; font.family: ui.sans; font.pixelSize: ui.px(10.5) }
              }
            }
            Row {
              width: parent.width
              spacing: ui.px(7)
              PillButton {
                c: root.c
                visible: !card.confirming
                width: parent.width - (card.me ? 0 : blockButton.width + parent.spacing)
                label: card.me ? "This is you" : (card.open ? "Message" : "Cannot message")
                primary: card.open && !card.me
                round: true
                enabled: card.open && !card.me
                onClicked: root.messageRequested(card.modelData.user_id)
              }
              PillButton { id: blockButton; c: root.c; visible: !card.me && !card.confirming; label: "Block"; round: true; onClicked: root.confirmBlock = card.modelData.user_id }
              PillButton { c: root.c; visible: card.confirming; label: "Block " + (card.modelData.name || card.modelData.user_id) + "?"; danger: true; round: true; onClicked: root.block(card.modelData.user_id) }
              PillButton { c: root.c; visible: card.confirming; label: "Keep"; round: true; onClicked: root.confirmBlock = "" }
            }
          }
        }
      }
    }
    Text {
      textFormat: Text.PlainText
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: ui.px(8)
      y: ui.px(24)
      visible: root.people.length === 0
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
      lineHeight: 1.3
      text: root.loading ? "Loading…" : (root.errorText !== "" ? root.errorText : (field.text.trim() !== "" ? "No one matches." : "No cards published yet. Yours can be the first — Settings › Community."))
      color: root.errorText !== "" ? root.c.bad : root.c.muted
      font.family: ui.sans; font.pixelSize: ui.f12
    }
  }
}
