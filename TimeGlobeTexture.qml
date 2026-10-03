import QtQuick
import qs.Commons
import "WorldMap.js" as WorldMap

// The World tab's picture of the earth for the GPU surface
// (TimeGlobeSurface.qml): an equirectangular Canvas (longitude −180…180°
// across, latitude +90…−90° down) with the time zones in alternating
// stripes, the zones off the full hour hatched, this computer's zone in the
// accent and the land's faint fill; the same as the Canvas path draws
// (TimeGlobe.qml, TimeWorldMap.qml). Painted only when the zones, the home
// zone or the theme change; never per frame. The night is the shader's.
Canvas {
  id: texture
  // Globe.prepareData's rings: zones [{ o, rings: [{ p: [lat, lon, …] }] }]
  // and land [{ p }].
  property var globeData: null
  property int homeZone: 99999
  property color ink: "white"
  property color accent: Color.accent
  // What painting costs (ms, the last repaint), for the status.
  property real lastMs: 0

  width: 1024
  height: 512
  // Plain pixels: the shader filters them.
  antialiasing: true

  onGlobeDataChanged: requestPaint()
  onHomeZoneChanged: requestPaint()
  onInkChanged: requestPaint()
  onAccentChanged: requestPaint()

  function rgba(color, alpha) {
    return Qt.rgba(color.r, color.g, color.b, alpha)
  }

  function traceRing(ctx, p) {
    var w = width, h = height
    ctx.moveTo((p[1] + 180) / 360 * w, (90 - p[0]) / 180 * h)
    for (var i = 2; i < p.length; i += 2) ctx.lineTo((p[i + 1] + 180) / 360 * w, (90 - p[i]) / 180 * h)
    ctx.closePath()
  }

  onPaint: {
    var started = Date.now()
    var ctx = getContext("2d")
    ctx.reset()
    var data = globeData
    if (!data) return
    ctx.fillRule = Qt.OddEvenFill
    var hatch = ctx.createPattern(rgba(ink, 0.16), Qt.BDiagPattern)
    for (var z = 0; z < data.zones.length; z++) {
      var zone = data.zones[z]
      var band = WorldMap.zebraBand(zone.o)
      ctx.beginPath()
      for (var r = 0; r < zone.rings.length; r++) traceRing(ctx, zone.rings[r].p)
      ctx.fillStyle = zone.o === homeZone ? rgba(accent, 0.22)
        : (band === 2 ? hatch : rgba(ink, band === 1 ? 0.12 : 0.035))
      ctx.fill()
    }
    ctx.beginPath()
    for (var l = 0; l < data.land.length; l++) traceRing(ctx, data.land[l].p)
    ctx.fillStyle = rgba(ink, 0.07)
    ctx.fill()
    lastMs = Date.now() - started
  }
}
