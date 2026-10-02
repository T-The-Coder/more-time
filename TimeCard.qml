import QtQuick
import qs.Commons

// One item of a tab's list (an alarm, a timer …): a bordered card that a
// click selects. The keyboard acts on the selected card; a delete waiting
// for its second press shows in the urgent colour.
Rectangle {
  id: card
  required property var panel
  property bool selected: false
  property bool armed: false
  property bool highlighted: false
  default property alias content: inner.data
  signal clicked()

  width: parent ? parent.width : 0
  height: inner.implicitHeight + Style.space(20)
  radius: Style.cornerRadius
  color: highlighted ? Style.selectedFillFor(panel.foreground, Color.accent)
    : (cardMouse.containsMouse ? Style.hoverFillFor(panel.foreground, Color.accent) : "transparent")
  border.color: armed ? Color.urgent : (selected ? Color.accent : panel.subtleText)
  border.width: Style.spacing.hairline

  // Behind the content, so buttons inside keep their own clicks.
  MouseArea {
    id: cardMouse
    anchors.fill: parent
    hoverEnabled: true
    onClicked: card.clicked()
  }

  Column {
    id: inner
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.space(10)
    spacing: Style.space(6)
  }
}
