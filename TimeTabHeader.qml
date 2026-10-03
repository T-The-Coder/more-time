import QtQuick
import qs.Commons

// The line above a tab's list: what the keys do, and the button for a new
// item at the far right.
Item {
  id: header
  required property var panel
  property string hint: ""
  property string addLabel: ""
  signal add()

  height: Math.max(addButton.visible ? addButton.height : 0, hintText.implicitHeight)

  // Right-aligned and muted like More Weather's section hints, directly
  // left of the button; shortened when there is no room.
  Text {
    textFormat: Text.PlainText
    id: hintText
    anchors.right: addButton.visible ? addButton.left : parent.right
    anchors.rightMargin: addButton.visible ? Style.space(10) : 0
    anchors.verticalCenter: parent.verticalCenter
    width: Math.max(0, Math.min(implicitWidth,
      header.width - (addButton.visible ? addButton.width + Style.space(10) : 0)))
    horizontalAlignment: Text.AlignRight
    text: header.hint
    color: header.panel.hintText
    font.family: header.panel.fontFamily
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
  }

  TimeButton {
    id: addButton
    visible: header.addLabel !== ""
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    panel: header.panel
    label: "+  " + header.addLabel
    onActivated: header.add()
  }
}
