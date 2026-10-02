import QtQuick
import qs.Commons
import "Model.js" as Model
import "WorldMap.js" as WorldMap

// A clock face on a Canvas, in one of five styles (Model.DIAL_STYLES):
//   classic     12 marks, the quarters longer (the hero's dial so far)
//   minimal     four marks, thin hands
//   roman       I–XII
//   twentyFour  one turn a day, 00 at the bottom, 24 marks; the night part
//               of the face (sunset to sunrise there) shaded like the map's
//               night side (WorldMap.nightFill)
//   dots        12 dots, bold hands
// `parts` is the place's wall clock (Model.zonedParts); `sun` its
// WorldMap.sunTimes for twentyFour, `offset` the place's offset in seconds.
Canvas {
  id: dial
  required property var panel
  property string style: "classic"
  property var parts: ({ hour: 0, minute: 0, second: 0 })
  property bool showSeconds: false
  property var sun: null
  property int offset: 0

  implicitWidth: Style.space(96)
  implicitHeight: implicitWidth
  height: width

  property color ink: panel.foreground
  property color accent: Color.accent
  readonly property string paintKey: style + "|" + parts.hour + ":" + parts.minute + ":" + (showSeconds ? parts.second : "")
    + "|" + (sun ? sun.sunrise + "-" + sun.sunset + sun.polar : "")
  onPaintKeyChanged: requestPaint()
  onInkChanged: requestPaint()
  onAccentChanged: requestPaint()
  onWidthChanged: requestPaint()
  onVisibleChanged: if (visible) requestPaint()

  // Hours of the local day, 0–24, of an instant at the place.
  function localHours(ms) {
    var p = Model.zonedParts(ms, offset)
    return p.hour + p.minute / 60
  }

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    var r = width / 2
    if (r <= 0) return
    var s = Model.dialStyle(style)
    var small = r < Style.space(24)
    ctx.translate(r, r)
    var p = parts

    // The 24-hour face: night shaded first, under the marks.
    if (s === "twentyFour" && sun) {
      var nf = WorldMap.nightFill([Color.popups.background.r, Color.popups.background.g, Color.popups.background.b])
      ctx.fillStyle = Qt.rgba(nf.r, nf.g, nf.b, nf.a)
      if (sun.polar === "night") {
        ctx.beginPath()
        ctx.arc(0, 0, r - 1, 0, Math.PI * 2)
        ctx.fill()
      } else if (sun.polar !== "day" && sun.sunrise && sun.sunset) {
        // Angle on the canvas (0 to the right, clockwise) of a local hour:
        // 00 at the bottom, 12 at the top.
        var angle = function(h) { return Math.PI / 2 + h / 24 * Math.PI * 2 }
        ctx.beginPath()
        ctx.moveTo(0, 0)
        ctx.arc(0, 0, r - 1, angle(localHours(sun.sunset)), angle(localHours(sun.sunrise) + 24 * (localHours(sun.sunrise) < localHours(sun.sunset) ? 1 : 0)), false)
        ctx.closePath()
        ctx.fill()
      }
    }

    ctx.strokeStyle = ink
    ctx.globalAlpha = 0.35
    ctx.lineWidth = 1
    ctx.beginPath()
    ctx.arc(0, 0, r - 1, 0, Math.PI * 2)
    ctx.stroke()

    // Marks: a = angle from 12 o'clock, clockwise.
    function mark(a, inner, outer, widthPx, alpha) {
      ctx.globalAlpha = alpha
      ctx.lineWidth = widthPx
      ctx.beginPath()
      ctx.moveTo(Math.sin(a) * inner, -Math.cos(a) * inner)
      ctx.lineTo(Math.sin(a) * outer, -Math.cos(a) * outer)
      ctx.stroke()
    }
    var i
    if (s === "classic") {
      for (i = 0; i < 12; i++) mark(i * Math.PI / 6, i % 3 === 0 ? r * 0.79 : r * 0.875, r - 3, i % 3 === 0 ? 2 : 1, i % 3 === 0 ? 0.8 : 0.45)
    } else if (s === "minimal") {
      for (i = 0; i < 4; i++) mark(i * Math.PI / 2, r * 0.82, r - 3, 1.5, 0.7)
    } else if (s === "dots") {
      ctx.fillStyle = ink
      for (i = 0; i < 12; i++) {
        var da = i * Math.PI / 6
        ctx.globalAlpha = i % 3 === 0 ? 0.85 : 0.5
        ctx.beginPath()
        ctx.arc(Math.sin(da) * (r * 0.84), -Math.cos(da) * (r * 0.84), i % 3 === 0 ? Math.max(1.5, r * 0.06) : Math.max(1, r * 0.035), 0, Math.PI * 2)
        ctx.fill()
      }
    } else if (s === "roman") {
      if (small) {
        for (i = 0; i < 12; i++) mark(i * Math.PI / 6, r * 0.82, r - 2, 1, i % 3 === 0 ? 0.8 : 0.4)
      } else {
        var numerals = ["XII", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI"]
        ctx.fillStyle = ink
        ctx.globalAlpha = 0.75
        ctx.font = panel.canvasFont(Math.max(7, r * 0.2), false, false)
        ctx.textAlign = "center"
        ctx.textBaseline = "middle"
        for (i = 0; i < 12; i++) {
          var na = i * Math.PI / 6
          ctx.fillText(numerals[i], Math.sin(na) * r * 0.74, -Math.cos(na) * r * 0.74)
        }
      }
    } else if (s === "twentyFour") {
      // 00 at the bottom: hour h sits at angle π + h·π/12 from the top.
      for (i = 0; i < 24; i++) mark(Math.PI + i * Math.PI / 12, i % 6 === 0 ? r * 0.79 : r * 0.89, r - 3, i % 6 === 0 ? 2 : 1, i % 6 === 0 ? 0.8 : 0.4)
    }

    function hand(a, length, widthPx, color, alpha) {
      ctx.globalAlpha = alpha
      ctx.strokeStyle = color
      ctx.lineWidth = widthPx
      ctx.lineCap = "round"
      ctx.beginPath()
      ctx.moveTo(-Math.sin(a) * r * 0.06, Math.cos(a) * r * 0.06)
      ctx.lineTo(Math.sin(a) * length, -Math.cos(a) * length)
      ctx.stroke()
    }
    var scale = small ? 0.6 : 1
    var hourWidth = (s === "dots" ? 4 : (s === "minimal" ? 1.8 : 3)) * scale
    var minuteWidth = (s === "dots" ? 3 : (s === "minimal" ? 1.2 : 2)) * scale
    var hourAngle = s === "twentyFour"
      ? Math.PI + (p.hour + p.minute / 60) * Math.PI / 12
      : ((p.hour % 12) + p.minute / 60) * Math.PI / 6
    hand(hourAngle, r * 0.52, Math.max(1, hourWidth), ink, 1)
    hand((p.minute + (showSeconds ? p.second / 60 : 0)) * Math.PI / 30, r * 0.78, Math.max(1, minuteWidth), ink, 1)
    if (showSeconds) hand(p.second * Math.PI / 30, r * 0.84, 1, accent, 1)
    ctx.globalAlpha = 1
    ctx.fillStyle = accent
    ctx.beginPath()
    ctx.arc(0, 0, Math.max(1.5, r * 0.05), 0, Math.PI * 2)
    ctx.fill()
  }
}
