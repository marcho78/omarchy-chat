import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "shared/Format.js" as Format
import "shared/Palettes.js" as Palettes

// Yapper service: the single connection to omarchy-yapperd, the session state,
// the room and invitation lists, and desktop notifications. Mounted when
// the shell starts. The bar popup (Panel.qml) and the app window
// (Window.qml) are views over this object and never talk to the socket.
//
// The one secret that passes through here is the password on a password
// sign-in: straight to the socket (0600, peer-uid checked), never stored.
Item {
  id: root
  property var shell: null
  property var manifest: null

  readonly property string pluginId: "marcho78.yapper"
  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR")
  readonly property string socketPath: runtimeDir + "/omarchy-yapper.sock"
  readonly property string daemonRepo: "https://github.com/marcho78/omarchy-yapperd"
  readonly property string pluginRepo: "https://github.com/marcho78/omarchy-yapper"
  readonly property string daemonUnit: "omarchy-yapperd"
  // Shown to the user verbatim: clone, read, build, install. No binary download.
  readonly property string installCommand: "git clone " + daemonRepo + " && cd omarchy-yapperd && git checkout \"$(git tag -l 'v*' --sort=-v:refname | head -1)\" && cd packaging && makepkg -si"
  // Same thing for the terminal button, in a scratch dir so nothing is left
  // behind, building the newest release tag rather than whatever master is.
  readonly property string installScript: "d=$(mktemp -d) && git clone " + daemonRepo + " \"$d/omarchy-yapperd\" && cd \"$d/omarchy-yapperd\" && t=$(git tag -l 'v*' --sort=-v:refname | head -1) && git checkout -q \"$t\" && cd packaging && makepkg -si; cd; rm -rf \"$d\""
  // The update reuses the install, but pinned to the release tag the card
  // announced (`daemonLatest`), so the build is exactly that version even
  // if master has moved on; then it restarts the unit.
  readonly property string updateScript: "d=$(mktemp -d) && git clone " + daemonRepo + " \"$d/omarchy-yapperd\" && cd \"$d/omarchy-yapperd\" && git checkout -q \"v" + daemonLatest + "\" && cd packaging && makepkg -si && systemctl --user restart " + daemonUnit + "; cd; rm -rf \"$d\""
  readonly property string glyph: "󰭹"
  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, "")
  readonly property string pluginVersion: (manifest && manifest.version) ? String(manifest.version) : ""
  // Short commit of the installed plugin, for the About card.
  property string pluginCommit: ""
  Process {
    id: pluginRev
    property string out: ""
    command: ["/usr/bin/git", "-C", root.pluginDir, "log", "-1", "--format=%h %cs"]
    stdout: SplitParser { splitMarker: ""; onRead: function(d) { pluginRev.out += d } }
    onExited: function(code) { root.pluginCommit = code === 0 ? pluginRev.out.trim() : "" }
    running: true
  }

  function log(msg) { console.log("[yapper] " + msg) }

  // ---------- settings (bar layout entry over manifest defaults) ----------

  readonly property var defaults: (manifest && manifest.barWidget && manifest.barWidget.defaults) ? manifest.barWidget.defaults : ({})
  readonly property var layoutEntry: findLayoutEntry(shell ? shell.barConfig : null)

  function findLayoutEntry(cfg) {
    if (!cfg || !cfg.layout) return null
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var list = cfg.layout[sections[s]]
      if (!list) continue
      for (var i = 0; i < list.length; i++) if (list[i] && String(list[i].id) === pluginId) return list[i]
    }
    return null
  }
  // Values applied ahead of the shell.json round-trip (a slider mid-drag, a
  // change just written) so controls never snap back to the stored value.
  property var overrides: ({})
  onLayoutEntryChanged: {
    var e = layoutEntry, o = root.overrides, keep = {}, changed = false
    for (var k in o) { if (e && e[k] === o[k]) changed = true; else keep[k] = o[k] }
    if (changed) root.overrides = keep
  }
  function previewSetting(key, value) {
    var o = Object.assign({}, root.overrides); o[key] = value; root.overrides = o
  }
  function dropPreview(key) {
    if (root.overrides[key] === undefined) return
    var o = Object.assign({}, root.overrides); delete o[key]; root.overrides = o
  }
  function setting(key, fallback) {
    var o = root.overrides
    if (o[key] !== undefined) return o[key]
    var e = layoutEntry
    if (e && e[key] !== undefined && e[key] !== null) return e[key]
    if (defaults && defaults[key] !== undefined) return defaults[key]
    return fallback
  }
  function flag(key, fallback) {
    var v = setting(key, fallback)
    if (v === true || v === false) return v
    var s = String(v).toLowerCase()
    if (s === "false" || s === "0" || s === "off" || s === "no") return false
    if (s === "true" || s === "1" || s === "on" || s === "yes") return true
    return fallback
  }

  // ---------- appearance ----------
  // Each color follows the Omarchy theme until the user picks one; an
  // empty setting means "theme".
  function isHex(v) { return /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(String(v || "").trim()) }
  function pickColor(key, fallback) { var v = setting(key, ""); return isHex(v) ? Qt.color(String(v).trim()) : fallback }
  function isThemeColor(key) { return !isHex(setting(key, "")) }
  // Color.background is opaque; popups.background carries the theme's popup alpha.
  readonly property color bg: pickColor("backgroundColor", Color.background)
  readonly property color sidebarBg: pickColor("sidebarColor", bg)
  readonly property color fg: pickColor("textColor", Color.foreground)
  readonly property color accent: pickColor("accentColor", Color.accent)
  readonly property color selection: pickColor("selectionColor", Color.menu.selectedBackground)
  readonly property color hover: pickColor("hoverColor", Util.alpha(Color.menu.selectedBackground, 0.5))
  // Offered as swatches in the picker.
  readonly property var themeSwatches: [
    { label: "Theme background", color: Color.background },
    { label: "Theme foreground", color: Color.foreground },
    { label: "Theme accent", color: Color.accent },
    { label: "Theme muted", color: Color.muted },
    { label: "Theme urgent", color: Color.urgent }
  ]
  readonly property bool bubbles: String(setting("messageStyle", "flat")) === "bubbles"
  readonly property bool showAvatars: flag("showAvatars", true)
  readonly property bool senderColors: flag("senderColors", true)
  readonly property real voiceVolume: Math.max(0.2, Math.min(1, (Number(setting("voiceVolume", 100)) || 100) / 100))
  readonly property real fontScale: Math.max(0.8, Math.min(1.5, (Number(setting("fontScale", 100)) || 100) / 100))

  // ---------- palettes (the Yapper look) ----------
  // A palette is the shell's theme or one of the fixed sets in
  // shared/Palettes.js. The color settings above belong to the Omarchy
  // look; a palette is drawn as designed.
  // (Named `colors`, not `palette`: Item already has a palette.)
  // Palettes you saved: [{ id, label, light, v: { token: "#hex" } }].
  readonly property var customPalettes: {
    var v = setting("customPalettes", [])
    if (typeof v === "string") { try { v = JSON.parse(v) } catch (e) { v = [] } }
    return Array.isArray(v) ? v : []
  }
  function customPalette(key) {
    for (var i = 0; i < customPalettes.length; i++) if ("custom:" + customPalettes[i].id === key) return customPalettes[i]
    return null
  }
  // Every palette a picker can offer, built-ins first.
  readonly property var paletteKeys: Palettes.order.concat(customPalettes.map(function(p) { return "custom:" + p.id }))
  function paletteFor(key) {
    if (key === "omarchy") return Palettes.omarchy(Color.background, Color.foreground, Color.accent, Color.urgent)
    if (String(key).indexOf("custom:") === 0) return customPalette(key)
    return Palettes.themes[key] || null
  }
  readonly property string theme: {
    var t = String(setting("theme", "omarchy"))
    return paletteFor(t) ? t : "omarchy"
  }
  // The Yapper look's own color overrides, on top of the palette. Set
  // one and it changes that slot only; the Omarchy look has its own six.
  readonly property var yapperColorKeys: ["yapperBackgroundColor", "yapperSidebarColor", "yapperTextColor", "yapperAccent", "yapperHoverColor", "yapperSelectionColor"]
  readonly property var colors: {
    // A deleted palette can be gone before `theme` has fallen back.
    var base = paletteFor(theme) || paletteFor("omarchy")
    var v = {}
    for (var k in base.v) v[k] = Qt.color(base.v[k])
    v.sidebar = v.bg2
    var bg = setting("yapperBackgroundColor", ""), sb = setting("yapperSidebarColor", ""), fg = setting("yapperTextColor", "")
    var ac = setting("yapperAccent", ""), hv = setting("yapperHoverColor", ""), sl = setting("yapperSelectionColor", "")
    if (isHex(bg)) { v.bg = Qt.color(String(bg).trim()); v.desk = Qt.darker(v.bg, 1.4) }
    if (isHex(sb)) { v.bg2 = Qt.color(String(sb).trim()); v.sidebar = v.bg2 }
    if (isHex(fg)) { v.fg = Qt.color(String(fg).trim()); v.muted = Palettes.mix(v.bg, v.fg, 0.55); v.chip = Palettes.alpha(v.fg, 0.06) }
    if (isHex(ac)) {
      v.accent = Qt.color(String(ac).trim())
      v.hover = Qt.rgba(v.accent.r, v.accent.g, v.accent.b, 0.10)
      v.sel = Qt.rgba(v.accent.r, v.accent.g, v.accent.b, 0.18)
      v.own = Palettes.mix(v.bg, v.accent, 0.18)
    }
    if (isHex(hv)) v.hover = Qt.color(String(hv).trim())
    if (isHex(sl)) v.sel = Qt.color(String(sl).trim())
    v.light = Palettes.luminance(v.bg) > 0.5
    v.label = base.label
    return v
  }
  // Keep what is on screen as a palette of its own: the current tokens,
  // overrides included, under a name. It becomes the selected palette and
  // the override rows go back to "follows the palette".
  function savePalette(name) {
    var label = String(name || "").trim()
    if (label === "") return null
    var id = label.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") || "palette"
    var taken = customPalettes.map(function(p) { return p.id })
    var base = id, n = 2
    while (taken.indexOf(id) >= 0) id = base + "-" + (n++)
    var tokens = ["bg", "bg2", "surface", "line", "fg", "muted", "accent", "accent2", "ok", "warn", "bad", "desk", "own", "chip", "hover", "sel"]
    var v = {}
    for (var i = 0; i < tokens.length; i++) v[tokens[i]] = String(colors[tokens[i]])
    var changes = { customPalettes: customPalettes.concat([{ id: id, label: label, light: colors.light === true, v: v }]), theme: "custom:" + id }
    for (var j = 0; j < yapperColorKeys.length; j++) changes[yapperColorKeys[j]] = ""
    for (var key in changes) previewSetting(key, changes[key])
    writeSettings(changes)
    return id
  }
  function deletePalette(id) {
    var rest = customPalettes.filter(function(p) { return p.id !== id })
    if (rest.length === customPalettes.length) return false
    var changes = { customPalettes: rest }
    if (theme === "custom:" + id) changes.theme = "omarchy"
    for (var key in changes) previewSetting(key, changes[key])
    writeSettings(changes)
    return true
  }
  // Phosphor icon faces for the Yapper look, registered once for every view
  // (shared/Icon.qml names the families).
  FontLoader { source: Qt.resolvedUrl("fonts/Phosphor.ttf") }
  FontLoader { source: Qt.resolvedUrl("fonts/Phosphor-Bold.ttf") }
  FontLoader { source: Qt.resolvedUrl("fonts/Phosphor-Fill.ttf") }

  // The manifest schema drives the settings screen, so a new key needs only
  // a manifest entry.
  readonly property var schema: (manifest && manifest.barWidget && Array.isArray(manifest.barWidget.schema)) ? manifest.barWidget.schema : []

  // Persist settings through the shell's inline writer (what its own bar
  // gestures use); falls back to `omarchy bar set` per key.
  function writeSettings(changes) {
    var keys = Object.keys(changes || {})
    if (keys.length === 0) return
    if (shell && typeof shell.updateEntryInline === "function" && layoutEntry) {
      var merged = {}
      for (var k in layoutEntry) if (k !== "id") merged[k] = layoutEntry[k]
      for (var i = 0; i < keys.length; i++) merged[keys[i]] = changes[keys[i]]
      shell.updateEntryInline(pluginId, merged)
      return
    }
    for (var j = 0; j < keys.length; j++) {
      var v = changes[keys[j]]
      var argv = ["omarchy-bar-set", pluginId, keys[j], typeof v === "string" ? v : JSON.stringify(v)]
      if (typeof v !== "string") argv.push("--json")
      Quickshell.execDetached(argv)
    }
  }
  function set(key, value) { previewSetting(key, value); var c = ({}); c[key] = value; writeSettings(c) }

  readonly property string defaultHomeserver: String(setting("homeserver", "https://matrix.org"))
  readonly property bool notificationsEnabled: flag("notifications", true)
  readonly property bool autostartDaemon: flag("autostartDaemon", true)

  // ---------- state ----------

  property bool checked: false          // `which omarchy-yapperd` has answered once
  property bool installed: false
  property bool starting: false
  property bool connected: false
  property var status: ({ logged_in: false, syncing: false })
  property var rooms: []
  property var invites: []
  property var spaces: []
  // "" = all rooms; otherwise a space id whose children (recursively) are shown
  property string currentSpace: ""
  property int nextId: 1
  property var pending: ({})
  // viewId -> roomId for every view currently showing a room; used to
  // decide whether an incoming message deserves a notification.
  property var viewing: ({})

  readonly property bool loggedIn: connected && status.logged_in === true
  readonly property bool pendingLogin: connected && status.pending_login === true
  // A session is saved but could not be restored (keyring locked or gone).
  readonly property bool savedSession: connected && !loggedIn && status.saved_session === true
  readonly property string daemonError: connected && status.error ? String(status.error) : ""
  // Where the daemon keeps the session's secrets: "keyring", "file" or "".
  readonly property string secretsBackend: loggedIn && status.secrets ? String(status.secrets) : ""
  function retrySession(cb) { root.request("retry_session", {}, cb || function() {}) }
  function forgetSession(cb) { root.request("forget_session", {}, cb || function() {}) }
  readonly property string userId: (status && status.user_id) ? String(status.user_id) : ""
  readonly property int unreadTotal: {
    var n = 0
    for (var i = 0; i < rooms.length; i++) n += Number(rooms[i].unread) || 0
    return n
  }
  readonly property string stateText: !checked ? "Checking…"
    : !installed ? "omarchy-yapperd not installed"
    : !connected ? (starting ? "Starting daemon…" : "Daemon not running")
    : pendingLogin ? "Waiting for the browser…"
    : !loggedIn ? "Signed out"
    : status.syncing ? (userId || "Connected")
    : (status.error ? "Reconnecting…" : "Connecting…")

  // Views subscribe to these instead of polling.
  signal messageReceived(var message)
  signal invitationReceived(var invite)
  signal verificationEvent(var info)

  // ---------- verification ----------
  // {device_verified, cross_signing, recovery, backup, device_id, other_devices}
  property var verification: null
  // The flow currently on screen (one at a time), as the last event for it.
  property var activeFlow: null
  readonly property bool deviceVerified: verification ? verification.device_verified === true : false
  readonly property bool needsVerification: loggedIn && verification !== null && !deviceVerified

  function refreshVerification() {
    root.request("verification_status", {}, function(r) { if (r.ok) root.verification = r.result })
  }
  function verifyRequest(cb) { root.request("verify_request", {}, cb || function() {}) }
  function verifyAccept(flowId, cb) { root.request("verify_accept", { flow_id: flowId }, cb || function() {}) }
  function verifyConfirm(flowId, cb) { root.request("verify_confirm", { flow_id: flowId }, cb || function() {}) }
  function verifyCancel(flowId, cb) {
    root.request("verify_cancel", { flow_id: flowId }, cb || function() {})
    if (root.activeFlow && root.activeFlow.flow_id === flowId) root.activeFlow = null
  }
  function recover(key, cb) { root.request("recover", { key: key }, function(r) { if (r.ok) root.verification = r.result; cb(r) }) }
  function setupRecovery(cb) { root.request("setup_recovery", {}, function(r) { root.refreshVerification(); cb(r) }) }
  function resetRecoveryKey(cb) { root.request("reset_recovery_key", {}, function(r) { root.refreshVerification(); cb(r) }) }
  function dismissFlow() { root.activeFlow = null }

  // ---------- daemon discovery / start ----------

  function checkInstalled() { if (!whichProc.running) whichProc.running = true }

  Process {
    id: whichProc
    command: ["/usr/bin/which", "omarchy-yapperd"]
    onExited: function(code) {
      root.installed = (code === 0)
      root.checked = true
      if (root.installed) root.connectSocket()
    }
  }

  // Called by a view when it opens: make sure the daemon is up.
  function ensureDaemon() {
    if (!root.checked || !root.installed) { root.checkInstalled(); return }
    if (!root.connected) { root.connectSocket(); if (root.autostartDaemon) root.startDaemon() }
  }

  property string startError: ""
  function restartDaemon() { Quickshell.execDetached(["/usr/bin/systemctl", "--user", "restart", root.daemonUnit + ".service"]) }
  function startDaemon() {
    if (!root.installed || root.connected || startProc.running) return
    root.starting = true
    root.startError = ""
    startProc.running = true
  }

  Process {
    id: startProc
    command: ["/usr/bin/systemctl", "--user", "start", root.daemonUnit + ".service"]
    onExited: function(code) {
      if (code !== 0) {
        root.starting = false
        root.startError = "Could not start omarchy-yapperd (systemctl exited " + code + "). Try: systemctl --user start omarchy-yapperd"
      }
    }
  }

  Timer {
    interval: 15000
    running: root.starting
    onTriggered: {
      if (root.connected) return
      root.starting = false
      root.startError = "omarchy-yapperd started but its socket did not appear. Check: journalctl --user -u omarchy-yapperd"
    }
  }

  function openInstallTerminal() {
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", root.installScript])
  }

  // ---------- socket ----------

  // A Socket that has been connected and then dropped by the server makes
  // no further attempts however `connected` is toggled, so every attempt
  // gets a fresh object and the dead one is destroyed.
  property var sock: null

  function connectSocket() {
    if (!root.installed || root.connected) return
    if (root.sock) { root.sock.destroy(); root.sock = null }
    root.sock = sockComponent.createObject(root)
    root.sock.connected = true
  }

  Component {
    id: sockComponent
    Socket {
      path: root.socketPath
      parser: SplitParser { onRead: function(line) { root.onLine(line) } }
      onConnectionStateChanged: {
        if (this !== root.sock) return
        root.connected = connected
        if (connected) {
          root.starting = false
          root.startError = ""
        } else {
          root.failPending("daemon disconnected")
          root.rooms = []
          root.invites = []
          root.status = ({ logged_in: false, syncing: false })
          var dead = root.sock
          root.sock = null
          dead.destroy()
        }
      }
    }
  }

  // The socket does not reconnect by itself; poll while the daemon is absent.
  Timer {
    interval: 5000
    repeat: true
    running: root.installed && !root.connected
    onTriggered: root.connectSocket()
  }

  // A request that gets no reply — the socket dropped, or the daemon is
  // stuck — is failed back to its caller, so no button waits forever.
  readonly property int requestTimeoutMs: 60 * 1000
  function failPending(reason) {
    var p = root.pending
    root.pending = ({})
    for (var id in p) { try { p[id].cb({ ok: false, error: reason }) } catch (e) { root.log("callback: " + e) } }
  }
  Timer {
    interval: 10 * 1000
    repeat: true
    running: root.connected
    onTriggered: {
      var now = Date.now(), p = root.pending, late = []
      for (var id in p) if (now - p[id].at > root.requestTimeoutMs) late.push(id)
      if (late.length === 0) return
      var keep = Object.assign({}, p)
      for (var i = 0; i < late.length; i++) delete keep[late[i]]
      root.pending = keep
      for (var j = 0; j < late.length; j++) { try { p[late[j]].cb({ ok: false, error: "no reply from the daemon" }) } catch (e) { root.log("callback: " + e) } }
    }
  }

  function request(cmd, fields, cb) {
    if (!root.sock || !root.sock.connected) { if (cb) cb({ ok: false, error: "daemon not connected" }); return }
    var id = root.nextId++
    var obj = fields || {}
    obj.id = id
    obj.cmd = cmd
    if (cb) { var p = root.pending; p[id] = { cb: cb, at: Date.now() }; root.pending = p }
    root.sock.write(JSON.stringify(obj) + "\n")
  }

  function onLine(line) {
    var s = String(line).trim()
    if (s === "") return
    var msg
    try { msg = JSON.parse(s) } catch (e) { log("bad line from daemon: " + s.slice(0, 200)); return }
    if (msg.event !== undefined) { root.onEvent(msg); return }
    var entry = root.pending[msg.id]
    if (entry) {
      var p = root.pending; delete p[msg.id]; root.pending = p
      entry.cb(msg)
    }
  }

  function onEvent(ev) {
    if (ev.event === "state") {
      var wasLoggedIn = root.loggedIn
      root.status = ev
      if (root.loggedIn && (!wasLoggedIn || ev.syncing)) root.refresh()
      if (!root.loggedIn) { root.rooms = []; root.invites = []; root.verification = null; root.activeFlow = null }
    } else if (ev.event === "message_edited") {
      root.messageEdited(ev)
    } else if (ev.event === "reaction") {
      root.reactionReceived(ev)
    } else if (ev.event === "redacted") {
      root.redacted(ev)
    } else if (ev.event === "typing") {
      root.typingChanged(ev)
    } else if (ev.event === "receipt") {
      root.receiptMoved(ev)
    } else if (ev.event === "message") {
      root.messageReceived(ev)
      if (!root.isViewed(ev.room)) {
        root.refreshRooms()
        // The daemon reports what the account's push rules decided (mute,
        // mentions-only, keywords). Without a verdict, fall back to the
        // room's mode.
        var wants = ev.notify !== undefined ? ev.notify === true : ((root.roomById(ev.room) || {}).notification_mode || "all") === "all"
        if (root.notificationsEnabled && ev.sender !== root.userId && wants) root.notify(ev)
      }
    } else if (ev.event === "invite") {
      root.refreshInvites()
      root.invitationReceived(ev)
      if (root.notificationsEnabled)
        Quickshell.execDetached(["omarchy-notification-send", "--app-name", "Yapper", "-g", root.glyph,
          "Invitation from " + (ev.inviter_name || ev.inviter || "someone"), ev.direct ? "wants to chat with you" : String(ev.name),
          "--exec", "omarchy-shell", "shell", "summon", root.pluginId, "{}"])
    } else if (ev.event === "rooms_changed") {
      root.refresh()
    } else if (ev.event === "verification") {
      // Keep the newest state per flow; a finished flow lingers so the
      // view can show "done" / "cancelled" until dismissed.
      if (!root.activeFlow || root.activeFlow.flow_id === ev.flow_id || ev.state === "requested") root.activeFlow = ev
      root.verificationEvent(ev)
      if (ev.state === "requested" && !ev.outgoing && root.notificationsEnabled)
        Quickshell.execDetached(["omarchy-notification-send", "--app-name", "Yapper", "-g", "󰌾", "-u", "critical",
          "Verification request", "Another device wants to verify with this one.",
          "--exec", "omarchy-shell", "shell", "summon", root.pluginId, "{}"])
    } else if (ev.event === "verification_status_changed") {
      root.refreshVerification()
    }
  }

  // ---------- session ----------

  function login(homeserver, username, password, cb) {
    homeserver = String(homeserver).trim()
    username = String(username).trim()
    if (homeserver === "" || username === "" || password === "") { cb({ ok: false, error: "Homeserver, username and password are all required." }); return }
    root.request("login", { homeserver: homeserver, username: username, password: password }, function(r) {
      if (r.ok) { root.status = r.result; root.refresh() }
      cb(r)
    })
    password = ""
  }

  function loginOauth(homeserver, cb) {
    homeserver = String(homeserver).trim()
    if (homeserver === "") { cb({ ok: false, error: "Enter a homeserver." }); return }
    root.request("login_oauth", { homeserver: homeserver }, function(r) {
      if (r.ok) Quickshell.execDetached(["omarchy-launch-browser", String(r.result.url)])
      cb(r)
    })
  }

  function loginCancel(cb) { root.request("login_cancel", {}, cb || function() {}) }

  function logout(cb) {
    root.request("logout", {}, function(r) {
      root.rooms = []
      root.invites = []
      if (cb) cb(r)
    })
  }

  // ---------- rooms / invites ----------

  function refresh() { root.refreshRooms(); root.refreshInvites(); root.refreshSpaces(); root.refreshVerification() }
  function refreshSpaces() { root.request("spaces", {}, function(r) { if (r.ok) root.spaces = r.result }) }
  function setFavourite(roomId, on, cb) { root.request("set_favourite", { room: roomId, favourite: on === true }, function(r) { root.refreshRooms(); if (cb) cb(r) }) }

  // Rooms inside a space, including sub-spaces' rooms.
  function roomsInSpace(spaceId) {
    var set = ({}), queue = [spaceId], seen = ({})
    while (queue.length) {
      var id = queue.shift()
      if (seen[id]) continue
      seen[id] = true
      for (var i = 0; i < root.spaces.length; i++) {
        if (root.spaces[i].id !== id) continue
        var ch = root.spaces[i].children
        for (var j = 0; j < ch.length; j++) { set[ch[j]] = true; queue.push(ch[j]) }
      }
    }
    return set
  }
  // The rooms the sidebar should show, filtered by space and sorted by setting.
  readonly property var visibleRooms: {
    var list = root.rooms.slice()
    if (root.currentSpace !== "") { var inSpace = root.roomsInSpace(root.currentSpace); list = list.filter(function(r) { return inSpace[r.id] === true }) }
    if (root.roomSort === "name") list.sort(function(a, b) { return a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1 })
    else list.sort(function(a, b) {
      var ua = a.notification_mode === "mute" ? 0 : (Number(a.unread) || 0), ub = b.notification_mode === "mute" ? 0 : (Number(b.unread) || 0)
      if ((ua > 0) !== (ub > 0)) return ua > 0 ? -1 : 1
      var ta = Number(a.last_activity) || 0, tb = Number(b.last_activity) || 0
      if (ta !== tb) return tb - ta
      return a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1
    })
    return list
  }
  function refreshRooms() {
    // Membership changes can be the community coming or going.
    if (root.loggedIn && (root.community === null || root.community.joined !== true)) root.refreshCommunity()
    root.request("rooms", {}, function(r) { if (r.ok) root.rooms = r.result })
  }
  function refreshInvites() { root.request("invites", {}, function(r) { if (r.ok) root.invites = r.result }) }

  function roomById(id) {
    for (var i = 0; i < root.rooms.length; i++) if (root.rooms[i].id === id) return root.rooms[i]
    return null
  }
  function roomName(id) { var r = roomById(id); return r ? r.name : id }

  // Pages backwards: `before` is the previous page's `next`. Accepts both
  // the paged shape and the older plain array from a pre-0.4 daemon.
  function timeline(roomId, limit, before, cb) {
    if (typeof before === "function") { cb = before; before = "" }
    root.request("timeline", { room: roomId, limit: limit || 60, before: before || null }, function(r) {
      if (r.ok && Array.isArray(r.result)) r.result = { messages: r.result, next: null }
      cb(r)
    })
  }
  function send(roomId, body, replyTo, cb) {
    if (typeof replyTo === "function") { cb = replyTo; replyTo = "" }
    root.request("send", { room: roomId, body: String(body), reply_to: replyTo || null }, cb)
  }
  // A message into the thread under `rootId`; `replyTo` makes it a reply within it.
  function sendInThread(roomId, rootId, body, replyTo, cb) {
    root.request("send", { room: roomId, body: String(body), reply_to: replyTo || null, thread: rootId }, cb)
  }
  // A thread's page: the root first (on the last page), then replies oldest first.
  function thread(roomId, rootId, limit, before, cb) {
    root.request("thread", { room: roomId, root: rootId, limit: limit || 60, before: before || null }, cb)
  }
  function edit(roomId, eventId, body, cb) { root.request("edit", { room: roomId, event_id: eventId, body: String(body) }, cb) }
  function deleteMessage(roomId, eventId, cb) { root.request("delete", { room: roomId, event_id: eventId }, cb) }
  function react(roomId, eventId, key, cb) { root.request("react", { room: roomId, event_id: eventId, key: key }, cb) }
  function unreact(roomId, reactionId, cb) { root.request("unreact", { room: roomId, reaction_id: reactionId }, cb) }
  function typing(roomId, on) { root.request("typing", { room: roomId, typing: on === true }) }
  signal messageEdited(var edit)
  signal reactionReceived(var reaction)
  signal redacted(var info)
  signal typingChanged(var info)
  signal receiptMoved(var info)
  function markRead(roomId, eventId, cb) {
    if (!roomId || !eventId) return
    root.request("mark_read", { room: roomId, event_id: eventId }, function(r) { root.refreshRooms(); if (cb) cb(r) })
  }
  // A thread read up to `eventId`: a threaded receipt; the room view is
  // told so the root's chip drops its "new" count.
  signal threadRead(string roomId, string rootId)
  function markThreadRead(roomId, rootId, eventId) {
    if (!roomId || !rootId || !eventId) return
    root.request("mark_read", { room: roomId, event_id: eventId, thread: rootId }, function(r) { if (r.ok) root.threadRead(roomId, rootId) })
  }

  // Avatars: mxc:// URL -> local path, resolved once and shared by every
  // view. Reassigning the map is what makes bindings notice.
  property var avatars: ({})
  property var avatarPending: ({})
  // `size` picks a larger thumbnail (keyed separately) for preview images.
  function resolveAvatar(mxc, size) {
    var key = size ? mxc + "@" + size : mxc
    if (!mxc || root.avatars[key] !== undefined || root.avatarPending[key]) return
    var p = root.avatarPending; p[key] = true; root.avatarPending = p
    root.request("avatar", size ? { url: mxc, size: size } : { url: mxc }, function(r) {
      // Assign a copy: re-assigning the same object does not notify bindings.
      var a = Object.assign({}, root.avatars); a[key] = r.ok ? r.result.path : ""; root.avatars = a
      var q = root.avatarPending; delete q[key]; root.avatarPending = q
    })
  }
  function roomDetails(roomId, cb) { root.request("room_details", { room: roomId }, cb) }
  // Link previews, cached per URL for the session.
  property var previews: ({})
  function preview(url, cb) {
    if (root.previews[url] !== undefined) { cb(root.previews[url]); return }
    root.request("preview", { url: url }, function(r) {
      var p = Object.assign({}, root.previews); p[url] = r.ok ? r.result : null; root.previews = p
      cb(p[url])
    })
  }

  // Emoji keywords from Omarchy's own table, loaded once.
  property var emojiTable: []
  Process {
    id: emojiLoad
    property string out: ""
    command: ["/usr/bin/cat", "/usr/share/omarchy/shell/plugins/emojis/emojis.json"]
    stdout: SplitParser { splitMarker: ""; onRead: function(d) { emojiLoad.out += d } }
    onExited: function(code) { if (code === 0) { try { root.emojiTable = JSON.parse(emojiLoad.out) } catch (e) { root.log("emoji table: " + e) } } }
    running: true
  }
  // Up to `max` emoji for a typed word: exact keyword, then keywords that
  // start with it, then ones that merely contain it. `k` is the keyword
  // that matched, so the hint explains why the emoji is offered.
  function emojiSuggestions(word, max) {
    var w = String(word).toLowerCase().replace(/-/g, "_")
    if (w.length < 2) return []
    var tiers = [[], [], []]
    for (var i = 0; i < root.emojiTable.length; i++) {
      var e = root.emojiTable[i]
      var keys = String(e.k).split(" ")
      var best = -1, matched = ""
      for (var j = 0; j < keys.length; j++) {
        var k = keys[j]
        var tier = k === w ? 0 : k.indexOf(w) === 0 ? 1 : k.indexOf(w) > 0 ? 2 : -1
        if (tier >= 0 && (best < 0 || tier < best)) { best = tier; matched = k }
        if (best === 0) break
      }
      if (best >= 0 && tiers[best].length < max) tiers[best].push({ e: e.e, k: matched })
      if (tiers[0].length >= max) break
    }
    return tiers[0].concat(tiers[1], tiers[2]).slice(0, max)
  }
  function openEmojiPicker() { Quickshell.execDetached(["omarchy-shell", "shell", "toggle", "omarchy.emojis"]) }

  function searchMessages(query, roomId, cb) { root.request("search", { query: String(query), room: roomId || null, limit: 60 }, cb) }
  function invite(roomId, userId, cb) { root.request("invite", { room: roomId, user: userId }, cb) }
  function kick(roomId, userId, reason, cb) { root.request("kick", { room: roomId, user: userId, reason: reason || null }, cb) }
  function ban(roomId, userId, reason, cb) { root.request("ban", { room: roomId, user: userId, reason: reason || null }, cb) }
  function setRoomName(roomId, name, cb) { root.request("set_name", { room: roomId, name: name }, function(r) { root.refreshRooms(); cb(r) }) }
  function setRoomTopic(roomId, topic, cb) { root.request("set_topic", { room: roomId, topic: topic }, function(r) { root.refreshRooms(); cb(r) }) }
  function setNotificationMode(roomId, mode, cb) { root.request("set_notification_mode", { room: roomId, mode: mode }, function(r) { root.refreshRooms(); cb(r) }) }
  function members(roomId, query, limit, cb) { root.request("members", { room: roomId, query: query || "", limit: limit || 200 }, cb) }

  // Attachments. The daemon fetches and decrypts into a cache and returns
  // a local path; thumbnails the same way.
  function download(roomId, eventId, thumbnail, cb) { root.request("download", { room: roomId, event_id: eventId, thumbnail: thumbnail === true }, cb) }
  function sendVoice(roomId, path, cb) { root.request("send_voice", { room: roomId, path: String(path) }, cb) }

  // ---------- the Omarchy community ----------
  readonly property string communityAlias: String(setting("communitySpace", "#omarchy-community:matrix.org"))
  readonly property bool communityPrompt: flag("communityPrompt", true)
  readonly property string dmPolicy: String(setting("dmPolicy", "anyone"))
  property var community: null          // last community_status result
  readonly property bool communityJoined: community !== null && community.joined === true
  property var blocked: []
  property string themeName: ""
  function refreshCommunity(cb) {
    if (!root.loggedIn) { if (cb) cb({ ok: false, error: "not signed in" }); return }
    root.request("community_status", { alias: root.communityAlias }, function(r) {
      if (r.ok) root.community = r.result
      if (cb) cb(r)
    })
  }
  function communityJoin(cb) {
    root.request("community_join", { alias: root.communityAlias }, function(r) {
      if (r.ok) { root.community = r.result; root.refreshRooms(); root.set("communityPrompt", false) }
      if (cb) cb(r)
    })
  }
  function communityLeave(cb) {
    root.request("community_leave", { alias: root.communityAlias }, function(r) {
      if (r.ok) { root.refreshRooms(); root.refreshCommunity() }
      if (cb) cb(r)
    })
  }
  function publishProfile(bio, openToDm, theme, cb) {
    root.request("publish_profile", { alias: root.communityAlias, bio: String(bio), open_to_dm: openToDm === true, theme: theme || null }, function(r) {
      if (r.ok) root.refreshCommunity()
      if (cb) cb(r)
    })
  }
  function clearProfile(cb) {
    root.request("clear_profile", { alias: root.communityAlias }, function(r) { if (r.ok) root.refreshCommunity(); if (cb) cb(r) })
  }
  function people(query, cb) { root.request("people", { alias: root.communityAlias, query: String(query || ""), limit: 200 }, cb) }
  function ignore(userId, cb) { root.request("ignore", { user: String(userId) }, function(r) { root.refreshBlocked(); if (cb) cb(r) }) }
  function unignore(userId, cb) { root.request("unignore", { user: String(userId) }, function(r) { root.refreshBlocked(); if (cb) cb(r) }) }
  function refreshBlocked() { root.request("ignored", {}, function(r) { if (r.ok) root.blocked = r.result }) }
  // The daemon enforces the policy even when the shell is closed; keep it told.
  function pushDmPolicy() { if (root.loggedIn) root.request("set_dm_policy", { policy: root.dmPolicy, community: root.communityAlias }, function() {}) }
  onDmPolicyChanged: pushDmPolicy()
  onLoggedInChanged: if (loggedIn) { pushDmPolicy(); refreshCommunity(); refreshBlocked() }
  Process {
    // The active Omarchy theme, offered on the card.
    id: themeRead
    command: ["/usr/bin/bash", "-c", "basename \"$(readlink -f ~/.config/omarchy/current/theme)\""]
    stdout: SplitParser { onRead: function(line) { root.themeName = String(line).trim() } }
    running: true
  }

  // ---------- audio devices ----------
  // PipeWire sources and sinks, by node name; "" means the system default.
  readonly property string voiceInput: String(setting("voiceInput", ""))
  readonly property string voiceOutput: String(setting("voiceOutput", ""))
  property var audioInputs: []    // [{ value: node name, label: description }]
  property var audioOutputs: []
  function refreshAudioDevices() { if (!deviceList.running) deviceList.running = true }
  Process {
    id: deviceList
    property string out: ""
    command: ["/usr/bin/bash", "-c", "pactl --format=json list sources; echo '@@'; pactl --format=json list sinks"]
    stdout: SplitParser { splitMarker: ""; onRead: function(d) { deviceList.out += d } }
    onStarted: out = ""
    onExited: function(code) {
      if (code !== 0) return
      var parts = deviceList.out.split("@@")
      function parse(text, dropMonitors) {
        var list = []
        try {
          var arr = JSON.parse(text)
          for (var i = 0; i < arr.length; i++) {
            var d = arr[i]
            if (dropMonitors && String(d.name).indexOf(".monitor") >= 0) continue
            list.push({ value: String(d.name), label: String(d.description || d.name) })
          }
        } catch (e) { root.log("audio devices: " + e) }
        return list
      }
      root.audioInputs = parse(parts[0] || "[]", true)
      root.audioOutputs = parse(parts[1] || "[]", false)
    }
  }

  // Record three seconds and play them back through the chosen output.
  property string audioTest: ""     // "" | "recording" | "playing"
  property int audioTestLeft: 0
  function testAudio() {
    if (root.recording || root.audioTest !== "") return
    root.recordPath = (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omarchy-yapper-test.wav"
    var cmd = ["/usr/bin/pw-record", "--format=s16", "--rate=48000", "--channels=1"]
    if (root.voiceInput !== "") cmd.push("--target=" + root.voiceInput)
    cmd.push(root.recordPath)
    testRecorder.command = cmd
    root.audioTest = "recording"
    root.audioTestLeft = 3
    testRecorder.running = true
  }
  Process {
    id: testRecorder
    onStarted: testTick.start()
    onExited: function() {
      testTick.stop()
      if (root.audioTest !== "recording") { root.audioTest = ""; return }
      root.audioTest = "playing"
      var cmd = ["/usr/bin/pw-play"]
      if (root.voiceOutput !== "") cmd.push("--target=" + root.voiceOutput)
      cmd.push(root.recordPath)
      testPlayer.command = cmd
      testPlayer.running = true
    }
  }
  Process {
    id: testPlayer
    onExited: function() { root.audioTest = ""; Quickshell.execDetached(["/usr/bin/rm", "-f", root.recordPath]) }
  }
  Timer {
    id: testTick
    interval: 1000
    repeat: true
    onTriggered: { root.audioTestLeft--; if (root.audioTestLeft <= 0) { testTick.stop(); testRecorder.signal(2) } }
  }

  // ---------- voice recording ----------
  // One recorder for the whole shell: pw-record writes 16-bit mono WAV to
  // the runtime dir, the daemon turns it into an Opus voice message.
  property bool recording: false
  property string recordingRoom: ""
  property int recordSeconds: 0
  property string recordPath: ""
  property bool recordSend: false
  readonly property int recordLimit: 5 * 60
  signal voiceSent(string roomId, bool ok, string error)
  function startRecording(roomId) {
    if (root.recording || !roomId) return
    root.recordPath = (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omarchy-yapper-voice-" + Date.now() + ".wav"
    root.recordingRoom = roomId
    root.recordSeconds = 0
    root.recordSend = false
    var cmd = ["/usr/bin/pw-record", "--format=s16", "--rate=48000", "--channels=1"]
    if (root.voiceInput !== "") cmd.push("--target=" + root.voiceInput)
    cmd.push(root.recordPath)
    recorder.command = cmd
    recorder.running = true
    root.recording = true
  }
  // Stop; with `send`, the file goes to the daemon once pw-record has closed it.
  function stopRecording(send) {
    if (!root.recording) return
    root.recordSend = send === true
    root.recording = false
    recorder.signal(2)
  }
  Process {
    id: recorder
    onExited: function(code, status) {
      recordTick.stop()
      var path = root.recordPath, room = root.recordingRoom, send = root.recordSend
      root.recording = false
      root.recordingRoom = ""
      root.recordPath = ""
      if (!send) { Quickshell.execDetached(["/usr/bin/rm", "-f", path]); return }
      root.sendVoice(room, path, function(r) { root.voiceSent(room, r.ok === true, r.ok ? "" : (r.error || "Could not send the voice message")) })
    }
    onStarted: recordTick.start()
  }
  Timer {
    id: recordTick
    interval: 1000
    repeat: true
    onTriggered: { root.recordSeconds++; if (root.recordSeconds >= root.recordLimit) root.stopRecording(true) }
  }

  function sendFile(roomId, path, caption, cb) { root.request("send_file", { room: roomId, path: String(path), caption: caption || null }, cb) }
  function openPath(path) { Quickshell.execDetached(["/usr/bin/xdg-open", String(path)]) }

  function searchRooms(query, cb) { root.request("search_rooms", { query: String(query) }, cb) }
  // A page of the public directory; `since` continues from the last page's `next`.
  function explore(since, cb) { root.request("explore", { query: "", limit: 30, since: since || null }, cb) }
  function searchUsers(query, cb) { root.request("search_users", { query: String(query) }, cb) }
  function join(idOrAlias, cb) { root.request("join", { room: String(idOrAlias) }, function(r) { root.refreshRooms(); cb(r) }) }
  // Unsent composer text per room, shared by the popup and the window for
  // the life of the shell session.
  property var drafts: ({})
  function draft(roomId) { return root.drafts[roomId] || "" }
  function setDraft(roomId, text) {
    if (!roomId) return
    if ((root.drafts[roomId] || "") === text) return
    var d = Object.assign({}, root.drafts)
    if (text) d[roomId] = text; else delete d[roomId]
    root.drafts = d
  }

  // Who made this, reachable from the sidebar and the About card.
  readonly property string developerName: "devsec_ai"
  readonly property string developerMatrix: "@devsec_ai:matrix.org"
  readonly property string developerX: "https://x.com/devsec_ai"
  property bool developerDmPending: false
  // You cannot DM yourself, so the developer's own account gets no Message button.
  readonly property bool canMessageDeveloper: loggedIn && userId !== developerMatrix && !developerDmPending
  // Open (or start) a DM with the developer and bring the window up in it.
  function messageDeveloper() {
    if (root.developerDmPending) return
    root.developerDmPending = true
    root.dm(root.developerMatrix, function(r) {
      root.developerDmPending = false
      if (!r.ok) { root.log("developer DM: " + (r.error || "failed")); return }
      Quickshell.execDetached(["omarchy-shell", "shell", "summon", root.pluginId, JSON.stringify({ room: r.result.id })])
    })
  }
  function openDeveloperX() { Quickshell.execDetached(["omarchy-launch-browser", root.developerX]) }

  function dm(userId, cb) { root.request("dm", { user: String(userId) }, function(r) { root.refreshRooms(); cb(r) }) }
  function createRoom(name, encrypted, priv, cb) {
    root.request("create_room", { name: String(name), encrypted: encrypted === true, private: priv === true }, function(r) { root.refreshRooms(); cb(r) })
  }
  function acceptInvite(roomId, cb) { root.request("accept_invite", { room: roomId }, function(r) { root.refresh(); cb(r) }) }
  function declineInvite(roomId, cb) { root.request("decline_invite", { room: roomId }, function(r) { root.refreshInvites(); if (cb) cb(r) }) }
  function leave(roomId, cb) { root.request("leave", { room: roomId }, function(r) { root.refreshRooms(); cb(r) }) }

  // ---------- views ----------

  function setViewing(viewId, roomId) {
    var v = ({})
    for (var k in root.viewing) v[k] = root.viewing[k]
    if (roomId) v[viewId] = roomId; else delete v[viewId]
    root.viewing = v
  }
  function isViewed(roomId) {
    for (var k in root.viewing) if (root.viewing[k] === roomId) return true
    return false
  }

  // Omarchy's notifier: themed, and clicking it opens the room in the window.
  function notify(m) {
    var room = root.roomName(m.room)
    var who = m.sender_name || m.sender
    var direct = (root.roomById(m.room) || {}).direct === true
    var title = direct ? who : who + " · " + room
    var body = m.attachment ? (m.attachment.kind === "image" ? "󰋩 Image" : "󰈔 " + m.attachment.name) : String(m.body).slice(0, 300)
    if (m.highlight === true) body = "󰀦 " + body
    Quickshell.execDetached(["omarchy-notification-send", "--app-name", "Yapper", "-g", root.glyph,
      "-u", m.highlight === true ? "critical" : "normal", title, body,
      "--exec", "omarchy-shell", "shell", "summon", root.pluginId, JSON.stringify({ room: m.room })])
  }

  function timeText(ts) {
    if (!ts) return ""
    return new Date(ts).toLocaleTimeString(Qt.locale(), "HH:mm")
  }

  // ---------- clipboard ----------

  Process {
    id: copyProc
    stdinEnabled: true
    command: ["/usr/bin/wl-copy"]
    onStarted: { copyProc.write(root._copyPayload); root._copyPayload = "" }
  }
  property string _copyPayload: ""
  function copyText(s) {
    if (copyProc.running) return
    root._copyPayload = String(s)
    copyProc.running = true
  }

  // ---------- updates ----------
  // Plugin: commits on the git remote we do not have. Daemon: newest v* tag
  // on its repo vs the version the running daemon reports. Checked on
  // startup and every six hours; nothing is installed without the user.

  readonly property string roomSort: String(setting("roomSort", "activity"))
  // Which look draws the window and popup: "omarchy" (the original) or
  // "yapper" (the designed one). Both share this service and RoomSession.
  readonly property string look: String(setting("look", "yapper")) === "omarchy" ? "omarchy" : "yapper"
  readonly property bool linkPreviews: flag("linkPreviews", true)
  readonly property bool checkUpdates: flag("checkUpdates", true)
  property bool checking: false
  property int pluginUpdateCount: 0
  property var pluginUpdateLog: []        // subjects of the incoming commits
  property string daemonLatest: ""
  property string lastChecked: ""
  property string updateError: ""
  readonly property string daemonVersion: (status && status.version) ? String(status.version) : ""
  readonly property bool daemonUpdateAvailable: daemonLatest !== "" && daemonVersion !== "" && Format.compareVersions(daemonLatest, daemonVersion) > 0
  readonly property bool pluginUpdateAvailable: pluginUpdateCount > 0
  readonly property bool updateAvailable: daemonUpdateAvailable || pluginUpdateAvailable

  function checkForUpdates() {
    if (root.checking) return
    root.checking = true
    root.updateError = ""
    pluginCheck.running = true
  }

  Process {
    id: pluginCheck
    property string out: ""
    // Fetch, then list what we are behind by. A non-git plugin dir (a dev
    // copy) simply reports nothing.
    command: ["/usr/bin/bash", "-c",
      "cd \"$0\" || exit 0; git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0; " +
      "GIT_TERMINAL_PROMPT=0 git fetch --quiet origin HEAD 2>/dev/null || { echo ERR fetch; exit 0; }; " +
      "git rev-list --count HEAD..FETCH_HEAD; git log --format=%s HEAD..FETCH_HEAD | head -8",
      root.pluginDir]
    stdout: SplitParser { splitMarker: ""; onRead: function(d) { pluginCheck.out += d } }
    onStarted: out = ""
    onExited: function() {
      var lines = pluginCheck.out.split("\n").filter(function(l) { return l.trim() !== "" })
      if (lines.length > 0 && lines[0].indexOf("ERR") === 0) {
        root.updateError = "Could not reach the plugin's git remote."
      } else if (lines.length > 0) {
        root.pluginUpdateCount = parseInt(lines[0], 10) || 0
        root.pluginUpdateLog = lines.slice(1)
      } else {
        root.pluginUpdateCount = 0
        root.pluginUpdateLog = []
      }
      daemonCheck.running = true
    }
  }

  Process {
    id: daemonCheck
    property string out: ""
    command: ["/usr/bin/bash", "-c",
      "GIT_TERMINAL_PROMPT=0 git ls-remote --tags --refs \"$0\" 'v*' 2>/dev/null | sed 's#.*/tags/##'",
      root.daemonRepo]
    stdout: SplitParser { splitMarker: ""; onRead: function(d) { daemonCheck.out += d } }
    onStarted: out = ""
    onExited: function(code) {
      var best = ""
      var tags = daemonCheck.out.split("\n")
      for (var i = 0; i < tags.length; i++) {
        var t = tags[i].trim()
        if (!/^v\d+\.\d+\.\d+$/.test(t)) continue
        if (best === "" || Format.compareVersions(t, best) > 0) best = t
      }
      if (best === "" && code !== 0) root.updateError = (root.updateError ? root.updateError + " " : "") + "Could not reach the daemon's repository."
      root.daemonLatest = best.replace(/^v/, "")
      root.lastChecked = new Date().toLocaleTimeString(Qt.locale(), "HH:mm")
      root.checking = false
    }
  }

  Timer {
    interval: 6 * 60 * 60 * 1000
    repeat: true
    running: root.checkUpdates
    triggeredOnStart: false
    onTriggered: root.checkForUpdates()
  }
  Timer {
    // First check shortly after the shell comes up, once the network is likely there.
    interval: 45 * 1000
    running: root.checkUpdates
    onTriggered: root.checkForUpdates()
  }

  // Both updates run in a floating terminal so the user sees the diff /
  // the build and answers the prompts themselves.
  function updatePlugin() {
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation",
      "omarchy plugin update " + root.pluginId + " && omarchy restart shell"])
  }
  function updateDaemon() {
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", root.updateScript])
  }

  // Open the app window, optionally straight onto something: a room,
  // settings, a section — anything the window's payload understands.
  function openWindow(payload) {
    if (root.shell && typeof root.shell.summon === "function") root.shell.summon(root.pluginId, payload ? JSON.stringify(payload) : "{}")
  }

  Component.onCompleted: checkInstalled()
}
