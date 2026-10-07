import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "WorldMap.js" as WorldMap
import "Moon.js" as Moon
import "Globe.js" as Globe
import "GlobeView.js" as GlobeView

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
  // "space": lit as from above; "earth": as it stands in the sky of the
  // current place (here or the selected city), Panel.moonLook.
  readonly property string moonStyle: panel.displaySetting("worldMoonStyle", "space")
  readonly property var observer: panel.currentCoordinates
  onShowMoonChanged: canvas.requestPaint()
  onMoonStyleChanged: canvas.requestPaint()
  onObserverChanged: canvas.requestPaint()
  // Where the Moon was drawn on the front side, for the hover, or null.
  property var moonHit: null
  readonly property real moonRadius: Style.space(6)
  // What painting costs (the screenshot harness measures a turn): frames,
  // total and longest milliseconds, and the total per part (zones, land and
  // grid, twilight and sky, places).
  property var paintStats: ({ count: 0, total: 0, max: 0 })
  // The same per part for the zoomed or tilted frames (paintView).
  property var viewStats: null
  // The pointer resting over the globe, for the hover, or null.
  property var pointer: null
  readonly property bool showLabels: panel.displaySetting("worldMapLabels", true)
  readonly property bool showGolden: panel.displaySetting("heroGoldenHour", false)
  readonly property bool showBlue: panel.displaySetting("heroBlueHour", false)
  readonly property bool autoRotate: panel.displaySetting("globeAutoRotate", false)
  // The visible height below the globe's top (TimeWorld): the globe fills
  // it, as wide as the page at most and Style.space(240) at least.
  property real fitHeight: Infinity
  readonly property real diameter: Math.min(width, Math.max(Style.space(240), Math.min(width, fitHeight)))
  // Zoomed in (z1 … z3, the radius doubling per step) or tilted, it is
  // drawn through Globe.js' view functions from (centerLat, centerLon);
  // the whole globe (z0, upright) keeps the equatorial drawing and its
  // cheap frames for turning by itself.
  readonly property int maxZoom: 3
  property int zoom: 0
  property real centerLat: 0
  readonly property bool tilted: zoom > 0 || Math.abs(centerLat) > 0.01
  onZoomChanged: repaint()
  onCenterLatChanged: repaint()
  readonly property real radius: diameter / 2 * Math.pow(2, zoom)
  readonly property real centerX: width / 2
  readonly property real centerY: diameter / 2
  implicitHeight: diameter

  // The longitude facing the viewer, unwrapped: turns animate through it
  // the short way and the drawing wraps it.
  property real centerLon: 0
  ParallelAnimation {
    id: turnAnimation
    NumberAnimation { id: latAnimation; target: globe; property: "centerLat"; duration: 600; easing.type: Easing.InOutCubic }
    NumberAnimation { id: lonAnimation; target: globe; property: "centerLon"; duration: 600; easing.type: Easing.InOutCubic }
  }

  // Turns to a longitude the short way round; with a latitude (zoomed in)
  // it tilts there too, and at z0 it rights itself.
  function turnTo(lon, lat) {
    if (lon === null || lon === undefined || isNaN(lon)) return
    turnAnimation.stop()
    latAnimation.from = centerLat
    latAnimation.to = zoom === 0 || lat === null || lat === undefined || isNaN(lat) ? (zoom === 0 ? 0 : centerLat)
      : GlobeView.clampLat(lat)
    lonAnimation.from = centerLon
    lonAnimation.to = centerLon + Globe.shortestTurn(centerLon, lon)
    turnAnimation.start()
  }
  // One step in or out with the place under (px, py) from the middle kept
  // there (GlobeView.zoomedCentre); back at z0 the globe stands upright.
  function zoomAt(delta, px, py) {
    touched()
    var next = Math.max(0, Math.min(maxZoom, zoom + delta))
    if (next === zoom) return
    turnAnimation.stop()
    if (next === 0) {
      zoom = 0
      turnTo(centerLon)
      return
    }
    var r1 = diameter / 2 * Math.pow(2, next)
    var centre = GlobeView.zoomedCentre(centerLat, centerLon, radius, r1, px, py)
    centerLat = centre.lat
    centerLon = centre.lon
    zoom = next
  }
  function zoomBy(delta) { zoomAt(delta, 0, 0) }
  // The crosshair: the current place in the middle, the zoom kept.
  function recenter() {
    touched()
    var c = panel.currentCoordinates || home
    if (c) turnTo(c.lon, c.lat)
  }
  // 0: the whole globe, upright, on the current place.
  function reset() {
    touched()
    zoom = 0
    var c = panel.currentCoordinates || home
    turnTo(c ? c.lon : centerLon)
  }
  // Ctrl + arrows: east and west turn, north and south tilt (zoomed in).
  function turnStep(east, north) {
    touched()
    var step = GlobeView.stepDegrees(zoom, radius, diameter)
    var lat = turnAnimation.running ? latAnimation.to : centerLat
    var lon = turnAnimation.running ? lonAnimation.to : centerLon
    var cos = zoom >= 1 ? Math.max(0.2, Math.cos(lat * Math.PI / 180)) : 1
    turnTo(lon + east * step / cos, lat + north * step)
  }
  // Keys from the World tab (Panel.handlePanelKey): + − zoom, 0 the whole
  // globe, Ctrl + arrows turn and tilt.
  function handleMapKey(event) {
    var text = event.text
    var control = (event.modifiers & Qt.ControlModifier) !== 0
    if (control) {
      if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) turnStep(event.key === Qt.Key_Right ? 1 : -1, 0)
      else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) turnStep(0, event.key === Qt.Key_Up ? 1 : -1)
      else return false
      return true
    }
    if (text === "+" || text === "=") { zoomBy(1); return true }
    if (text === "-" || text === "−") { zoomBy(-1); return true }
    if (text === "0") { reset(); return true }
    return false
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

  function placeLat(index) {
    var city = index >= 0 ? cities[index] : null
    if (city && city.lat !== null && city.lon !== null) return city.lat
    return index < 0 && home ? home.lat : null
  }

  Component.onCompleted: {
    var lon = placeLon(selectedIndex)
    centerLon = lon === null ? (home ? home.lon : 0) : lon
  }
  onSelectedIndexChanged: {
    touched()
    turnTo(placeLon(selectedIndex), placeLat(selectedIndex))
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
  // The instant drawn: now, or the World timeline's (Panel.worldMinuteMs).
  readonly property double minuteMs: panel.worldMinuteMs
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
    // On the GPU surface the shader draws them from the Sun alone, so a
    // time lapse costs only the uniforms.
    for (var i = 0; i < (surfaceOn ? 0 : elevations.length); i++)
      shapes[elevations[i]] = WorldMap.twilightRings(ms, elevations[i], rotating ? 4 : 2).map(function(r) { return Globe.prepareLatLon(r) })
    return { layers: layers, shapes: shapes, sun: WorldMap.subsolarPoint(ms) }
  }
  property var hover: null

  onGlobeDataChanged: globe.repaint()
  onTwilightChanged: globe.repaint()
  onCitiesChanged: globe.repaint()
  onWidthChanged: globe.repaint()
  onShowLabelsChanged: globe.repaint()
  onHomeZoneChanged: globe.repaint()
  // While turning by itself the fills follow at most eight times a second
  // (they move under a pixel a frame); everything else repaints both.
  onCenterLonChanged: {
    canvas.requestPaint()
    if (!cheapFrames) return
    var now = Date.now()
    if (now - lastFillMs >= 120) {
      lastFillMs = now
      fillCanvas.requestPaint()
    }
  }
  property double lastFillMs: 0
  function repaint() {
    canvas.requestPaint()
    if (cheapFrames) fillCanvas.requestPaint()
  }
  readonly property string labelStyle: panel.interfaceLanguage + "|" + panel.hour12 + "|" + panel.fontFamily
    + "|" + selectedIndex
  onLabelStyleChanged: canvas.requestPaint()
  Connections {
    target: globe.panel.zoneTable
    function onRevisionChanged() { globe.repaint() }
  }

  // ---- Turning by itself ----
  // After the set delay (General → Motion) it turns east, one turn in the set
  // minutes (General → Motion), only while it can be seen (popup open, World
  // tab). A press, drag, wheel or selection change stops it and restarts the
  // wait; a pointer resting on it does not, and the tooltip follows the turn.
  property bool rotating: false
  // Tilted it turns too (round its axis, the tilt kept); zoomed in it does
  // not.
  readonly property bool canRotate: autoRotate && panel.motionAllowed && panel.currentTab === "world"
    && visible && !mouse.pressed && zoom === 0
  onCanRotateChanged: if (!canRotate) rotating = false

  function touched() {
    rotating = false
    if (idleTimer.running) idleTimer.restart()
  }

  // Settings → Display → World: after how many idle seconds it starts, and
  // in how many minutes it makes one turn.
  readonly property int rotateDelaySeconds: Number(panel.generalSetting("motionDelay", "10")) || 10
  readonly property int rotateTurnMinutes: Number(panel.generalSetting("motionSpeed", "4")) || 4

  Timer {
    id: idleTimer
    interval: globe.rotateDelaySeconds * 1000
    running: globe.canRotate && !globe.rotating
    onTriggered: globe.rotating = true
  }

  // Frames a second as set (General → Motion, 15 unless changed); the turn
  // advances by the time elapsed. While turning it is drawn the cheap way
  // (cheapFrames).
  readonly property int rotateFps: Number(panel.generalSetting("motionFps", "15")) || 15
  // One step per frame shown (MotionGate), so the turn keeps step with the
  // display and stops by itself on another workspace.
  MotionGate {
    id: rotateGate
    active: globe.canRotate && globe.rotating
    fps: globe.rotateFps
    onStep: function(elapsed) {
      if (!turnAnimation.running) globe.centerLon += elapsed * 360 / (globe.rotateTurnMinutes * 60000)
    }
  }

  // The zones and the land as unit vectors for the view (Globe.js), from
  // the same rings, once per process.
  readonly property var zoneVectors: globeData ? globeData.zones.map(function(zone) {
    return { o: zone.o, rings: zone.rings.map(function(ring) { return Globe.prepareVectors(ring.p) }) }
  }) : []
  readonly property var landVectors: globeData ? globeData.land.map(function(ring) { return Globe.prepareVectors(ring.p) }) : []

  // While it turns by itself: no hatching, a coarser coastline without the
  // smallest islands, only the selected place labelled.
  readonly property bool cheapFrames: rotating && !surfaceOn
  // Every `every`-th point, and no ring smaller than `least` degrees each
  // way.
  function coarseRings(rings, every, least) {
    var out = []
    for (var i = 0; i < rings.length; i++) {
      var ring = rings[i]
      var p = ring.p
      var latLo = 90, latHi = -90
      for (var k = 0; k < p.length; k += 2) {
        if (p[k] < latLo) latLo = p[k]
        if (p[k] > latHi) latHi = p[k]
      }
      if (ring.hi - ring.lo < least && latHi - latLo < least) continue
      var flat = []
      for (var j = 0; j < p.length; j += 2 * every) flat.push(p[j], p[j + 1])
      if (flat.length >= 6) out.push(Globe.prepare(flat))
    }
    return out
  }
  readonly property var coarseLand: globeData ? coarseRings(globeData.land, 3, 1.5) : []
  readonly property var coarseZones: globeData ? globeData.zones.map(function(zone) {
    return { o: zone.o, rings: globe.coarseRings(zone.rings, 6, 3) }
  }) : []
  onCheapFramesChanged: {
    canvas.requestPaint()
    fillCanvas.requestPaint()
  }

  // Where each city's dot was drawn, for clicks.
  property var cityHits: []

  // ---- The GPU surface (TimeGlobeSurface.qml, shared with More Weather):
  //      the sphere, the zones, the land's fill and the night, from an
  //      equirectangular picture (TimeGlobeTexture.qml) painted once per
  //      change; turning only changes its uniforms. Up to z2 and where
  //      shaders run (not on the software scene graph of the offscreen
  //      harness); else the Canvas path below draws everything.
  readonly property bool gpuSurface: surface.available && zoom < 3
  // The picture's last repaint (ms), for the harness and the status.
  readonly property real textureMs: surfaceTexture.lastMs
  // The Canvas as with the surface on (the harness measures that branch
  // offscreen, where shaders do not run).
  property bool forceSurfaceBranch: false
  readonly property bool surfaceOn: gpuSurface || forceSurfaceBranch
  onSurfaceOnChanged: repaint()
  // Turning by itself, being dragged or turned: the per-frame Canvas keeps
  // to the least (only the selected place named).
  readonly property bool moving: rotating || mouse.dragged && mouse.pressed || turnAnimation.running
  readonly property bool coastOverlay: surfaceOn && zoom >= 1 && !moving
  onCoastOverlayChanged: repaint()
  onGpuSurfaceChanged: repaint()
  TimeGlobeTexture {
    id: surfaceTexture
    globeData: globe.globeData
    homeZone: globe.homeZone
    ink: globe.panel.foreground
  }
  TimeGlobeSurface {
    id: surface
    anchors.fill: parent
    visible: globe.gpuSurface
    style: "globe"
    centerLat: globe.tilted ? globe.centerLat : 0
    centerLon: globe.centerLon
    radius: globe.radius
    centerX: globe.centerX
    centerY: globe.centerY
    displayMs: globe.minuteMs
    night: globe.showNight
    goldenBand: globe.showGolden
    blueBand: globe.showBlue
    background: Color.popups.background
    baseColor: Qt.rgba(globe.panel.foreground.r, globe.panel.foreground.g, globe.panel.foreground.b, 0.03)
    textureSource: surfaceTexture
  }

  // ---- What the globe costs, for the IPC status (Panel status: globe):
  //      every 5 s while shown, the frames drawn (the surface's, else the
  //      Canvas's) and this process's CPU time from /proc/self/stat; the
  //      last minute spent turning by itself kept apart.
  property var perf: ({ surface: false, fps: 0, cpuMsPerFrame: 0, cpuPercent: 0, textureMs: 0 })
  property var perfLast: null
  property var turningHistory: []
  property FileView procStat: FileView {
    path: "/proc/self/stat"
    blockLoading: true
    printErrors: false
  }
  Component.onDestruction: if (globe.panel.globeItem === globe) globe.panel.globeItem = null
  Timer {
    interval: 5000
    repeat: true
    running: globe.panel.opened && globe.panel.currentTab === "world" && globe.visible
    onRunningChanged: {
      globe.perfLast = null
      if (running) globe.panel.globeItem = globe
    }
    onTriggered: {
      globe.procStat.reload()
      var text = String(globe.procStat.text() || "")
      var fields = text.slice(text.lastIndexOf(")") + 2).split(" ")
      var cpuMs = (Number(fields[11]) + Number(fields[12])) * 10
      var frames = globe.gpuSurface ? surface.frames : globe.paintStats.count
      var now = Date.now()
      var last = globe.perfLast
      if (last && isFinite(cpuMs) && now > last.at) {
        var dFrames = Math.max(0, frames - last.frames), dCpu = cpuMs - last.cpu, dt = now - last.at
        var history = globe.turningHistory
        if (last.turning && globe.rotating) {
          history = history.concat([{ dt: dt, frames: dFrames, cpu: dCpu, surface: globe.gpuSurface }])
          var total = 0
          for (var h = history.length - 1; h >= 0; h--) {
            total += history[h].dt
            if (total > 60000) { history = history.slice(h + 1); break }
          }
          globe.turningHistory = history
        }
        var tDt = 0, tFrames = 0, tCpu = 0
        for (var k = 0; k < history.length; k++) {
          tDt += history[k].dt
          tFrames += history[k].frames
          tCpu += history[k].cpu
        }
        globe.perf = { surface: globe.gpuSurface, fps: Math.round(dFrames / dt * 10000) / 10,
          cpuMsPerFrame: dFrames ? Math.round(dCpu / dFrames * 10) / 10 : 0,
          cpuPercent: Math.round(dCpu / dt * 1000) / 10, textureMs: surfaceTexture.lastMs,
          turning: { seconds: Math.round(tDt / 1000), fps: tDt ? Math.round(tFrames / tDt * 10000) / 10 : 0,
            cpuPercent: tDt ? Math.round(tCpu / tDt * 1000) / 10 : 0,
            cpuMsPerFrame: tFrames ? Math.round(tCpu / tFrames * 10) / 10 : 0,
            surface: history.length ? history[history.length - 1].surface : globe.gpuSurface } }
      }
      globe.perfLast = { at: now, cpu: cpuMs, frames: frames, turning: globe.rotating }
    }
  }

  // The fills while it turns by itself (cheapFrames): zones, land and
  // twilight at a third of the resolution, scaled up under the sharp
  // lines of `canvas`. Fills are soft-edged anyway, and painting them is
  // what costs (the rasterizer's time grows with the filled area).
  readonly property real fillScale: 3
  Canvas {
    id: fillCanvas
    visible: globe.cheapFrames
    width: Math.ceil(globe.width / globe.fillScale)
    height: Math.ceil(globe.height / globe.fillScale)
    transformOrigin: Item.TopLeft
    scale: globe.fillScale
    smooth: true
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      if (!globe.cheapFrames || !globe.globeData || globe.radius <= 0) return
      var lon = Globe.wrapLon(globe.centerLon)
      ctx.scale(1 / globe.fillScale, 1 / globe.fillScale)
      // No clip: every fill is clipped to the front side already, and a
      // clip path makes each fill dearer.
      canvas.disc(ctx)
      ctx.fillStyle = canvas.rgba(canvas.ink, 0.03)
      ctx.fill()
      canvas.zonesPass(ctx, lon)
      canvas.gridPass(ctx, lon)
      canvas.landFillPass(ctx, lon)
      canvas.twilightPass(ctx, lon)
    }
  }

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

    // The fills, in passes the cheap frames hand to fillCanvas.
    function backgroundPass(ctx) {
      ctx.fillStyle = rgba(ink, 0.03)
      ctx.fillRect(0, 0, globe.width, globe.height)
    }
    // Zebra: whole-hour zones alternate by the parity of their hour;
    // zones off the full hour are hatched (flat while turning).
    function zonesPass(ctx, lon) {
      var hatch = globe.cheapFrames ? null : ctx.createPattern(rgba(ink, 0.16), Qt.BDiagPattern)
      var zones = globe.cheapFrames ? globe.coarseZones : globe.globeData.zones
      for (var z = 0; z < zones.length; z++) {
        var zone = zones[z]
        var band = WorldMap.zebraBand(zone.o)
        fillRings(ctx, zone.rings, lon, zone.o === globe.homeZone ? rgba(accent, 0.22)
          : (band === 2 ? (hatch || rgba(ink, 0.08)) : rgba(ink, band === 1 ? 0.12 : 0.035)))
      }
    }
    // Meridians every 15° and the equator, faintly.
    function gridPass(ctx, lon) {
      ctx.strokeStyle = rgba(ink, 0.07)
      ctx.lineWidth = 1
      var lines = Globe.gridLines(lon, globe.radius, 15)
      ctx.beginPath()
      for (var g = 0; g < lines.length; g++) trace(ctx, lines[g], false)
      ctx.stroke()
    }
    function landFillPass(ctx, lon) {
      fillRings(ctx, globe.cheapFrames ? globe.coarseLand : globe.globeData.land, lon, rgba(ink, 0.07))
    }
    // The twilight layers: the golden and the blue band with soft edges,
    // the night in three steps (WorldMap.twilightLayers). Each cap is
    // clipped to the front side once per frame, however many layers share
    // it.
    // While turning, the caps come straight from the view (analytic, no
    // clipping of rings).
    // With the GPU surface only the golden and blue bands are drawn here;
    // the night's three steps are the shader's.
    function twilightPass(ctx, lon, bandsOnly) {
      var tw = globe.twilight
      var front = {}
      if (globe.cheapFrames) {
        var m = Globe.viewMatrix(0, lon)
        var antiLon = tw.sun.lon > 0 ? tw.sun.lon - 180 : tw.sun.lon + 180
        for (var a in tw.shapes) front[a] = Globe.capPolygonView(-tw.sun.lat, antiLon, 90 + Number(a), m, globe.radius)
      } else {
        for (var e in tw.shapes) {
          front[e] = []
          for (var c = 0; c < tw.shapes[e].length; c++) front[e] = front[e].concat(Globe.frontPolygons(tw.shapes[e][c], lon, globe.radius))
        }
      }
      ctx.fillRule = Qt.OddEvenFill
      var count = tw.layers.length - (bandsOnly && globe.showNight ? 3 : 0)
      for (var t = 0; t < count; t++) {
        var layer = tw.layers[t]
        var polys = front[layer.high].concat(layer.low !== null ? front[layer.low] : [])
        if (!polys.length) continue
        ctx.beginPath()
        for (var q = 0; q < polys.length; q++) trace(ctx, polys[q], true)
        ctx.fillStyle = Qt.rgba(layer.fill.r, layer.fill.g, layer.fill.b, layer.fill.a)
        ctx.fill()
      }
    }

    onPaint: {
      var started = Date.now()
      var ctx = getContext("2d")
      ctx.reset()
      var data = globe.globeData
      if (!data || globe.radius <= 0) return
      var lon = Globe.wrapLon(globe.centerLon)
      var R = globe.radius
      if (globe.tilted) {
        paintView(ctx)
        var doneView = Date.now()
        var sv = globe.paintStats
        globe.paintStats = { count: sv.count + 1, total: sv.total + doneView - started, max: Math.max(sv.max, doneView - started) }
        return
      }
      // While turning by itself the fills go to fillCanvas, at a lower
      // resolution; this canvas keeps the lines, the Sun, the Moon and the
      // places sharp.
      var split = globe.cheapFrames
      // The GPU surface (TimeGlobeSurface) draws the sphere, the zones, the
      // land's fill and the night under this canvas.
      var gpu = globe.surfaceOn

      ctx.save()
      if (!split && !gpu) {
        disc(ctx)
        ctx.clip()
        backgroundPass(ctx)
        zonesPass(ctx, lon)
      }

      var zonesDone = Date.now()

      // With the surface the grid, the coast and the bands are in its
      // picture and shader: per frame only the Sun, the Moon, the places
      // and the rim are drawn here.
      if (!split && !gpu) gridPass(ctx, lon)

      // Land: a light fill and a crisp coastline.
      if (!split && !gpu) landFillPass(ctx, lon)
      var land = gpu ? [] : (globe.cheapFrames ? globe.coarseLand : data.land)
      ctx.beginPath()
      for (var l = 0; l < land.length; l++) {
        var coast = Globe.frontLines(land[l], lon, R)
        for (var c = 0; c < coast.length; c++) trace(ctx, coast[c], false)
      }
      ctx.strokeStyle = rgba(ink, 0.55)
      ctx.lineWidth = 0.8
      ctx.stroke()

      var landDone = Date.now()

      if (!split && !gpu) twilightPass(ctx, lon, false)
      // The Sun at its zenith point.
      var tw = globe.twilight
      if (globe.showNight) {
        var sun = screenPoint(tw.sun.lat, tw.sun.lon, lon)
        if (sun.visible) WorldMap.paintSun(ctx, sun.x, sun.y, globe.panel.sunColor, globe.panel.rgbOf(Color.popups.background))
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
        globe.moonHit = globe.panel.paintMapMoon(ctx, mx, my, globe.moonRadius, globe.moonStyle, moon,
          Moon.moonLitAngle(moon, tw.sun, function(lat, lon2) { return screenPoint(lat, lon2, lon) }), globe.minuteMs, ink)
      }

      ctx.strokeStyle = rgba(ink, 0.35)
      ctx.lineWidth = 1
      disc(ctx)
      ctx.stroke()

      var skyDone = Date.now()
      paintPlaces(ctx, function(lat, lon2) { return screenPoint(lat, lon2, lon) })
      mouse.updateHover()
      var done = Date.now()
      var st = globe.paintStats
      globe.paintStats = { count: st.count + 1, total: st.total + done - started, max: Math.max(st.max, done - started),
        zones: (st.zones || 0) + zonesDone - started, land: (st.land || 0) + landDone - zonesDone,
        sky: (st.sky || 0) + skyDone - landDone, places: (st.places || 0) + done - skyDone }
    }

    // Zoomed in or tilted: everything through the view matrix, sharp, the
    // twilight as analytic caps.
    function paintView(ctx) {
      var m = Globe.viewMatrix(globe.centerLat, Globe.wrapLon(globe.centerLon))
      var R = globe.radius
      var cx = globe.centerX, cy = globe.centerY
      function traceXY(xy, close) {
        ctx.moveTo(cx + xy[0], cy - xy[1])
        for (var i = 2; i < xy.length; i += 2) ctx.lineTo(cx + xy[i], cy - xy[i + 1])
        if (close) ctx.closePath()
      }
      // Zoomed in, most rings lie outside the canvas: a ring is skipped when
      // its bounding cap, projected, misses the canvas.
      var W = width, H = height
      function inView(ring) {
        if (ring.sinMax < 0) return true
        var c = ring.c
        var bound = R * Math.sqrt(Math.max(0, 2 - 2 * Math.sqrt(Math.max(0, 1 - ring.sinMax * ring.sinMax)))) + 2
        var px = cx + R * (m[0] * c[0] + m[1] * c[1] + m[2] * c[2])
        var py = cy - R * (m[3] * c[0] + m[4] * c[1] + m[5] * c[2])
        return px + bound >= 0 && px - bound <= W && py + bound >= 0 && py - bound <= H
      }
      function fillVectors(rings, style) {
        ctx.beginPath()
        for (var r = 0; r < rings.length; r++) {
          if (!inView(rings[r])) continue
          var polys = Globe.frontPolygonsView(rings[r], m, R)
          for (var q = 0; q < polys.length; q++) traceXY(polys[q], true)
        }
        ctx.fillStyle = style
        ctx.fillRule = Qt.OddEvenFill
        ctx.fill()
      }
      function toScreen(lat, lon) {
        var p = Globe.projectView(lat, lon, m, R)
        return { x: cx + p.x, y: cy - p.y, visible: p.visible }
      }
      ctx.save()
      ctx.beginPath()
      ctx.arc(cx, cy, R, 0, Math.PI * 2)
      ctx.clip()
      var gpu = globe.surfaceOn
      if (!gpu) {
        ctx.fillStyle = rgba(ink, 0.03)
        ctx.fillRect(0, 0, width, height)
      }
      var t0 = Date.now()
      var hatch = ctx.createPattern(rgba(ink, 0.16), Qt.BDiagPattern)
      for (var z = 0; z < (gpu ? 0 : globe.zoneVectors.length); z++) {
        var zone = globe.zoneVectors[z]
        var band = WorldMap.zebraBand(zone.o)
        fillVectors(zone.rings, zone.o === globe.homeZone ? rgba(accent, 0.22)
          : (band === 2 ? hatch : rgba(ink, band === 1 ? 0.12 : 0.035)))
      }
      ctx.strokeStyle = rgba(ink, 0.07)
      ctx.lineWidth = 1
      var t1 = Date.now()
      var grid = gpu ? [] : Globe.gridLinesView(m, R, GlobeView.gridStep(globe.zoom))
      ctx.beginPath()
      for (var g = 0; g < grid.length; g++) traceXY(grid[g], false)
      ctx.stroke()
      if (!gpu) fillVectors(globe.landVectors, rgba(ink, 0.07))
      ctx.beginPath()
      // With the surface the coast is in its picture; zoomed in and at rest
      // a crisp one goes on top (the picture's texels grow with the zoom).
      var coastOn = !gpu || globe.coastOverlay
      for (var l = 0; l < (coastOn ? globe.landVectors.length : 0); l++) {
        if (!inView(globe.landVectors[l])) continue
        var coast = Globe.frontLinesView(globe.landVectors[l], m, R)
        for (var c = 0; c < coast.length; c++) traceXY(coast[c], false)
      }
      ctx.strokeStyle = rgba(ink, 0.55)
      ctx.lineWidth = 0.8
      ctx.stroke()
      var t2 = Date.now()
      var tw = globe.twilight
      var antiLon = tw.sun.lon > 0 ? tw.sun.lon - 180 : tw.sun.lon + 180
      var caps = {}
      for (var e in tw.shapes) caps[e] = Globe.capPolygonView(-tw.sun.lat, antiLon, 90 + Number(e), m, R)
      ctx.fillRule = Qt.OddEvenFill
      var layerCount = gpu ? 0 : tw.layers.length
      for (var t = 0; t < layerCount; t++) {
        var layer = tw.layers[t]
        var polys = caps[layer.high].concat(layer.low !== null ? caps[layer.low] : [])
        if (!polys.length) continue
        ctx.beginPath()
        for (var k = 0; k < polys.length; k++) traceXY(polys[k], true)
        ctx.fillStyle = Qt.rgba(layer.fill.r, layer.fill.g, layer.fill.b, layer.fill.a)
        ctx.fill()
      }
      if (globe.showNight) {
        var sun = toScreen(tw.sun.lat, tw.sun.lon)
        if (sun.visible) WorldMap.paintSun(ctx, sun.x, sun.y, globe.panel.sunColor, globe.panel.rgbOf(Color.popups.background))
      }
      var moon = globe.showMoon ? Moon.moonPosition(globe.minuteMs) : null
      var moonAt = moon ? toScreen(moon.lat, moon.lon) : null
      if (moon && moonAt.visible) Moon.paintMoonShadow(ctx, moonAt.x, moonAt.y, globe.moonRadius)
      ctx.restore()
      globe.moonHit = null
      if (moon && moonAt.visible) {
        var mx = cx + (moonAt.x - cx) * (1 + 0.15 / Math.pow(2, globe.zoom))
        var my = cy + (moonAt.y - cy) * (1 + 0.15 / Math.pow(2, globe.zoom))
        globe.moonHit = globe.panel.paintMapMoon(ctx, mx, my, globe.moonRadius, globe.moonStyle, moon,
          Moon.moonLitAngle(moon, tw.sun, toScreen), globe.minuteMs, ink)
      }
      ctx.strokeStyle = rgba(ink, 0.35)
      ctx.lineWidth = 1
      ctx.beginPath()
      ctx.arc(cx, cy, R, 0, Math.PI * 2)
      ctx.stroke()
      var t3 = Date.now()
      paintPlaces(ctx, toScreen)
      mouse.updateHover()
      var st = globe.viewStats || { zones: 0, land: 0, sky: 0, places: 0 }
      globe.viewStats = { zones: st.zones + t1 - t0, land: st.land + t2 - t1, sky: st.sky + t3 - t2, places: st.places + Date.now() - t3 }
    }

    function screenPoint(lat, lon, centerLon) {
      var p = Globe.projectOrtho(lat, lon, centerLon, globe.radius)
      return { x: globe.centerX + p.x, y: globe.centerY - p.y, visible: p.visible }
    }

    // toScreen(lat, lon): { x, y, visible } on the canvas.
    function paintPlaces(ctx, toScreen) {
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
        var hp = toScreen(globe.home.lat, globe.home.lon)
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
        var p = toScreen(city.lat, city.lon)
        // Behind the globe: not drawn, not clickable.
        if (!p.visible) continue
        var selected = index === globe.selectedIndex
        ctx.fillStyle = selected ? accent : ink
        ctx.beginPath()
        ctx.arc(p.x, p.y, selected ? 4 : 3, 0, Math.PI * 2)
        ctx.fill()
        hits.push({ index: index, x: p.x, y: p.y })
        taken.push({ x: p.x - 4, y: p.y - 4, w: 8, h: 8 })
        if (!globe.showLabels || ((globe.cheapFrames || (globe.surfaceOn && globe.moving)) && !selected)) continue
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
    property real pressY: 0
    property real pressLon: 0
    property real pressLat: 0
    property bool dragged: false

    function zoneUnder(x, y) {
      if (!globe.mapData) return null
      var place = globe.tilted
        ? Globe.unprojectView(x - globe.centerX, globe.centerY - y, Globe.viewMatrix(globe.centerLat, Globe.wrapLon(globe.centerLon)), globe.radius)
        : Globe.unprojectOrtho(x - globe.centerX, globe.centerY - y, Globe.wrapLon(globe.centerLon), globe.radius)
      if (!place) return null
      var p = WorldMap.project(place.lat, place.lon)
      return WorldMap.zoneAt(globe.mapData, p.x, p.y)
    }

    onPressed: function(event) {
      globe.touched()
      turnAnimation.stop()
      pressX = event.x
      pressY = event.y
      pressLon = globe.centerLon
      pressLat = globe.centerLat
      dragged = false
    }
    onPositionChanged: function(event) {
      if (pressed) {
        if (Math.abs(event.x - pressX) + (globe.zoom > 0 ? Math.abs(event.y - pressY) : 0) > Style.space(4)) dragged = true
        // The surface follows the pointer at the centre of the globe;
        // zoomed in, a drag up or down tilts it too.
        if (dragged && globe.zoom > 0) {
          var c = GlobeView.panned(pressLat, pressLon, event.x - pressX, event.y - pressY, globe.radius)
          globe.centerLat = c.lat
          globe.centerLon = c.lon
        } else if (dragged) {
          globe.centerLon = pressLon - (event.x - pressX) / Math.max(1, globe.radius) * 180 / Math.PI
        }
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
    function wantsWheel(wheel) { return (wheel.modifiers & Qt.ControlModifier) !== 0 || globe.panel.wheelIsSideways(wheel) }
    // Any wheel over it stops the turning, also one that scrolls the page.
    function noticeWheel(wheel) { globe.touched() }
    Component.onCompleted: globe.panel.registerWheelArea(this)
    Component.onDestruction: globe.panel.unregisterWheelArea(this)
    property real zoomWheel: 0
    // A double click zooms in at the pointer, Ctrl + wheel in or out.
    onDoubleClicked: function(event) { globe.zoomAt(1, event.x - globe.centerX, event.y - globe.centerY) }
    onWheel: function(event) {
      if (event.modifiers & Qt.ControlModifier) {
        zoomWheel += event.angleDelta.y
        if (Math.abs(zoomWheel) >= 120) {
          globe.zoomAt(zoomWheel > 0 ? 1 : -1, event.x - globe.centerX, event.y - globe.centerY)
          zoomWheel = 0
        }
        return
      }
      var sideways = event.angleDelta.x !== 0 ? event.angleDelta.x
        : ((event.modifiers & Qt.ShiftModifier) ? event.angleDelta.y : 0)
      if (sideways === 0) {
        event.accepted = false
        return
      }
      globe.touched()
      turnAnimation.stop()
      if (globe.zoom > 0) globe.centerLon -= sideways / 120 * 10 / Math.pow(2, globe.zoom)
      else globe.centerLon -= sideways / 120 * 10
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
      if (best === globe.selectedIndex) globe.turnTo(globe.placeLon(best), globe.placeLat(best))
      globe.cityClicked(best)
    }
  }

  TimeZoomControls {
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: Style.space(6)
    panel: globe.panel
    canZoomOut: globe.zoom > 0
    canZoomIn: globe.zoom < globe.maxZoom
    onRecenter: globe.recenter()
    onZoomOut: globe.zoomBy(-1)
    onZoomIn: globe.zoomBy(1)
  }

  TimeMapHoverLabel {
    panel: globe.panel
    hover: globe.hover
    boundsWidth: globe.width
  }
}
