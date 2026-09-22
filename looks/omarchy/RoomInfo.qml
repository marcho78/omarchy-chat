import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "../../shared"
import "../../shared/Format.js" as Format

// Room details and members. Used as the window's side pane and the popup's
// members view. Set `roomId` to load; `close()` clears.
Item {
  id: root
  property var service: null
  property color fg: Color.foreground
  property string fontFamily: Style.font.family
  property string roomId: ""
  property bool compact: false

  property var details: null
  property var members: []
  property bool loading: false
  property string errorText: ""

  signal closeRequested()
  signal memberChosen(var member)
  property bool confirmBlock: false
  onMemberChanged: confirmBlock = false
  signal leftRoom()

  property string editing: ""         // "" | "name" | "topic" | "invite"
  property var member: null           // member sheet
  property bool confirmLeave: false
  property bool busy: false
  function fail(msg) { root.errorText = msg }

  readonly property bool hasTextFocus: search.activeFocus || editField.activeFocus || reasonField.activeFocus
  readonly property color accent: service ? service.accent : Color.accent

  onRoomIdChanged: reload()
  function reload() {
    root.details = null
    root.members = []
    root.errorText = ""
    root.editing = ""
    root.member = null
    root.confirmLeave = false
    if (!root.roomId || !root.service) return
    root.loading = true
    var id = root.roomId
    root.service.roomDetails(id, function(r) {
      if (root.roomId !== id) return
      if (!r.ok) { root.loading = false; root.errorText = r.error || "Could not load the room"; return }
      root.details = r.result
      root.loadMembers()
    })
  }
  function loadMembers() {
    var id = root.roomId
    root.service.members(id, search.text, 300, function(r) {
      if (root.roomId !== id) return
      root.loading = false
      if (!r.ok) { root.errorText = r.error || "Could not load members"; return }
      root.members = r.result
    })
  }
  Timer { id: searchDebounce; interval: 250; onTriggered: root.loadMembers() }

  function startEdit(kind) {
    root.editing = kind
    root.errorText = ""
    editField.text = kind === "name" ? (root.details ? root.details.name : "") : kind === "topic" ? (root.details ? (root.details.topic || "") : "") : ""
    Qt.callLater(function() { editField.forceActiveFocus(); editField.selectAll() })
  }
  function commitEdit() {
    if (root.busy) return
    var v = editField.text
    root.busy = true
    var done = function(r) { root.busy = false; if (!r.ok) { root.fail(r.error || "That did not work"); return } root.editing = ""; root.reload() }
    if (root.editing === "name") root.service.setRoomName(root.roomId, v, done)
    else if (root.editing === "topic") root.service.setRoomTopic(root.roomId, v, done)
    else root.service.invite(root.roomId, v, done)
  }
  function act(kind) {
    if (root.busy || !root.member) return
    root.busy = true
    var done = function(r) { root.busy = false; if (!r.ok) { root.fail(r.error || "That did not work"); return } root.member = null; root.loadMembers() }
    if (kind === "kick") root.service.kick(root.roomId, root.member.id, reasonField.text, done)
    else root.service.ban(root.roomId, root.member.id, reasonField.text, done)
  }
  function doLeave() {
    if (root.busy) return
    root.busy = true
    root.service.leave(root.roomId, function(r) {
      root.busy = false
      if (!r.ok) { root.fail(r.error || "Could not leave"); return }
      root.confirmLeave = false
      root.leftRoom()
    })
  }

  Column {
    id: column
    anchors.fill: parent
    spacing: Style.space(10)

    // Header: avatar, name, close
    Item {
      width: parent.width
      implicitHeight: Math.max(headerCol.implicitHeight, Style.space(48))
      Avatar {
        id: roomAvatar
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        size: Style.space(48)
        userId: root.roomId
        name: root.details ? root.details.name : ""
        mxc: root.details && root.details.avatar ? root.details.avatar : ""
        service: root.service
        fontFamily: root.fontFamily
      }
      Column {
        id: headerCol
        anchors.left: roomAvatar.right
        anchors.leftMargin: Style.space(12)
        anchors.right: closeButton.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)
        Text {
          width: parent.width
          text: root.details ? root.details.name : "Room"
          color: root.fg
          font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true
          elide: Text.ElideRight
        }
        Text {
          width: parent.width
          text: {
            if (!root.details) return root.loading ? "Loading…" : ""
            var d = root.details
            var bits = [d.member_count + " member" + (d.member_count === 1 ? "" : "s")]
            bits.push(d.bridge ? (d.encrypted ? "󰌾 encrypted to the bridge" : "󰌿 not encrypted") : (d.encrypted ? "󰌾 encrypted" : "󰌿 not encrypted"))
            bits.push(d.join_rule === "public" ? "public" : d.join_rule === "invite" ? "invite only" : d.join_rule)
            return bits.join("  ·  ")
          }
          color: root.fg; opacity: 0.6
          font.family: root.fontFamily; font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
      Button {
        id: closeButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        iconText: "󰅖"
        text: ""
        onClicked: root.closeRequested()
      }
    }

    // Inline editor for name / topic / invite
    Column {
      width: parent.width
      spacing: Style.space(6)
      visible: root.editing !== ""
      Text {
        text: root.editing === "name" ? "Room name" : root.editing === "topic" ? "Topic" : "Invite by Matrix ID"
        color: root.fg
        font.family: root.fontFamily; font.pixelSize: Style.font.subtitle
      }
      TextField {
        id: editField
        width: parent.width
        maximumLength: root.editing === "topic" ? 2000 : 256
        placeholderText: root.editing === "invite" ? "@user:server" : ""
        enabled: !root.busy
        onAccepted: root.commitEdit()
      }
      Row {
        spacing: Style.spacing.controlGap
        Button { text: root.busy ? "…" : (root.editing === "invite" ? "Invite" : "Save"); bordered: true; enabled: !root.busy; onClicked: root.commitEdit() }
        Button { text: "Cancel"; enabled: !root.busy; onClicked: root.editing = "" }
      }
    }

    // Topic + alias
    Text {
      width: parent.width
      visible: root.details && !!root.details.topic && root.editing === ""
      wrapMode: Text.WordWrap
      maximumLineCount: root.compact ? 3 : 6
      elide: Text.ElideRight
      text: root.details ? Format.oneLine(root.details.topic) : ""
      color: root.fg; opacity: 0.8
      font.family: root.fontFamily; font.pixelSize: Style.font.body
    }
    Row {
      visible: root.details && !!root.details.alias
      spacing: Style.space(6)
      Text {
        text: root.details && root.details.alias ? String(root.details.alias) : ""
        color: root.accent
        font.family: root.fontFamily; font.pixelSize: Style.font.caption
      }
      Text {
        text: "󰆏"
        color: root.fg; opacity: 0.5
        font.family: root.fontFamily; font.pixelSize: Style.font.caption
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.service.copyText(root.details.alias) }
      }
    }

    // Bridged room: what it mirrors, and the bot that runs it
    Rectangle {
      readonly property var bridge: root.details ? root.details.bridge : null
      visible: bridge !== null && bridge !== undefined && root.editing === "" && root.member === null
      width: parent.width
      implicitHeight: visible ? bridgeCol.implicitHeight + Style.space(20) : 0
      radius: Style.space(8)
      color: Util.alpha(root.fg, 0.05)
      border.width: 1
      border.color: Util.alpha(root.fg, 0.18)
      Column {
        id: bridgeCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(10)
        spacing: Style.space(4)
        Row {
          spacing: Style.space(8)
          Text { anchors.verticalCenter: parent.verticalCenter; text: parent.parent.parent.bridge ? Format.bridgeGlyph(parent.parent.parent.bridge.protocol) : ""; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.subtitle }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            readonly property var b: parent.parent.parent.bridge
            text: b ? "Bridged to " + b.name + (b.channel ? " · " + b.channel : "") : ""
            color: root.fg
            font.family: root.fontFamily; font.pixelSize: Style.font.subtitle; font.bold: true
          }
        }
        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          readonly property var b: parent.parent.bridge
          text: (b && b.bridge ? "Run by " + b.bridge + ". " : "")
            + "Messages are relayed by the bridge, which reads them to forward them"
            + (root.details && root.details.encrypted ? " — Matrix encryption covers the leg to the bridge, not end to end." : ".")
          color: root.fg; opacity: 0.75
          font.family: root.fontFamily; font.pixelSize: Style.font.caption
        }
        Button {
          readonly property var b: parent.parent.bridge
          visible: !!(b && b.bot)
          text: "Message the bridge bot"
          iconText: "󰚩"
          bordered: true
          onClicked: root.memberChosen({ id: b.bot, name: b.bot })
        }
      }
    }

    // Actions
    Flow {
      width: parent.width
      spacing: Style.spacing.controlGap
      visible: root.details !== null && root.editing === "" && root.member === null
      Button {
        readonly property bool fav: (root.service && root.service.roomById(root.roomId) || {}).favourite === true
        text: fav ? "Favourite" : "Favourite"
        iconText: fav ? "󰓎" : "󰓒"
        bordered: fav
        onClicked: root.service.setFavourite(root.roomId, !fav)
      }
      Button { visible: root.details && root.details.can_invite; text: "Invite"; iconText: "󰀖"; bordered: true; onClicked: root.startEdit("invite") }
      Button { visible: root.details && root.details.can_set_name; text: "Rename"; iconText: "󰏫"; onClicked: root.startEdit("name") }
      Button { visible: root.details && root.details.can_set_topic; text: "Topic"; iconText: "󰏫"; onClicked: root.startEdit("topic") }
      Button { visible: !root.confirmLeave; text: "Leave"; iconText: "󰗼"; onClicked: root.confirmLeave = true }
    }

    // Leave confirmation
    Rectangle {
      width: parent.width
      visible: root.confirmLeave
      implicitHeight: visible ? leaveRow.implicitHeight + Style.space(12) : 0
      radius: Style.space(8)
      color: Util.alpha(Color.urgent, 0.12)
      border.width: 1
      border.color: Color.urgent
      Row {
        id: leaveRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.space(12)
        anchors.rightMargin: Style.space(8)
        spacing: Style.space(10)
        Text {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - Style.space(10) - leaveButtons.width
          wrapMode: Text.WordWrap
          text: "Leave " + (root.details ? root.details.name : "this room") + "? " + (root.details && root.details.join_rule === "public" ? "You can rejoin any time." : "You will need a new invitation to come back.")
          color: root.fg
          font.family: root.fontFamily; font.pixelSize: Style.font.caption
        }
        Row {
          id: leaveButtons
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.spacing.controlGap
          Button { text: root.busy ? "…" : "Leave"; bordered: true; enabled: !root.busy; onClicked: root.doLeave() }
          Button { text: "Stay"; enabled: !root.busy; onClicked: root.confirmLeave = false }
        }
      }
    }

    // Notifications for this room
    Row {
      width: parent.width
      spacing: Style.space(10)
      visible: root.details !== null && root.editing === "" && root.member === null
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "Notify"
        color: root.fg
        font.family: root.fontFamily; font.pixelSize: Style.font.caption
      }
      Dropdown {
        width: parent.width - Style.space(10) - Style.space(52)
        options: [{ value: "all", label: "All messages" }, { value: "mentions", label: "Mentions and keywords only" }, { value: "mute", label: "Muted" }]
        value: root.details ? root.details.notification_mode : "all"
        onChanged: function(v) { root.service.setNotificationMode(root.roomId, v, function(r) { if (!r.ok) root.fail(r.error || "Could not change notifications"); else root.details = r.result }) }
      }
    }

    // Member sheet
    Rectangle {
      width: parent.width
      visible: root.member !== null
      implicitHeight: visible ? sheet.implicitHeight + Style.space(24) : 0
      radius: Style.space(8)
      color: Util.alpha(root.fg, 0.05)
      border.width: 1
      border.color: Util.alpha(root.fg, 0.2)
      Column {
        id: sheet
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(12)
        spacing: Style.space(8)
        Row {
          width: parent.width
          spacing: Style.space(10)
          Avatar {
            anchors.verticalCenter: parent.verticalCenter
            size: Style.space(40)
            userId: root.member ? root.member.id : ""
            name: root.member ? root.member.name : ""
            mxc: root.member && root.member.avatar ? root.member.avatar : ""
            service: root.service
            fontFamily: root.fontFamily
          }
          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Style.space(40) - Style.space(10) - sheetClose.width - Style.space(10)
            Text { width: parent.width; text: root.member ? root.member.name : ""; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.subtitle; font.bold: true; elide: Text.ElideRight }
            Text { width: parent.width; text: root.member ? root.member.id + (root.member.via ? "  ·  via " + root.member.via : "") + (root.member.role !== "member" ? "  ·  " + (root.member.role === "admin" ? "Admin" : "Moderator") : "") : ""; color: root.fg; opacity: 0.6; font.family: root.fontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideMiddle }
          }
          Button { id: sheetClose; anchors.verticalCenter: parent.verticalCenter; iconText: "󰅖"; text: ""; onClicked: root.member = null }
        }
        TextField {
          id: reasonField
          width: parent.width
          visible: root.details && (root.details.can_kick || root.details.can_ban) && root.member && root.member.id !== root.service.userId
          placeholderText: "Reason (optional)"
          maximumLength: 256
        }
        Flow {
          width: parent.width
          spacing: Style.spacing.controlGap
          Button { text: "Message"; iconText: "󰭹"; bordered: true; visible: root.member && root.member.id !== root.service.userId && !root.confirmBlock; onClicked: root.memberChosen(root.member) }
          Button {
            readonly property bool isBlocked: root.member && root.service && root.service.blocked.indexOf(root.member.id) >= 0
            visible: root.member && root.member.id !== root.service.userId
            text: root.confirmBlock ? "Block " + root.member.name + "?" : (isBlocked ? "Unblock" : "Block")
            iconText: isBlocked ? "󰂬" : "󰂭"
            bordered: root.confirmBlock
            onClicked: {
              if (isBlocked) { root.service.unignore(root.member.id); return }
              if (!root.confirmBlock) { root.confirmBlock = true; return }
              root.confirmBlock = false
              root.service.ignore(root.member.id)
            }
          }
          Button { visible: root.confirmBlock; text: "Keep"; onClicked: root.confirmBlock = false }
          Button { text: "Copy ID"; iconText: "󰆏"; onClicked: root.service.copyText(root.member.id) }
          Button { visible: root.details && root.details.can_kick && root.member && root.member.id !== root.service.userId; text: root.busy ? "…" : "Remove"; enabled: !root.busy; onClicked: root.act("kick") }
          Button { visible: root.details && root.details.can_ban && root.member && root.member.id !== root.service.userId; text: root.busy ? "…" : "Ban"; enabled: !root.busy; onClicked: root.act("ban") }
        }
      }
    }

    PanelSeparator { width: parent.width }

    // Members
    Item {
      width: parent.width
      implicitHeight: search.implicitHeight
      PanelSectionHeader { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Members" + (root.details ? " · " + root.details.member_count : "") }
      TextField {
        id: search
        anchors.right: parent.right
        width: Math.min(parent.width * 0.55, Style.space(220))
        placeholderText: "Filter"
        maximumLength: 64
        onTextChanged: searchDebounce.restart()
      }
    }

    Text {
      width: parent.width
      visible: root.errorText !== ""
      wrapMode: Text.WordWrap
      text: root.errorText
      color: Color.urgent
      font.family: root.fontFamily; font.pixelSize: Style.font.caption
    }

    ListView {
      id: list
      width: parent.width
      height: parent.height - y
      clip: true
      spacing: Style.space(2)
      model: root.members
      boundsBehavior: Flickable.StopAtBounds
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
      delegate: Item {
        id: row
        required property var modelData
        width: list.width
        implicitHeight: Style.space(40)
        Rectangle {
          anchors.fill: parent
          radius: Style.space(6)
          color: mMouse.containsMouse ? (root.service ? root.service.hover : "transparent") : "transparent"
        }
        Row {
          anchors.fill: parent
          anchors.leftMargin: Style.space(6)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(10)
          Avatar {
            anchors.verticalCenter: parent.verticalCenter
            size: Style.space(28)
            userId: row.modelData.id
            name: row.modelData.name
            mxc: row.modelData.avatar || ""
            service: root.service
            fontFamily: root.fontFamily
          }
          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Style.space(28) - Style.space(10) - (roleBadge.visible ? roleBadge.width + Style.space(10) : 0)
            spacing: 0
            Text {
              width: parent.width
              text: row.modelData.name
              color: root.fg
              font.family: root.fontFamily; font.pixelSize: Style.font.body
              elide: Text.ElideRight
            }
            Text {
              width: parent.width
              text: (row.modelData.via ? "via " + row.modelData.via + "  ·  " : "") + row.modelData.id
              color: root.fg; opacity: 0.45
              font.family: root.fontFamily; font.pixelSize: Style.font.caption
              elide: Text.ElideMiddle
            }
          }
          Rectangle {
            id: roleBadge
            anchors.verticalCenter: parent.verticalCenter
            visible: row.modelData.role !== "member"
            width: roleText.implicitWidth + Style.space(10)
            height: Style.space(18)
            radius: Style.space(4)
            color: Util.alpha(root.accent, 0.18)
            border.width: 1
            border.color: root.accent
            Text {
              id: roleText
              anchors.centerIn: parent
              text: row.modelData.role === "admin" ? "Admin" : "Mod"
              color: root.accent
              font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true
            }
          }
        }
        MouseArea {
          id: mMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.member = row.modelData
        }
      }
      Text {
        anchors.centerIn: parent
        visible: root.members.length === 0 && !root.loading && root.details !== null
        text: search.text !== "" ? "No one matches" : "No members loaded"
        color: root.fg; opacity: 0.5
        font.family: root.fontFamily; font.pixelSize: Style.font.caption
      }
    }
  }
}
