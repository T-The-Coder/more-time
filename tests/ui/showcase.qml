import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import "Time" as Time
import "Time/WorldMap.js" as WorldMap

// The README pictures (tests/ui-showcase.sh): the app at 941 × 1150, the
// popup's view at 480 wide and the menu bar, with the cities, alarms,
// timers and pomodoros the script wrote. Each scene sets its clock format
// (12 or 24 hours) and the moment it shows (scene()). A step is 1.2 s.
ShellRoot {
  id: harness
  readonly property string shots: Quickshell.env("MT_SHOTS") || "/tmp"
  property int step: 0
  // The moment the pictures show (ms), from tests/ui-showcase.sh.
  readonly property double clockAt: Number(Quickshell.env("MT_CLOCK_AT")) || 0
  function clockOffset() { return clockAt > 0 ? clockAt - Date.now() : 0 }

  // The panel the bar widget loads for itself, to move its clock too.
  function findPanel(item) {
    if (!item) return null
    if (item.clockOffsetMs !== undefined && item.ringer !== undefined) return item
    if (item.item) {
      var loaded = findPanel(item.item)
      if (loaded) return loaded
    }
    for (var i = 0; i < (item.children || []).length; i++) {
      var found = findPanel(item.children[i])
      if (found) return found
    }
    for (var d = 0; d < (item.data || []).length; d++) {
      if (item.data[d] === item) continue
      var inData = item.data[d] && item.data[d].clockOffsetMs !== undefined ? item.data[d] : null
      if (inData) return inData
    }
    return null
  }

  function shot(name, item) {
    (item || panel.contentRoot.parent.parent).grabToImage(function(result) {
      result.saveToFile(harness.shots + "/" + name + ".png")
      console.log("SHOT", name)
    })
  }
  function onSurface(surface, key, value) {
    panel.settingsTargetSurface = surface
    panel.displayOptionsStore.setSettingsDisplaySetting(key, value)
  }
  function app(key, value) { onSurface("app", key, value) }
  function press(key) {
    panel.handlePanelKey({ key: key, text: "", modifiers: Qt.NoModifier, accepted: false })
  }
  function wait(seconds) {
    var list = []
    for (var i = 0; i < Math.ceil(seconds / 1.2); i++) list.push(function() {})
    return list
  }
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
  function cityIndex(name) {
    for (var i = 0; i < panel.cityList.length; i++)
      if (panel.cityList[i].name === name) return i
    return -1
  }
  // A scene: its clock format ("12" or "24") and the moment it shows (ms,
  // UTC; 0 is the script's moment, against which the items were written).
  function scene(hours, moment) {
    panel.displayOptionsStore.setGeneralSetting("timeFormat", hours)
    panel.clockOffsetMs = (moment || harness.clockAt) > 0 ? (moment || harness.clockAt) - Date.now() : 0
    console.log("SHOWCASE scene", hours + " h", new Date(moment || harness.clockAt).toISOString())
  }

  readonly property var steps: [].concat(
    [function() {
      panel.clockOffsetMs = harness.clockOffset()
      panel.contentRoot.parent = appHost
      app("worldStyle", "globe")
      app("heroGoldenHour", true)
      app("heroBlueHour", true)
      app("worldMoon", true)
      app("worldDials", true)
      app("worldSunrise", true)
      app("worldSunset", true)
      app("worldSunNext", false)
      app("worldRuler", true)
      app("astroConstellations", true)
      panel.setCurrentPlace(-1)
      panel.activeTab = "world"
    }],
    wait(3),
    // (1) The globe from New York in 12 hours, at 7:13 AM there (11:13
    // UTC), just after sunrise: the morning line west of the city with the
    // golden and the blue band, the day over the Atlantic. The scenes move
    // the clock only back from the script's moment, so nothing comes due.
    [function() {
      harness.scene("12", Date.UTC(2026, 9, 11, 11, 13))
      panel.setCurrentPlace(harness.cityIndex("New York"))
    }],
    wait(3),
    [function() { var g = findGlobe(panel.contentRoot); if (g) g.finishTurn() }],
    wait(2),
    [function() { press(Qt.Key_Home) }, function() { shot("world-globe") }],
    // (2) The flat map from Tokyo in 24 hours, at 17:10 there (08:10 UTC),
    // just before its sunset; the morning line over the Atlantic.
    [function() {
      harness.scene("24", Date.UTC(2026, 9, 11, 8, 10))
      panel.setCurrentPlace(harness.cityIndex("Tokyo"))
      app("worldStyle", "map")
    }],
    wait(3),
    [function() { press(Qt.Key_Home) }, function() { shot("world-map") }],
    // (3) Places in 24 hours: Berlin as here, the cities with their clock
    // faces, sunrise and sunset.
    [function() {
      harness.scene("24", 0)
      panel.setCurrentPlace(-1)
      panel.activeTab = "places"
    }],
    wait(2),
    [function() { press(Qt.Key_Home) }, function() { shot("places") }],
    // (4) Astro: the solar system before the stars and the constellations,
    // the sky events open on the eclipses.
    [function() {
      panel.activeTab = "astro"
      var a = harness.astro()
      a.zoomIndex = 0
      a.azimuth = -35
      a.elevation = 34
      var v = harness.astroView()
      v.eventsOpen = true
      v.eventsFilter = "eclipses"
    }],
    wait(3),
    // Scrolled to the end: the model, the chips, the timeline and the events.
    [function() { harness.astroView().computeEvents(); press(Qt.Key_End) }],
    wait(1),
    [function() { shot("astro") }],
    // (5) The total solar eclipse of 2 August 2027 (10:07 UTC) in the Earth
    // and Moon view: the Moon's shadow on Earth, the stars behind. The
    // Sun stands at 130° ecliptic longitude from Earth; the camera looks
    // from 35° beside it (azimuth = longitude + 90°, AstroView.view).
    [function() {
      var a = harness.astro()
      a.showAt(Date.UTC(2027, 7, 2, 10, 7))
      a.zoomIndex = 2
      a.azimuth = 130 + 90 + 35
      a.elevation = 35
      harness.astroView().eventsOpen = false
    }],
    wait(3),
    [function() {
      var a = harness.astro()
      console.log("SHOWCASE eclipse", JSON.stringify(a.eclipseNow ? { type: a.eclipseNow.e.type } : null))
      press(Qt.Key_Home)
    }],
    wait(1),
    [function() { shot("astro-eclipse") }],
    [function() {
      var a = harness.astro()
      a.backToNow(); a.finishTravel(); a.zoomIndex = 0; a.elevation = 30
    }],
    // (6) Alarms in 12 hours, one at Tokyo's time, its editor open on the place.
    [function() {
      harness.scene("12", 0)
      panel.activeTab = "alarms"
      panel.select("alarms", "a2")
      panel.editingId = "a2"
      panel.editField = 9
    }],
    wait(2),
    [function() { shot("alarms") }, function() { panel.editingId = "" }],
    // (7) Timers running in 24 hours, one named.
    [function() { harness.scene("24", 0); panel.activeTab = "timers"; panel.select("timers", "t1") }],
    wait(2),
    [function() { shot("timers") }],
    // (8) Pomodoros in 12 hours: one in focus, one in its break, the tally.
    [function() { harness.scene("12", 0); app("heroPomodoroTally", true); panel.activeTab = "pomodoros" }],
    wait(2),
    [function() { shot("pomodoros") }],
    // (9) Settings → What's new, in 24 hours.
    [function() { harness.scene("24", 0); app("heroPomodoroTally", false); panel.openSettings("changes") }],
    wait(2),
    [function() { shot("settings-changes") }, function() { panel.settingsOpen = false }],
    // The popup's view, 480 wide, in 24 hours on the map from Berlin, and
    // the menu bar with coloured values: the time, two cities, a running
    // timer and a pomodoro.
    [function() {
      onSurface("menubar", "cities", true)
      onSurface("menubar", "citiesCount", "2")
      onSurface("menubar", "timers", true)
      onSurface("menubar", "menubarAccents", "always")
      onSurface("widget", "worldStyle", "map")
      panel.activeTab = "world"
      panel.contentRoot.parent = widgetHost
    }],
    wait(3),
    [function() { press(Qt.Key_Home) }, function() { shot("widget") },
      function() { barHost.active = true }],
    wait(5),
    [function() {
      var barPanel = harness.findPanel(barHost.item)
      if (barPanel) barPanel.clockOffsetMs = harness.clockOffset()
      console.log("SHOWCASE bar", barPanel ? "clock moved" : "panel not found")
    }],
    wait(2),
    [function() { shot("bar", barHost) },
      function() { Qt.quit() }]
  )

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

  // The app window's content with its padding, on the popups' colour.
  FloatingWindow {
    visible: true
    implicitWidth: 941
    implicitHeight: 1150
    Rectangle {
      anchors.fill: parent
      color: Commons.Color.popups.background
      Item { id: appHost; anchors.fill: parent; anchors.margins: 14 }
    }
  }

  // The popup: 480 wide inside its padding.
  FloatingWindow {
    visible: true
    implicitWidth: 512
    implicitHeight: 1000
    Rectangle {
      anchors.fill: parent
      color: Commons.Color.popups.background
      Item { id: widgetHost; anchors.fill: parent; anchors.margins: 16 }
    }
  }

  FloatingWindow {
    visible: true
    implicitWidth: 900
    implicitHeight: 48
    color: "transparent"

    Rectangle {
      id: barHost
      property alias active: barLoader.active
      readonly property alias item: barLoader.item
      anchors.fill: parent
      color: Commons.Color.bar ? Commons.Color.bar.background : Commons.Color.popups.background

      Loader {
        id: barLoader
        active: false
        anchors.centerIn: parent
        height: 32
        sourceComponent: Component { Time.BarWidget { height: 32 } }
      }
    }
  }

  Time.Panel {
    id: panel
    standaloneMode: true
    Component.onCompleted: {
      clockOffsetMs = harness.clockOffset()
      open()
    }
  }
}
