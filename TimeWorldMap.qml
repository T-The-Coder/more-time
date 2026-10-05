import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model
import "WorldMap.js" as WorldMap
import "Moon.js" as Moon
import "Globe.js" as Globe

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
  // The twilight layers and their caps (projected), once a minute.
  readonly property var twilight: {
    var layers = WorldMap.twilightLayers({ golden: showGolden, blue: showBlue, night: showNight },
      panel.rgbOf(Color.popups.background))
    var shapes = {}
    var elevations = WorldMap.twilightElevations(layers)
    // On the GPU surface the shader draws them from the Sun alone.
    for (var i = 0; i < (gpuSurface ? 0 : elevations.length); i++) shapes[elevations[i]] = WorldMap.twilightPolygon(minuteMs, elevations[i])
    return { layers: layers, shapes: shapes }
  }
  onTwilightChanged: canvas.requestPaint()
  readonly property bool showMoon: panel.displaySetting("worldMoon", false)
  // "space": lit as from above; "earth": as it stands in the sky of the
  // current place (here or the selected city), Panel.moonLook.
  readonly property string moonStyle: panel.displaySetting("worldMoonStyle", "space")
  readonly property var observer: panel.currentCoordinates
  onShowMoonChanged: canvas.requestPaint()
  onMoonStyleChanged: canvas.requestPaint()
  onObserverChanged: canvas.requestPaint()
  // Where the Moon was drawn, for the hover: { x, y, moon } or null.
  property var moonHit: null
  readonly property real moonRadius: Style.space(6)
  // The Moon's lit colour, pale on any theme.
  readonly property string moonLit: "238,236,226"
  // The golden and the blue hour as bands along the day/night line, with
  // the clock's options of the same name.
  readonly property bool showGolden: panel.displaySetting("heroGoldenHour", false)
  readonly property bool showBlue: panel.displaySetting("heroBlueHour", false)
  readonly property bool showRuler: panel.displaySetting("worldRuler", true)
  readonly property bool showLabels: panel.displaySetting("worldMapLabels", true)
  readonly property real rulerHeight: showRuler ? Style.space(16) : 0
  readonly property real mapWidth: width
  // Height over width; TimeWorld narrows the map to fit the visible height.
  readonly property real aspect: WorldMap.Y_MAX / WorldMap.X_MAX
  readonly property real mapHeight: width * aspect
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

  // ---- Zoom (z0 … z3, the scale doubling per step) and panning ----
  // focusX/Y: the map point (px of the whole map, before zooming) in the
  // middle of the view, kept so the view never leaves the map. The ruler
  // is hidden while zoomed in.
  readonly property int maxZoom: 3
  property int zoom: 0
  readonly property real zoomScale: Math.pow(2, zoom)
  property real focusX: mapWidth / 2
  property real focusY: mapHeight / 2
  readonly property bool rulerShown: showRuler && zoom === 0
  onZoomChanged: { clampFocus(); canvas.requestPaint() }
  onFocusXChanged: canvas.requestPaint()
  onFocusYChanged: canvas.requestPaint()
  onMapWidthChanged: clampFocus()

  function clampFocus() {
    var hx = mapWidth / 2 / zoomScale, hy = mapHeight / 2 / zoomScale
    focusX = Math.max(hx, Math.min(mapWidth - hx, focusX))
    focusY = Math.max(hy, Math.min(mapHeight - hy, focusY))
  }
  // One step in or out with the map point under (sx, sy) kept there.
  function zoomAt(delta, sx, sy) {
    var next = Math.max(0, Math.min(maxZoom, zoom + delta))
    if (next === zoom) return
    var k0 = zoomScale, k1 = Math.pow(2, next)
    var mx = (sx - mapWidth / 2) / k0 + focusX
    var my = (sy - rulerHeight - mapHeight / 2) / k0 + focusY
    focusX = mx - (sx - mapWidth / 2) / k1
    focusY = my - (sy - rulerHeight - mapHeight / 2) / k1
    zoom = next
    clampFocus()
  }
  function zoomBy(delta) { zoomAt(delta, mapWidth / 2, rulerHeight + mapHeight / 2) }
  // The crosshair: the current place in the middle, the zoom kept.
  function recenter() {
    var c = panel.currentCoordinates
    if (!c) return
    var p = WorldMap.project(c.lat, c.lon)
    focusX = (p.x + WorldMap.X_MAX) * unit
    focusY = (WorldMap.Y_MAX - p.y) * unit
    clampFocus()
  }
  // 0: the whole map.
  function reset() {
    zoom = 0
    focusX = mapWidth / 2
    focusY = mapHeight / 2
  }
  // Keys from the World tab (Panel.handlePanelKey): + − zoom, 0 whole map,
  // Ctrl + arrows pan by a quarter of the view.
  function handleMapKey(event) {
    var text = event.text
    var control = (event.modifiers & Qt.ControlModifier) !== 0
    if (control && (event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
      var step = mapWidth / 4 / zoomScale
      if (event.key === Qt.Key_Left) focusX -= step
      else if (event.key === Qt.Key_Right) focusX += step
      else if (event.key === Qt.Key_Up) focusY -= step
      else focusY += step
      clampFocus()
      return true
    }
    if (control) return false
    if (text === "+" || text === "=") { zoomBy(1); return true }
    if (text === "-" || text === "−") { zoomBy(-1); return true }
    if (text === "0") { reset(); return true }
    return false
  }

  function px(point) {
    return { x: ((point.x + WorldMap.X_MAX) * unit - focusX) * zoomScale + mapWidth / 2,
      y: ((WorldMap.Y_MAX - point.y) * unit - focusY) * zoomScale + mapHeight / 2 + rulerHeight }
  }

  // The minute, not the second: the night side and the labels move slowly.
  // The instant drawn: now, or the World timeline's (Panel.worldMinuteMs).
  readonly property double minuteMs: panel.worldMinuteMs
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

  // ---- The GPU surface in its Equal Earth mode (TimeGlobeSurface.qml):
  //      the zones, the land's fill and the night from the same picture as
  //      the globe's, up to z2 and where shaders run; the Canvas keeps the
  //      rest (and draws everything otherwise).
  readonly property var globeData: mapData ? Globe.prepareData(mapData, WorldMap.unproject) : null
  readonly property bool gpuSurface: surface.available && zoom < 3
  onGpuSurfaceChanged: canvas.requestPaint()
  TimeGlobeTexture {
    id: surfaceTexture
    globeData: map.globeData
    homeZone: map.homeZone
    ink: map.panel.foreground
  }
  TimeGlobeSurface {
    id: surface
    x: 0
    y: map.rulerHeight
    width: map.mapWidth
    height: map.mapHeight
    visible: map.gpuSurface
    style: "map"
    zoom: map.zoom
    centerLat: 0
    centerLon: 0
    // Where the map's 0°/0° sits in the surface (map.px without the ruler).
    centerX: (WorldMap.X_MAX * map.unit - map.focusX) * map.zoomScale + map.mapWidth / 2
    centerY: (WorldMap.Y_MAX * map.unit - map.focusY) * map.zoomScale + map.mapHeight / 2
    displayMs: map.minuteMs
    night: map.showNight
    goldenBand: map.showGolden
    blueBand: map.showBlue
    background: Color.popups.background
    baseColor: Qt.rgba(map.panel.foreground.r, map.panel.foreground.g, map.panel.foreground.b, 0.03)
    textureSource: surfaceTexture
  }
  // What painting costs (the screenshot harness measures a time lapse).
  property var paintStats: ({ count: 0, total: 0, max: 0 })
  property var perf: ({ surface: gpuSurface, fps: 0, cpuMsPerFrame: 0, cpuPercent: 0, textureMs: surfaceTexture.lastMs })
  Component.onCompleted: map.panel.globeItem = map
  Component.onDestruction: if (map.panel.globeItem === map) map.panel.globeItem = null

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
      var k = map.zoomScale
      var u = map.unit / scale * k
      var ox = (WorldMap.X_MAX * map.unit - map.focusX) * k + map.mapWidth / 2
      var oy = (WorldMap.Y_MAX * map.unit - map.focusY) * k + map.mapHeight / 2 + map.rulerHeight
      ctx.moveTo(ox + ring[0] * u, oy - ring[1] * u)
      for (var i = 2; i < ring.length; i += 2) ctx.lineTo(ox + ring[i] * u, oy - ring[i + 1] * u)
      ctx.closePath()
    }

    function rgba(color, alpha) {
      return Qt.rgba(color.r, color.g, color.b, alpha)
    }

    onPaint: {
      var started = Date.now()
      var ctx = getContext("2d")
      ctx.reset()
      if (!map.mapData || width <= 0) return
      var data = map.mapData
      var scale = data.scale || 10000
      var outline = WorldMap.outline()

      // The globe's outline holds everything; the zones fill it edge to edge.
      // Zoomed in, the map stays between the ruler strips.
      ctx.save()
      if (map.zoom > 0) {
        ctx.beginPath()
        ctx.rect(0, map.rulerHeight, width, map.mapHeight)
        ctx.clip()
      }
      ctx.beginPath()
      tracePoints(ctx, outline)
      ctx.clip()

      // With the GPU surface the zones, the land's fill and the night are
      // under this canvas already.
      var gpu = map.gpuSurface
      if (!gpu) {
        ctx.fillStyle = rgba(ink, 0.03)
        ctx.fillRect(0, 0, width, height)
      }

      // Zebra: whole-hour zones alternate light and dark by the parity of
      // their hour; zones off the full hour are hatched.
      var hatch = ctx.createPattern(rgba(ink, 0.16), Qt.BDiagPattern)
      for (var z = 0; z < (gpu ? 0 : data.zones.length); z++) {
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
      var lines = gpu ? [] : WorldMap.graticule()
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
      if (!gpu) ctx.fill("evenodd")
      // With the surface the coast is in its picture; zoomed in a crisp
      // one goes on top (the map does not turn by itself).
      if (!gpu || map.zoom >= 1) {
        ctx.strokeStyle = rgba(ink, 0.55)
        ctx.lineWidth = 0.8
        ctx.stroke()
      }

      // The twilight along the day/night line (WorldMap.twilightLayers): the
      // golden and the blue band with soft edges, then the night in three
      // steps; each layer the even-odd fill of two caps. Qt's Canvas takes
      // the rule from fillRule, not from fill()'s argument.
      ctx.fillRule = Qt.OddEvenFill
      var tw = map.twilight
      var layerCount = gpu ? 0 : tw.layers.length
      for (var t = 0; t < layerCount; t++) {
        var layer = tw.layers[t]
        ctx.beginPath()
        tracePoints(ctx, tw.shapes[layer.high])
        if (layer.low !== null) tracePoints(ctx, tw.shapes[layer.low])
        ctx.fillStyle = Qt.rgba(layer.fill.r, layer.fill.g, layer.fill.b, layer.fill.a)
        ctx.fill()
      }
      // The Sun at its zenith point.
      var sunNow = WorldMap.subsolarPoint(map.minuteMs)
      if (map.showNight) {
        var sun = map.px(WorldMap.project(sunNow.lat, sunNow.lon))
        WorldMap.paintSun(ctx, sun.x, sun.y, map.panel.sunColor)
      }
      // The Moon floats a little up-left of its sub-lunar point, where its
      // shadow falls; drawn after the clip so it may stand out of the map.
      var moon = map.showMoon ? Moon.moonPosition(map.minuteMs) : null
      var moonAt = moon ? map.px(WorldMap.project(moon.lat, moon.lon)) : null
      if (moon) Moon.paintMoonShadow(ctx, moonAt.x, moonAt.y, map.moonRadius)
      ctx.restore()

      map.moonHit = null
      if (moon) {
        var lift = Style.space(4)
        var look = map.panel.moonLook(map.moonStyle, moon,
          Moon.moonLitAngle(moon, sunNow, function(lat, lon) { return map.px(WorldMap.project(lat, lon)) }), map.minuteMs)
        ctx.globalAlpha = look.alpha
        Moon.paintMoon(ctx, moonAt.x - lift, moonAt.y - lift, map.moonRadius, look.angle, look.illuminated,
          map.moonLit, Moon.rgbText(WorldMap.nightFill(map.panel.rgbOf(Color.popups.background))), Moon.rgbText(ink), look.earthshine)
        ctx.globalAlpha = 1
        map.moonHit = { x: moonAt.x - lift, y: moonAt.y - lift, moon: moon, ms: map.minuteMs }
      }

      ctx.strokeStyle = rgba(ink, 0.35)
      ctx.lineWidth = 1
      ctx.beginPath()
      tracePoints(ctx, outline)
      ctx.stroke()

      if (map.rulerShown) paintRuler(ctx)
      paintPlaces(ctx)
      var spent = Date.now() - started
      var st = map.paintStats
      map.paintStats = { count: st.count + 1, total: st.total + spent, max: Math.max(st.max, spent) }
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
  // A drag pans while zoomed in, Ctrl + wheel zooms at the pointer, a
  // double click zooms in there.
  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    property real pressX: 0
    property real pressY: 0
    property real pressFocusX: 0
    property real pressFocusY: 0
    property bool dragged: false
    onPressed: function(mouse) {
      pressX = mouse.x
      pressY = mouse.y
      pressFocusX = map.focusX
      pressFocusY = map.focusY
      dragged = false
    }
    onPositionChanged: function(mouse) {
      if (pressed && map.zoom > 0) {
        if (Math.abs(mouse.x - pressX) + Math.abs(mouse.y - pressY) > Style.space(4)) dragged = true
        if (dragged) {
          map.focusX = pressFocusX - (mouse.x - pressX) / map.zoomScale
          map.focusY = pressFocusY - (mouse.y - pressY) / map.zoomScale
          map.clampFocus()
          map.hover = null
          return
        }
      }
      if (!map.mapData) return
      map.hover = map.panel.mapHoverAt(map.moonHit, mouse.x, mouse.y, function(px, py) {
        var x = ((px - map.mapWidth / 2) / map.zoomScale + map.focusX) / map.unit - WorldMap.X_MAX
        var y = WorldMap.Y_MAX - ((py - map.rulerHeight - map.mapHeight / 2) / map.zoomScale + map.focusY) / map.unit
        return WorldMap.unproject(x, y) ? WorldMap.zoneAt(map.mapData, x, y) : null
      })
    }
    onExited: map.hover = null
    onDoubleClicked: function(mouse) { map.zoomAt(1, mouse.x, mouse.y) }
    function wantsWheel(wheel) { return (wheel.modifiers & Qt.ControlModifier) !== 0 }
    Component.onCompleted: map.panel.registerWheelArea(this)
    Component.onDestruction: map.panel.unregisterWheelArea(this)
    property real zoomWheel: 0
    onWheel: function(wheel) {
      if (!(wheel.modifiers & Qt.ControlModifier)) {
        wheel.accepted = false
        return
      }
      zoomWheel += wheel.angleDelta.y
      if (Math.abs(zoomWheel) >= 120) {
        map.zoomAt(zoomWheel > 0 ? 1 : -1, wheel.x, wheel.y)
        zoomWheel = 0
      }
    }
    onClicked: function(mouse) {
      if (dragged) return
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

  TimeMapHoverLabel {
    panel: map.panel
    hover: map.hover
    boundsWidth: map.width
  }

  TimeZoomControls {
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: map.rulerHeight + Style.space(6)
    anchors.rightMargin: Style.space(6)
    panel: map.panel
    canZoomOut: map.zoom > 0
    canZoomIn: map.zoom < map.maxZoom
    onRecenter: map.recenter()
    onZoomOut: map.zoomBy(-1)
    onZoomIn: map.zoomBy(1)
  }
}
