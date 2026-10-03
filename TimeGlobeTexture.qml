import QtQuick
import qs.Commons
import "WorldMap.js" as WorldMap

// The World tab's picture of the earth for the GPU surface
// (TimeGlobeSurface.qml): an equirectangular Canvas (longitude −180…180°
// across, latitude +90…−90° down) with the time zones in alternating
// stripes, the zones off the full hour hatched, this computer's zone in the
// accent, the land's faint fill, the coastline and the grid (meridians every
// 15° and the equator); the same as the Canvas path draws (TimeGlobe.qml,
// TimeWorldMap.qml). 2048 × 1024: a texel is 0.18°, about 1.3 px at the
// centre of an 840 px globe. Painted only when the zones, the home zone or
// the theme change; never per frame. The night and the twilight bands are
// the shader's.
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

  width: 2048
  height: 1024
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

    // The grid: meridians every 15° and the equator, faintly.
    var w = width, h = height
    ctx.strokeStyle = rgba(ink, 0.07)
    ctx.lineWidth = 1.5
    ctx.beginPath()
    for (var lon = -165; lon <= 165; lon += 15) {
      var x = (lon + 180) / 360 * w
      ctx.moveTo(x, 0)
      ctx.lineTo(x, h)
    }
    ctx.moveTo(0, h / 2)
    ctx.lineTo(w, h / 2)
    ctx.stroke()

    // The coast: every land ring's edges, without the seams along ±180°
    // and the poles, which are no coast.
    ctx.beginPath()
    for (var k = 0; k < data.land.length; k++) {
      var p = data.land[k].p
      var n = p.length / 2
      var open = false
      for (var i = 0; i < n; i++) {
        var j = (i + 1) % n
        var lat0 = p[i * 2], lon0 = p[i * 2 + 1], lat1 = p[j * 2], lon1 = p[j * 2 + 1]
        var seam = (Math.abs(lat0) >= 89.99 && Math.abs(lat1) >= 89.99)
          || (Math.abs(lon0) >= 179.99 && Math.abs(lon1) >= 179.99 && lon0 * lon1 > 0)
        if (seam) { open = false; continue }
        if (!open) ctx.moveTo((lon0 + 180) / 360 * w, (90 - lat0) / 180 * h)
        ctx.lineTo((lon1 + 180) / 360 * w, (90 - lat1) / 180 * h)
        open = true
      }
    }
    ctx.strokeStyle = rgba(ink, 0.55)
    ctx.lineWidth = 1.6
    ctx.stroke()
    lastMs = Date.now() - started
  }
}
