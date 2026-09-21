# Yapper

End-to-end encrypted chat, in the bar and as a window. It speaks Matrix, so
it talks to Element and everyone else on the network; encryption is
Olm/Megolm via matrix-rust-sdk, the same stack as Element X.

The plugin is QML only. Everything that touches keys or the network lives in
[omarchy-yapperd](https://github.com/marcho78/omarchy-yapperd), a small daemon
you build from source on your own machine. **No binary is downloaded, ever.**

## What you get

| In the bar | In the popup and the window |
|---|---|
| Yapper glyph with the unread count | Rooms with unread and highlight counts; encrypted rooms marked 󰌾, DMs 󰭹 |
| Left click opens the popup, middle click opens the window | **Find**: a word searches the public directory, `#alias:server` joins, `@user:server` opens a DM, `@name` finds people |
| Dimmed while signed out | **Room** creates one — end-to-end encrypted and private by default |
| Notifications for rooms no view is showing | Invitations with Accept / Decline; Leave room |
| | History back to the start of the room — scroll up or press *Load earlier*; live messages |
| | Multi-line composer: Enter sends, Shift+Enter (or Ctrl+Enter) starts a new line, grows to six lines then scrolls; unsent text is kept per room as a draft (shown 󰏫 in the room list) |
| | Images inline (click to open), files as cards with Open; send with 📎, drag-and-drop, or Ctrl+V an image — encrypted in encrypted rooms |
| | Voice messages: 󰍬 (or Ctrl+M) records from the microphone, Enter sends, Esc discards; sent as Opus with a waveform so Element shows them as voice notes; received ones play inline with a waveform scrubber |
| | Markdown in the composer (`**bold**`, `_italic_`, `` `code` ``, lists, quotes); `:tada` offers emoji, Tab or Enter inserts; 󰞅 opens Omarchy's emoji picker |
| | The first link in a message gets a preview card — title, description and image, fetched by your homeserver |
| | Replies, edits (Up edits your last message), reactions, read receipts, typing indicators; room info with members, invites and moderation |
| | Threads: 󰻞 on any message starts one; roots show "N replies · who · when"; the thread opens beside the conversation (or in its place when narrow, and in the popup) with its own composer; thread replies stay out of the room timeline |
| | Spaces, favourites, search across rooms and messages, per-room notification levels |
| | Bridged rooms (WhatsApp, Telegram, Signal, Discord… via a bridge on your homeserver or Beeper) show the network's logo, "via WhatsApp", who the bridge bot is, and say plainly that encryption stops at the bridge; bridged senders are tagged by name |
| | Sign in with the browser (Google, GitHub, a password — whatever the homeserver offers) or with a password |

The popup is for a quick reply from the bar. The window is a normal
Hyprland toplevel — tiled, resizable, title `Yapper` — with the room list on
the left and the conversation on the right. Both are views over one
connection to the daemon and stay in step.

## Install

```bash
omarchy plugin add https://github.com/marcho78/omarchy-yapper.git --enable
```

Click the chat icon. Without the daemon the panel shows the command that
builds it:

```bash
git clone https://github.com/marcho78/omarchy-yapperd && cd omarchy-yapperd && git checkout "$(git tag -l 'v*' --sort=-v:refname | head -1)" && cd packaging && makepkg -si
```

**Copy command** puts it on the clipboard for your own terminal — read the
`PKGBUILD` first if you like. **Open in terminal** runs the same thing in a
floating terminal. Either way `makepkg` compiles matrix-rust-sdk, so the
first build takes a few minutes and `-i` asks for your password to install
the package.

Back in the panel, **Check again** finds the daemon, the plugin starts it
(`systemctl --user start omarchy-yapperd`) and shows the sign-in form. Any
Matrix homeserver works; `matrix.org` is pre-filled.

## Encryption, verification and recovery

The first time you sign in, a red card asks you to **verify this device** —
until you do, other people's clients show it as untrusted and history from
before you signed in stays unreadable. Three ways:

* **Use another device** — Element on your phone, say. Both screens show the
  same seven emoji; confirm on both.
* **Use recovery key** — type the key you saved when you set up encryption.
* **Set up encryption** — first device on the account: creates your
  cross-signing identity and key backup and shows a recovery key **once**.
  Save it; it cannot be shown again.

Requests from your other devices show up as a notification and in the card,
with Accept / Decline. Nothing is accepted for you.

Settings → **Encryption** shows the state (verified, backup, other devices)
and **Reset recovery key** for when the key is lost: a new one is shown
once and the old one stops working.

## The window

```bash
omarchy-shell shell summon marcho78.yapper '{}'                       # open
omarchy-shell shell toggle marcho78.yapper '{}'                       # toggle
omarchy-shell shell summon marcho78.yapper '{"room":"!id:server"}'    # open into a room
omarchy-shell shell summon marcho78.yapper '{"room":"!id:server","thread":"$event"}'  # …and a thread in it
omarchy-shell shell summon marcho78.yapper '{"settings":true}'         # open on settings
omarchy-shell shell summon marcho78.yapper '{"pick":"accentColor"}'    # open a colour picker
```

A keybinding, in `~/.config/hypr/bindings.lua` (`SUPER+SHIFT+C` is Omarchy's
calendar, so pick something free):

```lua
o.bind("SUPER + SHIFT + T", "Yapper", "omarchy-shell shell toggle marcho78.yapper '{}'")
```

A launcher entry and its icon, so it shows up next to your other apps:

```bash
P=~/.config/omarchy/plugins/marcho78.yapper
ln -s $P/omarchy-yapper.desktop ~/.local/share/applications/
mkdir -p ~/.local/share/icons/hicolor/{scalable,256x256,48x48}/apps
ln -s $P/icon.svg ~/.local/share/icons/hicolor/scalable/apps/omarchy-yapper.svg
rsvg-convert -w 256 -h 256 $P/icon.svg -o ~/.local/share/icons/hicolor/256x256/apps/omarchy-yapper.png
rsvg-convert -w 48 -h 48 $P/icon.svg -o ~/.local/share/icons/hicolor/48x48/apps/omarchy-yapper.png
```

Window rules match on `title:^Yapper` (the class is `org.quickshell`, shared
with the shell's other windows).

## Remove

```bash
omarchy plugin remove marcho78.yapper
pacman -R omarchy-yapperd                  # optional
rm -rf ~/.local/share/omarchy-yapperd      # optional: drops the session and keys
```

## Settings

The ⚙ gear — top of the window's sidebar, or in the popup's header — opens a
settings screen; changes apply as you make them and are stored in
`~/.config/omarchy/shell.json` on the widget's entry. The same keys work
from the CLI (`omarchy bar set marcho78.yapper <key> <value>`):

| Key | Default | Meaning |
|---|---|---|
| `homeserver` | `https://matrix.org` | Pre-filled on the sign-in form |
| `notifications` | `true` | Desktop notifications for new messages in rooms not in view |
| `autostartDaemon` | `true` | Start the daemon's user unit when the panel opens |
| `backgroundColor`, `sidebarColor`, `textColor`, `accentColor`, `hoverColor`, `selectionColor` | empty | Picked in the settings screen (hue bar, saturation/value square, theme swatches, hex); empty follows the Omarchy theme |
| `messageStyle` | `flat` | `flat` (avatar, name, grouped runs) or `bubbles` (yours right, theirs left) |
| `showAvatars` | `true` | Avatars in the timeline and DM list |
| `senderColors` | `true` | A stable colour per sender's name |
| `fontScale` | `100` | Chat text size in percent, 80–150 |
| `linkPreviews` | `true` | Preview card for the first link in a message (your homeserver fetches the page, not this machine) |
| `voiceVolume` | `100` | Playback volume for voice messages, 20–100 % of the system output; notes are loudness-normalised on the way in and out |
| `roomSort` | `activity` | Room list order: `activity` or `name` |
| `checkUpdates` | `true` | Look for plugin and daemon updates when the panel opens |

The screen is rendered from the manifest's `barWidget.schema`, so a new
setting needs only a schema entry.

## Updates

Once a day (and at startup) Yapper compares the installed plugin with its git
remote and the running daemon's version with the newest `v*` tag of
[omarchy-yapperd](https://github.com/marcho78/omarchy-yapperd). When either is
behind, a 󰚰 appears next to the bar glyph and a card at the top of the popup
and the window says what is new, with an **Update** button:

* **Plugin** runs `omarchy plugin update marcho78.yapper` in a floating
  terminal — it shows the diff and asks before pulling — then restarts the shell.
* **Daemon** clones the repo, checks out exactly the release the card
  named, builds it with `makepkg -si` and restarts the daemon's unit. Your
  session stays signed in. Updates are never step-by-step: from any version,
  one update lands on the newest release.

Nothing is ever installed without you confirming in that terminal. The
About card at the top of Settings shows both versions, when the last check
ran, and a **Check for updates** button; the daily check can be turned off
under Settings → Updates. The version line under your account in the
window's sidebar lights up too.

## IPC

```bash
omarchy-shell marcho78.yapper toggle
omarchy-shell marcho78.yapper status     # {installed, connected, loggedIn, userId, syncing, unread, rooms, opened}
omarchy-shell marcho78.yapper refresh
omarchy-shell marcho78.yapper checkUpdates
omarchy-shell marcho78.yapper updates      # {daemon, daemonLatest, daemonUpdate, pluginBehind, pluginUpdate, lastChecked, error, checking}
```

## How it fits together

```
Panel.qml ──── $XDG_RUNTIME_DIR/omarchy-yapper.sock ──── omarchy-yapperd ──── homeserver
 renders            JSON lines, 0600, uid-checked        keys, store, sync
```

The plugin has three kinds:

| Kind | File | Role |
|---|---|---|
| `service` | `Service.qml` | The socket, session state, room and invitation lists, notifications. Mounted when the shell starts. |
| `bar-widget` | `Panel.qml` | The bar glyph and its popup. |
| `panel` | `Window.qml` | The app window (`FloatingWindow`), summoned by `omarchy-shell shell summon`. |

Shared pieces: `SessionGate.qml` (daemon missing → not running → sign in →
waiting for the browser), `RoomList.qml` (find, create, invitations, rooms)
and `RoomView.qml` (timeline and composer). Views register the room they are
showing with the service, which only notifies for rooms nobody is looking at.

The one secret that passes through the shell is the password on a password
sign-in: it goes straight to the socket and the field is cleared. The
protocol is documented in the [daemon's README](https://github.com/marcho78/omarchy-yapperd#socket-protocol).
The socket does not reconnect by itself; the service retries every 5 s
while the daemon is absent.

## Development

Work on a checkout directly in the plugin directory; the shell reloads
plugin code on save:

```bash
git clone https://github.com/marcho78/omarchy-yapper ~/.config/omarchy/plugins/marcho78.yapper
omarchy plugin enable marcho78.yapper
omarchy plugin validate ~/.config/omarchy/plugins/marcho78.yapper
omarchy restart shell        # the QML cache survives the file watcher; restart after edits
journalctl --user -f -o cat | grep -i 'chat'
```

Test against a throwaway daemon without touching your real session:

```bash
omarchy-yapperd --socket /tmp/chat-test.sock --data-dir /tmp/chat-test-data
# then, temporarily, socketPath: "/tmp/chat-test.sock" in Service.qml
```

## Not yet

Calls (Element Call in the browser), multiple accounts. See the daemon's
roadmap.

## License

MIT
