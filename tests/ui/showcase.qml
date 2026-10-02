import QtQuick
import Quickshell
import qs.Commons
import "Time" as Time
import "Time/WorldMap.js" as WorldMap

// The README pictures (tests/ui-showcase.sh): the app at 941 × 1150, the
// popup's view at 480 wide and the menu bar, with the cities, alarms,
// timers and pomodoros the script wrote. A step is 1.2 s.
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

  readonly property var steps: [].concat(
    [function() {
      panel.clockOffsetMs = harness.clockOffset()
      panel.contentRoot.parent = appHost
      app("worldStyle", "globe")
      app("heroGoldenHour", true)
      app("heroBlueHour", true)
      app("worldMoon", true)
      app("worldDials", true)
      app("worldSunNext", true)
      app("worldRuler", true)
      panel.setCurrentPlace(-1)
      panel.activeTab = "world"
    }],
    wait(4),
    // (1) The clock and the globe turned to the Atlantic: Berlin, the
    // twilight bands, the Moon, the cities with their faces.
    // Facing the Atlantic while the sun is up there; at night there the
    // sunlit side with the evening line in view instead.
    [function() {
      var g = findGlobe(panel.contentRoot)
      if (!g) return
      g.finishTurn()
      var now = panel.nowMs
      g.centerLon = WorldMap.sunElevation(30, -28, now) > 5 ? -28 : WorldMap.subsolarPoint(now).lon - 45
    }],
    wait(2),
    [function() { press(Qt.Key_Home) }, function() { shot("world-globe") }],
    // (2) The flat map with the hour ruler, the night in three steps and the sun.
    [function() { app("worldStyle", "map") }],
    wait(2),
    [function() { shot("world-map") }],
    // (3) Alarms, one at Tokyo's time, its editor open on the place.
    [function() {
      panel.activeTab = "alarms"
      panel.select("alarms", "a2")
      panel.editingId = "a2"
      panel.editField = 9
    }],
    wait(2),
    [function() { shot("alarms") }, function() { panel.editingId = "" }],
    // (4) Timers running, one named.
    [function() { panel.activeTab = "timers"; panel.select("timers", "t1") }],
    wait(2),
    [function() { shot("timers") }],
    // (5) Pomodoros: one in focus, one in its break, and the tally.
    [function() { app("heroPomodoroTally", true); panel.activeTab = "pomodoros" }],
    wait(2),
    [function() { shot("pomodoros") }],
    // (6) Settings → Sounds: the chimes.
    [function() { app("heroPomodoroTally", false); panel.openSettings("sounds") }],
    wait(2),
    [function() { shot("settings-sounds") }, function() { panel.settingsOpen = false }],
    // The popup's view, 480 wide, and the menu bar with coloured values:
    // the time, two cities, a running timer and the bell of a timer that
    // has just run out.
    [function() {
      onSurface("menubar", "cities", true)
      onSurface("menubar", "citiesCount", "2")
      onSurface("menubar", "timers", true)
      onSurface("menubar", "menubarAccents", "always")
      panel.activeTab = "world"
      panel.contentRoot.parent = widgetHost
    }],
    wait(3),
    [function() { press(Qt.Key_Home) }, function() { shot("widget") },
      function() { panel.startTimer(1000, "Eggs"); barHost.active = true }],
    wait(5),
    [function() {
      var barPanel = harness.findPanel(barHost.item)
      if (barPanel) barPanel.clockOffsetMs = harness.clockOffset()
      console.log("SHOWCASE bar", barPanel ? "clock moved" : "panel not found")
    }],
    wait(2),
    // The bell blinks: catch it lit.
    [function() { if (barHost.item) barHost.item.blinkOn = true; shot("bar", barHost) },
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
      color: Color.popups.background
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
      color: Color.popups.background
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
      color: Color.bar ? Color.bar.background : Color.popups.background

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
