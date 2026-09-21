import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Format.js" as Format

// One room: recent history, live messages, composer. Set `room` (an object
// from the service's room list or a command result) to show it; clear it
// with `close()`. `viewId` identifies this view to the service so incoming
// messages here don't raise notifications while it is visible.
Item {
  id: root
  property var service: null
  property string viewId: "room"
  property color fg: Color.foreground
  property string fontFamily: Style.font.family
  property bool showLeave: true
  property real timelineHeight: Style.space(340)
  property bool fillHeight: false   // the window gives us a fixed height instead

  property var room: null
  readonly property string roomId: room ? String(room.id) : ""
  readonly property string roomName: room ? String(room.name) : ""
  readonly property bool encrypted: room ? room.encrypted === true : false
  property bool busy: false
  property string errorText: ""

  signal roomLeft()
  // Someone wants the thread under a message opened (the host shows it).
  signal threadRequested(string eventId)
  // Esc in a thread with nothing to cancel: the host closes the thread.
  signal closeRequested()

  // Thread mode: this view shows one thread of `room` instead of the room.
  // Replies come from the `thread` command, sends go into the thread, and
  // nothing here marks the room read.
  property string threadRoot: ""
  readonly property bool inThread: threadRoot !== ""
  readonly property string draftKey: roomId + (inThread ? "#" + threadRoot : "")
  property bool _stashed: false
  function openThread(r, rootId) {
    // Stash under the thread we are leaving, before the key changes.
    root.stashDraft()
    root._stashed = true
    root.threadRoot = rootId
    root.open(r)
  }

  implicitHeight: column.implicitHeight
  readonly property bool hasTextFocus: composer.hasFocus
  function focusComposer() { composer.forceActiveFocus() }

  ListModel { id: msgModel }

  // Paging: `nextToken` points at the page before the oldest loaded one;
  // empty once history is exhausted.
  property string nextToken: ""
  property bool loadingOlder: false
  readonly property bool hasOlder: nextToken !== ""

  // ---------- read state ----------
  // A message counts as read only when this view is visible and the list
  // is at its end. Otherwise it stays unread and the pill offers to jump.
  property int pendingNew: 0
  property string lastEventId: ""
  readonly property bool atEnd: msgList.atYEnd || msgList.contentHeight <= msgList.height
  function maybeMarkRead() {
    if (!root.roomId || !root.visible || !root.atEnd || root.lastEventId === "") return
    if (root.pendingNew === 0 && root.readUpTo === root.lastEventId) return
    root.pendingNew = 0
    root.readUpTo = root.lastEventId
    if (root.inThread) root.service.markThreadRead(root.roomId, root.threadRoot, root.lastEventId)
    else root.service.markRead(root.roomId, root.lastEventId)
  }
  property string readUpTo: ""
  onAtEndChanged: if (atEnd) maybeMarkRead()
  onVisibleChanged: { if (root.service && !root.inThread) root.service.setViewing(root.viewId, visible ? root.roomId : ""); if (visible) Qt.callLater(maybeMarkRead) }
  function jumpToNew() { root.stickToEnd = true; root.snapToEnd(); }

  // Delegates load lazily (images, wrapped text), so a single
  // positionViewAtEnd lands short. Re-anchor a few times while rows
  // settle, and stop the moment the user scrolls away.
  property bool stickToEnd: false
  function snapToEnd() {
    msgList.positionViewAtEnd()
    settle.restart()
  }
  Timer {
    id: settle
    interval: 120
    repeat: true
    property int ticks: 0
    onRunningChanged: if (running) ticks = 0
    onTriggered: {
      if (!root.stickToEnd || msgList.dragging || msgList.flicking) { stop(); return }
      msgList.positionViewAtEnd()
      root.maybeMarkRead()
      if (++ticks >= 12) stop()
    }
  }

  // Open a room and land on a specific message (from search).
  function openAt(r, eventId) {
    root.open(r)
    root.pendingJump = eventId
  }
  property string pendingJump: ""

  function open(r) {
    if (!root._stashed) root.stashDraft()
    root._stashed = false
    root.room = r
    root.errorText = ""
    root.pendingJump = ""
    root.jumpTarget = ""
    root.nextToken = ""
    root.loadingOlder = false
    root.pendingNew = 0
    root.lastEventId = ""
    root.readUpTo = ""
    root.typingUsers = []
    root.reactionIndex = ({})
    root.confirmDelete = null
    msgModel.clear()
    if (!root.inThread) root.service.setViewing(root.viewId, root.roomId)
    root.restoreDraft()
    var id = root.roomId
    var marker = root.inThread ? "" : (r.read_marker || "")
    var thread = root.threadRoot
    var load = root.inThread
      ? function(cb) { root.service.thread(id, thread, 60, "", cb) }
      : function(cb) { root.service.timeline(id, 60, "", cb) }
    load(function(res) {
      if (root.roomId !== id || root.threadRoot !== thread) return
      if (!res.ok) { root.errorText = res.error || "Could not load messages"; return }
      var list = res.result.messages
      root.nextToken = res.result.next || ""
      if (list.length === 0) return
      var dividerAt = -1
      for (var i = 0; i < list.length; i++) {
        root.append(list[i])
        // First message after our marker, from someone else, starts the unread run.
        if (dividerAt === -1 && marker !== "" && i > 0 && list[i - 1].event_id === marker && list[i].sender !== root.service.userId) dividerAt = i
      }
      root.lastEventId = list[list.length - 1].event_id
      root.readUpTo = marker
      if (root.pendingJump !== "") {
        var target = root.pendingJump
        root.pendingJump = ""
        root.stickToEnd = false
        Qt.callLater(function() { root.jumpTo(target) })
      } else if (dividerAt > 0) {
        msgModel.setProperty(dividerAt, "newDivider", true)
        msgModel.setProperty(dividerAt, "header", true)
        root.stickToEnd = false
        Qt.callLater(function() { msgList.positionViewAtIndex(dividerAt, ListView.Beginning); Qt.callLater(root.maybeMarkRead) })
      } else {
        root.stickToEnd = true
        Qt.callLater(root.snapToEnd)
      }
      Qt.callLater(function() { composer.forceActiveFocus() })
    })
  }

  function loadOlder() {
    if (!root.hasOlder || root.loadingOlder || !root.roomId) return
    root.loadingOlder = true
    var id = root.roomId
    var token = root.nextToken
    var thread = root.threadRoot
    var load = root.inThread
      ? function(cb) { root.service.thread(id, thread, 60, token, cb) }
      : function(cb) { root.service.timeline(id, 60, token, cb) }
    load(function(res) {
      root.loadingOlder = false
      if (root.roomId !== id || root.threadRoot !== thread) return
      if (!res.ok) { root.errorText = res.error || "Could not load earlier messages"; return }
      root.nextToken = res.result.next || ""
      root.prepend(res.result.messages)
      if (root.jumpTarget !== "") {
        var t = root.jumpTarget
        var idx = root.indexOfEvent(t)
        if (idx >= 0) { root.jumpTarget = ""; Qt.callLater(function() { root.jumpTo(t) }) }
        else Qt.callLater(root.loadOlderForJump)
      }
    })
  }

  // Keep what was typed in the room we are leaving; an edit in progress is
  // dropped (it is the message's own text), a reply keeps its draft.
  function stashDraft() {
    if (root.roomId === "" || !root.service) return
    root.service.setDraft(root.draftKey, root.editing ? "" : composer.text)
    composer.text = ""
  }
  function restoreDraft() {
    if (!root.service) return
    var d = root.service.draft(root.draftKey)
    composer.text = d
    composer.cursorPosition = d.length
  }

  function close() {
    root.stashDraft()
    root.setTyping(false)
    root.room = null
    root.replyTo = null
    root.editing = null
    root.typingUsers = []
    msgModel.clear()
    if (!root.inThread) root.service.setViewing(root.viewId, "")
    root.threadRoot = ""
  }

  // Group a message under the previous header when it is the same sender
  // within five minutes on the same day; start a day divider on a new day.
  readonly property int groupWindowMs: 5 * 60 * 1000
  function metaFor(prev, m) {
    var ts = Number(m.ts) || 0
    var newDay = !prev || !Format.isSameDay(prev.ts, ts)
    var sys = m.msgtype === "system" || (prev && prev.msgtype === "system")
    return {
      header: newDay || !prev || sys || prev.sender !== m.sender || (ts - prev.ts) > groupWindowMs,
      dayLabel: newDay ? Format.dayLabel(ts, Date.now()) : ""
    }
  }
  function indexReactions(m) {
    var list = m.reactions || []
    var idx = root.reactionIndex
    for (var i = 0; i < list.length; i++)
      for (var j = 0; j < list[i].senders.length; j++) {
        var sd = list[i].senders[j]
        if (sd.reaction_id) idx[sd.reaction_id] = { eventId: m.event_id, key: list[i].key, user: { id: sd.id, name: sd.name } }
      }
    root.reactionIndex = idx
  }
  function entryFor(m, meta) {
    root.indexReactions(m)
    return {
      eventId: m.event_id,
      sender: m.sender,
      senderName: m.sender_name || m.sender,
      senderAvatar: m.sender_avatar || "",
      body: m.body,
      html: m.html || "",
      msgtype: m.msgtype || "m.text",
      attachmentJson: m.attachment ? JSON.stringify(m.attachment) : "",
      replyJson: m.reply_to ? JSON.stringify(m.reply_to) : "",
      edited: m.edited === true,
      deleted: m.deleted === true,
      mention: m.highlight === true,
      via: m.via || "",
      reactionsJson: JSON.stringify(m.reactions || []),
      readByJson: JSON.stringify(m.read_by || []),
      ts: Number(m.ts) || 0,
      mine: m.sender === root.service.userId,
      encrypted: m.encrypted === true,
      header: meta.header,
      dayLabel: meta.dayLabel,
      newDivider: false
    }
  }

  // Older messages go in at the top; the view keeps its place by growing
  // contentY by exactly what was added above it.
  function prepend(list) {
    if (list.length === 0) return
    root.stickToEnd = false
    var oldHeight = msgList.contentHeight
    var oldY = msgList.contentY
    var prev = null
    for (var i = 0; i < list.length; i++) {
      var meta = root.metaFor(prev, list[i])
      msgModel.insert(i, root.entryFor(list[i], meta))
      prev = { ts: Number(list[i].ts) || 0, sender: list[i].sender, msgtype: list[i].msgtype }
    }
    // The item that used to be first is now preceded by real history.
    if (msgModel.count > list.length) {
      var first = msgModel.get(list.length)
      var m2 = root.metaFor(prev, { ts: first.ts, sender: first.sender, msgtype: first.msgtype })
      msgModel.setProperty(list.length, "header", m2.header)
      msgModel.setProperty(list.length, "dayLabel", m2.dayLabel)
    }
    Qt.callLater(function() { msgList.contentY = oldY + (msgList.contentHeight - oldHeight) })
  }

  function append(m) {
    root.indexReactions(m)
    var ts = Number(m.ts) || 0
    var prev = msgModel.count > 0 ? msgModel.get(msgModel.count - 1) : null
    var newDay = !prev || !Format.isSameDay(prev.ts, ts)
    var sys = m.msgtype === "system" || (prev && prev.msgtype === "system")
    var header = newDay || !prev || sys || prev.sender !== m.sender || (ts - prev.ts) > groupWindowMs
    msgModel.append({
      eventId: m.event_id,
      sender: m.sender,
      senderName: m.sender_name || m.sender,
      senderAvatar: m.sender_avatar || "",
      body: m.body,
      html: m.html || "",
      msgtype: m.msgtype || "m.text",
      attachmentJson: m.attachment ? JSON.stringify(m.attachment) : "",
      replyJson: m.reply_to ? JSON.stringify(m.reply_to) : "",
      edited: m.edited === true,
      deleted: m.deleted === true,
      mention: m.highlight === true,
      via: m.via || "",
      reactionsJson: JSON.stringify(m.reactions || []),
      readByJson: JSON.stringify(m.read_by || []),
      ts: ts,
      mine: m.sender === root.service.userId,
      encrypted: m.encrypted === true,
      header: header,
      dayLabel: newDay ? Format.dayLabel(ts, Date.now()) : "",
      newDivider: false,
      threadRoot: m.thread_root || "",
      threadJson: m.thread ? JSON.stringify(m.thread) : ""
    })
  }

  // A reply arrived in a thread whose root is on screen: bump its summary.
  function bumpThread(m) {
    var i = root.indexOfEvent(m.thread_root)
    if (i < 0) return
    var cur = msgModel.get(i).threadJson
    var t = cur !== "" ? JSON.parse(cur) : { replies: 0 }
    t.replies = (t.replies || 0) + 1
    if (m.sender !== root.service.userId) t.unread = (t.unread || 0) + 1
    t.latest_ts = Number(m.ts) || Date.now()
    t.latest_sender = m.sender
    t.latest_sender_name = m.sender_name || m.sender
    msgModel.setProperty(i, "threadJson", JSON.stringify(t))
  }

  // ---------- reactions / receipts / typing ----------
  property var typingUsers: []
  readonly property string typingText: {
    var n = typingUsers.map(function(u) { return u.name })
    if (n.length === 0) return ""
    if (n.length === 1) return n[0] + " is typing"
    if (n.length === 2) return n[0] + " and " + n[1] + " are typing"
    return n[0] + ", " + n[1] + " and " + (n.length - 2) + " more are typing"
  }
  // Own typing notices: start on the first keystroke, stop after a pause
  // or when the message goes out.
  property bool typingSent: false
  Timer { id: typingStop; interval: 5000; onTriggered: root.setTyping(false) }
  function setTyping(on) {
    if (!root.roomId || on === root.typingSent) return
    root.typingSent = on
    root.service.typing(root.roomId, on)
  }
  function noteTyping() {
    if (!root.roomId) return
    if (composer.text.length > 0) { root.setTyping(true); typingStop.restart() }
    else { typingStop.stop(); root.setTyping(false) }
  }

  function toggleReaction(eventId, key) {
    var i = root.indexOfEvent(eventId)
    if (i < 0) return
    var list = JSON.parse(msgModel.get(i).reactionsJson)
    for (var k = 0; k < list.length; k++) {
      if (list[k].key === key && list[k].mine) {
        var rid = list[k].mine
        root.service.unreact(root.roomId, rid, function(r) { if (!r.ok) root.errorText = r.error || "Could not remove reaction" })
        root.applyReaction(eventId, key, { id: root.service.userId, name: "you" }, rid, false)
        return
      }
    }
    root.service.react(root.roomId, eventId, key, function(r) {
      if (!r.ok) { root.errorText = r.error || "Could not react"; return }
      var idx = root.reactionIndex; idx[r.result.reaction_id] = { eventId: eventId, key: key, user: { id: root.service.userId, name: "you" } }; root.reactionIndex = idx
      root.applyReaction(eventId, key, { id: root.service.userId, name: "you" }, r.result.reaction_id, true)
    })
  }

  // Add or remove one user's reaction in the model.
  function applyReaction(eventId, key, user, reactionId, add) {
    var i = root.indexOfEvent(eventId)
    if (i < 0) return
    var list = JSON.parse(msgModel.get(i).reactionsJson)
    var mine = user.id === root.service.userId
    var found = -1
    for (var k = 0; k < list.length; k++) if (list[k].key === key) found = k
    if (add) {
      if (found < 0) { list.push({ key: key, count: 0, senders: [], mine: null }); found = list.length - 1 }
      var r = list[found]
      if (r.senders.some(function(u) { return u.id === user.id })) return
      r.senders.push({ id: user.id, name: user.name, reaction_id: reactionId }); r.count = r.senders.length
      if (mine) r.mine = reactionId
    } else {
      if (found < 0) return
      var rr = list[found]
      rr.senders = rr.senders.filter(function(u) { return u.id !== user.id }); rr.count = rr.senders.length
      if (mine) rr.mine = null
      if (rr.count === 0) list.splice(found, 1)
    }
    msgModel.setProperty(i, "reactionsJson", JSON.stringify(list))
  }
  // reaction event id -> {eventId, key, user} so a redaction can undo it
  property var reactionIndex: ({})

  Connections {
    target: root.service
    function onReactionReceived(r) {
      if (!root.roomId || r.room !== root.roomId) return
      var idx = root.reactionIndex; idx[r.reaction_id] = { eventId: r.event_id, key: r.key, user: r.sender }; root.reactionIndex = idx
      root.applyReaction(r.event_id, r.key, r.sender, r.reaction_id, true)
    }
    function onRedacted(x) {
      if (!root.roomId || x.room !== root.roomId) return
      var ref = root.reactionIndex[x.event_id]
      if (ref) { root.applyReaction(ref.eventId, ref.key, ref.user, x.event_id, false); return }
      var i = root.indexOfEvent(x.event_id)
      if (i >= 0) { msgModel.setProperty(i, "deleted", true); msgModel.setProperty(i, "edited", false); msgModel.setProperty(i, "body", ""); msgModel.setProperty(i, "html", ""); msgModel.setProperty(i, "attachmentJson", ""); msgModel.setProperty(i, "reactionsJson", "[]") }
    }
    function onTypingChanged(t) {
      if (!root.roomId || t.room !== root.roomId) return
      root.typingUsers = t.users
    }
    function onReceiptMoved(rc) {
      if (!root.roomId || rc.room !== root.roomId) return
      // Each user's marker lives on exactly one message: remove elsewhere, add here.
      var ids = rc.users.map(function(u) { return u.id })
      for (var i = 0; i < msgModel.count; i++) {
        var it = msgModel.get(i)
        var list = JSON.parse(it.readByJson)
        var next = list.filter(function(u) { return ids.indexOf(u.id) === -1 })
        if (it.eventId === rc.event_id) next = next.concat(rc.users)
        if (next.length !== list.length || it.eventId === rc.event_id) msgModel.setProperty(i, "readByJson", JSON.stringify(next))
      }
    }
    function onMessageEdited(e) {
      if (!root.roomId || e.room !== root.roomId) return
      var i = root.indexOfEvent(e.event_id)
      if (i < 0) return
      msgModel.setProperty(i, "body", e.body)
      msgModel.setProperty(i, "html", e.html || "")
      msgModel.setProperty(i, "edited", true)
    }
    function onThreadRead(roomId, rootId) {
      if (root.inThread || roomId !== root.roomId) return
      var i = root.indexOfEvent(rootId)
      if (i < 0) return
      var cur = msgModel.get(i).threadJson
      if (cur === "") return
      var t = JSON.parse(cur); t.unread = 0
      msgModel.setProperty(i, "threadJson", JSON.stringify(t))
    }
    function onMessageReceived(m) {
      if (!root.roomId || m.room !== root.roomId) return
      // Thread replies belong to their thread; the room only counts them.
      if (root.inThread) { if (m.thread_root !== root.threadRoot) return }
      else if (m.thread_root) { root.bumpThread(m); return }
      var wasAtEnd = root.atEnd
      root.append(m)
      root.lastEventId = m.event_id
      if (m.sender === root.service.userId || (wasAtEnd && root.visible)) {
        root.stickToEnd = true
        Qt.callLater(root.snapToEnd)
      } else {
        root.pendingNew++
      }
    }
  }

  // ---------- emoji completion ----------
  // Typing ":smi" offers emoji; Tab/Enter inserts the highlighted one.
  property var emojiHits: []
  property int emojiIndex: 0
  property int emojiStart: -1
  function updateEmojiHints() {
    var t = composer.text, c = composer.cursorPosition
    var i = c - 1
    while (i >= 0 && /[a-z0-9_+-]/i.test(t.charAt(i))) i--
    if (i >= 0 && t.charAt(i) === ":" && (i === 0 || /\s/.test(t.charAt(i - 1)))) {
      var word = t.substring(i + 1, c)
      root.emojiHits = root.service.emojiSuggestions(word, 6)
      root.emojiStart = root.emojiHits.length ? i : -1
      root.emojiIndex = 0
    } else { root.emojiHits = []; root.emojiStart = -1 }
  }
  function insertEmoji(idx) {
    if (root.emojiStart < 0 || idx < 0 || idx >= root.emojiHits.length) return
    var t = composer.text, c = composer.cursorPosition, start = root.emojiStart
    var e = root.emojiHits[idx].e + " "
    // Setting the text re-runs the hint scan (which clears emojiStart), so
    // place the cursor from the saved start.
    composer.text = t.substring(0, start) + e + t.substring(c)
    composer.cursorPosition = start + e.length
    root.emojiHits = []; root.emojiStart = -1
  }

  // ---------- reply / edit ----------
  // One of these at a time; the strip above the composer shows which.
  property var replyTo: null      // {event_id, sender_name, body}
  property var editing: null      // {event_id, body}
  function startReply(m) { root.editing = null; root.replyTo = m; composer.forceActiveFocus() }
  function startEdit(m) { root.replyTo = null; root.editing = m; composer.text = m.body; composer.forceActiveFocus(); composer.cursorPosition = composer.text.length }
  function cancelCompose() { if (root.editing) composer.text = ""; root.replyTo = null; root.editing = null }
  function indexOfEvent(eventId) {
    for (var i = 0; i < msgModel.count; i++) if (msgModel.get(i).eventId === eventId) return i
    return -1
  }
  property var confirmDelete: null
  function deleteMessage(eventId) {
    root.service.deleteMessage(root.roomId, eventId, function(r) {
      if (!r.ok) root.errorText = r.error || "Could not delete"
    })
    root.confirmDelete = null
  }

  function jumpTo(eventId) {
    var i = root.indexOfEvent(eventId)
    if (i >= 0) { root.stickToEnd = false; msgList.positionViewAtIndex(i, ListView.Center); root.flashIndex = i; flashTimer.restart(); return }
    // Not loaded yet: page back until it is, within reason.
    root.jumpTarget = eventId
    root.jumpPagesLeft = 15
    root.loadOlderForJump()
  }
  property string jumpTarget: ""
  property int jumpPagesLeft: 0
  function loadOlderForJump() {
    if (root.jumpTarget === "" || root.jumpPagesLeft <= 0 || !root.hasOlder || root.loadingOlder) { if (root.jumpTarget !== "" && !root.loadingOlder) { root.jumpTarget = ""; root.errorText = "That message is further back than could be loaded" } return }
    root.jumpPagesLeft--
    root.loadOlder()
  }
  property int flashIndex: -1
  Timer { id: flashTimer; interval: 1200; onTriggered: root.flashIndex = -1 }

  function send() {
    var text = composer.text
    if (text.trim() === "" || !root.roomId || root.busy) return
    typingStop.stop(); root.setTyping(false)
    root.busy = true
    if (root.editing) {
      var target = root.editing.event_id
      root.service.edit(root.roomId, target, text, function(r) {
        root.busy = false
        if (!r.ok) { root.errorText = r.error || "Edit failed"; return }
        composer.text = ""; root.errorText = ""; root.editing = null
        var i = root.indexOfEvent(target)
        if (i >= 0) { msgModel.setProperty(i, "body", text); msgModel.setProperty(i, "html", ""); msgModel.setProperty(i, "edited", true) }
      })
      return
    }
    var reply = root.replyTo ? root.replyTo.event_id : ""
    var deliver = root.inThread
      ? function(cb) { root.service.sendInThread(root.roomId, root.threadRoot, text, reply, cb) }
      : function(cb) { root.service.send(root.roomId, text, reply, cb) }
    deliver(function(r) {
      root.busy = false
      if (!r.ok) root.errorText = r.error || "Send failed"
      else { composer.text = ""; root.service.setDraft(root.draftKey, ""); root.errorText = ""; root.replyTo = null; Qt.callLater(function() { msgList.positionViewAtEnd() }) }
    })
  }

  // ---------- voice messages ----------
  readonly property bool recordingHere: root.service && root.service.recording && root.service.recordingRoom === root.roomId
  function startVoice() {
    if (!root.service || root.roomId === "" || root.service.recording) return
    root.errorText = ""
    root.service.startRecording(root.roomId)
    root.uploads++
    Qt.callLater(function() { recordStrip.forceActiveFocus() })
  }
  Connections {
    target: root.service
    function onVoiceSent(roomId, ok, error) {
      if (roomId !== root.roomId) return
      root.uploads = Math.max(0, root.uploads - 1)
      if (!ok) root.errorText = error
      else Qt.callLater(function() { msgList.positionViewAtEnd() })
      composer.forceActiveFocus()
    }
    function onRecordingChanged() {
      if (root.service && !root.service.recording) {
        // Cancelled (not sent): drop the pending upload marker.
        if (!root.service.recordSend && root.uploads > 0) root.uploads = Math.max(0, root.uploads - 1)
        composer.forceActiveFocus()
      }
    }
  }

  // ---------- attachments ----------

  property int uploads: 0
  function sendFiles(paths) {
    for (var i = 0; i < paths.length; i++) {
      var p = String(paths[i]).replace(/^file:\/\//, "")
      if (p === "") continue
      root.uploads++
      root.service.sendFile(root.roomId, p, "", function(r) {
        root.uploads--
        if (!r.ok) root.errorText = r.error || "Could not send the file"
      })
    }
  }

  FileDialog {
    id: fileDialog
    title: "Send a file"
    fileMode: FileDialog.OpenFiles
    onAccepted: root.sendFiles(selectedFiles)
  }

  // Ctrl+V with an image on the clipboard sends it; otherwise it pastes text.
  Process {
    id: pasteProc
    property string out: ""
    command: ["/usr/bin/bash", "-c",
      "if wl-paste -l 2>/dev/null | grep -q '^image/'; then f=\"${XDG_RUNTIME_DIR:-/tmp}/yapper-paste-$(date +%s%N).png\"; wl-paste -t image/png > \"$f\" && echo \"$f\"; fi"]
    stdout: SplitParser { splitMarker: ""; onRead: function(d) { pasteProc.out += d } }
    onStarted: out = ""
    onExited: function() {
      var p = pasteProc.out.trim()
      if (p !== "") root.sendFiles([p])
      else composer.paste()
    }
  }

  function leave() {
    if (!root.roomId || root.busy) return
    root.busy = true
    root.service.leave(root.roomId, function(r) {
      root.busy = false
      if (!r.ok) { root.errorText = r.error || "Could not leave"; return }
      root.close()
      root.roomLeft()
    })
  }

  DropArea {
    id: drop
    anchors.fill: parent
    enabled: root.roomId !== ""
    onDropped: function(d) { if (d.hasUrls) { root.sendFiles(d.urls); d.accept() } }
  }
  Rectangle {
    anchors.fill: parent
    visible: drop.containsDrag
    z: 10
    radius: Style.space(8)
    color: Util.alpha(root.service ? root.service.accent : Color.accent, 0.12)
    border.width: 2
    border.color: root.service ? root.service.accent : Color.accent
    Text {
      anchors.centerIn: parent
      text: "󰁦  Drop to send" + (root.encrypted ? " (encrypted)" : "")
      color: root.fg
      font.family: root.fontFamily
      font.pixelSize: Style.font.title
    }
  }

  Column {
    id: column
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: root.fillHeight ? parent.bottom : undefined
    spacing: Style.space(8)

    ListView {
      id: msgList
      width: parent.width
      // Fill mode: whatever the rows below leave over (a Column skips
      // invisible and zero-height children, so count only the rest).
      readonly property real below: {
        var rows = [typingItem, confirmBox, replyStrip, composerRow, errorLabel, leaveButton]
        var h = 0
        for (var i = 0; i < rows.length; i++) if (rows[i].visible && rows[i].height > 0) h += rows[i].height + column.spacing
        return h
      }
      height: root.fillHeight ? column.height - below : root.timelineHeight
      clip: true
      spacing: 0
      model: msgModel
      cacheBuffer: 2000
      boundsBehavior: Flickable.StopAtBounds
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
      // Reaching the top loads the page before it.
      onContentYChanged: if (contentY <= originY + Style.space(40) && root.hasOlder && !root.loadingOlder && count > 0) root.loadOlder()
      // A manual scroll up releases the bottom anchor.
      onDraggingChanged: if (dragging) root.stickToEnd = false
      onFlickingChanged: if (flicking && !atYEnd) root.stickToEnd = false
      onAtYEndChanged: if (atYEnd) root.stickToEnd = true
      // The composer growing shrinks the list; keep the end in view.
      onHeightChanged: if (root.stickToEnd) Qt.callLater(root.snapToEnd)

      header: Item {
        width: msgList.width
        height: root.hasOlder || root.loadingOlder ? Style.space(40) : (msgModel.count > 0 ? Style.space(28) : 0)
        Button {
          anchors.centerIn: parent
          visible: root.hasOlder || root.loadingOlder
          text: root.loadingOlder ? "Loading…" : "Load earlier messages"
          enabled: !root.loadingOlder
          onClicked: root.loadOlder()
        }
        Text {
          anchors.centerIn: parent
          visible: !root.hasOlder && !root.loadingOlder && msgModel.count > 0
          text: "Beginning of the conversation"
          color: root.fg; opacity: 0.4
          font.family: root.fontFamily; font.pixelSize: Style.font.caption
        }
      }
      delegate: MessageRow {
        required property var model
        required property int index
        width: msgList.width
        sender: model.sender
        senderName: model.senderName
        senderAvatar: model.senderAvatar
        body: model.body
        html: model.html
        msgtype: model.msgtype
        attachment: model.attachmentJson !== "" ? JSON.parse(model.attachmentJson) : null
        roomId: root.roomId
        eventId: model.eventId
        service: root.service
        ts: model.ts
        mine: model.mine
        encrypted: model.encrypted
        roomEncrypted: root.encrypted
        header: model.header
        dayLabel: model.dayLabel
        newDivider: model.newDivider
        replyTo: model.replyJson !== "" ? JSON.parse(model.replyJson) : null
        edited: model.edited
        deleted: model.deleted
        mention: model.mention
        via: model.via
        linkPreviews: root.service ? root.service.linkPreviews : true
        reactions: JSON.parse(model.reactionsJson)
        readBy: JSON.parse(model.readByJson)
        onReactRequested: function(key) { root.toggleReaction(model.eventId, key) }
        onDeleteRequested: root.confirmDelete = { event_id: model.eventId, body: model.body }
        highlighted: index === root.flashIndex
        canEdit: model.mine && !model.attachmentJson && !model.deleted
        canDelete: model.mine && !model.deleted
        onReplyRequested: root.startReply({ event_id: model.eventId, sender_name: model.senderName, body: model.body })
        onEditRequested: root.startEdit({ event_id: model.eventId, body: model.body })
        onJumpRequested: function(id) { root.jumpTo(id) }
        threadInfo: model.threadJson !== "" ? JSON.parse(model.threadJson) : null
        inThread: root.inThread
        isThreadRoot: root.inThread && model.eventId === root.threadRoot
        onThreadRequested: root.threadRequested(model.eventId)
        fg: root.fg
        accent: root.service ? root.service.accent : Color.accent
        bg: root.service ? root.service.bg : Color.popups.background
        hover: root.service ? root.service.hover : Util.alpha(Color.foreground, 0.05)
        bubbles: root.service ? root.service.bubbles : false
        showAvatars: root.service ? root.service.showAvatars : true
        senderColors: root.service ? root.service.senderColors : true
        scale: root.service ? root.service.fontScale : 1.0
        fontFamily: root.fontFamily
      }
    }

    // Who is typing
    Item {
      id: typingItem
      width: parent.width
      height: root.typingText !== "" ? Style.space(18) : 0
      visible: height > 0
      Row {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(4)
        spacing: Style.space(6)
        Row {
          anchors.verticalCenter: parent.verticalCenter
          spacing: 3
          Repeater {
            model: 3
            delegate: Rectangle {
              required property int index
              width: 5; height: 5; radius: 2.5
              color: root.fg
              SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: root.typingText !== ""
                PauseAnimation { duration: index * 160 }
                NumberAnimation { to: 1; duration: 320 }
                NumberAnimation { to: 0.25; duration: 320 }
                PauseAnimation { duration: (2 - index) * 160 }
              }
            }
          }
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.typingText
          color: root.fg; opacity: 0.6
          font.family: root.fontFamily; font.pixelSize: Style.font.caption
        }
      }
    }

    // Delete confirmation
    Rectangle {
      id: confirmBox
      width: parent.width
      visible: root.confirmDelete !== null
      implicitHeight: visible ? delRow.implicitHeight + Style.space(12) : 0
      radius: Style.space(8)
      color: Util.alpha(Color.urgent, 0.12)
      border.width: 1
      border.color: Color.urgent
      Row {
        id: delRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.space(12)
        anchors.rightMargin: Style.space(8)
        spacing: Style.space(10)
        Column {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - Style.space(10) - delButtons.width
          spacing: Style.space(1)
          Text { text: "Delete this message?"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
          Text {
            width: parent.width
            text: root.confirmDelete ? (root.confirmDelete.body || "(attachment)") : ""
            color: root.fg; opacity: 0.7; elide: Text.ElideRight
            font.family: root.fontFamily; font.pixelSize: Style.font.caption
          }
        }
        Row {
          id: delButtons
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.spacing.controlGap
          Button { text: "Delete"; bordered: true; onClicked: root.deleteMessage(root.confirmDelete.event_id) }
          Button { text: "Keep"; onClicked: root.confirmDelete = null }
        }
      }
    }

    // Replying to / editing strip
    Rectangle {
      id: replyStrip
      width: parent.width
      visible: root.replyTo !== null || root.editing !== null
      implicitHeight: visible ? stripRow.implicitHeight + Style.space(12) : 0
      radius: Style.space(8)
      color: Util.alpha(root.service ? root.service.accent : Color.accent, 0.1)
      Row {
        id: stripRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.space(12)
        anchors.rightMargin: Style.space(6)
        spacing: Style.space(10)
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.editing ? "󰏫" : "󰑚"
          color: root.service ? root.service.accent : Color.accent
          font.family: root.fontFamily; font.pixelSize: Style.font.icon
        }
        Column {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - Style.space(10) * 2 - Style.space(24) - stripClose.width
          spacing: Style.space(1)
          Text {
            text: root.editing ? "Editing message" : ("Replying to " + (root.replyTo ? root.replyTo.sender_name : ""))
            color: root.service ? root.service.accent : Color.accent
            font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
          }
          Text {
            width: parent.width
            text: root.editing ? root.editing.body : (root.replyTo ? root.replyTo.body : "")
            color: root.fg; opacity: 0.7
            elide: Text.ElideRight
            font.family: root.fontFamily; font.pixelSize: Style.font.caption
          }
        }
        Button { id: stripClose; anchors.verticalCenter: parent.verticalCenter; iconText: "󰅖"; text: ""; onClicked: root.cancelCompose() }
      }
    }

    Row {
      id: composerRow
      width: parent.width
      spacing: Style.spacing.controlGap
      Button {
        id: attachButton
        anchors.bottom: parent.bottom
        iconText: "󰁦"
        text: ""
        enabled: !root.busy && root.roomId !== ""
        onClicked: fileDialog.open()
      }
      Button {
        id: emojiButton
        anchors.bottom: parent.bottom
        iconText: "󰞅"
        text: ""
        visible: !root.recordingHere
        enabled: !root.busy && root.roomId !== ""
        onClicked: { composer.forceActiveFocus(); root.service.openEmojiPicker() }
      }
      Button {
        id: micButton
        anchors.bottom: parent.bottom
        iconText: "󰍬"
        text: ""
        visible: !root.recordingHere
        enabled: !root.busy && root.roomId !== "" && root.service && !root.service.recording
        onClicked: root.startVoice()
      }
      // Recording: a pulsing dot and the clock take the composer's place.
      Rectangle {
        id: recordStrip
        visible: root.recordingHere
        anchors.bottom: parent.bottom
        width: parent.width - sendButton.width - attachButton.width - cancelRecord.width - 3 * Style.spacing.controlGap
        height: composer.implicitHeight
        radius: Style.cornerRadius
        color: Util.alpha(Color.urgent, 0.10)
        border.width: 1
        border.color: Util.alpha(Color.urgent, 0.5)
        // The composer is hidden meanwhile, so the strip takes the keys.
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { event.accepted = true; root.service.stopRecording(true) }
          else if (event.key === Qt.Key_Escape) { event.accepted = true; root.service.stopRecording(false) }
        }
        Row {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.leftMargin: Style.space(12)
          anchors.rightMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(10)
          Rectangle {
            id: recordDot
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(10); height: width; radius: width / 2
            color: Color.urgent
            SequentialAnimation on opacity {
              loops: Animation.Infinite
              running: root.recordingHere
              NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutSine }
              NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
            }
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - recordDot.width - parent.spacing
            elide: Text.ElideRight
            text: "Recording  " + Format.clock(root.service ? root.service.recordSeconds : 0)
              + "   <font color=\"" + Util.alpha(root.fg, 0.55) + "\">Enter sends · Esc discards</font>"
            textFormat: Text.StyledText
            color: root.fg
            font.family: root.fontFamily; font.pixelSize: Style.font.body
          }
        }
      }
      Button {
        id: cancelRecord
        anchors.bottom: parent.bottom
        visible: root.recordingHere
        iconText: "󰅖"
        text: ""
        onClicked: root.service.stopRecording(false)
      }
      Composer {
        id: composer
        visible: !root.recordingHere
        width: parent.width - sendButton.width - attachButton.width - emojiButton.width - micButton.width - 4 * Style.spacing.controlGap
        maximumLength: 4000
        foreground: root.fg
        accent: root.service ? root.service.accent : Color.accent
        placeholderText: root.uploads > 0 ? "Sending " + root.uploads + " file" + (root.uploads === 1 ? "" : "s") + "…"
          : root.editing ? "Edit your message…" : root.replyTo ? "Write a reply…"
          : root.inThread ? "Reply in thread…"
          : (root.encrypted ? "Encrypted message…" : "Message (not encrypted)…")
        enabled: !root.busy && root.roomId !== ""
        onAccepted: { if (root.emojiHits.length) root.insertEmoji(root.emojiIndex); else root.send() }
        onTextChanged: { root.noteTyping(); root.updateEmojiHints() }
        onCursorPositionChanged: root.updateEmojiHints()
        onKeyPressed: function(event) {
          if (root.emojiHits.length) {
            if (event.key === Qt.Key_Tab) { event.accepted = true; root.insertEmoji(root.emojiIndex); return }
            if (event.key === Qt.Key_Down || event.key === Qt.Key_Right) { event.accepted = true; root.emojiIndex = (root.emojiIndex + 1) % root.emojiHits.length; return }
            if (event.key === Qt.Key_Up || event.key === Qt.Key_Left) { event.accepted = true; root.emojiIndex = (root.emojiIndex + root.emojiHits.length - 1) % root.emojiHits.length; return }
            if (event.key === Qt.Key_Escape) { event.accepted = true; root.emojiHits = []; root.emojiStart = -1; return }
          }
          if (event.key === Qt.Key_V && (event.modifiers & Qt.ControlModifier)) {
            event.accepted = true
            if (!pasteProc.running) pasteProc.running = true
          } else if (event.key === Qt.Key_M && (event.modifiers & Qt.ControlModifier)) {
            // Ctrl+M: record a voice message from the keyboard.
            event.accepted = true
            root.startVoice()
          } else if (event.key === Qt.Key_Escape && (root.replyTo || root.editing)) {
            event.accepted = true
            root.cancelCompose()
          } else if (event.key === Qt.Key_Escape && root.inThread) {
            event.accepted = true
            root.closeRequested()
          } else if (event.key === Qt.Key_Up && composer.text === "" && !root.editing) {
            // Up in an empty composer edits your last message, like Slack/Element.
            for (var i = msgModel.count - 1; i >= 0; i--) {
              var it = msgModel.get(i)
              if (it.mine && it.attachmentJson === "") { event.accepted = true; root.startEdit({ event_id: it.eventId, body: it.body }); break }
            }
          }
        }
      }
      Button {
        id: sendButton
        anchors.bottom: parent.bottom
        text: root.busy ? "…" : (root.editing ? "Save" : "Send")
        iconText: root.editing ? "󰄬" : "󰒊"
        enabled: !root.busy && root.roomId !== ""
        onClicked: root.recordingHere ? root.service.stopRecording(true) : root.send()
      }
    }

    Text {
      id: errorLabel
      width: parent.width
      wrapMode: Text.WordWrap
      visible: root.errorText !== ""
      height: visible ? implicitHeight : 0
      text: root.errorText
      color: Color.urgent
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Row {
      id: leaveButton
      visible: root.showLeave && !root.inThread && root.roomId !== ""
      spacing: Style.spacing.controlGap
      property bool confirm: false
      Button {
        visible: !leaveButton.confirm
        text: "Leave room"
        enabled: !root.busy
        onClicked: leaveButton.confirm = true
      }
      Text {
        visible: leaveButton.confirm
        anchors.verticalCenter: parent.verticalCenter
        text: "Leave " + root.roomName + "?"
        color: root.fg
        font.family: root.fontFamily; font.pixelSize: Style.font.caption
      }
      Button { visible: leaveButton.confirm; text: root.busy ? "…" : "Leave"; bordered: true; enabled: !root.busy; onClicked: { leaveButton.confirm = false; root.leave() } }
      Button { visible: leaveButton.confirm; text: "Stay"; onClicked: leaveButton.confirm = false }
    }
  }

  // Overlays over the bottom of the message list. They live outside the
  // Column because a positioner does not place zero-height children.
  Rectangle {
    id: emojiPop
    visible: root.emojiHits.length > 0
    x: column.x + msgList.x
    y: column.y + msgList.y + msgList.height - height - Style.space(8)
    width: Math.min(msgList.width, hintRow.implicitWidth + Style.space(12))
    height: Style.space(48)
    radius: Style.space(10)
    color: root.service ? root.service.bg : Color.background
    border.width: 1
    border.color: Util.alpha(root.fg, 0.25)
    Row {
      id: hintRow
      anchors.centerIn: parent
      spacing: Style.space(2)
      Repeater {
        model: root.emojiHits
        delegate: Rectangle {
          required property var modelData
          required property int index
          width: Math.max(hintLabel.implicitWidth, Style.space(40)) + Style.space(10)
          height: Style.space(40)
          radius: Style.space(7)
          color: index === root.emojiIndex ? Util.alpha(root.service ? root.service.accent : Color.accent, 0.22)
               : (hintMouse.containsMouse ? (root.service ? root.service.hover : Util.alpha(root.fg, 0.06)) : "transparent")
          border.width: index === root.emojiIndex ? 1 : 0
          border.color: root.service ? root.service.accent : Color.accent
          Column {
            id: hintCol
            anchors.centerIn: parent
            spacing: 0
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.e; font.pixelSize: Style.space(17) }
            Text {
              id: hintLabel
              anchors.horizontalCenter: parent.horizontalCenter
              text: ":" + (modelData.k.length > 14 ? modelData.k.substring(0, 13) + "…" : modelData.k)
              color: root.fg; opacity: 0.6
              font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2
            }
          }
          MouseArea { id: hintMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.insertEmoji(index) }
        }
      }
    }
  }

  // "N new messages" pill when new messages arrived below the fold
  Rectangle {
    visible: root.pendingNew > 0 && !root.atEnd
    x: column.x + msgList.x + (msgList.width - width) / 2
    y: column.y + msgList.y + msgList.height - height - Style.space(10)
    width: pillText.implicitWidth + Style.space(28)
    height: Style.space(32)
    radius: height / 2
    color: root.service ? root.service.accent : Color.accent
    Text {
      id: pillText
      anchors.centerIn: parent
      text: "󰁅  " + root.pendingNew + " new message" + (root.pendingNew === 1 ? "" : "s")
      color: root.service ? root.service.bg : Color.background
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.jumpToNew() }
  }
}
