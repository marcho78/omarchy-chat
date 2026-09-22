import QtQuick
import QtQuick.Controls
import "../../shared"
import "../../shared/Palettes.js" as Palettes
import "../../shared/Format.js" as Format

// Room info for the right panel: the room's picture, name, address and
// topic; notifications, favourite, address, rename, topic and leave;
// the bridge note; and the members with their roles. A member opens a
// sheet with message, block, copy and — with the power — remove or ban.
Item {
  id: root
  property var c: Palettes.fallback()
  property var tips: null
  property var service: null
  property string roomId: ""
  signal memberChosen(var member)
  signal leftRoom()
  Ui { id: ui }

  property var details: null
  property var members: []
  property bool loading: false
  property string errorText: ""
  property bool busy: false
  property string editing: ""          // "" | name | topic | invite
  property var member: null            // the open member sheet
  property bool confirmLeave: false
  property bool confirmBlock: false
  property bool pickingNotify: false
  readonly property int memberCount: details ? Number(details.member_count) || 0 : 0
  readonly property bool hasTextFocus: editField.hasFocus || reasonField.hasFocus || filterField.hasFocus
  readonly property var room: service ? service.roomById(roomId) : null
  readonly property bool favourite: room ? room.favourite === true : false
  readonly property string notifyMode: details ? String(details.notification_mode) : "all"
  readonly property var notifyOptions: [{ value: "all", label: "All messages" }, { value: "mentions", label: "Mentions only" }, { value: "mute", label: "Muted" }]
  function notifyLabel(mode) { for (var i = 0; i < notifyOptions.length; i++) if (notifyOptions[i].value === mode) return notifyOptions[i].label; return mode }
  function fail(msg) { root.busy = false; root.errorText = msg }

  onRoomIdChanged: reload()
  Component.onCompleted: reload()
  function reload() {
    root.details = null
    root.members = []
    root.errorText = ""
    root.editing = ""
    root.member = null
    root.confirmLeave = false
    root.pickingNotify = false
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
    root.service.members(id, filterField.text, 300, function(r) {
      if (root.roomId !== id) return
      root.loading = false
      if (!r.ok) { root.errorText = r.error || "Could not load members"; return }
      root.members = r.result
    })
  }
  Timer { id: filterDebounce; interval: 250; onTriggered: root.loadMembers() }

  function startEdit(kind) {
    root.editing = kind
    root.errorText = ""
    root.member = null
    editField.text = kind === "name" ? (root.details ? root.details.name : "") : kind === "topic" ? (root.details ? (root.details.topic || "") : "") : ""
    Qt.callLater(function() { editField.forceActiveFocus(); editField.selectAll() })
  }
  function commitEdit() {
    if (root.busy) return
    var v = editField.text.trim()
    if (v === "" && root.editing !== "topic") return
    root.busy = true
    var done = function(r) { root.busy = false; if (!r.ok) { root.fail(r.error || "That did not work"); return } root.editing = ""; root.reload() }
    if (root.editing === "name") root.service.setRoomName(root.roomId, v, done)
    else if (root.editing === "topic") root.service.setRoomTopic(root.roomId, v, done)
    else root.service.invite(root.roomId, v, done)
  }
  function setNotify(mode) {
    root.pickingNotify = false
    root.service.setNotificationMode(root.roomId, mode, function(r) {
      if (!r.ok) root.fail(r.error || "Could not change notifications"); else root.details = r.result
    })
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

  component Pill: Rectangle {
    property string label: ""
    property string icon: ""
    property bool primary: false
    property bool danger: false
    signal clicked()
    width: pillRow.implicitWidth + ui.px(22)
    height: ui.px(30)
    radius: ui.px(7)
    opacity: enabled ? 1 : 0.5
    color: primary ? (pillMouse.containsMouse ? Qt.lighter(root.c.accent, 1.1) : root.c.accent)
      : danger ? (pillMouse.containsMouse ? Qt.lighter(root.c.bad, 1.1) : root.c.bad)
      : (pillMouse.containsMouse ? root.c.hover : "transparent")
    border.width: primary || danger ? 0 : 1
    border.color: root.c.line
    Row {
      id: pillRow
      anchors.centerIn: parent
      spacing: ui.px(6)
      Icon { anchors.verticalCenter: parent.verticalCenter; visible: parent.parent.icon !== ""; name: parent.parent.icon; size: ui.px(13); color: parent.parent.primary || parent.parent.danger ? root.c.bg2 : root.c.fg }
      Text { anchors.verticalCenter: parent.verticalCenter; text: parent.parent.label; color: parent.parent.primary || parent.parent.danger ? root.c.bg2 : root.c.fg; font.family: ui.sans; font.pixelSize: ui.f12; font.weight: parent.parent.primary || parent.parent.danger ? Font.DemiBold : Font.Normal }
    }
    MouseArea { id: pillMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
  }
  component ActionRow: Item {
    property string icon: ""
    property string label: ""
    property string value: ""
    property color tone: root.c.fg
    signal clicked()
    width: parent.width
    height: ui.px(36)
    Rectangle { anchors.fill: parent; radius: ui.px(7); color: actionMouse.containsMouse ? root.c.hover : "transparent" }
    Icon { id: actionIcon; anchors.left: parent.left; anchors.leftMargin: ui.px(10); anchors.verticalCenter: parent.verticalCenter; name: parent.icon; size: ui.px(16); color: parent.tone }
    Text {
      anchors.left: actionIcon.right
      anchors.leftMargin: ui.px(10)
      anchors.right: actionValue.left
      anchors.rightMargin: ui.px(8)
      anchors.verticalCenter: parent.verticalCenter
      text: parent.label
      color: parent.tone
      elide: Text.ElideRight
      font.family: ui.sans; font.pixelSize: ui.f13
    }
    Text {
      id: actionValue
      anchors.right: parent.right
      anchors.rightMargin: ui.px(10)
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(implicitWidth, parent.width * 0.5)
      elide: Text.ElideMiddle
      text: parent.value
      color: root.c.muted
      font.family: ui.sans; font.pixelSize: ui.f11
    }
    MouseArea { id: actionMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
  }

  Flickable {
    id: list
    anchors.fill: parent
    clip: true
    contentHeight: column.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    Column {
      id: column
      width: list.width
      spacing: 0

      // Hero
      Column {
        width: parent.width
        topPadding: ui.px(18)
        bottomPadding: ui.px(16)
        spacing: ui.px(9)
        Avatar {
          anchors.horizontalCenter: parent.horizontalCenter
          service: root.service
          userId: root.roomId
          name: root.details ? root.details.name : ""
          mxc: root.details && root.details.avatar ? root.details.avatar : ""
          size: ui.px(60)
          radius: root.details && root.details.direct ? size / 2 : ui.px(16)
          fallbackColor: root.details && root.details.direct ? Palettes.colorOf(root.roomId, root.c.light) : root.c.surface
          initialColor: root.details && root.details.direct ? root.c.bg2 : root.c.fg
          fontFamily: ui.sans
        }
        Text {
          width: parent.width - ui.px(28)
          anchors.horizontalCenter: parent.horizontalCenter
          horizontalAlignment: Text.AlignHCenter
          text: root.details ? root.details.name : (root.loading ? "Loading…" : "Room")
          color: root.c.fg
          wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
          font.family: ui.sans; font.pixelSize: ui.f15; font.weight: Font.DemiBold
        }
        Text {
          visible: text !== ""
          width: parent.width - ui.px(28)
          anchors.horizontalCenter: parent.horizontalCenter
          horizontalAlignment: Text.AlignHCenter
          text: root.details && root.details.alias ? root.details.alias : ""
          color: root.c.muted
          elide: Text.ElideMiddle
          font.family: ui.mono; font.pixelSize: ui.px(10.5)
        }
        Text {
          visible: text !== ""
          width: parent.width - ui.px(28)
          anchors.horizontalCenter: parent.horizontalCenter
          horizontalAlignment: Text.AlignHCenter
          text: root.details && root.details.topic ? String(root.details.topic) : ""
          color: root.c.muted
          wrapMode: Text.Wrap; maximumLineCount: 6; elide: Text.ElideRight
          lineHeight: 1.25
          font.family: ui.sans; font.pixelSize: ui.px(12.5)
        }
        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: ui.px(6)
          Rectangle {
            width: encChip.implicitWidth + ui.px(20); height: ui.px(24); radius: height / 2
            color: root.c.chip
            Row {
              id: encChip
              anchors.centerIn: parent
              spacing: ui.px(5)
              Icon { anchors.verticalCenter: parent.verticalCenter; name: root.details && root.details.encrypted ? "lock-simple" : "lock-simple-open"; weight: "fill"; size: ui.px(10); color: root.details && root.details.encrypted ? root.c.ok : root.c.warn }
              Text { anchors.verticalCenter: parent.verticalCenter; text: root.details && root.details.encrypted ? "Encrypted" : "Not encrypted"; color: root.details && root.details.encrypted ? root.c.ok : root.c.warn; font.family: ui.sans; font.pixelSize: ui.f11 }
            }
          }
          Rectangle {
            width: membersChip.implicitWidth + ui.px(20); height: ui.px(24); radius: height / 2
            color: root.c.chip
            Row {
              id: membersChip
              anchors.centerIn: parent
              spacing: ui.px(5)
              Icon { anchors.verticalCenter: parent.verticalCenter; name: "users"; size: ui.px(11); color: root.c.muted }
              Text { anchors.verticalCenter: parent.verticalCenter; text: root.memberCount + (root.memberCount === 1 ? " member" : " members"); color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.f11 }
            }
          }
          Rectangle {
            visible: !!(root.details && root.details.join_rule === "public")
            width: publicChip.implicitWidth + ui.px(20); height: ui.px(24); radius: height / 2
            color: root.c.chip
            Row {
              id: publicChip
              anchors.centerIn: parent
              spacing: ui.px(5)
              Icon { anchors.verticalCenter: parent.verticalCenter; name: "globe-simple"; size: ui.px(11); color: root.c.muted }
              Text { anchors.verticalCenter: parent.verticalCenter; text: "Public"; color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.f11 }
            }
          }
        }
      }
      Rectangle { width: parent.width; height: 1; color: root.c.line }

      // Bridged room
      Column {
        readonly property var bridge: root.details ? root.details.bridge : null
        width: parent.width
        visible: bridge !== null && bridge !== undefined
        padding: ui.px(12)
        spacing: ui.px(6)
        Row {
          spacing: ui.px(8)
          Icon { anchors.verticalCenter: parent.verticalCenter; name: "plugs-connected"; weight: "fill"; size: ui.px(15); color: root.c.warn }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            readonly property var b: parent.parent.bridge
            text: b ? "Bridged to " + b.name + (b.channel ? " · " + b.channel : "") : ""
            color: root.c.fg
            font.family: ui.sans; font.pixelSize: ui.px(12.5); font.weight: Font.Medium
          }
        }
        Text {
          width: parent.width - ui.px(24)
          wrapMode: Text.WordWrap
          readonly property var b: parent.bridge
          text: (b && b.bridge ? "Run by " + b.bridge + ". " : "")
            + "Messages are relayed by the bridge, which reads them to forward them"
            + (root.details && root.details.encrypted ? " — encryption covers the leg to the bridge, not end to end." : ".")
          color: root.c.muted
          lineHeight: 1.3
          font.family: ui.sans; font.pixelSize: ui.f11
        }
        Pill { readonly property var b: parent.bridge; visible: !!(b && b.bot); label: "Message the bridge bot"; icon: "robot"; onClicked: root.memberChosen({ id: b.bot, name: b.bot }) }
      }
      Rectangle { width: parent.width; height: 1; color: root.c.line; visible: !!(root.details && root.details.bridge) }

      // Inline editor
      Column {
        width: parent.width
        visible: root.editing !== ""
        padding: ui.px(12)
        spacing: ui.px(8)
        Text {
          text: root.editing === "name" ? "Room name" : root.editing === "topic" ? "Topic" : "Invite by Matrix ID"
          color: root.c.fg
          font.family: ui.sans; font.pixelSize: ui.f13; font.weight: Font.DemiBold
        }
        Field {
          id: editField
          c: root.c
          width: parent.width - ui.px(24)
          maximumLength: root.editing === "topic" ? 2000 : 256
          placeholder: root.editing === "invite" ? "@user:server" : ""
          onAccepted: root.commitEdit()
        }
        Row {
          spacing: ui.px(6)
          Pill { label: root.busy ? "…" : (root.editing === "invite" ? "Invite" : "Save"); primary: true; enabled: !root.busy; onClicked: root.commitEdit() }
          Pill { label: "Cancel"; enabled: !root.busy; onClicked: root.editing = "" }
        }
      }

      // Member sheet
      Column {
        width: parent.width
        visible: root.member !== null
        padding: ui.px(12)
        spacing: ui.px(10)
        Row {
          width: parent.width - ui.px(24)
          spacing: ui.px(10)
          Avatar {
            anchors.verticalCenter: parent.verticalCenter
            service: root.service
            userId: root.member ? root.member.id : ""
            name: root.member ? root.member.name : ""
            mxc: root.member && root.member.avatar ? root.member.avatar : ""
            size: ui.px(40)
            fallbackColor: Palettes.colorOf(userId, root.c.light)
            initialColor: root.c.bg2
            fontFamily: ui.sans
          }
          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - ui.px(50) - ui.px(30)
            spacing: ui.px(1)
            Text { width: parent.width; text: root.member ? root.member.name : ""; color: root.c.fg; elide: Text.ElideRight; font.family: ui.sans; font.pixelSize: ui.f13; font.weight: Font.DemiBold }
            Text {
              width: parent.width
              text: root.member ? root.member.id + (root.member.via ? " · via " + root.member.via : "") + (root.member.role && root.member.role !== "member" ? " · " + root.member.role : "") : ""
              color: root.c.muted; elide: Text.ElideMiddle
              font.family: ui.mono; font.pixelSize: ui.f10
            }
          }
          IconButton { anchors.verticalCenter: parent.verticalCenter; c: root.c; icon: "x"; size: ui.px(28); iconSize: ui.px(14); radius: ui.px(7); onClicked: { root.member = null; root.confirmBlock = false } }
        }
        Field {
          id: reasonField
          c: root.c
          width: parent.width - ui.px(24)
          visible: !!(root.details && (root.details.can_kick || root.details.can_ban) && root.member && root.member.id !== root.service.userId)
          placeholder: "Reason (optional)"
          maximumLength: 256
        }
        Flow {
          width: parent.width - ui.px(24)
          spacing: ui.px(6)
          Pill { visible: !!(root.member && root.member.id !== root.service.userId && !root.confirmBlock); label: "Message"; icon: "chat-circle"; primary: true; onClicked: root.memberChosen(root.member) }
          Pill {
            readonly property bool isBlocked: root.member && root.service && root.service.blocked.indexOf(root.member.id) >= 0
            visible: !!(root.member && root.member.id !== root.service.userId)
            label: root.confirmBlock ? "Block " + root.member.name + "?" : (isBlocked ? "Unblock" : "Block")
            icon: isBlocked ? "prohibit" : "prohibit"
            danger: root.confirmBlock
            onClicked: {
              if (isBlocked) { root.service.unignore(root.member.id); return }
              if (!root.confirmBlock) { root.confirmBlock = true; return }
              root.confirmBlock = false
              root.service.ignore(root.member.id)
            }
          }
          Pill { visible: root.confirmBlock; label: "Keep"; onClicked: root.confirmBlock = false }
          Pill { label: "Copy ID"; icon: "copy"; onClicked: root.service.copyText(root.member.id) }
          Pill { visible: !!(root.details && root.details.can_kick && root.member && root.member.id !== root.service.userId); label: root.busy ? "…" : "Remove"; icon: "user-minus"; enabled: !root.busy; onClicked: root.act("kick") }
          Pill { visible: !!(root.details && root.details.can_ban && root.member && root.member.id !== root.service.userId); label: root.busy ? "…" : "Ban"; icon: "gavel"; danger: true; enabled: !root.busy; onClicked: root.act("ban") }
        }
      }

      // Actions
      Column {
        width: parent.width
        visible: root.details !== null && root.editing === "" && root.member === null
        padding: ui.px(10)
        spacing: ui.px(2)
        ActionRow { icon: "bell"; label: "Notifications"; value: root.notifyLabel(root.notifyMode); onClicked: root.pickingNotify = !root.pickingNotify }
        Row {
          visible: root.pickingNotify
          leftPadding: ui.px(36)
          spacing: ui.px(6)
          Repeater {
            model: root.notifyOptions
            delegate: Pill {
              required property var modelData
              label: modelData.label
              primary: modelData.value === root.notifyMode
              onClicked: root.setNotify(modelData.value)
            }
          }
        }
        ActionRow { icon: root.favourite ? "star" : "star"; label: "Favourite"; value: root.favourite ? "On" : "Off"; onClicked: root.service.setFavourite(root.roomId, !root.favourite) }
        ActionRow { icon: "link-simple"; label: "Copy room address"; value: root.details && root.details.alias ? root.details.alias : root.roomId; onClicked: root.service.copyText(root.details && root.details.alias ? root.details.alias : root.roomId) }
        ActionRow { visible: !!(root.details && root.details.can_set_name); icon: "pencil-simple"; label: "Rename"; onClicked: root.startEdit("name") }
        ActionRow { visible: !!(root.details && root.details.can_set_topic); icon: "text-align-left"; label: "Edit topic"; onClicked: root.startEdit("topic") }
        ActionRow { visible: !root.confirmLeave; icon: "sign-out"; label: "Leave room"; tone: root.c.bad; onClicked: root.confirmLeave = true }
        Rectangle {
          width: parent.width - ui.px(20)
          visible: root.confirmLeave
          height: visible ? leaveColumn.implicitHeight + ui.px(22) : 0
          radius: ui.px(8)
          color: root.c.bg
          border.width: 1
          border.color: root.c.bad
          Column {
            id: leaveColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: ui.px(11)
            spacing: ui.px(8)
            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              text: "Leave " + (root.details ? root.details.name : "this room") + "? " + (root.details && root.details.join_rule === "public" ? "You can rejoin any time." : "You will need a new invitation to come back.")
              color: root.c.fg
              lineHeight: 1.25
              font.family: ui.sans; font.pixelSize: ui.f12
            }
            Row {
              spacing: ui.px(6)
              Pill { label: root.busy ? "…" : "Leave"; danger: true; enabled: !root.busy; onClicked: root.doLeave() }
              Pill { label: "Stay"; enabled: !root.busy; onClicked: root.confirmLeave = false }
            }
          }
        }
      }
      Rectangle { width: parent.width; height: 1; color: root.c.line; visible: root.details !== null && root.editing === "" && root.member === null }

      Text {
        width: parent.width - ui.px(24)
        x: ui.px(12)
        visible: root.errorText !== ""
        topPadding: ui.px(8)
        wrapMode: Text.WordWrap
        text: root.errorText
        color: root.c.bad
        font.family: ui.sans; font.pixelSize: ui.f11
      }

      // Members header + filter
      Item {
        width: parent.width
        visible: root.editing === "" && root.member === null
        height: visible ? ui.px(48) : 0
        Text {
          anchors.left: parent.left
          anchors.leftMargin: ui.px(20)
          anchors.verticalCenter: parent.verticalCenter
          text: "MEMBERS"
          color: root.c.muted
          font.family: ui.mono; font.pixelSize: ui.f10; font.letterSpacing: 1.2
        }
        Field {
          id: filterField
          c: root.c
          anchors.right: parent.right
          anchors.rightMargin: ui.px(12)
          anchors.verticalCenter: parent.verticalCenter
          width: ui.px(140)
          height: ui.px(28)
          visible: root.memberCount > 8
          placeholder: "Filter"
          maximumLength: 64
          onTextChanged: filterDebounce.restart()
        }
      }

      // Members
      Repeater {
        model: root.member !== null || root.editing !== "" ? [] : root.members
        delegate: Item {
          id: memberRow
          required property var modelData
          width: list.width
          height: ui.px(44)
          Rectangle { anchors.fill: parent; anchors.leftMargin: ui.px(12); anchors.rightMargin: ui.px(12); radius: ui.px(7); color: memberMouse.containsMouse ? root.c.hover : "transparent" }
          Avatar {
            id: memberAvatar
            anchors.left: parent.left
            anchors.leftMargin: ui.px(22)
            anchors.verticalCenter: parent.verticalCenter
            service: root.service
            userId: memberRow.modelData.id
            name: memberRow.modelData.name
            mxc: memberRow.modelData.avatar || ""
            size: ui.px(28)
            fallbackColor: Palettes.colorOf(memberRow.modelData.id, root.c.light)
            initialColor: root.c.bg2
            fontFamily: ui.sans
          }
          Column {
            anchors.left: memberAvatar.right
            anchors.leftMargin: ui.px(10)
            anchors.right: roleChip.visible ? roleChip.left : parent.right
            anchors.rightMargin: ui.px(22)
            anchors.verticalCenter: parent.verticalCenter
            spacing: ui.px(1)
            Text { width: parent.width; text: memberRow.modelData.name; color: root.c.fg; elide: Text.ElideRight; font.family: ui.sans; font.pixelSize: ui.px(12.5); font.weight: Font.Medium }
            Text { width: parent.width; text: (memberRow.modelData.via ? "via " + memberRow.modelData.via + " · " : "") + memberRow.modelData.id; color: root.c.muted; elide: Text.ElideMiddle; font.family: ui.mono; font.pixelSize: ui.f10 }
          }
          Rectangle {
            id: roleChip
            anchors.right: parent.right
            anchors.rightMargin: ui.px(22)
            anchors.verticalCenter: parent.verticalCenter
            visible: !!(memberRow.modelData.role && memberRow.modelData.role !== "member")
            width: roleText.implicitWidth + ui.px(14)
            height: ui.px(20)
            radius: height / 2
            color: root.c.chip
            Text {
              id: roleText
              anchors.centerIn: parent
              text: memberRow.modelData.role === "admin" ? "Admin" : "Moderator"
              color: memberRow.modelData.role === "admin" ? root.c.warn : root.c.accent
              font.family: ui.sans; font.pixelSize: ui.f10
            }
          }
          MouseArea { id: memberMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.confirmBlock = false; root.member = memberRow.modelData } }
        }
      }

      // Footer
      Column {
        width: list.width
        visible: root.editing === "" && root.member === null
        padding: ui.px(12)
        spacing: ui.px(8)
        Text {
          visible: root.members.length === 0 && !root.loading && root.details !== null
          width: parent.width - ui.px(24)
          horizontalAlignment: Text.AlignHCenter
          text: filterField.text !== "" ? "No one matches" : "No members loaded"
          color: root.c.muted
          font.family: ui.sans; font.pixelSize: ui.f11
        }
        Rectangle {
          visible: !!(root.details && root.details.can_invite)
          width: parent.width - ui.px(24)
          height: ui.px(38)
          radius: ui.px(8)
          color: inviteMouse.containsMouse ? root.c.hover : "transparent"
          border.width: 1
          border.color: inviteMouse.containsMouse ? root.c.accent : root.c.line
          Row {
            anchors.centerIn: parent
            spacing: ui.px(7)
            Icon { anchors.verticalCenter: parent.verticalCenter; name: "user-plus"; size: ui.px(15); color: inviteMouse.containsMouse ? root.c.accent : root.c.muted }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "Invite people"; color: inviteMouse.containsMouse ? root.c.accent : root.c.muted; font.family: ui.sans; font.pixelSize: ui.px(12.5) }
          }
          MouseArea { id: inviteMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.startEdit("invite") }
        }
      }
    }
  }
}
