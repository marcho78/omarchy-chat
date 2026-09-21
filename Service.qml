import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

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
  // Shown to the user verbatim: clone, read, build, install. No binary download.
  readonly property string installCommand: "git clone " + daemonRepo + " && cd omarchy-yapperd/packaging && makepkg -si"
  // Same thing for the terminal button, in a scratch dir so nothing is left behind.
  readonly property string installScript: "d=$(mktemp -d) && git clone " + daemonRepo + " \"$d/omarchy-yapperd\" && cd \"$d/omarchy-yapperd/packaging\" && makepkg -si; cd; rm -rf \"$d\""
  readonly property string glyph: "󰭹"

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
    command: ["/usr/bin/systemctl", "--user", "start", "omarchy-yapperd.service"]
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

  // After a failed attempt Socket.connected still reports the requested
  // state, so reset it before asking again or nothing happens.
  function connectSocket() {
    if (!root.installed || root.connected) return
    sock.connected = false
    sock.connected = true
  }

  Socket {
    id: sock
    path: root.socketPath
    parser: SplitParser { onRead: function(line) { root.onLine(line) } }
    onConnectionStateChanged: {
      root.connected = sock.connected
      if (sock.connected) {
        root.starting = false
        root.startError = ""
      } else {
        root.pending = ({})
        root.rooms = []
        root.invites = []
        root.status = ({ logged_in: false, syncing: false })
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
    if (!sock.connected) { if (cb) cb({ ok: false, error: "daemon not connected" }); return }
    var id = root.nextId++
    var obj = fields || {}
    obj.id = id
    obj.cmd = cmd
    if (cb) { var p = root.pending; p[id] = cb; root.pending = p }
    sock.write(JSON.stringify(obj) + "\n")
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
      if (!root.loggedIn) { root.rooms = []; root.invites = [] }
    } else if (ev.event === "message") {
      root.messageReceived(ev)
      if (!root.isViewed(ev.room)) {
        root.refreshRooms()
        if (root.notificationsEnabled && ev.sender !== root.userId) root.notify(ev)
      }
    } else if (ev.event === "invite") {
      root.refreshInvites()
      root.invitationReceived(ev)
      if (root.notificationsEnabled)
        Quickshell.execDetached(["/usr/bin/notify-send", "-a", "Yapper", "-i", "dialog-information", "--",
          "Invitation from " + (ev.inviter_name || ev.inviter || "someone"), ev.direct ? "wants to chat with you" : String(ev.name)])
    } else if (ev.event === "rooms_changed") {
      root.refresh()
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

  function refresh() { root.refreshRooms(); root.refreshInvites() }
  function refreshRooms() { root.request("rooms", {}, function(r) { if (r.ok) root.rooms = r.result }) }
  function refreshInvites() { root.request("invites", {}, function(r) { if (r.ok) root.invites = r.result }) }

  function roomById(id) {
    for (var i = 0; i < root.rooms.length; i++) if (root.rooms[i].id === id) return root.rooms[i]
    return null
  }
  function roomName(id) { var r = roomById(id); return r ? r.name : id }

  function timeline(roomId, limit, cb) { root.request("timeline", { room: roomId, limit: limit || 60 }, cb) }
  function send(roomId, body, cb) { root.request("send", { room: roomId, body: String(body) }, cb) }
  function markRead(roomId, eventId, cb) {
    if (!roomId || !eventId) return
    root.request("mark_read", { room: roomId, event_id: eventId }, function(r) { root.refreshRooms(); if (cb) cb(r) })
  }

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

  function notify(m) {
    var title = (m.sender_name || m.sender) + " · " + root.roomName(m.room)
    var body = String(m.body).slice(0, 300)
    Quickshell.execDetached(["/usr/bin/notify-send", "-a", "Yapper", "-i", "dialog-information", "--", title, body])
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

  function openWindow() {
    if (root.shell && typeof root.shell.summon === "function") root.shell.summon(root.pluginId, "{}")
  }

  Component.onCompleted: checkInstalled()
}
