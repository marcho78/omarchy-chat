import QtQuick
import QtQuick.Dialogs
import Quickshell.Io
import "Format.js" as Format

// Everything a conversation view does that is not drawing: the message
// model, paging, live events, drafts, replies and edits, reactions, read
// marking, typing notices, emoji completion, voice notes, attachments.
// Both looks put one of these behind their RoomView and bind their visuals
// to it, so behaviour is written once.
//
// The view tells the session three things it cannot know: which composer
// holds the text (`composer`), whether the view is on screen
// (`viewVisible`) and whether the list is scrolled to its end (`atEnd`).
// The session asks the view for the few things only a list can do through
// signals: anchor to the end, reveal a row, keep its place while older
// rows are inserted above.
Item {
  id: session
  width: 0
  height: 0

  property var service: null
  property string viewId: "room"
  // The view's composer: needs text, cursorPosition, forceActiveFocus(), paste().
  property var composer: null
  property bool viewVisible: false
  property bool atEnd: true

  property var room: null
  readonly property string roomId: room ? String(room.id) : ""
  readonly property string roomName: room ? String(room.name) : ""
  readonly property bool encrypted: room ? room.encrypted === true : false
  property bool busy: false
  property string errorText: ""

  signal roomLeft()
  // Esc in a thread with nothing to cancel: the host closes the thread.
  signal closeRequested()
  // Scroll the list to its end (a settle pass follows in the view).
  signal anchorEnd()
  // Bring row `index` into view: mode 0 at the top, 1 centred.
  signal reveal(int index, int mode)
  // Older rows are about to be inserted above / were inserted.
  signal prependStarted()
  signal prependFinished(int count)
  signal focusComposerRequested()
  signal focusRecordingRequested()

  // Thread mode: this session shows one thread of `room` instead of the room.
  // Replies come from the `thread` command, sends go into the thread, and
  // nothing here marks the room read.
  property string threadRoot: ""
  readonly property bool inThread: threadRoot !== ""
  readonly property string draftKey: roomId + (inThread ? "#" + threadRoot : "")
  property bool _stashed: false

  ListModel { id: msgModel }
  readonly property alias model: msgModel
  readonly property int count: msgModel.count

  // Paging: `nextToken` points at the page before the oldest loaded one;
  // empty once history is exhausted.
  property string nextToken: ""
  property bool loadingOlder: false
  readonly property bool hasOlder: nextToken !== ""

  // ---------- read state ----------
  // A message counts as read only when the view is on screen and the list
  // is at its end. Otherwise it stays unread and the pill offers to jump.
  property int pendingNew: 0
  property string lastEventId: ""
  property string readUpTo: ""
  property bool stickToEnd: false
  function maybeMarkRead() {
    if (!session.roomId || !session.viewVisible || !session.atEnd || session.lastEventId === "") return
    if (session.pendingNew === 0 && session.readUpTo === session.lastEventId) return
    session.pendingNew = 0
    session.readUpTo = session.lastEventId
    if (session.inThread) session.service.markThreadRead(session.roomId, session.threadRoot, session.lastEventId)
    else session.service.markRead(session.roomId, session.lastEventId)
  }
  onAtEndChanged: if (atEnd) maybeMarkRead()
  onViewVisibleChanged: {
    if (session.service && !session.inThread) session.service.setViewing(session.viewId, viewVisible ? session.roomId : "")
    if (viewVisible) Qt.callLater(maybeMarkRead)
  }
  function jumpToNew() { session.stickToEnd = true; session.anchorEnd() }

  // ---------- opening ----------
  property string pendingJump: ""
  function openAt(r, eventId) {
    session.open(r)
    session.pendingJump = eventId
  }
  function openThread(r, rootId) {
    // Stash under the thread we are leaving, before the key changes.
    session.stashDraft()
    session._stashed = true
    session.threadRoot = rootId
    session.open(r)
  }

  function open(r) {
    if (!session._stashed) session.stashDraft()
    session._stashed = false
    session.room = r
    session.errorText = ""
    session.pendingJump = ""
    session.jumpTarget = ""
    session.nextToken = ""
    session.loadingOlder = false
    session.pendingNew = 0
    session.lastEventId = ""
    session.readUpTo = ""
    session.typingUsers = []
    session.reactionIndex = ({})
    session.confirmDelete = null
    msgModel.clear()
    if (!session.inThread) session.service.setViewing(session.viewId, session.roomId)
    session.restoreDraft()
    var id = session.roomId
    var marker = session.inThread ? "" : (r.read_marker || "")
    var thread = session.threadRoot
    var load = session.inThread
      ? function(cb) { session.service.thread(id, thread, 60, "", cb) }
      : function(cb) { session.service.timeline(id, 60, "", cb) }
    load(function(res) {
      if (session.roomId !== id || session.threadRoot !== thread) return
      if (!res.ok) { session.errorText = res.error || "Could not load messages"; return }
      var list = res.result.messages
      session.nextToken = res.result.next || ""
      if (list.length === 0) return
      var dividerAt = -1
      for (var i = 0; i < list.length; i++) {
        session.append(list[i])
        // First message after our marker, from someone else, starts the unread run.
        if (dividerAt === -1 && marker !== "" && i > 0 && list[i - 1].event_id === marker && list[i].sender !== session.service.userId) dividerAt = i
      }
      session.lastEventId = list[list.length - 1].event_id
      session.readUpTo = marker
      if (session.pendingJump !== "") {
        var target = session.pendingJump
        session.pendingJump = ""
        session.stickToEnd = false
        Qt.callLater(function() { session.jumpTo(target) })
      } else if (dividerAt > 0) {
        msgModel.setProperty(dividerAt, "newDivider", true)
        msgModel.setProperty(dividerAt, "header", true)
        session.stickToEnd = false
        Qt.callLater(function() { session.reveal(dividerAt, 0); Qt.callLater(session.maybeMarkRead) })
      } else {
        session.stickToEnd = true
        Qt.callLater(session.anchorEnd)
      }
      Qt.callLater(session.focusComposerRequested)
    })
  }

  function loadOlder() {
    if (!session.hasOlder || session.loadingOlder || !session.roomId) return
    session.loadingOlder = true
    var id = session.roomId
    var token = session.nextToken
    var thread = session.threadRoot
    var load = session.inThread
      ? function(cb) { session.service.thread(id, thread, 60, token, cb) }
      : function(cb) { session.service.timeline(id, 60, token, cb) }
    load(function(res) {
      session.loadingOlder = false
      if (session.roomId !== id || session.threadRoot !== thread) return
      if (!res.ok) { session.errorText = res.error || "Could not load earlier messages"; return }
      session.nextToken = res.result.next || ""
      session.prepend(res.result.messages)
      if (session.jumpTarget !== "") {
        var t = session.jumpTarget
        var idx = session.indexOfEvent(t)
        if (idx >= 0) { session.jumpTarget = ""; Qt.callLater(function() { session.jumpTo(t) }) }
        else Qt.callLater(session.loadOlderForJump)
      }
    })
  }

  // Keep what was typed in the room we are leaving; an edit in progress is
  // dropped (it is the message's own text), a reply keeps its draft.
  function stashDraft() {
    if (session.roomId === "" || !session.service || !session.composer) return
    session.service.setDraft(session.draftKey, session.editing ? "" : session.composer.text)
    session.composer.text = ""
  }
  function restoreDraft() {
    if (!session.service || !session.composer) return
    var d = session.service.draft(session.draftKey)
    session.composer.text = d
    session.composer.cursorPosition = d.length
  }

  function close() {
    session.stashDraft()
    session.setTyping(false)
    session.room = null
    session.replyTo = null
    session.editing = null
    session.typingUsers = []
    msgModel.clear()
    if (!session.inThread) session.service.setViewing(session.viewId, "")
    session.threadRoot = ""
  }

  // ---------- the model ----------
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
    var idx = session.reactionIndex
    for (var i = 0; i < list.length; i++)
      for (var j = 0; j < list[i].senders.length; j++) {
        var sd = list[i].senders[j]
        if (sd.reaction_id) idx[sd.reaction_id] = { eventId: m.event_id, key: list[i].key, user: { id: sd.id, name: sd.name } }
      }
    session.reactionIndex = idx
  }
  function entryFor(m, meta) {
    session.indexReactions(m)
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
      mine: m.sender === session.service.userId,
      encrypted: m.encrypted === true,
      header: meta.header,
      dayLabel: meta.dayLabel,
      newDivider: false,
      threadRoot: m.thread_root || "",
      threadJson: m.thread ? JSON.stringify(m.thread) : ""
    }
  }

  // Older messages go in at the top; the view keeps its place by growing
  // contentY by exactly what was added above it (prependStarted/Finished).
  function prepend(list) {
    if (list.length === 0) return
    session.stickToEnd = false
    session.prependStarted()
    var prev = null
    for (var i = 0; i < list.length; i++) {
      var meta = session.metaFor(prev, list[i])
      msgModel.insert(i, session.entryFor(list[i], meta))
      prev = { ts: Number(list[i].ts) || 0, sender: list[i].sender, msgtype: list[i].msgtype }
    }
    // The item that used to be first is now preceded by real history.
    if (msgModel.count > list.length) {
      var first = msgModel.get(list.length)
      var m2 = session.metaFor(prev, { ts: first.ts, sender: first.sender, msgtype: first.msgtype })
      msgModel.setProperty(list.length, "header", m2.header)
      msgModel.setProperty(list.length, "dayLabel", m2.dayLabel)
    }
    session.prependFinished(list.length)
  }

  function append(m) {
    var prev = msgModel.count > 0 ? msgModel.get(msgModel.count - 1) : null
    msgModel.append(session.entryFor(m, session.metaFor(prev, m)))
  }

  // A reply arrived in a thread whose root is on screen: bump its summary.
  function bumpThread(m) {
    var i = session.indexOfEvent(m.thread_root)
    if (i < 0) return
    var cur = msgModel.get(i).threadJson
    var t = cur !== "" ? JSON.parse(cur) : { replies: 0 }
    t.replies = (t.replies || 0) + 1
    if (m.sender !== session.service.userId) t.unread = (t.unread || 0) + 1
    t.latest_ts = Number(m.ts) || Date.now()
    t.latest_sender = m.sender
    t.latest_sender_name = m.sender_name || m.sender
    msgModel.setProperty(i, "threadJson", JSON.stringify(t))
  }

  function indexOfEvent(eventId) {
    for (var i = 0; i < msgModel.count; i++) if (msgModel.get(i).eventId === eventId) return i
    return -1
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
  Timer { id: typingStop; interval: 5000; onTriggered: session.setTyping(false) }
  function setTyping(on) {
    if (!session.roomId || on === session.typingSent) return
    session.typingSent = on
    session.service.typing(session.roomId, on)
  }
  function noteTyping() {
    if (!session.roomId || !session.composer) return
    if (session.composer.text.length > 0) { session.setTyping(true); typingStop.restart() }
    else { typingStop.stop(); session.setTyping(false) }
  }

  function toggleReaction(eventId, key) {
    var i = session.indexOfEvent(eventId)
    if (i < 0) return
    var list = JSON.parse(msgModel.get(i).reactionsJson)
    for (var k = 0; k < list.length; k++) {
      if (list[k].key === key && list[k].mine) {
        var rid = list[k].mine
        session.service.unreact(session.roomId, rid, function(r) { if (!r.ok) session.errorText = r.error || "Could not remove reaction" })
        session.applyReaction(eventId, key, { id: session.service.userId, name: "you" }, rid, false)
        return
      }
    }
    session.service.react(session.roomId, eventId, key, function(r) {
      if (!r.ok) { session.errorText = r.error || "Could not react"; return }
      var idx = session.reactionIndex; idx[r.result.reaction_id] = { eventId: eventId, key: key, user: { id: session.service.userId, name: "you" } }; session.reactionIndex = idx
      session.applyReaction(eventId, key, { id: session.service.userId, name: "you" }, r.result.reaction_id, true)
    })
  }

  // Add or remove one user's reaction in the model.
  function applyReaction(eventId, key, user, reactionId, add) {
    var i = session.indexOfEvent(eventId)
    if (i < 0) return
    var list = JSON.parse(msgModel.get(i).reactionsJson)
    var mine = user.id === session.service.userId
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
    target: session.service
    function onReactionReceived(r) {
      if (!session.roomId || r.room !== session.roomId) return
      var idx = session.reactionIndex; idx[r.reaction_id] = { eventId: r.event_id, key: r.key, user: r.sender }; session.reactionIndex = idx
      session.applyReaction(r.event_id, r.key, r.sender, r.reaction_id, true)
    }
    function onRedacted(x) {
      if (!session.roomId || x.room !== session.roomId) return
      var ref = session.reactionIndex[x.event_id]
      if (ref) { session.applyReaction(ref.eventId, ref.key, ref.user, x.event_id, false); return }
      var i = session.indexOfEvent(x.event_id)
      if (i >= 0) { msgModel.setProperty(i, "deleted", true); msgModel.setProperty(i, "edited", false); msgModel.setProperty(i, "body", ""); msgModel.setProperty(i, "html", ""); msgModel.setProperty(i, "attachmentJson", ""); msgModel.setProperty(i, "reactionsJson", "[]") }
    }
    function onTypingChanged(t) {
      if (!session.roomId || t.room !== session.roomId) return
      session.typingUsers = t.users
    }
    function onReceiptMoved(rc) {
      if (!session.roomId || rc.room !== session.roomId) return
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
      if (!session.roomId || e.room !== session.roomId) return
      var i = session.indexOfEvent(e.event_id)
      if (i < 0) return
      msgModel.setProperty(i, "body", e.body)
      msgModel.setProperty(i, "html", e.html || "")
      msgModel.setProperty(i, "edited", true)
    }
    function onThreadRead(roomId, rootId) {
      if (session.inThread || roomId !== session.roomId) return
      var i = session.indexOfEvent(rootId)
      if (i < 0) return
      var cur = msgModel.get(i).threadJson
      if (cur === "") return
      var t = JSON.parse(cur); t.unread = 0
      msgModel.setProperty(i, "threadJson", JSON.stringify(t))
    }
    function onMessageReceived(m) {
      if (!session.roomId || m.room !== session.roomId) return
      // Thread replies belong to their thread; the room only counts them.
      if (session.inThread) { if (m.thread_root !== session.threadRoot) return }
      else if (m.thread_root) { session.bumpThread(m); return }
      var wasAtEnd = session.atEnd
      session.append(m)
      session.lastEventId = m.event_id
      if (m.sender === session.service.userId || (wasAtEnd && session.viewVisible)) {
        session.stickToEnd = true
        Qt.callLater(session.anchorEnd)
      } else {
        session.pendingNew++
      }
    }
    function onVoiceSent(roomId, ok, error) {
      if (roomId !== session.roomId) return
      session.uploads = Math.max(0, session.uploads - 1)
      if (!ok) session.errorText = error
      else Qt.callLater(session.anchorEnd)
      session.focusComposerRequested()
    }
    function onRecordingChanged() {
      if (session.service && !session.service.recording) {
        // Cancelled (not sent): drop the pending upload marker.
        if (!session.service.recordSend && session.uploads > 0) session.uploads = Math.max(0, session.uploads - 1)
        session.focusComposerRequested()
      }
    }
  }

  // ---------- emoji completion ----------
  // Typing ":smi" offers emoji; Tab/Enter inserts the highlighted one.
  property var emojiHits: []
  property int emojiIndex: 0
  property int emojiStart: -1
  function updateEmojiHints() {
    if (!session.composer) return
    var t = session.composer.text, c = session.composer.cursorPosition
    var i = c - 1
    while (i >= 0 && /[a-z0-9_+-]/i.test(t.charAt(i))) i--
    if (i >= 0 && t.charAt(i) === ":" && (i === 0 || /\s/.test(t.charAt(i - 1)))) {
      var word = t.substring(i + 1, c)
      session.emojiHits = session.service.emojiSuggestions(word, 6)
      session.emojiStart = session.emojiHits.length ? i : -1
      session.emojiIndex = 0
    } else { session.emojiHits = []; session.emojiStart = -1 }
  }
  function insertEmoji(idx) {
    if (!session.composer || session.emojiStart < 0 || idx < 0 || idx >= session.emojiHits.length) return
    var t = session.composer.text, c = session.composer.cursorPosition, start = session.emojiStart
    var e = session.emojiHits[idx].e + " "
    // Setting the text re-runs the hint scan (which clears emojiStart), so
    // place the cursor from the saved start.
    session.composer.text = t.substring(0, start) + e + t.substring(c)
    session.composer.cursorPosition = start + e.length
    session.emojiHits = []; session.emojiStart = -1
  }

  // ---------- reply / edit ----------
  // One of these at a time; the strip above the composer shows which.
  property var replyTo: null      // {event_id, sender_name, body}
  property var editing: null      // {event_id, body}
  function startReply(m) { session.editing = null; session.replyTo = m; session.focusComposerRequested() }
  function startEdit(m) {
    session.replyTo = null; session.editing = m
    if (session.composer) { session.composer.text = m.body; session.composer.cursorPosition = session.composer.text.length }
    session.focusComposerRequested()
  }
  function cancelCompose() { if (session.editing && session.composer) session.composer.text = ""; session.replyTo = null; session.editing = null }
  // Up in an empty composer edits your last message, like Slack/Element.
  function editLastOwn() {
    for (var i = msgModel.count - 1; i >= 0; i--) {
      var it = msgModel.get(i)
      if (it.mine && it.attachmentJson === "") { session.startEdit({ event_id: it.eventId, body: it.body }); return true }
    }
    return false
  }
  property var confirmDelete: null
  function deleteMessage(eventId) {
    session.service.deleteMessage(session.roomId, eventId, function(r) {
      if (!r.ok) session.errorText = r.error || "Could not delete"
    })
    session.confirmDelete = null
  }

  // ---------- jumping ----------
  property int flashIndex: -1
  Timer { id: flashTimer; interval: 1200; onTriggered: session.flashIndex = -1 }
  function jumpTo(eventId) {
    var i = session.indexOfEvent(eventId)
    if (i >= 0) { session.stickToEnd = false; session.reveal(i, 1); session.flashIndex = i; flashTimer.restart(); return }
    // Not loaded yet: page back until it is, within reason.
    session.jumpTarget = eventId
    session.jumpPagesLeft = 15
    session.loadOlderForJump()
  }
  property string jumpTarget: ""
  property int jumpPagesLeft: 0
  function loadOlderForJump() {
    if (session.jumpTarget === "" || session.jumpPagesLeft <= 0 || !session.hasOlder || session.loadingOlder) { if (session.jumpTarget !== "" && !session.loadingOlder) { session.jumpTarget = ""; session.errorText = "That message is further back than could be loaded" } return }
    session.jumpPagesLeft--
    session.loadOlder()
  }

  // ---------- sending ----------
  function send() {
    if (!session.composer) return
    var text = session.composer.text
    if (text.trim() === "" || !session.roomId || session.busy) return
    typingStop.stop(); session.setTyping(false)
    session.busy = true
    if (session.editing) {
      var target = session.editing.event_id
      session.service.edit(session.roomId, target, text, function(r) {
        session.busy = false
        if (!r.ok) { session.errorText = r.error || "Edit failed"; return }
        session.composer.text = ""; session.errorText = ""; session.editing = null
        var i = session.indexOfEvent(target)
        if (i >= 0) { msgModel.setProperty(i, "body", text); msgModel.setProperty(i, "html", ""); msgModel.setProperty(i, "edited", true) }
      })
      return
    }
    var reply = session.replyTo ? session.replyTo.event_id : ""
    var deliver = session.inThread
      ? function(cb) { session.service.sendInThread(session.roomId, session.threadRoot, text, reply, cb) }
      : function(cb) { session.service.send(session.roomId, text, reply, cb) }
    deliver(function(r) {
      session.busy = false
      if (!r.ok) session.errorText = r.error || "Send failed"
      else { session.composer.text = ""; session.service.setDraft(session.draftKey, ""); session.errorText = ""; session.replyTo = null; Qt.callLater(session.anchorEnd) }
    })
  }
  // Enter: an emoji pick if one is highlighted, else the message.
  function accept() { if (session.emojiHits.length) session.insertEmoji(session.emojiIndex); else session.send() }

  // The composer's keys that mean something beyond typing. Returns true
  // when handled (the caller sets event.accepted).
  function handleComposerKey(event) {
    if (session.emojiHits.length) {
      if (event.key === Qt.Key_Tab) { session.insertEmoji(session.emojiIndex); return true }
      if (event.key === Qt.Key_Down || event.key === Qt.Key_Right) { session.emojiIndex = (session.emojiIndex + 1) % session.emojiHits.length; return true }
      if (event.key === Qt.Key_Up || event.key === Qt.Key_Left) { session.emojiIndex = (session.emojiIndex + session.emojiHits.length - 1) % session.emojiHits.length; return true }
      if (event.key === Qt.Key_Escape) { session.emojiHits = []; session.emojiStart = -1; return true }
    }
    if (event.key === Qt.Key_V && (event.modifiers & Qt.ControlModifier)) { session.pasteOrSend(); return true }
    if (event.key === Qt.Key_M && (event.modifiers & Qt.ControlModifier)) { session.startVoice(); return true }
    if (event.key === Qt.Key_Escape && (session.replyTo || session.editing)) { session.cancelCompose(); return true }
    if (event.key === Qt.Key_Escape && session.inThread) { session.closeRequested(); return true }
    if (event.key === Qt.Key_Up && session.composer && session.composer.text === "" && !session.editing) return session.editLastOwn()
    return false
  }

  // ---------- voice messages ----------
  readonly property bool recordingHere: session.service && session.service.recording && session.service.recordingRoom === session.roomId
  function startVoice() {
    if (!session.service || session.roomId === "" || session.service.recording) return
    session.errorText = ""
    session.service.startRecording(session.roomId)
    session.uploads++
    Qt.callLater(session.focusRecordingRequested)
  }
  function stopVoice(send) { if (session.service) session.service.stopRecording(send === true) }

  // ---------- attachments ----------
  property int uploads: 0
  function sendFiles(paths) {
    for (var i = 0; i < paths.length; i++) {
      var p = String(paths[i]).replace(/^file:\/\//, "")
      if (p === "") continue
      session.uploads++
      session.service.sendFile(session.roomId, p, "", function(r) {
        session.uploads--
        if (!r.ok) session.errorText = r.error || "Could not send the file"
      })
    }
  }
  function attach() { fileDialog.open() }
  FileDialog {
    id: fileDialog
    title: "Send a file"
    fileMode: FileDialog.OpenFiles
    onAccepted: session.sendFiles(selectedFiles)
  }

  // Ctrl+V with an image on the clipboard sends it; otherwise it pastes text.
  function pasteOrSend() { if (!pasteProc.running) pasteProc.running = true }
  Process {
    id: pasteProc
    property string out: ""
    command: ["/usr/bin/bash", "-c",
      "if wl-paste -l 2>/dev/null | grep -q '^image/'; then f=\"${XDG_RUNTIME_DIR:-/tmp}/yapper-paste-$(date +%s%N).png\"; wl-paste -t image/png > \"$f\" && echo \"$f\"; fi"]
    stdout: SplitParser { splitMarker: ""; onRead: function(d) { pasteProc.out += d } }
    onStarted: out = ""
    onExited: function() {
      var p = pasteProc.out.trim()
      if (p !== "") session.sendFiles([p])
      else if (session.composer) session.composer.paste()
    }
  }

  function leave() {
    if (!session.roomId || session.busy) return
    session.busy = true
    session.service.leave(session.roomId, function(r) {
      session.busy = false
      if (!r.ok) { session.errorText = r.error || "Could not leave"; return }
      session.close()
      session.roomLeft()
    })
  }
}
