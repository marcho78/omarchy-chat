import QtQuick
import QtQuick.Controls
import "../../shared"
import "../../shared/Palettes.js" as Palettes
import "../../shared/Format.js" as Format

// The bar popup's body in the Yapper look: a strip with the place you
// are, the room list with its find field and cards, or one room (or a
// thread) with the composer. Anything bigger opens the window. The root
// Panel.qml owns the bar button, the popup frame and IPC.
Item {
  id: root
  width: parent ? parent.width : ui.px(420)
  implicitHeight: ui.px(580)
  Ui { id: ui }

  // Set by the host popup.
  property var service: null
  property var bar: null
  property bool opened: false
  signal closeRequested()

  readonly property var c: service && service.colors ? service.colors : Palettes.fallback()
  readonly property bool loggedIn: service ? service.loggedIn : false
  readonly property string stateText: service ? service.stateText : "Starting…"
  readonly property bool inRoom: roomView.roomId !== ""
  readonly property bool inThread: threadView.roomId !== ""
  readonly property bool hasTextFocus: roomView.hasTextFocus || threadView.hasTextFocus || sidebar.hasTextFocus
  property bool updateDismissed: false
  property bool communityDismissed: false

  function openRoom(r) { roomView.open(r) }
  function backToList() { threadView.close(); roomView.close() }
  function openThread(eventId) { if (roomView.room) { threadView.openThread(roomView.room, eventId); Qt.callLater(function() { threadView.focusComposer() }) } }
  function closeThread() { threadView.close(); roomView.focusComposer() }
  // Esc / close request: step back one level; false means "nothing to step back from".
  function handleClose() {
    if (root.inThread) root.closeThread()
    else if (root.inRoom) root.backToList()
    else return false
    return true
  }
  function focusDefault() {
    if (root.inThread) threadView.focusComposer()
    else if (root.inRoom) roomView.focusComposer()
    else if (root.loggedIn) sidebar.focusFind()
  }
  function clearSecrets() { }
  onOpenedChanged: {
    if (opened) Qt.callLater(root.focusDefault)
    else root.backToList()
  }

  Rectangle { anchors.fill: parent; color: root.c.bg }

  // Strip: where you are
  Rectangle {
    id: strip
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: ui.px(46)
    color: root.c.bg2
    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: root.c.line }
    IconButton {
      id: backButton
      anchors.left: parent.left
      anchors.leftMargin: ui.px(8)
      anchors.verticalCenter: parent.verticalCenter
      visible: root.inRoom
      c: root.c
      icon: "caret-left"
      size: ui.px(30); iconSize: ui.px(15); radius: ui.px(7)
      onClicked: root.inThread ? root.closeThread() : root.backToList()
    }
    Avatar {
      id: stripAvatar
      anchors.left: backButton.visible ? backButton.right : parent.left
      anchors.leftMargin: backButton.visible ? ui.px(4) : ui.px(12)
      anchors.verticalCenter: parent.verticalCenter
      service: root.service
      mxc: root.inRoom && roomView.room && roomView.room.avatar ? roomView.room.avatar : ""
      name: root.inRoom ? roomView.roomName : "Yapper"
      userId: root.inRoom ? roomView.roomId : "yapper"
      size: ui.px(24)
      radius: root.inRoom && roomView.room && roomView.room.direct ? size / 2 : ui.px(7)
      fallbackColor: root.inRoom ? (roomView.room && roomView.room.direct ? Palettes.colorOf(roomView.roomId, root.c.light) : root.c.surface) : "#22b8a8"
      initialColor: root.inRoom ? (roomView.room && roomView.room.direct ? root.c.bg2 : root.c.fg) : "#062b28"
      fontFamily: ui.sans
    }
    Column {
      anchors.left: stripAvatar.right
      anchors.leftMargin: ui.px(9)
      anchors.right: stripButtons.left
      anchors.rightMargin: ui.px(6)
      anchors.verticalCenter: parent.verticalCenter
      spacing: ui.px(1)
      Text {
        textFormat: Text.PlainText
        width: parent.width
        elide: Text.ElideRight
        text: root.inThread ? "Thread" : root.inRoom ? roomView.roomName : "Yapper"
        color: root.c.fg
        font.family: ui.sans; font.pixelSize: ui.f13; font.weight: Font.DemiBold
      }
      Text {
        textFormat: Text.PlainText
        width: parent.width
        elide: Text.ElideRight
        text: root.inThread ? "in " + roomView.roomName
          : root.inRoom && roomView.room && roomView.room.bridge ? "via " + roomView.room.bridge.name + (roomView.encrypted ? " · encrypted to the bridge" : " · not encrypted")
          : root.inRoom ? (roomView.encrypted ? "End-to-end encrypted" : "Not encrypted")
          : root.loggedIn ? (root.service ? root.service.userId : "") : root.stateText
        color: root.inRoom && !roomView.encrypted ? root.c.warn : root.c.muted
        font.family: ui.sans; font.pixelSize: ui.px(10.5)
      }
    }
    Row {
      id: stripButtons
      anchors.right: parent.right
      anchors.rightMargin: ui.px(8)
      anchors.verticalCenter: parent.verticalCenter
      spacing: ui.px(2)
      IconButton { visible: root.inRoom && !root.inThread; c: root.c; icon: "info"; size: ui.px(30); iconSize: ui.px(15); radius: ui.px(7); tooltip: "Room info"; onClicked: { root.service.openWindow({ room: roomView.roomId, info: true }); root.closeRequested() } }
      IconButton { c: root.c; icon: "gear-six"; size: ui.px(30); iconSize: ui.px(15); radius: ui.px(7); tooltip: "Settings"; onClicked: { root.service.openWindow({ settings: true }); root.closeRequested() } }
      IconButton { c: root.c; icon: "arrows-out-simple"; size: ui.px(30); iconSize: ui.px(15); radius: ui.px(7); subtle: false; tooltip: "Open the window"; onClicked: { root.service.openWindow(root.inRoom ? { room: roomView.roomId } : null); root.closeRequested() } }
    }
  }

  // Not signed in: the window has the sign-in flow.
  Column {
    anchors.centerIn: body
    width: body.width - ui.px(52)
    visible: !root.loggedIn
    spacing: ui.px(14)
    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      width: ui.px(46); height: ui.px(46); radius: ui.px(13)
      color: root.c.chip
      Icon { anchors.centerIn: parent; name: root.service && root.service.connected ? "plugs" : "plugs-connected"; size: ui.px(24); color: root.c.muted }
    }
    Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.service && !root.service.installed && root.service.checked ? "Daemon not installed" : root.service && !root.service.connected ? "Daemon not running" : "Not signed in"; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.f15; font.weight: Font.DemiBold }
    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
      lineHeight: 1.3
      text: root.service && !root.service.installed && root.service.checked ? "Yapper is QML only; the part that touches keys and the network is a small daemon you build from source. The window shows the command."
        : root.service && !root.service.connected ? "Start it once and Yapper keeps it running from here on."
        : "Yapper has a daemon but no session yet. Sign in once and it stays signed in."
      color: root.c.muted
      font.family: ui.sans; font.pixelSize: ui.px(12.5)
    }
    PillButton { c: root.c; anchors.horizontalCenter: parent.horizontalCenter; label: root.service && root.service.connected ? "Sign in" : "Open Yapper"; primary: true; round: true; onClicked: { root.service.openWindow(); root.closeRequested() } }
  }

  Item {
    id: body
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: strip.bottom
    anchors.bottom: parent.bottom

    // Rooms
    Item {
      anchors.fill: parent
      visible: root.loggedIn && !root.inRoom
      Sidebar {
        id: sidebar
        anchors.fill: parent
        c: root.c
        service: root.service
        compact: true
        currentRoom: ""
        onRoomChosen: function(r) { root.openRoom(r); Qt.callLater(function() { roomView.focusComposer() }) }
        onCreateRequested: { root.service.openWindow({ create: true }); root.closeRequested() }
        onExploreRequested: function(q) { root.service.openWindow({ explore: true, query: q }); root.closeRequested() }
        onPeopleRequested: function(q) { root.service.openWindow({ people: true }); root.closeRequested() }
        onSearchRequested: function(q) { root.service.openWindow({ search: q }); root.closeRequested() }
        onSettingsRequested: function(section) { root.service.openWindow({ settings: section || true }); root.closeRequested() }
        // Cards above the list
        cards: Column {
          width: parent ? parent.width : 0
          spacing: ui.px(9)
          // An update
          Rectangle {
            width: parent.width
            visible: root.service && root.service.updateAvailable && !root.updateDismissed
            height: visible ? updateColumn.implicitHeight + ui.px(24) : 0
            radius: ui.px(9)
            color: root.c.chip
            border.width: 1
            border.color: root.c.warn
            Column {
              id: updateColumn
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: ui.px(12)
              spacing: ui.px(5)
              Row {
                width: parent.width
                spacing: ui.px(8)
                Icon { anchors.verticalCenter: parent.verticalCenter; name: "arrow-circle-up"; weight: "fill"; size: ui.px(15); color: root.c.warn }
                Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - ui.px(52); elide: Text.ElideRight; text: root.service && root.service.daemonUpdateAvailable ? "Daemon " + root.service.daemonLatest + " available" : "Plugin update available"; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.px(12.5); font.weight: Font.DemiBold }
                IconButton { anchors.verticalCenter: parent.verticalCenter; c: root.c; icon: "x"; size: ui.px(22); iconSize: ui.px(13); radius: ui.px(6); onClicked: root.updateDismissed = true }
              }
              Text { width: parent.width; wrapMode: Text.Wrap; lineHeight: 1.3; text: root.service && root.service.daemonUpdateAvailable ? "You have " + root.service.daemonVersion + ". Installs through pacman in a terminal; your session stays signed in." : (root.service ? root.service.pluginUpdateCount + " new change" + (root.service.pluginUpdateCount === 1 ? "" : "s") + ". Shows the diff in a terminal, then restarts the shell." : ""); color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.f11 }
              Row {
                topPadding: ui.px(5)
                spacing: ui.px(6)
                PillButton { c: root.c; label: "Update"; warn: true; round: true; onClicked: { if (root.service.daemonUpdateAvailable) root.service.openWindow({ install: "update" }); else root.service.updatePlugin(); root.closeRequested() } }
                PillButton { c: root.c; label: "Later"; round: true; onClicked: root.updateDismissed = true }
              }
            }
          }
          // The community, asked once
          Rectangle {
            width: parent.width
            visible: root.service && root.service.communityPrompt && !root.service.communityJoined && root.service.community && root.service.community.exists && !root.communityDismissed
            height: visible ? communityColumn.implicitHeight + ui.px(24) : 0
            radius: ui.px(9)
            color: root.c.sel
            border.width: 1
            border.color: root.c.accent
            Column {
              id: communityColumn
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: ui.px(12)
              spacing: ui.px(5)
              Row {
                spacing: ui.px(8)
                Icon { anchors.verticalCenter: parent.verticalCenter; name: "users-three"; weight: "fill"; size: ui.px(15); color: root.c.accent }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Join the Omarchy community?"; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.px(12.5); font.weight: Font.DemiBold }
              }
              Text { textFormat: Text.PlainText; width: parent.width; wrapMode: Text.Wrap; lineHeight: 1.3; text: (root.service && root.service.community ? root.service.community.rooms.map(function(r) { return r.name }).join(", ") + " — " + root.service.community.rooms.length + " rooms under one space." : "") + " Asked once."; color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.f11 }
              Row {
                topPadding: ui.px(5)
                spacing: ui.px(6)
                PillButton { c: root.c; label: "Have a look"; primary: true; round: true; onClicked: { root.service.openWindow({ join: true }); root.closeRequested() } }
                PillButton { c: root.c; label: "Not now"; round: true; onClicked: { root.communityDismissed = true; root.service.set("communityPrompt", false) } }
              }
            }
          }
        }
      }
    }

    // One room, or a thread in its place
    RoomView {
      id: roomView
      anchors.fill: parent
      visible: root.loggedIn && root.inRoom && !root.inThread && root.opened
      c: root.c
      service: root.service
      viewId: "popup"
      onRoomLeft: root.backToList()
      onThreadRequested: function(id) { root.openThread(id) }
    }
    RoomView {
      id: threadView
      anchors.fill: parent
      visible: root.loggedIn && root.inThread && root.opened
      c: root.c
      service: root.service
      viewId: "popup-thread"
      onCloseRequested: root.closeThread()
    }
  }
}
