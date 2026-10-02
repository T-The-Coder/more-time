import QtQuick
import qs.Commons

// A thin bar from 0 to 1, for timers and pomodoros.
Rectangle {
  id: bar
  required property var panel
  property real progress: 0
  property color tint: Color.accent

  height: Style.space(4)
  radius: height / 2
  color: Qt.rgba(panel.foreground.r, panel.foreground.g, panel.foreground.b, 0.12)

  Rectangle {
    // Grows from the reading side in right-to-left languages too.
    x: bar.LayoutMirroring.enabled ? bar.width - width : 0
    width: Math.max(0, Math.min(1, bar.progress)) * bar.width
    height: parent.height
    radius: parent.radius
    color: bar.tint
  }
}
