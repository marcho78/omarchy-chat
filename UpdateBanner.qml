import QtQuick
import qs.Commons
import qs.Ui

// "An update is available" card. Hidden when there is nothing to do.
Rectangle {
  id: root
  property var service: null
  property color fg: Color.foreground
  property string fontFamily: Style.font.family

  readonly property bool daemon: service ? service.daemonUpdateAvailable : false
  readonly property bool plugin: service ? service.pluginUpdateAvailable : false
  visible: daemon || plugin
  implicitHeight: visible ? column.implicitHeight + Style.space(24) : 0
  radius: Style.space(8)
  color: Util.alpha(service ? service.accent : Color.accent, 0.12)
  border.width: 1
  border.color: service ? service.accent : Color.accent

  Column {
    id: column
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.space(12)
    spacing: Style.space(8)

    // Daemon
    Item {
      width: parent.width
      visible: root.daemon
      implicitHeight: Math.max(daemonText.implicitHeight, daemonButton.implicitHeight)
      Column {
        id: daemonText
        anchors.left: parent.left
        anchors.right: daemonButton.left
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)
        Text {
          text: "󰚰  Yapper daemon " + (root.service ? root.service.daemonLatest : "")
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }
        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          text: "You have " + (root.service ? root.service.daemonVersion : "") + ". Builds from source in a terminal (a few minutes), then restarts the daemon; your session stays signed in."
          color: root.fg
          opacity: 0.7
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
      Button {
        id: daemonButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: "Update"
        bordered: true
        onClicked: root.service.updateDaemon()
      }
    }

    PanelSeparator { width: parent.width; visible: root.daemon && root.plugin }

    // Plugin
    Item {
      width: parent.width
      visible: root.plugin
      implicitHeight: Math.max(pluginText.implicitHeight, pluginButton.implicitHeight)
      Column {
        id: pluginText
        anchors.left: parent.left
        anchors.right: pluginButton.left
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)
        Text {
          text: "󰚰  Yapper plugin: " + (root.service ? root.service.pluginUpdateCount : 0) + (root.service && root.service.pluginUpdateCount === 1 ? " new change" : " new changes")
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }
        Repeater {
          model: root.service ? root.service.pluginUpdateLog.slice(0, 4) : []
          delegate: Text {
            required property string modelData
            width: pluginText.width
            text: "· " + modelData
            elide: Text.ElideRight
            color: root.fg
            opacity: 0.7
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          text: "Shows the diff in a terminal for you to confirm, then restarts the shell."
          color: root.fg
          opacity: 0.55
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
      Button {
        id: pluginButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: "Update"
        bordered: true
        onClicked: root.service.updatePlugin()
      }
    }
  }
}
