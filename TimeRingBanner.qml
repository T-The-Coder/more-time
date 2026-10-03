import QtQuick
import qs.Commons

// What rings right now, above everything else, with Stop and Snooze. Shown
// in every instance; the leader (TimeRinger) plays the sound.
Column {
  id: banner
  required property var panel
  visible: panel.ringer.ringing.length > 0
  spacing: Style.space(6)

  Repeater {
    model: banner.panel.ringer.ringing

    Rectangle {
      required property var modelData
      width: banner.width
      height: Style.space(52)
      radius: Style.cornerRadius
      color: Style.selectedFillFor(banner.panel.foreground, Color.urgent)
      border.color: Color.urgent
      border.width: Style.spacing.hairline

      Text {
        textFormat: Text.PlainText
        id: bell
        anchors.left: parent.left
        anchors.leftMargin: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{f009e}"
        color: Color.urgent
        font.family: banner.panel.fontFamily
        font.pixelSize: Style.font.heading

        SequentialAnimation on opacity {
          running: banner.visible
          loops: Animation.Infinite
          NumberAnimation { to: 0.3; duration: 500 }
          NumberAnimation { to: 1; duration: 500 }
        }
      }

      Column {
        anchors.left: bell.right
        anchors.leftMargin: Style.space(10)
        anchors.right: actions.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: parent.parent.modelData.title
          color: banner.panel.foreground
          font.family: banner.panel.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          elide: Text.ElideRight
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: parent.parent.modelData.body
          color: banner.panel.mutedText
          font.family: banner.panel.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      Row {
        id: actions
        anchors.right: parent.right
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)

        TimeButton {
          visible: parent.parent.modelData.kind === "alarm"
          panel: banner.panel
          label: banner.panel.i18n("snoozeShort")
          onActivated: banner.panel.ringer.snooze(parent.parent.modelData.key)
        }

        TimeButton {
          panel: banner.panel
          label: banner.panel.i18n("stop")
          onActivated: banner.panel.ringer.stop(parent.parent.modelData.key)
        }
      }
    }
  }

  Text {
    textFormat: Text.PlainText
    width: parent.width
    horizontalAlignment: Text.AlignHCenter
    text: banner.panel.i18n("ringingKeysHint")
    color: banner.panel.hintText
    font.family: banner.panel.fontFamily
    font.pixelSize: Style.font.caption
  }
}
