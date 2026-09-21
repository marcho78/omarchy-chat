import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Yapper: the bar widget and its popup. A view over Service.qml — the socket,
// session and room state live there and are shared with the app window.
Panel {
  id: root
  moduleName: "marcho78.yapper"
  ipcTarget: "marcho78.yapper"
  manageIpc: false

  readonly property var service: (bar && bar.shell && typeof bar.shell.serviceFor === "function")
    ? bar.shell.serviceFor("marcho78.yapper") : null
  readonly property bool loggedIn: service ? service.loggedIn : false
  readonly property int unreadTotal: service ? service.unreadTotal : 0
  readonly property string stateText: service ? service.stateText : "Starting…"
  readonly property string glyph: "󰭹"
  readonly property bool inRoom: roomView.roomId !== ""
  property bool showSettings: false
  property bool showInfo: false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function openRoom(r) { roomView.open(r) }
  function backToList() { root.showInfo = false; roomView.close() }

  onOpenedChanged: {
    if (opened) {
      if (service) { service.ensureDaemon(); if (service.loggedIn) service.refresh() }
      Qt.callLater(function() {
        if (roomView.visible) roomView.focusComposer()
        else if (gate.visible) gate.focusFirst()
      })
    } else {
      gate.clearSecrets()
      roomView.close()
      root.showSettings = false
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function status(): string {
      var s = root.service
      return JSON.stringify({
        installed: s ? s.installed : false, connected: s ? s.connected : false, loggedIn: root.loggedIn,
        userId: s ? (s.userId || null) : null, syncing: s ? s.status.syncing === true : false,
        unread: root.unreadTotal, rooms: s ? s.rooms.length : 0, invites: s ? s.invites.length : 0, opened: root.opened
      })
    }
    function refresh(): void { if (root.service) root.service.refresh() }
    function app(): void { if (root.service) root.service.openWindow() }
    function checkUpdates(): string {
      if (!root.service) return "no service"
      root.service.checkForUpdates()
      return "checking"
    }
    function updates(): string {
      var s = root.service
      return JSON.stringify(s ? { daemon: s.daemonVersion, daemonLatest: s.daemonLatest, daemonUpdate: s.daemonUpdateAvailable, pluginBehind: s.pluginUpdateCount, pluginUpdate: s.pluginUpdateAvailable, lastChecked: s.lastChecked, error: s.updateError, checking: s.checking } : {})
    }
  }

  // ---------- bar button ----------

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: (root.unreadTotal > 0 ? root.glyph + " " + root.unreadTotal : root.glyph) + (root.service && root.service.updateAvailable ? " 󰚰" : "") + (root.service && root.service.needsVerification ? " 󰀦" : "")
    dimmed: !root.loggedIn
    tooltipText: "Yapper: " + root.stateText + (root.unreadTotal > 0 ? " · " + root.unreadTotal + " unread" : "") + (root.service && root.service.updateAvailable ? " · update available" : "") + (root.service && root.service.needsVerification ? " · device not verified" : "")
    onPressed: function(b) {
      if (b === Qt.MiddleButton) { if (root.service) root.service.openWindow() }
      else root.toggle()
    }
  }

  // ---------- popup ----------

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: roomView.hasTextFocus || roomList.hasTextFocus || gate.hasTextFocus || settingsView.hasTextFocus || verifyView.hasTextFocus || infoView.hasTextFocus
      onCloseRequested: { if (root.showInfo) root.showInfo = false; else if (root.showSettings) root.showSettings = false; else if (root.inRoom) root.backToList(); else root.close() }
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: panelColumn
        width: parent.width
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
              enabled: root.inRoom || root.showSettings || root.showInfo
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: { if (root.showInfo) root.showInfo = false; else if (root.showSettings) root.showSettings = false; else root.backToList() }
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
              text: root.inRoom ? roomView.roomName : "Yapper"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }
            Text {
              text: root.showInfo ? roomView.roomName
                : root.showSettings ? "Applied as you change them"
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
              onClicked: { if (root.service) root.service.openWindow(); root.close() }
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
          width: parent.width
          visible: root.showSettings
          service: root.service
          fg: root.bar.foreground
          fontFamily: root.bar.fontFamily
        }

        RoomList {
          id: roomList
          width: parent.width
          visible: root.loggedIn && !root.inRoom && !root.showSettings
          service: root.service
          fg: root.bar.foreground
          fontFamily: root.bar.fontFamily
          onRoomChosen: function(r) { root.openRoom(r) }
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
        }

        RoomView {
          id: roomView
          width: parent.width
          height: visible ? implicitHeight : 0
          visible: root.loggedIn && root.inRoom && root.opened && !root.showSettings && !root.showInfo
          service: root.service
          viewId: "popup"
          fg: root.bar.foreground
          fontFamily: root.bar.fontFamily
          onRoomLeft: root.backToList()
        }

        PanelSeparator { width: parent.width; visible: root.loggedIn && !root.showSettings }

        // Footer: account + sign out
        Item {
          width: parent.width
          visible: root.loggedIn && !root.showSettings
          implicitHeight: Math.max(footerText.implicitHeight, signOut.implicitHeight)

          Text {
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
    }
  }
}
