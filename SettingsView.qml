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

  readonly property bool hasTextFocus: {
    for (var i = 0; i < fields.count; i++) {
      var it = fields.itemAt(i)
      if (it && it.textFocus) return true
    }
    return false
  }

  function current(key, fallback) { return root.service ? root.service.setting(key, fallback) : fallback }
  function themeFallback(key) {
    if (key === "backgroundColor") return Color.background
    if (key === "sidebarColor") return root.service ? root.service.bg : Color.background
    if (key === "textColor") return Color.foreground
    return Color.accent
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
      readonly property bool isColor: String(modelData.format || "") === "color"
      readonly property bool pickerOpen: root.pickKey === key
      readonly property string section: String(modelData.section || "")
      readonly property bool newSection: index === 0 || String((root.service.schema[index - 1] || {}).section || "") !== section
      required property int index
      width: root.width
      spacing: Style.space(4)

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
            text: String(Number(field.value) || field.modelData.defaultValue || 0) + (field.key === "fontScale" ? "%" : "")
            color: Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
          }
        }
        PanelSlider {
          width: parent.width
          minimum: Number(field.modelData.min !== undefined ? field.modelData.min : 0)
          maximum: Number(field.modelData.max !== undefined ? field.modelData.max : 100)
          step: Number(field.modelData.step || 1)
          integer: true
          value: Number(field.value) || 0
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
            color: colorMouse.containsMouse || field.pickerOpen ? Util.alpha(root.fg, 0.06) : "transparent"
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
