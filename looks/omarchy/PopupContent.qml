import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui
import "../../shared"
import "../../shared/Format.js" as Format

// The bar popup's body for the Omarchy look. The root Panel.qml owns the
// bar button, the popup frame and IPC; this is what goes inside.
Column {
  id: root
  width: parent ? parent.width : implicitWidth

  // Set by the host popup.
  property var service: null
  property var bar: null
  property bool opened: false
  signal closeRequested()

  readonly property bool loggedIn: service ? service.loggedIn : false
  readonly property string stateText: service ? service.stateText : "Starting…"
  readonly property string glyph: "󰭹"
  readonly property bool inRoom: roomView.roomId !== ""
  readonly property bool inThread: threadView.roomId !== ""
  property bool showSettings: false
  property bool showInfo: false
  property bool showPeople: false
  readonly property bool hasTextFocus: roomView.hasTextFocus || threadView.hasTextFocus || roomList.hasTextFocus || gate.hasTextFocus || settingsView.hasTextFocus || verifyView.hasTextFocus || infoView.hasTextFocus

  function openRoom(r) { roomView.open(r) }
  function backToList() { root.showInfo = false; threadView.close(); roomView.close() }
  function openThread(eventId) { if (roomView.room) { threadView.openThread(roomView.room, eventId); Qt.callLater(function() { threadView.focusComposer() }) } }
  function closeThread() { threadView.close(); roomView.focusComposer() }
  // Esc / close request: step back one level; false means "nothing to step back from".
  function handleClose() {
    if (root.showInfo) root.showInfo = false
    else if (root.showPeople) root.showPeople = false
    else if (root.showSettings) root.showSettings = false
    else if (root.inThread) root.closeThread()
    else if (root.inRoom) root.backToList()
    else return false
    return true
  }
  function focusDefault() {
    if (roomView.visible) roomView.focusComposer()
    else if (gate.visible) gate.focusFirst()
  }
  function clearSecrets() { gate.clearSecrets() }
  onOpenedChanged: {
    if (opened) Qt.callLater(root.focusDefault)
    else { gate.clearSecrets(); roomView.close(); root.showSettings = false }
  }
  spacing: Style.space(12)

  // Hero
  Item {
    width: parent.width
    implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, appButton.implicitHeight)

    Text {
      id: heroIcon
      text: (root.inRoom || root.showSettings || root.showInfo) ? "󰁍" : root.glyph
      color: root.loggedIn ? Color.accent : root.bar.foreground
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.display
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      MouseArea {
        anchors.fill: parent
        enabled: root.inRoom || root.showSettings || root.showInfo || root.showPeople
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: { if (root.showInfo) root.showInfo = false; else if (root.showPeople) root.showPeople = false; else if (root.showSettings) root.showSettings = false; else if (root.inThread) root.closeThread(); else root.backToList() }
      }
    }

    Column {
      id: heroLabels
      anchors.left: heroIcon.right
      anchors.leftMargin: Style.space(14)
      anchors.right: appButton.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Text {
        textFormat: Text.PlainText
        text: root.showPeople ? "󰀏  People" : root.inThread ? "󰻞  Thread" : root.inRoom ? roomView.roomName : "Yapper"
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
        elide: Text.ElideRight
        width: parent.width
      }
      Text {
        textFormat: Text.PlainText
        text: root.showInfo ? roomView.roomName
          : root.inThread ? roomView.roomName
          : root.showSettings ? "Applied as you change them"
          : root.inRoom && roomView.room && roomView.room.bridge ? Format.bridgeGlyph(roomView.room.bridge.protocol) + " via " + roomView.room.bridge.name + (roomView.encrypted ? " · encrypted to the bridge" : " · not encrypted")
          : root.inRoom ? (roomView.encrypted ? "󰌾 End-to-end encrypted" : "󰌿 Not encrypted")
          : root.stateText
        color: root.inRoom && !roomView.encrypted ? Color.urgent : root.bar.foreground
        opacity: 0.7
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        width: parent.width
      }
    }

    Row {
      id: appButton
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.spacing.controlGap
      Button {
        visible: root.inRoom && !root.showSettings
        iconText: "󰋽"
        text: ""
        bordered: root.showInfo
        onClicked: root.showInfo = !root.showInfo
      }
      Button {
        iconText: "󰒓"
        text: ""
        bordered: root.showSettings
        onClicked: root.showSettings = !root.showSettings
      }
      Button {
        iconText: "󰖲"
        text: "App"
        bordered: true
        onClicked: { if (root.service) root.service.openWindow(); root.closeRequested() }
      }
    }
  }

  PanelSeparator { width: parent.width }

  UpdateBanner {
    width: parent.width
    visible: (root.service ? root.service.updateAvailable : false) && !root.inRoom && !root.showSettings
    service: root.service
    fg: root.bar.foreground
    fontFamily: root.bar.fontFamily
  }

  VerificationView {
    id: verifyView
    width: parent.width
    visible: root.loggedIn && !root.inRoom && !root.showSettings && (root.service.needsVerification || root.service.activeFlow !== null || mode === "key")
    service: root.service
    fg: root.bar.foreground
    fontFamily: root.bar.fontFamily
    compact: true
  }

  SessionGate {
    id: gate
    width: parent.width
    service: root.service
    fg: root.bar.foreground
    fontFamily: root.bar.fontFamily
  }

  SettingsView {
    id: settingsView
    onPeopleRequested: { root.showSettings = false; root.showPeople = true; peopleView.reset() }
    width: parent.width
    visible: root.showSettings
    service: root.service
    fg: root.bar.foreground
    fontFamily: root.bar.fontFamily
  }

  CommunityCard {
    width: parent.width
    service: root.service
    fg: root.bar.foreground
    fontFamily: root.bar.fontFamily
    visible: service && service.loggedIn && !root.inRoom && !root.showSettings && !root.showPeople && service.communityPrompt && community && community.exists && !community.joined
  }

  RoomList {
    id: roomList
    width: parent.width
    visible: root.loggedIn && !root.inRoom && !root.showSettings && !root.showPeople
    service: root.service
    fg: root.bar.foreground
    fontFamily: root.bar.fontFamily
    showPeopleButton: true
    onRoomChosen: function(r) { root.openRoom(r) }
    onPeopleRequested: { root.showPeople = true; peopleView.reset() }
  }

  PeopleView {
    id: peopleView
    width: parent.width
    height: visible ? Style.space(480) : 0
    visible: root.loggedIn && root.showPeople && !root.showSettings
    compact: true
    service: root.service
    fg: root.bar.foreground
    fontFamily: root.bar.fontFamily
    onCloseRequested: root.showPeople = false
    onMessageRequested: function(id) { root.showPeople = false; roomList.openDm(id) }
  }

  RoomInfo {
    id: infoView
    width: parent.width
    height: visible ? Style.space(440) : 0
    visible: root.loggedIn && root.inRoom && root.showInfo && !root.showSettings
    compact: true
    service: root.service
    fg: root.bar.foreground
    fontFamily: root.bar.fontFamily
    roomId: (root.inRoom && root.showInfo) ? roomView.roomId : ""
    onCloseRequested: root.showInfo = false
    onMemberChosen: function(m) { root.showInfo = false; root.backToList(); roomList.openDm(m.id) }
    onLeftRoom: root.backToList()
  }

  RoomView {
    id: roomView
    width: parent.width
    height: visible ? implicitHeight : 0
    visible: root.loggedIn && root.inRoom && root.opened && !root.showSettings && !root.showInfo && !root.inThread
    service: root.service
    viewId: "popup"
    fg: root.bar.foreground
    fontFamily: root.bar.fontFamily
    onRoomLeft: root.backToList()
    onThreadRequested: function(id) { root.openThread(id) }
  }

  // A thread takes the room's place; the hero's back arrow returns.
  RoomView {
    id: threadView
    width: parent.width
    height: visible ? implicitHeight : 0
    visible: root.loggedIn && root.inThread && root.opened && !root.showSettings && !root.showInfo
    service: root.service
    viewId: "popup-thread"
    fg: root.bar.foreground
    fontFamily: root.bar.fontFamily
    showLeave: false
    onCloseRequested: root.closeThread()
  }

  PanelSeparator { width: parent.width; visible: root.loggedIn && !root.showSettings }

  // Footer: account + sign out
  Item {
    width: parent.width
    visible: root.loggedIn && !root.showSettings
    implicitHeight: Math.max(footerText.implicitHeight, signOut.implicitHeight)

    Text {
      textFormat: Text.PlainText
      id: footerText
      anchors.left: parent.left
      anchors.right: signOut.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      wrapMode: Text.WrapAnywhere
      text: root.service ? (root.service.userId + (root.service.status.syncing ? "" : " · " + (root.service.status.error || "not syncing"))) : ""
      color: root.bar.foreground
      opacity: 0.45
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.caption
    }
    Button {
      id: signOut
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: "Sign out"
      bordered: true
      onClicked: { root.backToList(); root.service.logout() }
    }
  }
}
