import QtQuick
import Quickshell
import qs.Commons
import "../../shared"
import "../../shared/Palettes.js" as Palettes
import "../../shared/Format.js" as Format
import "../omarchy" as Omarchy

// Yapper as an app window, in the designed look: a title strip, the rail,
// the room list and the conversation, drawn from the chosen palette.
// Same Service.qml as the bar popup, so both stay in step.
//
//   omarchy-shell shell summon marcho78.yapper '{}'   # open
//   omarchy-shell shell toggle marcho78.yapper '{}'   # toggle
//   omarchy-shell shell hide marcho78.yapper          # close
//
// The payload may carry { room, thread, settings, pick, info, search, people, space }.
Item {
  id: root
  property var shell: null
  property var service: null
  property bool closingFromHost: false

  readonly property bool loggedIn: service ? service.loggedIn : false
  readonly property var c: service && service.colors ? service.colors : Palettes.fallback()
  readonly property bool opened: window.visible
  // chat | people | explore | search | settings
  property string view: "chat"
  property var room: null
  readonly property string roomId: room ? String(room.id) : ""
  readonly property bool inRoom: roomId !== ""
  Ui { id: ui }

  readonly property string titleHint: !loggedIn ? "not signed in"
    : view !== "chat" ? view
    : room ? (room.topic ? Format.oneLine(room.topic) : (room.direct ? "direct chat" : "")) : ""

  // ---- plugin lifecycle ----------------------------------------------------

  function open(payloadJson) {
    closingFromHost = false
    window.visible = true
    if (service) { service.ensureDaemon(); if (service.loggedIn) service.refresh() }
    var wanted = ""
    if (payloadJson) {
      try {
        var p = JSON.parse(String(payloadJson))
        if (p && typeof p.room === "string") { wanted = p.room; root.view = "chat" }
        if (p && (p.settings === true || typeof p.pick === "string")) root.view = "settings"
        if (p && typeof p.search === "string") root.view = "search"
        if (p && p.people === true) root.view = "people"
        if (p && typeof p.space === "string" && service) service.currentSpace = p.space
      } catch (e) { /* ignore */ }
    }
    Qt.callLater(function() {
      if (wanted !== "" && service) {
        var r = service.roomById(wanted)
        if (r) root.openRoom(r)
      }
      if (root.loggedIn && !root.inRoom && root.view === "chat") sidebar.focusFind()
      else if (!root.loggedIn) gate.focusFirst()
    })
  }

  // Host-initiated close (`shell hide`).
  function close() {
    closingFromHost = true
    window.visible = false
    closingFromHost = false
  }

  // User-initiated close (window close button): keep the shell's open map right.
  function requestClose() {
    if (shell && typeof shell.hide === "function") shell.hide("marcho78.yapper")
    else window.visible = false
  }

  function openRoom(r) { root.room = r; root.view = "chat" }
  function show(view) { root.view = view }

  FloatingWindow {
    id: window
    title: root.inRoom ? root.room.name + " – Yapper" : "Yapper"
    color: root.c.bg
    implicitWidth: ui.px(1200)
    implicitHeight: ui.px(772)
    minimumSize: Qt.size(ui.px(900), ui.px(560))

    onVisibleChanged: {
      if (!visible && !root.closingFromHost && root.shell && typeof root.shell.hide === "function")
        root.shell.hide("marcho78.yapper")
      if (!visible) gate.clearSecrets()
    }

    Shortcut { sequences: ["/", "Ctrl+K"]; onActivated: if (root.loggedIn) sidebar.focusFind() }

    // Title strip
    Rectangle {
      id: titleStrip
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: ui.titleHeight
      color: root.c.bg2
      Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: root.c.line }
      Row {
        anchors.left: parent.left
        anchors.leftMargin: ui.px(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: ui.px(8)
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: ui.px(11); height: ui.px(11); radius: ui.px(4); color: "#22b8a8" }
        Text { anchors.verticalCenter: parent.verticalCenter; text: "Yapper"; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.f11; font.weight: Font.Medium }
      }
      Text {
        anchors.right: parent.right
        anchors.rightMargin: ui.px(12)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, parent.width * 0.6)
        elide: Text.ElideRight
        text: root.titleHint
        color: root.c.muted
        font.family: ui.mono
        font.pixelSize: ui.f10
      }
    }

    // Signed out: the gate, centred.
    Item {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: titleStrip.bottom
      anchors.bottom: parent.bottom
      visible: !root.loggedIn
      Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - ui.px(48), ui.px(520))
        height: gateColumn.implicitHeight + ui.px(48)
        radius: ui.px(12)
        color: root.c.bg2
        border.width: 1
        border.color: root.c.line
        Column {
          id: gateColumn
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: ui.px(24)
          spacing: ui.px(16)
          Row {
            spacing: ui.px(12)
            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: ui.px(36); height: ui.px(36); radius: ui.px(10)
              color: "#22b8a8"
              Icon { anchors.centerIn: parent; name: "lock-simple"; weight: "fill"; size: ui.px(18); color: "#062b28" }
            }
            Column {
              anchors.verticalCenter: parent.verticalCenter
              spacing: ui.px(2)
              Text { text: "Yapper"; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.f15; font.weight: Font.DemiBold }
              Text { text: root.service ? root.service.stateText : ""; color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.f12 }
            }
          }
          Omarchy.SessionGate {
            id: gate
            width: parent.width
            service: root.service
            fg: root.c.fg
            fontFamily: ui.sans
          }
        }
      }
    }

    // Signed in: rail, sidebar, conversation
    Item {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: titleStrip.bottom
      anchors.bottom: parent.bottom
      visible: root.loggedIn

      Rail {
        id: rail
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        c: root.c
        tips: tips
        service: root.service
        view: root.view
        onViewRequested: function(v) { root.view = v }
        onSpaceRequested: function(id) { if (root.service) root.service.currentSpace = id }
        onVerifyRequested: root.view = "settings"
      }

      Sidebar {
        id: sidebar
        anchors.left: rail.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: ui.sidebarWidth
        c: root.c
        tips: tips
        service: root.service
        currentRoom: root.view === "chat" ? root.roomId : ""
        onRoomChosen: function(r) { root.openRoom(r) }
        onCreateRequested: root.view = "explore"
        onExploreRequested: function(q) { root.view = "explore" }
        onPeopleRequested: function(q) { root.view = "people" }
        onSearchRequested: function(q) { root.view = "search" }
        onSettingsRequested: function(section) { root.view = "settings" }
      }

      // Conversation column
      Item {
        id: main
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        // Room header
        Item {
          id: roomHeader
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          height: ui.headerHeight
          visible: root.view === "chat" && root.inRoom
          Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: root.c.line }
          Avatar {
            id: headerAvatar
            anchors.left: parent.left
            anchors.leftMargin: ui.px(14)
            anchors.verticalCenter: parent.verticalCenter
            service: root.service
            mxc: root.room && root.room.avatar ? root.room.avatar : ""
            name: root.room ? root.room.name : ""
            userId: root.roomId
            size: ui.px(32)
            radius: root.room && root.room.direct ? size / 2 : ui.px(9)
            fallbackColor: root.room && root.room.direct ? Palettes.colorOf(root.roomId, root.c.light) : root.c.surface
            initialColor: root.room && root.room.direct ? root.c.bg2 : root.c.fg
            fontFamily: ui.sans
          }
          Column {
            anchors.left: headerAvatar.right
            anchors.leftMargin: ui.px(11)
            anchors.right: headerButtons.left
            anchors.rightMargin: ui.px(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: ui.px(1)
            Row {
              width: parent.width
              spacing: ui.px(6)
              Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.room ? root.room.encrypted === true : false
                name: "lock-simple"; weight: "fill"; size: ui.px(11); color: root.c.ok
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width - ui.px(40))
                elide: Text.ElideRight
                text: root.room ? root.room.name : ""
                color: root.c.fg
                font.family: ui.sans; font.pixelSize: ui.f14; font.weight: Font.DemiBold
              }
              Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.room ? root.room.favourite === true : false
                name: "star"; weight: "fill"; size: ui.px(11); color: root.c.warn
              }
            }
            Text {
              width: parent.width
              elide: Text.ElideRight
              text: root.room && root.room.topic ? Format.oneLine(root.room.topic) : (root.room && root.room.encrypted ? "End-to-end encrypted" : "Not encrypted")
              color: root.c.muted
              font.family: ui.sans; font.pixelSize: ui.f11
            }
          }
          Row {
            id: headerButtons
            anchors.right: parent.right
            anchors.rightMargin: ui.px(14)
            anchors.verticalCenter: parent.verticalCenter
            spacing: ui.px(2)
            IconButton { c: root.c; tips: tips; icon: "magnifying-glass"; size: ui.px(32); iconSize: ui.px(16); tooltip: "Search this room"; onClicked: root.view = "search" }
            IconButton { c: root.c; tips: tips; icon: "users"; size: ui.px(32); iconSize: ui.px(16); tooltip: "Members" }
            IconButton { c: root.c; tips: tips; icon: "info"; size: ui.px(32); iconSize: ui.px(16); tooltip: "Room info" }
          }
        }

        // Where the conversation goes (the next step).
        Text {
          anchors.centerIn: parent
          visible: root.view === "chat" && root.inRoom
          text: "The conversation view is the next step of the new look."
          color: root.c.muted
          font.family: ui.sans; font.pixelSize: ui.f12
        }

        // Nothing picked yet
        Column {
          anchors.centerIn: parent
          visible: root.view === "chat" && !root.inRoom
          spacing: ui.px(10)
          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: ui.px(56); height: ui.px(56); radius: ui.px(16)
            color: root.c.chip
            Icon { anchors.centerIn: parent; name: "chats-circle"; size: ui.px(28); color: root.c.accent }
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Pick a room"
            color: root.c.fg
            font.family: ui.sans; font.pixelSize: ui.f15; font.weight: Font.DemiBold
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Choose one on the left, or press  /  to find one."
            color: root.c.muted
            font.family: ui.sans; font.pixelSize: ui.f12
          }
        }

        // The other views, arriving in later steps
        Item {
          anchors.fill: parent
          visible: root.view !== "chat"
          Item {
            id: viewHeader
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: ui.headerHeight
            Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: root.c.line }
            Row {
              anchors.left: parent.left
              anchors.leftMargin: ui.px(14)
              anchors.verticalCenter: parent.verticalCenter
              spacing: ui.px(10)
              Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.view === "people" ? "users-three" : root.view === "explore" ? "compass" : root.view === "search" ? "magnifying-glass" : "gear-six"
                size: ui.px(18)
                color: root.c.accent
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.view === "people" ? "Omarchy community" : root.view === "explore" ? "Explore public rooms" : root.view === "search" ? "Search messages" : "Settings"
                color: root.c.fg
                font.family: ui.sans; font.pixelSize: ui.f14; font.weight: Font.DemiBold
              }
            }
            IconButton {
              anchors.right: parent.right
              anchors.rightMargin: ui.px(14)
              anchors.verticalCenter: parent.verticalCenter
              c: root.c; tips: tips
              icon: "x"; size: ui.px(32); iconSize: ui.px(16)
              tooltip: "Back to chat"
              onClicked: root.view = "chat"
            }
          }
          Text {
            anchors.centerIn: parent
            text: "This view is built in a later step of the new look."
            color: root.c.muted
            font.family: ui.sans; font.pixelSize: ui.f12
          }
        }
      }
    }

    Tips { id: tips; anchors.fill: parent; c: root.c }
  }
}
