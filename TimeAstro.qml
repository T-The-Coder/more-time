import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Astro.js" as Astro
import "AstroRotation.js" as AstroRotation
import "AstroEvents.js" as AstroEvents
import "AstroClock.js" as AstroClock
import "AstroBodies.js" as AstroBodies
import "AstroIss.js" as AstroIss
import "AstroDate.js" as AstroDate
import "Model.js" as Model
import "Globe.js" as Globe
import "Moon.js" as Moon
import "AstroView.js" as AstroView
import "Sky.js" as Sky

// The Astro tab: the solar system as a clock. The Sun and the eight planets
// where they stand now (Astro.js, JPL's approximate elements), seen at a
// slant from above the ecliptic, the distances drawn as r^0.45 so Mercury
// to Neptune fit (AstroView.js). The month ring around Earth's orbit makes
// Earth the hand of the year. A drag turns and tilts the view, the
// sideways wheel turns it, Ctrl + wheel or + − change the zoom; the pointer
// on a body names it with its distances and period.
Column {
  id: view
  required property var panel
  spacing: Style.space(10)

  TimeTabHeader {
    width: parent.width
    panel: view.panel
    hint: view.panel.i18n("astroKeysHint") + (view.showTimeline ? " · " + view.panel.i18n("astroTimeKeysHint") : "")
  }

  // Ctrl + ← → turn, Ctrl + ↑ ↓ tilt, + − zoom, 0 back to the start view
  // (from Panel.handlePanelKey); true when the key was taken.
  function handleAstroKey(event) {
    var control = (event.modifiers & Qt.ControlModifier) !== 0
    var key = event.key
    var text = event.text
    if (control && (key === Qt.Key_Left || key === Qt.Key_Right)) {
      sky.turnBy((key === Qt.Key_Right ? 1 : -1) * 15)
      return true
    }
    if (control && (key === Qt.Key_Up || key === Qt.Key_Down)) {
      sky.tiltBy((key === Qt.Key_Up ? 1 : -1) * 10)
      return true
    }
    if (control) return false
    // The timeline: , . a day, Space play / pause, n or Backspace back to
    // now, g the date field (Space stays the ringing's while something
    // rings).
    if (text === "," || text === ".") {
      sky.stepDays(text === "." ? 1 : -1)
      return true
    }
    if (key === Qt.Key_Space && !view.panel.ringer.ringing.length && view.showTimeline) {
      sky.togglePlay()
      return true
    }
    if (text === "n" || key === Qt.Key_Backspace) {
      sky.backToNow()
      return true
    }
    if (text === "g" && view.showTimeline) {
      dateField.forceActiveFocus()
      dateField.selectAll()
      return true
    }
    if ((key === Qt.Key_Return || key === Qt.Key_Enter) && sky.traveling) {
      sky.stopTravel()
      return true
    }
    if (text === "+" || text === "=" || key === Qt.Key_Plus) {
      sky.zoomBy(1)
      return true
    }
    if (text === "-" || key === Qt.Key_Minus) {
      sky.zoomBy(-1)
      return true
    }
    if (text === "0") {
      sky.reset()
      return true
    }
    return false
  }

  // Esc: a running travel stops where it is; the date field is left
  // (Panel.handlePanelKey asks before closing).
  function handleAstroEscape() {
    if (sky.traveling) {
      sky.stopTravel()
      return true
    }
    if (dateField.activeFocus) {
      view.panel.restoreKeyFocus()
      return true
    }
    return false
  }

  readonly property bool showTimeline: panel.displaySetting("astroTimeline", true)
  readonly property bool showInfo: panel.displaySetting("astroInfo", true)

  Item {
    id: sky
    objectName: "timeAstro"
    width: parent.width
    // Fills the visible height below it (less the timeline and the info
    // line), like the globe: never taller than wide, never lower than
    // Style.space(240).
    readonly property real fitHeight: view.panel.viewportHeight - view.panel.tabContentTop - view.y - y - Style.space(16)
      - (timeline.visible ? timeline.height + view.spacing : 0) - (infoLine.visible ? infoLine.height + view.spacing : 0)
      - astroChips.height - view.spacing
    height: Math.max(Style.space(240), Math.min(width * 0.9, fitHeight))

    // Pictures are never mirrored, whatever the language.
    LayoutMirroring.enabled: false
    LayoutMirroring.childrenInherit: true

    readonly property var panel: view.panel
    readonly property bool showOrbits: panel.displaySetting("astroOrbits", true)
    readonly property bool showNames: panel.displaySetting("astroNames", true)
    readonly property bool showMonthRing: panel.displaySetting("astroMonthRing", true)
    readonly property bool autoRotate: panel.displaySetting("astroAutoRotate", false)
    // The Earth–Moon inset in a corner (not in the Earth–Moon zoom), and
    // the bodies' tilt and turning (bands, a meridian, Saturn's rings).
    readonly property bool showInset: panel.displaySetting("astroEarthInset", true)
    readonly property bool showRotation: panel.displaySetting("astroRotation", true)
    readonly property bool earthView: zoomIndex === AstroView.ZOOMS.length - 1
    onShowInsetChanged: canvas.requestPaint()
    onShowRotationChanged: canvas.requestPaint()
    onEarthViewChanged: canvas.requestPaint()
    onShowOrbitsChanged: canvas.requestPaint()
    onShowNamesChanged: canvas.requestPaint()
    onShowMonthRingChanged: canvas.requestPaint()

    // ---- Camera ----
    readonly property real startAzimuth: -60
    property real azimuth: startAzimuth
    property real elevation: AstroView.ELEVATION_DEFAULT
    property int zoomIndex: 0
    property real extent: AstroView.ZOOMS[zoomIndex].extent
    Behavior on extent { NumberAnimation { duration: 450; easing.type: Easing.InOutCubic } }
    onAzimuthChanged: canvas.requestPaint()
    onElevationChanged: canvas.requestPaint()
    onExtentChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    NumberAnimation {
      id: turnAnimation
      target: sky
      property: "azimuth"
      duration: 400
      easing.type: Easing.InOutCubic
    }
    NumberAnimation {
      id: tiltAnimation
      target: sky
      property: "elevation"
      duration: 400
      easing.type: Easing.InOutCubic
    }

    function turnBy(degrees) {
      touched()
      var from = turnAnimation.running ? turnAnimation.to : azimuth
      turnAnimation.stop()
      turnAnimation.from = azimuth
      turnAnimation.to = from + degrees
      turnAnimation.start()
    }
    function tiltBy(degrees) {
      touched()
      var from = tiltAnimation.running ? tiltAnimation.to : elevation
      tiltAnimation.stop()
      tiltAnimation.from = elevation
      tiltAnimation.to = AstroView.clampElevation(from + degrees)
      tiltAnimation.start()
    }
    function zoomBy(step) {
      touched()
      zoomIndex = Math.max(0, Math.min(AstroView.ZOOMS.length - 1, zoomIndex + step))
    }
    function reset() {
      zoomIndex = 0
      resetCamera()
    }
    // The crosshair: the start view's angles, keeping the zoom step.
    function resetCamera() {
      touched()
      tiltAnimation.stop()
      tiltAnimation.from = elevation
      tiltAnimation.to = AstroView.ELEVATION_DEFAULT
      tiltAnimation.start()
      turnAnimation.stop()
      turnAnimation.from = azimuth
      turnAnimation.to = azimuth + AstroView.shortestTurn(azimuth, startAzimuth)
      turnAnimation.start()
    }
    // Ends running camera moves at once (the screenshot harness).
    function finishMoves() {
      if (turnAnimation.running) turnAnimation.complete()
      if (tiltAnimation.running) tiltAnimation.complete()
    }

    // ---- The bodies, once a minute ----
    // ---- The shown instant: now (to the minute), or pinned by the
    //      timeline, playback or a travel ("Go to date") ----
    readonly property double liveMs: Math.floor(panel.nowMs / 60000) * 60000
    property bool timePinned: false
    property double pinnedMs: 0
    readonly property double minuteMs: timePinned ? pinnedMs : liveMs
    readonly property bool approximate: Astro.isApproximate(minuteMs)
    // The scrubber's days count from now, or from the pinned moment when
    // that lies more than its year away (AstroClock.js).
    readonly property double scrubBase: timePinned && Math.abs(pinnedMs - liveMs) > AstroClock.RANGE_DAYS * AstroClock.DAY_MS
      ? pinnedMs : liveMs
    readonly property int scrubIndex: AstroClock.nearestIndex(scrubBase, minuteMs)
    readonly property bool nowInRange: scrubBase === liveMs

    function showAt(ms) {
      pinnedMs = ms
      timePinned = true
    }
    function stepDays(days) {
      stopTravel()
      playing = false
      var next = minuteMs + days * AstroClock.DAY_MS
      var limit = AstroClock.RANGE_DAYS * AstroClock.DAY_MS
      showAt(Math.max(scrubBase - limit, Math.min(scrubBase + limit, next)))
    }
    function scrubTo(index) {
      stopTravel()
      showAt(scrubBase + (index - AstroClock.NOW_INDEX) * AstroClock.DAY_MS)
    }
    function backToNow() {
      playing = false
      if (!timePinned) return
      travelTo(liveMs, true)
    }

    // Playing: a day, a week or a month a second (AstroClock.timing).
    property bool playing: false
    property int speedIndex: 0
    function togglePlay() {
      stopTravel()
      if (!playing && !timePinned) showAt(liveMs)
      playing = !playing
    }
    Timer {
      id: playTimer
      interval: AstroClock.timing(sky.speedIndex).delay
      repeat: true
      running: sky.playing && sky.panel.opened && sky.panel.currentTab === "astro"
      onTriggered: {
        var t = AstroClock.timing(sky.speedIndex)
        var next = sky.minuteMs + t.step * AstroClock.DAY_MS
        var end = sky.scrubBase + AstroClock.RANGE_DAYS * AstroClock.DAY_MS
        if (next >= end) {
          sky.showAt(end)
          sky.playing = false
        } else {
          sky.showAt(next)
        }
      }
    }

    // A travel: from the shown moment to another in AstroDate.TRAVEL_MS,
    // eased, every frame at its own moment (a time lapse).
    property bool traveling: false
    readonly property bool moving: playing || traveling || rotating
    property double travelFrom: 0
    property double travelTarget: 0
    property double travelStart: 0
    property bool travelToNow: false
    function travelTo(ms, toNow) {
      playing = false
      travelFrom = minuteMs
      travelTarget = ms
      travelToNow = !!toNow
      travelStart = Date.now()
      showAt(travelFrom)
      traveling = true
    }
    function stopTravel() {
      traveling = false
    }
    // Ends a running travel at once (the screenshot harness).
    function finishTravel() {
      if (!traveling) return
      traveling = false
      if (travelToNow) timePinned = false
      else showAt(travelTarget)
    }
    Timer {
      interval: 33
      repeat: true
      running: sky.traveling && sky.panel.opened
      onTriggered: {
        var t = (Date.now() - sky.travelStart) / AstroDate.TRAVEL_MS
        if (t >= 1) {
          sky.finishTravel()
          return
        }
        sky.showAt(AstroDate.travelAt(sky.travelFrom, sky.travelTarget, t))
      }
    }

    // The shown moment as text: "Sunday, 20 July 1969 · 9:17 PM", the
    // computer's local time.
    function momentText(ms) {
      var offset = Model.localOffsetSeconds(ms)
      return panel.dateFor(ms, offset, "long") + " · " + panel.clockFor(ms, offset, false)
    }
    readonly property double dayMs: Math.floor(minuteMs / 86400000) * 86400000
    readonly property int year: new Date(minuteMs).getUTCFullYear()
    // True positions (au) and drawn ones (model units), by planet.
    readonly property var bodies: {
      var at = Astro.positions(minuteMs)
      var out = {}
      for (var i = 0; i < Astro.PLANETS.length; i++) {
        var key = Astro.PLANETS[i]
        out[key] = { au: at[key], model: AstroView.modelPoint(at[key]) }
      }
      return out
    }
    // The orbits change with the day at most.
    readonly property var orbits: {
      var out = {}
      for (var i = 0; i < Astro.PLANETS.length; i++) {
        var key = Astro.PLANETS[i]
        out[key] = Astro.orbit(key, dayMs, 144).map(function(p) { return AstroView.modelPoint(p) })
      }
      return out
    }
    readonly property var marks: Astro.seasonMarks(year)

    // ---- Earth and Moon, and how the bodies turn (AstroRotation.js) ----
    // The land for the Earth globe, prepared once per process (Globe.js).
    property var landRings: null
    property FileView landFile: FileView {
      path: String(Qt.resolvedUrl("data/globe-land.json")).replace(/^file:\/\//, "")
      printErrors: false
      onLoaded: {
        try { sky.landRings = Globe.prepareLand(JSON.parse(text())) } catch (e) { console.warn("more-time: globe land data unreadable:", e) }
      }
    }
    onLandRingsChanged: canvas.requestPaint()
    // The Moon from Earth's centre (au), the Sun's direction from Earth, the
    // Earth's and the Moon's body frames, the planets' poles and meridians:
    // once a minute (the Earth turns a quarter of a degree in it).
    readonly property var earthMoon: {
      var ms = minuteMs
      var g = AstroEvents.moonGeocentric(ms)
      var e = Astro.position("earth", ms)
      return {
        moon: g, sun: AstroRotation.norm({ x: -e.x, y: -e.y, z: -e.z }),
        earthMatrix: AstroRotation.bodyMatrix("earth", ms),
        moonNear: AstroRotation.surfaceVector("moon", 0, 0, ms),
        subsolar: AstroRotation.subPoint("earth", { x: -e.x, y: -e.y, z: -e.z }, ms)
      }
    }
    // The Moon's path around Earth, half a month back and forward, as unit
    // directions times the distance in mean distances (refreshed hourly).
    readonly property double hourMs: Math.floor(minuteMs / 3600000) * 3600000
    readonly property var moonPath: {
      var out = []
      for (var i = 0; i < 96; i++) {
        var g = AstroEvents.moonGeocentric(hourMs + (i / 96 - 0.5) * 27.32 * 86400000)
        var r = Math.sqrt(g.x * g.x + g.y * g.y + g.z * g.z) || 1
        var k = g.distanceKm / 384400 / r
        out.push({ x: g.x * k, y: g.y * k, z: g.z * k })
      }
      return out
    }
    // ---- More bodies (AstroBodies.js), each group its own switch ----
    readonly property bool showBelts: panel.displaySetting("astroBelts", true)
    readonly property bool showDwarfs: panel.displaySetting("astroDwarfs", true)
    readonly property bool showComets: panel.displaySetting("astroComets", false)
    readonly property bool showMoons: panel.displaySetting("astroMoons", false)
    readonly property bool showSpacecraft: panel.displaySetting("astroSpacecraft", false)
    onShowBeltsChanged: canvas.requestPaint()
    onShowDwarfsChanged: canvas.requestPaint()
    onShowCometsChanged: canvas.requestPaint()
    onShowMoonsChanged: canvas.requestPaint()
    onShowSpacecraftChanged: canvas.requestPaint()
    // The belts' sample points move little in a day: once per shown day.
    readonly property var belts: {
      if (!showBelts) return null
      var ms = dayMs
      return { asteroids: AstroBodies.beltPoints("asteroids", ms, 400).map(function(p) { return AstroView.modelPoint(p) }),
        kuiper: AstroBodies.beltPoints("kuiper", ms, 600).map(function(p) { return AstroView.modelPoint(p) }) }
    }
    // The small bodies' fixed orbits (model units), once.
    readonly property var smallOrbits: {
      var out = {}
      for (var i = 0; i < AstroBodies.SMALL_BODY_KEYS.length; i++) {
        var key = AstroBodies.SMALL_BODY_KEYS[i]
        out[key] = AstroBodies.orbit(key, key === "halley" ? 256 : 160).map(function(p) { return AstroView.modelPoint(p) })
      }
      return out
    }
    // Positions of the dwarf planets, Halley, the large moons and the
    // spacecraft at the shown moment.
    readonly property var extras: {
      var ms = minuteMs
      var out = {}
      var small = AstroBodies.SMALL_BODY_KEYS
      for (var i = 0; i < small.length; i++) {
        var au = AstroBodies.position(small[i], ms)
        out[small[i]] = { au: au, model: AstroView.modelPoint(au) }
      }
      for (var m = 0; m < AstroBodies.MOON_KEYS.length; m++) out[AstroBodies.MOON_KEYS[m]] = { rel: AstroBodies.moonPosition(AstroBodies.MOON_KEYS[m], ms) }
      for (var c = 0; c < AstroBodies.SPACECRAFT_KEYS.length; c++) out[AstroBodies.SPACECRAFT_KEYS[c]] = { au: AstroBodies.spacecraftPosition(AstroBodies.SPACECRAFT_KEYS[c], ms) }
      return out
    }
    onBeltsChanged: canvas.requestPaint()
    onExtrasChanged: canvas.requestPaint()
    // ---- The ISS (option astroIss; orbit data from Panel.issStore) ----
    readonly property bool showIss: panel.displaySetting("astroIss", false) === true
    readonly property var issElements: panel.issStore.elements
    // Its moment: the shown one, or (live) now to the second, refreshed
    // every five seconds while it can be seen: it moves 4° a minute.
    property double issNowMs: Date.now()
    readonly property double issMs: timePinned ? minuteMs : issNowMs
    readonly property bool issSeen: showIss && !!issElements && (earthView || showInset)
    Timer {
      interval: 5000
      repeat: true
      running: sky.issSeen && !sky.timePinned && sky.panel.motionAllowed && sky.panel.currentTab === "astro"
      onTriggered: sky.issNowMs = Date.now()
    }
    // How far the shown moment is from the data's epoch (days): beyond 7
    // days the place is only a guess, so the station is hidden while the
    // timeline shows another time, and marked ≈ when live.
    readonly property real issAgeDays: issElements ? Math.abs(issMs - issElements.epochMs) / 86400000 : 0
    readonly property bool issHidden: !issElements || (timePinned && issAgeDays > 7)
    readonly property var iss: {
      if (!issSeen || issHidden) return null
      var el = issElements
      var state = AstroIss.init(el)
      var at = AstroIss.stationAt(el, issMs, state)
      if (!at) return null
      return { at: at, track: AstroIss.groundTrack(el, issMs, 96, state),
        dir: AstroRotation.surfaceVector("earth", at.lat, at.lon, issMs), approximate: issAgeDays > 7 }
    }
    onIssChanged: canvas.requestPaint()

    // The planet whose moons show close up: the one under the pointer or
    // the one clicked (Jupiter, Saturn).
    readonly property string moonHost: !showMoons ? "" : (hover && hover.key === "jupiter" || hover && hover.key === "saturn" ? hover.key
      : (pinned === "jupiter" || pinned === "saturn" ? pinned : ""))
    onMoonHostChanged: canvas.requestPaint()

    readonly property var spins: {
      var ms = minuteMs
      var out = {}
      var keys = ["sun"].concat(Astro.PLANETS)
      for (var i = 0; i < keys.length; i++) {
        var key = keys[i]
        out[key] = { pole: AstroRotation.poleVector(key, ms), meridian: AstroRotation.surfaceVector(key, 0, 0, ms),
          east: AstroRotation.surfaceVector(key, 0, 90, ms) }
      }
      out.rings = AstroRotation.ringPlaneNormal("saturn", ms)
      return out
    }
    onEarthMoonChanged: canvas.requestPaint()
    onBodiesChanged: canvas.requestPaint()
    onOrbitsChanged: canvas.requestPaint()

    // The tints of the planets, restrained, softened towards the text
    // colour like the other accents.
    readonly property var tints: ({
      mercury: "#a39e96", venus: "#d6c39a", earth: "#6f9bd4", mars: "#c87f62",
      jupiter: "#c8a984", saturn: "#d2c194", uranus: "#93c4c8", neptune: "#6f86c8"
    })
    function softTint(hex) {
      var c = Sky.hexRgb(hex)
      var ink = canvas.ink
      var mixed = Sky.mixRgb(c, [ink.r, ink.g, ink.b], 0.22)
      return Qt.rgba(mixed[0], mixed[1], mixed[2], 1)
    }

    // ---- What the pointer rests on ----
    property var pointer: null
    property var hover: null
    // A body clicked keeps its label while the pointer is elsewhere.
    property string pinned: ""
    // Where the Earth–Moon inset was drawn (a click there zooms in), or null.
    property var insetRect: null
    property var hits: []
    // What painting costs (the screenshot harness measures a turn).
    property var paintStats: ({ count: 0, total: 0, max: 0 })

    function infoText(key) {
      var earth = bodies.earth.au
      var lines = [panel.i18n("astroBody_" + key)]
      function number(value, decimals) {
        return panel.latinDigits(Number(value).toLocaleString(panel.interfaceLocale, "f", decimals))
      }
      function distanceLine(textKey, au) {
        return panel.i18n(textKey, { au: number(au, au < 10 ? 2 : 1),
          minutes: number(au * Astro.LIGHT_MINUTES_PER_AU, au * Astro.LIGHT_MINUTES_PER_AU < 100 ? 1 : 0) })
      }
      // One turn and the axis' tilt; the giants' and the Sun's turns are
      // approximate (radio periods, differential rotation).
      function turnLine() {
        var hours = Math.abs(AstroRotation.rotationPeriodHours(key))
        var approx = key === "sun" || key === "saturn" || key === "uranus" || key === "neptune" ? "≈ " : ""
        var turn = hours < 72 ? panel.i18n("astroTurnHours", { hours: approx + number(hours, 1) })
          : panel.i18n("astroTurnDays", { days: approx + number(hours / 24, 1) })
        return turn + " · " + panel.i18n("astroAxialTilt", { degrees: number(AstroRotation.obliquityOf(key, minuteMs), 1) })
      }
      if (key === "moon") {
        var info = AstroEvents.moonInfo(minuteMs)
        lines.push(panel.i18n("moonPhase_" + info.key) + " · " + panel.i18n("astroMoonLit", { percent: Math.round(info.illuminated * 100) }))
        lines.push(panel.i18n("astroMoonDistance", { km: number(Math.round(info.distanceKm), 0),
          seconds: number(info.distanceKm / 299792.458, 2) }))
        lines.push(panel.i18n("astroMoonAge", { days: number(info.ageDays, 1) }))
        return lines.join("\n")
      }
      if (key === "sun") {
        lines.push(distanceLine("astroFromEarth", earth.r))
        lines.push(turnLine())
        return lines.join("\n")
      }
      var extra = extras[key]
      if (extra && AstroBodies.MOONS[key]) {
        var mm = AstroBodies.MOONS[key]
        lines.push(panel.i18n("astroFromPlanet", { km: number(mm.aKm, 0), planet: panel.i18n("astroBody_" + mm.planet) }))
        lines.push(panel.i18n("astroOrbitDays", { days: number(AstroBodies.moonPeriodDays(key), 2) }))
        return lines.join("\n")
      }
      if (key === "iss" && sky.iss) {
        var at = sky.iss.at
        var latText = panel.i18n(at.lat >= 0 ? "astroLatNorth" : "astroLatSouth", { deg: number(Math.abs(at.lat), 0) })
        var lonText = panel.i18n(at.lon >= 0 ? "astroLonEast" : "astroLonWest", { deg: number(Math.abs(at.lon), 0) })
        lines.push((sky.iss.approximate ? "≈ " : "") + panel.i18n("astroIssInfo", { place: latText + " " + lonText,
          km: number(at.altitude, 0), minutes: number(at.periodMinutes, 0) }))
        return lines.join("\n")
      }
      if (key === "jwst") {
        var j = extra.au
        lines.push(panel.i18n("astroFromEarthKm", { km: number(Math.round(Astro.distance(j, earth) * 149597870.7), 0) }))
        return lines.join("\n")
      }
      if (extra && AstroBodies.SPACECRAFT[key]) {
        lines.push(distanceLine("astroFromSun", extra.au.r))
        lines.push(panel.i18n("astroSpeedAway", { speed: number(extra.au.speed, 2) }))
        return lines.join("\n")
      }
      if (extra && AstroBodies.SMALL_BODIES[key]) {
        lines.push(distanceLine("astroFromSun", extra.au.r))
        lines.push(distanceLine("astroFromEarth", Astro.distance(extra.au, earth)))
        var sd = AstroBodies.periodDays(key)
        lines.push(sd < 1000 ? panel.i18n("astroOrbitDays", { days: number(sd, 0) })
          : panel.i18n("astroOrbitYears", { years: number(sd / 365.25, 1) }))
        return lines.join("\n")
      }
      var p = bodies[key].au
      lines.push(distanceLine("astroFromSun", p.r))
      if (key !== "earth") lines.push(distanceLine("astroFromEarth", Astro.distance(p, earth)))
      var days = Astro.periodDays(key)
      lines.push(days < 1000 ? panel.i18n("astroOrbitDays", { days: number(days, 0) })
        : panel.i18n("astroOrbitYears", { years: number(days / 365.25, 1) }))
      lines.push(turnLine())
      return lines.join("\n")
    }

    function updateHover() {
      var p = pointer
      if (!p || mouse.pressed) {
        hover = pinnedHover()
        return
      }
      var hit = AstroView.hitTest(hits, p.x, p.y, Style.space(6))
      hover = hit ? { key: hit.key, text: infoText(hit.key), x: p.x, y: p.y } : pinnedHover()
    }
    function pinnedHover() {
      if (pinned === "") return null
      for (var i = 0; i < hits.length; i++)
        if (hits[i].key === pinned) return { text: infoText(pinned), x: hits[i].x, y: hits[i].y }
      return null
    }

    // ---- Turning by itself (the globe's options under astro* keys) ----
    property bool rotating: false
    readonly property bool canRotate: autoRotate && panel.motionAllowed && panel.currentTab === "astro"
      && visible && !mouse.pressed && !playing && !traveling
    onCanRotateChanged: if (!canRotate) rotating = false
    readonly property int rotateDelaySeconds: Number(panel.generalSetting("motionDelay", "10")) || 10
    readonly property int rotateTurnMinutes: Number(panel.generalSetting("motionSpeed", "4")) || 4

    function touched() {
      rotating = false
      if (idleTimer.running) idleTimer.restart()
    }

    Timer {
      id: idleTimer
      interval: sky.rotateDelaySeconds * 1000
      running: sky.canRotate && !sky.rotating
      onTriggered: sky.rotating = true
    }
    // Frames a second as set (General → Motion, 15 unless changed); the turn
    // advances by the time elapsed.
    readonly property int rotateFps: Number(panel.generalSetting("motionFps", "15")) || 15
    Timer {
      id: rotateTimer
      interval: Math.round(1000 / Math.max(1, sky.rotateFps))
      repeat: true
      running: sky.canRotate && sky.rotating
      property double last: 0
      onRunningChanged: last = Date.now()
      onTriggered: {
        var now = Date.now()
        var elapsed = Math.min(500, now - last)
        last = now
        if (!turnAnimation.running) sky.azimuth += elapsed * 360 / (sky.rotateTurnMinutes * 60000)
      }
    }

    Canvas {
      id: canvas
      anchors.fill: parent
      property color ink: sky.panel.foreground
      property color accent: Color.accent
      onInkChanged: requestPaint()
      onAccentChanged: requestPaint()

      function rgba(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha)
      }

      // A closed or open polyline of projected points, split into the part
      // behind the Sun's depth and the part in front.
      function strokeSplit(ctx, points, closed, style, backAlpha, frontAlpha, width) {
        var n = points.length
        var edges = closed ? n : n - 1
        var halves = [[], []]
        for (var i = 0; i < edges; i++) {
          var a = points[i], b = points[(i + 1) % n]
          halves[(a.depth + b.depth) / 2 >= 0 ? 1 : 0].push(a, b)
        }
        ctx.lineWidth = width
        for (var h = 0; h < 2; h++) {
          var list = halves[h]
          if (!list.length) continue
          ctx.strokeStyle = rgba(style, h === 1 ? frontAlpha : backAlpha)
          ctx.beginPath()
          for (var k = 0; k < list.length; k += 2) {
            if (k === 0 || list[k] !== list[k - 1]) ctx.moveTo(list[k].x, list[k].y)
            ctx.lineTo(list[k + 1].x, list[k + 1].y)
          }
          ctx.stroke()
        }
      }

      // The Sun in warm gold (Panel.sunColor), so it reads on light and
      // dark themes; the accent stays for the hand of the year and
      // selection.
      function paintSun(ctx, x, y, r) {
        var gold = sky.panel.sunColor
        var glow = ctx.createRadialGradient(x, y, r * 0.6, x, y, r * 2.6)
        glow.addColorStop(0, rgba(gold, 0.30))
        glow.addColorStop(1, rgba(gold, 0))
        ctx.fillStyle = glow
        ctx.beginPath()
        ctx.arc(x, y, r * 2.6, 0, Math.PI * 2)
        ctx.fill()
        ctx.strokeStyle = rgba(gold, 0.6)
        ctx.lineWidth = 1.2
        ctx.lineCap = "round"
        ctx.beginPath()
        for (var i = 0; i < 12; i++) {
          var t = i * Math.PI / 6
          ctx.moveTo(x + Math.cos(t) * r * 1.25, y + Math.sin(t) * r * 1.25)
          ctx.lineTo(x + Math.cos(t) * r * 1.7, y + Math.sin(t) * r * 1.7)
        }
        ctx.stroke()
        var disc = ctx.createRadialGradient(x - r * 0.3, y - r * 0.3, r * 0.1, x, y, r)
        disc.addColorStop(0, Qt.lighter(gold, 1.25))
        disc.addColorStop(1, gold)
        ctx.fillStyle = disc
        ctx.beginPath()
        ctx.arc(x, y, r, 0, Math.PI * 2)
        ctx.fill()
      }

      // A planet as a sphere lit from the Sun's side of the picture.
      function paintPlanet(ctx, x, y, r, tint, sunX, sunY) {
        var a = Math.atan2(sunY - y, sunX - x)
        var lx = x + Math.cos(a) * r * 0.45
        var ly = y + Math.sin(a) * r * 0.45
        var shade = ctx.createRadialGradient(lx, ly, r * 0.1, x, y, r * 1.05)
        shade.addColorStop(0, Qt.lighter(tint, 1.25))
        shade.addColorStop(0.55, tint)
        shade.addColorStop(1, Qt.darker(tint, 2.6))
        ctx.fillStyle = shade
        ctx.beginPath()
        ctx.arc(x, y, r, 0, Math.PI * 2)
        ctx.fill()
        ctx.strokeStyle = rgba(ink, 0.25)
        ctx.lineWidth = 0.8
        ctx.stroke()
      }

      function dot(a, b) { return a.x * b.x + a.y * b.y + a.z * b.z }

      // The bodies' turning: latitude bands round the pole and the prime
      // meridian, on the visible side only (AstroRotation's pole and
      // meridian). spin: { pole, meridian, east } (ecliptic unit vectors).
      function paintSpin(ctx, x, y, r, spin, axes, many) {
        if (!spin || !spin.pole || r < 3.5) return
        function point(v) {
          return { x: x + dot(v, axes.right) * r, y: y - dot(v, axes.up) * r, front: dot(v, axes.toward) > 0.02 }
        }
        function onSphere(lat, lon) {
          var a = lat * Math.PI / 180, o = lon * Math.PI / 180
          var c = Math.cos(a)
          return { x: Math.sin(a) * spin.pole.x + c * (Math.cos(o) * spin.meridian.x + Math.sin(o) * spin.east.x),
            y: Math.sin(a) * spin.pole.y + c * (Math.cos(o) * spin.meridian.y + Math.sin(o) * spin.east.y),
            z: Math.sin(a) * spin.pole.z + c * (Math.cos(o) * spin.meridian.z + Math.sin(o) * spin.east.z) }
        }
        function stroke(points) {
          ctx.beginPath()
          var open = false
          for (var i = 0; i < points.length; i++) {
            var p = points[i]
            if (!p.front) { open = false; continue }
            if (open) ctx.lineTo(p.x, p.y)
            else ctx.moveTo(p.x, p.y)
            open = true
          }
          ctx.stroke()
        }
        var bands = many ? [-40, -20, 0, 20, 40] : [-30, 0, 30]
        ctx.lineWidth = 0.7
        ctx.strokeStyle = rgba(ink, 0.22)
        for (var b = 0; b < bands.length; b++) {
          var ring = []
          for (var t = 0; t <= 360; t += 15) ring.push(point(onSphere(bands[b], t)))
          stroke(ring)
        }
        // The prime meridian, turning with W.
        var meridian = []
        for (var m = -70; m <= 70; m += 10) meridian.push(point(onSphere(m, 0)))
        ctx.lineWidth = 1.1
        ctx.strokeStyle = rgba(ink, 0.5)
        stroke(meridian)
      }

      // Half of Saturn's rings (B and A, the Cassini division between):
      // the far half before the planet, the near half after it.
      function paintRings(ctx, x, y, r, normal, axes, far) {
        if (!normal) return
        var u = AstroRotation.norm(AstroRotation.cross(normal, axes.toward))
        var w = AstroRotation.cross(normal, u)
        // A point's depth is sin t · (w·toward): the far half has it below 0.
        var start = (dot(w, axes.toward) >= 0) === far ? Math.PI : 0
        var radii = AstroRotation.RING_RADII
        var bands = [[radii.bInner, radii.bOuter, 0.55], [radii.aInner, radii.aOuter, 0.42]]
        var tint = sky.softTint(sky.tints.saturn)
        for (var b = 0; b < bands.length; b++) {
          ctx.beginPath()
          for (var i = 0; i <= 24; i++) {
            var t = start + Math.PI * i / 24
            var vx = dot(u, axes.right) * Math.cos(t) + dot(w, axes.right) * Math.sin(t)
            var vy = dot(u, axes.up) * Math.cos(t) + dot(w, axes.up) * Math.sin(t)
            if (i === 0) ctx.moveTo(x + vx * r * bands[b][1], y - vy * r * bands[b][1])
            else ctx.lineTo(x + vx * r * bands[b][1], y - vy * r * bands[b][1])
          }
          for (var j = 24; j >= 0; j--) {
            var t2 = start + Math.PI * j / 24
            var ux = dot(u, axes.right) * Math.cos(t2) + dot(w, axes.right) * Math.sin(t2)
            var uy = dot(u, axes.up) * Math.cos(t2) + dot(w, axes.up) * Math.sin(t2)
            ctx.lineTo(x + ux * r * bands[b][0], y - uy * r * bands[b][0])
          }
          ctx.closePath()
          ctx.fillStyle = rgba(tint, bands[b][2])
          ctx.fill()
        }
      }

      // A dwarf planet (a small grey sphere) or Halley (a nucleus and its
      // tail, pointing away from the Sun, longer the nearer it is).
      function paintSmallBody(ctx, body, cam, scale, sun) {
        if (body.key === "halley") {
          var au = sky.extras.halley.au
          var tail = AstroBodies.tailDirection(au)
          var len = Math.min(60, 24 / Math.max(0.3, au.r))
          var tv = AstroView.view(tail, cam)
          var tl = Math.sqrt(tv.x * tv.x + tv.y * tv.y) || 1
          var ex = body.x + tv.x / tl * len, ey = body.y - tv.y / tl * len
          var grad = ctx.createLinearGradient(body.x, body.y, ex, ey)
          grad.addColorStop(0, Qt.rgba(0.75, 0.85, 1, 0.55))
          grad.addColorStop(1, Qt.rgba(0.75, 0.85, 1, 0))
          ctx.strokeStyle = grad
          ctx.lineWidth = 2.2
          ctx.lineCap = "round"
          ctx.beginPath()
          ctx.moveTo(body.x, body.y)
          ctx.lineTo(ex, ey)
          ctx.stroke()
          ctx.fillStyle = Qt.rgba(0.85, 0.92, 1, 1)
          ctx.beginPath()
          ctx.arc(body.x, body.y, body.r * 0.8, 0, Math.PI * 2)
          ctx.fill()
          return
        }
        paintPlanet(ctx, body.x, body.y, body.r, sky.softTint("#a8a49c"), sun.x, sun.y)
      }

      // The Earth as a globe seen from the camera: land from
      // data/globe-land.json, the night in three steps round the antisolar
      // point, all through Globe.js' view functions (y up, flipped here).
      function paintEarthGlobe(ctx, x, y, R, axes) {
        var em = sky.earthMoon
        var vm = AstroRotation.bodyViewMatrix(em.earthMatrix, axes)
        function trace(xy) {
          ctx.moveTo(x + xy[0], y - xy[1])
          for (var i = 2; i < xy.length; i += 2) ctx.lineTo(x + xy[i], y - xy[i + 1])
          ctx.closePath()
        }
        var sea = sky.softTint(sky.tints.earth)
        ctx.beginPath()
        ctx.arc(x, y, R, 0, Math.PI * 2)
        ctx.fillStyle = rgba(sea, 0.55)
        ctx.fill()
        if (sky.landRings) {
          ctx.beginPath()
          for (var l = 0; l < sky.landRings.length; l++) {
            // Islands smaller than a pixel at this size are left out.
            var landRing = sky.landRings[l]
            // While time runs or the view turns, only what spans a few pixels.
            if (landRing.sinMax >= 0 && landRing.sinMax * R < (sky.moving ? 4 : 1)) continue
            var polys = Globe.frontPolygonsView(landRing, vm, R)
            for (var p = 0; p < polys.length; p++) trace(polys[p])
          }
          ctx.fillStyle = Qt.rgba(0.80, 0.82, 0.74, 0.95)
          ctx.fill()
        }
        var sub = em.subsolar
        var antiLon = sub.lon > 0 ? sub.lon - 180 : sub.lon + 180
        var layers = Sky.twilightLayers({ night: true }, sky.panel.rgbOf(Color.popups.background))
        ctx.fillRule = Qt.OddEvenFill
        for (var k = 0; k < layers.length; k++) {
          var layer = layers[k]
          var caps = Globe.capPolygonView(-sub.lat, antiLon, 90 + layer.high, vm, R)
          if (layer.low !== null) caps = caps.concat(Globe.capPolygonView(-sub.lat, antiLon, 90 + layer.low, vm, R))
          if (!caps.length) continue
          ctx.beginPath()
          for (var c = 0; c < caps.length; c++) trace(caps[c])
          ctx.fillStyle = Qt.rgba(0, 0, 0.08, Math.min(0.75, layer.fill.a * 1.6))
          ctx.fill()
        }
        ctx.beginPath()
        ctx.arc(x, y, R, 0, Math.PI * 2)
        ctx.strokeStyle = rgba(ink, 0.35)
        ctx.lineWidth = 1
        ctx.stroke()
      }

      // The Moon lit from the Sun as the camera sees it (Moon.paintMoon), its
      // near side (the mark) always facing Earth.
      function paintMoonBody(ctx, x, y, r, axes) {
        var em = sky.earthMoon
        var s = em.sun
        var angle = Math.atan2(-dot(s, axes.up), dot(s, axes.right))
        var lit = (1 + dot(s, axes.toward)) / 2
        Moon.paintMoon(ctx, x, y, r, angle, lit, "238,236,226",
          Moon.rgbText(Sky.nightFill(sky.panel.rgbOf(Color.popups.background))), Moon.rgbText(ink))
        var near = em.moonNear
        if (near && r >= 4 && dot(near, axes.toward) > 0.1) {
          ctx.fillStyle = Qt.rgba(0.35, 0.36, 0.40, 0.45)
          ctx.beginPath()
          ctx.arc(x + dot(near, axes.right) * r * 0.55, y - dot(near, axes.up) * r * 0.55, r * 0.24, 0, Math.PI * 2)
          ctx.fill()
        }
      }

      // Earth and Moon close up around (cx, cy) in a square of `size`: the
      // Moon's orbit in its own scale (0.42 of the size at its mean
      // distance, the true shape and tilt), the Sun's direction at the edge.
      // Returns the hit list.
      function paintEarthMoon(ctx, cx, cy, size, cam, axes, small) {
        var em = sky.earthMoon
        var R = size * (small ? 0.13 : 0.11)
        var orbit = size * 0.42
        var path = sky.moonPath.map(function(p) {
          var v = AstroView.view(p, cam)
          return { x: cx + v.x * orbit, y: cy - v.y * orbit, depth: v.depth }
        })
        var g = em.moon
        var gr = Math.sqrt(g.x * g.x + g.y * g.y + g.z * g.z) || 1
        var k = g.distanceKm / 384400 / gr
        var mv = AstroView.view({ x: g.x * k, y: g.y * k, z: g.z * k }, cam)
        var moon = { key: "moon", x: cx + mv.x * orbit, y: cy - mv.y * orbit, depth: mv.depth, r: Math.max(3, R * 0.36) }
        var earth = { key: "earth", x: cx, y: cy, depth: 0, r: R }
        strokeSplit(ctx, path, true, ink, 0.18, 0.4, 1)
        // The Sun's direction: a gold arrow at the edge.
        var sx = dot(em.sun, axes.right), sy = dot(em.sun, axes.up)
        var sl = Math.sqrt(sx * sx + sy * sy)
        if (sl > 0.05) {
          var ax = cx + sx / sl * size * 0.47, ay = cy - sy / sl * size * 0.47
          var dir = Math.atan2(-sy, sx)
          ctx.fillStyle = sky.panel.sunColor
          ctx.beginPath()
          ctx.moveTo(ax + Math.cos(dir) * 6, ay + Math.sin(dir) * 6)
          ctx.lineTo(ax + Math.cos(dir + 2.5) * 6, ay + Math.sin(dir + 2.5) * 6)
          ctx.lineTo(ax + Math.cos(dir - 2.5) * 6, ay + Math.sin(dir - 2.5) * 6)
          ctx.closePath()
          ctx.fill()
        }
        var order = AstroView.depthSorted([moon, earth])
        for (var i = 0; i < order.length; i++) {
          if (order[i].key === "earth") paintEarthGlobe(ctx, cx, cy, R, axes)
          else paintMoonBody(ctx, moon.x, moon.y, moon.r, axes)
        }
        // The ISS: its ground track for one orbit and the place under it on
        // the globe, the station above it (its height enlarged).
        var hits = [earth, moon]
        if (sky.iss) {
          var vmI = AstroRotation.bodyViewMatrix(sky.earthMoon.earthMatrix, axes)
          var track = sky.iss.track
          ctx.strokeStyle = rgba(accent, 0.45)
          ctx.lineWidth = 1
          ctx.beginPath()
          var penDown = false
          for (var ti = 0; ti < track.length; ti++) {
            var tp = Globe.projectView(track[ti].lat, track[ti].lon, vmI, R)
            if (!tp.visible) { penDown = false; continue }
            if (penDown) ctx.lineTo(cx + tp.x, cy - tp.y)
            else ctx.moveTo(cx + tp.x, cy - tp.y)
            penDown = true
          }
          ctx.stroke()
          var subP = Globe.projectView(sky.iss.at.lat, sky.iss.at.lon, vmI, R)
          if (subP.visible) {
            ctx.fillStyle = accent
            ctx.beginPath()
            ctx.arc(cx + subP.x, cy - subP.y, small ? 1.5 : 2.2, 0, Math.PI * 2)
            ctx.fill()
          }
          var lift = R * 1.3
          var d = sky.iss.dir
          var ix = cx + dot(d, axes.right) * lift, iy = cy - dot(d, axes.up) * lift
          var hiddenBehind = dot(d, axes.toward) < 0 && Math.hypot(ix - cx, iy - cy) < R
          if (!hiddenBehind) {
            ctx.strokeStyle = rgba(accent, 0.5)
            ctx.beginPath()
            if (subP.visible) {
              ctx.moveTo(cx + subP.x, cy - subP.y)
              ctx.lineTo(ix, iy)
              ctx.stroke()
            }
            ctx.fillStyle = accent
            ctx.beginPath()
            ctx.moveTo(ix, iy - 3.5)
            ctx.lineTo(ix + 3.5, iy)
            ctx.lineTo(ix, iy + 3.5)
            ctx.lineTo(ix - 3.5, iy)
            ctx.closePath()
            ctx.fill()
            hits.push({ key: "iss", x: ix, y: iy, depth: 1, r: 4 })
          }
        }
        // JWST near L2, four times the Moon's distance away from the Sun:
        // beyond this view, so a small mark at its edge, opposite the Sun.
        if (sky.showSpacecraft && !small && sl > 0.05) {
          var jx = cx - sx / sl * size * 0.47, jy = cy + sy / sl * size * 0.47
          ctx.fillStyle = rgba(ink, 0.8)
          ctx.beginPath()
          ctx.rect(jx - 2.5, jy - 2.5, 5, 5)
          ctx.fill()
          return hits.concat([{ key: "jwst", x: jx, y: jy, depth: 0, r: 4 }])
        }
        return hits
      }

      // When the view is not now: the shown moment, bottom left.
      function paintShownLabel(ctx) {
        if (!sky.timePinned) return
        var text = sky.momentText(sky.minuteMs) + (sky.approximate ? " · " + sky.panel.i18n("astroApproximate") : "")
        ctx.font = sky.panel.canvasFont(Style.font.caption, true, false)
        var tw = ctx.measureText(text).width + 10
        var th = Style.font.caption + 8
        ctx.fillStyle = Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 0.85)
        ctx.fillRect(4, height - th - 4, tw, th)
        ctx.fillStyle = accent
        ctx.textAlign = "left"
        ctx.textBaseline = "middle"
        ctx.fillText(text, 9, height - th / 2 - 4)
      }

      onPaint: {
        var started = Date.now()
        var ctx = getContext("2d")
        ctx.reset()
        var w = width, h = height
        if (w <= 0 || h <= 0) return
        var cam = AstroView.camera(sky.azimuth, sky.elevation)
        var scale = AstroView.scaleFor(sky.extent, w, h, sky.elevation)
        var cx = w / 2, cy = h / 2
        function proj(p) { return AstroView.project(p, cam, scale, cx, cy) }
        var fontPx = Style.font.caption
        var labelFont = sky.panel.canvasFont(fontPx, false, false)
        var smallFont = sky.panel.canvasFont(Math.max(9, fontPx - 2), false, false)
        var keys = Astro.PLANETS
        var sun = proj({ x: 0, y: 0, z: 0 })
        var axes = AstroRotation.cameraAxes(cam)

        // The Earth–Moon zoom: the two close up, nothing else.
        if (sky.earthView) {
          var size = Math.min(w, h)
          var pair = paintEarthMoon(ctx, cx, cy, size, cam, axes, false)
          sky.hits = pair
          ctx.font = labelFont
          ctx.textAlign = "left"
          ctx.textBaseline = "middle"
          for (var pi = 0; pi < pair.length; pi++) {
            if (!sky.showNames) break
            var it = pair[pi]
            var label = sky.panel.i18n("astroBody_" + it.key)
            var lw = ctx.measureText(label).width + 6
            var lx = it.x + it.r + 4, ly = it.y - (fontPx + 4) / 2
            ctx.fillStyle = Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 0.72)
            ctx.fillRect(lx, ly, lw, fontPx + 4)
            ctx.fillStyle = it.key === sky.pinned ? accent : rgba(ink, 0.9)
            ctx.fillText(label, lx + 3, ly + (fontPx + 4) / 2 + 0.5)
          }
          paintShownLabel(ctx)
          var spentEarth = Date.now() - started
          var se = sky.paintStats
          sky.paintStats = { count: se.count + 1, total: se.total + spentEarth, max: Math.max(se.max, spentEarth) }
          sky.insetRect = null
          sky.updateHover()
          return
        }

        // The month ring just outside Earth's orbit, and the vernal point.
        var ringRadius = AstroView.modelDistance(1.0) * 1.075
        var ring = []
        for (var a = 0; a < 360; a += 3) {
          var t = a * Math.PI / 180
          ring.push(proj({ x: Math.cos(t) * ringRadius, y: Math.sin(t) * ringRadius, z: 0 }))
        }
        function ringPoint(lon, k) {
          var t = lon * Math.PI / 180
          return proj({ x: Math.cos(t) * ringRadius * k, y: Math.sin(t) * ringRadius * k, z: 0 })
        }

        // Back halves first: orbits, the ring.
        var orbitPoints = {}
        if (sky.showOrbits) {
          for (var o = 0; o < keys.length; o++) {
            orbitPoints[keys[o]] = sky.orbits[keys[o]].map(proj)
            strokeSplit(ctx, orbitPoints[keys[o]], true, ink, 0.13, 0.32, 1)
          }
        }
        if (sky.showMonthRing) {
          strokeSplit(ctx, ring, true, ink, 0.18, 0.4, 1)
          // Month starts: short ticks; equinoxes and solstices: longer, in
          // the accent; the month's initial in its middle.
          var months = sky.marks.months
          ctx.lineWidth = 1
          for (var m = 0; m < months.length; m++) {
            var inner = ringPoint(months[m].lon, 0.975), outer = ringPoint(months[m].lon, 1.025)
            ctx.strokeStyle = rgba(ink, inner.depth >= 0 ? 0.45 : 0.22)
            ctx.beginPath()
            ctx.moveTo(inner.x, inner.y)
            ctx.lineTo(outer.x, outer.y)
            ctx.stroke()
            var next = months[(m + 1) % 12].lon
            var mid = months[m].lon + (((next - months[m].lon) % 360) + 360) % 360 / 2
            // Initials only where the ring is large enough to hold them.
            if (ringRadius * scale < Style.space(80)) continue
            var at = ringPoint(mid, 1.085)
            ctx.font = smallFont
            ctx.textAlign = "center"
            ctx.textBaseline = "middle"
            ctx.fillStyle = rgba(ink, at.depth >= 0 ? 0.62 : 0.32)
            ctx.fillText(sky.panel.interfaceLocale.standaloneMonthName(months[m].month, Locale.NarrowFormat), at.x, at.y)
          }
          var seasons = sky.marks.seasons
          ctx.lineWidth = 1.6
          for (var s = 0; s < seasons.length; s++) {
            var s0 = ringPoint(seasons[s].lon, 0.95), s1 = ringPoint(seasons[s].lon, 1.05)
            ctx.strokeStyle = rgba(accent, s0.depth >= 0 ? 0.8 : 0.4)
            ctx.beginPath()
            ctx.moveTo(s0.x, s0.y)
            ctx.lineTo(s1.x, s1.y)
            ctx.stroke()
          }
          // The vernal point: a dashed line out from the ring towards +x.
          var v0 = ringPoint(0, 1.13), v1 = ringPoint(0, 1.32)
          ctx.strokeStyle = rgba(ink, 0.45)
          ctx.lineWidth = 1
          ctx.setLineDash([3, 3])
          ctx.beginPath()
          ctx.moveTo(v0.x, v0.y)
          ctx.lineTo(v1.x, v1.y)
          ctx.stroke()
          ctx.setLineDash([])
          // An arrowhead and γ, the vernal point's old sign.
          var va = Math.atan2(v1.y - v0.y, v1.x - v0.x)
          ctx.fillStyle = rgba(ink, 0.55)
          ctx.beginPath()
          ctx.moveTo(v1.x, v1.y)
          ctx.lineTo(v1.x - Math.cos(va - 0.45) * 6, v1.y - Math.sin(va - 0.45) * 6)
          ctx.lineTo(v1.x - Math.cos(va + 0.45) * 6, v1.y - Math.sin(va + 0.45) * 6)
          ctx.closePath()
          ctx.fill()
          ctx.font = labelFont
          ctx.textAlign = "center"
          ctx.textBaseline = "middle"
          ctx.fillText("\u03b3", v1.x + Math.cos(va) * 9, v1.y + Math.sin(va) * 9)
          // Earth as the hand of the year: from the Sun out to the ring.
          var hand = ringPoint(sky.bodies.earth.au.lon, 1.05)
          ctx.strokeStyle = rgba(accent, 0.5)
          ctx.lineWidth = 1.2
          ctx.beginPath()
          ctx.moveTo(sun.x, sun.y)
          ctx.lineTo(hand.x, hand.y)
          ctx.stroke()
        }

        // The belts as faint points, the small bodies' orbits dashed.
        if (sky.belts) {
          // One path for all points, the view's arithmetic inline (a
          // thousand points a frame while the view turns).
          var bands = [sky.belts.asteroids, sky.belts.kuiper]
          var ca = cam.ca, sa = cam.sa, ce = cam.ce, se = cam.se
          ctx.beginPath()
          for (var bb = 0; bb < bands.length; bb++) {
            var list = bands[bb]
            for (var bp = 0; bp < list.length; bp++) {
              var pt = list[bp]
              var px = cx + (pt.x * ca + pt.y * sa) * scale
              var py = cy - ((-pt.x * sa + pt.y * ca) * se + pt.z * ce) * scale
              if (px < 0 || px > w || py < 0 || py > h) continue
              ctx.rect(px - 0.6, py - 0.6, 1.2, 1.2)
            }
          }
          ctx.fillStyle = rgba(ink, 0.32)
          ctx.fill()
        }
        var smallKeys = (sky.showDwarfs ? ["ceres", "pluto", "eris"] : []).concat(sky.showComets ? ["halley"] : [])
        if (sky.showOrbits && smallKeys.length) {
          ctx.setLineDash([2, 3])
          for (var so = 0; so < smallKeys.length; so++)
            strokeSplit(ctx, sky.smallOrbits[smallKeys[so]].map(proj), true, ink, 0.1, 0.22, 0.8)
          ctx.setLineDash([])
        }

        // The bodies, far first; the Sun at depth 0.
        var drawn = [{ key: "sun", x: sun.x, y: sun.y, depth: 0, r: AstroView.bodyRadius(Astro.RADIUS_KM.sun) }]
        for (var sk = 0; sk < smallKeys.length; sk++) {
          var sq = proj(sky.extras[smallKeys[sk]].model)
          if (sq.x < -20 || sq.x > w + 20 || sq.y < -20 || sq.y > h + 20) continue
          drawn.push({ key: smallKeys[sk], x: sq.x, y: sq.y, depth: sq.depth, r: smallKeys[sk] === "halley" ? 2.5 : 3, small: true })
        }
        for (var b = 0; b < keys.length; b++) {
          var q = proj(sky.bodies[keys[b]].model)
          drawn.push({ key: keys[b], x: q.x, y: q.y, depth: q.depth, r: AstroView.bodyRadius(Astro.RADIUS_KM[keys[b]]) })
        }
        var order = AstroView.depthSorted(drawn)
        var spinning = sky.showRotation
        for (var d = 0; d < order.length; d++) {
          var body = order[d]
          if (body.key === "sun") {
            paintSun(ctx, body.x, body.y, body.r)
            continue
          }
          if (body.small) {
            paintSmallBody(ctx, body, cam, scale, sun)
            continue
          }
          if (spinning && body.key === "saturn") paintRings(ctx, body.x, body.y, body.r, sky.spins.rings, axes, true)
          paintPlanet(ctx, body.x, body.y, body.r, sky.softTint(sky.tints[body.key]), sun.x, sun.y)
          if (spinning) paintSpin(ctx, body.x, body.y, body.r, sky.spins[body.key], axes, body.key === "jupiter" || body.key === "saturn")
          if (spinning && body.key === "saturn") paintRings(ctx, body.x, body.y, body.r, sky.spins.rings, axes, false)
          // In the inner system, a tiny Moon beside Earth, on its side.
          if (body.key === "earth" && sky.zoomIndex === 1) {
            var gm = sky.earthMoon.moon
            var gv = AstroView.view(gm, cam)
            var gl = Math.sqrt(gv.x * gv.x + gv.y * gv.y) || 1
            var tinyX = body.x + gv.x / gl * (body.r + 6), tinyY = body.y - gv.y / gl * (body.r + 6)
            ctx.fillStyle = Qt.rgba(0.85, 0.85, 0.82, 1)
            ctx.beginPath()
            ctx.arc(tinyX, tinyY, 2.2, 0, Math.PI * 2)
            ctx.fill()
            drawn.push({ key: "moon", x: tinyX, y: tinyY, depth: body.depth + gv.depth * 0.01, r: 2.2 })
          }
        }
        // The large moons of the planet under the pointer or clicked, close
        // up: their circles (radius by distance, 40 px for Callisto) in
        // their true plane, the moons where they stand.
        if (sky.moonHost !== "") {
          var host = drawn.filter(function(item) { return item.key === sky.moonHost })[0]
          if (host) {
            var keysM = AstroBodies.MOON_KEYS.filter(function(k) { return AstroBodies.MOONS[k].planet === sky.moonHost })
            for (var mk = 0; mk < keysM.length; mk++) {
              var mkey = keysM[mk]
              var spec = AstroBodies.MOONS[mkey]
              var ringPx = host.r + 6 + spec.aKm / 1882700 * 40
              var normal = AstroBodies.moonOrbitNormal(mkey)
              var ua = AstroRotation.norm(AstroRotation.cross(normal, axes.toward))
              var wa = AstroRotation.cross(normal, ua)
              ctx.strokeStyle = rgba(ink, 0.25)
              ctx.lineWidth = 0.8
              ctx.beginPath()
              for (var ti = 0; ti <= 48; ti++) {
                var tt = 2 * Math.PI * ti / 48
                var ox = (dot(ua, axes.right) * Math.cos(tt) + dot(wa, axes.right) * Math.sin(tt)) * ringPx
                var oy = (dot(ua, axes.up) * Math.cos(tt) + dot(wa, axes.up) * Math.sin(tt)) * ringPx
                if (ti === 0) ctx.moveTo(host.x + ox, host.y - oy)
                else ctx.lineTo(host.x + ox, host.y - oy)
              }
              ctx.stroke()
              var rel = sky.extras[mkey].rel
              var rr = Math.sqrt(rel.x * rel.x + rel.y * rel.y + rel.z * rel.z) || 1
              var dir = { x: rel.x / rr, y: rel.y / rr, z: rel.z / rr }
              var mx = host.x + dot(dir, axes.right) * ringPx, my = host.y - dot(dir, axes.up) * ringPx
              var behind = dot(dir, axes.toward) < 0 && Math.hypot(mx - host.x, my - host.y) < host.r
              if (behind) continue
              ctx.fillStyle = Qt.rgba(0.88, 0.86, 0.80, 1)
              ctx.beginPath()
              ctx.arc(mx, my, 2.4, 0, Math.PI * 2)
              ctx.fill()
              drawn.push({ key: mkey, x: mx, y: my, depth: host.depth + 0.001, r: 2.4 })
            }
          }
        }
        // The spacecraft far beyond the view: arrows at its edge in their
        // direction from the Sun, with the distance.
        if (sky.showSpacecraft) {
          var craft = ["voyager1", "voyager2", "newhorizons"]
          ctx.font = smallFont
          for (var ci = 0; ci < craft.length; ci++) {
            var ca = sky.extras[craft[ci]].au
            var cv = AstroView.view(ca, cam)
            var cl = Math.sqrt(cv.x * cv.x + cv.y * cv.y)
            if (cl < 1e-6) continue
            var ux = cv.x / cl, uy = -cv.y / cl
            // Where the ray from the Sun leaves the canvas, a little inside.
            var tx = ux > 0 ? (w - 14 - sun.x) / ux : (ux < 0 ? (14 - sun.x) / ux : Infinity)
            var ty = uy > 0 ? (h - 14 - sun.y) / uy : (uy < 0 ? (14 - sun.y) / uy : Infinity)
            var tEdge = Math.max(0, Math.min(tx, ty))
            var ex = sun.x + ux * tEdge, ey = sun.y + uy * tEdge
            var ang = Math.atan2(uy, ux)
            ctx.fillStyle = rgba(ink, 0.75)
            ctx.beginPath()
            ctx.moveTo(ex + Math.cos(ang) * 7, ey + Math.sin(ang) * 7)
            ctx.lineTo(ex + Math.cos(ang + 2.6) * 6, ey + Math.sin(ang + 2.6) * 6)
            ctx.lineTo(ex + Math.cos(ang - 2.6) * 6, ey + Math.sin(ang - 2.6) * 6)
            ctx.closePath()
            ctx.fill()
            var clabel = sky.panel.i18n("astroBody_" + craft[ci]) + " · " + Math.round(ca.r) + " au"
            var cw = ctx.measureText(clabel).width
            ctx.textBaseline = "middle"
            ctx.textAlign = "left"
            var lx2 = Math.max(2, Math.min(w - cw - 2, ex - Math.cos(ang) * 10 - (ux > 0 ? cw : 0)))
            var ly2 = Math.max(8, Math.min(h - 8, ey - Math.sin(ang) * 10))
            ctx.fillStyle = rgba(ink, 0.7)
            ctx.fillText(clabel, lx2, ly2)
            drawn.push({ key: craft[ci], x: ex, y: ey, depth: 0, r: 7 })
          }
        }
        sky.hits = drawn

        // Names: beside each body where there is room; the hovered or
        // pinned one first.
        if (sky.showNames) {
          var taken = drawn.map(function(item) { return { x: item.x - item.r, y: item.y - item.r, w: item.r * 2, h: item.r * 2 } })
          function free(rect) {
            for (var i = 0; i < taken.length; i++) {
              var o = taken[i]
              if (rect.x < o.x + o.w && rect.x + rect.w > o.x && rect.y < o.y + o.h && rect.y + rect.h > o.y) return false
            }
            return true
          }
          var labelled = order.slice().reverse()
          ctx.font = labelFont
          for (var l = 0; l < labelled.length; l++) {
            var item = labelled[l]
            var name = sky.panel.i18n("astroBody_" + item.key)
            var tw = ctx.measureText(name).width + 6
            var th = fontPx + 4
            var gap = item.r + 3
            var spots = [
              { x: item.x + gap, y: item.y - th / 2 }, { x: item.x - gap - tw, y: item.y - th / 2 },
              { x: item.x - tw / 2, y: item.y - gap - th }, { x: item.x - tw / 2, y: item.y + gap }
            ]
            for (var sp = 0; sp < spots.length; sp++) {
              var rect = { x: spots[sp].x, y: spots[sp].y, w: tw, h: th }
              if (rect.x < 0 || rect.x + tw > w || rect.y < 0 || rect.y + th > h || !free(rect)) continue
              taken.push(rect)
              ctx.fillStyle = Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 0.72)
              ctx.fillRect(rect.x, rect.y, tw, th)
              ctx.fillStyle = item.key === sky.pinned ? accent : rgba(ink, 0.9)
              ctx.textAlign = "left"
              ctx.textBaseline = "middle"
              ctx.fillText(name, rect.x + 3, rect.y + th / 2 + 0.5)
              break
            }
          }
        }

        // The Earth–Moon inset in the top left corner, joined to Earth.
        sky.insetRect = null
        if (sky.showInset) {
          var insetSize = Math.max(Style.space(110), Math.min(Style.space(180), Math.min(w, h) * 0.3))
          var ix = Style.space(4), iy = Style.space(4)
          var earthHit = drawn.filter(function(item) { return item.key === "earth" })[0]
          if (earthHit) {
            ctx.strokeStyle = rgba(ink, 0.3)
            ctx.lineWidth = 1
            ctx.setLineDash([2, 3])
            ctx.beginPath()
            ctx.moveTo(ix + insetSize, iy + insetSize)
            ctx.lineTo(earthHit.x, earthHit.y)
            ctx.stroke()
            ctx.setLineDash([])
          }
          ctx.save()
          ctx.fillStyle = Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 0.92)
          ctx.fillRect(ix, iy, insetSize, insetSize)
          ctx.strokeStyle = rgba(ink, 0.35)
          ctx.strokeRect(ix + 0.5, iy + 0.5, insetSize - 1, insetSize - 1)
          ctx.beginPath()
          ctx.rect(ix, iy, insetSize, insetSize)
          ctx.clip()
          var insetHits = paintEarthMoon(ctx, ix + insetSize / 2, iy + insetSize / 2, insetSize, cam, axes, true)
          ctx.restore()
          // The inset's Moon answers the pointer too.
          sky.hits = sky.hits.concat(insetHits.filter(function(item) { return item.key === "moon" || item.key === "iss" }))
          sky.insetRect = { x: ix, y: iy, w: insetSize, h: insetSize }
        }

        paintShownLabel(ctx)
        var spent = Date.now() - started
        var st = sky.paintStats
        sky.paintStats = { count: st.count + 1, total: st.total + spent, max: Math.max(st.max, spent) }
        sky.updateHover()
      }
    }

    // A drag turns (sideways) and tilts (up and down); a click on a body
    // keeps its label; the sideways wheel turns, Ctrl + wheel zooms.
    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      property real pressX: 0
      property real pressY: 0
      property real pressAzimuth: 0
      property real pressElevation: 0
      property bool dragged: false

      onPressed: function(event) {
        sky.touched()
        turnAnimation.stop()
        tiltAnimation.stop()
        pressX = event.x
        pressY = event.y
        pressAzimuth = sky.azimuth
        pressElevation = sky.elevation
        dragged = false
      }
      onPositionChanged: function(event) {
        if (pressed) {
          if (Math.abs(event.x - pressX) + Math.abs(event.y - pressY) > Style.space(4)) dragged = true
          if (dragged) {
            sky.azimuth = pressAzimuth - (event.x - pressX) * 0.4
            sky.elevation = AstroView.clampElevation(pressElevation + (event.y - pressY) * 0.3)
          }
          sky.hover = null
          return
        }
        sky.pointer = { x: event.x, y: event.y }
        sky.updateHover()
      }
      onExited: {
        sky.pointer = null
        sky.updateHover()
      }
      onClicked: function(event) {
        if (dragged) return
        var inset = sky.insetRect
        if (inset && event.x >= inset.x && event.x < inset.x + inset.w && event.y >= inset.y && event.y < inset.y + inset.h) {
          sky.zoomBy(AstroView.ZOOMS.length - 1 - sky.zoomIndex)
          return
        }
        var hit = AstroView.hitTest(sky.hits, event.x, event.y, Style.space(6))
        sky.pinned = hit && hit.key !== sky.pinned ? hit.key : ""
        canvas.requestPaint()
      }

      // The sideways wheel (or Shift + wheel) turns, Ctrl + wheel zooms;
      // the plain wheel scrolls the tab (Panel.wheelTakenBelow).
      function wantsWheel(wheel) {
        return (wheel.modifiers & Qt.ControlModifier) !== 0 || sky.panel.wheelIsSideways(wheel)
      }
      function noticeWheel(wheel) { sky.touched() }
      Component.onCompleted: sky.panel.registerWheelArea(this)
      Component.onDestruction: sky.panel.unregisterWheelArea(this)
      property real zoomWheel: 0
      onWheel: function(event) {
        if (event.modifiers & Qt.ControlModifier) {
          zoomWheel += event.angleDelta.y
          if (Math.abs(zoomWheel) >= 120) {
            sky.zoomBy(zoomWheel > 0 ? 1 : -1)
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
        sky.touched()
        turnAnimation.stop()
        sky.azimuth -= sideways / 120 * 10
      }
    }

    TimeMapHoverLabel {
      panel: sky.panel
      hover: sky.hover
      boundsWidth: sky.width
    }

    // The crosshair (start view, same zoom), the previous and the next zoom
    // step.
    TimeZoomControls {
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.margins: Style.space(8)
      panel: sky.panel
      canZoomOut: sky.zoomIndex > 0
      canZoomIn: sky.zoomIndex < AstroView.ZOOMS.length - 1
      onRecenter: sky.resetCamera()
      onZoomOut: sky.zoomBy(-1)
      onZoomIn: sky.zoomBy(1)
    }
  }

  // ---- The info line (AstroEvents.js), its searches once per shown day ----
  readonly property double infoDay: Math.floor(sky.minuteMs / 86400000)
  property var info: null
  onInfoDayChanged: infoTimer.restart()
  onShowInfoChanged: if (showInfo) infoTimer.restart()
  Component.onCompleted: computeInfo()
  Timer {
    id: infoTimer
    interval: 250
    onTriggered: view.computeInfo()
  }
  function computeInfo() {
    if (!showInfo) return
    var ms = sky.minuteMs
    var moon = AstroEvents.moonInfo(ms)
    var season = AstroEvents.nextSeasonEvent(ms)
    var seen = AstroEvents.visibility(ms)
    var opposition = null
    for (var i = 0; i < AstroEvents.OUTER_PLANETS.length; i++) {
      var key = AstroEvents.OUTER_PLANETS[i]
      var at = AstroEvents.nextOpposition(key, ms)
      if (at && (!opposition || at < opposition.utcMs)) opposition = { key: key, utcMs: at }
    }
    info = { moon: moon, season: season, seen: seen, opposition: opposition }
  }
  function shortMoment(ms) {
    var offset = Model.localOffsetSeconds(ms)
    return panel.dateFor(ms, offset, "short") + " " + panel.clockFor(ms, offset, false)
  }
  readonly property string infoText: {
    if (!info) return ""
    var lines = []
    if (sky.timePinned)
      lines.push(panel.i18n("astroShown", { date: sky.momentText(sky.minuteMs) }) + (sky.approximate ? " · " + panel.i18n("astroApproximate") : ""))
    var phase = Moon.moonPhaseFraction(sky.minuteMs)
    var moonLine = panel.i18n("moonPhase_" + AstroEvents.phaseKey(phase)) + " · "
      + panel.i18n("astroMoonLit", { percent: Math.round((1 - Math.cos(2 * Math.PI * phase)) / 2 * 100) })
    if (info.moon.nextNew && info.moon.nextFull)
      moonLine += " · " + panel.i18n("astroMoonNext", { newMoon: shortMoment(info.moon.nextNew), fullMoon: shortMoment(info.moon.nextFull) })
    lines.push(moonLine)
    var yearLine = []
    if (info.season) yearLine.push(panel.i18n("astroSeason_" + info.season.key) + " " + shortMoment(info.season.utcMs))
    if (info.opposition) yearLine.push(panel.i18n("astroOpposition", { planet: panel.i18n("astroBody_" + info.opposition.key),
      date: shortMoment(info.opposition.utcMs) }))
    if (yearLine.length) lines.push(yearLine.join(" · "))
    var evening = [], morning = []
    for (var key in info.seen) {
      if (info.seen[key] === "evening") evening.push(panel.i18n("astroBody_" + key))
      else if (info.seen[key] === "morning") morning.push(panel.i18n("astroBody_" + key))
    }
    var skyLine = []
    if (evening.length) skyLine.push(panel.i18n("astroEvening", { planets: evening.join(", ") }))
    if (morning.length) skyLine.push(panel.i18n("astroMorning", { planets: morning.join(", ") }))
    if (skyLine.length) lines.push(skyLine.join(" · "))
    if (sky.showIss && sky.issElements && sky.issHidden)
      lines.push(panel.i18n("astroIssHidden", { date: shortMoment(sky.issElements.epochMs) }))
    return lines.join("\n")
  }

  // ---- The chips under the model: what it shows (the same options as the
  //      Astro card, for the surface shown) ----
  TimeChipBar {
    id: astroChips
    width: parent.width
    panel: view.panel
    readonly property var keys: ({ orbits: "astroOrbits", names: "astroNames", monthRing: "astroMonthRing",
      rotation: "astroRotation", belts: "astroBelts", dwarfs: "astroDwarfs", comets: "astroComets", moons: "astroMoons",
      spacecraft: "astroSpacecraft", iss: "astroIss" })
    readonly property var defaults: ({ orbits: true, names: true, monthRing: true, rotation: true, belts: true, dwarfs: true,
      comets: false, moons: false, spacecraft: false, iss: false })
    function on(id) { return view.panel.displaySetting(keys[id], defaults[id]) === true }
    chips: [
      { id: "orbits", glyph: "\u{f0018}", label: "chip_orbits", on: on("orbits") },
      { id: "names", glyph: "\u{f0284}", label: "chip_names", on: on("names") },
      { id: "monthRing", glyph: "\u{f0e17}", label: "chip_monthRing", on: on("monthRing") },
      { id: "rotation", glyph: "\u{f0464}", label: "chip_rotation", on: on("rotation") },
      { id: "belts", glyph: "\u{f1978}", label: "chip_belts", on: on("belts"), divider: true },
      { id: "dwarfs", glyph: "\u{f09df}", label: "chip_dwarfs", on: on("dwarfs") },
      { id: "comets", glyph: "\u{f1741}", label: "chip_comets", on: on("comets") },
      { id: "moons", glyph: "\u{f0f62}", label: "chip_moons", on: on("moons") },
      { id: "spacecraft", glyph: "\u{f14de}", label: "chip_spacecraft", on: on("spacecraft") },
      { id: "iss", glyph: "\u{f1383}", label: "chip_iss", on: on("iss") }
    ]
    onToggled: function(id) { view.panel.setViewDisplaySetting(keys[id], !on(id)) }
  }

  // ---- The timeline: play, the year either side, speed, now; Go to date ----
  Column {
    id: timeline
    visible: view.showTimeline
    width: parent.width
    spacing: Style.space(6)

    Row {
      width: parent.width
      spacing: Style.space(8)

      TimeIconButton {
        id: playButton
        anchors.verticalCenter: parent.verticalCenter
        panel: view.panel
        glyph: sky.playing ? "\u{f03e4}" : "\u{f040a}"
        glyphSize: Style.font.body
        active: sky.playing
        onActivated: sky.togglePlay()
      }

      // The track: a year back to a year on, a mark at now, the handle at
      // the shown day; a click or a drag picks a day.
      Item {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - playButton.width - speeds.width - nowButton.width - 3 * parent.spacing
        height: Style.space(24)
        readonly property real fraction: sky.scrubIndex / AstroClock.LAST_INDEX
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
          height: Style.space(2)
          radius: height / 2
          color: view.panel.subtleText
        }
        Rectangle {
          visible: sky.nowInRange
          x: parent.width * AstroClock.NOW_INDEX / AstroClock.LAST_INDEX - width / 2
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(2)
          height: Style.space(12)
          color: Color.accent
        }
        Rectangle {
          x: parent.width * track.fraction - width / 2
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(10)
          height: width
          radius: width / 2
          color: sky.timePinned ? Color.accent : view.panel.foreground
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          function pick(x) {
            sky.playing = false
            sky.scrubTo(Math.round(Math.max(0, Math.min(1, x / width)) * AstroClock.LAST_INDEX))
          }
          onPressed: function(event) { pick(event.x) }
          onPositionChanged: function(event) { if (pressed) pick(event.x) }
        }
      }

      // The speeds: a day, a week, a month a second.
      Row {
        id: speeds
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(4)
        Repeater {
          model: AstroClock.SPEEDS
          Rectangle {
            required property var modelData
            required property int index
            width: speedText.implicitWidth + Style.space(10)
            height: Style.space(20)
            radius: Style.cornerRadius
            color: sky.speedIndex === index ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22) : "transparent"
            border.color: sky.speedIndex === index ? Color.accent : view.panel.subtleText
            border.width: Style.spacing.hairline
            Text {
              id: speedText
              textFormat: Text.PlainText
              anchors.centerIn: parent
              text: view.panel.i18n("astroSpeed_" + parent.modelData.key)
              color: sky.speedIndex === parent.index ? Color.accent : view.panel.mutedText
              font.family: view.panel.fontFamily
              font.pixelSize: Style.font.caption
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: sky.speedIndex = parent.index
            }
          }
        }
      }

      TimeButton {
        id: nowButton
        anchors.verticalCenter: parent.verticalCenter
        panel: view.panel
        label: view.panel.i18n("astroNow")
        onActivated: sky.backToNow()
      }
    }

    // Go to date: typed, read as it is typed, Enter travels there.
    Row {
      width: parent.width
      spacing: Style.space(10)

      TextField {
        id: dateField
        width: Math.min(Style.space(220), parent.width / 2)
        foreground: view.panel.foreground
        font.family: view.panel.fontFamily
        font.pixelSize: Style.font.bodySmall
        placeholderText: view.panel.i18n("astroGoToPlaceholder")
        readonly property var parsed: AstroDate.parseDate(text,
          AstroDate.dateOrder(view.panel.interfaceLocale.dateFormat(Locale.ShortFormat)))
        onAccepted: {
          if (sky.traveling) {
            sky.stopTravel()
            return
          }
          if (!parsed.ok) return
          sky.travelTo(parsed.ms, false)
          view.panel.restoreKeyFocus()
        }
        onActiveFocusChanged: {
          if (activeFocus) view.panel.activeTextField = dateField
          else if (view.panel.activeTextField === dateField) view.panel.activeTextField = null
        }
      }

      Text {
        textFormat: Text.PlainText
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - dateField.width - parent.spacing
        text: dateField.text === "" ? view.panel.i18n("astroGoToHint")
          : (dateField.parsed.ok ? "= " + sky.momentText(dateField.parsed.ms)
            + (Astro.isApproximate(dateField.parsed.ms) ? " · " + view.panel.i18n("astroApproximate") : "")
            : view.panel.i18n(dateField.parsed.reason === "range" ? "astroOutOfRange" : "astroNotADate"))
        color: dateField.text !== "" && !dateField.parsed.ok ? Color.urgent : view.panel.mutedText
        font.family: view.panel.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }
  }

  Text {
    id: infoLine
    textFormat: Text.PlainText
    visible: view.showInfo && text !== ""
    width: parent.width
    text: view.infoText
    color: view.panel.mutedText
    font.family: view.panel.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }
}
