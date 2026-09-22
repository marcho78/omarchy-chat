import QtQuick
import Quickshell
import qs.Commons
import "../../shared"
import "../../shared/Palettes.js" as Palettes
import "../../shared/Format.js" as Format

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
  readonly property var room: roomView.room
  readonly property string roomId: roomView.roomId
  readonly property bool inRoom: roomId !== ""
  readonly property bool inThread: threadView.roomId !== ""
  // "" | thread | info — what the right panel shows
  property string panel: ""
  // Settings: which section is open, and a color row to unfold
  property string settingsSection: "about"
  function openSettings(section, pick) {
    root.view = "settings"
    settingsView.show(section && section !== "" ? section : root.settingsSection, pick || "")
    root.settingsSection = settingsView.section
  }
  function togglePanel(which) {
    if (root.panel === which) { root.closePanel(); return }
    if (which === "info" && root.inThread) threadView.close()
    root.panel = which
  }
  function closePanel() {
    if (root.panel === "thread") { if (threadView.roomId !== "") threadView.close(); roomView.focusComposer() }
    root.panel = ""
  }
  Ui { id: ui }

  readonly property string titleHint: !loggedIn ? "not signed in"
    : view !== "chat" ? view
    : room ? (room.topic ? Format.oneLine(room.topic) : (room.direct ? "direct chat" : "")) : ""

  // ---- plugin lifecycle ----------------------------------------------------

  // One dialog at a time; a new open request starts clean.
  function closeDialogs() { newRoomDialog.open = false; inviteDialog.open = false; joinDialog.open = false; verifyDialog.open = false; installDialog.open = false; quitDialog.open = false }
  function askInstall(update) { root.closeDialogs(); installDialog.update = update; installDialog.open = true }
  function open(payloadJson) {
    closingFromHost = false
    window.visible = true
    root.closeDialogs()
    if (service) { service.ensureDaemon(); if (service.loggedIn) service.refresh() }
    var wanted = ""
    var wantedThread = ""
    if (payloadJson) {
      try {
        var p = JSON.parse(String(payloadJson))
        if (p && typeof p.room === "string") { wanted = p.room; root.view = "chat" }
        if (p && typeof p.thread === "string") wantedThread = p.thread
        if (p && p.info === true) root.panel = "info"
        if (p && p.settings === true) root.openSettings("")
        if (p && typeof p.settings === "string") root.openSettings(p.settings)
        if (p && typeof p.pick === "string") root.openSettings("appearance", p.pick)
        if (p && typeof p.search === "string") { search.scope = ""; search.query = p.search; root.view = "search"; if (p.search !== "") Qt.callLater(search.run) }
        if (p && p.people === true) root.view = "people"
        if (p && p.explore === true) { if (typeof p.query === "string") explore.query = p.query; root.view = "explore" }
        if (p && p.create === true) newRoomDialog.open = true
        if (p && p.join === true) joinDialog.open = true
        if (p && p.verify === true) verifyDialog.open = true
        if (p && p.invite === true) inviteDialog.open = true
        if (p && p.install === "update") root.askInstall(true)
        else if (p && p.install === true) root.askInstall(false)
        if (p && typeof p.space === "string" && service) service.currentSpace = p.space
      } catch (e) { /* ignore */ }
    }
    Qt.callLater(function() {
      if (wanted !== "" && service) {
        var r = service.roomById(wanted)
        if (r) root.openRoom(r)
        if (r && wantedThread !== "") root.openThread(wantedThread)
      }
      if (root.loggedIn && root.inRoom && root.view === "chat") (root.inThread ? threadView : roomView).focusComposer()
      else if (root.loggedIn && root.view === "chat") sidebar.focusFind()
      else if (!root.loggedIn) gate.focusFirst()
    })
  }

  // Host-initiated close (`shell hide`).
  function close() {
    closingFromHost = true
    window.visible = false
    closingFromHost = false
    root.closeDialogs()
  }

  // User-initiated close (window close button): keep the shell's open map right.
  function requestClose() {
    if (shell && typeof shell.hide === "function") shell.hide("marcho78.yapper")
    else window.visible = false
  }

  function openRoom(r) { roomView.open(r); root.view = "chat" }
  function show(view) { root.view = view }
  // A thread takes the conversation's place; its ✕ or Esc goes back.
  function openThread(eventId) {
    if (!roomView.room) return
    threadView.openThread(roomView.room, eventId)
    root.panel = "thread"
    Qt.callLater(function() { threadView.focusComposer() })
  }
  function closeThread() { root.closePanel() }
  onInThreadChanged: if (!inThread && root.panel === "thread") root.panel = ""

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

    // Signed out: the gate
    Gate {
      id: gate
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: titleStrip.bottom
      anchors.bottom: parent.bottom
      visible: !root.loggedIn
      c: root.c
      tips: tips
      service: root.service
      onInstallRequested: root.askInstall(false)
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
        onViewRequested: function(v) { if (v === "settings") root.openSettings(""); else root.view = v }
        onQuitRequested: { root.closeDialogs(); quitDialog.open = true }
        onSpaceRequested: function(id) { if (root.service) root.service.currentSpace = id }
        onVerifyRequested: verifyDialog.open = true
      }

      Sidebar {
        id: sidebar
        anchors.left: rail.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: ui.sidebarWidth
        // Settings take the whole width beside the rail.
        visible: root.view !== "settings"
        c: root.c
        tips: tips
        service: root.service
        currentRoom: root.view === "chat" ? root.roomId : ""
        onRoomChosen: function(r) { root.openRoom(r) }
        onCreateRequested: newRoomDialog.open = true
        onExploreRequested: function(q) { explore.query = q; root.view = "explore" }
        onPeopleRequested: function(q) { people.query = q; root.view = "people" }
        onSearchRequested: function(q) { search.scope = ""; search.query = q; root.view = "search"; Qt.callLater(search.run) }
        onSettingsRequested: function(section) { root.openSettings(section) }
      }

      // Conversation column
      Item {
        id: main
        anchors.left: root.view === "settings" ? rail.right : sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        // The right panel sits beside the conversation when there is room
        // for both; otherwise it takes the conversation's place.
        readonly property bool split: width >= ui.px(330) + ui.px(440)
        readonly property bool panelOpen: root.view === "chat" && root.inRoom && root.panel !== ""
        readonly property bool covered: panelOpen && !split
        readonly property real conversationWidth: panelOpen && split ? width - panelBox.width : width

        // Room header
        Item {
          id: roomHeader
          anchors.left: parent.left
          anchors.top: parent.top
          width: main.conversationWidth
          height: ui.headerHeight
          visible: root.view === "chat" && root.inRoom && !main.covered
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
            IconButton { c: root.c; tips: tips; icon: "magnifying-glass"; size: ui.px(32); iconSize: ui.px(16); tooltip: "Search this room"; onClicked: { search.scope = root.roomId; root.view = "search" } }
            IconButton { c: root.c; tips: tips; icon: "users"; size: ui.px(32); iconSize: ui.px(16); tooltip: "Members"; active: root.panel === "info"; onClicked: root.togglePanel("info") }
            IconButton { c: root.c; tips: tips; icon: "info"; size: ui.px(32); iconSize: ui.px(16); tooltip: "Room info"; active: root.panel === "info"; onClicked: root.togglePanel("info") }
          }
        }

        RoomView {
          id: roomView
          anchors.left: parent.left
          anchors.top: roomHeader.bottom
          anchors.bottom: parent.bottom
          width: main.conversationWidth
          visible: root.view === "chat" && root.inRoom && !main.covered && window.visible
          c: root.c
          tips: tips
          service: root.service
          viewId: "window"
          onThreadRequested: function(id) { root.openThread(id) }
          // Switching rooms closes the thread of the previous one.
          onRoomIdChanged: if (threadView.roomId !== "" && threadView.roomId !== roomId) threadView.close()
        }

        // The right panel: a thread, or room info
        Rectangle {
          id: panelBox
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: main.split ? ui.px(330) : main.width
          visible: main.panelOpen
          color: root.c.bg2
          Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 1; color: root.c.line; visible: main.split }
          Item {
            id: panelHeader
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: ui.headerHeight
            Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: root.c.line }
            Row {
              anchors.left: parent.left
              anchors.leftMargin: ui.px(12)
              anchors.right: panelClose.left
              anchors.rightMargin: ui.px(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: ui.px(9)
              Icon { anchors.verticalCenter: parent.verticalCenter; name: root.panel === "thread" ? "tree-structure" : "info"; size: ui.px(16); color: root.c.accent }
              Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - ui.px(25)
                spacing: ui.px(1)
                Text { text: root.panel === "thread" ? "Thread" : "Room info"; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.px(13.5); font.weight: Font.DemiBold }
                Text { width: parent.width; visible: root.panel === "thread" || !main.split; text: "in " + roomView.roomName; color: root.c.muted; elide: Text.ElideRight; font.family: ui.sans; font.pixelSize: ui.f11 }
              }
            }
            IconButton {
              id: panelClose
              anchors.right: parent.right
              anchors.rightMargin: ui.px(12)
              anchors.verticalCenter: parent.verticalCenter
              c: root.c; tips: tips
              icon: main.split ? "x" : "arrow-left"
              size: ui.px(30); iconSize: ui.px(15); radius: ui.px(7)
              tooltip: root.panel === "thread" ? "Close the thread (Esc)" : "Close"
              onClicked: root.closePanel()
            }
          }
          Item {
            id: threadSlot
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: panelHeader.bottom
            anchors.bottom: parent.bottom
            visible: root.panel === "thread"
          }
          RoomInfo {
            id: roomInfo
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: panelHeader.bottom
            anchors.bottom: parent.bottom
            visible: root.panel === "info"
            c: root.c
            tips: tips
            service: root.service
            roomId: root.panel === "info" && main.panelOpen ? root.roomId : ""
            onMemberChosen: function(m) { root.closePanel(); sidebar.chat(m.id) }
            onLeftRoom: { root.closePanel(); roomView.close() }
            onInviteRequested: inviteDialog.open = true
          }
        }
        RoomView {
          id: threadView
          parent: threadSlot
          anchors.fill: parent
          visible: root.panel === "thread" && main.panelOpen && window.visible
          c: root.c
          tips: tips
          service: root.service
          viewId: "window-thread"
          onCloseRequested: root.closeThread()
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

        SettingsView {
          id: settingsView
          anchors.fill: parent
          visible: root.view === "settings"
          c: root.c
          tips: tips
          service: root.service
          onCloseRequested: root.view = "chat"
          onPeopleRequested: root.view = "people"
          onInstallRequested: function(update) { root.askInstall(update) }
        }

        Explore {
          id: explore
          anchors.fill: parent
          visible: root.view === "explore"
          c: root.c
          tips: tips
          service: root.service
          onRoomChosen: function(r) { root.openRoom(r) }
          onCloseRequested: root.view = "chat"
        }
        People {
          id: people
          anchors.fill: parent
          visible: root.view === "people"
          c: root.c
          tips: tips
          service: root.service
          onMessageRequested: function(id) { sidebar.chat(id) }
          onCloseRequested: root.view = "chat"
        }
        Search {
          id: search
          anchors.fill: parent
          visible: root.view === "search"
          c: root.c
          tips: tips
          service: root.service
          scopeName: roomView.roomName
          onOpenMessage: function(rid, eid) {
            var r = root.service.roomById(rid)
            if (!r) return
            root.view = "chat"
            if (roomView.roomId === rid) roomView.jumpTo(eid); else roomView.openAt(r, eid)
          }
          onCloseRequested: root.view = "chat"
        }
      }
    }

    // Dialogs
    NewRoomDialog { id: newRoomDialog; c: root.c; tips: tips; service: root.service; onCreated: function(r) { root.openRoom(r) } }
    InviteDialog { id: inviteDialog; c: root.c; tips: tips; service: root.service; roomId: root.roomId; roomName: roomView.roomName }
    JoinDialog { id: joinDialog; c: root.c; tips: tips; service: root.service }
    VerifyDialog { id: verifyDialog; c: root.c; tips: tips; service: root.service }
    InstallDialog { id: installDialog; c: root.c; tips: tips; service: root.service }
    // Quit: the window closes and the daemon stops
    Modal {
      id: quitDialog
      c: root.c
      tips: tips
      icon: "power"
      tone: root.c.bad
      iconBg: Qt.rgba(root.c.bad.r, root.c.bad.g, root.c.bad.b, 0.16)
      title: "Quit Yapper?"
      description: "The daemon stops, so notifications pause until you open Yapper again. You stay signed in."
      dialogWidth: ui.px(420)
      Row {
        spacing: ui.px(10)
        PillButton { c: root.c; label: "Quit"; icon: "power"; danger: true; round: true; onClicked: { quitDialog.close(); root.service.quit(); root.requestClose() } }
        PillButton { c: root.c; label: "Keep running"; round: true; onClicked: quitDialog.close() }
      }
    }
    // Another of your devices asking to verify surfaces by itself.
    Connections {
      target: root.service
      function onActiveFlowChanged() {
        var f = root.service.activeFlow
        if (f && !f.outgoing && f.state === "requested" && root.loggedIn) { window.visible = true; verifyDialog.open = true }
      }
    }

    Tips { id: tips; anchors.fill: parent; c: root.c }
  }
}
