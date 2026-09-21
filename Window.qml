import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui
import "Format.js" as Format

// Yapper as an app: a real window Hyprland tiles like any other, with the
// room list on the left and the conversation on the right. Same
// Service.qml as the bar popup, so both stay in step.
//
//   omarchy-shell shell summon marcho78.yapper '{}'   # open
//   omarchy-shell shell toggle marcho78.yapper '{}'   # toggle
//   omarchy-shell shell hide marcho78.yapper          # close
//
// The payload may carry { room: "!id:server" } to open straight into a room,
// or { settings: true } to open on the settings pane.
Item {
  id: root
  property var shell: null
  property var service: null
  property bool closingFromHost: false

  readonly property bool loggedIn: service ? service.loggedIn : false
  readonly property color fg: service ? service.fg : Color.foreground
  readonly property color bg: service ? service.bg : Color.popups.background
  readonly property color sidebarBg: service ? service.sidebarBg : bg
  readonly property string fontFamily: Style.font.family
  readonly property bool inRoom: roomView.roomId !== ""
  readonly property bool opened: window.visible
  property bool showSettings: false
  onShowSettingsChanged: if (showSettings) settingsFlick.contentY = 0
  property bool showInfo: false
  property bool showSearch: false
  function openSearch(scoped) {
    root.showSearch = true
    searchView.inRoom = scoped && root.inRoom
    Qt.callLater(searchView.focusField)
  }

  // ---- plugin lifecycle ----------------------------------------------------

  function open(payloadJson) {
    closingFromHost = false
    window.visible = true
    if (service) { service.ensureDaemon(); if (service.loggedIn) service.refresh() }
    var wanted = ""
    if (payloadJson) {
      try {
        var p = JSON.parse(String(payloadJson))
        if (p && typeof p.room === "string") wanted = p.room
        if (p && p.settings === true) root.showSettings = true
        if (p && typeof p.pick === "string") { root.showSettings = true; settingsView.pickKey = p.pick }
        if (p && p.info === true) root.showInfo = true
        if (p && typeof p.search === "string") { root.openSearch(false); searchView.reset(); }
        if (p && typeof p.space === "string" && service) service.currentSpace = p.space
      } catch (e) { /* ignore */ }
    }
    Qt.callLater(function() {
      if (wanted !== "" && service) {
        var r = service.roomById(wanted)
        if (r) root.openRoom(r)
      }
      if (root.showSearch) searchView.focusField()
      else if (roomView.roomId !== "") roomView.focusComposer()
      else if (gate.visible) gate.focusFirst()
      else roomList.focusSearch()
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

  function openRoom(r) { roomView.open(r) }

  FloatingWindow {
    id: window
    title: root.inRoom ? roomView.roomName + " – Yapper" : "Yapper"
    color: root.bg
    implicitWidth: 960
    implicitHeight: 640
    minimumSize: Qt.size(640, 420)

    onVisibleChanged: {
      if (!visible && !root.closingFromHost && root.shell && typeof root.shell.hide === "function")
        root.shell.hide("marcho78.yapper")
      if (!visible) gate.clearSecrets()
    }

    // Sign-in / daemon states take the whole window.
    Item {
      anchors.fill: parent
      anchors.margins: Style.space(24)
      visible: !root.loggedIn

      Column {
        anchors.centerIn: parent
        width: Math.min(parent.width, Style.space(520))
        spacing: Style.space(16)

        Row {
          spacing: Style.space(14)
          Text {
            text: root.service ? root.service.glyph : "󰭹"
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            anchors.verticalCenter: parent.verticalCenter
          }
          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)
            Text { text: "Yapper"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
            Text { text: root.service ? root.service.stateText : ""; color: root.fg; opacity: 0.7; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
          }
        }

        SessionGate {
          id: gate
          width: parent.width
          service: root.service
          fg: root.fg
          fontFamily: root.fontFamily
        }
      }
    }

    // Signed in: sidebar + conversation
    Item {
      anchors.fill: parent
      visible: root.loggedIn

      // Sidebar
      Item {
        id: sidebar
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.max(Style.space(300), Math.min(Style.space(380), parent.width * 0.34))

        Rectangle {
          anchors.fill: parent
          visible: root.sidebarBg !== root.bg
          color: root.sidebarBg
        }
        Rectangle {
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: 1
          color: Color.popups.border
          opacity: 0.4
        }

        Column {
          anchors.fill: parent
          anchors.margins: Style.space(16)
          spacing: Style.space(12)

          Item {
            width: parent.width
            implicitHeight: Math.max(accountLabels.implicitHeight, signOutButton.implicitHeight)
            Column {
              id: accountLabels
              anchors.left: parent.left
              anchors.right: signOutButton.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)
              Text { text: "Yapper"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
              Text {
                width: parent.width
                text: root.service ? root.service.userId : ""
                color: root.fg; opacity: 0.6
                font.family: root.fontFamily; font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
              Text {
                width: parent.width
                text: "v" + (root.service ? root.service.pluginVersion : "") + "  ·  daemon " + (root.service && root.service.daemonVersion ? root.service.daemonVersion : "—")
                  + (root.service && root.service.updateAvailable ? "  ·  󰚰 update" : "")
                color: root.service && root.service.updateAvailable ? Color.accent : root.fg
                opacity: root.service && root.service.updateAvailable ? 1 : 0.4
                font.family: root.fontFamily; font.pixelSize: Style.font.caption
                elide: Text.ElideRight
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.showSettings = true }
              }
            }
            Row {
              id: signOutButton
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.spacing.controlGap
              Button {
                iconText: "󰒓"
                text: ""
                bordered: root.showSettings
                onClicked: root.showSettings = !root.showSettings
              }
              Button {
                text: "Sign out"
                onClicked: { roomView.close(); root.service.logout() }
              }
            }
          }

          UpdateBanner {
            width: parent.width
            service: root.service
            fg: root.fg
            fontFamily: root.fontFamily
          }

          VerificationView {
            width: parent.width
            service: root.service
            fg: root.fg
            fontFamily: root.fontFamily
            compact: true
          }

          Flickable {
            id: listFlick
            width: parent.width
            height: parent.height - y
            contentHeight: roomList.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            RoomList {
              id: roomList
              width: listFlick.width
              service: root.service
              fg: root.fg
              fontFamily: root.fontFamily
              currentRoom: roomView.roomId
              showSearchButton: true
              onRoomChosen: function(r) { root.openRoom(r) }
              onSearchRequested: root.openSearch(false)
            }
          }
        }
      }

      // Conversation
      Item {
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: Style.space(16)

        // Settings
        Flickable {
          id: settingsFlick
          anchors.fill: parent
          visible: root.showSettings
          // A slider drag must not turn into a flick.
          interactive: !settingsView.dragging
          contentHeight: settingsColumn.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          Column {
            id: settingsColumn
            width: parent.width
            spacing: Style.space(12)
            Item {
              width: parent.width
              implicitHeight: Math.max(settingsTitle.implicitHeight, settingsClose.implicitHeight)
              Text {
                id: settingsTitle
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Settings"
                color: root.fg
                font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true
              }
              Button {
                id: settingsClose
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Done"
                bordered: true
                onClicked: root.showSettings = false
              }
            }
            PanelSeparator { width: parent.width }
            SettingsView {
              id: settingsView
              width: parent.width
              service: root.service
              fg: root.fg
              fontFamily: root.fontFamily
              onReveal: function(y) {
                var target = settingsView.y + y - Style.space(12)
                settingsFlick.contentY = Math.max(0, Math.min(target, settingsFlick.contentHeight - settingsFlick.height))
              }
            }
          }
        }

        // Empty state
        Column {
          anchors.centerIn: parent
          visible: !root.inRoom && !root.showSettings && !root.showSearch
          spacing: Style.space(6)
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "󰭹"
            color: root.fg; opacity: 0.35
            font.family: root.fontFamily; font.pixelSize: Style.font.display * 2
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Pick a room, or find one on the left."
            color: root.fg; opacity: 0.5
            font.family: root.fontFamily; font.pixelSize: Style.font.body
          }
        }

        // Search pane: takes the conversation area
        Item {
          anchors.fill: parent
          visible: root.showSearch && !root.showSettings
          z: 2
          Rectangle { anchors.fill: parent; color: root.bg }
          SearchView {
            id: searchView
            anchors.fill: parent
            service: root.service
            fg: root.fg
            fontFamily: root.fontFamily
            roomId: roomView.roomId
            roomName: roomView.roomName
            onCloseRequested: root.showSearch = false
            onOpenMessage: function(rid, eid) {
              root.showSearch = false
              var r = root.service.roomById(rid)
              if (!r) return
              if (roomView.roomId === rid) roomView.jumpTo(eid)
              else roomView.openAt(r, eid)
            }
          }
        }

        // Room info: slides over the right side of the conversation
        Rectangle {
          id: infoPane
          visible: false
          height: 0
        }
        Rectangle {
          id: infoOverlay
          visible: root.showInfo && root.inRoom && !root.showSettings
          z: 3
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: Math.min(parent.width, Style.space(360))
          color: root.bg
          border.width: 1
          border.color: Util.alpha(root.fg, 0.2)
          radius: Style.space(8)
          RoomInfo {
            anchors.fill: parent
            anchors.margins: Style.space(14)
            service: root.service
            fg: root.fg
            fontFamily: root.fontFamily
            roomId: root.showInfo ? roomView.roomId : ""
            onCloseRequested: root.showInfo = false
            onMemberChosen: function(m) { root.showInfo = false; roomList.openDm(m.id) }
            onLeftRoom: { root.showInfo = false; roomView.close() }
          }
        }

        Column {
          anchors.fill: parent
          visible: root.inRoom && !root.showSettings && !root.showSearch
          spacing: Style.space(10)

          // Room header (click for room info)
          Item {
            id: roomHeader
            width: parent.width
            implicitHeight: Math.max(headerLabels.implicitHeight, infoButton.implicitHeight, Style.space(28))
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.showInfo = !root.showInfo
            }
            Avatar {
              id: headerAvatar
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              size: Style.space(34)
              userId: roomView.roomId
              name: roomView.roomName
              mxc: roomView.room && roomView.room.avatar ? roomView.room.avatar : ""
              service: root.service
              fontFamily: root.fontFamily
            }
            Column {
              id: headerLabels
              anchors.left: headerAvatar.right
              anchors.leftMargin: Style.space(10)
              anchors.right: infoButton.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)
              Text {
                width: parent.width
                text: roomView.roomName
                color: root.fg
                font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true
                elide: Text.ElideRight
              }
              Text {
                width: parent.width
                text: (roomView.encrypted ? "󰌾 End-to-end encrypted" : "󰌿 Not encrypted")
                  + (roomView.room && roomView.room.topic ? " · " + Format.oneLine(roomView.room.topic) : "")
                color: roomView.encrypted ? root.fg : Color.urgent
                opacity: 0.7
                font.family: root.fontFamily; font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }
            Row {
              id: infoButton
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.spacing.controlGap
              Button { iconText: "󰍉"; text: ""; bordered: root.showSearch; onClicked: root.openSearch(true) }
              Button { iconText: "󰋽"; text: ""; bordered: root.showInfo; onClicked: root.showInfo = !root.showInfo }
            }
          }

          PanelSeparator { width: parent.width }

          RoomView {
            id: roomView
            width: parent.width
            height: parent.height - roomHeader.height - parent.spacing * 2 - 1 - (infoPane.visible ? infoPane.height + parent.spacing : 0)
            fillHeight: true
            service: root.service
            viewId: "window"
            fg: root.fg
            fontFamily: root.fontFamily
            visible: root.inRoom && !root.showSettings && !root.showSearch && window.visible
          }
        }
      }
    }
  }
}
