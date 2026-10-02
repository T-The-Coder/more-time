import QtQuick
import qs.Commons

// The label over the flat map and the globe for what the pointer rests on:
// a zone ("UTC+2 · 7:42 PM (standard time)": the maps draw standard time, so
// the label says so rather than show an hour that may be off) or the Moon
// ("Moon · 61 % · waxing"). hover: { minutes | moon, x, y } or null.
Rectangle {
  id: label
  required property var panel
  property var hover: null
  property real boundsWidth: 0

  visible: hover !== null
  x: hover ? Math.min(boundsWidth - width, hover.x + Style.space(12)) : 0
  y: hover ? Math.max(0, hover.y - height - Style.space(6)) : 0
  width: text.implicitWidth + Style.space(12)
  height: text.implicitHeight + Style.space(6)
  radius: Style.cornerRadius
  color: Color.popups.background
  border.color: panel.subtleText
  border.width: Style.spacing.hairline

  Text {
    id: text
    anchors.centerIn: parent
    text: label.panel.mapHoverText(label.hover)
    color: label.panel.foreground
    font.family: label.panel.fontFamily
    font.pixelSize: Style.font.caption
  }
}
