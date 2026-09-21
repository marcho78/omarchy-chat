import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Format.js" as Format

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
  function setting(key, fallback) {
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
  // Each colour follows the Omarchy theme until the user picks one; an
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
  readonly property real fontScale: Math.max(0.8, Math.min(1.5, (Number(setting("fontScale", 100)) || 100) / 100))

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
  function set(key, value) { var c = ({}); c[key] = value; writeSettings(c) }

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
          root.pending = ({})
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

  function request(cmd, fields, cb) {
    if (!root.sock || !root.sock.connected) { if (cb) cb({ ok: false, error: "daemon not connected" }); return }
    var id = root.nextId++
    var obj = fields || {}
    obj.id = id
    obj.cmd = cmd
    if (cb) { var p = root.pending; p[id] = cb; root.pending = p }
    root.sock.write(JSON.stringify(obj) + "\n")
  }

  function onLine(line) {
    var s = String(line).trim()
    if (s === "") return
    var msg
    try { msg = JSON.parse(s) } catch (e) { log("bad line from daemon: " + s.slice(0, 200)); return }
    if (msg.event !== undefined) { root.onEvent(msg); return }
    var cb = root.pending[msg.id]
    if (cb) {
      var p = root.pending; delete p[msg.id]; root.pending = p
      cb(msg)
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
  function refreshRooms() { root.request("rooms", {}, function(r) { if (r.ok) root.rooms = r.result }) }
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

  // Avatars: mxc:// URL -> local path, resolved once and shared by every
  // view. Reassigning the map is what makes bindings notice.
  property var avatars: ({})
  property var avatarPending: ({})
  function resolveAvatar(mxc) {
    if (!mxc || root.avatars[mxc] !== undefined || root.avatarPending[mxc]) return
    var p = root.avatarPending; p[mxc] = true; root.avatarPending = p
    root.request("avatar", { url: mxc }, function(r) {
      var a = root.avatars; a[mxc] = r.ok ? r.result.path : ""; root.avatars = a
      var q = root.avatarPending; delete q[mxc]; root.avatarPending = q
    })
  }
  function roomDetails(roomId, cb) { root.request("room_details", { room: roomId }, cb) }
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
  function sendFile(roomId, path, caption, cb) { root.request("send_file", { room: roomId, path: String(path), caption: caption || null }, cb) }
  function openPath(path) { Quickshell.execDetached(["/usr/bin/xdg-open", String(path)]) }

  function searchRooms(query, cb) { root.request("search_rooms", { query: String(query) }, cb) }
  function searchUsers(query, cb) { root.request("search_users", { query: String(query) }, cb) }
  function join(idOrAlias, cb) { root.request("join", { room: String(idOrAlias) }, function(r) { root.refreshRooms(); cb(r) }) }
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

  function openWindow() {
    if (root.shell && typeof root.shell.summon === "function") root.shell.summon(root.pluginId, "{}")
  }

  Component.onCompleted: checkInstalled()
}
