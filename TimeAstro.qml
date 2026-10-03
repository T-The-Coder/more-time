import QtQuick
import qs.Commons
import "Astro.js" as Astro
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
    hint: view.panel.i18n("astroKeysHint")
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

  Item {
    id: sky
    objectName: "timeAstro"
    width: parent.width
    // Fills the visible height below it, like the globe: never taller than
    // wide, never lower than Style.space(240).
    readonly property real fitHeight: view.panel.viewportHeight - view.panel.tabContentTop - view.y - y - Style.space(16)
    height: Math.max(Style.space(240), Math.min(width * 0.9, fitHeight))

    // Pictures are never mirrored, whatever the language.
    LayoutMirroring.enabled: false
    LayoutMirroring.childrenInherit: true

    readonly property var panel: view.panel
    readonly property bool showOrbits: panel.displaySetting("astroOrbits", true)
    readonly property bool showNames: panel.displaySetting("astroNames", true)
    readonly property bool showMonthRing: panel.displaySetting("astroMonthRing", true)
    readonly property bool autoRotate: panel.displaySetting("astroAutoRotate", false)
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
      touched()
      zoomIndex = 0
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
    readonly property double minuteMs: Math.floor(panel.nowMs / 60000) * 60000
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
      if (key === "sun") {
        lines.push(distanceLine("astroFromEarth", earth.r))
        return lines.join("\n")
      }
      var p = bodies[key].au
      lines.push(distanceLine("astroFromSun", p.r))
      if (key !== "earth") lines.push(distanceLine("astroFromEarth", Astro.distance(p, earth)))
      var days = Astro.periodDays(key)
      lines.push(days < 1000 ? panel.i18n("astroOrbitDays", { days: number(days, 0) })
        : panel.i18n("astroOrbitYears", { years: number(days / 365.25, 1) }))
      return lines.join("\n")
    }

    function updateHover() {
      var p = pointer
      if (!p || mouse.pressed) {
        hover = pinnedHover()
        return
      }
      var hit = AstroView.hitTest(hits, p.x, p.y, Style.space(6))
      hover = hit ? { text: infoText(hit.key), x: p.x, y: p.y } : pinnedHover()
    }
    function pinnedHover() {
      if (pinned === "") return null
      for (var i = 0; i < hits.length; i++)
        if (hits[i].key === pinned) return { text: infoText(pinned), x: hits[i].x, y: hits[i].y }
      return null
    }

    // ---- Turning by itself (the globe's options under astro* keys) ----
    property bool rotating: false
    readonly property bool canRotate: autoRotate && panel.opened && panel.currentTab === "astro"
      && visible && !mouse.pressed
    onCanRotateChanged: if (!canRotate) rotating = false
    readonly property int rotateDelaySeconds: Number(panel.displaySetting("astroRotateDelay", "10")) || 10
    readonly property int rotateTurnMinutes: Number(panel.displaySetting("astroRotateSpeed", "4")) || 4

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
    // A frame for every pixel the outer edge moves, at most 30 a second.
    Timer {
      id: rotateTimer
      interval: Math.max(33, Math.min(250, (180 / Math.PI / Math.max(1, sky.width / 2))
        / (360 / (sky.rotateTurnMinutes * 60000))))
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

      function paintSun(ctx, x, y, r) {
        var glow = ctx.createRadialGradient(x, y, r * 0.6, x, y, r * 2.6)
        glow.addColorStop(0, rgba(accent, 0.30))
        glow.addColorStop(1, rgba(accent, 0))
        ctx.fillStyle = glow
        ctx.beginPath()
        ctx.arc(x, y, r * 2.6, 0, Math.PI * 2)
        ctx.fill()
        ctx.strokeStyle = rgba(accent, 0.45)
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
        disc.addColorStop(0, Qt.lighter(accent, 1.35))
        disc.addColorStop(1, accent)
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

        // The bodies, far first; the Sun at depth 0.
        var drawn = [{ key: "sun", x: sun.x, y: sun.y, depth: 0, r: AstroView.bodyRadius(Astro.RADIUS_KM.sun) }]
        for (var b = 0; b < keys.length; b++) {
          var q = proj(sky.bodies[keys[b]].model)
          drawn.push({ key: keys[b], x: q.x, y: q.y, depth: q.depth, r: AstroView.bodyRadius(Astro.RADIUS_KM[keys[b]]) })
        }
        var order = AstroView.depthSorted(drawn)
        for (var d = 0; d < order.length; d++) {
          var body = order[d]
          if (body.key === "sun") paintSun(ctx, body.x, body.y, body.r)
          else paintPlanet(ctx, body.x, body.y, body.r, sky.softTint(sky.tints[body.key]), sun.x, sun.y)
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
  }
}
