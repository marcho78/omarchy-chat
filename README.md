# Chat for Omarchy

End-to-end encrypted chat from the bar. It speaks Matrix, so it talks to
Element and everyone else on the network; encryption is Olm/Megolm via
matrix-rust-sdk, the same stack as Element X.

The plugin is QML only. Everything that touches keys or the network lives in
[omarchy-chatd](https://github.com/marcho78/omarchy-chatd), a small daemon
you build from source on your own machine. **No binary is downloaded, ever.**

## What you get

| In the bar | In the panel |
|---|---|
| Chat glyph with the unread count | Room list, unread and highlight counts, encrypted rooms marked 󰌾 |
| Left click opens the panel, middle click refreshes | One room at a time: recent history, live messages, composer |
| Dimmed while signed out | Enter sends, Escape goes back to the list, Escape again closes |
| Notifications for rooms you are not looking at | Sign in and sign out; the daemon keeps a token, never the password |

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

`Panel.qml` connects to the socket, sends `rooms` / `timeline` / `send`
requests and renders the replies, and listens for `state` and `message`
events. The one secret that passes through the shell is the password at sign
in: it goes straight to the socket and the field is cleared. The protocol is
documented in the [daemon's README](https://github.com/marcho78/omarchy-chatd#socket-protocol).

Panel states, top to bottom in the file: checking → daemon not installed
(command + buttons) → installed but not running (start button) → signed out
(form) → room list → one room. Reconnection is a timer: the socket does not
reconnect by itself, so the panel retries every 1.5 s while open and every
10 s while closed.

## Development

Work on a checkout directly in the plugin directory; the shell reloads
plugin code on save:

```bash
git clone https://github.com/marcho78/omarchy-chat ~/.config/omarchy/plugins/marcho78.chat
omarchy plugin enable marcho78.chat
omarchy plugin validate ~/.config/omarchy/plugins/marcho78.chat
journalctl --user -u omarchy-shell -f | grep '\[chat\]'
```

Test against a throwaway daemon without touching your real session:

```bash
omarchy-chatd --socket /tmp/chat-test.sock --data-dir /tmp/chat-test-data
# then, temporarily, socketPath: "/tmp/chat-test.sock" in Panel.qml
```

## Not yet

Device verification and key backup, attachments, reactions, edits, replies,
invites, starting a DM from the panel. Until verification lands, other
clients show this device as unverified and history from before you signed in
here is not readable. See the daemon's roadmap.

## License

MIT
