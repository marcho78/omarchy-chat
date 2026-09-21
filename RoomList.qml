import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Find / create / invitations / rooms. Emits roomChosen(room) when the user
// picks or lands in a room; the parent decides where to show it.
Column {
  id: root
  property var service: null
  property color fg: Color.foreground
  property string fontFamily: Style.font.family
  property string currentRoom: ""     // highlighted row, if any
  property bool busy: false
  property string errorText: ""
  property var results: []
  property string resultsKind: ""     // "rooms" | "users"
  property bool searching: false
  property bool showNewRoom: false

  signal roomChosen(var room)

  spacing: Style.space(8)

  function fail(msg) { root.errorText = msg }
  function clearResults() { root.results = []; root.resultsKind = ""; searchField.text = "" }
  function focusSearch() { searchField.forceActiveFocus() }
  readonly property bool hasTextFocus: searchField.activeFocus || newRoomName.activeFocus

  // One field, three behaviours: "#alias:server" / "!id:server" joins,
  // "@user:server" opens a DM, "@name" searches people, anything else
  // searches the public room directory.
  function search(text) {
    text = String(text).trim()
    if (text === "" || root.searching) return
    root.errorText = ""
    var first = text.charAt(0)
    if (first === "#" || first === "!") { root.joinRoom(text); return }
    if (first === "@") {
      if (text.indexOf(":") > 1) { root.openDm(text); return }
      root.searching = true
      root.service.searchUsers(text.substring(1), function(r) {
        root.searching = false
        if (!r.ok) { root.fail(r.error || "Search failed"); return }
        root.results = r.result; root.resultsKind = "users"
        if (r.result.length === 0) root.fail("No one found for " + text)
      })
      return
    }
    root.searching = true
    root.service.searchRooms(text, function(r) {
      root.searching = false
      if (!r.ok) { root.fail(r.error || "Search failed"); return }
      root.results = r.result; root.resultsKind = "rooms"
      if (r.result.length === 0) root.fail("No public rooms match \"" + text + "\"")
    })
  }

  function joinRoom(idOrAlias) {
    if (root.busy) return
    root.busy = true
    root.service.join(idOrAlias, function(r) {
      root.busy = false
      if (!r.ok) { root.fail(r.error || "Could not join"); return }
      root.clearResults()
      root.roomChosen(r.result)
    })
  }

  function openDm(userId) {
    if (root.busy) return
    root.busy = true
    root.service.dm(userId, function(r) {
      root.busy = false
      if (!r.ok) { root.fail(r.error || "Could not open chat"); return }
      root.clearResults()
      root.roomChosen(r.result)
    })
  }

  function createRoom() {
    if (root.busy) return
    root.busy = true
    root.service.createRoom(newRoomName.text, encryptedToggle.checked, privateToggle.checked, function(r) {
      root.busy = false
      if (!r.ok) { root.fail(r.error || "Could not create room"); return }
      root.showNewRoom = false
      newRoomName.text = ""
      root.roomChosen(r.result)
    })
  }

  // Find
  Row {
    width: parent.width
    spacing: Style.spacing.controlGap
    TextField {
      id: searchField
      width: parent.width - findButton.width - newRoomButton.width - 2 * Style.spacing.controlGap
      maximumLength: 256
      placeholderText: "Find rooms · #alias · @user"
      enabled: !root.searching
      onAccepted: root.search(searchField.text)
    }
    Button {
      id: findButton
      text: root.searching ? "…" : "Find"
      iconText: "󰍉"
      enabled: !root.searching
      onClicked: root.search(searchField.text)
    }
    Button {
      id: newRoomButton
      iconText: "󰐕"
      text: "Room"
      bordered: true
      onClicked: { root.showNewRoom = !root.showNewRoom; if (root.showNewRoom) Qt.callLater(function() { newRoomName.forceActiveFocus() }) }
    }
  }

  // New room form
  Column {
    width: parent.width
    spacing: Style.space(6)
    visible: root.showNewRoom
    TextField {
      id: newRoomName
      width: parent.width
      maximumLength: 128
      placeholderText: "Room name"
      enabled: !root.busy
      onAccepted: root.createRoom()
    }
    Toggle {
      id: encryptedToggle
      width: parent.width
      label: "End-to-end encrypted"
      description: "Cannot be turned off later"
      checked: true
      onClicked: checked = !checked
    }
    Toggle {
      id: privateToggle
      width: parent.width
      label: "Private"
      description: checked ? "Invite only" : "Listed in the public directory"
      checked: true
      onClicked: checked = !checked
    }
    Row {
      spacing: Style.spacing.controlGap
      Button { text: root.busy ? "Creating…" : "Create"; iconText: "󰐕"; bordered: true; enabled: !root.busy; onClicked: root.createRoom() }
      Button { text: "Cancel"; onClicked: root.showNewRoom = false }
    }
  }

  // Search results
  Column {
    width: parent.width
    spacing: Style.space(2)
    visible: root.results.length > 0

    Item {
      width: parent.width
      implicitHeight: resultsHeader.implicitHeight
      PanelSectionHeader { id: resultsHeader; text: root.resultsKind === "users" ? "People" : "Public rooms" }
      Button { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "Clear"; onClicked: root.clearResults() }
    }

    Repeater {
      model: root.results
      delegate: Item {
        id: resultRow
        required property var modelData
        width: root.width
        implicitHeight: Style.space(36)

        Column {
          anchors.left: parent.left
          anchors.right: resultAction.left
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(1)
          Text {
            width: parent.width
            text: root.resultsKind === "users" ? (resultRow.modelData.name || resultRow.modelData.id) : resultRow.modelData.name
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
          }
          Text {
            width: parent.width
            text: root.resultsKind === "users"
              ? resultRow.modelData.id
              : ((resultRow.modelData.alias || resultRow.modelData.id) + " · " + resultRow.modelData.members + " members")
            color: root.fg
            opacity: 0.5
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
        }
        Button {
          id: resultAction
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          bordered: true
          enabled: !root.busy
          text: root.resultsKind === "users" ? "Message" : (resultRow.modelData.joined ? "Open" : "Join")
          onClicked: {
            if (root.resultsKind === "users") root.openDm(resultRow.modelData.id)
            else if (resultRow.modelData.joined) { root.clearResults(); root.roomChosen(resultRow.modelData) }
            else root.joinRoom(resultRow.modelData.alias || resultRow.modelData.id)
          }
        }
      }
    }
  }

  // Invitations
  Column {
    width: parent.width
    spacing: Style.space(2)
    visible: root.service && root.service.invites.length > 0

    PanelSectionHeader { text: "Invitations" }

    Repeater {
      model: root.service ? root.service.invites : []
      delegate: Item {
        id: inviteRow
        required property var modelData
        width: root.width
        implicitHeight: Style.space(36)

        Column {
          anchors.left: parent.left
          anchors.right: inviteButtons.left
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(1)
          Text {
            width: parent.width
            text: inviteRow.modelData.name
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
            elide: Text.ElideRight
          }
          Text {
            width: parent.width
            text: "from " + (inviteRow.modelData.inviter_name || inviteRow.modelData.inviter || "unknown")
            color: root.fg
            opacity: 0.5
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
        }
        Row {
          id: inviteButtons
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.spacing.controlGap
          Button {
            text: "Accept"; bordered: true
            onClicked: root.service.acceptInvite(inviteRow.modelData.room, function(r) {
              if (!r.ok) root.fail(r.error || "Could not accept"); else root.roomChosen(r.result)
            })
          }
          Button {
            text: "Decline"
            onClicked: root.service.declineInvite(inviteRow.modelData.room, function(r) { if (!r.ok) root.fail(r.error || "Could not decline") })
          }
        }
      }
    }
  }

  // Rooms
  Column {
    width: parent.width
    spacing: Style.space(2)

    PanelSectionHeader { text: "Rooms"; visible: root.service && root.service.rooms.length > 0 }

    Text {
      width: parent.width
      visible: root.service && root.service.rooms.length === 0
      wrapMode: Text.WordWrap
      text: root.service && root.service.status.syncing
        ? "No rooms yet. Search the directory above, join by #alias, or message someone by @user:server."
        : "Syncing…"
      color: root.fg
      opacity: 0.6
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Repeater {
      model: root.service ? root.service.rooms : []
      delegate: Item {
        id: roomRow
        required property var modelData
        width: root.width
        implicitHeight: Style.space(34)

        Rectangle {
          anchors.fill: parent
          radius: Style.space(6)
          color: roomRow.modelData.id === root.currentRoom ? Color.menu.selectedBackground
            : (rowMouse.containsMouse ? Util.alpha(Color.menu.selectedBackground, 0.5) : "transparent")
        }
        Row {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(8)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: roomRow.modelData.direct ? "󰭹" : (roomRow.modelData.encrypted ? "󰌾" : "󰌿")
            color: roomRow.modelData.encrypted ? Color.accent : Color.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Style.space(60)
            text: roomRow.modelData.name
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: (Number(roomRow.modelData.unread) || 0) > 0
            elide: Text.ElideRight
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: (Number(roomRow.modelData.unread) || 0) > 0
            text: String(roomRow.modelData.unread)
            color: (Number(roomRow.modelData.highlights) || 0) > 0 ? Color.urgent : Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }
        MouseArea {
          id: rowMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.roomChosen(roomRow.modelData)
        }
      }
    }
  }

  Text {
    width: parent.width
    wrapMode: Text.WordWrap
    visible: root.errorText !== ""
    text: root.errorText
    color: Color.urgent
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }
}
