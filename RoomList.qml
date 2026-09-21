import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "Format.js" as Format

// Find / create / invitations / rooms. Emits roomChosen(room) when the user
// picks or lands in a room; the parent decides where to show it.
Column {
  id: root
  property var service: null
  property color fg: Color.foreground
  property color accent: service ? service.accent : Color.accent
  property color hover: service ? service.hover : Util.alpha(Color.menu.selectedBackground, 0.5)
  property color selection: service ? service.selection : Color.menu.selectedBackground
  property string fontFamily: Style.font.family
  property string currentRoom: ""     // highlighted row, if any
  property bool busy: false
  property string errorText: ""
  property var results: []
  property string resultsKind: ""     // "rooms" | "users"
  property bool searching: false
  property bool showNewRoom: false

  signal roomChosen(var room)
  signal searchRequested()
  // The window shows a message-search button; the popup has no room for it.
  property bool showSearchButton: false

  spacing: Style.space(8)

  function fail(msg) { root.errorText = msg }
  // Results take the list's place until cleared: the ✕ in the field, Esc,
  // emptying the field, the header's Back, or picking a result.
  readonly property bool showingResults: results.length > 0
  property string resultsQuery: ""
  function clearResults() { root.results = []; root.resultsKind = ""; root.resultsQuery = ""; root.errorText = ""; searchField.text = "" }
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
        root.results = r.result; root.resultsKind = "users"; root.resultsQuery = text
        if (r.result.length === 0) root.fail("No one found for " + text)
      })
      return
    }
    root.searching = true
    root.service.searchRooms(text, function(r) {
      root.searching = false
      if (!r.ok) { root.fail(r.error || "Search failed"); return }
      root.results = r.result; root.resultsKind = "rooms"; root.resultsQuery = text
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
      width: parent.width - findButton.width - newRoomButton.width - (msgSearchButton.visible ? msgSearchButton.width + Style.spacing.controlGap : 0) - 2 * Style.spacing.controlGap
      maximumLength: 256
      placeholderText: "Find rooms · #alias · @user"
      enabled: !root.searching
      rightPadding: clearGlyph.visible ? clearGlyph.width + Style.space(12) : Style.spacing.controlPaddingX
      onAccepted: root.search(searchField.text)
      onTextChanged: if (text === "" && root.showingResults) root.clearResults()
      Keys.onEscapePressed: function(event) { if (searchField.text !== "" || root.showingResults) { event.accepted = true; root.clearResults() } }
      // ✕ inside the field once there is something to clear.
      Text {
        id: clearGlyph
        visible: searchField.text !== "" || root.showingResults
        anchors.right: parent.right
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        text: "󰅖"
        color: root.fg
        opacity: clearMouse.containsMouse ? 1 : 0.5
        font.family: root.fontFamily; font.pixelSize: Style.font.body
        MouseArea {
          id: clearMouse
          anchors.fill: parent
          anchors.margins: -Style.space(6)
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: { root.clearResults(); searchField.forceActiveFocus() }
        }
      }
    }
    Button {
      id: findButton
      text: root.searching ? "…" : (root.showSearchButton ? "" : "Find")
      iconText: "󰇧"
      enabled: !root.searching
      onClicked: root.search(searchField.text)
    }
    Button {
      id: msgSearchButton
      visible: root.showSearchButton
      iconText: "󰍉"
      text: ""
      onClicked: root.searchRequested()
    }
    Button {
      id: newRoomButton
      iconText: "󰐕"
      text: root.showSearchButton ? "" : "Room"
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
      implicitHeight: Math.max(resultsHeader.implicitHeight, backButton.implicitHeight)
      PanelSectionHeader {
        id: resultsHeader
        anchors.left: parent.left
        anchors.right: backButton.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: (root.resultsKind === "users" ? "People" : "Public rooms") + " · " + root.results.length + " for \"" + root.resultsQuery + "\""
      }
      Button {
        id: backButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        iconText: "󰅖"
        text: "Back to rooms"
        bordered: true
        onClicked: root.clearResults()
      }
    }

    Repeater {
      model: root.results
      delegate: Item {
        id: resultRow
        required property var modelData
        width: root.width
        implicitHeight: Math.max(Style.space(36), resultLabels.implicitHeight + Style.space(10))
        Rectangle { anchors.fill: parent; anchors.margins: -Style.space(4); radius: Style.space(6); color: resultMouse.containsMouse ? root.hover : "transparent" }
        MouseArea { id: resultMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }

        Column {
          id: resultLabels
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
              : ((resultRow.modelData.alias || resultRow.modelData.id) + " · " + resultRow.modelData.members + " members" + (resultRow.modelData.topic ? " · " + Format.oneLine(resultRow.modelData.topic) : ""))
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
        implicitHeight: Math.max(Style.space(36), inviteLabels.implicitHeight + Style.space(10))

        Column {
          id: inviteLabels
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

  readonly property var shown: root.service ? root.service.visibleRooms : []
  readonly property var favouriteRooms: shown.filter(function(r) { return r.favourite === true })
  readonly property var directRooms: shown.filter(function(r) { return r.direct === true && r.favourite !== true })
  readonly property var groupRooms: shown.filter(function(r) { return r.direct !== true && r.favourite !== true })

  // A row in either section.
  component RoomRow: Item {
    id: row
    required property var modelData
    property bool direct: false
    width: root.width
    // Tall enough for name + topic at any font size; never clips the next row.
    implicitHeight: Math.max(Style.space(38), labels.implicitHeight + Style.space(12))

    readonly property int unread: Number(modelData.unread) || 0
    readonly property bool selected: modelData.id === root.currentRoom

    Rectangle {
      anchors.fill: parent
      radius: Style.space(6)
      color: row.selected ? root.selection : (rowMouse.containsMouse ? root.hover : "transparent")
    }
    Row {
      anchors.fill: parent
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(10)

      Item {
        width: Style.space(30)
        height: parent.height
        Avatar {
          anchors.centerIn: parent
          size: Style.space(30)
          userId: row.modelData.id
          name: row.modelData.name
          mxc: row.modelData.avatar || ""
          service: root.service
          fontFamily: root.fontFamily
        }
        // Encryption badge on the avatar's corner
        Rectangle {
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.rightMargin: -2
          anchors.bottomMargin: Style.space(2)
          width: Style.space(13); height: width
          radius: width / 2
          color: root.service ? root.service.sidebarBg : Color.background
          Text {
            anchors.centerIn: parent
            text: row.modelData.encrypted ? "󰌾" : "󰌿"
            color: row.modelData.encrypted ? root.accent : Color.urgent
            font.family: root.fontFamily; font.pixelSize: Style.space(9)
          }
        }
      }
      Column {
        id: labels
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - Style.space(30) - Style.space(10) - (badge.visible ? badge.width + Style.space(10) : 0) - (star.visible ? star.implicitWidth + Style.space(10) : 0)
        spacing: Style.space(1)
        Row {
          width: parent.width
          spacing: Style.space(6)
          Text {
            width: parent.width - (muteGlyph.visible ? muteGlyph.implicitWidth + Style.space(6) : 0)
            text: row.modelData.name
            color: row.selected ? Color.menu.selectedText : root.fg
            opacity: row.modelData.notification_mode === "mute" ? 0.6 : 1
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: row.unread > 0 && row.modelData.notification_mode !== "mute"
            elide: Text.ElideRight
          }
          Text {
            id: muteGlyph
            visible: row.modelData.notification_mode === "mute"
            text: "󰂛"
            color: root.fg; opacity: 0.45
            font.family: root.fontFamily; font.pixelSize: Style.font.caption
          }
        }
        Text {
          // An unsent draft takes the subtitle's place so it is not forgotten.
          readonly property string draft: root.service ? root.service.draft(row.modelData.id) : ""
          visible: draft !== "" || (!row.direct && !!row.modelData.topic)
          width: parent.width
          text: draft !== "" ? "󰏫 " + Format.oneLine(draft) : Format.oneLine(row.modelData.topic)
          color: draft !== "" ? (root.service ? root.service.accent : Color.accent) : root.fg
          opacity: draft !== "" ? 0.85 : 0.45
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
      Text {
        id: star
        anchors.verticalCenter: parent.verticalCenter
        visible: rowMouse.containsMouse || row.modelData.favourite === true
        text: row.modelData.favourite === true ? "󰓎" : "󰓒"
        color: row.modelData.favourite === true ? root.accent : root.fg
        opacity: row.modelData.favourite === true ? 1 : 0.4
        font.family: root.fontFamily; font.pixelSize: Style.font.caption
        MouseArea {
          anchors.fill: parent
          anchors.margins: -Style.space(4)
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.service.setFavourite(row.modelData.id, row.modelData.favourite !== true)
        }
      }
      Rectangle {
        id: badge
        anchors.verticalCenter: parent.verticalCenter
        visible: row.unread > 0
        width: Math.max(badgeText.implicitWidth + Style.space(10), Style.space(20))
        height: Style.space(18)
        radius: height / 2
        color: (Number(row.modelData.highlights) || 0) > 0 ? Color.urgent : root.accent
        Text {
          id: badgeText
          anchors.centerIn: parent
          text: row.unread > 99 ? "99+" : String(row.unread)
          color: Color.background
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
    }
    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.roomChosen(row.modelData)
    }
  }

  // Spaces: chips that filter the list
  Flow {
    width: parent.width
    spacing: Style.space(6)
    visible: !root.showingResults && root.service && root.service.spaces.length > 0
    component SpaceChip: Rectangle {
      property string spaceId: ""
      property string label: ""
      property string mxc: ""
      readonly property bool active: root.service && root.service.currentSpace === spaceId
      width: chipRow.implicitWidth + Style.space(16)
      height: Style.space(28)
      radius: height / 2
      color: active ? Util.alpha(root.accent, 0.18) : (chipMouse.containsMouse ? root.hover : Util.alpha(root.fg, 0.06))
      border.width: 1
      border.color: active ? root.accent : Util.alpha(root.fg, 0.15)
      Row {
        id: chipRow
        anchors.centerIn: parent
        spacing: Style.space(6)
        Avatar {
          visible: mxc !== "" || spaceId !== ""
          anchors.verticalCenter: parent.verticalCenter
          size: Style.space(18)
          userId: spaceId
          name: label
          mxc: parent.parent.mxc
          service: root.service
          fontFamily: root.fontFamily
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: label
          color: active ? root.accent : root.fg
          font.family: root.fontFamily; font.pixelSize: Style.font.caption
          font.bold: active
        }
      }
      MouseArea { id: chipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.service.currentSpace = spaceId }
    }
    SpaceChip { spaceId: ""; label: "All" }
    Repeater {
      model: root.service ? root.service.spaces : []
      delegate: SpaceChip { required property var modelData; spaceId: modelData.id; label: modelData.name; mxc: modelData.avatar || "" }
    }
  }

  // Favourites
  Column {
    width: parent.width
    spacing: Style.space(2)
    visible: !root.showingResults && root.favouriteRooms.length > 0
    PanelSectionHeader { text: "Favourites" }
    Repeater {
      model: root.favouriteRooms
      delegate: RoomRow { direct: modelData.direct === true }
    }
  }

  // Direct messages
  Column {
    width: parent.width
    spacing: Style.space(2)
    visible: !root.showingResults && root.directRooms.length > 0
    PanelSectionHeader { text: "Direct messages" }
    Repeater {
      model: root.directRooms
      delegate: RoomRow { direct: true }
    }
  }

  // Rooms
  Column {
    width: parent.width
    spacing: Style.space(2)
    visible: !root.showingResults

    PanelSectionHeader { text: "Rooms"; visible: root.groupRooms.length > 0 }

    Text {
      width: parent.width
      visible: root.shown.length === 0
      wrapMode: Text.WordWrap
      text: root.service && root.service.currentSpace !== "" ? "No rooms in this space yet."
        : root.service && root.service.status.syncing
        ? "No rooms yet. Search the directory above, join by #alias, or message someone by @user:server."
        : "Syncing…"
      color: root.fg
      opacity: 0.6
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Repeater {
      model: root.groupRooms
      delegate: RoomRow {}
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
