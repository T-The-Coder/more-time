import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model
import "WorldMap.js" as WorldMap

// The world map of the World tab, Equal Earth (less distorted than Mercator,
// equal in area): the time zones in alternating stripes, the night side, the
// sun, the favourite cities with their time, and this computer's place.
// Above and below run the hours: what time it is in each whole-hour zone,
// and its offset. Hovering a zone names its offset and time.
Item {
  id: map
  required property var panel
  property int selectedIndex: -1
  signal cityClicked(int index)

  // Maps are never mirrored, whatever the language.
  LayoutMirroring.enabled: false
  LayoutMirroring.childrenInherit: true

  readonly property bool showNight: panel.displaySetting("worldNight", true)
  // The golden and the blue hour as bands along the day/night line, with
  // the clock's options of the same name.
  readonly property bool showGolden: panel.displaySetting("heroGoldenHour", true)
  readonly property bool showBlue: panel.displaySetting("heroBlueHour", true)
  readonly property bool showRuler: panel.displaySetting("worldRuler", true)
  readonly property bool showLabels: panel.displaySetting("worldMapLabels", true)
  readonly property real rulerHeight: showRuler ? Style.space(16) : 0
  readonly property real mapWidth: width
  readonly property real mapHeight: width * WorldMap.Y_MAX / WorldMap.X_MAX
  readonly property real unit: mapWidth / (2 * WorldMap.X_MAX)
  implicitHeight: mapHeight + rulerHeight * 2

  // Parsed once per process; every map shares it.
  property var mapData: null
  property FileView dataFile: FileView {
    path: String(Qt.resolvedUrl("data/worldmap.json")).replace(/^file:\/\//, "")
    printErrors: false
    onLoaded: {
      try { map.mapData = JSON.parse(text()) } catch (e) { console.warn("more-time: world map data unreadable:", e) }
    }
  }

  function px(point) {
    return { x: (point.x + WorldMap.X_MAX) * unit, y: (WorldMap.Y_MAX - point.y) * unit + rulerHeight }
  }

  // The minute, not the second: the night side and the labels move slowly.
  readonly property double minuteMs: Math.floor(panel.nowMs / 60000) * 60000
  readonly property var cities: panel.cityList
  readonly property var home: panel.zoneTable.home
  readonly property int homeZone: mapData && home ? (function() {
    var p = WorldMap.project(home.lat, home.lon)
    var zone = WorldMap.zoneAt(mapData, p.x, p.y)
    return zone === null ? 99999 : zone
  })() : 99999
  property var hover: null

  onMapDataChanged: canvas.requestPaint()
  onMinuteMsChanged: canvas.requestPaint()
  onCitiesChanged: canvas.requestPaint()
  onSelectedIndexChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()
  onShowNightChanged: canvas.requestPaint()
  onShowGoldenChanged: canvas.requestPaint()
  onShowBlueChanged: canvas.requestPaint()
  onShowRulerChanged: canvas.requestPaint()
  onShowLabelsChanged: canvas.requestPaint()
  onHomeZoneChanged: canvas.requestPaint()
  // Labels carry the time in the chosen format and language.
  readonly property string labelStyle: panel.interfaceLanguage + "|" + panel.hour12 + "|" + panel.fontFamily
  onLabelStyleChanged: canvas.requestPaint()
  Connections {
    target: map.panel.zoneTable
    function onRevisionChanged() { canvas.requestPaint() }
  }

  // Where each city's dot was drawn, for clicks.
  property var cityHits: []

  Canvas {
    id: canvas
    anchors.fill: parent
    property color ink: map.panel.foreground
    property color accent: Color.accent
    property color urgent: Color.urgent
    onInkChanged: requestPaint()
    onAccentChanged: requestPaint()

    function tracePoints(ctx, points) {
      for (var i = 0; i < points.length; i++) {
        var p = map.px(points[i])
        if (i === 0) ctx.moveTo(p.x, p.y)
        else ctx.lineTo(p.x, p.y)
      }
      ctx.closePath()
    }

    // A ring of the data file: integers in projected units × scale.
    function traceRing(ctx, ring, scale) {
      var u = map.unit / scale
      var ox = WorldMap.X_MAX * map.unit
      var oy = WorldMap.Y_MAX * map.unit + map.rulerHeight
      ctx.moveTo(ox + ring[0] * u, oy - ring[1] * u)
      for (var i = 2; i < ring.length; i += 2) ctx.lineTo(ox + ring[i] * u, oy - ring[i + 1] * u)
      ctx.closePath()
    }

    function rgba(color, alpha) {
      return Qt.rgba(color.r, color.g, color.b, alpha)
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      if (!map.mapData || width <= 0) return
      var data = map.mapData
      var scale = data.scale || 10000
      var outline = WorldMap.outline()

      // The globe's outline holds everything; the zones fill it edge to edge.
      ctx.save()
      ctx.beginPath()
      tracePoints(ctx, outline)
      ctx.clip()

      ctx.fillStyle = rgba(ink, 0.03)
      ctx.fillRect(0, 0, width, height)

      // Zebra: whole-hour zones alternate light and dark by the parity of
      // their hour; zones off the full hour are hatched.
      var hatch = ctx.createPattern(rgba(ink, 0.16), Qt.BDiagPattern)
      for (var z = 0; z < data.zones.length; z++) {
        var zone = data.zones[z]
        var band = WorldMap.zebraBand(zone.o)
        ctx.beginPath()
        for (var r = 0; r < zone.r.length; r++) traceRing(ctx, zone.r[r], scale)
        ctx.fillStyle = zone.o === map.homeZone ? rgba(accent, 0.22)
          : (band === 2 ? hatch : rgba(ink, band === 1 ? 0.12 : 0.035))
        ctx.fill("evenodd")
      }

      // Meridians every 15°: the ideal hour zones, faintly.
      ctx.strokeStyle = rgba(ink, 0.07)
      ctx.lineWidth = 1
      var lines = WorldMap.graticule()
      for (var g = 0; g < lines.length; g++) {
        ctx.beginPath()
        for (var gp = 0; gp < lines[g].length; gp++) {
          var q = map.px(lines[g][gp])
          if (gp === 0) ctx.moveTo(q.x, q.y)
          else ctx.lineTo(q.x, q.y)
        }
        ctx.stroke()
      }

      // Land: a light fill and a crisp coastline.
      ctx.beginPath()
      for (var l = 0; l < data.land.length; l++) traceRing(ctx, data.land[l], scale)
      ctx.fillStyle = rgba(ink, 0.07)
      ctx.fill("evenodd")
      ctx.strokeStyle = rgba(ink, 0.55)
      ctx.lineWidth = 0.8
      ctx.stroke()

      // The golden hour on the day side of the day/night line (sun +6° to
      // 0°) and the blue hour on the night side (0° to −8°), so the line
      // stays a crisp edge between them: each band the even-odd fill of its
      // two caps (WorldMap.twilightPolygon). The night fill goes over them.
      // Qt's Canvas takes the rule from fillRule, not from fill()'s argument.
      ctx.fillRule = Qt.OddEvenFill
      if (map.showGolden || map.showBlue) {
        var below0 = WorldMap.twilightPolygon(map.minuteMs, 0)
        if (map.showGolden) {
          ctx.beginPath()
          tracePoints(ctx, WorldMap.twilightPolygon(map.minuteMs, 6))
          tracePoints(ctx, below0)
          ctx.fillStyle = Qt.rgba(0xe3 / 255, 0xa4 / 255, 0x47 / 255, 0.28)
          ctx.fill("evenodd")
        }
        if (map.showBlue) {
          ctx.beginPath()
          tracePoints(ctx, below0)
          tracePoints(ctx, WorldMap.twilightPolygon(map.minuteMs, -8))
          ctx.fillStyle = Qt.rgba(0x3b / 255, 0x5b / 255, 0xd6 / 255, 0.28)
          ctx.fill("evenodd")
        }
      }

      // The night side, and the line between day and night.
      if (map.showNight) {
        var night = WorldMap.nightPolygon(map.minuteMs)
        ctx.beginPath()
        tracePoints(ctx, night)
        var nf = WorldMap.nightFill([Color.popups.background.r, Color.popups.background.g, Color.popups.background.b])
        ctx.fillStyle = Qt.rgba(nf.r, nf.g, nf.b, nf.a)
        ctx.fill("evenodd")
        var sun = map.px(WorldMap.project(WorldMap.subsolarPoint(map.minuteMs).lat, WorldMap.subsolarPoint(map.minuteMs).lon))
        ctx.fillStyle = rgba(accent, 0.9)
        ctx.beginPath()
        ctx.arc(sun.x, sun.y, 3.5, 0, Math.PI * 2)
        ctx.fill()
        ctx.strokeStyle = rgba(accent, 0.5)
        ctx.lineWidth = 1
        ctx.beginPath()
        ctx.arc(sun.x, sun.y, 7, 0, Math.PI * 2)
        ctx.stroke()
      }
      ctx.restore()

      ctx.strokeStyle = rgba(ink, 0.35)
      ctx.lineWidth = 1
      ctx.beginPath()
      tracePoints(ctx, outline)
      ctx.stroke()

      if (map.showRuler) paintRuler(ctx)
      paintPlaces(ctx)
    }

    // Above: the hour in each whole-hour zone at its meridian; below: the
    // offsets. ±12 would sit on the map's edge and are left out. This
    // computer's offset is in the accent.
    function paintRuler(ctx) {
      var utc = Model.zonedParts(map.minuteMs, 0)
      var localHours = map.panel.localOffset / 3600
      ctx.font = map.panel.canvasFont(Style.font.caption * 0.95, false, false)
      ctx.textAlign = "center"
      ctx.textBaseline = "middle"
      var step = map.mapWidth < Style.space(420) ? 2 : 1
      for (var h = -11; h <= 11; h += step) {
        var x = map.px(WorldMap.project(0, h * 15)).x
        var hour = ((utc.hour + h) % 24 + 24) % 24
        var mine = h === Math.round(localHours)
        ctx.fillStyle = mine ? accent : rgba(ink, 0.6)
        var label = map.panel.hour12 ? String((hour % 12) || 12) : Model.pad2(hour)
        ctx.fillText(label, x, map.rulerHeight / 2)
        ctx.fillStyle = mine ? accent : rgba(ink, 0.4)
        ctx.fillText(h === 0 ? "UTC" : Model.offsetText(h * 3600), x, height - map.rulerHeight / 2)
      }
    }

    function paintPlaces(ctx) {
      var taken = []
      var hits = []
      function free(rect) {
        for (var t = 0; t < taken.length; t++) {
          var o = taken[t]
          if (rect.x < o.x + o.w && rect.x + rect.w > o.x && rect.y < o.y + o.h && rect.y + rect.h > o.y) return false
        }
        return true
      }
      // Home first: a ring where this computer's zone has its city.
      if (map.home) {
        var hp = map.px(WorldMap.project(map.home.lat, map.home.lon))
        ctx.strokeStyle = accent
        ctx.lineWidth = 1.5
        ctx.beginPath()
        ctx.arc(hp.x, hp.y, 4.5, 0, Math.PI * 2)
        ctx.stroke()
        taken.push({ x: hp.x - 6, y: hp.y - 6, w: 12, h: 12 })
      }
      var fontPx = Style.font.caption
      var labelFont = map.panel.canvasFont(fontPx, false, false)
      var boldFont = map.panel.canvasFont(fontPx, true, false)
      // The selected city's label is placed first so it is never pushed out.
      var order = []
      for (var c = 0; c < map.cities.length; c++) order.push(c)
      order.sort(function(a, b) { return (b === map.selectedIndex) - (a === map.selectedIndex) })
      for (var k = 0; k < order.length; k++) {
        var index = order[k]
        var city = map.cities[index]
        if (city.lat === null || city.lon === null) continue
        var p = map.px(WorldMap.project(city.lat, city.lon))
        var selected = index === map.selectedIndex
        ctx.fillStyle = selected ? accent : ink
        ctx.beginPath()
        ctx.arc(p.x, p.y, selected ? 4 : 3, 0, Math.PI * 2)
        ctx.fill()
        hits.push({ index: index, x: p.x, y: p.y })
        taken.push({ x: p.x - 4, y: p.y - 4, w: 8, h: 8 })
        if (!map.showLabels) continue
        var offset = map.panel.cityOffset(city)
        var label = city.name + (offset !== null ? " " + map.panel.clockFor(map.minuteMs, offset, false) : "")
        ctx.font = selected ? boldFont : labelFont
        var w = ctx.measureText(label).width + 6
        var h = fontPx + 4
        // Right, left, above, below the dot: the first free spot.
        var spots = [
          { x: p.x + 6, y: p.y - h / 2 }, { x: p.x - 6 - w, y: p.y - h / 2 },
          { x: p.x - w / 2, y: p.y - 6 - h }, { x: p.x - w / 2, y: p.y + 6 }
        ]
        for (var s = 0; s < spots.length; s++) {
          var rect = { x: spots[s].x, y: spots[s].y, w: w, h: h }
          if (rect.x < 0 || rect.x + w > width || rect.y < 0 || rect.y + h > height) continue
          if (!free(rect) && !selected) continue
          taken.push(rect)
          ctx.fillStyle = Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 0.78)
          ctx.fillRect(rect.x, rect.y, w, h)
          ctx.fillStyle = selected ? accent : ink
          ctx.textAlign = "left"
          ctx.textBaseline = "middle"
          ctx.fillText(label, rect.x + 3, rect.y + h / 2 + 0.5)
          break
        }
      }
      map.cityHits = hits
    }
  }

  // Hover names the zone under the pointer; a click on a dot picks the city.
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onPositionChanged: function(mouse) {
      if (!map.mapData) return
      var x = mouse.x / map.unit - WorldMap.X_MAX
      var y = WorldMap.Y_MAX - (mouse.y - map.rulerHeight) / map.unit
      var minutes = WorldMap.unproject(x, y) ? WorldMap.zoneAt(map.mapData, x, y) : null
      map.hover = minutes === null ? null : { minutes: minutes, x: mouse.x, y: mouse.y }
    }
    onExited: map.hover = null
    onClicked: function(mouse) {
      var best = -1
      var bestDistance = Style.space(14)
      for (var i = 0; i < map.cityHits.length; i++) {
        var d = Math.hypot(map.cityHits[i].x - mouse.x, map.cityHits[i].y - mouse.y)
        if (d < bestDistance) {
          best = map.cityHits[i].index
          bestDistance = d
        }
      }
      if (best >= 0) map.cityClicked(best)
    }
  }

  Rectangle {
    visible: map.hover !== null
    x: map.hover ? Math.min(map.width - width, map.hover.x + Style.space(12)) : 0
    y: map.hover ? Math.max(0, map.hover.y - height - Style.space(6)) : 0
    width: hoverLabel.implicitWidth + Style.space(12)
    height: hoverLabel.implicitHeight + Style.space(6)
    radius: Style.cornerRadius
    color: Color.popups.background
    border.color: map.panel.subtleText
    border.width: Style.spacing.hairline

    Text {
      id: hoverLabel
      anchors.centerIn: parent
      // The map's zones are standard time: summer time is not drawn, so
      // the label says so rather than show an hour that may be off.
      text: map.hover ? Model.utcOffsetLabel(map.hover.minutes * 60) + "  ·  "
        + map.panel.clockFor(map.panel.nowMs, map.hover.minutes * 60, false)
        + "  " + map.panel.i18n("standardTime") : ""
      color: map.panel.foreground
      font.family: map.panel.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
