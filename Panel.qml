import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
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
      if (Palettes.order.indexOf(name) < 0) return "unknown palette: " + name + " (one of " + Palettes.order.join(", ") + ")"
      root.service.set("theme", name)
      return name
    }
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
