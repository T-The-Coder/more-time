import QtQuick
import qs.Commons

// The line above a tab's list: what the keys do (unless General › App ›
// Control hints is off), and the button for a new item at the far right:
// "+", its full name as tooltip.
Item {
  id: header
  required property var panel
  property string hint: ""
  property string addLabel: ""
  signal add()

  // From the conditions, not the children's `visible` (which follows this
  // item's own and would keep it hidden).
  readonly property bool hintShown: panel.showHints && hint !== ""
  readonly property bool addShown: addLabel !== ""
  visible: hintShown || addShown
  height: Math.max(addShown ? addButton.height : 0, hintShown ? hintText.implicitHeight : 0)

  // Right-aligned and muted like More Weather's section hints, directly
  // left of the button; shortened when there is no room.
  Text {
    textFormat: Text.PlainText
    id: hintText
    visible: header.hintShown
    anchors.right: header.addShown ? addButton.left : parent.right
    anchors.rightMargin: header.addShown ? Style.space(10) : 0
    anchors.verticalCenter: parent.verticalCenter
    width: Math.max(0, Math.min(implicitWidth,
      header.width - (header.addShown ? addButton.width + Style.space(10) : 0)))
    horizontalAlignment: Text.AlignRight
    text: header.hint
    color: header.panel.hintText
    font.family: header.panel.fontFamily
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
  }

  TimeButton {
    id: addButton
    visible: header.addShown
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    panel: header.panel
    width: height
    label: "+"
    tooltip: header.addLabel
    onActivated: header.add()
  }
}
