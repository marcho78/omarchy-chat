import QtQuick
import qs.Commons
import qs.Ui
import "Format.js" as Format

// Members of the Omarchy community who chose to be listed: their card,
// a Message button when they welcome DMs, and Block.
Rectangle {
  id: root
  property var service: null
  property color fg: Color.foreground
  property string fontFamily: Style.font.family
  property bool compact: false

  signal closeRequested()
  signal messageRequested(string userId)

  readonly property color accent: service ? service.accent : Color.accent
  readonly property color hover: service ? service.hover : Util.alpha(fg, 0.05)
  property var people: []
  property bool loading: false
  property string errorText: ""
  property string confirmBlock: ""     // user id awaiting confirmation

  color: "transparent"

  function reset() { searchField.text = ""; root.confirmBlock = ""; root.load() }
  function focusField() { searchField.forceActiveFocus() }
  function load() {
    if (!root.service) return
    root.loading = true; root.errorText = ""
    root.service.people(searchField.text, function(r) {
      root.loading = false
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

  Column {
    anchors.fill: parent
    spacing: Style.space(10)

    Item {
      width: parent.width
      implicitHeight: Math.max(peopleTitle.implicitHeight, peopleClose.implicitHeight, Style.space(28))
      Column {
        id: peopleTitle
        anchors.left: parent.left
        anchors.right: peopleClose.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)
        Text { text: "󰀏  People"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
        Text {
          width: parent.width
          text: root.loading ? "Loading…" : root.people.length + (root.people.length === 1 ? " Omarchy user listed" : " Omarchy users listed") + "  ·  only people who chose to be"
          color: root.fg; opacity: 0.6
          font.family: root.fontFamily; font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
      Button { id: peopleClose; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; iconText: "󰅖"; text: ""; onClicked: root.closeRequested() }
    }

    TextField {
      id: searchField
      width: parent.width
      maximumLength: 128
      placeholderText: "Search by name, bio or theme"
      onTextChanged: searchDebounce.restart()
      Keys.onEscapePressed: root.closeRequested()
    }
    Timer { id: searchDebounce; interval: 250; onTriggered: root.load() }

    Text {
      width: parent.width
      visible: root.errorText !== ""
      wrapMode: Text.WordWrap
      text: root.errorText
      color: Color.urgent
      font.family: root.fontFamily; font.pixelSize: Style.font.caption
    }

    Text {
      width: parent.width
      visible: !root.loading && root.people.length === 0 && root.errorText === ""
      wrapMode: Text.WordWrap
      text: searchField.text !== "" ? "Nobody matches that." : "Nobody is listed yet. Publish your own card in Settings → Community to be the first."
      color: root.fg; opacity: 0.6
      font.family: root.fontFamily; font.pixelSize: Style.font.body
    }

    ListView {
      id: list
      width: parent.width
      height: parent.height - y
      clip: true
      spacing: Style.space(8)
      model: root.people
      boundsBehavior: Flickable.StopAtBounds
      delegate: Rectangle {
        id: card
        required property var modelData
        width: list.width
        implicitHeight: cardCol.implicitHeight + Style.space(20)
        radius: Style.space(10)
        color: cardMouse.containsMouse ? root.hover : Util.alpha(root.fg, 0.04)
        border.width: 1
        border.color: Util.alpha(root.fg, 0.15)
        MouseArea { id: cardMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }

        Row {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Style.space(10)
          spacing: Style.space(12)
          Avatar {
            userId: card.modelData.user_id
            name: card.modelData.name
            mxc: card.modelData.avatar || ""
            service: root.service
            size: Style.space(44)
            fontFamily: root.fontFamily
          }
          Column {
            id: cardCol
            width: parent.width - Style.space(44) - parent.spacing
            spacing: Style.space(4)
            Row {
              width: parent.width
              spacing: Style.space(8)
              Text {
                text: card.modelData.name
                color: root.fg
                font.family: root.fontFamily; font.pixelSize: Style.font.subtitle; font.bold: true
                elide: Text.ElideRight
              }
              Text {
                anchors.baseline: parent.children[0].baseline
                text: card.modelData.user_id
                color: root.fg; opacity: 0.5
                font.family: root.fontFamily; font.pixelSize: Style.font.caption
                elide: Text.ElideMiddle
              }
            }
            Text {
              width: parent.width
              visible: !!card.modelData.bio
              wrapMode: Text.WordWrap
              text: card.modelData.bio || ""
              color: root.fg; opacity: 0.85
              font.family: root.fontFamily; font.pixelSize: Style.font.body
            }
            Flow {
              width: parent.width
              spacing: Style.space(6)
              Rectangle {
                visible: !!card.modelData.theme
                width: themeText.implicitWidth + Style.space(12)
                height: Style.space(20)
                radius: Style.space(5)
                color: Util.alpha(root.accent, 0.15)
                Text { id: themeText; anchors.centerIn: parent; text: "󰏘 " + (card.modelData.theme || ""); color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1 }
              }
              Rectangle {
                width: dmText.implicitWidth + Style.space(12)
                height: Style.space(20)
                radius: Style.space(5)
                color: Util.alpha(root.fg, 0.08)
                Text { id: dmText; anchors.centerIn: parent; text: card.modelData.open_to_dm ? "󰭹 Open to messages" : "󰭼 Not taking messages"; color: root.fg; opacity: 0.7; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1 }
              }
              Rectangle {
                visible: !!card.modelData.updated
                width: listedText.implicitWidth + Style.space(4)
                height: Style.space(20)
                color: "transparent"
                Text { id: listedText; anchors.centerIn: parent; text: card.modelData.updated ? "listed " + Format.timeOf(Number(card.modelData.updated)) : ""; color: root.fg; opacity: 0.45; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1 }
              }
            }
            Row {
              spacing: Style.spacing.controlGap
              visible: root.service && card.modelData.user_id !== root.service.userId
              Button {
                text: "Message"
                iconText: "󰭹"
                bordered: true
                visible: card.modelData.open_to_dm === true && root.confirmBlock !== card.modelData.user_id
                onClicked: root.messageRequested(card.modelData.user_id)
              }
              Button {
                text: root.confirmBlock === card.modelData.user_id ? "Block " + card.modelData.name + "?" : "Block"
                iconText: "󰂭"
                bordered: root.confirmBlock === card.modelData.user_id
                onClicked: { if (root.confirmBlock === card.modelData.user_id) root.block(card.modelData.user_id); else root.confirmBlock = card.modelData.user_id }
              }
              Button { visible: root.confirmBlock === card.modelData.user_id; text: "Keep"; onClicked: root.confirmBlock = "" }
            }
          }
        }
      }
    }
  }
}
