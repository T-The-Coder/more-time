import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "WorldMap.js" as WorldMap
import "Moon.js" as Moon
import "Globe.js" as Globe

// The World tab's other map: the earth as a globe, seen from above the
// equator, drawn like the flat map (TimeWorldMap.qml) — the time zones in
// alternating stripes, the land, the night side and the sun, the favourite
// cities with their time, this computer's place, and the zone under the
// pointer. Picking a city turns the globe to it the short way round; a drag
// or the wheel turns it by hand; with "globeAutoRotate" it turns slowly by
// itself after ten seconds without a touch.
Item {
  id: globe
  objectName: "timeGlobe"
  required property var panel
  property int selectedIndex: -1
  signal cityClicked(int index)

  // Maps are never mirrored, whatever the language.
  LayoutMirroring.enabled: false
  LayoutMirroring.childrenInherit: true

  readonly property bool showNight: panel.displaySetting("worldNight", true)
  readonly property bool showMoon: panel.displaySetting("worldMoon", false)
  onShowMoonChanged: canvas.requestPaint()
  // Where the Moon was drawn on the front side, for the hover, or null.
  property var moonHit: null
  readonly property real moonRadius: Style.space(6)
  // What painting costs (the screenshot harness measures a turn): frames,
  // total and longest milliseconds, and the total per part (zones, land and
  // grid, twilight and sky, places).
  property var paintStats: ({ count: 0, total: 0, max: 0 })
  // The pointer resting over the globe, for the hover, or null.
  property var pointer: null
  readonly property bool showLabels: panel.displaySetting("worldMapLabels", true)
  readonly property bool showGolden: panel.displaySetting("heroGoldenHour", false)
  readonly property bool showBlue: panel.displaySetting("heroBlueHour", false)
  readonly property bool autoRotate: panel.displaySetting("globeAutoRotate", false)
  readonly property real diameter: Math.min(width, Style.space(380))
  readonly property real radius: diameter / 2
  readonly property real centerX: width / 2
  readonly property real centerY: radius
  implicitHeight: diameter

  // The longitude facing the viewer, unwrapped: turns animate through it
  // the short way and the drawing wraps it.
  property real centerLon: 0
  NumberAnimation {
    id: turnAnimation
    target: globe
    property: "centerLon"
    duration: 600
    easing.type: Easing.InOutCubic
  }

  function turnTo(lon) {
    if (lon === null || lon === undefined || isNaN(lon)) return
    turnAnimation.stop()
    turnAnimation.from = centerLon
    turnAnimation.to = centerLon + Globe.shortestTurn(centerLon, lon)
    turnAnimation.start()
  }
  // Ends a running turn at once (the screenshot harness).
  function finishTurn() {
    if (turnAnimation.running) turnAnimation.complete()
  }

  function placeLon(index) {
    var city = index >= 0 ? cities[index] : null
    if (city && city.lat !== null && city.lon !== null) return city.lon
    return index < 0 && home ? home.lon : null
  }

  Component.onCompleted: {
    var lon = placeLon(selectedIndex)
    centerLon = lon === null ? (home ? home.lon : 0) : lon
  }
  onSelectedIndexChanged: {
    touched()
    turnTo(placeLon(selectedIndex))
  }

  // Parsed per view, converted to lat/lon once per process (Globe.js).
  property var mapData: null
  property var globeData: null
  property FileView dataFile: FileView {
    path: String(Qt.resolvedUrl("data/worldmap.json")).replace(/^file:\/\//, "")
    printErrors: false
    onLoaded: {
      try {
        var data = JSON.parse(text())
        globe.globeData = Globe.prepareData(data, WorldMap.unproject)
        globe.mapData = data
      } catch (e) {
        console.warn("more-time: world map data unreadable:", e)
      }
    }
  }

  // The minute, not the second: the night side and the labels move slowly.
  readonly property double minuteMs: Math.floor(panel.nowMs / 60000) * 60000
  readonly property var cities: panel.cityList
  // Here (TimeHere: the weather location, IP or the zone's city), else
  // this computer's zone city: the home ring and where "here" turns to.
  readonly property var home: panel.here.place || panel.zoneTable.home
  onHomeChanged: if (selectedIndex < 0 && home) turnTo(home.lon)
  readonly property int homeZone: mapData && home ? (function() {
    var p = WorldMap.project(home.lat, home.lon)
    var zone = WorldMap.zoneAt(mapData, p.x, p.y)
    return zone === null ? 99999 : zone
  })() : 99999
  // The twilight areas change with the minute; kept in lat/lon, clipped
  // per frame.
  // The twilight layers (WorldMap.twilightLayers) and their caps as lat/lon
  // rings, once a minute; clipped to the front side per frame.
  readonly property var twilight: {
    var ms = minuteMs
    var layers = WorldMap.twilightLayers({ golden: showGolden, blue: showBlue, night: showNight },
      panel.rgbOf(Color.popups.background))
    var shapes = {}
    var elevations = WorldMap.twilightElevations(layers)
    for (var i = 0; i < elevations.length; i++)
      shapes[elevations[i]] = WorldMap.twilightRings(ms, elevations[i], rotating ? 4 : 2).map(function(r) { return Globe.prepareLatLon(r) })
    return { layers: layers, shapes: shapes, sun: WorldMap.subsolarPoint(ms) }
  }
  property var hover: null

  onGlobeDataChanged: canvas.requestPaint()
  onTwilightChanged: canvas.requestPaint()
  onCitiesChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()
  onShowLabelsChanged: canvas.requestPaint()
  onHomeZoneChanged: canvas.requestPaint()
  onCenterLonChanged: canvas.requestPaint()
  readonly property string labelStyle: panel.interfaceLanguage + "|" + panel.hour12 + "|" + panel.fontFamily
    + "|" + selectedIndex
  onLabelStyleChanged: canvas.requestPaint()
  Connections {
    target: globe.panel.zoneTable
    function onRevisionChanged() { canvas.requestPaint() }
  }

  // ---- Turning by itself ----
  // After the set delay (globeRotateDelay) it turns east, one turn in the set
  // minutes (globeRotateSpeed), only while it can be seen (popup open, World
  // tab). A press, drag, wheel or selection change stops it and restarts the
  // wait; a pointer resting on it does not, and the tooltip follows the turn.
  property bool rotating: false
  readonly property bool canRotate: autoRotate && panel.opened && panel.currentTab === "world"
    && visible && !mouse.pressed
  onCanRotateChanged: if (!canRotate) rotating = false

  function touched() {
    rotating = false
    if (idleTimer.running) idleTimer.restart()
  }

  // Settings → Display → World: after how many idle seconds it starts, and
  // in how many minutes it makes one turn.
  readonly property int rotateDelaySeconds: Number(panel.displaySetting("globeRotateDelay", "10")) || 10
  readonly property int rotateTurnMinutes: Number(panel.displaySetting("globeRotateSpeed", "4")) || 4

  Timer {
    id: idleTimer
    interval: globe.rotateDelaySeconds * 1000
    running: globe.canRotate && !globe.rotating
    onTriggered: globe.rotating = true
  }

  // A frame for every pixel the surface moves at the centre, not more
  // often than 30 a second: at one turn in four minutes about five a second,
  // which keeps a frame of 30–40 ms (QML, every layer on) cheap.
  Timer {
    id: rotateTimer
    interval: Math.max(33, Math.min(250, (180 / Math.PI / Math.max(1, globe.radius))
      / (360 / (globe.rotateTurnMinutes * 60000))))
    repeat: true
    running: globe.canRotate && globe.rotating
    property double last: 0
    onRunningChanged: last = Date.now()
    onTriggered: {
      var now = Date.now()
      var elapsed = Math.min(500, now - last)
      last = now
      if (!turnAnimation.running) globe.centerLon += elapsed * 360 / (globe.rotateTurnMinutes * 60000)
    }
  }

  // Where each city's dot was drawn, for clicks.
  property var cityHits: []

  Canvas {
    id: canvas
    anchors.fill: parent
    property color ink: globe.panel.foreground
    property color accent: Color.accent
    onInkChanged: requestPaint()
    onAccentChanged: requestPaint()

    function rgba(color, alpha) {
      return Qt.rgba(color.r, color.g, color.b, alpha)
    }

    // Globe.js gives y to the north around the centre; the canvas wants
    // pixels downwards.
    function trace(ctx, xy, close) {
      ctx.moveTo(globe.centerX + xy[0], globe.centerY - xy[1])
      for (var i = 2; i < xy.length; i += 2) ctx.lineTo(globe.centerX + xy[i], globe.centerY - xy[i + 1])
      if (close) ctx.closePath()
    }

    function traceRings(ctx, rings, lon) {
      for (var r = 0; r < rings.length; r++) {
        var polys = Globe.frontPolygons(rings[r], lon, globe.radius)
        for (var p = 0; p < polys.length; p++) trace(ctx, polys[p], true)
      }
    }

    function fillRings(ctx, rings, lon, style) {
      if (!rings.length) return
      ctx.beginPath()
      traceRings(ctx, rings, lon)
      ctx.fillStyle = style
      // Even-odd: holes, enclaves and the twilight bands are ring pairs.
      ctx.fillRule = Qt.OddEvenFill
      ctx.fill()
    }

    function disc(ctx) {
      ctx.beginPath()
      ctx.arc(globe.centerX, globe.centerY, globe.radius, 0, Math.PI * 2)
    }

    onPaint: {
      var started = Date.now()
      var ctx = getContext("2d")
      ctx.reset()
      var data = globe.globeData
      if (!data || globe.radius <= 0) return
      var lon = Globe.wrapLon(globe.centerLon)
      var R = globe.radius

      ctx.save()
      disc(ctx)
      ctx.clip()
      ctx.fillStyle = rgba(ink, 0.03)
      ctx.fillRect(0, 0, width, height)

      // Zebra: whole-hour zones alternate by the parity of their hour;
      // zones off the full hour are hatched.
      var hatch = ctx.createPattern(rgba(ink, 0.16), Qt.BDiagPattern)
      for (var z = 0; z < data.zones.length; z++) {
        var zone = data.zones[z]
        var band = WorldMap.zebraBand(zone.o)
        fillRings(ctx, zone.rings, lon, zone.o === globe.homeZone ? rgba(accent, 0.22)
          : (band === 2 ? hatch : rgba(ink, band === 1 ? 0.12 : 0.035)))
      }

      var zonesDone = Date.now()

      // Meridians every 15° and the equator, faintly.
      ctx.strokeStyle = rgba(ink, 0.07)
      ctx.lineWidth = 1
      var lines = Globe.gridLines(lon, R, 15)
      ctx.beginPath()
      for (var g = 0; g < lines.length; g++) trace(ctx, lines[g], false)
      ctx.stroke()

      // Land: a light fill and a crisp coastline.
      fillRings(ctx, data.land, lon, rgba(ink, 0.07))
      ctx.beginPath()
      for (var l = 0; l < data.land.length; l++) {
        var coast = Globe.frontLines(data.land[l], lon, R)
        for (var c = 0; c < coast.length; c++) trace(ctx, coast[c], false)
      }
      ctx.strokeStyle = rgba(ink, 0.55)
      ctx.lineWidth = 0.8
      ctx.stroke()

      var landDone = Date.now()

      // The twilight layers: the golden and the blue band with soft edges,
      // the night in three steps (WorldMap.twilightLayers); then the Sun at
      // its zenith point.
      // Each cap is clipped to the front side once per frame, however many
      // layers share it.
      var tw = globe.twilight
      var front = {}
      for (var e in tw.shapes) {
        front[e] = []
        for (var c = 0; c < tw.shapes[e].length; c++) front[e] = front[e].concat(Globe.frontPolygons(tw.shapes[e][c], lon, R))
      }
      ctx.fillRule = Qt.OddEvenFill
      for (var t = 0; t < tw.layers.length; t++) {
        var layer = tw.layers[t]
        var polys = front[layer.high].concat(layer.low !== null ? front[layer.low] : [])
        if (!polys.length) continue
        ctx.beginPath()
        for (var q = 0; q < polys.length; q++) trace(ctx, polys[q], true)
        ctx.fillStyle = Qt.rgba(layer.fill.r, layer.fill.g, layer.fill.b, layer.fill.a)
        ctx.fill()
      }
      if (globe.showNight) {
        var sun = screenPoint(tw.sun.lat, tw.sun.lon, lon)
        if (sun.visible) WorldMap.paintSun(ctx, sun.x, sun.y, rgba(accent, 0.95))
      }
      // The Moon floats above its sub-lunar point, lifted along the view
      // direction (1.15 of its distance from the centre), its shadow on the
      // surface; hidden on the back side, drawn after the clip.
      var moon = globe.showMoon ? Moon.moonPosition(globe.minuteMs) : null
      var moonAt = moon ? screenPoint(moon.lat, moon.lon, lon) : null
      if (moon && moonAt.visible) Moon.paintMoonShadow(ctx, moonAt.x, moonAt.y, globe.moonRadius)
      ctx.restore()

      globe.moonHit = null
      if (moon && moonAt.visible) {
        var mx = globe.centerX + (moonAt.x - globe.centerX) * 1.15
        var my = globe.centerY + (moonAt.y - globe.centerY) * 1.15
        var angle = Moon.moonLitAngle(moon, tw.sun, function(lat, lon2) { return screenPoint(lat, lon2, lon) })
        Moon.paintMoon(ctx, mx, my, globe.moonRadius, angle, moon.illuminated, "238,236,226",
          Moon.rgbText(WorldMap.nightFill(globe.panel.rgbOf(Color.popups.background))), Moon.rgbText(ink))
        globe.moonHit = { x: mx, y: my, moon: moon }
      }

      ctx.strokeStyle = rgba(ink, 0.35)
      ctx.lineWidth = 1
      disc(ctx)
      ctx.stroke()

      var skyDone = Date.now()
      paintPlaces(ctx, lon)
      mouse.updateHover()
      var done = Date.now()
      var st = globe.paintStats
      globe.paintStats = { count: st.count + 1, total: st.total + done - started, max: Math.max(st.max, done - started),
        zones: (st.zones || 0) + zonesDone - started, land: (st.land || 0) + landDone - zonesDone,
        sky: (st.sky || 0) + skyDone - landDone, places: (st.places || 0) + done - skyDone }
    }

    function screenPoint(lat, lon, centerLon) {
      var p = Globe.projectOrtho(lat, lon, centerLon, globe.radius)
      return { x: globe.centerX + p.x, y: globe.centerY - p.y, visible: p.visible }
    }

    function paintPlaces(ctx, centerLon) {
      var taken = []
      var hits = []
      function free(rect) {
        for (var t = 0; t < taken.length; t++) {
          var o = taken[t]
          if (rect.x < o.x + o.w && rect.x + rect.w > o.x && rect.y < o.y + o.h && rect.y + rect.h > o.y) return false
        }
        return true
      }
      if (globe.home) {
        var hp = screenPoint(globe.home.lat, globe.home.lon, centerLon)
        if (hp.visible) {
          ctx.strokeStyle = accent
          ctx.lineWidth = 1.5
          ctx.beginPath()
          ctx.arc(hp.x, hp.y, 4.5, 0, Math.PI * 2)
          ctx.stroke()
          taken.push({ x: hp.x - 6, y: hp.y - 6, w: 12, h: 12 })
        }
      }
      var fontPx = Style.font.caption
      var labelFont = globe.panel.canvasFont(fontPx, false, false)
      var boldFont = globe.panel.canvasFont(fontPx, true, false)
      var order = []
      for (var c = 0; c < globe.cities.length; c++) order.push(c)
      order.sort(function(a, b) { return (b === globe.selectedIndex) - (a === globe.selectedIndex) })
      for (var k = 0; k < order.length; k++) {
        var index = order[k]
        var city = globe.cities[index]
        if (city.lat === null || city.lon === null) continue
        var p = screenPoint(city.lat, city.lon, centerLon)
        // Behind the globe: not drawn, not clickable.
        if (!p.visible) continue
        var selected = index === globe.selectedIndex
        ctx.fillStyle = selected ? accent : ink
        ctx.beginPath()
        ctx.arc(p.x, p.y, selected ? 4 : 3, 0, Math.PI * 2)
        ctx.fill()
        hits.push({ index: index, x: p.x, y: p.y })
        taken.push({ x: p.x - 4, y: p.y - 4, w: 8, h: 8 })
        if (!globe.showLabels) continue
        var offset = globe.panel.cityOffset(city)
        var label = city.name + (offset !== null ? " " + globe.panel.clockFor(globe.minuteMs, offset, false) : "")
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
      globe.cityHits = hits
    }
  }

  // Hover names the zone under the pointer; a click on a dot picks the
  // city; a drag or the wheel turns the globe.
  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    property real pressX: 0
    property real pressLon: 0
    property bool dragged: false

    function zoneUnder(x, y) {
      if (!globe.mapData) return null
      var place = Globe.unprojectOrtho(x - globe.centerX, globe.centerY - y, Globe.wrapLon(globe.centerLon), globe.radius)
      if (!place) return null
      var p = WorldMap.project(place.lat, place.lon)
      return WorldMap.zoneAt(globe.mapData, p.x, p.y)
    }

    onPressed: function(event) {
      globe.touched()
      turnAnimation.stop()
      pressX = event.x
      pressLon = globe.centerLon
      dragged = false
    }
    onPositionChanged: function(event) {
      if (pressed) {
        if (Math.abs(event.x - pressX) > Style.space(4)) dragged = true
        // The surface follows the pointer at the centre of the globe.
        if (dragged) globe.centerLon = pressLon - (event.x - pressX) / Math.max(1, globe.radius) * 180 / Math.PI
        globe.hover = null
        return
      }
      globe.pointer = { x: event.x, y: event.y }
      updateHover()
    }
    onExited: {
      globe.pointer = null
      globe.hover = null
    }

    // The zone or the Moon under the resting pointer; again after every
    // frame, since the globe may turn under it.
    function updateHover() {
      var p = globe.pointer
      if (!p || pressed) return
      globe.hover = globe.panel.mapHoverAt(globe.moonHit, p.x, p.y, zoneUnder)
    }
    // Only a sideways wheel (or Shift + wheel) turns the globe; the plain
    // wheel goes on scrolling the tab (the page's wheel area leaves it the
    // sideways ones: wantsWheel, Panel.wheelTakenBelow).
    function wantsWheel(wheel) { return globe.panel.wheelIsSideways(wheel) }
    // Any wheel over it stops the turning, also one that scrolls the page.
    function noticeWheel(wheel) { globe.touched() }
    Component.onCompleted: globe.panel.registerWheelArea(this)
    Component.onDestruction: globe.panel.unregisterWheelArea(this)
    onWheel: function(event) {
      var sideways = event.angleDelta.x !== 0 ? event.angleDelta.x
        : ((event.modifiers & Qt.ShiftModifier) ? event.angleDelta.y : 0)
      if (sideways === 0) {
        event.accepted = false
        return
      }
      globe.touched()
      turnAnimation.stop()
      globe.centerLon -= sideways / 120 * 10
    }
    onClicked: function(event) {
      if (dragged) return
      var best = -1
      var bestDistance = Style.space(14)
      for (var i = 0; i < globe.cityHits.length; i++) {
        var d = Math.hypot(globe.cityHits[i].x - event.x, globe.cityHits[i].y - event.y)
        if (d < bestDistance) {
          best = globe.cityHits[i].index
          bestDistance = d
        }
      }
      if (best < 0) return
      // Clicking the city already chosen still brings it to the middle.
      if (best === globe.selectedIndex) globe.turnTo(globe.placeLon(best))
      globe.cityClicked(best)
    }
  }

  TimeMapHoverLabel {
    panel: globe.panel
    hover: globe.hover
    boundsWidth: globe.width
  }
}
