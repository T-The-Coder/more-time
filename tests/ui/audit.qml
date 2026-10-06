import QtQuick
import Quickshell
import "Time" as Time
import qs.Commons

// Interface audit for tests/ui-shots.sh (MT_HARNESS=audit): every view once
// at one width (MT_WIDTH, the popup's 500 by default), with sample items,
// in English: hero, each tab with its editor, empty states, the ringing
// banner, Astro with its panels, every settings page and the search.
// Pictures go to $MT_SHOTS, named NN-view.
ShellRoot {
  id: harness
  readonly property string shots: Quickshell.env("MT_SHOTS") || "/tmp"
  readonly property int width: Number(Quickshell.env("MT_WIDTH")) || 500
  property int step: 0

  function shot(name) {
    panel.contentRoot.grabToImage(function(result) {
      result.saveToFile(harness.shots + "/" + name + ".png")
      console.log("SHOT", name)
    })
  }
  function general(key, value) { panel.displayOptionsStore.setGeneralSetting(key, value) }
  function display(key, value) { panel.displayOptionsStore.setSettingsDisplaySetting(key, value) }
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
  function size(w, h) {
    var content = panel.contentRoot
    content.anchors.fill = undefined
    content.width = w
    content.height = h
  }

  // Every glyph-only control in view: a visible Text of one or two
  // non-letter characters whose parent is a small box (≤ 60 × 48). Logged
  // as GLYPH <view> <code points> box x y w h, in the shot's pixels, for
  // tools/ measuring the ink's centre in the box.
  function dumpGlyphs(view) {
    var root = panel.contentRoot
    function walk(item) {
      if (!item || !item.visible) return
      var text = item.text
      if (typeof text === "string" && item.font !== undefined && item.parent && text.length >= 1 && text.length <= 2
          && !/[A-Za-z0-9]/.test(text)) {
        var box = item.parent
        if (box.width > 0 && box.width <= 100 && box.height > 0 && box.height <= 48) {
          var p = box.mapToItem(root, 0, 0)
          var codes = []
          for (var c = 0; c < text.length; c++) codes.push(text.charCodeAt(c).toString(16))
          console.log("GLYPH", view, codes.join("+"), Math.round(p.x), Math.round(p.y), Math.round(box.width), Math.round(box.height))
        }
      }
      for (var i = 0; i < item.children.length; i++) walk(item.children[i])
    }
    walk(root)
  }

  readonly property var steps: [
    function() {
      panel.motionForced = true
      general("language", "en")
      general("alarmSound", "none")
      general("timerSound", "none")
      general("pomodoroSound", "none")
      size(harness.width, 900)
      // The window's background, which the grab leaves out.
      Qt.createQmlObject('import QtQuick; import qs.Commons; Rectangle { anchors.fill: parent; z: -1; color: Color.popups.background }',
        panel.contentRoot)
      panel.here.weatherPlace = { name: "Bobingen", lat: 48.27, lon: 10.83 }
    },
    // Empty states first.
    function() { panel.activeTab = "alarms" },
    function() { shot("01-alarms-empty") },
    function() { panel.activeTab = "stopwatches" },
    function() { shot("02-stopwatches-empty") },
    function() { panel.activeTab = "pomodoros" },
    function() { shot("03-pomodoros-empty") },
    function() {
      panel.startTimer(25 * 60000, "Tea")
      panel.startTimer(1500, "Egg")
      panel.addItem("stopwatches")
      panel.addItem("pomodoros")
      panel.toggleItem("pomodoros", panel.itemsStore.items.pomodoros[0].id)
      panel.addItem("alarms")
      panel.editingId = ""
      panel.activeTab = "world"
      display("worldSunrise", true)
      display("worldSunset", true)
      display("heroGoldenHour", true)
    },
    function() { panel.lapStopwatch(panel.itemsStore.items.stopwatches[0].id) },
    function() {},
    // The timer of a second and a half rings now: the banner.
    function() { shot("11-ringing-banner") },
    function() { panel.ringer.stopNewest() },
    function() { shot("10-world-map"); dumpGlyphs("10-world-map") },
    function() { display("worldStyle", "globe"); display("worldMoon", true) },
    function() { shot("12-world-globe") },
    function() { findNamed(panel.contentRoot, "timeWorld").showAt(Date.UTC(2026, 5, 21, 12, 0)) },
    function() { shot("13-world-timeline-pinned") },
    function() { findNamed(panel.contentRoot, "timeWorld").backToNow(); display("worldStyle", "map"); display("worldMoon", false) },
    function() { panel.openCitySearch(); panel.citySearch.query = "ber" },
    function() { shot("14-city-search") },
    function() { panel.searchOpen = false; panel.activeTab = "alarms" },
    function() { shot("20-alarms") },
    function() { panel.editingId = panel.itemsStore.items.alarms[0].id },
    function() { shot("21-alarm-editor"); dumpGlyphs("21-alarm-editor") },
    function() { panel.editingId = ""; panel.activeTab = "timers" },
    function() { shot("22-timers") },
    function() { panel.newTimerOpen = true },
    function() { shot("23-timer-new") },
    function() { panel.newTimerOpen = false; panel.activeTab = "stopwatches" },
    function() { shot("24-stopwatches") },
    function() { panel.activeTab = "pomodoros" },
    function() { shot("25-pomodoros") },
    function() { panel.editingId = panel.itemsStore.items.pomodoros[0].id },
    function() { shot("26-pomodoro-editor") },
    function() { panel.editingId = ""; panel.activeTab = "astro" },
    function() { shot("30-astro"); dumpGlyphs("30-astro") },
    function() {
      var a = astro()
      var jupiter = a.hits.filter(function(h) { return h.key === "jupiter" })[0]
      if (jupiter) { a.pointer = { x: jupiter.x, y: jupiter.y }; a.updateHover() }
    },
    function() { shot("31-astro-hover") },
    function() { var a = astro(); a.pointer = null; a.updateHover(); a.parent.lapseMenuOpen = true },
    function() { shot("32-astro-lapse-menu") },
    function() { var v = astro().parent; v.lapseMenuOpen = false; v.infoExpanded = true; v.eventsOpen = true },
    function() { panel.scrollBy(10000) },
    function() { shot("33-astro-info-events"); dumpGlyphs("33-astro-info-events") },
    function() { var v = astro().parent; v.infoExpanded = false; v.eventsOpen = false; panel.scrollBy(-10000) },
    function() { panel.openSettings("general") },
    function() { shot("40-settings-general"); dumpGlyphs("40-settings-general") },
    function() { panel.settingsItem.scrollBy(700) },
    function() { shot("41-settings-general-more") },
    function() { panel.settingsItem.scrollBy(10000) },
    function() { shot("42-settings-general-end") },
    function() { panel.openSettings("display"); panel.settingsTargetSurface = "app" },
    function() { shot("43-settings-display") },
    function() { panel.settingsItem.scrollBy(1400) },
    function() { shot("44-settings-display-world") },
    function() { panel.openSettings("sounds") },
    function() { shot("45-settings-sounds") },
    function() { panel.openSettings("shortcuts") },
    function() { shot("46-settings-shortcuts") },
    function() { panel.openSettings("sources") },
    function() { shot("47-settings-sources") },
    function() { panel.openSettings("changes") },
    function() { shot("48-settings-changes") },
    function() { panel.openSettings("general"); panel.settingsItem.search("moon") },
    function() { shot("49-settings-search") },
    function() { panel.settingsItem.search("xyzzy") },
    function() { shot("50-settings-search-none") },
    function() { panel.settingsItem.search(""); panel.settingsOpen = false; Qt.quit() }
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
