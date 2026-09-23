import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import "../../shared"
import "../../shared/Palettes.js" as Palettes
import "../../shared/Format.js" as Format

// Settings in the Yapper look: a section list on the left and one
// section at a time on the right. Every control writes through
// service.set(), so changes apply as they are made.
Item {
  id: root
  property var c: Palettes.fallback()
  property var tips: null
  property var service: null
  property string section: "about"
  // The color row whose picker is unfolded (one at a time).
  property string pickKey: ""
  // Section state (kept here: the root id is what children bind to).
  property bool confirmSignOut: false
  property bool confirmRemoveDaemon: false
  property bool confirmReset: false
  readonly property string dataDir: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/omarchy-yapperd"
  property string storeSizeText: "…"
  readonly property string audioTestState: root.service ? root.service.audioTest : ""
  signal closeRequested()
  signal peopleRequested()
  signal installRequested(bool update)
  Ui { id: ui }

  readonly property var sections: [
    { key: "about", label: "About", icon: "info", desc: "Versions, the update check, and who made this." },
    { key: "account", label: "Account", icon: "user-circle", desc: "Your session on this machine." },
    { key: "appearance", label: "Appearance", icon: "palette", desc: "The look, its palette, and the colors you override." },
    { key: "messages", label: "Messages", icon: "chat-text", desc: "How the timeline reads." },
    { key: "rooms", label: "Rooms & notifications", icon: "bell", desc: "Sorting, and who is allowed to interrupt you." },
    { key: "voice", label: "Voice", icon: "waveform", desc: "Devices and volume for voice messages." },
    { key: "community", label: "Community", icon: "users-three", desc: "Your card, who may start a direct chat with you, and the block list." },
    { key: "encryption", label: "Encryption", icon: "shield-check", desc: "Device verification, key backup and recovery." },
    { key: "daemon", label: "Daemon", icon: "hard-drives", desc: "The process that owns your keys and the socket." }
  ]
  readonly property var current: { for (var i = 0; i < sections.length; i++) if (sections[i].key === section) return sections[i]; return sections[0] }
  readonly property bool hasTextFocus: homeserverField.hasFocus || bioField.hasFocus || spaceField.hasFocus || verification.hasTextFocus || yapperColors.hasTextFocus || themeColors.hasTextFocus
  // A saved palette awaiting the Delete confirmation
  property string deletingPalette: ""
  function savePalette() {
    var name = paletteNameField.text.trim()
    if (name === "" || !root.service) return
    root.service.savePalette(name)
    paletteNameField.text = ""
    root.pickKey = ""
  }
  function setting(key, fallback) { return root.service ? root.service.setting(key, fallback) : fallback }
  function flag(key, fallback) { return root.service ? root.service.flag(key, fallback) : fallback }
  function show(sectionKey, pick) {
    root.section = sectionKey
    content.contentY = 0
    root.pickKey = pick || ""
  }
  // Scroll so an item sits near the top of the page.
  function revealItem(item) {
    var y = item.mapToItem(page, 0, 0).y + page.y - ui.px(12)
    content.contentY = Math.max(0, Math.min(y, content.contentHeight - content.height))
  }
  onSectionChanged: {
    if (!root.service) return
    if (section === "voice") root.service.refreshAudioDevices()
    if (section === "community") { root.service.refreshCommunity(); root.service.refreshBlocked() }
    if (section === "encryption") root.service.refreshVerification()
    if (section === "daemon") storeSize.running = true
  }

  component SectionLabel: Text {
    property string label: ""
    text: label.toUpperCase()
    color: root.c.muted
    topPadding: ui.px(8)
    bottomPadding: ui.px(4)
    font.family: ui.mono; font.pixelSize: ui.f10; font.letterSpacing: 1.2
  }
  component Note: Text {
    width: parent.width
    wrapMode: Text.Wrap
    lineHeight: 1.35
    color: root.c.muted
    font.family: ui.sans; font.pixelSize: ui.f12
  }
  component ValueText: Text {
    color: root.c.muted
    elide: Text.ElideMiddle
    width: Math.min(implicitWidth, ui.px(270))
    font.family: ui.mono; font.pixelSize: ui.f11
  }
  component ColorRow: Column {
    // A color setting: the row with its swatch, and the picker unfolded below.
    id: colorRow
    property string key: ""
    property string label: ""
    property string description: ""
    property color fallback: root.c.accent
    readonly property bool set: root.service ? root.service.isHex(root.setting(key, "")) : false
    readonly property color shown: set ? Qt.color(String(root.setting(key, "")).trim()) : fallback
    readonly property bool open: root.pickKey === key
    readonly property bool hasTextFocus: picker.item ? picker.item.hasTextFocus : false
    // Whether the open picker's color was kept; otherwise the preview goes.
    property bool kept: false
    width: parent.width
    spacing: ui.px(10)
    onOpenChanged: {
      if (open) { kept = false; Qt.callLater(function() { root.revealItem(colorRow) }) }
      else if (!kept && root.service) root.service.dropPreview(key)
    }
    SettingRow {
      c: root.c; label: colorRow.label; description: colorRow.description
      Row {
        spacing: ui.px(9)
        Text { anchors.verticalCenter: parent.verticalCenter; text: colorRow.set ? String(colorRow.shown) : (root.service && root.service.look === "omarchy" ? "Follows the theme" : "Follows the palette"); color: root.c.muted; font.family: colorRow.set ? ui.mono : ui.sans; font.pixelSize: ui.f11 }
        Rectangle {
          width: ui.px(30); height: ui.px(30); radius: ui.px(8)
          color: colorRow.shown
          border.width: 1
          border.color: swatchMouse.containsMouse || colorRow.open ? root.c.accent : root.c.line
          MouseArea { id: swatchMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.pickKey = colorRow.open ? "" : colorRow.key }
        }
      }
    }
    Loader {
      id: picker
      width: parent.width
      active: colorRow.open
      visible: active
      sourceComponent: HsvPicker {
        c: root.c
        value: colorRow.shown
        useLabel: "Use this color"
        onChanged: function(hex) { root.service.previewSetting(colorRow.key, hex) }
        onPicked: function(hex) { colorRow.kept = true; root.service.set(colorRow.key, hex); root.pickKey = "" }
        onCleared: { colorRow.kept = true; root.service.set(colorRow.key, ""); root.pickKey = "" }
      }
    }
  }

  // ---------- nav ----------
  Item {
    id: nav
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: ui.px(212)
    Rectangle { anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 1; color: root.c.line }
    Column {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: ui.px(8)
      anchors.topMargin: ui.px(12)
      spacing: ui.px(1)
      Item {
        width: parent.width
        height: ui.px(30)
        Text { anchors.left: parent.left; anchors.leftMargin: ui.px(10); anchors.verticalCenter: parent.verticalCenter; text: "SETTINGS"; color: root.c.muted; font.family: ui.mono; font.pixelSize: ui.f10; font.letterSpacing: 1.2 }
        IconButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; c: root.c; tips: root.tips; icon: "x"; size: ui.px(26); iconSize: ui.px(14); radius: ui.px(6); tooltip: "Back to chat (Esc)"; onClicked: root.closeRequested() }
      }
      Repeater {
        model: root.sections
        delegate: Rectangle {
          required property var modelData
          readonly property bool on: root.section === modelData.key
          width: parent.width
          height: ui.px(34)
          radius: ui.px(7)
          color: on ? root.c.sel : (navMouse.containsMouse ? root.c.hover : "transparent")
          Row {
            anchors.left: parent.left
            anchors.leftMargin: ui.px(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: ui.px(10)
            Icon { anchors.verticalCenter: parent.verticalCenter; name: parent.parent.modelData.icon; size: ui.px(15); color: parent.parent.on ? root.c.accent : root.c.fg }
            Text { textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter; text: parent.parent.modelData.label; color: parent.parent.on ? root.c.accent : root.c.fg; font.family: ui.sans; font.pixelSize: ui.px(12.5); font.weight: parent.parent.on ? Font.DemiBold : Font.Medium }
          }
          MouseArea { id: navMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.show(parent.modelData.key) }
        }
      }
    }
  }

  // ---------- content ----------
  Flickable {
    id: content
    anchors.left: nav.right
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    contentHeight: page.implicitHeight + ui.px(64)
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    Column {
      id: page
      x: ui.px(28)
      y: ui.px(24)
      width: Math.min(content.width - ui.px(56), ui.px(620))
      spacing: ui.px(6)

      Text { textFormat: Text.PlainText; text: root.current.label; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.px(20); font.weight: Font.DemiBold; font.letterSpacing: -0.4 }
      Note { text: root.current.desc; bottomPadding: ui.px(14) }

      // ===== About =====
      Column {
        width: parent.width
        visible: root.section === "about"
        spacing: ui.px(14)
        Card {
          c: root.c
          width: parent.width
          padding: ui.px(18)
          Row {
            width: parent.width
            spacing: ui.px(16)
            Rectangle {
              width: ui.px(48); height: ui.px(48); radius: ui.px(13)
              color: "#22b8a8"
              Icon { anchors.centerIn: parent; name: "lock-simple"; weight: "fill"; size: ui.px(26); color: "#062b28" }
            }
            Column {
              width: parent.width - ui.px(64)
              spacing: ui.px(4)
              Text { text: "Yapper " + (root.service ? root.service.pluginVersion : ""); color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.f15; font.weight: Font.DemiBold }
              Note { text: "End-to-end encrypted Matrix chat for Omarchy. The shell never touches a key — everything cryptographic lives in the omarchy-yapperd daemon, installed as a pacman package you can read the source of." }
              Flow {
                width: parent.width
                spacing: ui.px(16)
                topPadding: ui.px(6)
                Text { text: "plugin " + (root.service ? root.service.pluginVersion : "") + (root.service && root.service.pluginUpdateAvailable ? " · " + root.service.pluginUpdateCount + " new change" + (root.service.pluginUpdateCount === 1 ? "" : "s") : (root.service && root.service.lastChecked ? " · up to date" : "")); color: root.c.muted; font.family: ui.mono; font.pixelSize: ui.px(10.5) }
                Text { text: "daemon " + (root.service && root.service.daemonVersion ? root.service.daemonVersion : "not running") + (root.service && root.service.daemonUpdateAvailable ? " → " + root.service.daemonLatest : ""); color: root.c.muted; font.family: ui.mono; font.pixelSize: ui.px(10.5) }
                Text { text: root.service && root.service.checking ? "checking…" : (root.service && root.service.lastChecked ? "checked " + root.service.lastChecked : "not checked yet"); color: root.c.muted; font.family: ui.mono; font.pixelSize: ui.px(10.5) }
              }
            }
          }
        }
        // Updates
        Card {
          id: updateCard
          c: root.c
          width: parent.width
          ring: root.c.warn
          color: root.c.chip
          property string dismissedDaemon: ""
          property int dismissedPlugin: 0
          readonly property bool daemon: !!(root.service && root.service.daemonUpdateAvailable && dismissedDaemon !== root.service.daemonLatest)
          readonly property bool plugin: !!(root.service && root.service.pluginUpdateAvailable && dismissedPlugin !== root.service.pluginUpdateCount)
          visible: daemon || plugin
          Row {
            width: parent.width
            spacing: ui.px(14)
            Icon { name: "arrow-circle-up"; weight: "fill"; size: ui.px(22); color: root.c.warn }
            Column {
              width: parent.width - ui.px(36)
              spacing: ui.px(6)
              Text { width: parent.width; wrapMode: Text.Wrap; text: updateCard.daemon ? "omarchy-yapperd " + root.service.daemonLatest + " is available" : "The plugin has " + root.service.pluginUpdateCount + " new change" + (root.service.pluginUpdateCount === 1 ? "" : "s"); color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.px(13.5); font.weight: Font.DemiBold }
              Note { text: updateCard.daemon ? "You have " + root.service.daemonVersion + (root.service.daemonKind === "bin" ? ", prebuilt" : root.service.daemonKind === "source" ? ", built from source" : "") + ". Installs through pacman in a terminal, then restarts the daemon; your session stays signed in." : "Shows the diff in a terminal for you to confirm, then restarts the shell." }
              Column {
                visible: !updateCard.daemon && root.service && root.service.pluginUpdateLog.length > 0
                width: parent.width
                Repeater { model: root.service ? root.service.pluginUpdateLog : []; delegate: Note { required property string modelData; text: "· " + modelData } }
              }
              Flow {
                width: parent.width
                spacing: ui.px(8)
                topPadding: ui.px(6)
                PillButton { c: root.c; label: updateCard.daemon ? "Update the daemon" : "Update the plugin"; warn: true; round: true; enabled: !(updateCard.daemon && root.service.installActive); onClicked: updateCard.daemon ? root.installRequested(true) : root.service.updatePlugin() }
                PillButton { c: root.c; label: "Release notes"; round: true; onClicked: Quickshell.execDetached(["/usr/share/omarchy/bin/omarchy-launch-browser", updateCard.daemon ? root.service.daemonRepo + "/releases" : root.service.pluginRepo + "/commits"]) }
                PillButton { c: root.c; label: "Not now"; round: true; onClicked: { if (updateCard.daemon) updateCard.dismissedDaemon = root.service.daemonLatest; else updateCard.dismissedPlugin = root.service.pluginUpdateCount } }
              }
            }
          }
        }
        InstallProgress { width: parent.width; visible: root.service && root.service.installState !== null; c: root.c; service: root.service }
        Column {
          width: parent.width
          SettingRow { c: root.c; label: "Plugin"; description: "Checked against its git remote"; ValueText { text: "marcho78.yapper " + (root.service ? root.service.pluginVersion : "") + (root.service && root.service.pluginCommit ? " · " + root.service.pluginCommit : "") } }
          SettingRow { c: root.c; label: "Daemon"; description: "Checked against the newest pkg-v* tag"; ValueText { text: "omarchy-yapperd " + (root.service && root.service.daemonVersion ? root.service.daemonVersion : "—") } }
          SettingRow { c: root.c; label: "Check for updates"; description: "Every six hours and shortly after the shell starts. Nothing is installed without you confirming in a terminal."; Toggle { c: root.c; checked: root.flag("checkUpdates", true); onToggled: root.service.set("checkUpdates", !checked) } }
          SettingRow { c: root.c; label: "Check now"; description: root.service && root.service.updateError ? root.service.updateError : (root.service && root.service.lastChecked ? "Last checked at " + root.service.lastChecked : "Not checked yet"); PillButton { c: root.c; label: root.service && root.service.checking ? "Checking…" : "Check for updates"; round: true; enabled: !(root.service && root.service.checking); onClicked: root.service.checkForUpdates() } }
          SettingRow {
            c: root.c; label: "Made by " + (root.service ? root.service.developerName : ""); description: (root.service ? root.service.developerMatrix : "") + " · 𝕏 @" + (root.service ? root.service.developerName : "")
            Row {
              spacing: ui.px(8)
              PillButton { c: root.c; visible: root.service && root.service.userId !== root.service.developerMatrix; label: root.service && root.service.developerDmPending ? "Opening…" : "Message"; icon: "chat-circle"; round: true; enabled: root.service && root.service.canMessageDeveloper; onClicked: root.service.messageDeveloper() }
              PillButton { c: root.c; label: "𝕏"; round: true; onClicked: root.service.openDeveloperX() }
            }
          }
        }
      }

      // ===== Account =====
      Column {
        width: parent.width
        visible: root.section === "account"
        SettingRow { c: root.c; label: "Matrix ID"; ValueText { text: root.service ? root.service.userId : "" } }
        SettingRow {
          c: root.c; label: "Homeserver"; description: "Pre-filled on the sign-in form"
          Field { id: homeserverField; c: root.c; width: ui.px(250); text: String(root.setting("homeserver", "https://matrix.org")); maximumLength: 256; onAccepted: root.service.set("homeserver", text.trim()); onHasFocusChanged: if (!hasFocus && text.trim() !== String(root.setting("homeserver", ""))) root.service.set("homeserver", text.trim()) }
        }
        SettingRow { c: root.c; label: "This device"; ValueText { text: root.service && root.service.verification && root.service.verification.device_id ? root.service.verification.device_id : "—" } }
        SettingRow { c: root.c; label: "Secrets"; description: "Access token and store passphrase"; ValueText { text: root.service && root.service.secretsBackend === "keyring" ? "keyring · Secret Service" : root.service && root.service.secretsBackend === "file" ? "session.json (no keyring found)" : "—" } }
        SettingRow {
          c: root.c; label: "Sign out"; labelColor: root.c.bad; description: root.confirmSignOut ? "This revokes the token on the server and deletes the session, the store and the keyring item. Sure?" : "Revokes the token on the server and deletes the session, the store and the keyring item."
          Row {
            spacing: ui.px(8)
            PillButton { c: root.c; visible: !root.confirmSignOut; label: "Sign out"; round: true; onClicked: root.confirmSignOut = true }
            PillButton { c: root.c; visible: root.confirmSignOut; label: "Yes, sign out"; danger: true; round: true; onClicked: { root.confirmSignOut = false; root.service.logout() } }
            PillButton { c: root.c; visible: root.confirmSignOut; label: "Stay"; round: true; onClicked: root.confirmSignOut = false }
          }
        }
      }

      // ===== Appearance =====
      Column {
        width: parent.width
        visible: root.section === "appearance"
        spacing: ui.px(4)
        SettingRow { c: root.c; label: "Look"; description: "Yapper is the designed look; Omarchy uses the shell's own widgets and follows the desktop theme."; Segmented { c: root.c; options: [{ value: "yapper", label: "Yapper" }, { value: "omarchy", label: "Omarchy" }]; value: root.service ? root.service.look : "yapper"; onChosen: function(v) { root.service.set("look", v) } } }
        SectionLabel { label: "Palette" }
        Flow {
          width: parent.width
          spacing: ui.px(7)
          Repeater {
            model: root.service ? root.service.paletteKeys : Palettes.order
            delegate: Rectangle {
              required property string modelData
              readonly property var pal: root.service ? root.service.paletteFor(modelData) : Palettes.themes.tokyonight
              readonly property var v: pal ? pal.v : Palettes.themes.tokyonight.v
              readonly property string label: modelData === "omarchy" ? "Omarchy theme" : (pal ? pal.label : modelData)
              readonly property bool custom: modelData.indexOf("custom:") === 0
              readonly property bool on: root.service ? root.service.theme === modelData : false
              width: ui.px(132)
              height: ui.px(62)
              radius: ui.px(9)
              color: v.bg
              border.width: 1.5
              border.color: on || cardMouse.containsMouse ? v.accent : root.c.line
              Column {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: ui.px(11)
                spacing: ui.px(7)
                Row {
                  spacing: ui.px(3)
                  Rectangle { width: ui.px(11); height: ui.px(11); radius: ui.px(3); color: parent.parent.parent.v.accent }
                  Rectangle { width: ui.px(11); height: ui.px(11); radius: ui.px(3); color: parent.parent.parent.v.ok }
                  Rectangle { width: ui.px(11); height: ui.px(11); radius: ui.px(3); color: parent.parent.parent.v.warn }
                  Rectangle { width: ui.px(11); height: ui.px(11); radius: ui.px(3); color: parent.parent.parent.v.bad }
                }
                Text { textFormat: Text.PlainText; width: ui.px(110); elide: Text.ElideRight; text: parent.parent.label; color: parent.parent.v.fg; font.family: ui.sans; font.pixelSize: ui.f11; font.weight: Font.Medium }
              }
              MouseArea { id: cardMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.service.set("theme", parent.modelData) }
              // A saved palette can go again.
              Rectangle {
                visible: parent.custom && (cardMouse.containsMouse || trashMouse.containsMouse || parent.on)
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: ui.px(5)
                width: ui.px(20); height: ui.px(20); radius: ui.px(5)
                color: trashMouse.containsMouse ? root.c.hover : "transparent"
                Icon { anchors.centerIn: parent; name: "trash"; size: ui.px(12); color: trashMouse.containsMouse ? root.c.bad : parent.parent.v.muted }
                MouseArea { id: trashMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.deletingPalette = parent.parent.modelData }
              }
            }
          }
        }
        Row {
          visible: root.deletingPalette !== ""
          topPadding: ui.px(8)
          spacing: ui.px(8)
          Text { textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter; text: "Delete the palette “" + (root.service && root.service.paletteFor(root.deletingPalette) ? root.service.paletteFor(root.deletingPalette).label : "") + "”?"; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.f12 }
          PillButton { c: root.c; label: "Delete"; danger: true; round: true; onClicked: { root.service.deletePalette(root.deletingPalette.replace(/^custom:/, "")); root.deletingPalette = "" } }
          PillButton { c: root.c; label: "Keep"; round: true; onClicked: root.deletingPalette = "" }
        }
        Note { topPadding: ui.px(8); text: "Omarchy theme follows the desktop; the others are fixed sets, Catppuccin Latte being the light one. Set a color below and it overrides that slot only." }
        // Keep what is on screen as a palette
        Rectangle {
          width: parent.width
          visible: !(root.service && root.service.look === "omarchy")
          height: saveColumn.implicitHeight + ui.px(28)
          radius: ui.px(10)
          color: root.c.bg2
          border.width: 1
          border.color: root.c.line
          Column {
            id: saveColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: ui.px(14)
            spacing: ui.px(9)
            Row {
              spacing: ui.px(8)
              Icon { anchors.verticalCenter: parent.verticalCenter; name: "floppy-disk"; size: ui.px(16); color: root.c.accent }
              Text { anchors.verticalCenter: parent.verticalCenter; text: "Save as a palette"; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.f13; font.weight: Font.DemiBold }
            }
            Note { text: "The palette above plus any colors you set below become a card of your own, selected, with the rows back to following it." }
            Row {
              width: parent.width
              spacing: ui.px(8)
              Field { id: paletteNameField; c: root.c; width: parent.width - saveButton.width - parent.spacing; placeholder: "Name, e.g. Night shift"; maximumLength: 40; onAccepted: root.savePalette() }
              PillButton { id: saveButton; c: root.c; anchors.verticalCenter: parent.verticalCenter; label: "Save"; primary: true; enabled: paletteNameField.text.trim() !== ""; onClicked: root.savePalette() }
            }
          }
        }

        // ---- Colors for the look you are in ----
        SectionLabel { label: root.service && root.service.look === "omarchy" ? "Omarchy look colors" : "Colors"; topPadding: ui.px(18) }
        Column {
          id: yapperColors
          width: parent.width
          visible: !(root.service && root.service.look === "omarchy")
          readonly property bool hasTextFocus: ybgRow.hasTextFocus || ysbRow.hasTextFocus || yfgRow.hasTextFocus || yacRow.hasTextFocus || yhvRow.hasTextFocus || yslRow.hasTextFocus || paletteNameField.hasFocus
          ColorRow { id: ybgRow; key: "yapperBackgroundColor"; label: "Window background"; description: "The conversation, dialogs and the popup"; fallback: root.c.bg }
          ColorRow { id: ysbRow; key: "yapperSidebarColor"; label: "Sidebar background"; description: "The room list, the rail, the title strip and cards"; fallback: root.c.bg2 }
          ColorRow { id: yfgRow; key: "yapperTextColor"; label: "Text"; description: "Message and interface text; captions follow it"; fallback: root.c.fg }
          ColorRow { id: yacRow; key: "yapperAccent"; label: "Accent"; description: "Links, your name, unread badges, the selected room"; fallback: root.c.accent }
          ColorRow { id: yhvRow; key: "yapperHoverColor"; label: "Hover highlight"; description: "Rows and messages under the pointer"; fallback: root.c.hover }
          ColorRow { id: yslRow; key: "yapperSelectionColor"; label: "Selection"; description: "The open room in the list"; fallback: root.c.sel }
        }
        Column {
          id: themeColors
          width: parent.width
          visible: root.service && root.service.look === "omarchy"
          readonly property bool hasTextFocus: bgRow.hasTextFocus || sbRow.hasTextFocus || fgRow.hasTextFocus || acRow.hasTextFocus || hvRow.hasTextFocus || slRow.hasTextFocus
          Note { text: "The Omarchy look follows the desktop theme. Leave a color empty to keep the theme's; set one and it overrides that slot only."; bottomPadding: ui.px(6) }
          ColorRow { id: bgRow; key: "backgroundColor"; label: "Window background"; description: "The window and popup surface"; fallback: Color.background }
          ColorRow { id: sbRow; key: "sidebarColor"; label: "Sidebar background"; description: "The room list"; fallback: Color.background }
          ColorRow { id: fgRow; key: "textColor"; label: "Text"; description: "Message and interface text"; fallback: Color.foreground }
          ColorRow { id: acRow; key: "accentColor"; label: "Accent"; description: "Links, your name, unread badges"; fallback: Color.accent }
          ColorRow { id: hvRow; key: "hoverColor"; label: "Hover highlight"; description: "Rows and messages under the pointer"; fallback: Color.menu.selectedBackground }
          ColorRow { id: slRow; key: "selectionColor"; label: "Selection"; description: "The open room in the list"; fallback: Color.menu.selectedBackground }
        }
      }

      // ===== Messages =====
      Column {
        width: parent.width
        visible: root.section === "messages"
        spacing: ui.px(4)
        Row {
          width: parent.width
          spacing: ui.px(10)
          bottomPadding: ui.px(14)
          Repeater {
            model: [
              { value: "flat", label: "Flat", desc: "Avatar, name, grouped runs. Element and Slack read this way." },
              { value: "bubbles", label: "Bubbles", desc: "Yours on the right, theirs on the left." }
            ]
            delegate: Rectangle {
              required property var modelData
              readonly property bool on: String(root.setting("messageStyle", "flat")) === modelData.value
              readonly property bool bubbles: modelData.value === "bubbles"
              width: (parent.width - parent.spacing) / 2
              height: ui.px(150)
              radius: ui.px(10)
              color: root.c.bg2
              border.width: 1.5
              border.color: on || styleMouse.containsMouse ? root.c.accent : root.c.line
              Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: ui.px(13)
                spacing: ui.px(10)
                // A sketch of two messages in the style
                Column {
                  width: parent.width
                  spacing: ui.px(6)
                  Row {
                    width: parent.width
                    spacing: ui.px(7)
                    layoutDirection: Qt.LeftToRight
                    Rectangle { visible: !parent.parent.parent.parent.bubbles; width: ui.px(18); height: ui.px(18); radius: width / 2; color: Palettes.colorOf("@ines:matrix.org", root.c.light) }
                    Rectangle { width: parent.width * 0.58; height: ui.px(26); radius: parent.parent.parent.parent.bubbles ? ui.px(12) : ui.px(5); color: root.c.surface }
                  }
                  Row {
                    width: parent.width
                    spacing: ui.px(7)
                    layoutDirection: parent.parent.parent.bubbles ? Qt.RightToLeft : Qt.LeftToRight
                    Rectangle { visible: !parent.parent.parent.parent.bubbles; width: ui.px(18); height: ui.px(18); radius: width / 2; color: root.c.accent }
                    Rectangle { width: parent.width * 0.44; height: ui.px(20); radius: parent.parent.parent.parent.bubbles ? ui.px(12) : ui.px(5); color: parent.parent.parent.parent.bubbles ? root.c.own : root.c.surface }
                  }
                }
                Text { textFormat: Text.PlainText; text: parent.parent.modelData.label; color: parent.parent.on ? root.c.accent : root.c.fg; font.family: ui.sans; font.pixelSize: ui.px(12.5); font.weight: Font.DemiBold }
                Note { text: parent.parent.modelData.desc; font.pixelSize: ui.f11 }
              }
              MouseArea { id: styleMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.service.set("messageStyle", parent.modelData.value) }
            }
          }
        }
        SettingRow { c: root.c; label: "Show avatars"; description: "In the timeline and the people list"; Toggle { c: root.c; checked: root.flag("showAvatars", true); onToggled: root.service.set("showAvatars", !checked) } }
        SettingRow { c: root.c; label: "Color each sender's name"; description: "Off: names use the text color, yours the accent"; Toggle { c: root.c; checked: root.flag("senderColors", true); onToggled: root.service.set("senderColors", !checked) } }
        SettingRow {
          c: root.c; label: "Chat text size"; description: "Applies to the timeline only"
          Row {
            spacing: ui.px(10)
            LevelSlider { id: fontSlider; c: root.c; anchors.verticalCenter: parent.verticalCenter; from: 80; to: 150; step: 5; value: Number(root.setting("fontScale", 100)) || 100; onMoved: function(v) { root.service.previewSetting("fontScale", Math.round(v)) }; onReleased: function(v) { root.service.set("fontScale", Math.round(v)) } }
            Text { anchors.verticalCenter: parent.verticalCenter; width: ui.px(44); horizontalAlignment: Text.AlignRight; text: Math.round(fontSlider.shown) + "%"; color: root.c.fg; font.family: ui.mono; font.pixelSize: ui.f11 }
          }
        }
        SettingRow { c: root.c; label: "Link previews"; description: "A card for the first link in a message. Your homeserver fetches the page, not this machine."; Toggle { c: root.c; checked: root.flag("linkPreviews", true); onToggled: root.service.set("linkPreviews", !checked) } }
      }

      // ===== Rooms & notifications =====
      Column {
        width: parent.width
        visible: root.section === "rooms"
        spacing: ui.px(4)
        SettingRow { c: root.c; label: "Sort rooms by"; Segmented { c: root.c; options: [{ value: "activity", label: "Activity" }, { value: "name", label: "Name" }]; value: root.service ? root.service.roomSort : "activity"; onChosen: function(v) { root.service.set("roomSort", v) } } }
        SettingRow { c: root.c; label: "Notify on new messages"; description: "For rooms no Yapper view is showing"; Toggle { c: root.c; checked: root.flag("notifications", true); onToggled: root.service.set("notifications", !checked) } }
        SettingRow {
          c: root.c; label: "Keyboard shortcut"
          description: root.service && root.service.shortcutError !== "" ? root.service.shortcutError
            : root.service && root.service.shortcutPresent ? "Toggles the Yapper window. One o.bind line in " + root.service.shortcutFile + "; Remove takes it out again."
            : "Adds one o.bind line to ~/.config/hypr/bindings.lua that toggles the Yapper window. Nothing is written until you press Add."
          Row {
            spacing: ui.px(8)
            Field { id: shortcutField; c: root.c; width: ui.px(190); text: root.service && root.service.shortcutCombo !== "" ? root.service.shortcutCombo : "SUPER + SHIFT + T"; placeholder: "SUPER + SHIFT + T"; maximumLength: 40; onAccepted: root.service.setShortcut(text) }
            PillButton { c: root.c; label: root.service && root.service.shortcutPresent ? (shortcutField.text.trim() !== root.service.shortcutCombo ? "Change" : "Added") : "Add to Hyprland"; primary: !(root.service && root.service.shortcutPresent && shortcutField.text.trim() === root.service.shortcutCombo); round: true; enabled: shortcutField.text.trim() !== "" && !(root.service && root.service.shortcutPresent && shortcutField.text.trim() === root.service.shortcutCombo); onClicked: root.service.setShortcut(shortcutField.text) }
            PillButton { c: root.c; visible: root.service && root.service.shortcutPresent; label: "Remove"; round: true; onClicked: root.service.removeShortcut() }
          }
        }
        SectionLabel { label: "Per room"; topPadding: ui.px(18) }
        Note { text: "Mentions and keywords still notify on Mentions; Mute keeps the room quiet and its badge grey." }
        Repeater {
          model: root.service ? root.service.rooms.slice().sort(function(a, b) { return String(a.name).toLowerCase() < String(b.name).toLowerCase() ? -1 : 1 }) : []
          delegate: SettingRow {
            required property var modelData
            c: root.c
            label: modelData.name
            description: modelData.topic ? Format.oneLine(modelData.topic) : ""
            Segmented { c: root.c; options: [{ value: "all", label: "All" }, { value: "mentions", label: "Mentions" }, { value: "mute", label: "Mute" }]; value: String(parent.parent.modelData.notification_mode || "all"); onChosen: function(v) { root.service.setNotificationMode(parent.parent.modelData.id, v, function() {}) } }
          }
        }
      }

      // ===== Voice =====
      Column {
        width: parent.width
        visible: root.section === "voice"
        spacing: ui.px(4)
        SettingRow { c: root.c; label: "Microphone"; description: "A PipeWire source. System default follows Omarchy's audio menu."; Select { c: root.c; options: [{ value: "", label: "System default" }].concat(root.service ? root.service.audioInputs : []); value: root.service ? root.service.voiceInput : ""; onChosen: function(v) { root.service.set("voiceInput", v) } } }
        SettingRow { c: root.c; label: "Speaker"; description: "A PipeWire sink for playback"; Select { c: root.c; options: [{ value: "", label: "System default" }].concat(root.service ? root.service.audioOutputs : []); value: root.service ? root.service.voiceOutput : ""; onChosen: function(v) { root.service.set("voiceOutput", v) } } }
        SettingRow {
          c: root.c; label: "Playback volume"; description: "Notes are loudness-normalised on the way in and out"
          Row {
            spacing: ui.px(10)
            LevelSlider { id: volumeSlider; c: root.c; anchors.verticalCenter: parent.verticalCenter; from: 20; to: 100; step: 5; value: Number(root.setting("voiceVolume", 100)) || 100; onMoved: function(v) { root.service.previewSetting("voiceVolume", Math.round(v)) }; onReleased: function(v) { root.service.set("voiceVolume", Math.round(v)) } }
            Text { anchors.verticalCenter: parent.verticalCenter; width: ui.px(44); horizontalAlignment: Text.AlignRight; text: Math.round(volumeSlider.shown) + "%"; color: root.c.fg; font.family: ui.mono; font.pixelSize: ui.f11 }
          }
        }
        Card {
          c: root.c
          width: parent.width
          Text { text: "Record and play back"; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.f13; font.weight: Font.DemiBold }
          Note { text: "Three seconds through the devices above, at the volume you set. Nothing is sent." }
          Row {
            width: parent.width
            spacing: ui.px(12)
            PillButton { c: root.c; anchors.verticalCenter: parent.verticalCenter; label: root.audioTestState === "recording" ? "Recording…" : root.audioTestState === "playing" ? "Playing back…" : "Test"; icon: root.audioTestState === "playing" ? "speaker-high" : "microphone"; iconWeight: "fill"; danger: root.audioTestState !== "playing"; primary: root.audioTestState === "playing"; round: true; enabled: root.audioTestState === "" && root.service && !root.service.recording; onClicked: root.service.testAudio() }
            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - ui.px(120) - parent.spacing * 2
              height: ui.px(6)
              radius: ui.px(3)
              color: root.c.surface
              Rectangle {
                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                radius: ui.px(3)
                width: root.audioTestState === "recording" ? parent.width * (1 - (root.service ? root.service.audioTestLeft : 0) / 3) : root.audioTestState === "playing" ? parent.width : 0
                color: root.audioTestState === "recording" ? root.c.bad : root.c.accent
                Behavior on width { NumberAnimation { duration: 300 } }
              }
            }
            Text { anchors.verticalCenter: parent.verticalCenter; width: ui.px(40); horizontalAlignment: Text.AlignRight; text: root.audioTestState === "recording" ? "0:0" + (root.service ? 3 - root.service.audioTestLeft : 0) : root.audioTestState === "playing" ? "0:03" : "0:00"; color: root.c.muted; font.family: ui.mono; font.pixelSize: ui.f11 }
          }
        }
      }

      // ===== Community =====
      Column {
        width: parent.width
        visible: root.section === "community"
        spacing: ui.px(14)
        readonly property var community: root.service ? root.service.community : null
        readonly property bool joined: community !== null && community.joined === true
        readonly property var profile: community ? community.profile : null
        property bool busy: false
        property bool editing: false
        property bool confirmLeave: false
        property string errorText: ""
        id: communitySection
        function startEdit() {
          bioField.text = profile ? String(profile.bio || "") : ""
          dmToggle.checked = profile ? profile.open_to_dm === true : true
          themeToggle.checked = profile ? !!profile.theme : true
          editing = true
          Qt.callLater(function() { bioField.forceActiveFocus() })
        }
        function publish() {
          busy = true; errorText = ""
          root.service.publishProfile(bioField.text, dmToggle.checked, themeToggle.checked ? root.service.themeName : "", function(r) {
            communitySection.busy = false
            if (!r.ok) { communitySection.errorText = r.error || "Could not publish"; return }
            communitySection.editing = false
          })
        }
        // Membership
        Card {
          c: root.c
          width: parent.width
          Row {
            width: parent.width
            spacing: ui.px(12)
            Icon { anchors.verticalCenter: parent.verticalCenter; name: "users-three"; size: ui.px(18); color: root.c.accent }
            Column {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - ui.px(30) - joinButton.width - ui.px(12)
              spacing: ui.px(3)
              Text { textFormat: Text.PlainText; text: communitySection.community && communitySection.community.name ? communitySection.community.name : "Omarchy community"; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.f13; font.weight: Font.DemiBold }
              Note {
                text: {
                  var cm = communitySection.community
                  if (!cm) return "Checking…"
                  if (!cm.exists) return "The space " + (root.service ? root.service.communityAlias : "") + " does not exist yet."
                  var bits = [cm.member_count + (cm.member_count === 1 ? " member" : " members"), cm.rooms.length + (cm.rooms.length === 1 ? " room" : " rooms")]
                  return (cm.joined ? "Joined · " : "Not joined · ") + bits.join(" · ") + (cm.joined && cm.rooms.length ? " · " + cm.rooms.map(function(r) { return r.name }).join(", ") : "")
                }
                font.pixelSize: ui.f11
              }
            }
            PillButton { id: joinButton; c: root.c; anchors.verticalCenter: parent.verticalCenter; visible: !!(communitySection.community && communitySection.community.exists) && !communitySection.confirmLeave; label: communitySection.busy ? "…" : (communitySection.joined ? "Leave" : "Join"); primary: !communitySection.joined; round: true; enabled: !communitySection.busy; onClicked: { if (communitySection.joined) { communitySection.confirmLeave = true; return } communitySection.busy = true; communitySection.errorText = ""; root.service.communityJoin(function(r) { communitySection.busy = false; if (!r.ok) communitySection.errorText = r.error || "Could not join" }) } }
          }
          Row {
            visible: communitySection.confirmLeave
            width: parent.width
            spacing: ui.px(8)
            Note { width: parent.width - ui.px(160); anchors.verticalCenter: parent.verticalCenter; text: "Leave the space and its rooms? Your card is withdrawn." }
            PillButton { c: root.c; label: "Leave"; danger: true; round: true; onClicked: { communitySection.confirmLeave = false; communitySection.busy = true; root.service.communityLeave(function(r) { communitySection.busy = false; if (!r.ok) communitySection.errorText = r.error || "Could not leave" }) } }
            PillButton { c: root.c; label: "Stay"; round: true; onClicked: communitySection.confirmLeave = false }
          }
        }
        // Your card
        Card {
          c: root.c
          width: parent.width
          visible: communitySection.joined
          Row {
            width: parent.width
            spacing: ui.px(8)
            Icon { anchors.verticalCenter: parent.verticalCenter; name: "identification-card"; size: ui.px(16); color: root.c.accent }
            Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - ui.px(110); text: "Your card"; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.f13; font.weight: Font.DemiBold }
            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: publishedText.implicitWidth + ui.px(18); height: ui.px(22); radius: height / 2
              color: root.c.chip
              Text { id: publishedText; anchors.centerIn: parent; text: communitySection.profile ? "Published" : "Not listed"; color: communitySection.profile ? root.c.ok : root.c.muted; font.family: ui.sans; font.pixelSize: ui.px(10.5) }
            }
          }
          Row {
            width: parent.width
            spacing: ui.px(13)
            Avatar { service: root.service; userId: root.service ? root.service.userId : ""; name: root.service ? root.service.userId : ""; size: ui.px(44); fallbackColor: root.c.accent; initialColor: root.c.bg2; fontFamily: ui.sans }
            Column {
              width: parent.width - ui.px(57)
              spacing: ui.px(9)
              Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.StyledText; text: Format.escapeHtml(root.service ? root.service.userId.split(":")[0].replace("@", "") : "") + "  <font color=\"" + root.c.muted + "\" size=\"2\">" + Format.escapeHtml(root.service ? root.service.userId : "") + "</font>"; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.f13; font.weight: Font.DemiBold }
              Note { visible: !communitySection.editing; text: communitySection.profile ? (communitySection.profile.bio ? "“" + communitySection.profile.bio + "”" : "No bio.") + (communitySection.profile.open_to_dm ? " · open to messages" : " · not taking messages") + (communitySection.profile.theme ? " · showing " + communitySection.profile.theme : "") : "Publishing a card puts your name, bio and theme in the People view; only you can change or remove it." }
              Field { id: bioField; c: root.c; visible: communitySection.editing; width: parent.width; placeholder: "One line about you"; maximumLength: 280; onAccepted: communitySection.publish() }
              Flow {
                visible: communitySection.editing
                width: parent.width
                spacing: ui.px(14)
                Row { spacing: ui.px(8); Toggle { id: dmToggle; c: root.c; anchors.verticalCenter: parent.verticalCenter; checked: true; onToggled: checked = !checked } Text { anchors.verticalCenter: parent.verticalCenter; text: "Open to direct messages from members"; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.f12 } }
                Row { spacing: ui.px(8); Toggle { id: themeToggle; c: root.c; anchors.verticalCenter: parent.verticalCenter; checked: true; onToggled: checked = !checked } Text { anchors.verticalCenter: parent.verticalCenter; text: "Show my theme" + (root.service && root.service.themeName ? " (" + root.service.themeName + ")" : ""); color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.f12 } }
              }
            }
          }
          Flow {
            width: parent.width
            spacing: ui.px(8)
            PillButton { c: root.c; visible: !communitySection.editing; label: communitySection.profile ? "Edit card" : "Publish a card"; primary: !communitySection.profile; round: true; onClicked: communitySection.startEdit() }
            PillButton { c: root.c; visible: !communitySection.editing && !!communitySection.profile; label: "Withdraw"; round: true; enabled: !communitySection.busy; onClicked: { communitySection.busy = true; root.service.clearProfile(function(r) { communitySection.busy = false; if (!r.ok) communitySection.errorText = r.error || "Could not remove the card" }) } }
            PillButton { c: root.c; visible: !communitySection.editing; label: "People"; icon: "users"; round: true; onClicked: root.peopleRequested() }
            PillButton { c: root.c; visible: communitySection.editing; label: communitySection.busy ? "Publishing…" : "Save card"; primary: true; round: true; enabled: !communitySection.busy; onClicked: communitySection.publish() }
            PillButton { c: root.c; visible: communitySection.editing; label: "Cancel"; round: true; enabled: !communitySection.busy; onClicked: communitySection.editing = false }
          }
        }
        // Who may start a direct chat
        Column {
          width: parent.width
          spacing: ui.px(6)
          SectionLabel { label: "Who may start a direct chat with you" }
          Repeater {
            model: [
              { value: "anyone", label: "Anyone", desc: "Any Matrix user may open a direct chat with you." },
              { value: "community", label: "Community and people I talk to", desc: "Members of the community space, and anyone you already have a room with." },
              { value: "contacts", label: "Only people I already talk to", desc: "An existing shared room is required." },
              { value: "nobody", label: "Nobody", desc: "All incoming direct invitations are declined." }
            ]
            delegate: Rectangle {
              required property var modelData
              readonly property bool on: root.service ? root.service.dmPolicy === modelData.value : false
              width: parent.width
              height: policyColumn.implicitHeight + ui.px(22)
              radius: ui.px(9)
              color: on ? root.c.sel : "transparent"
              border.width: 1
              border.color: on || policyMouse.containsMouse ? root.c.accent : root.c.line
              Rectangle {
                id: radio
                anchors.left: parent.left
                anchors.leftMargin: ui.px(13)
                anchors.top: parent.top
                anchors.topMargin: ui.px(12)
                width: ui.px(16); height: ui.px(16); radius: width / 2
                color: "transparent"
                border.width: 1.5
                border.color: parent.on ? root.c.accent : root.c.muted
                Rectangle { anchors.centerIn: parent; width: ui.px(8); height: ui.px(8); radius: width / 2; color: parent.parent.on ? root.c.accent : "transparent" }
              }
              Column {
                id: policyColumn
                anchors.left: radio.right
                anchors.leftMargin: ui.px(11)
                anchors.right: parent.right
                anchors.rightMargin: ui.px(13)
                anchors.top: parent.top
                anchors.topMargin: ui.px(11)
                spacing: ui.px(2)
                Text { textFormat: Text.PlainText; text: parent.parent.modelData.label; color: root.c.fg; font.family: ui.sans; font.pixelSize: ui.px(12.5); font.weight: Font.DemiBold }
                Note { text: parent.parent.modelData.desc; font.pixelSize: ui.f11 }
              }
              MouseArea { id: policyMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.service.set("dmPolicy", parent.modelData.value) }
            }
          }
          Note { text: "Invitations outside this are declined by the daemon before you see them. Group invitations always reach you." }
        }
        // Blocked
        Column {
          width: parent.width
          spacing: ui.px(6)
          SectionLabel { label: "Blocked" }
          Rectangle {
            width: parent.width
            height: root.service && root.service.blocked.length > 0 ? blockedColumn.implicitHeight : ui.px(44)
            radius: ui.px(9)
            color: root.c.bg2
            border.width: 1
            border.color: root.c.line
            clip: true
            Note { anchors.centerIn: parent; visible: !(root.service && root.service.blocked.length > 0); text: "No one is blocked." }
            Column {
              id: blockedColumn
              width: parent.width
              Repeater {
                model: root.service ? root.service.blocked : []
                delegate: Item {
                  required property string modelData
                  required property int index
                  width: parent.width
                  height: ui.px(46)
                  Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: root.c.line; visible: index < root.service.blocked.length - 1 }
                  Avatar { id: blockedAvatar; anchors.left: parent.left; anchors.leftMargin: ui.px(13); anchors.verticalCenter: parent.verticalCenter; service: root.service; userId: modelData; name: modelData; size: ui.px(26); fallbackColor: root.c.surface; initialColor: root.c.muted; fontFamily: ui.sans }
                  Text { anchors.left: blockedAvatar.right; anchors.leftMargin: ui.px(11); anchors.right: unblockButton.left; anchors.rightMargin: ui.px(10); anchors.verticalCenter: parent.verticalCenter; text: modelData; color: root.c.fg; elide: Text.ElideMiddle; font.family: ui.mono; font.pixelSize: ui.f11 }
                  PillButton { id: unblockButton; c: root.c; anchors.right: parent.right; anchors.rightMargin: ui.px(13); anchors.verticalCenter: parent.verticalCenter; label: "Unblock"; round: true; onClicked: root.service.unignore(modelData) }
                }
              }
            }
          }
        }
        Column {
          width: parent.width
          SettingRow { c: root.c; label: "Community space"; description: "The space the join card, People and this page use"; Field { id: spaceField; c: root.c; width: ui.px(250); text: root.service ? root.service.communityAlias : ""; maximumLength: 256; onAccepted: root.service.set("communitySpace", text.trim()); onHasFocusChanged: if (!hasFocus && root.service && text.trim() !== root.service.communityAlias) root.service.set("communitySpace", text.trim()) } }
          SettingRow { c: root.c; label: "Show the join card"; description: "Until you join or press Not now"; Toggle { c: root.c; checked: root.flag("communityPrompt", true); onToggled: root.service.set("communityPrompt", !checked) } }
        }
        Text { textFormat: Text.PlainText; width: parent.width; visible: communitySection.errorText !== ""; wrapMode: Text.Wrap; text: communitySection.errorText; color: root.c.bad; font.family: ui.sans; font.pixelSize: ui.f11 }
      }

      // ===== Encryption =====
      Column {
        width: parent.width
        visible: root.section === "encryption"
        spacing: ui.px(14)
        readonly property var status: root.service ? root.service.verification : null
        Grid {
          width: parent.width
          columns: width >= ui.px(560) ? 4 : 2
          columnSpacing: ui.px(9)
          rowSpacing: ui.px(9)
          Repeater {
            model: {
              var st = parent.parent.status
              var ok = root.c.ok, warn = root.c.warn, bad = root.c.bad, muted = root.c.muted
              var rec = st ? String(st.recovery || "") : "", bak = st ? String(st.backup || "") : ""
              return [
                { label: "This device", value: st ? (st.device_verified ? "Verified" : "Unverified") : "—", icon: st && st.device_verified ? "shield-check" : "shield-warning", color: st ? (st.device_verified ? ok : bad) : muted },
                { label: "Cross-signing", value: st ? (st.cross_signing ? "Ready" : "Not set up") : "—", icon: st && st.cross_signing ? "check-circle" : "warning-circle", color: st ? (st.cross_signing ? ok : warn) : muted },
                { label: "Key backup", value: bak !== "" ? bak.charAt(0).toUpperCase() + bak.slice(1) : "—", icon: bak === "enabled" || bak === "on" ? "cloud-check" : "cloud-slash", color: bak === "enabled" || bak === "on" ? ok : (bak === "" ? muted : warn) },
                { label: "Recovery key", value: rec !== "" ? rec.charAt(0).toUpperCase() + rec.slice(1) : "—", icon: "key", color: rec === "enabled" || rec === "set" || rec === "ready" ? ok : (rec === "" ? muted : warn) }
              ]
            }
            delegate: Rectangle {
              required property var modelData
              width: (parent.width - (parent.columns - 1) * parent.columnSpacing) / parent.columns
              height: ui.px(70)
              radius: ui.px(9)
              color: root.c.bg2
              border.width: 1
              border.color: root.c.line
              Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: ui.px(13)
                spacing: ui.px(6)
                Row {
                  spacing: ui.px(8)
                  Icon { anchors.verticalCenter: parent.verticalCenter; name: parent.parent.parent.modelData.icon; weight: "fill"; size: ui.px(15); color: parent.parent.parent.modelData.color }
                  Text { textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter; text: parent.parent.parent.modelData.label; color: root.c.muted; font.family: ui.sans; font.pixelSize: ui.f12 }
                }
                Text { textFormat: Text.PlainText; text: parent.parent.modelData.value; color: parent.parent.modelData.color; font.family: ui.sans; font.pixelSize: ui.px(13.5); font.weight: Font.DemiBold }
              }
            }
          }
        }
        Column {
          width: parent.width
          spacing: ui.px(6)
          SectionLabel { label: "Other devices" }
          Rectangle {
            width: parent.width
            readonly property var devices: parent.parent.status && parent.parent.status.other_devices ? parent.parent.status.other_devices : []
            height: devices.length > 0 ? devicesColumn.implicitHeight : ui.px(44)
            radius: ui.px(9)
            color: root.c.bg2
            border.width: 1
            border.color: root.c.line
            clip: true
            Note { anchors.centerIn: parent; visible: parent.devices.length === 0; text: "No other devices are signed in to this account." }
            Column {
              id: devicesColumn
              width: parent.width
              Repeater {
                model: parent.parent.devices
                delegate: Item {
                  required property var modelData
                  required property int index
                  width: parent.width
                  height: ui.px(52)
                  Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: root.c.line; visible: index < parent.parent.parent.devices.length - 1 }
                  Icon { id: deviceIcon; anchors.left: parent.left; anchors.leftMargin: ui.px(13); anchors.verticalCenter: parent.verticalCenter; name: "device-mobile"; size: ui.px(18); color: root.c.muted }
                  Column {
                    anchors.left: deviceIcon.right
                    anchors.leftMargin: ui.px(11)
                    anchors.right: deviceState.left
                    anchors.rightMargin: ui.px(10)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: ui.px(1)
                    Text { textFormat: Text.PlainText; width: parent.width; text: modelData.name || modelData.id; color: root.c.fg; elide: Text.ElideRight; font.family: ui.sans; font.pixelSize: ui.px(12.5); font.weight: Font.Medium }
                    Text { textFormat: Text.PlainText; width: parent.width; text: modelData.id; color: root.c.muted; elide: Text.ElideRight; font.family: ui.mono; font.pixelSize: ui.px(10.5) }
                  }
                  Rectangle {
                    id: deviceState
                    anchors.right: parent.right
                    anchors.rightMargin: ui.px(13)
                    anchors.verticalCenter: parent.verticalCenter
                    width: stateRow.implicitWidth + ui.px(20); height: ui.px(24); radius: height / 2
                    color: root.c.chip
                    Row {
                      id: stateRow
                      anchors.centerIn: parent
                      spacing: ui.px(5)
                      Icon { anchors.verticalCenter: parent.verticalCenter; name: modelData.verified ? "shield-check" : "shield-warning"; weight: modelData.verified ? "fill" : "regular"; size: ui.px(11); color: modelData.verified ? root.c.ok : root.c.warn }
                      Text { textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter; text: modelData.verified ? "Verified" : "Unverified"; color: modelData.verified ? root.c.ok : root.c.warn; font.family: ui.sans; font.pixelSize: ui.f11 }
                    }
                  }
                }
              }
            }
          }
        }
        Card {
          c: root.c
          width: parent.width
          VerificationFlow { id: verification; c: root.c; tips: root.tips; service: root.service; width: parent.width }
        }
        Note { text: root.service && root.service.secretsBackend === "keyring" ? "Session secrets are in your keyring." : root.service && root.service.secretsBackend === "file" ? "Session secrets are in session.json — no keyring was found." : "" }
      }

      // ===== Daemon =====
      Column {
        width: parent.width
        visible: root.section === "daemon"
        Process {
          id: storeSize
          property string out: ""
          command: ["/usr/bin/python3", "-I", root.service.helperPath, "store-size", root.dataDir]
          stdout: SplitParser { splitMarker: ""; onRead: function(d) { if (storeSize.out.length < 4096) storeSize.out += d } }
          onStarted: out = ""
          onExited: function() { try { root.storeSizeText = String(JSON.parse(storeSize.out).human || "—") } catch (e) { root.storeSizeText = "—" } }
        }
        SettingRow { c: root.c; label: "Socket"; description: "Mode 0600; the peer's uid is checked on every connection"; ValueText { text: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omarchy-yapper.sock" } }
        SettingRow { c: root.c; label: "Data directory"; description: "Mode 0700"; ValueText { text: root.dataDir } }
        SettingRow { c: root.c; label: "Store"; description: "SQLite, encrypted with a random passphrase"; ValueText { text: root.storeSizeText } }
        SettingRow { c: root.c; label: "Start the daemon when needed"; description: "Starts it when Yapper opens and it is installed but not running."; Toggle { c: root.c; checked: root.flag("autostartDaemon", true); onToggled: root.service.set("autostartDaemon", !checked) } }
        SettingRow {
          c: root.c; label: "Daemon"; description: root.service && root.service.daemonActive ? "Running. Stopping it pauses notifications; your session stays signed in." : "Stopped."
          Row {
            spacing: ui.px(8)
            PillButton { c: root.c; visible: root.service && root.service.daemonActive; label: "Stop"; icon: "stop"; round: true; onClicked: root.service.stopDaemon() }
            PillButton { c: root.c; visible: root.service && !root.service.daemonActive; label: root.service && root.service.starting ? "Starting…" : "Start"; icon: "play"; primary: true; round: true; enabled: root.service && root.service.installed && !root.service.starting; onClicked: root.service.startDaemon() }
            PillButton { c: root.c; visible: root.service && root.service.daemonActive; label: "Restart"; icon: "arrow-clockwise"; round: true; onClicked: root.service.restartDaemon() }
          }
        }
        SettingRow { c: root.c; label: "Package"; description: root.service && root.service.daemonKind === "bin" ? "The prebuilt release, installed through pacman from packaging/bin/PKGBUILD" : root.service && root.service.daemonKind === "source" ? "Built from source on this machine through pacman from packaging/PKGBUILD" : "Not installed"; ValueText { text: root.service && root.service.daemonPackage !== "" ? root.service.daemonPackage + " " + root.service.daemonPackageVersion : "—" } }
        SettingRow { c: root.c; label: "Reinstall"; description: "Installs release " + (root.service ? root.service.daemonPinVersion : "") + " again, prebuilt or from source, in a terminal. Your session stays signed in."; PillButton { c: root.c; label: root.service && root.service.installed ? "Reinstall" : "Install"; icon: "download-simple"; round: true; enabled: root.service && !root.service.installActive; onClicked: root.installRequested(false) } }
        InstallProgress { width: parent.width; visible: root.service && root.service.installState !== null; c: root.c; service: root.service }
        SettingRow {
          c: root.c; label: "Reset the data"; labelColor: root.c.bad; description: root.confirmReset ? "Signs you out on this machine and deletes the encrypted store in " + root.dataDir + ". Messages and keys backed up on the server stay; unbacked keys are lost." : "Stops the daemon, deletes " + root.dataDir + " and starts fresh."
          Row {
            spacing: ui.px(8)
            PillButton { c: root.c; visible: !root.confirmReset; label: "Reset"; round: true; enabled: root.service && root.service.installed && !root.service.installActive; onClicked: root.confirmReset = true }
            PillButton { c: root.c; visible: root.confirmReset; label: "Delete the data"; danger: true; round: true; onClicked: { root.confirmReset = false; root.service.resetData() } }
            PillButton { c: root.c; visible: root.confirmReset; label: "Keep"; round: true; onClicked: root.confirmReset = false }
          }
        }
        SettingRow {
          c: root.c; label: "Remove the daemon"; labelColor: root.c.bad; description: root.confirmRemoveDaemon ? "Stops and disables it, then runs " + root.service.removeCommand() + " in a terminal. \"Remove everything\" also deletes " + root.dataDir + " and ~/.cache/omarchy-yapper." : "Uninstalls the pacman package in a terminal."
          Row {
            spacing: ui.px(8)
            PillButton { c: root.c; visible: !root.confirmRemoveDaemon; label: "Remove"; round: true; enabled: root.service && root.service.daemonPackage !== "" && !root.service.installActive; onClicked: root.confirmRemoveDaemon = true }
            PillButton { c: root.c; visible: root.confirmRemoveDaemon; label: "Remove the package"; danger: true; round: true; onClicked: { root.confirmRemoveDaemon = false; root.service.removeDaemon(false) } }
            PillButton { c: root.c; visible: root.confirmRemoveDaemon; label: "Remove everything"; danger: true; round: true; onClicked: { root.confirmRemoveDaemon = false; root.service.removeDaemon(true) } }
            PillButton { c: root.c; visible: root.confirmRemoveDaemon; label: "Keep"; round: true; onClicked: root.confirmRemoveDaemon = false }
          }
        }
        SettingRow {
          c: root.c; label: "Logs"
          Row {
            spacing: ui.px(8)
            ValueText { anchors.verticalCenter: parent.verticalCenter; text: "journalctl --user -u omarchy-yapperd -f" }
            PillButton { c: root.c; anchors.verticalCenter: parent.verticalCenter; label: "Copy"; icon: "copy"; round: true; onClicked: root.service.copyText("journalctl --user -u omarchy-yapperd -f") }
          }
        }
      }
    }
  }
}
