import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "shared"
import "shared/Palettes.js" as Palettes

// Yapper in the bar: the glyph with the unread count, and the popup under
// it. The popup's body comes from the chosen look (`looks/<look>/PopupContent.qml`);
// this file owns what every look shares — the bar button, the popup frame,
// keyboard handling and the IPC surface. Session and room state live in
// Service.qml, shared with the app window.
Panel {
  id: root
  moduleName: "marcho78.yapper"
  ipcTarget: "marcho78.yapper"
  manageIpc: false

  readonly property var service: (bar && bar.shell && typeof bar.shell.serviceFor === "function")
    ? bar.shell.serviceFor("marcho78.yapper") : null
  readonly property bool loggedIn: service ? service.loggedIn : false
  readonly property int unreadTotal: service ? service.unreadTotal : 0
  readonly property int mentionTotal: {
    var n = 0
    if (service) for (var i = 0; i < service.rooms.length; i++) n += Number(service.rooms[i].highlights) || 0
    return n
  }
  readonly property string stateText: service ? service.stateText : "Starting…"
  readonly property string glyph: "󰭹"
  readonly property string look: service ? service.look : "omarchy"
  // Set when the chosen look failed to load: the Omarchy look stands in.
  property string fallbackLook: ""
  onLookChanged: { if (fallbackLook !== "") fallbackLook = ""; else content.load() }
  onFallbackLookChanged: content.load()
  onBarChanged: if (bar && content.status === Loader.Null) content.load()
  readonly property var body: content.item

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function openRoom(r) { if (root.body) root.body.openRoom(r) }

  onOpenedChanged: {
    if (opened && service) { service.ensureDaemon(); if (service.loggedIn) service.refresh() }
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
    // The daemon, for scripts and tests: omarchy-shell marcho78.yapper installDaemon bin|source
    function installDaemon(kind: string): string {
      if (!root.service) return "no service"
      if (kind !== "bin" && kind !== "source") return "kind must be bin or source"
      root.service.installDaemon(kind)
      return "installing " + root.service.daemonPinVersion + " (" + kind + ") in a terminal"
    }
    function updateDaemon(kind: string): string {
      if (!root.service) return "no service"
      if (!root.service.daemonUpdateAvailable) return "no update"
      root.service.updateDaemon(kind === "source" ? "source" : "bin")
      return "installing " + root.service.daemonLatest + " in a terminal"
    }
    function stopDaemon(): string { if (!root.service) return "no service"; root.service.stopDaemon(); return "stopping" }
    function startDaemon(): string { if (!root.service) return "no service"; root.service.startDaemon(); return "starting" }
    function daemonStatus(): string {
      var s = root.service
      return JSON.stringify(s ? { package: s.daemonPackage, version: s.daemonPackageVersion, installed: s.installed, active: s.daemonActive, connected: s.connected, install: s.installState, pending: s.installPending, pin: s.daemonPinVersion, pinCommit: s.daemonPinCommit } : {})
    }
    // Open the popup on a room: omarchy-shell marcho78.yapper room '!id:server'
    function room(id: string): string {
      var r = root.service ? root.service.roomById(id) : null
      if (!r) return "unknown room"
      root.open()
      root.openRoom(r)
      return r.name
    }
    // Switch the look or the palette from the shell:
    //   omarchy-shell marcho78.yapper setLook yapper
    //   omarchy-shell marcho78.yapper setTheme latte
    function setLook(name: string): string {
      if (!root.service) return "no service"
      if (name !== "yapper" && name !== "omarchy") return "unknown look: " + name
      root.service.set("look", name)
      return name
    }
    function setTheme(name: string): string {
      if (!root.service) return "no service"
      if (root.service.paletteKeys.indexOf(name) < 0) return "unknown palette: " + name + " (one of " + root.service.paletteKeys.join(", ") + ")"
      root.service.set("theme", name)
      return name
    }
    // Keep the colors on screen as a palette: omarchy-shell marcho78.yapper savePalette "Night shift"
    function savePalette(name: string): string {
      if (!root.service) return "no service"
      var id = root.service.savePalette(name)
      return id ? "custom:" + id : "a name is needed"
    }
    function deletePalette(id: string): string {
      if (!root.service) return "no service"
      return root.service.deletePalette(String(id).replace(/^custom:/, "")) ? "deleted" : "unknown palette: " + id
    }
    function app(): void { if (root.service) root.service.openWindow() }
    // Open the window onto something: omarchy-shell marcho78.yapper show '{"settings":"daemon"}'
    function show(payload: string): string {
      if (!root.service) return "no service"
      var p = null
      try { p = JSON.parse(payload) } catch (e) { return "payload must be JSON" }
      root.service.openWindow(p)
      return "opened"
    }
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
    // The Omarchy look uses the bar's glyph font; the Yapper look draws
    // its own icon with a badge.
    text: root.look === "yapper" ? "" : (root.unreadTotal > 0 ? root.glyph + " " + root.unreadTotal : root.glyph) + (root.service && root.service.updateAvailable ? " 󰚰" : "") + (root.service && root.service.needsVerification ? " 󰀦" : "")
    iconComponent: root.look === "yapper" ? yapperGlyph : null
    dimmed: !root.loggedIn
    tooltipText: "Yapper: " + root.stateText + (root.unreadTotal > 0 ? " · " + root.unreadTotal + " unread" : "") + (root.service && root.service.updateAvailable ? " · update available" : "") + (root.service && root.service.needsVerification ? " · device not verified" : "")
    onPressed: function(b) {
      if (b === Qt.MiddleButton) { if (root.service) root.service.openWindow() }
      else root.toggle()
    }
  }

  Component {
    id: yapperGlyph
    Item {
      readonly property var c: root.service && root.service.colors ? root.service.colors : null
      readonly property bool mention: root.mentionTotal > 0
      Icon {
        anchors.centerIn: parent
        name: "chat-teardrop-text"
        weight: "fill"
        size: Math.round(parent.height * 0.82)
        color: !root.loggedIn ? (root.bar ? root.bar.barForeground : "#888888")
          : parent.mention ? parent.c.bad
          : root.unreadTotal > 0 ? parent.c.accent
          : root.service && root.service.needsVerification ? parent.c.warn
          : (root.bar ? root.bar.barForeground : "#888888")
      }
      // Unread count, red when a mention is waiting
      Rectangle {
        visible: root.unreadTotal > 0
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -Math.round(parent.width * 0.32)
        anchors.topMargin: -Math.round(parent.height * 0.22)
        width: Math.max(height, badgeText.implicitWidth + 6)
        height: Math.round(parent.height * 0.62)
        radius: height / 2
        color: parent.mention ? parent.c.bad : parent.c.accent
        Text {
          id: badgeText
          anchors.centerIn: parent
          text: root.unreadTotal > 99 ? "99+" : String(root.unreadTotal)
          color: parent.parent.c ? parent.parent.c.bg2 : "#000000"
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Math.round(parent.parent.height * 0.42)
          font.bold: true
        }
      }
      // An update is waiting
      Icon {
        visible: root.service && root.service.updateAvailable
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: -Math.round(parent.width * 0.3)
        anchors.bottomMargin: -Math.round(parent.height * 0.12)
        name: "arrow-circle-up"
        weight: "fill"
        size: Math.round(parent.height * 0.5)
        color: parent.c ? parent.c.warn : "#e0af68"
      }
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
    contentHeight: panel.fittedContentHeight(content.item ? content.item.implicitHeight : 0, Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: content.item ? content.item.hasTextFocus : false
      onCloseRequested: { if (!content.item || !content.item.handleClose()) root.close() }
      onTabRequested: function(direction) { root.switchPanel(direction) }

      // The look's body, created with its bindings already set. Swapping
      // looks recreates it; the service keeps the state.
      Loader {
        id: content
        width: parent.width
        function load() {
          // The host hands `bar` over after creating the panel; the body
          // reads it from its first frame, so wait for it.
          if (!root.bar) return
          var look = root.fallbackLook !== "" ? root.fallbackLook : root.look
          setSource("looks/" + look + "/PopupContent.qml", {
            service: Qt.binding(function() { return root.service }),
            bar: Qt.binding(function() { return root.bar }),
            opened: Qt.binding(function() { return root.opened })
          })
        }
        Component.onCompleted: load()
        onLoaded: item.closeRequested.connect(function() { root.close() })
        onStatusChanged: {
          if (status !== Loader.Error) return
          console.log("[yapper] popup body failed to load: " + source)
          // Deferred: the status changes while the source is being set.
          if (root.fallbackLook === "" && root.look !== "omarchy") Qt.callLater(function() { root.fallbackLook = "omarchy" })
        }
      }
    }
  }
}
