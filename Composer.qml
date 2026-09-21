import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// The message box: a multi-line input styled like the shell's TextField.
// Enter sends (`accepted`); Shift+Enter or Ctrl+Enter starts a new line.
// It grows with the text up to `maxLines`, then scrolls to follow the cursor.
Item {
  id: root

  property color foreground: Color.foreground
  property color accent: Color.accent
  property int maxLines: 6
  property alias text: area.text
  property alias cursorPosition: area.cursorPosition
  property alias placeholderText: area.placeholderText
  property alias maximumLength: limiter.max
  property alias hasFocus: area.activeFocus
  readonly property int lineCount: area.lineCount

  // Enter with no modifier. Other keys arrive on `keyPressed` before the
  // text area sees them; set `event.accepted` to swallow one.
  signal accepted()
  signal keyPressed(var event)

  function forceActiveFocus() { area.forceActiveFocus() }
  function paste() { area.paste() }
  function insert(position, str) { area.insert(position, str) }
  function clear() { area.clear() }

  readonly property bool _focused: area.activeFocus
  readonly property bool _hot: area.hovered
  readonly property var _borderSpec: Border.controlSpec(_focused ? "focus" : (_hot ? "hover-cursor" : "normal"), root.foreground, root.accent)
  readonly property real _lineHeight: metrics.height
  readonly property real _frame: area.topPadding + area.bottomPadding

  FontMetrics { id: metrics; font: area.font }
  QtObject { id: limiter; property int max: 4000 }

  implicitHeight: Math.min(Math.max(area.contentHeight, _lineHeight), _lineHeight * maxLines) + _frame

  BorderSurface {
    anchors.fill: parent
    color: Style.controlFill(root._focused, root._hot, root.foreground, root.accent)
    borderSpec: root._borderSpec
    radius: Style.cornerRadius
  }

  Flickable {
    id: flick
    anchors.fill: parent
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height
    TextArea.flickable: TextArea {
      id: area
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      color: root.foreground
      selectionColor: Style.selectionFillFor(root.foreground, root.accent)
      selectedTextColor: root.foreground
      placeholderTextColor: Qt.darker(root.foreground, 1.6)
      wrapMode: TextEdit.Wrap
      selectByMouse: true
      persistentSelection: false
      hoverEnabled: true
      background: null
      leftPadding: Style.spacing.controlPaddingX + Border.left(root._borderSpec)
      rightPadding: Style.spacing.controlPaddingX + Border.right(root._borderSpec)
      topPadding: Style.spacing.inputPaddingY + Border.top(root._borderSpec)
      bottomPadding: Style.spacing.inputPaddingY + Border.bottom(root._borderSpec)
      onTextChanged: if (text.length > limiter.max) { var c = cursorPosition; text = text.substring(0, limiter.max); cursorPosition = Math.min(c, limiter.max) }
      Keys.onPressed: function(event) {
        root.keyPressed(event)
        if (event.accepted) return
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          event.accepted = true
          if (event.modifiers & (Qt.ShiftModifier | Qt.ControlModifier)) area.insert(area.cursorPosition, "\n")
          else root.accepted()
        }
      }
    }
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
  }
}
