import QtQuick
import "../../shared"
import "../../shared/Palettes.js" as Palettes

// The strip on the far left: home, your spaces, the community, the
// public directory and message search; settings and the encryption
// state at the bottom.
Item {
  id: root
  property var c: Palettes.fallback()
  property var tips: null
  property var service: null
  property string view: "chat"
  readonly property string currentSpace: service ? service.currentSpace : ""
  readonly property bool verified: service ? service.deviceVerified : false
  readonly property bool needsVerification: service ? service.needsVerification : false
  signal viewRequested(string view)
  signal spaceRequested(string spaceId)
  signal verifyRequested()
  signal quitRequested()
  Ui { id: ui }

  width: ui.railWidth

  component RailButton: Item {
    id: button
    property string icon: ""
    property string weight: "regular"
    property bool active: false
    property string tooltip: ""
    signal clicked()
    width: ui.px(38)
    height: ui.px(38)
    Rectangle {
      anchors.fill: parent
      radius: ui.px(12)
      color: button.active ? root.c.sel : (railMouse.containsMouse ? root.c.hover : "transparent")
    }
    Icon {
      anchors.centerIn: parent
      name: button.icon
      weight: button.weight
      size: ui.px(17)
      color: button.active ? root.c.accent : (railMouse.containsMouse ? root.c.fg : root.c.muted)
    }
    // The selection mark on the rail's edge.
    Rectangle {
      x: -ui.px(9)
      anchors.verticalCenter: parent.verticalCenter
      width: ui.px(3)
      height: button.active ? ui.px(20) : 0
      radius: ui.px(3)
      color: root.c.accent
      Behavior on height { NumberAnimation { duration: 120 } }
    }
    MouseArea {
      id: railMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: button.clicked()
      onContainsMouseChanged: {
        if (!root.tips || button.tooltip === "") return
        if (containsMouse) root.tips.show(button, button.tooltip, "right"); else root.tips.hide(button)
      }
    }
  }

  Rectangle { anchors.fill: parent; color: root.c.bg2 }
  Rectangle {
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: 1
    color: root.c.line
  }

  Column {
    anchors.top: parent.top
    anchors.topMargin: ui.px(10)
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: ui.px(6)

    RailButton {
      icon: "house"; weight: "fill"
      active: root.view === "chat" && root.currentSpace === ""
      tooltip: "Home — every room"
      onClicked: { root.spaceRequested(""); root.viewRequested("chat") }
    }

    // Your spaces: each one filters the sidebar to its rooms.
    Repeater {
      model: root.service ? root.service.spaces : []
      delegate: Item {
        id: spaceButton
        required property var modelData
        readonly property bool active: root.view === "chat" && root.currentSpace === modelData.id
        width: ui.px(38)
        height: ui.px(38)
        Rectangle {
          anchors.fill: parent
          anchors.margins: -ui.px(3)
          radius: ui.px(14)
          color: spaceMouse.containsMouse && !spaceButton.active ? root.c.hover : "transparent"
        }
        Avatar {
          anchors.fill: parent
          service: root.service
          mxc: spaceButton.modelData.avatar || ""
          name: spaceButton.modelData.name
          userId: spaceButton.modelData.id
          size: ui.px(38)
          radius: spaceButton.active ? ui.px(12) : ui.px(14)
          fallbackColor: spaceButton.active ? root.c.sel : root.c.surface
          initialColor: spaceButton.active ? root.c.accent : root.c.fg
          fontFamily: ui.sans
          Behavior on radius { NumberAnimation { duration: 120 } }
        }
        Rectangle {
          x: -ui.px(9)
          anchors.verticalCenter: parent.verticalCenter
          width: ui.px(3)
          height: spaceButton.active ? ui.px(20) : 0
          radius: ui.px(3)
          color: root.c.accent
          Behavior on height { NumberAnimation { duration: 120 } }
        }
        MouseArea {
          id: spaceMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: { root.spaceRequested(spaceButton.modelData.id); root.viewRequested("chat") }
          onContainsMouseChanged: {
            if (!root.tips) return
            if (containsMouse) root.tips.show(spaceButton, spaceButton.modelData.name, "right"); else root.tips.hide(spaceButton)
          }
        }
      }
    }

    RailButton { icon: "users-three"; active: root.view === "people"; tooltip: "Omarchy community"; onClicked: root.viewRequested("people") }
    RailButton { icon: "compass"; active: root.view === "explore"; tooltip: "Explore public rooms"; onClicked: root.viewRequested("explore") }
    RailButton { icon: "magnifying-glass"; active: root.view === "search"; tooltip: "Search messages"; onClicked: root.viewRequested("search") }
  }

  Column {
    anchors.bottom: parent.bottom
    anchors.bottomMargin: ui.px(10)
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: ui.px(6)

    RailButton { icon: "gear-six"; active: root.view === "settings"; tooltip: "Settings"; onClicked: root.viewRequested("settings") }
    RailButton { icon: "power"; tooltip: "Quit Yapper"; onClicked: root.quitRequested() }

    // Encryption: a green shield when this device is verified, a warning
    // ring until then.
    Item {
      id: shield
      anchors.horizontalCenter: parent.horizontalCenter
      width: ui.px(30)
      height: ui.px(30)
      Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: shieldMouse.containsMouse ? root.c.hover : root.c.chip
        border.width: 1.5
        border.color: root.needsVerification ? root.c.warn : (root.verified ? root.c.ok : root.c.line)
      }
      Icon {
        anchors.centerIn: parent
        name: root.needsVerification ? "shield-warning" : "shield-check"
        weight: "fill"
        size: ui.px(14)
        color: root.needsVerification ? root.c.warn : (root.verified ? root.c.ok : root.c.muted)
      }
      MouseArea {
        id: shieldMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.verifyRequested()
        onContainsMouseChanged: {
          if (!root.tips) return
          var label = root.needsVerification ? "Verify this device" : (root.verified ? "This device is verified" : "Encryption")
          if (containsMouse) root.tips.show(shield, label, "right"); else root.tips.hide(shield)
        }
      }
    }
  }
}
