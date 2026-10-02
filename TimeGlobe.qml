import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model
import "WorldMap.js" as WorldMap
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
  readonly property bool showLabels: panel.displaySetting("worldMapLabels", true)
  readonly property bool showGolden: panel.displaySetting("heroGoldenHour", true)
  readonly property bool showBlue: panel.displaySetting("heroBlueHour", true)
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
  readonly property var twilight: {
    var ms = minuteMs
    function rings(e) { return WorldMap.twilightRings(ms, e).map(function(r) { return Globe.prepareLatLon(r) }) }
    return {
      night: showNight ? rings(0) : [],
      // Gold on the day side of the day/night line (+6° … 0°), blue on the
      // night side (0° … −8°): the line stays a crisp edge between them.
      golden: showGolden ? rings(6).concat(rings(0)) : [],
      blue: showBlue ? rings(0).concat(rings(-8)) : [],
      sun: WorldMap.subsolarPoint(ms)
    }
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
  // Ten seconds after the last touch it turns east, once in four minutes,
  // only while it can be seen: popup open, World tab, no pointer on it.
  property bool rotating: false
  readonly property bool canRotate: autoRotate && panel.opened && panel.currentTab === "world"
    && visible && !mouse.containsMouse && !mouse.pressed
  onCanRotateChanged: if (!canRotate) rotating = false

  function touched() {
    rotating = false
    if (idleTimer.running) idleTimer.restart()
  }

  // Settings → Display → World: after how many idle seconds it starts, and
  // in how many minutes it makes one turn.
  readonly property int rotateDelaySeconds: Number(panel.displaySetting("globeRotateDelay", "10")) || 10
  readonly property int rotateTurnMinutes: Number(panel.displaySetting("globeRotateSpeed", "1")) || 1

  Timer {
    id: idleTimer
    interval: globe.rotateDelaySeconds * 1000
    running: globe.canRotate && !globe.rotating
    onTriggered: globe.rotating = true
  }

  Timer {
    id: rotateTimer
    interval: 33
    repeat: true
    running: globe.canRotate && globe.rotating
    property double last: 0
    onRunningChanged: last = Date.now()
    onTriggered: {
      var now = Date.now()
      var elapsed = Math.min(200, now - last)
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

      // The golden and the blue hour as bands along the terminator, then
      // the night side and the sun.
      var tw = globe.twilight
      fillRings(ctx, tw.golden, lon, Qt.rgba(0xE3 / 255, 0xA4 / 255, 0x47 / 255, 0.28))
      fillRings(ctx, tw.blue, lon, Qt.rgba(0x3B / 255, 0x5B / 255, 0xD6 / 255, 0.28))
      if (globe.showNight) {
        var nf = WorldMap.nightFill([Color.popups.background.r, Color.popups.background.g, Color.popups.background.b])
        fillRings(ctx, tw.night, lon, Qt.rgba(nf.r, nf.g, nf.b, nf.a))
        var sun = Globe.projectOrtho(tw.sun.lat, tw.sun.lon, lon, R)
        if (sun.visible) {
          var sx = globe.centerX + sun.x
          var sy = globe.centerY - sun.y
          ctx.fillStyle = rgba(accent, 0.9)
          ctx.beginPath()
          ctx.arc(sx, sy, 3.5, 0, Math.PI * 2)
          ctx.fill()
          ctx.strokeStyle = rgba(accent, 0.5)
          ctx.lineWidth = 1
          ctx.beginPath()
          ctx.arc(sx, sy, 7, 0, Math.PI * 2)
          ctx.stroke()
        }
      }
      // The Moon at its sub-lunar point, lit towards the Sun; hidden on the
      // back side.
      globe.moonHit = null
      if (globe.showMoon) {
        var moon = WorldMap.moonPosition(globe.minuteMs)
        var mp = screenPoint(moon.lat, moon.lon, lon)
        if (mp.visible) {
          var toward = WorldMap.towards(moon.lat, moon.lon, tw.sun.lat, tw.sun.lon, 4)
          var tp = screenPoint(toward.lat, toward.lon, lon)
          var nfm = WorldMap.nightFill([Color.popups.background.r, Color.popups.background.g, Color.popups.background.b])
          WorldMap.paintMoon(ctx, mp.x, mp.y, Style.space(5), Math.atan2(tp.y - mp.y, tp.x - mp.x), moon.illuminated,
            rgba(globe.panel.mutedText, 0.9), Qt.rgba(nfm.r, nfm.g, nfm.b, 0.9), rgba(ink, 0.6))
          globe.moonHit = { x: mp.x, y: mp.y, moon: moon }
        }
      }
      ctx.restore()

      ctx.strokeStyle = rgba(ink, 0.35)
      ctx.lineWidth = 1
      disc(ctx)
      ctx.stroke()

      paintPlaces(ctx, lon)
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
    onContainsMouseChanged: if (containsMouse) globe.touched()

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
      if (globe.moonHit && Math.hypot(globe.moonHit.x - event.x, globe.moonHit.y - event.y) <= Style.space(8)) {
        globe.hover = { moon: globe.moonHit.moon, x: event.x, y: event.y }
        return
      }
      var minutes = zoneUnder(event.x, event.y)
      globe.hover = minutes === null ? null : { minutes: minutes, x: event.x, y: event.y }
    }
    onExited: globe.hover = null
    // Only a sideways wheel (or Shift + wheel) turns the globe; the plain
    // wheel goes on scrolling the tab (the page's wheel area leaves it the
    // sideways ones: wantsWheel, Panel.wheelTakenBelow).
    function wantsWheel(wheel) { return globe.panel.wheelIsSideways(wheel) }
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

  Rectangle {
    visible: globe.hover !== null
    x: globe.hover ? Math.min(globe.width - width, globe.hover.x + Style.space(12)) : 0
    y: globe.hover ? Math.max(0, globe.hover.y - height - Style.space(6)) : 0
    width: hoverLabel.implicitWidth + Style.space(12)
    height: hoverLabel.implicitHeight + Style.space(6)
    radius: Style.cornerRadius
    color: Color.popups.background
    border.color: globe.panel.subtleText
    border.width: Style.spacing.hairline

    Text {
      id: hoverLabel
      anchors.centerIn: parent
      // The zones are standard time, as on the flat map.
      text: globe.hover && globe.hover.moon ? globe.panel.moonText(globe.hover.moon)
        : globe.hover ? Model.utcOffsetLabel(globe.hover.minutes * 60) + "  ·  "
        + globe.panel.clockFor(globe.panel.nowMs, globe.hover.minutes * 60, false)
        + "  " + globe.panel.i18n("standardTime") : ""
      color: globe.panel.foreground
      font.family: globe.panel.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
