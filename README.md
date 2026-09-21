# Chat for Omarchy

End-to-end encrypted chat, in the bar and as a window. It speaks Matrix, so
it talks to Element and everyone else on the network; encryption is
Olm/Megolm via matrix-rust-sdk, the same stack as Element X.

The plugin is QML only. Everything that touches keys or the network lives in
[omarchy-chatd](https://github.com/marcho78/omarchy-chatd), a small daemon
you build from source on your own machine. **No binary is downloaded, ever.**

## What you get

| In the bar | In the popup and the window |
|---|---|
| Chat glyph with the unread count | Rooms with unread and highlight counts; encrypted rooms marked 󰌾, DMs 󰭹 |
| Left click opens the popup, middle click opens the window | **Find**: a word searches the public directory, `#alias:server` joins, `@user:server` opens a DM, `@name` finds people |
| Dimmed while signed out | **Room** creates one — end-to-end encrypted and private by default |
| Notifications for rooms no view is showing | Invitations with Accept / Decline; Leave room |
| | Recent history, live messages, composer; Enter sends |
| | Sign in with the browser (Google, GitHub, a password — whatever the homeserver offers) or with a password |

The popup is for a quick reply from the bar. The window is a normal
Hyprland toplevel — tiled, resizable, title `Chat` — with the room list on
the left and the conversation on the right. Both are views over one
connection to the daemon and stay in step.

## Install

```bash
omarchy plugin add https://github.com/marcho78/omarchy-chat.git --enable
```

Click the chat icon. Without the daemon the panel shows the command that
builds it:

```bash
git clone https://github.com/marcho78/omarchy-chatd && cd omarchy-chatd/packaging && makepkg -si
```

**Copy command** puts it on the clipboard for your own terminal — read the
`PKGBUILD` first if you like. **Open in terminal** runs the same thing in a
floating terminal. Either way `makepkg` compiles matrix-rust-sdk, so the
first build takes a few minutes and `-i` asks for your password to install
the package.

Back in the panel, **Check again** finds the daemon, the plugin starts it
(`systemctl --user start omarchy-chatd`) and shows the sign-in form. Any
Matrix homeserver works; `matrix.org` is pre-filled.

## The window

```bash
omarchy-shell shell summon marcho78.chat '{}'                       # open
omarchy-shell shell toggle marcho78.chat '{}'                       # toggle
omarchy-shell shell summon marcho78.chat '{"room":"!id:server"}'    # open into a room
```

A keybinding, in `~/.config/hypr/bindings.lua` (`SUPER+SHIFT+C` is Omarchy's
calendar, so pick something free):

```lua
o.bind("SUPER + SHIFT + T", "Chat", "omarchy-shell shell toggle marcho78.chat '{}'")
```

A launcher entry, so it shows up next to your other apps:

```bash
ln -s ~/.config/omarchy/plugins/marcho78.chat/omarchy-chat.desktop ~/.local/share/applications/
```

Window rules match on `title:^Chat` (the class is `org.quickshell`, shared
with the shell's other windows).

## Remove

```bash
omarchy plugin remove marcho78.chat
pacman -R omarchy-chatd                  # optional
rm -rf ~/.local/share/omarchy-chatd      # optional: drops the session and keys
```

## Settings

Set from Omarchy's bar settings or in `~/.config/omarchy/shell.json`:

| Key | Default | Meaning |
|---|---|---|
| `homeserver` | `https://matrix.org` | Pre-filled on the sign-in form |
| `notifications` | `true` | Desktop notifications for new messages in rooms not in view |
| `autostartDaemon` | `true` | Start the daemon's user unit when the panel opens |

## IPC

```bash
omarchy-shell marcho78.chat toggle
omarchy-shell marcho78.chat status     # {installed, connected, loggedIn, userId, syncing, unread, rooms, opened}
omarchy-shell marcho78.chat refresh
```

## How it fits together

```
Panel.qml ──── $XDG_RUNTIME_DIR/omarchy-chat.sock ──── omarchy-chatd ──── homeserver
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
protocol is documented in the [daemon's README](https://github.com/marcho78/omarchy-chatd#socket-protocol).
The socket does not reconnect by itself; the service retries every 5 s
while the daemon is absent.

## Development

Work on a checkout directly in the plugin directory; the shell reloads
plugin code on save:

```bash
git clone https://github.com/marcho78/omarchy-chat ~/.config/omarchy/plugins/marcho78.chat
omarchy plugin enable marcho78.chat
omarchy plugin validate ~/.config/omarchy/plugins/marcho78.chat
omarchy restart shell        # the QML cache survives the file watcher; restart after edits
journalctl --user -f -o cat | grep -i 'chat'
```

Test against a throwaway daemon without touching your real session:

```bash
omarchy-chatd --socket /tmp/chat-test.sock --data-dir /tmp/chat-test-data
# then, temporarily, socketPath: "/tmp/chat-test.sock" in Service.qml
```

## Not yet

Device verification and key backup, attachments, reactions, edits, replies,
typing indicators, member lists. Until verification lands, other clients
show this device as unverified and history from before you signed in here
is not readable. See the daemon's roadmap.

## License

MIT
