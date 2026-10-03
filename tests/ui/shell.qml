import QtQuick
import Quickshell
import "Time" as Time
import "Time/WorldMap.js" as WorldMap
import "Time/Moon.js" as Moon
import qs.Commons

// Screenshot run for tests/ui-shots.sh: the app view with sample items, every
// tab, the editors and every settings page, in English, German and Arabic
// (right to left). Pictures go to $MT_SHOTS.
ShellRoot {
  id: harness
  readonly property string shots: Quickshell.env("MT_SHOTS") || "/tmp"
  property int step: 0
  property var backdrop: null

  function shot(name) {
    var target = panel.contentRoot
    target.grabToImage(function(result) {
      result.saveToFile(harness.shots + "/" + name + ".png")
      console.log("SHOT", name)
    })
  }

  function general(key, value) { panel.displayOptionsStore.setGeneralSetting(key, value) }
  function display(key, value) { panel.displayOptionsStore.setSettingsDisplaySetting(key, value) }

  // The globe of the World tab, wherever the view tree holds it.
  function findGlobe(item) {
    if (!item) return null
    if (item.objectName === "timeGlobe") return item
    for (var i = 0; i < item.children.length; i++) {
      var found = findGlobe(item.children[i])
      if (found) return found
    }
    return null
  }
  function globe() { return findGlobe(panel.contentRoot) }
  function findNamed(item, name) {
    if (!item) return null
    if (item.objectName === name) return item
    for (var i = 0; i < item.children.length; i++) {
      var found = findNamed(item.children[i], name)
      if (found) return found
    }
    return null
  }
  function astro() { return findNamed(panel.contentRoot, "timeAstro") }
  // The app window's size, in pixels.
  // The app's size in pixels: an offscreen window keeps its first size,
  // so the content area takes the size inside the window's padding (the
  // page scrolls inside it, as in a window of that size).
  function appSize(w, h) {
    var content = panel.contentRoot
    var pad = Style.spacing.popupPadding
    content.anchors.fill = undefined
    content.width = w - 2 * pad
    content.height = h - 2 * pad
  }
  function appSizeReset() {
    var content = panel.contentRoot
    content.anchors.fill = content.parent
  }
  function globeSize(label) {
    var g = globe()
    console.log("GLOBE size", label, "content", Math.round(panel.contentRoot.width) + "x" + Math.round(panel.contentRoot.height),
      "viewport", Math.round(panel.viewportHeight), "diameter", Math.round(g.diameter), "page width", Math.round(g.width),
      "bottom", Math.round(g.mapToItem(panel.contentRoot, 0, g.diameter).y))
  }
  function findMap(item) {
    if (!item) return null
    if (item.aspect !== undefined && item.mapHeight !== undefined) return item
    for (var i = 0; i < item.children.length; i++) {
      var found = findMap(item.children[i])
      if (found) return found
    }
    return null
  }
  function mapSize(label) {
    var m = findMap(panel.contentRoot)
    console.log("MAP size", label, "viewport", Math.round(panel.viewportHeight), "map", Math.round(m.width) + "x" + Math.round(m.implicitHeight),
      "bottom", Math.round(m.mapToItem(panel.contentRoot, 0, m.implicitHeight).y))
  }

  readonly property var steps: [
    // Silent, so an alarm or timer that comes due during the run plays
    // nothing on the speakers.
    function() {
      panel.motionForced = true
      general("language", "en")
      general("alarmSound", "none")
      general("timerSound", "none")
      general("pomodoroSound", "none")
    },
    function() {
      var now = Date.now()
      panel.startTimer(25 * 60000, "Tea")
      panel.startTimer(90 * 1000, "")
      panel.addItem("stopwatches")
      panel.addItem("pomodoros")
      panel.toggleItem("pomodoros", panel.itemsStore.items.pomodoros[0].id)
      panel.addItem("alarms")
      panel.editingId = ""
    },
    function() { panel.lapStopwatch(panel.itemsStore.items.stopwatches[0].id) },
    function() { panel.lapStopwatch(panel.itemsStore.items.stopwatches[0].id); panel.activeTab = "world" },
    function() { panel.here.weatherPlace = { name: "Bobingen", lat: 48.27, lon: 10.83 } },
    function() { shot("01-world") },
    // A city as the current place, with the sun line per city.
    function() {
      display("worldSunrise", true)
      display("worldSunset", true)
      display("worldSunNext", true)
      panel.setCurrentPlace(2)
      console.log("PLACE", panel.currentPlace, panel.currentName, panel.currentOffset, "stored", panel.placeStore.current, "here", JSON.stringify(panel.here.place))
    },
    function() { shot("01a-world-city-current") },
    function() { panel.cyclePlace(1); panel.cyclePlace(1); panel.cyclePlace(1); console.log("PLACE cycled", panel.selectedCity) },
    function() { panel.setCurrentPlace(-1); display("worldSunrise", false); display("worldSunset", false) },
    // The globe: a city picked turns it there; the night side, the golden
    // and the blue hour on.
    function() { display("worldStyle", "globe"); display("worldNight", true); display("heroGoldenHour", true); display("heroBlueHour", true) },
    function() { panel.selectedCity = 0 },
    function() { var g = globe(); g.finishTurn(); console.log("GLOBE", g.centerLon, g.width, g.height) },
    function() { shot("01b-globe") },
    function() { panel.selectedCity = 2 },
    function() {
      var g = globe()
      g.finishTurn()
      g.centerLon = panel.cityList[2].lon
      console.log("GLOBE turned", g.centerLon, panel.cityList[2].name)
    },
    function() { shot("01c-globe-turned") },
    // Facing the evening terminator: both twilight bands; then the date line.
    function() { var g = globe(); g.centerLon = WorldMap.subsolarPoint(Date.now()).lon + 80 },
    function() { shot("01d-globe-twilight") },
    function() { var g = globe(); g.centerLon = 180; g.hover = { minutes: 720, x: g.width / 2, y: g.height / 2 } },
    function() { shot("01e-globe-dateline") },
    // Night side with and without the bands, globe facing the evening line.
    function() {
      display("worldMoon", true)
      var m = Moon.moonPosition(Date.now())
      console.log("MOON", m.lat.toFixed(1), m.lon.toFixed(1), Math.round(m.illuminated * 100) + " %", m.waxing ? "waxing" : "waning", panel.moonText(m))
      globe().hover = null
      globe().centerLon = WorldMap.subsolarPoint(Date.now()).lon + 80
    },
    function() { shot("01g-globe-bands") },
    function() { display("heroGoldenHour", false); display("heroBlueHour", false) },
    function() { shot("01h-globe-no-bands") },
    function() { display("worldStyle", "map"); panel.selectedCity = -1 },
    function() { shot("01i-map-no-bands") },
    function() { display("heroGoldenHour", true); display("heroBlueHour", true) },
    function() { shot("01j-map-bands") },
    // The Moon's tooltip on the globe, centred on it; the hero's clock face
    // set to Roman for all places.
    function() { display("worldStyle", "globe"); display("heroDial", "roman") },
    function() { var g = globe(); g.finishTurn(); g.centerLon = Moon.moonPosition(Date.now()).lon },
    function() {
      var g = globe()
      g.hover = g.moonHit ? { moon: g.moonHit.moon, x: g.moonHit.x, y: g.moonHit.y } : null
      console.log("MOON hit", JSON.stringify(g.moonHit ? { x: Math.round(g.moonHit.x), y: Math.round(g.moonHit.y) } : null))
    },
    function() { shot("01k-globe-moon") },
    // The Moon as seen from here (its phase in the sky), then from space again.
    function() { var g = globe(); g.hover = null; display("worldMoonStyle", "earth") },
    function() {
      var m = Moon.moonPosition(Date.now())
      console.log("MOON style earth", m.waxing ? "waxing" : "waning", "observer", globe().observerLat.toFixed(1),
        "lit", Moon.moonLitAngleFor("earth", m, 0, globe().observerLat) === 0 ? "right" : "left")
    },
    function() { shot("01l-globe-moon-earth") },
    function() { display("worldMoonStyle", "space") },
    // What a frame of turning costs: the globe turns by itself for a few
    // seconds with every layer on (bands, night steps, moon).
    function() {
      display("heroGoldenHour", true); display("heroBlueHour", true); display("globeAutoRotate", true)
      var g = globe()
      g.hover = null
      g.paintStats = { count: 0, total: 0, max: 0 }
      g.rotating = true
    },
    function() {},
    // Turning by itself: the cheap frames (fills at a lower resolution).
    function() { shot("01m-globe-turning") },
    function() {
      var st = globe().paintStats
      var per = function(v) { return ((v || 0) / Math.max(1, st.count)).toFixed(1) }
      console.log("GLOBE frames", st.count, "ms/frame", per(st.total), "max", st.max,
        "zones", per(st.zones), "land", per(st.land), "sky", per(st.sky), "places", per(st.places))
      display("globeAutoRotate", false); display("heroGoldenHour", false); display("heroBlueHour", false)
    },
    function() { globe().hover = null; display("worldStyle", "map"); display("worldMoon", false); display("heroDial", "place") },
    // Clock faces: one style per place, the chooser open under here; the
    // hero shows here's 24-hour face with the night shaded.
    function() {
      panel.citiesStore.setDial(0, "roman")
      panel.citiesStore.setDial(1, "twentyFour")
      panel.citiesStore.setDial(2, "dots")
      panel.citiesStore.setDial(3, "minimal")
      panel.setDialStyle(-1, "twentyFour")
      display("worldMap", false)
      display("worldSunrise", true)
      display("worldSunset", true)
      display("heroSunNext", true)
      panel.dialChooserOpen = true
      console.log("DIALS", panel.cityList.map(function(c) { return c.dial }).join(","), panel.placeStore.hereDial)
    },
    function() { shot("01f-world-dials") },
    // The chooser under another row: Tokyo (city 3), picked by the keys'
    // path (stepDialStyle), written to the cities file.
    function() {
      panel.dialChooserOpen = false
      panel.selectedCity = 2
      // The keys as typed: e opens under the selected row, ← picks.
      var e = { key: Qt.Key_E, text: "e", modifiers: 0, accepted: false }
      panel.handlePanelKey(e)
      var left = { key: Qt.Key_Left, text: "", modifiers: 0, accepted: false }
      panel.handlePanelKey(left)
      console.log("DIALS keys", e.accepted, left.accepted, panel.dialChooserOpen, panel.cityList[2].dial)
    },
    function() { shot("01f2-world-dial-tokyo") },
    function() {
      panel.citiesStore.file.reload()
      var stored = JSON.parse(panel.citiesStore.file.text())
      console.log("DIALS tokyo", panel.cityList[2].dial, "file", stored[2].name, stored[2].dial, "chooser", panel.dialChooserOpen)
    },
    function() { panel.dialChooserOpen = false; display("worldMap", true); display("worldSunrise", false); display("worldSunset", false); display("heroSunNext", false); panel.setDialStyle(-1, "classic") },
    function() { panel.activeTab = "alarms" },
    function() { shot("02-alarms") },
    function() { panel.editingId = panel.itemsStore.items.alarms[0].id },
    function() { shot("03-alarm-editor") },
    function() { panel.editingId = ""; panel.activeTab = "timers" },
    function() { shot("04-timers") },
    function() { panel.activeTab = "stopwatches" },
    function() { shot("05-stopwatches") },
    function() { panel.activeTab = "pomodoros" },
    function() { shot("06-pomodoros") },
    function() { panel.activeTab = "world"; panel.openCitySearch(); panel.citySearch.query = "ber" },
    // Online answers as the shared search gives them: one with a zone
    // (Open-Meteo), one without (Nominatim), which gets the nearest one.
    function() {
      // As if they answered "ber" (resultsQuery: the results are current).
      panel.citySearch.online.resultsQuery = "ber"
      panel.citySearch.online.results = [
        { name: "Bergamo", region: "Lombardy", country: "Italy", countryCode: "it", lat: 45.695, lon: 9.67, tz: "Europe/Rome" },
        { name: "Bernried", region: "Bavaria", country: "Germany", countryCode: "de", lat: 47.866, lon: 11.293, tz: "" }]
      console.log("SEARCH", JSON.stringify(panel.citySearch.results.map(function(c) { return c.name + " " + c.tz + (c.tzGuessed ? " ≈" : "") })))
    },
    function() { shot("07-city-search") },
    function() { panel.citySearch.switchSection(); panel.citySearch.step(1) },
    function() { shot("07b-city-search-saved") },
    function() { panel.searchOpen = false; panel.openSettings("general") },
    function() { shot("08-settings-general") },
    function() { panel.placesImport.run() },
    function() {},
    function() {
      console.log("IMPORT", JSON.stringify(panel.placesImport.status), JSON.stringify(panel.cityList.map(function(c) { return c.name + " " + c.tz })))
      panel.settingsItem.focusId = "importPlaces"
    },
    function() { shot("08a-settings-places-import") },
    function() { panel.settingsPage = "sounds" },
    function() { shot("08b-settings-sounds") },
    function() { general("chimeInterval", "custom"); general("hourChime", "24"); general("chimeTone", "bell") },
    function() { panel.settingsItem.focusId = "chimesMuted" },
    function() { shot("08c-settings-sounds-custom") },
    // Every tone once, as the test button plays it (dry run: logged only).
    function() { general("chimeTone", "wood"); panel.ringer.testChime("chimeTone") },
    function() { general("chimeTone", "chirp"); panel.ringer.testChime("chimeTone") },
    function() { general("chimeTone", "glass"); panel.ringer.testChime("chimeTone") },
    function() { general("chimeTone", "bell"); panel.ringer.testChime("chimeTone") },
    function() { general("chimeTone", "beep"); panel.ringer.testChime("chimeTone") },
    // The chime of a full hour, as the ringer plays it on the minute turn:
    // once (a second call in the same minute is nothing), never late.
    function() {
      general("chimeInterval", "quarter")
      var hour = new Date()
      hour.setHours(15, 0, 0, 0)
      var current = panel.ringer.read()
      current.chimedAt = 0
      console.log("CHIME first", panel.ringer.chime(current, hour.getTime() + 800))
      console.log("CHIME again", panel.ringer.chime(current, hour.getTime() + 5000))
      var late = panel.ringer.read()
      late.chimedAt = 0
      console.log("CHIME late", panel.ringer.chime(late, hour.getTime() + 60000 + 20000))
    },
    function() { panel.settingsOpen = false; general("chimesMuted", true) },
    function() {
      var muted = panel.ringer.read()
      muted.chimedAt = 0
      var quarter = new Date()
      quarter.setHours(15, 15, 0, 0)
      console.log("CHIME muted", panel.ringer.chime(muted, quarter.getTime() + 500), "STATUS", panel.statusSummary().slice(-1)[0])
      shot("08e-hero-chimes-muted")
    },
    function() { general("chimesMuted", false); panel.ringer.testChime("hourChime") },
    function() { panel.openSettings("display"); panel.settingsTargetSurface = "menubar" },
    function() { shot("09-settings-menubar") },
    function() { panel.settingsTargetSurface = "app" },
    function() { shot("10-settings-app") },
    function() { panel.openSettings("display"); panel.settingsTargetSurface = "app" },
    function() { display("worldStyle", "globe"); display("globeAutoRotate", true) },
    function() { panel.settingsItem.focusId = "heroDial" },
    function() { shot("10a-settings-clock-face") },
    function() { panel.settingsItem.focusId = "worldStyle"; panel.settingsItem.scrollBy(420) },
    function() { shot("10b-settings-world-globe") },
    function() { display("worldStyle", "map"); display("globeAutoRotate", false); panel.settingsItem.focusId = ""; panel.settingsOpen = false },
    function() { panel.openSettings("shortcuts") },
    function() { shot("11-settings-shortcuts") },
    function() { panel.settingsPage = "sources" },
    function() { shot("12-settings-sources") },
    function() { panel.settingsOpen = false; general("language", "de"); panel.activeTab = "alarms"; panel.editingId = panel.itemsStore.items.alarms[0].id },
    function() { shot("13-alarm-editor-de") },
    function() { panel.editingId = ""; panel.activeTab = "timers" },
    function() { shot("13b-timers-de") },
    function() { panel.openSettings("sounds") },
    function() { shot("13c-settings-sounds-de") },
    function() { panel.settingsOpen = false },
    function() { panel.editingId = ""; panel.activeTab = "world"; general("language", "ar") },
    function() { shot("14-world-ar") },
    function() { panel.menubarHovered = true; console.log("MENUBAR", JSON.stringify(panel.menubarEntries)) },
    // The bar's tooltip (hoverTooltip): the hover entries, one per line.
    function() {
      general("language", "en")
      panel.menubarHovered = false
      console.log("TOOLTIP", JSON.stringify(panel.menubarTooltipLines()))
      panel.menubarHovered = true
    },
    // The time's sky colour at a fixed place (Bobingen, as in Omarchy's
    // weather location) on 2 October: noon, 20:00, 23:00 local time, with
    // the contrast on the popup background.
    function() {
      panel.here.weatherPlace = { name: "Bobingen", lat: 48.27, lon: 10.83 }
      var bg = [Color.popups.background.r, Color.popups.background.g, Color.popups.background.b]
      ;[12, 19, 20, 23].forEach(function(h) {
        var ms = new Date(2026, 9, 2, h, 0).getTime()
        var hex = panel.skyColorAt(ms)
        console.log("SKY", h + ":00", "elevation", WorldMap.sunElevation(48.27, 10.83, ms).toFixed(1), hex,
          "contrast", WorldMap.contrast(WorldMap.hexRgb(hex), bg).toFixed(2))
      })
    },
    // Coloured values, always: the roles per entry and part.
    function() {
      panel.settingsTargetSurface = "menubar"
      panel.displayOptionsStore.setSettingsDisplaySetting("menubarAccents", "always")
      panel.displayOptionsStore.setSettingsDisplaySetting("secondsOnHover", false)
      panel.displayOptionsStore.setSettingsDisplaySetting("seconds", true)
      panel.displayOptionsStore.setSettingsDisplaySetting("week", true)
    },
    function() {
      console.log("MENUBAR always", JSON.stringify(panel.menubarEntries.map(function(e) {
        return { key: e.key, color: e.color, parts: e.parts }
      })))
      panel.displayOptionsStore.setSettingsDisplaySetting("menubarAccents", "off")
    },
    function() {
      console.log("MENUBAR off", JSON.stringify(panel.menubarEntries.map(function(e) {
        return e.key + ":" + e.color + "/" + e.parts.map(function(p) { return p.color }).join(",")
      })))
      panel.settingsPage = "display"
      panel.openSettings("display")
      panel.settingsTargetSurface = "menubar"
      general("language", "en")
      panel.displayOptionsStore.setSettingsDisplaySetting("menubarAccents", "always")
    },
    function() { panel.settingsItem.focusId = "menubarAccents"; panel.settingsItem.scrollBy(240) },
    function() { shot("15-settings-menubar-accents") },
    // The README's pictures (screenshots/, preview.png): English, the app.
    function() {
      general("language", "en")
      // Nothing ringing, no timer run out; the popup's background behind the
      // view (the window's colour is not part of a grab).
      panel.ringer.stopAll()
      panel.itemsStore.items.timers.forEach(function(t) { if (t.state === "done") panel.resetItem("timers", t.id) })
      harness.backdrop = Qt.createQmlObject('import QtQuick; import qs.Commons; Rectangle { anchors.fill: parent; z: -1; color: Color.popups.background }',
        panel.contentRoot)
      panel.settingsOpen = false
      panel.settingsTargetSurface = "app"
      panel.setCurrentPlace(-1)
      display("worldStyle", "map"); display("worldMoon", true); display("worldMap", true)
      display("heroGoldenHour", true); display("heroBlueHour", true)
      panel.activeTab = "world"
    },
    function() { shot("readme-preview") },
    function() { display("worldStyle", "globe") },
    function() { var g = globe(); g.finishTurn(); g.hover = null; g.centerLon = WorldMap.subsolarPoint(Date.now()).lon + 75 },
    function() { shot("readme-globe") },
    function() {
      display("worldStyle", "map")
      panel.activeTab = "alarms"
      var alarm = panel.itemsStore.items.alarms[0]
      panel.updateItem("alarms", alarm.id, { tz: "Asia/Tokyo", placeName: "Tokyo", hour: 7, minute: 0, days: [1, 2, 3, 4, 5] })
      panel.addItem("alarms")
      panel.editingId = panel.itemsStore.items.alarms[1].id
      panel.editField = 9
    },
    function() { shot("readme-alarms") },
    function() { panel.editingId = ""; panel.activeTab = "timers" },
    function() { shot("readme-timers") },
    function() {
      var today = new Date()
      panel.itemsStore.updateMany([{ kind: "pomodoroLog", fn: function(log) {
        var next = {}
        for (var d = 0; d < 6; d++) {
          var day = new Date(today.getFullYear(), today.getMonth(), today.getDate() - d)
          next[Qt.formatDate(day, "yyyy-MM-dd")] = [4, 3, 5, 2, 6, 1][d]
        }
        return next
      } }])
      panel.activeTab = "pomodoros"
    },
    function() { shot("readme-pomodoros") },
    function() { panel.openSettings("sounds") },
    function() { shot("readme-sounds") },
    function() { panel.openSettings("display"); panel.settingsTargetSurface = "app" },
    function() { shot("readme-display") },
    function() { panel.settingsOpen = false; panel.activeTab = "world"; display("worldMoon", false); harness.backdrop.destroy() },
    // The globe and the map fill the visible height: the app at 941×1150,
    // at 600×700 and at the popup's size (500 wide, 720 high at most).
    function() { display("worldStyle", "globe"); appSize(941, 1150) },
    function() { globeSize("941x1150"); globe().finishTurn() },
    function() { shot("31a-globe-941x1150") },
    function() {
      display("globeAutoRotate", true)
      var g = globe()
      g.paintStats = { count: 0, total: 0, max: 0 }
      g.rotating = true
    },
    function() {},
    // Turning by itself: the cheap frames (fills at a lower resolution).
    function() { shot("01m-globe-turning") },
    function() {
      var st = globe().paintStats
      var per = function(v) { return ((v || 0) / Math.max(1, st.count)).toFixed(1) }
      console.log("GLOBE frames large", st.count, "ms/frame", per(st.total), "max", st.max, "diameter", Math.round(globe().diameter))
      display("globeAutoRotate", false)
    },
    function() { display("worldStyle", "map") },
    function() { mapSize("941x1150") },
    function() { shot("31b-map-941x1150") },
    function() { display("worldStyle", "globe"); appSize(600, 700) },
    function() { globeSize("600x700"); globe().finishTurn() },
    function() { shot("31c-globe-600x700") },
    function() { display("worldStyle", "map") },
    function() { mapSize("600x700") },
    function() { shot("31d-map-600x700") },
    function() {
      display("worldStyle", "globe")
      var pad = Style.spacing.popupPadding
      appSize(Style.space(500) + 2 * pad, Style.space(720) + 2 * pad)
    },
    function() { globeSize("popup"); globe().finishTurn() },
    function() { shot("31e-globe-popup") },
    function() { display("worldStyle", "map") },
    function() { mapSize("popup") },
    function() { shot("31f-map-popup") },
    function() { appSizeReset() },
    // The Astro tab: the whole system, the inner system, two camera angles,
    // a body's label, and what a frame costs while it turns.
    function() { display("worldStyle", "map"); panel.activeTab = "astro" },
    function() {
      var a = astro()
      console.log("ASTRO size", Math.round(a.width) + "x" + Math.round(a.height), "earth lon", a.bodies.earth.au.lon.toFixed(2),
        "marks", a.marks.seasons.map(function(m) { return m.key + " " + new Date(m.utcMs).toISOString().slice(0, 16) }).join(", "))
    },
    function() { shot("40a-astro-system") },
    function() { astro().zoomIndex = 1 },
    function() { shot("40b-astro-inner") },
    function() { var a = astro(); a.zoomIndex = 0; a.azimuth = 40; a.elevation = 70 },
    function() { shot("40c-astro-high") },
    function() { var a = astro(); a.azimuth = 150; a.elevation = 12 },
    function() { shot("40d-astro-low") },
    function() {
      var a = astro()
      a.azimuth = a.startAzimuth
      a.elevation = 30
      a.zoomIndex = 1
    },
    function() {
      var a = astro()
      var earth = a.hits.filter(function(h) { return h.key === "earth" })[0]
      a.pointer = { x: earth.x, y: earth.y }
      a.updateHover()
      console.log("ASTRO hover", JSON.stringify(a.hover ? a.hover.text : null))
    },
    function() { shot("40e-astro-hover") },
    function() {
      var a = astro()
      a.pointer = null
      a.updateHover()
      a.zoomIndex = 0
      display("astroAutoRotate", true)
      a.paintStats = { count: 0, total: 0, max: 0 }
      a.rotating = true
    },
    function() {},
    function() {},
    function() {
      var a = astro()
      var st = a.paintStats
      console.log("ASTRO frames", st.count, "ms/frame", (st.total / Math.max(1, st.count)).toFixed(1), "max", st.max,
        "size", Math.round(a.width) + "x" + Math.round(a.height))
      display("astroAutoRotate", false)
      panel.activeTab = "world"
    },
    // Deleting a city before the current one keeps the same city current.
    function() {
      panel.setCurrentPlace(2)
      var before = panel.currentPlace
      panel.deleteItem("world", panel.cityDeleteId(0))
      panel.deleteItem("world", panel.cityDeleteId(0))
      console.log("CHECK delete keeps place", before, "->", panel.currentPlace, panel.placeStore.current,
        before === panel.currentPlace ? "ok" : "WRONG")
    },
    // A change before the items file is read (an IPC startTimer right after
    // a start) waits for it instead of wiping the file.
    function() {
      var alarmsBefore = panel.itemsStore.items.alarms.length
      var timersBefore = panel.itemsStore.items.timers.length
      panel.itemsStore.loaded = false
      panel.startTimer(5 * 60000, "Race")
      var queued = panel.itemsStore.pending.length
      panel.itemsStore.file.reload()
      var items = panel.itemsStore.items
      console.log("CHECK early change", "queued", queued, "alarms", alarmsBefore, "->", items.alarms.length,
        "timers", timersBefore, "->", items.timers.length,
        queued === 1 && items.alarms.length === alarmsBefore ? "ok" : "WRONG")
    },
    function() {
      var items = panel.itemsStore.items
      console.log("CHECK early change after load", "timers", items.timers.length,
        items.timers.some(function(t) { return t.label === "Race" }) ? "ok" : "WRONG")
    },
    function() { console.log("STATUS", panel.statusSummary().join(" | ")); Qt.quit() }
  ]

  Timer {
    interval: 1200
    running: true
    repeat: true
    onTriggered: {
      if (harness.step >= harness.steps.length) return
      try { harness.steps[harness.step]() } catch (e) { console.log("STEP FAILED", harness.step, e, e.stack) }
      harness.step++
    }
  }

  Time.Panel {
    id: panel
    standaloneMode: true
    Component.onCompleted: open()
  }
}
