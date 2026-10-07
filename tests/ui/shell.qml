import QtQuick
import Quickshell
import "Time" as Time
import "Time/WorldMap.js" as WorldMap
import "Time/Moon.js" as Moon
import "Time/MoonView.js" as MoonView
import qs.Commons

// Screenshot run for tests/ui-shots.sh: the app view with sample items, every
// tab, the editors and every settings page, in English, German and Arabic
// (right to left). Pictures go to $MT_SHOTS.
ShellRoot {
  id: harness
  readonly property string shots: Quickshell.env("MT_SHOTS") || "/tmp"
  property int step: 0
  property var backdrop: null
  property var dpmsFile: null

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
  function astroView() { return astro().parent }
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
    function() {
      var g = globe()
      g.finishTurn()
      console.log("GLOBE", g.centerLon, g.width, g.height)
      // The software scene graph has no shaders: the Canvas path is tested.
      console.log("CHECK surface off offscreen", g.gpuSurface, g.gpuSurface === false ? "ok" : "WRONG", "texture ms", g.textureMs)
    },
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
      var g = globe()
      var c = panel.currentCoordinates
      var v = MoonView.view(Number(c.lat), Number(c.lon), g.minuteMs)
      console.log("MOON view", panel.currentName, "tilt", v.tilt.toFixed(1), "lit", (v.illuminated * 100).toFixed(0) + "%",
        "alt", v.apparentAltitude.toFixed(1), "az", v.azimuth.toFixed(0), "earthshine", v.earthshine)
      g.hover = g.moonHit ? { moon: g.moonHit.moon, ms: g.moonHit.ms, x: g.moonHit.x, y: g.moonHit.y } : null
      console.log("MOON hover", JSON.stringify(panel.mapHoverText(g.hover)))
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
    function() { panel.settingsItem.focusId = ""; panel.settingsItem.scrollBy(4000) },
    function() { shot("10c-settings-astro") },
    // The search: across every page, grouped, the rows working as on the
    // pages; "Mond" in German finds the Moon rows, "night" in English too.
    function() { panel.settingsItem.scrollBy(-10000); panel.settingsItem.search("moon") },
    function() {
      var s = panel.settingsItem
      console.log("SEARCH moon", s.searchResults.length, JSON.stringify(s.searchGroups.map(function(g) { return g.heading })))
      s.moveFocus(1)
    },
    function() { shot("10d-settings-search") },
    function() { panel.settingsItem.search("xyzzy") },
    function() { console.log("SEARCH none", panel.settingsItem.searchResults.length); shot("10e-settings-search-none") },
    function() { panel.settingsItem.search(""); panel.openSettings("general") },
    function() { panel.settingsItem.scrollBy(560) },
    function() { shot("08f-settings-general-motion") },
    function() { display("worldStyle", "map"); display("globeAutoRotate", false); panel.settingsItem.focusId = ""; panel.settingsOpen = false },
    function() { panel.openSettings("shortcuts") },
    function() { shot("11-settings-shortcuts") },
    function() { panel.settingsPage = "sources" },
    function() { shot("12-settings-sources") },
    function() { panel.settingsItem.scrollBy(1500) },
    function() { shot("12b-settings-sources-stars") },
    function() { panel.settingsItem.scrollBy(1000) },
    function() { shot("12c-settings-sources-licence") },
    function() { panel.settingsItem.scrollBy(-10000) },
    // What's new: the change log, newest first; the older versions too.
    function() { panel.openSettings("changes") },
    function() { shot("12d-settings-changes") },
    function() {
      var page = findNamed(panel.contentRoot, "timeChanges") || null
      console.log("CHANGES page", panel.settingsPage)
      panel.settingsItem.handleKey({ key: Qt.Key_Return, text: "\r", modifiers: 0 })
      panel.settingsItem.scrollBy(100000)
    },
    function() { shot("12e-settings-changes-older") },
    function() { panel.settingsItem.scrollBy(-100000); panel.openSettings("sources") },
    function() { panel.settingsOpen = false; general("language", "de"); panel.activeTab = "alarms"; panel.editingId = panel.itemsStore.items.alarms[0].id },
    function() { shot("13-alarm-editor-de") },
    function() { panel.editingId = ""; panel.activeTab = "timers" },
    function() { shot("13b-timers-de") },
    function() { panel.openSettings("sounds") },
    function() { shot("13c-settings-sounds-de") },
    // The page strip at the popup's width in long languages: shrunk, then
    // in centred lines, nothing cut off.
    function() {
      var pad = Style.spacing.popupPadding
      appSize(Style.space(500) + 2 * pad, Style.space(720) + 2 * pad)
    },
    function() { general("language", "de"); panel.openSettings("general") },
    function() {
      var lines = panel.settingsItem.settingsPageLines || []
      console.log("PAGES de", lines.length, "lines", JSON.stringify(lines.map(function(l) { return l.map(function(p) { return Math.round(p.width) }) })),
        "width", Math.round(panel.contentRoot.width))
      shot("16-settings-pages-de")
    },
    function() { general("language", "fr"); panel.openSettings("general") },
    function() {
      var lines = panel.settingsItem.settingsPageLines || []
      console.log("PAGES fr", lines.length, "lines", JSON.stringify(lines.map(function(l) { return l.map(function(p) { return Math.round(p.width) }) })),
        "width", Math.round(panel.contentRoot.width))
      shot("16-settings-pages-fr")
    },
    function() { general("language", "hu"); panel.openSettings("general") },
    function() {
      var lines = panel.settingsItem.settingsPageLines || []
      console.log("PAGES hu", lines.length, "lines", JSON.stringify(lines.map(function(l) { return l.map(function(p) { return Math.round(p.width) }) })),
        "width", Math.round(panel.contentRoot.width))
      shot("16-settings-pages-hu")
    },
    function() { general("language", "fi"); panel.openSettings("general") },
    function() {
      var lines = panel.settingsItem.settingsPageLines || []
      console.log("PAGES fi", lines.length, "lines", JSON.stringify(lines.map(function(l) { return l.map(function(p) { return Math.round(p.width) }) })),
        "width", Math.round(panel.contentRoot.width))
      shot("16-settings-pages-fi")
    },
    function() { general("language", "en"); panel.openSettings("general") },
    function() {
      var lines = panel.settingsItem.settingsPageLines || []
      console.log("PAGES en", lines.length, "lines", JSON.stringify(lines.map(function(l) { return l.map(function(p) { return Math.round(p.width) }) })),
        "width", Math.round(panel.contentRoot.width))
      shot("16-settings-pages-en")
    },
    function() { appSizeReset(); general("language", "de") },
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
      // The same turning with the Canvas as when the GPU surface is on
      // (forced: shaders do not run offscreen).
      var g = globe()
      g.forceSurfaceBranch = true
      g.paintStats = { count: 0, total: 0, max: 0 }
    },
    function() {},
    function() {
      var g = globe()
      var st = g.paintStats
      console.log("GLOBE surface-branch frames", st.count, "ms/frame", (st.total / Math.max(1, st.count)).toFixed(2), "max", st.max,
        "diameter", Math.round(g.diameter))
      g.forceSurfaceBranch = false
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
    // Zoomed in: the globe at z2 on Europe (tilted), what a moving frame
    // costs there, and the flat map at z2 on the current place.
    function() { display("worldStyle", "globe"); var g = globe(); g.zoomBy(1); g.zoomBy(1) },
    function() { var g = globe(); g.turnTo(10.8, 48.3); g.finishTurn() },
    function() { shot("32a-globe-z2") },
    function() { var g = globe(); g.paintStats = { count: 0, total: 0, max: 0 }; g.turnTo(g.centerLon + 30, 40) },
    function() {
      var g = globe()
      var st = g.paintStats
      console.log("GLOBE z2 moving frames", st.count, "ms/frame", (st.total / Math.max(1, st.count)).toFixed(1), "max", st.max,
        "zoom", g.zoom, "lat", g.centerLat.toFixed(1))
      g.reset()
      g.finishTurn()
    },
    function() { display("worldStyle", "map") },
    function() { var m = findMap(panel.contentRoot); m.zoomBy(1); m.zoomBy(1); m.recenter() },
    function() { shot("32b-map-z2") },
    function() { findMap(panel.contentRoot).reset() },
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
    // The Earth–Moon zoom with the Moon's label; Saturn from high above
    // with its rings and its label.
    function() { var a = astro(); a.pointer = null; a.updateHover(); a.zoomIndex = 2 },
    function() { shot("40f-astro-earth-moon") },
    function() {
      var a = astro()
      var moon = a.hits.filter(function(h) { return h.key === "moon" })[0]
      a.pointer = { x: moon.x, y: moon.y }
      a.updateHover()
      console.log("ASTRO moon", JSON.stringify(a.hover ? a.hover.text : null))
    },
    function() { shot("40g-astro-moon-hover") },
    function() { var a = astro(); a.pointer = null; a.updateHover(); a.zoomIndex = 0; a.elevation = 75 },
    function() {
      var a = astro()
      var saturn = a.hits.filter(function(h) { return h.key === "saturn" })[0]
      a.pointer = { x: saturn.x, y: saturn.y }
      a.updateHover()
      console.log("ASTRO saturn", JSON.stringify(a.hover ? a.hover.text : null))
    },
    function() { shot("40h-astro-saturn-high") },
    // The timeline: 90 days ahead; 1969-07-20 20:17 UTC; a travel half
    // way; what a frame costs while playing a year in a minute.
    function() { var a = astro(); a.pointer = null; a.updateHover(); a.elevation = 30; a.zoomIndex = 1; a.scrubTo(366 + 90) },
    function() { console.log("ASTRO info", JSON.stringify(astroView().infoText)); shot("41a-astro-timeline-90") },
    function() { astro().showAt(Date.UTC(1969, 6, 20, 20, 17)) },
    function() { console.log("ASTRO 1969", JSON.stringify(astroView().infoText)); shot("41b-astro-1969") },
    function() { astro().zoomIndex = 0; astro().travelTo(Date.UTC(2026, 9, 3, 12), false) },
    function() { console.log("ASTRO travel", new Date(astro().minuteMs).toISOString()); shot("41c-astro-travel") },
    function() {
      var a = astro()
      a.finishTravel()
      a.zoomIndex = 1
      display("astroLapse", "yearInMinute")
      a.paintStats = { count: 0, total: 0, max: 0 }
      a.togglePlay()
    },
    function() {},
    function() {
      var a = astro()
      var st = a.paintStats
      console.log("ASTRO playback", new Date(a.minuteMs).toISOString(), "frames", st.count, "ms/frame", (st.total / Math.max(1, st.count)).toFixed(1), "max", st.max)
      a.togglePlay()
      a.finishTravel()
      a.backToNow()
      a.finishTravel()
    },
    // More bodies: belts and dwarf planets (on by default), Halley, the
    // spacecraft and Jupiter's moons (pinned) switched on; the Earth–Moon
    // view with JWST; Halley's and Voyager 1's labels.
    function() {
      display("astroComets", true); display("astroMoons", true); display("astroSpacecraft", true)
      var a = astro(); a.zoomIndex = 0; a.elevation = 40; a.azimuth = -60; a.pinned = "jupiter"
    },
    function() { shot("42a-astro-bodies") },
    function() {
      var a = astro()
      var moons = a.hits.filter(function(h) { return h.key === "io" || h.key === "ganymede" })
      console.log("ASTRO moons", moons.length, JSON.stringify(moons.length ? a.infoText(moons[0].key) : null))
      var v1 = a.hits.filter(function(h) { return h.key === "voyager1" })[0]
      console.log("ASTRO voyager", JSON.stringify(v1 ? a.infoText("voyager1") : null))
      a.pinned = ""
      a.elevation = 70
    },
    function() {
      var a = astro()
      var hal = a.hits.filter(function(h) { return h.key === "halley" })[0]
      if (hal) { a.pointer = { x: hal.x, y: hal.y }; a.updateHover() }
      console.log("ASTRO halley", JSON.stringify(a.hover ? a.hover.text : null))
    },
    function() { shot("42b-astro-halley") },
    function() { var a = astro(); a.pointer = null; a.pinned = ""; a.updateHover(); a.zoomIndex = 2 },
    function() { console.log("ASTRO jwst", JSON.stringify(astro().infoText("jwst"))); shot("42c-astro-jwst") },
    // The ISS from a fixture TLE (tests/fixtures/iss-tle.json), shown at
    // 2026-10-05 18:32 UTC (over Canada) in the Earth–Moon view, with its
    // label.
    function() {
      panel.issStore.adoptTle("ISS (ZARYA)\n1 25544U 98067A   26278.04655461  .00004924  00000+0  98343-4 0  9995\n"
        + "2 25544  51.6316 116.4131 0006856 223.9771 136.0673 15.48738655588781", Date.now())
      display("astroIss", true)
      var a = astro()
      a.showAt(1791225155000)
      a.zoomIndex = 2
    },
    function() {
      var a = astro()
      var st = a.hits.filter(function(h) { return h.key === "iss" })[0]
      if (st) { a.pointer = { x: st.x, y: st.y }; a.updateHover() }
      console.log("ASTRO iss", JSON.stringify(a.hover ? a.hover.text : null), a.iss ? a.iss.at.lat.toFixed(2) + " " + a.iss.at.lon.toFixed(2) : "none",
        new Date(a.minuteMs).toISOString(), new Date(a.issMs).toISOString(), a.timePinned)
    },
    function() {
      var a = astro()
      console.log("ASTRO iss shot", a.timePinned, new Date(a.minuteMs).toISOString(), a.traveling, a.playing)
      shot("43a-astro-iss")
    },
    function() {
      var a = astro()
      a.pointer = null
      a.updateHover()
      a.showAt(1791225155000 + 30 * 86400000)
    },
    function() { console.log("ASTRO iss far", astro().iss === null ? "hidden" : "SHOWN", JSON.stringify(astroView().infoText.split("\n").slice(-1)[0])) },
    function() { var a = astro(); a.backToNow(); a.finishTravel(); display("astroIss", false) },
    function() { var a = astro(); a.zoomIndex = 0; a.pinned = "jupiter"; display("astroConstellations", true) },
    function() {
      var a = astro()
      a.pointer = null
      a.updateHover()
      a.zoomIndex = 0
      display("astroAutoRotate", true)
      a.paintStats = { count: 0, total: 0, max: 0 }
      a.starStats = { count: 0, total: 0, max: 0 }
      a.rotating = true
    },
    function() {},
    function() {},
    function() {
      var a = astro()
      var st = a.paintStats, ss = a.starStats
      console.log("ASTRO frames", st.count, "ms/frame", (st.total / Math.max(1, st.count)).toFixed(1), "max", st.max,
        "stars frames", ss.count, "ms/frame", (ss.total / Math.max(1, ss.count)).toFixed(1), "max", ss.max,
        "proj", ((ss.proj || 0) / Math.max(1, ss.count)).toFixed(1), "figs", ((ss.figs || 0) / Math.max(1, ss.count)).toFixed(1),
        "dots", ((ss.dots || 0) / Math.max(1, ss.count)).toFixed(1), "labels", ((ss.labels || 0) / Math.max(1, ss.count)).toFixed(1),
        "size", Math.round(a.width) + "x" + Math.round(a.height))
      display("astroAutoRotate", false)
      a.rotating = false
      a.pinned = ""
      a.azimuth = -100
      a.elevation = 25
    },
    // The stars and the constellations behind the system; a bright star's
    // name under the pointer; the Earth–Moon view with the stars.
    function() {
      var a = astro()
      var s = a.starData, p = a.starProjection
      var hit = null
      for (var i = 0; s && p && i < s.nameList.length && !hit; i++) {
        var k = s.nameList[i].index
        if (p.on[k] && p.x[k] > 60 && p.x[k] < a.width - 200 && p.y[k] > 40 && p.y[k] < a.height - 40) hit = { x: p.x[k], y: p.y[k] }
      }
      if (hit) { a.pointer = hit; a.updateHover() }
      console.log("ASTRO star", JSON.stringify(a.hover ? a.hover.text : null), "stars", s ? s.count : 0)
    },
    function() { shot("44a-astro-constellations") },
    function() { var a = astro(); a.pointer = null; a.updateHover(); a.zoomIndex = 2 },
    function() { shot("44b-astro-earth-stars") },
    // A constellation under the pointer, highlighted and named.
    function() {
      var a = astro()
      a.zoomIndex = 0
      display("astroConstellations", true)
    },
    function() {
      var a = astro()
      var p = a.starProjection, f = null
      for (var k = 0; a.figures && p && k < a.figures.length && !f; k++) {
        var seg = a.figures[k].segments[0]
        if (seg && p.on[seg[0]] && p.on[seg[1]]) {
          var mx = (p.x[seg[0]] + p.x[seg[1]]) / 2, my = (p.y[seg[0]] + p.y[seg[1]]) / 2
          if (mx > 200 && mx < a.width - 60 && my > 40 && my < a.height - 40) f = { x: mx, y: my }
        }
      }
      if (f) { a.pointer = f; a.updateHover() }
      console.log("ASTRO figure", a.hoverFigure, JSON.stringify(a.hover ? a.hover.text : null))
    },
    function() { shot("44c-astro-figure-hover") },
    // Sky events: the panel open, all kinds; the eclipses; a solar eclipse
    // (2026-08-12) and a lunar one (2026-03-03) in the Earth–Moon view; the
    // info unfolded; the time lapse's speeds.
    function() { var a = astro(); a.pointer = null; a.updateHover(); display("astroConstellations", false); astroView().eventsOpen = true },
    function() {
      var v = astroView()
      v.computeEvents()
      console.log("EVENTS all", JSON.stringify(v.eventRows.map(function(r) { return r.when + " | " + r.text })))
      console.log("ASTRO layout sky", Math.round(astro().height), "viewport", Math.round(panel.viewportHeight - panel.tabContentTop))
    },
    function() { shot("45a-astro-events") },
    function() { astroView().eventsFilter = "eclipses" },
    function() {
      var v = astroView()
      v.computeEvents()
      console.log("EVENTS eclipses", JSON.stringify(v.eventRows.map(function(r) { return r.when + " | " + r.text })))
      shot("45b-astro-events-eclipses")
    },
    function() { var a = astro(); a.showAt(Date.UTC(2026, 7, 12, 17, 46)); a.zoomIndex = 2 },
    function() {
      var a = astro()
      var earth = a.hits.filter(function(h) { return h.key === "earth" })[0]
      if (earth) { a.pointer = { x: earth.x, y: earth.y }; a.updateHover() }
      console.log("ECLIPSE solar", JSON.stringify(a.eclipseNow ? { type: a.eclipseNow.e.type, lat: a.eclipseNow.e.lat, lon: a.eclipseNow.e.lon } : null),
        JSON.stringify(a.hover ? a.hover.text : null))
    },
    function() { var a = astro(); a.pointer = null; a.updateHover(); a.elevation = 55 },
    function() { shot("45c-astro-solar-eclipse") },
    function() { var a = astro(); a.elevation = 30; a.showAt(Date.UTC(2026, 2, 3, 11, 33)) },
    function() {
      var a = astro()
      console.log("ECLIPSE lunar", JSON.stringify(a.eclipseNow ? { type: a.eclipseNow.e.type, fade: a.eclipseNow.fade.toFixed(2) } : null))
      shot("45d-astro-lunar-eclipse")
    },
    function() { var v = astroView(); v.eventsOpen = false; v.infoExpanded = true; astro().zoomIndex = 0 },
    function() { console.log("ASTRO info expanded", JSON.stringify(astroView().infoText)); shot("45e-astro-info") },
    function() { var v = astroView(); v.infoExpanded = false; v.lapseMenuOpen = true },
    function() { shot("45f-astro-lapse-menu") },
    function() { var v = astroView(); v.lapseMenuOpen = false; v.eventsFilter = "all"; astro().backToNow(); astro().finishTravel() },
    function() { var a = astro(); a.zoomIndex = 0; a.azimuth = a.startAzimuth; a.elevation = 30; display("astroConstellations", false) },
    function() { console.log("ASTRO info here", JSON.stringify(astroView().infoText)); panel.activeTab = "world" },
    // The World timeline: the seasons on the globe (21 June 12:00 UTC),
    // then the flat map playing a day in ten seconds; the Moon as seen
    // from here as a thin crescent with earthshine (2026-10-12 16:30 UTC).
    function() { panel.activeTab = "world"; display("worldStyle", "globe"); display("worldMoon", true); display("worldMoonStyle", "earth") },
    function() {
      var w = findNamed(panel.contentRoot, "timeWorld")
      w.showAt(Date.UTC(2026, 5, 21, 12, 0))
      display("worldLapse", "seasonsInMinute")
    },
    function() { shot("46a-world-shown-june") },
    function() {
      var w = findNamed(panel.contentRoot, "timeWorld")
      display("worldLapse", "dayIn10Seconds")
      display("worldStyle", "map")
      w.showAt(Date.UTC(2026, 9, 12, 16, 30))
    },
    function() {
      var c = panel.currentCoordinates
      var v = MoonView.view(Number(c.lat), Number(c.lon), panel.worldMinuteMs)
      console.log("MOON crescent lit", (v.illuminated * 100).toFixed(1) + "%", "earthshine", v.earthshine, "alt", v.apparentAltitude.toFixed(1))
      shot("46b-world-crescent")
    },
    function() {
      var w = findNamed(panel.contentRoot, "timeWorld")
      var m = findMap(panel.contentRoot)
      if (m) m.paintStats = { count: 0, total: 0, max: 0 }
      w.togglePlay()
    },
    function() {},
    function() {
      var w = findNamed(panel.contentRoot, "timeWorld")
      var m = findMap(panel.contentRoot)
      var st = m ? m.paintStats : null
      console.log("WORLD lapse", new Date(panel.worldMinuteMs).toISOString(), "playing", w.playing,
        st ? "map frames " + st.count + " ms/frame " + (st.total / Math.max(1, st.count)).toFixed(1) : "")
      shot("46c-world-lapse-playing")
      w.backToNow()
      display("worldMoon", false); display("worldMoonStyle", "space"); display("worldLapse", "dayInMinute")
    },
    // Control hints on and off (General › App), World and Astro; the "+"
    // button with its tooltip name.
    function() { panel.activeTab = "world" },
    function() { shot("47a-world-hints-on") },
    function() { general("showHints", false) },
    function() { console.log("HINTS off", panel.showHints); shot("47b-world-hints-off") },
    function() { panel.activeTab = "astro"; panel.scrollBy(-10000) },
    function() { shot("47d-astro-hints-off") },
    function() { general("showHints", true); panel.scrollBy(-10000) },
    function() { shot("47c-astro-hints-on") },
    function() { panel.activeTab = "world" },
    // The monitor turned off (the fake hyprctl's DPMS state): screenOn
    // false, then on again at the next look.
    function() {
      harness.dpmsFile = Qt.createQmlObject('import Quickshell.Io; FileView { path: "' + Quickshell.env("FAKE_DPMS") + '" }', harness)
      harness.dpmsFile.setText("off\n")
    },
    function() { panel.screenState.probe() },
    function() {
      var known = panel.screenState.hyprland
      console.log("CHECK screen off", panel.screenOn, known ? (panel.screenOn === false ? "ok" : "WRONG") : "skipped (no Hyprland)")
      harness.dpmsFile.setText("on\n")
    },
    function() { panel.screenState.probe() },
    function() { console.log("CHECK screen on again", panel.screenOn, panel.screenOn ? "ok" : "WRONG") },
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
