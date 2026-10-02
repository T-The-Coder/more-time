import QtQuick
import qs.Commons

// A number in an editor (hours, minutes, lengths) with − and +; ↑ ↓ change
// it while the keyboard is on it (kbFocused).
Column {
  id: stepper
  required property var panel
  property string title: ""
  property string valueText: ""
  property bool kbFocused: false
  signal step(int delta)
  signal focusRequested()

  spacing: Style.space(2)

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    text: stepper.title
    color: stepper.panel.mutedText
    font.family: stepper.panel.fontFamily
    font.pixelSize: Style.font.caption
  }

  Rectangle {
    width: Math.max(Style.space(86), valueLabel.implicitWidth + Style.space(60))
    height: Style.space(32)
    radius: Style.cornerRadius
    color: stepper.kbFocused ? Style.hoverFillFor(stepper.panel.foreground, Color.accent) : "transparent"
    border.color: stepper.kbFocused ? Color.accent : stepper.panel.subtleText
    border.width: Style.spacing.hairline

    MouseArea {
      anchors.fill: parent
      onClicked: stepper.focusRequested()
      onWheel: function(wheel) { stepper.step(wheel.angleDelta.y > 0 ? 1 : -1) }
    }

    TimeIconButton {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      panel: stepper.panel
      glyph: "−"
      glyphSize: Style.font.body
      implicitWidth: Style.space(26)
      onActivated: {
        stepper.focusRequested()
        stepper.step(-1)
      }
    }

    Text {
      id: valueLabel
      anchors.centerIn: parent
      text: stepper.valueText
      color: stepper.panel.foreground
      font.family: stepper.panel.fontFamily
      font.pixelSize: Style.font.title
      font.bold: true
    }

    TimeIconButton {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      panel: stepper.panel
      glyph: "+"
      glyphSize: Style.font.body
      implicitWidth: Style.space(26)
      onActivated: {
        stepper.focusRequested()
        stepper.step(1)
      }
    }
  }
}
