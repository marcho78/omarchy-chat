import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Chat: end-to-end encrypted Matrix chat from the bar.
//
// All crypto and the session live in omarchy-chatd (Rust, matrix-rust-sdk),
// reached over $XDG_RUNTIME_DIR/omarchy-chat.sock. This file only renders
// what the daemon reports and forwards what the user types. The one secret
// that passes through here is the password at login: it goes straight to the
// socket (0600, peer-uid checked) and the field is cleared.
Panel {
  id: root
  moduleName: "marcho78.chat"
  ipcTarget: "marcho78.chat"
  manageIpc: false

  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR")
  readonly property string socketPath: runtimeDir + "/omarchy-chat.sock"
  readonly property string daemonRepo: "https://github.com/marcho78/omarchy-chatd"
  // Shown to the user verbatim: clone, read, build, install. No binary download.
  readonly property string installCommand: "git clone " + daemonRepo + " && cd omarchy-chatd/packaging && makepkg -si"
  // Same thing for the terminal button, in a scratch dir so nothing is left behind.
  readonly property string installScript: "d=$(mktemp -d) && git clone " + daemonRepo + " \"$d/omarchy-chatd\" && cd \"$d/omarchy-chatd/packaging\" && makepkg -si; cd; rm -rf \"$d\""

  readonly property string defaultHomeserver: String(setting("homeserver", "https://matrix.org"))
  readonly property bool notificationsEnabled: setting("notifications", true) !== false
  readonly property bool autostartDaemon: setting("autostartDaemon", true) !== false

  // ---------- state ----------

  property bool checked: false          // `which omarchy-chatd` has answered once
  property bool installed: false
  property bool starting: false
  property bool connected: false
  property var status: ({ logged_in: false, syncing: false })
  property var rooms: []
  property var invites: []
  property var results: []          // directory search results
  property string resultsKind: ""   // "rooms" | "users"
  property bool searching: false
  property bool showNewRoom: false
  property string currentRoom: ""
  property string currentRoomName: ""
  property bool currentRoomEncrypted: false
  property bool busy: false
  property bool usePassword: false
  property string errorText: ""
  property int nextId: 1
  property var pending: ({})

  readonly property bool loggedIn: connected && status.logged_in === true
  readonly property bool pendingLogin: connected && status.pending_login === true
  readonly property int unreadTotal: {
    var n = 0
    for (var i = 0; i < rooms.length; i++) n += Number(rooms[i].unread) || 0
    return n
  }
  readonly property string glyph: "󰭹"
  readonly property string stateText: !checked ? "Checking…"
    : !installed ? "omarchy-chatd not installed"
    : !connected ? (starting ? "Starting daemon…" : "Daemon not running")
    : pendingLogin ? "Waiting for the browser…"
    : !loggedIn ? "Signed out"
    : status.syncing ? (status.user_id || "Connected")
    : (status.error ? "Reconnecting…" : "Connecting…")

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  ListModel { id: msgModel }

  // ---------- daemon discovery / start ----------

  function checkInstalled() {
    if (!whichProc.running) whichProc.running = true
  }

  Process {
    id: whichProc
    command: ["/usr/bin/which", "omarchy-chatd"]
    onExited: function(code) {
      root.installed = (code === 0)
      root.checked = true
      if (root.installed) root.connectSocket()
    }
  }

  function startDaemon() {
    if (!root.installed || root.connected || startProc.running) return
    root.starting = true
    startProc.running = true
  }

  Process {
    id: startProc
    command: ["/usr/bin/systemctl", "--user", "start", "omarchy-chatd.service"]
    onExited: function(code) {
      if (code !== 0) {
        root.starting = false
        root.errorText = "Could not start omarchy-chatd (systemctl exited " + code + "). Try: systemctl --user start omarchy-chatd"
      }
      // On success the reconnect timer picks the socket up.
    }
  }

  // Give up waiting for the socket if the unit started but never listened.
  Timer {
    interval: 15000
    running: root.starting
    onTriggered: {
      if (root.connected) return
      root.starting = false
      root.errorText = "omarchy-chatd started but its socket did not appear. Check: journalctl --user -u omarchy-chatd"
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
        root.errorText = ""
        // The daemon greets with a state event; rooms follow once logged in.
      } else {
        root.pending = ({})
        root.busy = false
        root.rooms = []
        root.status = ({ logged_in: false, syncing: false })
        if (root.autostartDaemon && root.opened) root.startDaemon()
      }
    }
  }

  // The socket does not reconnect by itself; poll while the daemon is absent.
  Timer {
    interval: root.opened ? 1500 : 10000
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
    try { msg = JSON.parse(s) } catch (e) { console.warn("[chat] bad line from daemon: " + s.slice(0, 200)); return }
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
      if (root.loggedIn && (!wasLoggedIn || ev.syncing)) { root.refreshRooms(); root.refreshInvites() }
      if (!root.loggedIn) { root.rooms = []; root.leaveRoomView() }
    } else if (ev.event === "message") {
      root.onMessage(ev)
    } else if (ev.event === "invite") {
      root.refreshInvites()
      if (root.notificationsEnabled && !root.opened)
        Quickshell.execDetached(["/usr/bin/notify-send", "-a", "Chat", "-i", "dialog-information", "--",
          "Invitation from " + (ev.inviter_name || ev.inviter || "someone"), ev.direct ? "wants to chat with you" : ev.name])
    } else if (ev.event === "rooms_changed") {
      root.refreshRooms()
      root.refreshInvites()
      if (root.currentRoom !== "" && !root.rooms.some(function(r) { return r.id === root.currentRoom })) root.leaveRoomView()
    }
  }

  // ---------- session ----------

  function login(homeserver, username, password) {
    if (root.busy) return
    homeserver = String(homeserver).trim()
    username = String(username).trim()
    if (homeserver === "" || username === "" || password === "") { root.errorText = "Homeserver, username and password are all required."; return }
    root.busy = true
    root.errorText = ""
    root.request("login", { homeserver: homeserver, username: username, password: password }, function(r) {
      root.busy = false
      if (!r.ok) root.errorText = r.error || "Login failed"
      else { pwField.text = ""; root.status = r.result; root.refreshRooms() }
    })
    password = ""
  }

  function loginOauth(homeserver) {
    if (root.busy) return
    homeserver = String(homeserver).trim()
    if (homeserver === "") { root.errorText = "Enter a homeserver."; return }
    root.busy = true
    root.errorText = ""
    root.request("login_oauth", { homeserver: homeserver }, function(r) {
      root.busy = false
      if (!r.ok) { root.errorText = r.error || "Could not start browser sign-in"; return }
      Quickshell.execDetached(["omarchy-launch-browser", String(r.result.url)])
    })
  }

  function loginCancel() {
    root.request("login_cancel", {}, function(r) {
      if (!r.ok) root.errorText = r.error || "Could not cancel"
    })
  }

  function logout() {
    if (root.busy) return
    root.busy = true
    root.request("logout", {}, function(r) {
      root.busy = false
      if (!r.ok) root.errorText = r.error || "Logout failed"
      root.leaveRoomView()
      root.rooms = []
    })
  }

  // ---------- discovery ----------

  function refreshInvites() {
    root.request("invites", {}, function(r) { if (r.ok) root.invites = r.result })
  }

  function clearResults() { root.results = []; root.resultsKind = ""; searchField.text = "" }

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
      root.request("search_users", { query: text.substring(1) }, function(r) {
        root.searching = false
        if (!r.ok) { root.errorText = r.error || "Search failed"; return }
        root.results = r.result; root.resultsKind = "users"
        if (r.result.length === 0) root.errorText = "No one found for " + text
      })
      return
    }
    root.searching = true
    root.request("search_rooms", { query: text }, function(r) {
      root.searching = false
      if (!r.ok) { root.errorText = r.error || "Search failed"; return }
      root.results = r.result; root.resultsKind = "rooms"
      if (r.result.length === 0) root.errorText = "No public rooms match \"" + text + "\""
    })
  }

  function joinRoom(idOrAlias) {
    if (root.busy) return
    root.busy = true
    root.request("join", { room: idOrAlias }, function(r) {
      root.busy = false
      if (!r.ok) { root.errorText = r.error || "Could not join"; return }
      root.clearResults()
      root.refreshRooms()
      root.openRoom(r.result)
    })
  }

  function openDm(userId) {
    if (root.busy) return
    root.busy = true
    root.request("dm", { user: userId }, function(r) {
      root.busy = false
      if (!r.ok) { root.errorText = r.error || "Could not open chat"; return }
      root.clearResults()
      root.refreshRooms()
      root.openRoom(r.result)
    })
  }

  function createRoom(name, encrypted, priv) {
    if (root.busy) return
    root.busy = true
    root.request("create_room", { name: name, encrypted: encrypted, private: priv }, function(r) {
      root.busy = false
      if (!r.ok) { root.errorText = r.error || "Could not create room"; return }
      root.showNewRoom = false
      newRoomName.text = ""
      root.refreshRooms()
      root.openRoom(r.result)
    })
  }

  function acceptInvite(roomId) {
    root.request("accept_invite", { room: roomId }, function(r) {
      if (!r.ok) { root.errorText = r.error || "Could not accept"; return }
      root.refreshInvites(); root.refreshRooms()
      root.openRoom(r.result)
    })
  }

  function declineInvite(roomId) {
    root.request("decline_invite", { room: roomId }, function(r) {
      if (!r.ok) root.errorText = r.error || "Could not decline"
      root.refreshInvites()
    })
  }

  function leaveCurrentRoom() {
    if (!root.currentRoom || root.busy) return
    root.busy = true
    root.request("leave", { room: root.currentRoom }, function(r) {
      root.busy = false
      if (!r.ok) { root.errorText = r.error || "Could not leave"; return }
      root.leaveRoomView()
      root.refreshRooms()
    })
  }

  // ---------- rooms / timeline ----------

  function refreshRooms() {
    root.request("rooms", {}, function(r) {
      if (r.ok) root.rooms = r.result
    })
  }

  function openRoom(room) {
    root.currentRoom = room.id
    root.currentRoomName = room.name
    root.currentRoomEncrypted = room.encrypted === true
    msgModel.clear()
    root.request("timeline", { room: room.id, limit: 60 }, function(r) {
      if (!r.ok) { root.errorText = r.error || "Could not load messages"; return }
      if (r.result.length === 0) return
      for (var i = 0; i < r.result.length; i++) root.appendMessage(r.result[i])
      root.markRead(r.result[r.result.length - 1].event_id)
      Qt.callLater(function() { composer.forceActiveFocus() })
    })
  }

  function leaveRoomView() {
    root.currentRoom = ""
    root.currentRoomName = ""
    msgModel.clear()
  }

  function appendMessage(m) {
    msgModel.append({
      eventId: m.event_id,
      sender: m.sender,
      senderName: m.sender_name || m.sender,
      body: m.body,
      ts: Number(m.ts) || 0,
      mine: m.sender === root.status.user_id,
      encrypted: m.encrypted === true
    })
    Qt.callLater(function() { msgList.positionViewAtEnd() })
  }

  function markRead(eventId) {
    if (!root.currentRoom || !eventId) return
    root.request("mark_read", { room: root.currentRoom, event_id: eventId }, function() { root.refreshRooms() })
  }

  function send(text) {
    text = String(text)
    if (text.trim() === "" || !root.currentRoom || root.busy) return
    root.busy = true
    root.request("send", { room: root.currentRoom, body: text }, function(r) {
      root.busy = false
      if (!r.ok) root.errorText = r.error || "Send failed"
      else composer.text = ""
    })
  }

  function onMessage(m) {
    var viewing = root.opened && m.room === root.currentRoom
    if (viewing) {
      root.appendMessage(m)
      root.markRead(m.event_id)
    } else {
      root.refreshRooms()
      if (root.notificationsEnabled && m.sender !== root.status.user_id) root.notify(m)
    }
  }

  function roomName(id) {
    for (var i = 0; i < root.rooms.length; i++) if (root.rooms[i].id === id) return root.rooms[i].name
    return id
  }

  function notify(m) {
    var title = m.sender_name + " · " + root.roomName(m.room)
    var body = String(m.body).slice(0, 300)
    Quickshell.execDetached(["/usr/bin/notify-send", "-a", "Chat", "-i", "dialog-information", "--", title, body])
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

  // ---------- lifecycle ----------

  Component.onCompleted: checkInstalled()

  onOpenedChanged: {
    if (opened) {
      root.errorText = ""
      if (!root.installed) root.checkInstalled()
      else if (!root.connected) { root.connectSocket(); if (root.autostartDaemon) root.startDaemon() }
      else if (root.loggedIn) { root.refreshRooms(); root.refreshInvites() }
      Qt.callLater(function() {
        if (composer.visible) composer.forceActiveFocus()
        else if (userField.visible) userField.forceActiveFocus()
      })
    } else {
      pwField.text = ""
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function status(): string {
      return JSON.stringify({ installed: root.installed, connected: root.connected, loggedIn: root.loggedIn, userId: root.status.user_id || null, syncing: root.status.syncing === true, unread: root.unreadTotal, rooms: root.rooms.length, opened: root.opened })
    }
    function refresh(): void { root.refreshRooms() }
  }

  // ---------- bar button ----------

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.unreadTotal > 0 ? root.glyph + " " + root.unreadTotal : root.glyph
    dimmed: !root.loggedIn
    tooltipText: "Chat: " + root.stateText + (root.unreadTotal > 0 ? " · " + root.unreadTotal + " unread" : "")
    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.refreshRooms()
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
      blocked: composer.activeFocus || hsField.activeFocus || userField.activeFocus || pwField.activeFocus || searchField.activeFocus || newRoomName.activeFocus
      onCloseRequested: { if (root.currentRoom !== "") root.leaveRoomView(); else root.close() }
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: panelColumn
        width: parent.width
        spacing: Style.space(12)

        // Hero
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

          Text {
            id: heroIcon
            text: root.currentRoom !== "" ? "󰁍" : root.glyph
            color: root.loggedIn ? Color.accent : root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            MouseArea {
              anchors.fill: parent
              enabled: root.currentRoom !== ""
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: root.leaveRoomView()
            }
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: root.currentRoom !== "" ? root.currentRoomName : "Chat"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }
            Text {
              text: root.currentRoom !== ""
                ? (root.currentRoomEncrypted ? "󰌾 End-to-end encrypted" : "󰌿 Not encrypted")
                : root.stateText
              color: root.currentRoom !== "" && !root.currentRoomEncrypted ? Color.urgent : root.bar.foreground
              opacity: 0.7
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: parent.width
            }
          }
        }

        PanelSeparator { width: parent.width }

        // Daemon missing: show the command, never fetch a binary.
        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: root.checked && !root.installed

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Chat needs the omarchy-chatd daemon. It is built from source on your machine with makepkg — read the PKGBUILD first if you like. The first build takes a few minutes."
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
          }
          Text {
            width: parent.width
            wrapMode: Text.WrapAnywhere
            text: root.installCommand
            color: Color.accent
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
          }
          Row {
            spacing: Style.spacing.controlGap
            Button { text: "Copy command"; bordered: true; onClicked: root.copyText(root.installCommand) }
            Button { text: "Open in terminal"; iconText: "󰆍"; bordered: true; onClicked: root.openInstallTerminal() }
            Button { text: "Check again"; bordered: true; onClicked: root.checkInstalled() }
          }
        }

        // Installed but not running
        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: root.checked && root.installed && !root.connected

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.starting ? "Starting omarchy-chatd…" : "The daemon is installed but not running."
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
          }
          Button {
            text: root.starting ? "Starting…" : "Start daemon"
            iconText: "󰐊"
            bordered: true
            enabled: !root.starting
            onClicked: root.startDaemon()
          }
        }

        // Signed out: browser sign-in first, password as the fallback
        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: root.connected && !root.loggedIn && !root.pendingLogin

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.usePassword
              ? "The password goes only to the local daemon, which keeps an access token and never the password."
              : "Sign in with a Matrix account. Your browser opens on the homeserver's own sign-in page — Google, GitHub or a password there — and nothing but the resulting token reaches this machine."
            color: root.bar.foreground
            opacity: 0.85
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
          }
          TextField {
            id: hsField
            width: parent.width
            maximumLength: 256
            text: root.defaultHomeserver
            placeholderText: "Homeserver, e.g. matrix.org"
            enabled: !root.busy
            onAccepted: { if (root.usePassword) userField.forceActiveFocus(); else root.loginOauth(hsField.text) }
          }
          TextField {
            id: userField
            width: parent.width
            visible: root.usePassword
            maximumLength: 256
            placeholderText: "Username"
            enabled: !root.busy
            onAccepted: pwField.forceActiveFocus()
          }
          TextField {
            id: pwField
            width: parent.width
            visible: root.usePassword
            maximumLength: 1024
            password: true
            placeholderText: "Password"
            enabled: !root.busy
            onAccepted: root.login(hsField.text, userField.text, pwField.text)
          }
          Row {
            spacing: Style.spacing.controlGap
            Button {
              visible: !root.usePassword
              text: root.busy ? "Starting…" : "Sign in with browser"
              iconText: "󰖟"
              bordered: true
              enabled: !root.busy
              onClicked: root.loginOauth(hsField.text)
            }
            Button {
              visible: root.usePassword
              text: root.busy ? "Signing in…" : "Sign in"
              iconText: "󰍂"
              bordered: true
              enabled: !root.busy
              onClicked: root.login(hsField.text, userField.text, pwField.text)
            }
            Button {
              text: root.usePassword ? "Use the browser instead" : "Use a password instead"
              enabled: !root.busy
              onClicked: { root.usePassword = !root.usePassword; root.errorText = "" }
            }
          }
        }

        // Browser sign-in in progress
        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: root.pendingLogin

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Finish signing in in your browser. This panel updates by itself when the homeserver sends you back."
            color: root.bar.foreground
            opacity: 0.85
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
          }
          Button {
            text: "Cancel"
            bordered: true
            onClicked: root.loginCancel()
          }
        }

        // Signed in: find / create / invites / rooms
        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: root.loggedIn && root.currentRoom === ""

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
              onAccepted: root.createRoom(newRoomName.text, encryptedToggle.checked, privateToggle.checked)
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
              Button {
                text: root.busy ? "Creating…" : "Create"
                iconText: "󰐕"
                bordered: true
                enabled: !root.busy
                onClicked: root.createRoom(newRoomName.text, encryptedToggle.checked, privateToggle.checked)
              }
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
              Button {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Clear"
                onClicked: root.clearResults()
              }
            }

            Repeater {
              model: root.results
              delegate: Item {
                id: resultRow
                required property var modelData
                width: panelColumn.width
                implicitHeight: Style.space(36)

                Column {
                  anchors.left: parent.left
                  anchors.right: resultAction.left
                  anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(1)
                  Text {
                    width: parent.width
                    text: root.resultsKind === "users"
                      ? (resultRow.modelData.name || resultRow.modelData.id)
                      : resultRow.modelData.name
                    color: root.bar.foreground
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.body
                    elide: Text.ElideRight
                  }
                  Text {
                    width: parent.width
                    text: root.resultsKind === "users"
                      ? resultRow.modelData.id
                      : ((resultRow.modelData.alias || resultRow.modelData.id) + " · " + resultRow.modelData.members + " members")
                    color: root.bar.foreground
                    opacity: 0.5
                    font.family: root.bar.fontFamily
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
                    else if (resultRow.modelData.joined) { root.clearResults(); root.openRoom(resultRow.modelData) }
                    else root.joinRoom(resultRow.modelData.alias || resultRow.modelData.id)
                  }
                }
              }
            }
          }

          // Invites
          Column {
            width: parent.width
            spacing: Style.space(2)
            visible: root.invites.length > 0

            PanelSectionHeader { text: "Invitations" }

            Repeater {
              model: root.invites
              delegate: Item {
                id: inviteRow
                required property var modelData
                width: panelColumn.width
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
                    color: root.bar.foreground
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                    elide: Text.ElideRight
                  }
                  Text {
                    width: parent.width
                    text: "from " + (inviteRow.modelData.inviter_name || inviteRow.modelData.inviter || "unknown")
                    color: root.bar.foreground
                    opacity: 0.5
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }
                Row {
                  id: inviteButtons
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.spacing.controlGap
                  Button { text: "Accept"; bordered: true; onClicked: root.acceptInvite(inviteRow.modelData.room) }
                  Button { text: "Decline"; onClicked: root.declineInvite(inviteRow.modelData.room) }
                }
              }
            }
          }

          // Rooms
          Column {
            width: parent.width
            spacing: Style.space(2)

            PanelSectionHeader { text: "Rooms"; visible: root.rooms.length > 0 }

            Text {
              width: parent.width
              visible: root.rooms.length === 0
              wrapMode: Text.WordWrap
              text: root.status.syncing
                ? "No rooms yet. Search the directory above, join by #alias, or message someone by @user:server."
                : "Syncing…"
              color: root.bar.foreground
              opacity: 0.6
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
            }

            Repeater {
              model: root.rooms
              delegate: Item {
                id: roomRow
                required property var modelData
                width: panelColumn.width
                implicitHeight: Style.space(34)

                Rectangle {
                  anchors.fill: parent
                  radius: Style.space(6)
                  color: rowMouse.containsMouse ? Color.menu.selectedBackground : "transparent"
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
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.body
                  }
                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Style.space(60)
                    text: roomRow.modelData.name
                    color: root.bar.foreground
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: (Number(roomRow.modelData.unread) || 0) > 0
                    elide: Text.ElideRight
                  }
                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: (Number(roomRow.modelData.unread) || 0) > 0
                    text: String(roomRow.modelData.unread)
                    color: (Number(roomRow.modelData.highlights) || 0) > 0 ? Color.urgent : Color.accent
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
                MouseArea {
                  id: rowMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.openRoom(roomRow.modelData)
                }
              }
            }
          }
        }

        // Signed in: one room
        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: root.loggedIn && root.currentRoom !== ""

          ListView {
            id: msgList
            width: parent.width
            height: Style.space(340)
            clip: true
            spacing: Style.space(6)
            model: msgModel
            delegate: Column {
              required property string senderName
              required property string body
              required property real ts
              required property bool mine
              required property bool encrypted
              width: msgList.width
              spacing: Style.space(1)

              Row {
                spacing: Style.space(6)
                Text {
                  text: senderName
                  color: mine ? Color.accent : root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
                Text {
                  text: root.timeText(ts) + (encrypted ? "" : " 󰌿")
                  color: root.bar.foreground
                  opacity: 0.5
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
              Text {
                width: parent.width
                text: body
                wrapMode: Text.Wrap
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
              }
            }
          }

          Row {
            width: parent.width
            spacing: Style.spacing.controlGap
            TextField {
              id: composer
              width: parent.width - sendButton.width - Style.spacing.controlGap
              maximumLength: 4000
              placeholderText: root.currentRoomEncrypted ? "Encrypted message…" : "Message (not encrypted)…"
              enabled: !root.busy
              onAccepted: root.send(composer.text)
            }
            Button {
              id: sendButton
              text: root.busy ? "…" : "Send"
              iconText: "󰒊"
              enabled: !root.busy
              onClicked: root.send(composer.text)
            }
          }
          Button {
            text: "Leave room"
            enabled: !root.busy
            onClicked: root.leaveCurrentRoom()
          }
        }

        // Error
        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          visible: root.errorText !== ""
          text: root.errorText
          color: Color.urgent
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
        }

        PanelSeparator { width: parent.width; visible: root.loggedIn }

        // Footer: account + sign out
        Item {
          width: parent.width
          visible: root.loggedIn
          implicitHeight: Math.max(footerText.implicitHeight, signOut.implicitHeight)

          Text {
            id: footerText
            anchors.left: parent.left
            anchors.right: signOut.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            wrapMode: Text.WrapAnywhere
            text: (root.status.user_id || "") + (root.status.syncing ? "" : " · " + (root.status.error || "not syncing"))
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
            enabled: !root.busy
            onClicked: root.logout()
          }
        }
      }
    }
  }
}
