import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui

// Chat as an app: a real window Hyprland tiles like any other, with the
// room list on the left and the conversation on the right. Same
// Service.qml as the bar popup, so both stay in step.
//
//   omarchy-shell shell summon marcho78.chat '{}'   # open
//   omarchy-shell shell toggle marcho78.chat '{}'   # toggle
//   omarchy-shell shell hide marcho78.chat          # close
//
// The payload may carry { room: "!id:server" } to open straight into a room.
Item {
  id: root
  property var shell: null
  property var service: null
  property bool closingFromHost: false

  readonly property bool loggedIn: service ? service.loggedIn : false
  readonly property color fg: Color.foreground
  readonly property string fontFamily: Style.font.family
  readonly property bool inRoom: roomView.roomId !== ""
  readonly property bool opened: window.visible

  // ---- plugin lifecycle ----------------------------------------------------

  function open(payloadJson) {
    closingFromHost = false
    window.visible = true
    if (service) { service.ensureDaemon(); if (service.loggedIn) service.refresh() }
    var wanted = ""
    if (payloadJson) {
      try { var p = JSON.parse(String(payloadJson)); if (p && typeof p.room === "string") wanted = p.room } catch (e) { /* ignore */ }
    }
    Qt.callLater(function() {
      if (wanted !== "" && service) {
        var r = service.roomById(wanted)
        if (r) root.openRoom(r)
      }
      if (roomView.roomId !== "") roomView.focusComposer()
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
    if (shell && typeof shell.hide === "function") shell.hide("marcho78.chat")
    else window.visible = false
  }

  function openRoom(r) { roomView.open(r) }

  FloatingWindow {
    id: window
    title: root.inRoom ? roomView.roomName + " – Chat" : "Chat"
    color: Color.popups.background
    implicitWidth: 960
    implicitHeight: 640
    minimumSize: Qt.size(640, 420)

    onVisibleChanged: {
      if (!visible && !root.closingFromHost && root.shell && typeof root.shell.hide === "function")
        root.shell.hide("marcho78.chat")
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
            Text { text: "Chat"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
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
          color: Util.alpha(Color.menu.selectedBackground, 0.5)
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
              Text { text: "Chat"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
              Text {
                width: parent.width
                text: root.service ? root.service.userId : ""
                color: root.fg; opacity: 0.6
                font.family: root.fontFamily; font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }
            Button {
              id: signOutButton
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: "Sign out"
              onClicked: { roomView.close(); root.service.logout() }
            }
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
              onRoomChosen: function(r) { root.openRoom(r) }
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

        // Empty state
        Column {
          anchors.centerIn: parent
          visible: !root.inRoom
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

        Column {
          anchors.fill: parent
          visible: root.inRoom
          spacing: Style.space(10)

          // Room header
          Item {
            id: roomHeader
            width: parent.width
            implicitHeight: Math.max(headerLabels.implicitHeight, Style.space(28))
            Column {
              id: headerLabels
              anchors.left: parent.left
              anchors.right: parent.right
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
                  + (roomView.room && roomView.room.topic ? " · " + roomView.room.topic : "")
                color: roomView.encrypted ? root.fg : Color.urgent
                opacity: 0.7
                font.family: root.fontFamily; font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }
          }

          PanelSeparator { width: parent.width }

          RoomView {
            id: roomView
            width: parent.width
            height: parent.height - roomHeader.height - parent.spacing * 2 - 1
            fillHeight: true
            service: root.service
            viewId: "window"
            fg: root.fg
            fontFamily: root.fontFamily
            visible: root.inRoom && window.visible
          }
        }
      }
    }
  }
}
