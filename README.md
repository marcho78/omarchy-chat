# Chat for Omarchy

End-to-end encrypted chat from the bar. Matrix, so it talks to Element and
everyone else on the network; Olm/Megolm via matrix-rust-sdk, the same stack
as Element X.

The plugin is QML only. Everything that touches keys or the network lives in
[omarchy-chatd](https://github.com/marcho78/omarchy-chatd), a small daemon you
build from source on your own machine. **No binary is downloaded, ever.**

## What you get

* Bar icon with the unread count; click for the panel, middle-click to refresh.
* Room list with a lock per room: 󰌾 encrypted, 󰌿 not. Unread and highlight counts.
* One room at a time: recent history, live messages, a composer. Enter sends,
  Escape goes back, Escape again closes.
* Desktop notifications for messages in rooms you are not looking at
  (respects the shell's do-not-disturb).
* Sign in / sign out from the panel. The password goes to the local daemon
  over a 0600, uid-checked socket and is never stored; the daemon keeps an
  access token and an encrypted store.

## Install

```bash
omarchy plugin add https://github.com/marcho78/omarchy-chat.git --enable
```

Click the chat icon. If the daemon is missing, the panel shows the command
that builds it:

```bash
git clone https://github.com/marcho78/omarchy-chatd && cd omarchy-chatd/packaging && makepkg -si
```

Copy it, or press **Open in terminal** to run it in a floating terminal. It
compiles matrix-rust-sdk, so the first build takes a few minutes. Then the
panel starts the daemon (`systemctl --user start omarchy-chatd`) and shows the
sign-in form.

## Remove

```bash
omarchy plugin remove marcho78.chat
pacman -R omarchy-chatd          # optional; also: rm -rf ~/.local/share/omarchy-chatd
```

## Settings

| Key | Default | Meaning |
|---|---|---|
| `homeserver` | `https://matrix.org` | Pre-filled on the sign-in form |
| `notifications` | `true` | Desktop notifications for new messages |
| `autostartDaemon` | `true` | Start the daemon's user unit when the panel opens |

## IPC

```bash
omarchy-shell marcho78.chat toggle
omarchy-shell marcho78.chat status
```

## Not yet

Device verification and key backup, attachments, reactions and edits. Until
verification lands, other clients show this device as unverified and history
from before you signed in here is not readable. See the daemon's roadmap.

## License

MIT
