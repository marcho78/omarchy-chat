import QtQuick
import qs.Commons

// Yapper as an app window. The window itself is drawn by the chosen look
// (`looks/<look>/Window.qml`); this root only hands the host's calls and
// properties through, so a look swap is a reload of that file.
//
//   omarchy-shell shell summon marcho78.yapper '{}'   # open
//   omarchy-shell shell toggle marcho78.yapper '{}'   # toggle
//   omarchy-shell shell hide marcho78.yapper          # close
//
// The payload may carry { room, thread, settings, pick, info, search, people, space }.
Item {
  id: root
  property var shell: null
  property var service: null
  readonly property string look: service ? service.look : "omarchy"
  readonly property var window: content.item

  // Remember an open request that arrives before the look has loaded.
  property string pendingPayload: ""
  property bool pendingOpen: false

  function open(payloadJson) {
    if (content.item) { content.item.open(payloadJson) }
    else { root.pendingOpen = true; root.pendingPayload = payloadJson || "" }
  }
  function close() { if (content.item) content.item.close() }

  Loader {
    id: content
    source: "looks/" + root.look + "/Window.qml"
    onLoaded: {
      item.shell = Qt.binding(function() { return root.shell })
      item.service = Qt.binding(function() { return root.service })
      if (root.pendingOpen) { root.pendingOpen = false; item.open(root.pendingPayload) }
    }
    onStatusChanged: if (status === Loader.Error) console.log("[yapper] window look failed to load: " + source)
  }

  // A look change while the window is open: reopen it in the new look.
  onLookChanged: if (content.item && content.item.opened) { root.pendingOpen = true; root.pendingPayload = "" }
}
