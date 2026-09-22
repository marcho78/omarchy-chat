import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Settings, rendered from the manifest schema: booleans as toggles, enums
// as dropdowns, integers as sliders, strings and paths as text fields.
// Each change is written to shell.json at once and applies live.
Column {
  id: root
  property var service: null
  property color fg: Color.foreground
  property string fontFamily: Style.font.family
  // The colour row whose picker is unfolded (one at a time). Set from a
  // deep link, or by clicking a row.
  property string pickKey: ""

  spacing: Style.space(10)

  // Ask the enclosing scroller to bring an unfolded row into view.
  signal reveal(real y)
  // The Community card's People button: the host shows the directory.
  signal peopleRequested()

  // Delegates report focus and slider drags upward so these stay reactive.
  property int textFocusCount: 0
  property int draggingCount: 0
  readonly property bool hasTextFocus: textFocusCount > 0 || encryptionCard.hasTextFocus
  readonly property bool dragging: draggingCount > 0

  function current(key, fallback) { return root.service ? root.service.setting(key, fallback) : fallback }
  function themeFallback(key) {
    if (key === "backgroundColor") return Color.background
    if (key === "sidebarColor") return root.service ? root.service.bg : Color.background
    if (key === "textColor") return Color.foreground
    if (key === "selectionColor") return Color.menu.selectedBackground
    if (key === "hoverColor") return Util.alpha(Color.menu.selectedBackground, 0.5)
    return Color.accent
  }

  // About & updates — first thing in Settings.
  Rectangle {
    width: parent.width
    implicitHeight: aboutColumn.implicitHeight + Style.space(24)
    radius: Style.space(8)
    color: "transparent"
    border.width: 1
    border.color: Util.alpha(root.fg, 0.25)

    Column {
      id: aboutColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.space(12)
      spacing: Style.space(6)

      Item {
        width: parent.width
        implicitHeight: Math.max(aboutText.implicitHeight, checkButton.implicitHeight)
        Column {
          id: aboutText
          anchors.left: parent.left
          anchors.right: checkButton.left
          anchors.rightMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)
          Text {
            width: parent.width
            elide: Text.ElideRight
            text: "Yapper " + (root.service ? root.service.pluginVersion : "")
              + (root.service && root.service.pluginCommit ? "  ·  " + root.service.pluginCommit : "")
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }
          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Daemon " + (root.service && root.service.daemonVersion ? root.service.daemonVersion : "not running")
              + (root.service && root.service.daemonLatest ? "  ·  newest " + root.service.daemonLatest : "")
            color: root.fg
            opacity: 0.7
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: {
              if (!root.service) return ""
              var s = root.service
              if (s.checking) return "Checking…"
              if (s.updateError) return s.updateError
              if (!s.lastChecked) return "Not checked yet"
              return (s.updateAvailable ? "Update available" : "Up to date") + "  ·  checked " + s.lastChecked
            }
            color: root.service && root.service.updateError ? Color.urgent : (root.service && root.service.updateAvailable ? Color.accent : root.fg)
            opacity: root.service && (root.service.updateError || root.service.updateAvailable) ? 1 : 0.55
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
        Button {
          id: checkButton
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          iconText: "󰚰"
          text: root.service && root.service.checking ? "Checking…" : "Check for updates"
          bordered: true
          enabled: !(root.service && root.service.checking)
          onClicked: root.service.checkForUpdates()
        }
      }

      UpdateBanner {
        width: parent.width
        service: root.service
        fg: root.fg
        fontFamily: root.fontFamily
      }

      Rectangle { width: parent.width; height: 1; color: Util.alpha(root.fg, 0.15) }

      // Developer
      Item {
        width: parent.width
        implicitHeight: Math.max(developerText.implicitHeight, developerLinks.implicitHeight)
        Column {
          id: developerText
          anchors.left: parent.left
          anchors.right: developerLinks.left
          anchors.rightMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)
          Text {
            text: "Made by " + (root.service ? root.service.developerName : "")
            color: root.fg
            font.family: root.fontFamily; font.pixelSize: Style.font.subtitle; font.bold: true
          }
          Text {
            width: parent.width
            elide: Text.ElideRight
            text: (root.service ? root.service.developerMatrix : "") + "  ·  𝕏 @" + (root.service ? root.service.developerName : "")
            color: root.fg; opacity: 0.7
            font.family: root.fontFamily; font.pixelSize: Style.font.caption
          }
        }
        Row {
          id: developerLinks
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.spacing.controlGap
          Button {
            iconText: "󰭹"
            text: root.service && root.service.developerDmPending ? "Opening…" : "Message"
            bordered: true
            visible: root.service && root.service.userId !== root.service.developerMatrix
            enabled: root.service && root.service.canMessageDeveloper
            onClicked: root.service.messageDeveloper()
          }
          Button { text: "𝕏"; onClicked: root.service.openDeveloperX() }
        }
      }
    }
  }

  PanelSectionHeader { text: "Encryption"; visible: root.service && root.service.loggedIn }
  VerificationView {
    id: encryptionCard
    width: parent.width
    visible: root.service && root.service.loggedIn
    service: root.service
    fg: root.fg
    fontFamily: root.fontFamily
    inSettings: true
  }

  // Community: membership, the card others see, who may message you, blocks
  PanelSectionHeader { text: "Community"; visible: root.service && root.service.loggedIn }
  Rectangle {
    id: communityCard
    readonly property var c: root.service ? root.service.community : null
    readonly property bool joined: c !== null && c.joined === true
    readonly property var profile: c ? c.profile : null
    property bool busy: false
    property bool editing: false
    property bool confirmLeave: false
    property string errorText: ""
    visible: root.service && root.service.loggedIn
    width: parent.width
    implicitHeight: visible ? communityCol.implicitHeight + Style.space(24) : 0
    radius: Style.space(8)
    color: "transparent"
    border.width: 1
    border.color: Util.alpha(root.fg, 0.25)
    Component.onCompleted: if (root.service) root.service.refreshCommunity()
    onVisibleChanged: if (visible && root.service) { root.service.refreshCommunity(); root.service.refreshBlocked() }
    function startEdit() {
      bioField.text = profile ? profile.bio : ""
      dmToggle.checked = profile ? profile.open_to_dm === true : true
      themeToggle.checked = profile ? !!profile.theme : true
      editing = true
      Qt.callLater(function() { bioField.forceActiveFocus() })
    }
    function publish() {
      busy = true; errorText = ""
      root.service.publishProfile(bioField.text, dmToggle.checked, themeToggle.checked ? root.service.themeName : "", function(r) {
        communityCard.busy = false
        if (!r.ok) { communityCard.errorText = r.error || "Could not publish"; return }
        communityCard.editing = false
      })
    }
    Column {
      id: communityCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.space(12)
      spacing: Style.space(10)

      // Status + join / leave
      Item {
        width: parent.width
        implicitHeight: Math.max(statusCol.implicitHeight, joinButton.implicitHeight)
        Column {
          id: statusCol
          anchors.left: parent.left
          anchors.right: joinButton.left
          anchors.rightMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)
          Text {
            text: "󰀏  " + (communityCard.c && communityCard.c.name ? communityCard.c.name : "Omarchy community")
            color: root.fg
            font.family: root.fontFamily; font.pixelSize: Style.font.subtitle; font.bold: true
          }
          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: {
              var c = communityCard.c
              if (!c) return "Checking…"
              if (!c.exists) return "The space " + (root.service ? root.service.communityAlias : "") + " does not exist yet."
              var bits = [c.member_count + (c.member_count === 1 ? " member" : " members"), c.rooms.length + (c.rooms.length === 1 ? " room" : " rooms")]
              return (c.joined ? "Joined  ·  " : "Not joined  ·  ") + bits.join("  ·  ") + (c.joined && c.rooms.length ? "  ·  " + c.rooms.map(function(r) { return r.name }).join(", ") : "")
            }
            color: root.fg; opacity: 0.7
            font.family: root.fontFamily; font.pixelSize: Style.font.caption
          }
        }
        Button {
          id: joinButton
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          visible: communityCard.c && communityCard.c.exists && !communityCard.confirmLeave
          text: communityCard.busy ? "…" : (communityCard.joined ? "Leave" : "Join")
          iconText: communityCard.joined ? "󰗼" : "󰜘"
          bordered: !communityCard.joined
          enabled: !communityCard.busy
          onClicked: {
            if (communityCard.joined) { communityCard.confirmLeave = true; return }
            communityCard.busy = true; communityCard.errorText = ""
            root.service.communityJoin(function(r) { communityCard.busy = false; if (!r.ok) communityCard.errorText = r.error || "Could not join" })
          }
        }
      }
      Row {
        visible: communityCard.confirmLeave
        spacing: Style.spacing.controlGap
        Text { anchors.verticalCenter: parent.verticalCenter; text: "Leave the space and its rooms? Your card is withdrawn."; color: root.fg; opacity: 0.8; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
        Button { text: "Leave"; bordered: true; onClicked: { communityCard.confirmLeave = false; communityCard.busy = true; root.service.communityLeave(function(r) { communityCard.busy = false; if (!r.ok) communityCard.errorText = r.error || "Could not leave" }) } }
        Button { text: "Stay"; onClicked: communityCard.confirmLeave = false }
      }

      // Your card
      Column {
        width: parent.width
        spacing: Style.space(6)
        visible: communityCard.joined
        Rectangle { width: parent.width; height: 1; color: Util.alpha(root.fg, 0.15) }
        Column {
          width: parent.width
          spacing: Style.space(8)
          Column {
            id: cardText
            width: parent.width
            spacing: Style.space(2)
            Text { text: "Show me to other Omarchy users"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.subtitle }
            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              text: communityCard.profile
                ? "Listed" + (communityCard.profile.bio ? ": “" + communityCard.profile.bio + "”" : "") + (communityCard.profile.open_to_dm ? "  ·  open to messages" : "  ·  not taking messages") + (communityCard.profile.theme ? "  ·  " + communityCard.profile.theme : "")
                : "Not listed. Publishing a card puts your name, bio and theme in the People view; only you can change or remove it."
              color: root.fg; opacity: 0.7
              font.family: root.fontFamily; font.pixelSize: Style.font.caption
            }
          }
          Flow {
            id: cardButtons
            width: parent.width
            spacing: Style.spacing.controlGap
            visible: !communityCard.editing
            Button { text: communityCard.profile ? "Edit card" : "Publish a card"; iconText: "󰏫"; bordered: !communityCard.profile; onClicked: communityCard.startEdit() }
            Button { visible: !!communityCard.profile; text: "Remove"; iconText: "󰅖"; enabled: !communityCard.busy; onClicked: { communityCard.busy = true; root.service.clearProfile(function(r) { communityCard.busy = false; if (!r.ok) communityCard.errorText = r.error || "Could not remove" }) } }
            Button { text: "People"; iconText: "󰀏"; onClicked: root.peopleRequested() }
          }
        }
        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: communityCard.editing
          TextField {
            id: bioField
            width: parent.width
            maximumLength: 280
            placeholderText: "A line about you (optional)"
            onAccepted: communityCard.publish()
          }
          Row {
            width: parent.width
            spacing: Style.space(10)
            Toggle { id: dmToggle; checked: true }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "Open to direct messages from members"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.body }
          }
          Row {
            width: parent.width
            spacing: Style.space(10)
            Toggle { id: themeToggle; checked: true }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "Show my theme" + (root.service && root.service.themeName ? " (" + root.service.themeName + ")" : ""); color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.body }
          }
          Row {
            spacing: Style.spacing.controlGap
            Button { text: communityCard.busy ? "Publishing…" : "Publish"; iconText: "󰒊"; bordered: true; enabled: !communityCard.busy; onClicked: communityCard.publish() }
            Button { text: "Cancel"; enabled: !communityCard.busy; onClicked: communityCard.editing = false }
          }
        }
      }

      // Who may message you
      Column {
        width: parent.width
        spacing: Style.space(4)
        Rectangle { width: parent.width; height: 1; color: Util.alpha(root.fg, 0.15) }
        Text { text: "Who can start a direct chat with me"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.subtitle }
        Dropdown {
          width: parent.width
          options: [
            { value: "anyone", label: "Anyone on Matrix" },
            { value: "community", label: "Omarchy community members and people I already talk to" },
            { value: "contacts", label: "Only people I already talk to" },
            { value: "nobody", label: "Nobody — decline all new direct chats" }
          ]
          value: root.service ? root.service.dmPolicy : "anyone"
          onChanged: function(v) { root.service.set("dmPolicy", v) }
        }
        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          text: "Invites that fall outside this are declined by the daemon before you see them. Group invites always reach you."
          color: root.fg; opacity: 0.55
          font.family: root.fontFamily; font.pixelSize: Style.font.caption
        }
      }

      // Blocked users
      Column {
        width: parent.width
        spacing: Style.space(4)
        visible: root.service && root.service.blocked.length > 0
        Rectangle { width: parent.width; height: 1; color: Util.alpha(root.fg, 0.15) }
        Text { text: "Blocked"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.subtitle }
        Repeater {
          model: root.service ? root.service.blocked : []
          delegate: Item {
            required property string modelData
            width: parent.width
            implicitHeight: Style.space(30)
            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.right: unblock.left; anchors.rightMargin: Style.space(8); text: modelData; color: root.fg; opacity: 0.8; elide: Text.ElideMiddle; font.family: root.fontFamily; font.pixelSize: Style.font.body }
            Button { id: unblock; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "Unblock"; onClicked: root.service.unignore(modelData) }
          }
        }
      }

      Text {
        width: parent.width
        visible: communityCard.errorText !== ""
        wrapMode: Text.WordWrap
        text: communityCard.errorText
        color: Color.urgent
        font.family: root.fontFamily; font.pixelSize: Style.font.caption
      }
    }
  }

  // Voice: which microphone and speaker voice messages use
  PanelSectionHeader { text: "Voice" }
  Rectangle {
    id: voiceCard
    width: parent.width
    implicitHeight: voiceCol.implicitHeight + Style.space(24)
    radius: Style.space(8)
    color: "transparent"
    border.width: 1
    border.color: Util.alpha(root.fg, 0.25)
    Component.onCompleted: if (root.service) root.service.refreshAudioDevices()
    onVisibleChanged: if (visible && root.service) root.service.refreshAudioDevices()
    Column {
      id: voiceCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.space(12)
      spacing: Style.space(10)
      Column {
        width: parent.width
        spacing: Style.space(4)
        Text { text: "Microphone"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.subtitle }
        Dropdown {
          width: parent.width
          options: [{ value: "", label: "System default" }].concat(root.service ? root.service.audioInputs : [])
          value: root.service ? root.service.voiceInput : ""
          onChanged: function(v) { root.service.set("voiceInput", v) }
        }
      }
      Column {
        width: parent.width
        spacing: Style.space(4)
        Text { text: "Speaker"; color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.subtitle }
        Dropdown {
          width: parent.width
          options: [{ value: "", label: "System default" }].concat(root.service ? root.service.audioOutputs : [])
          value: root.service ? root.service.voiceOutput : ""
          onChanged: function(v) { root.service.set("voiceOutput", v) }
        }
      }
      Column {
        width: parent.width
        spacing: Style.space(6)
        Button {
          readonly property string state: root.service ? root.service.audioTest : ""
          text: state === "recording" ? "Recording… " + (root.service ? root.service.audioTestLeft : 0)
              : state === "playing" ? "Playing back…" : "Test: record 3 s and play it back"
          iconText: state === "recording" ? "󰍬" : state === "playing" ? "󰕾" : "󰐊"
          bordered: true
          enabled: state === "" && root.service && !root.service.recording
          onClicked: root.service.testAudio()
        }
        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          text: "Devices come from PipeWire; the system default follows Omarchy's audio menu."
          color: root.fg; opacity: 0.55
          font.family: root.fontFamily; font.pixelSize: Style.font.caption
        }
      }
    }
  }

  Text {
    width: parent.width
    wrapMode: Text.WordWrap
    text: "Changes apply as you make them. Colours follow the Omarchy theme until you pick one."
    color: root.fg
    opacity: 0.6
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  Repeater {
    id: fields
    model: root.service ? root.service.schema : []
    delegate: Column {
      id: field
      required property var modelData
      readonly property string key: String(modelData.key)
      readonly property string type: String(modelData.type)
      readonly property var value: root.current(key, modelData.defaultValue)
      readonly property bool textFocus: textField.activeFocus || (picker.item ? picker.item.hasTextFocus : false)
      readonly property bool dragging: slider.dragging
      onTextFocusChanged: root.textFocusCount += textFocus ? 1 : -1
      onDraggingChanged: root.draggingCount += dragging ? 1 : -1
      Component.onDestruction: { if (textFocus) root.textFocusCount--; if (dragging) root.draggingCount-- }
      readonly property bool isColor: String(modelData.format || "") === "color"
      readonly property bool pickerOpen: root.pickKey === key
      readonly property string section: String(modelData.section || "")
      readonly property bool newSection: index === 0 || String((root.service.schema[index - 1] || {}).section || "") !== section
      required property int index
      width: root.width
      spacing: Style.space(4)
      onPickerOpenChanged: if (pickerOpen) Qt.callLater(function() { root.reveal(field.y) })

      PanelSectionHeader {
        visible: field.newSection && field.section !== ""
        text: field.section
      }

      // boolean
      Toggle {
        visible: field.type === "boolean"
        width: parent.width
        label: String(field.modelData.label || field.key)
        description: String(field.modelData.description || "")
        checked: field.value === true || String(field.value) === "true"
        onClicked: root.service.set(field.key, !checked)
      }

      // enum
      Column {
        visible: field.type === "enum"
        width: parent.width
        spacing: Style.space(4)
        Text {
          text: String(field.modelData.label || field.key)
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: Style.font.subtitle
        }
        Dropdown {
          width: parent.width
          options: field.modelData.options || []
          value: String(field.value)
          onChanged: function(v) { root.service.set(field.key, v) }
        }
        Text {
          visible: !!field.modelData.description
          width: parent.width
          wrapMode: Text.WordWrap
          text: String(field.modelData.description || "")
          color: root.fg
          opacity: 0.55
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      // integer
      Column {
        visible: field.type === "integer"
        width: parent.width
        spacing: Style.space(2)
        Row {
          width: parent.width
          Text {
            text: String(field.modelData.label || field.key)
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
          }
          Item { width: parent.width - parent.children[0].implicitWidth - valueLabel.implicitWidth; height: 1 }
          Text {
            id: valueLabel
            text: String(slider.dragging ? Math.round(slider.liveValue) : (Number(field.value) || field.modelData.defaultValue || 0)) + (field.key === "fontScale" ? "%" : "")
            color: Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
          }
        }
        PanelSlider {
          id: slider
          width: parent.width
          minimum: Number(field.modelData.min !== undefined ? field.modelData.min : 0)
          maximum: Number(field.modelData.max !== undefined ? field.modelData.max : 100)
          step: Number(field.modelData.step || 1)
          // The knob follows the pointer continuously; only the stored value is whole.
          integer: false
          value: Number(field.value) || 0
          onMoved: function(v) { root.service.previewSetting(field.key, Math.round(v)) }
          onReleased: function(v) { root.service.set(field.key, Math.round(v)) }
        }
      }

      // colour: a row with a swatch; click to unfold the picker
      Column {
        visible: field.isColor
        width: parent.width
        spacing: Style.space(6)

        Item {
          width: parent.width
          implicitHeight: Style.space(54)
          Rectangle {
            anchors.fill: parent
            radius: Style.space(8)
            color: field.pickerOpen ? (root.service ? root.service.selection : Util.alpha(root.fg, 0.06))
              : colorMouse.containsMouse ? (root.service ? root.service.hover : Util.alpha(root.fg, 0.06)) : "transparent"
            border.width: 1
            border.color: field.pickerOpen ? Color.accent : Util.alpha(root.fg, 0.25)
          }
          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(14)
            anchors.rightMargin: Style.space(14)
            spacing: Style.space(12)
            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(28)
              height: width
              radius: Style.space(8)
              color: root.service ? root.service.pickColor(field.key, root.themeFallback(field.key)) : "transparent"
              border.width: 1
              border.color: Util.alpha(root.fg, 0.35)
            }
            Column {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - Style.space(28) - Style.space(12) - stateLabel.width - Style.space(12)
              spacing: Style.space(1)
              Text {
                text: String(field.modelData.label || field.key)
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.subtitle
              }
              Text {
                width: parent.width
                text: String(field.modelData.description || "")
                color: root.fg
                opacity: 0.55
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }
            Text {
              id: stateLabel
              anchors.verticalCenter: parent.verticalCenter
              text: root.service && root.service.isThemeColor(field.key) ? "Theme" : String(field.value).toLowerCase()
              color: root.service && root.service.isThemeColor(field.key) ? root.fg : Color.accent
              opacity: root.service && root.service.isThemeColor(field.key) ? 0.5 : 1
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
          MouseArea {
            id: colorMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.pickKey = field.pickerOpen ? "" : field.key
          }
        }

        Loader {
          id: picker
          width: parent.width
          active: field.pickerOpen
          visible: active
          sourceComponent: ColorPicker {
            width: picker.width - Style.space(28)
            x: Style.space(14)
            fg: root.fg
            fontFamily: root.fontFamily
            swatches: root.service ? root.service.themeSwatches : []
            value: root.service ? root.service.pickColor(field.key, root.themeFallback(field.key)) : "#888888"
            onPicked: function(hex) { root.service.set(field.key, hex) }
            onCleared: { root.service.set(field.key, ""); root.pickKey = "" }
          }
        }
      }

      // string / path
      Column {
        visible: (field.type === "string" || field.type === "path") && !field.isColor
        width: parent.width
        spacing: Style.space(4)
        Text {
          text: String(field.modelData.label || field.key)
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: Style.font.subtitle
        }
        Row {
          width: parent.width
          spacing: Style.spacing.controlGap
          TextField {
            id: textField
            width: parent.width
            text: String(field.value === undefined || field.value === null ? "" : field.value)
            placeholderText: String(field.modelData.description || "")
            maximumLength: 512
            onAccepted: root.service.set(field.key, text)
            onActiveFocusChanged: if (!activeFocus && text !== String(field.value || "")) root.service.set(field.key, text)
          }
        }
        Text {
          visible: !!field.modelData.description && field.type !== "string"
          width: parent.width
          wrapMode: Text.WordWrap
          text: String(field.modelData.description || "")
          color: root.fg
          opacity: 0.55
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }

}
