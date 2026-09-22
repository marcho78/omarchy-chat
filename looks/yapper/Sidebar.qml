import QtQuick
import QtQuick.Controls
import "../../shared"
import "../../shared/Palettes.js" as Palettes
import "../../shared/Format.js" as Format

// The room list: a find field that also joins, starts chats and hands
// off to the directory or message search; invitations; favourites,
// people and rooms; and the account footer.
Item {
  id: root
  property var c: Palettes.fallback()
  property var tips: null
  property var service: null
  property string currentRoom: ""
  property bool busy: false
  property string errorText: ""
  signal roomChosen(var room)
  signal createRequested()
  signal exploreRequested(string query)
  signal peopleRequested(string query)
  signal searchRequested(string query)
  signal settingsRequested(string section)
  Ui { id: ui }

  readonly property bool hasTextFocus: findInput.activeFocus
  function focusFind() { findInput.forceActiveFocus(); findInput.selectAll() }

  // ---------- find ----------
  readonly property string query: findInput.text.trim()
  readonly property bool joinable: query.charAt(0) === "#" || query.charAt(0) === "!"
  readonly property bool userId: /^@[^:\s]+:[^\s]+$/.test(query)
  readonly property bool userName: query.charAt(0) === "@" && !userId
  readonly property bool hintsOpen: findInput.activeFocus && query !== ""

  // Enter takes the first hint that applies to what was typed.
  function submit() {
    if (query === "" || root.busy) return
    if (root.joinable) { root.join(query); return }
    if (root.userId) { root.chat(query); return }
    if (root.userName) { root.peopleRequested(query.substring(1)); return }
    root.exploreRequested(query)
  }
  function fail(msg) { root.busy = false; root.errorText = msg }
  function join(idOrAlias) {
    root.busy = true; root.errorText = ""
    root.service.join(idOrAlias, function(r) {
      root.busy = false
      if (!r.ok) { root.fail(r.error || "Could not join"); return }
      findInput.text = ""
      root.roomChosen(r.result)
    })
  }
  function chat(userId) {
    root.busy = true; root.errorText = ""
    root.service.dm(userId, function(r) {
      root.busy = false
      if (!r.ok) { root.fail(r.error || "Could not open the chat"); return }
      findInput.text = ""
      root.roomChosen(r.result)
    })
  }

  // ---------- rooms ----------
  readonly property var shown: service ? service.visibleRooms : []
  function matches(r) {
    if (root.query === "" || root.joinable || root.userId || root.userName) return true
    var q = root.query.toLowerCase()
    return String(r.name || "").toLowerCase().indexOf(q) >= 0 || String(r.topic || "").toLowerCase().indexOf(q) >= 0
  }
  readonly property var favourites: shown.filter(function(r) { return r.favourite === true && root.matches(r) })
  readonly property var people: shown.filter(function(r) { return r.direct === true && r.favourite !== true && root.matches(r) })
  readonly property var rooms: shown.filter(function(r) { return r.direct !== true && r.favourite !== true && root.matches(r) })
  readonly property var invites: service ? service.invites : []

  // An accepted invitation opens once the room list carries it.
  property string pendingOpen: ""
  Connections {
    target: root.service
    function onRoomsChanged() {
      if (root.pendingOpen === "") return
      var r = root.service.roomById(root.pendingOpen)
      if (r) { root.pendingOpen = ""; root.roomChosen(r) }
    }
  }
  function accept(inv) {
    root.busy = true; root.errorText = ""
    root.service.acceptInvite(inv.room, function(r) {
      root.busy = false
      if (!r.ok) { root.fail(r.error || "Could not accept"); return }
      root.pendingOpen = inv.room
    })
  }
  function decline(inv) {
    root.errorText = ""
    root.service.declineInvite(inv.room, function(r) { if (!r.ok) root.fail(r.error || "Could not decline") })
  }

  component GroupHeader: Item {
    property string icon: ""
    property string weight: "regular"
    property string label: ""
    property int count: 0
    width: parent.width
    height: ui.px(26)
    Icon {
      id: groupIcon
      anchors.left: parent.left
      anchors.leftMargin: ui.px(8)
      anchors.verticalCenter: parent.verticalCenter
      name: parent.icon; weight: parent.weight
      size: ui.px(11)
      color: root.c.muted
    }
    Text {
      anchors.left: groupIcon.right
      anchors.leftMargin: ui.px(6)
      anchors.verticalCenter: parent.verticalCenter
      text: parent.label
      color: root.c.muted
      font.family: ui.mono
      font.pixelSize: ui.f10
      font.letterSpacing: 1.2
    }
    Text {
      anchors.right: parent.right
      anchors.rightMargin: ui.px(8)
      anchors.verticalCenter: parent.verticalCenter
      text: String(parent.count)
      color: root.c.muted
      font.family: ui.mono
      font.pixelSize: ui.f10
    }
  }
  component Group: Column {
    property string icon: ""
    property string weight: "regular"
    property string label: ""
    property var list: []
    width: parent.width
    visible: list.length > 0
    spacing: ui.px(1)
    bottomPadding: ui.px(10)
    GroupHeader { icon: parent.icon; weight: parent.weight; label: parent.label; count: parent.list.length }
    Repeater {
      model: parent.list
      delegate: RoomRow {
        required property var modelData
        width: parent.width
        c: root.c
        service: root.service
        room: modelData
        active: root.currentRoom === String(modelData.id)
        onChosen: root.roomChosen(modelData)
      }
    }
  }
  component Hint: Item {
    property string icon: ""
    property string key: ""
    property string detail: ""
    signal picked()
    width: parent.width
    height: ui.px(30)
    Rectangle { anchors.fill: parent; radius: ui.px(7); color: hintMouse.containsMouse ? root.c.hover : "transparent" }
    Row {
      anchors.left: parent.left
      anchors.leftMargin: ui.px(8)
      anchors.right: parent.right
      anchors.rightMargin: ui.px(8)
      anchors.verticalCenter: parent.verticalCenter
      spacing: ui.px(9)
      Icon { anchors.verticalCenter: parent.verticalCenter; name: parent.parent.icon; size: ui.px(14); color: root.c.accent }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: parent.parent.key
        color: root.c.fg
        font.family: ui.mono; font.pixelSize: ui.f11
        elide: Text.ElideRight
        width: Math.min(implicitWidth, parent.width * 0.55)
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: parent.parent.detail
        color: root.c.muted
        font.family: ui.sans; font.pixelSize: ui.f11
        elide: Text.ElideRight
        width: parent.width - x
      }
    }
    MouseArea { id: hintMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.picked() }
  }

  Rectangle { anchors.fill: parent; color: root.c.sidebar }
  Rectangle {
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: 1
    color: root.c.line
  }

  // Find row
  Item {
    id: findRow
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: ui.px(12)
    anchors.topMargin: ui.px(11)
    height: ui.px(34)
    Rectangle {
      id: findBox
      anchors.left: parent.left
      anchors.right: newRoom.left
      anchors.rightMargin: ui.px(7)
      height: parent.height
      radius: ui.px(8)
      color: root.c.bg
      border.width: 1
      border.color: findInput.activeFocus ? root.c.accent : root.c.line
      Icon {
        id: findIcon
        anchors.left: parent.left
        anchors.leftMargin: ui.px(10)
        anchors.verticalCenter: parent.verticalCenter
        name: "magnifying-glass"
        size: ui.px(14)
        color: root.c.muted
      }
      TextInput {
        id: findInput
        anchors.left: findIcon.right
        anchors.leftMargin: ui.px(8)
        anchors.right: clearFind.visible ? clearFind.left : parent.right
        anchors.rightMargin: ui.px(8)
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        color: root.c.fg
        selectionColor: root.c.sel
        selectedTextColor: root.c.fg
        font.family: ui.sans
        font.pixelSize: ui.f13
        onTextChanged: root.errorText = ""
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { event.accepted = true; root.submit() }
          else if (event.key === Qt.Key_Escape) { event.accepted = true; if (text !== "") text = ""; else focus = false }
        }
        Text {
          anchors.fill: parent
          visible: findInput.text === "" && !findInput.activeFocus
          text: "Find rooms, #alias, @user"
          color: root.c.muted
          font: findInput.font
          verticalAlignment: Text.AlignVCenter
        }
        Text {
          anchors.fill: parent
          visible: findInput.text === "" && findInput.activeFocus
          text: "Type to find, Enter to go"
          color: root.c.muted
          font: findInput.font
          verticalAlignment: Text.AlignVCenter
        }
      }
      IconButton {
        id: clearFind
        anchors.right: parent.right
        anchors.rightMargin: ui.px(4)
        anchors.verticalCenter: parent.verticalCenter
        visible: findInput.text !== ""
        c: root.c
        icon: "x"
        size: ui.px(24)
        iconSize: ui.px(13)
        radius: ui.px(6)
        onClicked: { findInput.text = ""; findInput.forceActiveFocus() }
      }
    }
    IconButton {
      id: newRoom
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      c: root.c
      tips: root.tips
      icon: "plus"
      size: ui.px(34)
      iconSize: ui.px(16)
      bordered: true
      subtle: false
      fill: root.c.bg
      tooltip: "New room"
      onClicked: root.createRequested()
    }
  }

  // What Enter would do with the text, and the other things it could do.
  Column {
    id: hints
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: findRow.bottom
    anchors.margins: ui.px(12)
    anchors.topMargin: ui.px(4)
    visible: root.hintsOpen
    spacing: ui.px(2)
    Hint { visible: root.joinable; icon: "hash"; key: root.query; detail: "join this room"; onPicked: root.join(root.query) }
    Hint { visible: root.userId; icon: "at"; key: root.query; detail: "open a direct chat"; onPicked: root.chat(root.query) }
    Hint { visible: root.userName; icon: "users"; key: root.query; detail: "find people"; onPicked: root.peopleRequested(root.query.substring(1)) }
    Hint { visible: !root.joinable && !root.userId && !root.userName; icon: "globe-hemisphere-west"; key: root.query; detail: "search the public directory"; onPicked: root.exploreRequested(root.query) }
    Hint { visible: !root.joinable && !root.userId && !root.userName; icon: "magnifying-glass"; key: root.query; detail: "search what people said"; onPicked: root.searchRequested(root.query) }
  }
  Text {
    id: errorLine
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: hints.visible ? hints.bottom : findRow.bottom
    anchors.margins: ui.px(12)
    anchors.topMargin: ui.px(6)
    visible: root.errorText !== "" || root.busy
    text: root.busy ? "Working…" : root.errorText
    color: root.busy ? root.c.muted : root.c.bad
    wrapMode: Text.WordWrap
    font.family: ui.sans
    font.pixelSize: ui.f11
  }

  // The list
  Flickable {
    id: listFlick
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: errorLine.visible ? errorLine.bottom : (hints.visible ? hints.bottom : findRow.bottom)
    anchors.topMargin: ui.px(6)
    anchors.bottom: footer.top
    anchors.leftMargin: ui.px(8)
    anchors.rightMargin: ui.px(8)
    contentHeight: listColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    Column {
      id: listColumn
      width: parent.width
      spacing: 0

      // Invitations
      Repeater {
        model: root.invites
        delegate: Rectangle {
          id: inviteCard
          required property var modelData
          width: parent.width - ui.px(8)
          anchors.horizontalCenter: parent.horizontalCenter
          height: inviteColumn.implicitHeight + ui.px(22)
          radius: ui.px(8)
          color: root.c.sel
          border.width: 1
          border.color: root.c.accent
          Column {
            id: inviteColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: ui.px(12)
            anchors.topMargin: ui.px(11)
            spacing: ui.px(2)
            Row {
              spacing: ui.px(7)
              Icon { anchors.verticalCenter: parent.verticalCenter; name: "envelope-simple"; weight: "fill"; size: ui.px(13); color: root.c.accent }
              Text { text: "Invitation"; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.f12; font.weight: Font.DemiBold }
            }
            Text {
              width: parent.width
              topPadding: ui.px(3)
              text: inviteCard.modelData.name
              color: root.c.fg; elide: Text.ElideRight
              font.family: ui.sans; font.pixelSize: ui.f13; font.weight: Font.Medium
            }
            Text {
              width: parent.width
              text: "from " + (inviteCard.modelData.inviter_name || inviteCard.modelData.inviter || "someone") + (inviteCard.modelData.direct ? " · direct chat" : "")
              color: root.c.muted; elide: Text.ElideRight
              font.family: ui.sans; font.pixelSize: ui.f11
            }
            Row {
              width: parent.width
              topPadding: ui.px(8)
              spacing: ui.px(6)
              Rectangle {
                width: (parent.width - parent.spacing) / 2
                height: ui.px(30)
                radius: ui.px(7)
                color: acceptMouse.containsMouse ? Qt.lighter(root.c.accent, 1.12) : root.c.accent
                Text { anchors.centerIn: parent; text: "Accept"; color: root.c.bg2; font.family: ui.sans; font.pixelSize: ui.f12; font.weight: Font.DemiBold }
                MouseArea { id: acceptMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: !root.busy; onClicked: root.accept(inviteCard.modelData) }
              }
              Rectangle {
                width: (parent.width - parent.spacing) / 2
                height: ui.px(30)
                radius: ui.px(7)
                color: declineMouse.containsMouse ? root.c.hover : "transparent"
                border.width: 1
                border.color: root.c.line
                Text { anchors.centerIn: parent; text: "Decline"; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.f12 }
                MouseArea { id: declineMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: !root.busy; onClicked: root.decline(inviteCard.modelData) }
              }
            }
          }
        }
      }
      Item { width: parent.width; height: root.invites.length > 0 ? ui.px(10) : 0 }

      Group { icon: "star"; weight: "fill"; label: "FAVOURITES"; list: root.favourites }
      Group { icon: "user"; label: "PEOPLE"; list: root.people }
      Group { icon: "hash"; label: "ROOMS"; list: root.rooms }

      Text {
        width: parent.width
        visible: root.favourites.length + root.people.length + root.rooms.length === 0
        topPadding: ui.px(18)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: root.query !== "" && !root.joinable && !root.userId && !root.userName ? "None of your rooms match. Enter searches the public directory."
          : root.shown.length === 0 && root.service && root.service.currentSpace !== "" ? "This space has no rooms you have joined."
          : "No rooms yet. Find one above, or press + to start your own."
        color: root.c.muted
        font.family: ui.sans
        font.pixelSize: ui.f12
        lineHeight: 1.35
      }
    }
  }

  // Account footer
  Item {
    id: footer
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: ui.px(50)
    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 1; color: root.c.line }
    readonly property string userId: root.service ? root.service.userId : ""
    readonly property bool online: root.service && root.service.status ? root.service.status.syncing === true : false
    readonly property bool daemonUpdate: root.service ? root.service.daemonUpdateAvailable : false
    readonly property bool pluginUpdate: root.service ? root.service.pluginUpdateAvailable : false
    Avatar {
      id: me
      anchors.left: parent.left
      anchors.leftMargin: ui.px(10)
      anchors.verticalCenter: parent.verticalCenter
      service: root.service
      userId: footer.userId
      name: footer.userId
      size: ui.px(30)
      fallbackColor: root.c.accent
      initialColor: root.c.bg2
      fontFamily: ui.sans
      Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: -1
        anchors.bottomMargin: -1
        width: ui.px(10); height: ui.px(10); radius: width / 2
        color: footer.online ? root.c.ok : root.c.warn
        border.width: 2
        border.color: root.c.sidebar
      }
    }
    Column {
      anchors.left: me.right
      anchors.leftMargin: ui.px(9)
      anchors.right: settingsButton.left
      anchors.rightMargin: ui.px(6)
      anchors.verticalCenter: parent.verticalCenter
      spacing: ui.px(1)
      Text {
        width: parent.width
        text: footer.userId
        color: root.c.fg
        elide: Text.ElideRight
        font.family: ui.sans; font.pixelSize: ui.f12; font.weight: Font.Medium
      }
      Item {
        width: parent.width
        height: ui.px(14)
        Row {
          anchors.verticalCenter: parent.verticalCenter
          spacing: ui.px(5)
          Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: footer.daemonUpdate || footer.pluginUpdate
            name: "arrow-circle-up"; weight: "fill"
            size: ui.px(11)
            color: root.c.warn
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: footer.daemonUpdate ? "daemon " + root.service.daemonVersion + " → " + root.service.daemonLatest
              : footer.pluginUpdate ? "plugin update available"
              : "v" + (root.service ? root.service.pluginVersion : "") + " · daemon " + (root.service && root.service.daemonVersion ? root.service.daemonVersion : "—")
            color: footer.daemonUpdate || footer.pluginUpdate ? root.c.warn : root.c.muted
            font.family: ui.mono; font.pixelSize: ui.f10
          }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.settingsRequested("about") }
      }
    }
    IconButton {
      id: settingsButton
      anchors.right: parent.right
      anchors.rightMargin: ui.px(10)
      anchors.verticalCenter: parent.verticalCenter
      c: root.c
      tips: root.tips
      icon: "gear-six"
      size: ui.px(30)
      iconSize: ui.px(16)
      radius: ui.px(7)
      tooltip: "Settings"
      onClicked: root.settingsRequested("")
    }
  }
}
