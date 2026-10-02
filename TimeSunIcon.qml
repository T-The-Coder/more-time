import QtQuick
import qs.Commons

// Sunrise or sunset as More Weather draws it (Panel.paintSunEventIcon): a
// horizon line and an arrow up (rising) or down.
Canvas {
  id: icon
  property bool rising: true
  property color iconColor: Color.foreground
  property bool bold: false
  implicitWidth: Style.space(11)
  implicitHeight: Style.space(11)
  onRisingChanged: requestPaint()
  onIconColorChanged: requestPaint()
  onBoldChanged: requestPaint()
  onWidthChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.clearRect(0, 0, width, height)
    ctx.strokeStyle = iconColor
    ctx.lineWidth = bold ? 2 : 1.2
    ctx.lineCap = "round"
    ctx.lineJoin = "round"
    var centerX = width / 2
    var baselineY = height - 1
    var tipY = rising ? 1 : baselineY - 0.5
    var farY = rising ? baselineY - 0.5 : 1
    var arrowWing = 2.25
    ctx.beginPath()
    ctx.moveTo(1, baselineY)
    ctx.lineTo(width - 1, baselineY)
    ctx.moveTo(centerX, farY)
    ctx.lineTo(centerX, tipY)
    ctx.moveTo(centerX, tipY)
    ctx.lineTo(centerX - arrowWing, rising ? tipY + arrowWing : tipY - arrowWing)
    ctx.moveTo(centerX, tipY)
    ctx.lineTo(centerX + arrowWing, rising ? tipY + arrowWing : tipY - arrowWing)
    ctx.stroke()
  }
}
