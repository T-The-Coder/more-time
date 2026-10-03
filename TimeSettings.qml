import QtQuick
import qs.Commons
import qs.Ui
import "I18n.js" as I18n
import "Model.js" as Model

// The settings, over the panel while open: General (language, time format,
// snooze, pomodoro lengths, app launcher, export and import), Display (per
// surface: menu bar, widget, app), Sounds (ringing sounds and chimes),
// Keyboard and Sources.
Rectangle {
  id: settingsView
  required property var panel
  anchors.fill: parent
  z: 100
  color: Color.popups.background

  MouseArea { anchors.fill: parent }

  TextMetrics { id: alwaysHeadingMetrics; font.family: panel.fontFamily; font.pixelSize: Style.font.caption; text: panel.i18n("showAlways") }
  TextMetrics { id: relevantHeadingMetrics; font.family: panel.fontFamily; font.pixelSize: Style.font.caption; text: panel.i18n("showWhenRelevant") }
  TextMetrics { id: onHoverHeadingMetrics; font.family: panel.fontFamily; font.pixelSize: Style.font.caption; text: panel.i18n("showOnHover") }
  readonly property real switchColumnWidth: Math.max(Style.space(40),
    alwaysHeadingMetrics.advanceWidth + Style.space(6),
    relevantHeadingMetrics.advanceWidth + Style.space(6),
    onHoverHeadingMetrics.advanceWidth + Style.space(6))

  // ---- General and Sounds: one list of dropdowns, drawn and walked in
  //      this order, each on its page ("sounds" or else General) ----
  // An entry is a dropdown, or with `kind` a text field ("field") or a
  // switch ("switch"); `test` adds a test button, `section` starts a section.

  function minuteOptions(values) {
    return values.map(function(m) { return { value: String(m), label: panel.i18n("minutesLong", { minutes: m }) } })
  }
  readonly property var soundOptions: panel.ringer.soundIds.map(function(id) {
    return { value: id, label: panel.i18n("sound_" + id) }
  })
  readonly property var choices: panel.displayOptionsStore.generalChoices
  // Only a new interval rebuilds the list (daily adds the hour, custom the
  // minutes), not every other general setting.
  readonly property string chimeIntervalValue: String(panel.generalSetting("chimeInterval", "quarter"))
  readonly property var generalDropdowns: {
    var list = [
      { id: "language", title: panel.i18n("language"), options: [{ value: "auto", label: panel.i18n("languageAuto",
          { language: I18n.languageName(I18n.languageForLocale(panel.localeName)) }) }]
        .concat(I18n.supportedLanguages().map(function(code) { return { value: code, label: I18n.languageName(code) } })) },
      { id: "timeFormat", title: panel.i18n("timeFormat"), options: [
        { value: "auto", label: panel.i18n("timeFormatAuto", { example: panel.wallClock(14, 30) }) },
        { value: "24", label: panel.i18n("timeFormat24") },
        { value: "12", label: panel.i18n("timeFormat12") }] },
      { id: "snoozeMinutes", title: panel.i18n("snoozeDefault"), options: minuteOptions(choices.snoozeMinutes) },
      { id: "timerPresets", title: panel.i18n("timerPresets"), kind: "field", section: "timers",
        hint: "timerPresetsHint", fieldWidth: Style.space(260),
        parse: function(text) { var list = Model.parseTimerPresets(text); return list ? list.join(",") : null } },
      { id: "detectLocation", title: panel.i18n("detectLocation"), kind: "switch", section: "location",
        hint: "detectLocationHint" },
      { id: "alarmSound", page: "sounds", title: panel.i18n("alarmSound"), options: soundOptions, test: true, section: "sounds" },
      { id: "timerSound", page: "sounds", title: panel.i18n("timerSound"), options: soundOptions, test: true },
      { id: "pomodoroSound", page: "sounds", title: panel.i18n("pomodoroSound"), options: soundOptions, test: true },
      { id: "volume", page: "sounds", title: panel.i18n("volume"), options: choices.volume.map(function(v) { return { value: String(v), label: v + " %" } }) },
      { id: "chimeInterval", page: "sounds", title: panel.i18n("chimeInterval"), test: true, section: "chimes", options: [
        { value: "off", label: panel.i18n("chimeOff") },
        { value: "minute", label: panel.i18n("chimeEveryMinute") },
        { value: "quarter", label: panel.i18n("chimeEveryQuarter") },
        { value: "hour", label: panel.i18n("chimeEveryHour") },
        { value: "daily", label: panel.i18n("chimeDaily") },
        { value: "custom", label: panel.i18n("chimeCustom") }] }
    ]
    var interval = chimeIntervalValue
    if (interval === "daily") list.push({ id: "chimeDailyHour", page: "sounds", title: panel.i18n("chimeDailyTime"),
      options: choices.chimeDailyHour.map(function(h) { return { value: String(h), label: panel.wallClock(h, 0) } }) })
    if (interval === "custom") list.push({ id: "chimeMinutes", page: "sounds", title: panel.i18n("chimeCustomMinutes"), kind: "field",
      hint: "chimeCustomHint", parse: function(text) { return Model.chimeMinutesValue(text) || null } })
    list = list.concat([
      { id: "chimeTone", page: "sounds", title: panel.i18n("chimeTone"), test: true, options: [
        { value: "beep", label: panel.i18n("chimeTone_beep") },
        { value: "bell", label: panel.i18n("chimeTone_bell") },
        { value: "wood", label: panel.i18n("chimeTone_wood") },
        { value: "chirp", label: panel.i18n("chimeTone_chirp") },
        { value: "glass", label: panel.i18n("chimeTone_glass") }] },
      { id: "hourChime", page: "sounds", title: panel.i18n("hourChime"), test: true, options: [
        { value: "off", label: panel.i18n("chimeOff") },
        { value: "12", label: panel.i18n("hourChime12") },
        { value: "24", label: panel.i18n("hourChime24") }] },
      { id: "chimeVolume", page: "sounds", title: panel.i18n("chimeVolume"), options: choices.chimeVolume.map(function(v) { return { value: String(v), label: v + " %" } }) },
      { id: "chimesMuted", page: "sounds", title: panel.i18n("chimesMute"), kind: "switch" },
      { id: "pomodoroWork", title: panel.i18n("focusPhase"), options: minuteOptions(choices.pomodoroWork), section: "pomodoro" },
      { id: "pomodoroBreak", title: panel.i18n("breakPhase"), options: minuteOptions(choices.pomodoroBreak) },
      { id: "pomodoroLongBreak", title: panel.i18n("longBreakPhase"), options: minuteOptions(choices.pomodoroLongBreak) },
      { id: "pomodoroLongEvery", title: panel.i18n("longBreakEvery"), options: choices.pomodoroLongEvery.map(function(n) {
        return { value: String(n), label: n > 0 ? panel.i18n("everyRounds", { count: n }) : panel.i18n("never") } }) }
    ])
    if (barPositionUsable) list.splice(2, 0, { id: "barPosition", title: panel.i18n("barPosition"), options: [
      { value: "left", label: panel.i18n(panel.barPlacement.verticalBar ? "barPositionTop" : "barPositionLeft") },
      { value: "center", label: panel.i18n("barPositionCenter") },
      { value: "right", label: panel.i18n(panel.barPlacement.verticalBar ? "barPositionBottom" : "barPositionRight") }] })
    return list
  }
  readonly property var generalPageEntries: generalDropdowns.filter(function(e) { return e.page !== "sounds" })
  readonly property var soundsPageEntries: generalDropdowns.filter(function(e) { return e.page === "sounds" })
  readonly property bool barPositionUsable: panel.barPlacement.section !== "" && !panel.barPlacement.busy
  property var dropdownItems: ({})
  property var fieldItems: ({})
  readonly property var sectionTitles: ({ sounds: "sounds", chimes: "chimes", pomodoro: "pomodoroDefaults",
    location: "location", timers: "timersTab" })
  readonly property var sectionHints: ({ chimes: "chimesHint", pomodoro: "pomodoroDefaultsHint",
    location: "locationHint" })

  // The test buttons: an alarm, timer or pomodoro sound, one interval beep
  // (interval and tone), or the hour chime of this hour, in the chosen tone.
  function testUsable(id) {
    if (id === "chimeTone") return true
    if (id === "chimeInterval" || id === "hourChime") return dropdownValue(id) !== "off"
    return dropdownValue(id) !== "none"
  }

  function runTest(id) {
    if (!testUsable(id)) return
    if (id === "chimeInterval" || id === "hourChime" || id === "chimeTone") panel.ringer.testChime(id)
    else panel.ringer.testSound(dropdownValue(id))
  }

  // A text field's setting (custom chime minutes, timer presets): kept when
  // the entry's parse() takes it, else the field shows the setting again.
  function commitField(entry, field) {
    var value = entry.parse(field.text)
    if (value !== null) panel.displayOptionsStore.setGeneralSetting(entry.id, value)
    field.text = dropdownValue(entry.id)
  }

  function dropdownValue(id) {
    if (id === "barPosition") return panel.barPlacement.section
    return String(panel.generalSetting(id, panel.displayOptionsStore.generalDefaults[id]))
  }

  function setDropdown(id, value) {
    if (id === "barPosition") panel.barPlacement.moveTo(value)
    // The list is rebuilt with it, the dropdown too: not from inside its
    // own signal.
    else if (id === "chimeInterval") panel.defer(function() { panel.displayOptionsStore.setGeneralSetting(id, value) })
    else panel.displayOptionsStore.setGeneralSetting(id, value)
  }

  function dropdownSpec(id) {
    if (id === "defaultTab") return {
      options: panel.settingsTabs.map(function(key) { return { value: key, label: panel.i18n(key + "Tab") } }),
      value: panel.settingsDefaultTab,
      set: function(value) { panel.displayOptionsStore.setSettingsDisplaySetting("defaultTab", value) }
    }
    // Display options with a few values (TimeOptionDropdown).
    var choiceOption = tabOptions.world.concat(heroOptions, menubarChoices).filter(function(o) { return o.key === id && o.choices })[0]
    if (choiceOption) return {
      options: choiceOption.choices,
      value: String(panel.settingsDisplaySetting(id, "")),
      set: function(value) { panel.displayOptionsStore.setSettingsDisplaySetting(id, value) }
    }
    for (var i = 0; i < generalDropdowns.length; i++) {
      if (generalDropdowns[i].id !== id) continue
      return { options: generalDropdowns[i].options, value: dropdownValue(id),
        set: function(value) { settingsView.setDropdown(id, value) } }
    }
    return null
  }

  // ---- Display: cards per surface ----

  // The menu bar's options with a few values, drawn by TimeOptionDropdown.
  readonly property var menubarChoices: [
    { key: "menubarAccents", title: panel.i18n("menubarAccents"), choices: [
      { value: "off", label: panel.i18n("menubarAccents_off") },
      { value: "hover", label: panel.i18n("menubarAccents_hover") },
      { value: "always", label: panel.i18n("menubarAccents_always") }] },
    { key: "citiesCount", title: panel.i18n("citiesCount"),
      choices: ["1", "2", "3", "4"].map(function(n) { return { value: n, label: n } }) }
  ]

  readonly property var heroOptions: [
    { key: "heroSeconds", title: panel.i18n("optionSeconds") },
    { key: "heroDate", title: panel.i18n("optionDate") },
    { key: "heroWeek", title: panel.i18n("optionWeek") },
    { key: "heroDayOfYear", title: panel.i18n("optionDayOfYear") },
    { key: "heroZone", title: panel.i18n("optionZone") },
    { key: "heroAnalog", title: panel.i18n("optionAnalog") },
    { key: "heroDial", title: panel.i18n("optionHeroDial"), dependsOn: "heroAnalog", choices: [
      { value: "place", label: panel.i18n("heroDialPlace") }, { value: "classic", label: panel.i18n("dial_classic") },
      { value: "minimal", label: panel.i18n("dial_minimal") }, { value: "roman", label: panel.i18n("dial_roman") },
      { value: "twentyFour", label: panel.i18n("dial_twentyFour") }, { value: "dots", label: panel.i18n("dial_dots") }] },
    { key: "heroSun", title: panel.i18n("optionSun") },
    { key: "heroSunNext", title: panel.i18n("sunNext") },
    { key: "heroGoldenHour", title: panel.i18n("optionGoldenHour"), hint: "optionGoldenHourHint" },
    { key: "heroBlueHour", title: panel.i18n("optionBlueHour"), hint: "optionBlueHourHint" },
    { key: "heroNextAlarm", title: panel.i18n("optionNextAlarm") },
    { key: "heroPomodoroTally", title: panel.i18n("optionPomodoroTally") }
  ]
  readonly property var tabOptions: ({
    world: [
      { key: "worldMap", title: panel.i18n("optionMap") },
      { key: "worldStyle", title: panel.i18n("optionMapStyle"), dependsOn: "worldMap", choices: [
        { value: "map", label: panel.i18n("mapStyleFlat") }, { value: "globe", label: panel.i18n("mapStyleGlobe") }] },
      { key: "worldNight", title: panel.i18n("optionNight"), dependsOn: "worldMap", hint: panel.i18n("optionNightHint") },
      { key: "worldRuler", title: panel.i18n("optionRuler"), dependsOn: "worldMap", style: "map" },
      { key: "worldMapLabels", title: panel.i18n("optionMapLabels"), dependsOn: "worldMap" },
      { key: "worldMoon", title: panel.i18n("moon"), dependsOn: "worldMap" },
      { key: "worldMoonStyle", title: panel.i18n("optionMoonStyle"), dependsOn: "worldMoon", choices: [
        { value: "space", label: panel.i18n("moonStyleSpace") }, { value: "earth", label: panel.i18n("moonStyleEarth") }] },
      { key: "globeAutoRotate", title: panel.i18n("optionGlobeAutoRotate"), dependsOn: "worldMap", style: "globe",
        hint: panel.i18n("optionGlobeAutoRotateHint") },
      { key: "globeRotateDelay", title: panel.i18n("optionGlobeRotateDelay"), dependsOn: "globeAutoRotate", style: "globe",
        choices: ["5", "10", "30"].map(function(n) { return { value: n, label: panel.i18n("secondsShort", { seconds: n }) } }) },
      { key: "globeRotateSpeed", title: panel.i18n("optionGlobeRotateSpeed"), dependsOn: "globeAutoRotate", style: "globe",
        choices: ["1", "2", "4", "8"].map(function(n) { return { value: n, label: panel.i18n("minutesShort", { minutes: n }) } }) },
      { key: "globeRotateFps", title: panel.i18n("optionRotateFps"), dependsOn: "globeAutoRotate", style: "globe",
        hint: panel.i18n("optionRotateFpsHint"), choices: ["8", "15", "24", "30"].map(function(n) { return { value: n, label: n } }) },
      { key: "worldList", title: panel.i18n("optionCityList") },
      { key: "worldDifference", title: panel.i18n("optionDifference"), dependsOn: "worldList" },
      { key: "worldDials", title: panel.i18n("optionWorldDials"), dependsOn: "worldList" },
      { key: "worldSunrise", title: panel.i18n("sunrise"), dependsOn: "worldList" },
      { key: "worldSunset", title: panel.i18n("sunset"), dependsOn: "worldList" },
      { key: "worldSunNext", title: panel.i18n("sunNext"), dependsOn: "worldList" }
    ],
    alarms: [],
    timers: [],
    stopwatches: [{ key: "stopwatchHundredths", title: panel.i18n("optionHundredths") }],
    pomodoros: [],
    astro: [
      { key: "astroOrbits", title: panel.i18n("optionAstroOrbits") },
      { key: "astroNames", title: panel.i18n("optionAstroNames") },
      { key: "astroMonthRing", title: panel.i18n("optionAstroMonthRing"), hint: panel.i18n("optionAstroMonthRingHint") },
      { key: "astroAutoRotate", title: panel.i18n("optionAstroAutoRotate"), hint: panel.i18n("optionGlobeAutoRotateHint") },
      { key: "astroRotateDelay", title: panel.i18n("optionGlobeRotateDelay"), dependsOn: "astroAutoRotate",
        choices: ["5", "10", "30"].map(function(n) { return { value: n, label: panel.i18n("secondsShort", { seconds: n }) } }) },
      { key: "astroRotateSpeed", title: panel.i18n("optionGlobeRotateSpeed"), dependsOn: "astroAutoRotate",
        choices: ["1", "2", "4", "8"].map(function(n) { return { value: n, label: panel.i18n("minutesShort", { minutes: n }) } }) },
      { key: "astroRotateFps", title: panel.i18n("optionRotateFps"), dependsOn: "astroAutoRotate",
        hint: panel.i18n("optionRotateFpsHint"), choices: ["8", "15", "24", "30"].map(function(n) { return { value: n, label: n } }) }
    ]
  })
  // A tab option can be set when its switch (dependsOn) is on and, with
  // `style`, the map is drawn in that style.
  function optionAvailable(option) {
    if (option.dependsOn && !panel.settingsDisplaySetting(option.dependsOn, true)) return false
    return !option.style || panel.settingsDisplaySetting("worldStyle", "map") === option.style
  }
  // Menu bar rows in the bar's order; seconds ride along with the time.
  readonly property var menubarOptions: {
    var order = panel.settingsOrderFor("entryOrder")
    var list = []
    for (var i = 0; i < order.length; i++) {
      var key = order[i]
      list.push({ key: key, title: panel.i18n("entry_" + key), relevant: panel.relevantEntries.indexOf(key) >= 0, orderable: true })
      if (key === "time") list.push({ key: "seconds", title: panel.i18n("entry_seconds"), relevant: false, orderable: false })
    }
    return list
  }

  // ---- Keyboard: one flat list of what can be set on the page, in the
  //      order it is drawn; ↑↓ walk it, ←→ change the value or the column,
  //      Space / Enter switch or open, ⇧↑↓ move an entry.
  property string focusId: ""
  property int focusColumn: 0
  onFocusIdChanged: focusColumn = 0

  function entryFocusItems(entries) {
    var items = []
    for (var i = 0; i < entries.length; i++) {
      var kind = entries[i].kind
      items.push({ id: entries[i].id, type: kind === "field" ? "field" : (kind === "switch" ? "general" : "dropdown") })
      if (entries[i].test) items.push({ id: "test:" + entries[i].id, type: "test" })
    }
    return items
  }

  readonly property var focusItems: {
    var items = []
    if (panel.settingsPage === "sounds") return entryFocusItems(soundsPageEntries)
    if (panel.settingsPage === "general") {
      items = entryFocusItems(generalPageEntries)
      items.push({ id: "pomodoroAuto", type: "general" }, { id: "launcher", type: "launcher" },
        { id: "transferPath", type: "path" }, { id: "exportSettings", type: "button" },
        { id: "importSettings", type: "button" })
      if (panel.placesImport.available) items.push({ id: "importPlaces", type: "button" })
      if (!panel.displayOptionsStore.generalIsDefault()) items.push({ id: "restoreGeneral", type: "button" })
      return items
    }
    if (panel.settingsPage !== "display") return []
    if (panel.settingsTargetSurface === "menubar") {
      items.push({ id: "master:showClock", type: "switch", key: "showClock" })
      if (panel.settingsDisplaySetting("showClock", true)) {
        for (var m = 0; m < menubarOptions.length; m++) {
          var option = menubarOptions[m]
          items.push({ id: "switch:" + option.key, type: "switch", key: option.key,
            relevantKey: option.relevant ? option.key + "WhenRelevant" : "", hoverKey: option.key + "OnHover",
            orderListKey: option.orderable ? "entryOrder" : "", orderEntry: option.orderable ? option.key : "" })
        }
        items.push({ id: "switch:boldOnHover", type: "switch", key: "boldOnHover" },
          { id: "menubarAccents", type: "dropdown" },
          { id: "switch:hoverTooltip", type: "switch", key: "hoverTooltip" },
          { id: "switch:openWidgetOnHover", type: "switch", key: "openWidgetOnHover" },
          { id: "citiesCount", type: "dropdown" })
      }
    } else {
      for (var h = 0; h < heroOptions.length; h++) {
        if (!optionAvailable(heroOptions[h])) continue
        items.push(heroOptions[h].choices ? { id: heroOptions[h].key, type: "dropdown" }
          : { id: "switch:" + heroOptions[h].key, type: "switch", key: heroOptions[h].key })
      }
      var tabs = panel.settingsOrderFor("tabOrder")
      for (var t = 0; t < tabs.length; t++) {
        var master = panel.tabMasterKeys[tabs[t]]
        items.push({ id: "master:" + master, type: "switch", key: master, orderListKey: "tabOrder", orderEntry: tabs[t] })
        if (!panel.settingsDisplaySetting(master, true)) continue
        var options = tabOptions[tabs[t]]
        for (var o = 0; o < options.length; o++) {
          if (!optionAvailable(options[o])) continue
          items.push(options[o].choices ? { id: options[o].key, type: "dropdown" }
            : { id: "switch:" + options[o].key, type: "switch", key: options[o].key })
        }
      }
      if (panel.settingsTabs.length > 1) items.push({ id: "defaultTab", type: "dropdown" })
    }
    if (!panel.settingsOrderIsDefault) items.push({ id: "restoreOrder", type: "button" })
    if (!panel.displayOptionsStore.settingsDisplayIsDefault()) items.push({ id: "restoreDefaults", type: "button" })
    return items
  }
  readonly property var focusItem: {
    for (var i = 0; i < focusItems.length; i++) if (focusItems[i].id === focusId) return focusItems[i]
    return null
  }

  function switchColumns(item) {
    var columns = [item.key]
    if (item.hoverKey) {
      columns.push(item.relevantKey || "")
      columns.push(item.hoverKey)
    }
    return columns
  }

  function moveFocus(delta) {
    if (!focusItems.length) return
    var index = -1
    for (var i = 0; i < focusItems.length; i++) if (focusItems[i].id === focusId) index = i
    var next = index < 0 ? (delta > 0 ? 0 : focusItems.length - 1)
      : Math.max(0, Math.min(focusItems.length - 1, index + delta))
    focusId = focusItems[next].id
  }

  function stepDropdown(id, delta) {
    var spec = dropdownSpec(id)
    if (!spec) return
    var index = 0
    for (var i = 0; i < spec.options.length; i++) if (spec.options[i].value === spec.value) index = i
    var next = Math.max(0, Math.min(spec.options.length - 1, index + delta))
    if (next !== index) spec.set(spec.options[next].value)
  }

  function changeValue(item, delta) {
    if (item.type === "dropdown") stepDropdown(item.id, delta)
    else if (item.type === "switch") {
      var columns = switchColumns(item)
      var next = focusColumn + delta
      if (next === 1 && columns[1] === "") next += delta
      if (next >= 0 && next < columns.length) focusColumn = next
    }
  }

  function activate(item) {
    if (item.type === "dropdown") {
      var dropdown = dropdownItems[item.id]
      if (dropdown) dropdown.open()
    } else if (item.type === "test") {
      runTest(item.id.slice(5))
    } else if (item.type === "general") {
      panel.displayOptionsStore.setGeneralSetting(item.id,
        !panel.generalSetting(item.id, panel.displayOptionsStore.generalDefaults[item.id]))
    } else if (item.type === "field") {
      if (fieldItems[item.id]) fieldItems[item.id].forceActiveFocus()
    } else if (item.type === "launcher") {
      if (!panel.appLauncherEntry.busy) panel.appLauncherEntry.setInstalled(!panel.appLauncherEntry.installed)
    } else if (item.type === "switch") {
      var key = switchColumns(item)[focusColumn] || ""
      if (key === "") return
      panel.displayOptionsStore.setSettingsDisplaySetting(key,
        !(panel.settingsDisplaySetting(key, key === item.key) === true))
    } else if (item.type === "path") {
      transferPathField.forceActiveFocus()
    } else if (item.id === "exportSettings") exportButton.press()
    else if (item.id === "importSettings") importButton.press()
    else if (item.id === "importPlaces") importPlacesButton.press()
    else if (item.id === "restoreGeneral") restoreGeneralButton.press()
    else if (item.id === "restoreOrder") restoreOrderButton.press()
    else if (item.id === "restoreDefaults") restoreDefaultsButton.press()
  }

  function reorder(item, delta) {
    if (!item || !item.orderListKey || !item.orderEntry) return
    panel.displayOptionsStore.moveSettingsDisplayEntry(item.orderListKey, item.orderEntry, delta)
  }

  function ensureVisible(target) {
    if (!target) return
    panel.defer(function() {
      var top = target.mapToItem(settingsColumn, 0, 0).y - Style.space(8)
      var bottom = top + target.height + Style.space(16)
      var maximum = Math.max(0, settingsFlick.contentHeight - settingsFlick.height)
      if (top < settingsFlick.contentY) settingsFlick.contentY = Math.max(0, top)
      else if (bottom > settingsFlick.contentY + settingsFlick.height)
        settingsFlick.contentY = Math.min(maximum, bottom - settingsFlick.height)
    })
  }

  function scrollBy(delta) {
    var maximum = Math.max(0, settingsFlick.contentHeight - settingsFlick.height)
    settingsFlick.contentY = Math.max(0, Math.min(maximum, settingsFlick.contentY + delta))
  }

  // Returns true when the key was used.
  function handleKey(event) {
    var control = !!(event.modifiers & Qt.ControlModifier)
    var alternate = !!(event.modifiers & (Qt.AltModifier | Qt.MetaModifier))
    if (control || alternate) return false
    var shift = !!(event.modifiers & Qt.ShiftModifier)
    var text = String(event.text || "")
    var key = event.key

    if (key === Qt.Key_Tab || key === Qt.Key_Backtab) {
      panel.stepSettingsPage(shift || key === Qt.Key_Backtab ? -1 : 1)
      focusId = ""
      settingsFlick.contentY = 0
      return true
    }
    if (key === Qt.Key_PageDown || key === Qt.Key_PageUp) {
      scrollBy((key === Qt.Key_PageDown ? 1 : -1) * settingsFlick.height * 0.9)
      return true
    }
    if (key === Qt.Key_Home || key === Qt.Key_End) {
      scrollBy(key === Qt.Key_Home ? -settingsFlick.contentHeight : settingsFlick.contentHeight)
      return true
    }
    var down = key === Qt.Key_Down || text === "j" || text === "J"
    var up = key === Qt.Key_Up || text === "k" || text === "K"
    if (panel.settingsPage !== "display" && panel.settingsPage !== "general" && panel.settingsPage !== "sounds") {
      if (down || up) {
        scrollBy((down ? 1 : -1) * Style.space(48))
        return true
      }
      return false
    }
    if (panel.settingsPage === "display" && (text === "1" || text === "2" || text === "3")) {
      panel.settingsTargetSurface = ["menubar", "widget", "app"][Number(text) - 1]
      focusId = ""
      return true
    }
    if (down || up) {
      if (shift || text === "J" || text === "K") reorder(focusItem, down ? 1 : -1)
      else moveFocus(down ? 1 : -1)
      return true
    }
    var left = key === Qt.Key_Left || text === "h"
    var right = key === Qt.Key_Right || text === "l"
    if (left || right) {
      if (focusItem) changeValue(focusItem, right ? 1 : -1)
      return true
    }
    if (key === Qt.Key_Space || key === Qt.Key_Return || key === Qt.Key_Enter) {
      if (focusItem) activate(focusItem)
      else moveFocus(1)
      return true
    }
    return false
  }

  component SectionTitle: Text {
    textFormat: Text.PlainText
    color: settingsView.panel.foreground
    font.family: settingsView.panel.fontFamily
    font.pixelSize: Style.font.bodySmall
    font.bold: true
    font.letterSpacing: 1
  }

  component Hint: Text {
    textFormat: Text.PlainText
    width: parent ? parent.width : 0
    color: settingsView.panel.mutedText
    font.family: settingsView.panel.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  component Card: Rectangle {
    default property alias content: cardColumn.data
    width: settingsColumn.width
    height: cardColumn.implicitHeight + Style.space(20)
    radius: Style.cornerRadius
    color: "transparent"
    border.color: settingsView.panel.subtleText
    border.width: Style.spacing.hairline

    Column {
      id: cardColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.space(10)
      spacing: 0
    }
  }

  // One entry of the General or Sounds list (see generalDropdowns).
  Component {
    id: settingRow

    Column {
      id: dropdownRow
      required property var modelData
      required property int index
      readonly property string kind: modelData.kind || "dropdown"
      width: parent.width
      spacing: Style.space(4)

      SectionTitle {
        visible: !!dropdownRow.modelData.section
        topPadding: dropdownRow.index > 0 ? Style.space(10) : 0
        text: dropdownRow.modelData.section
          ? panel.upperLabel(panel.i18n(settingsView.sectionTitles[dropdownRow.modelData.section])) : ""
      }
      Hint {
        visible: !!settingsView.sectionHints[dropdownRow.modelData.section || ""]
        text: visible ? panel.i18n(settingsView.sectionHints[dropdownRow.modelData.section]) : ""
      }

      Text {
        textFormat: Text.PlainText
        visible: dropdownRow.kind !== "switch"
        text: dropdownRow.modelData.title
        color: panel.mutedText
        font.family: panel.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      Row {
        visible: dropdownRow.kind !== "switch"
        spacing: Style.space(8)

        Dropdown {
          id: dropdown
          visible: dropdownRow.kind === "dropdown"
          width: Math.min(dropdownRow.width - (testButton.visible ? testButton.width + Style.space(8) : 0), Style.space(280))
          showLabel: false
          fontFamily: panel.fontFamily
          hasCursor: settingsView.focusId === dropdownRow.modelData.id
          onHasCursorChanged: if (hasCursor) settingsView.ensureVisible(this)
          onPopupOpenChanged: if (!popupOpen) panel.restoreKeyFocus()
          value: visible ? settingsView.dropdownValue(dropdownRow.modelData.id) : ""
          options: dropdownRow.modelData.options || []
          onChanged: function(value) { settingsView.setDropdown(dropdownRow.modelData.id, value) }
          Component.onCompleted: {
            if (dropdownRow.kind !== "dropdown") return
            var items = Object.assign({}, settingsView.dropdownItems)
            items[dropdownRow.modelData.id] = dropdown
            settingsView.dropdownItems = items
          }
        }

        // A typed value (custom chime minutes, timer presets), checked by the
        // entry's parse().
        TextField {
          id: numberField
          readonly property bool valid: dropdownRow.kind !== "field" || text === ""
            || dropdownRow.modelData.parse(text) !== null
          visible: dropdownRow.kind === "field"
          width: dropdownRow.modelData.fieldWidth || Style.space(110)
          text: visible ? settingsView.dropdownValue(dropdownRow.modelData.id) : ""
          foreground: panel.foreground
          font.family: panel.fontFamily
          hasCursor: settingsView.focusId === dropdownRow.modelData.id
          onHasCursorChanged: if (hasCursor) settingsView.ensureVisible(this)
          // Enter keeps the number, Esc drops it; both hand the keys
          // back to the settings, as does leaving the field.
          onAccepted: panel.restoreKeyFocus()
          onActiveFocusChanged: if (!activeFocus && visible) settingsView.commitField(dropdownRow.modelData, numberField)
          Keys.onEscapePressed: {
            numberField.text = settingsView.dropdownValue(dropdownRow.modelData.id)
            panel.restoreKeyFocus()
          }
          Component.onCompleted: {
            if (dropdownRow.kind !== "field") return
            var items = Object.assign({}, settingsView.fieldItems)
            items[dropdownRow.modelData.id] = numberField
            settingsView.fieldItems = items
          }
        }

        TimeButton {
          id: testButton
          visible: !!dropdownRow.modelData.test
          panel: settingsView.panel
          label: "\u{f040a}  " + panel.i18n("testSound")
          enabled: settingsView.testUsable(dropdownRow.modelData.id)
          kbFocused: settingsView.focusId === "test:" + dropdownRow.modelData.id
          onActivated: settingsView.runTest(dropdownRow.modelData.id)
        }
      }


      TimeSwitchRow {
        visible: dropdownRow.kind === "switch"
        panel: settingsView.panel
        title: dropdownRow.modelData.title
        indented: false
        switchState: visible && panel.generalSetting(dropdownRow.modelData.id,
          panel.displayOptionsStore.generalDefaults[dropdownRow.modelData.id]) === true
        kbFocused: settingsView.focusId === dropdownRow.modelData.id
        onKbFocusedChanged: if (kbFocused) settingsView.ensureVisible(this)
        onToggled: function(value) { panel.displayOptionsStore.setGeneralSetting(dropdownRow.modelData.id, value) }
      }

      // Red while a typed value is not one the field takes.
      Hint {
        visible: !!dropdownRow.modelData.hint
        text: visible ? panel.i18n(dropdownRow.modelData.hint) : ""
        color: numberField.valid ? panel.mutedText : Color.urgent
      }
    }
  }

  // The wheel scrolls a fixed step, touchpads their scaled pixel deltas
  // (Panel.wheelPixels), as in More Weather.
  MouseArea {
    anchors.fill: settingsFlick
    z: 2
    acceptedButtons: Qt.NoButton
    onWheel: function(wheel) {
      settingsView.scrollBy(-panel.wheelPixels(wheel, false))
      wheel.accepted = true
    }
  }

  Flickable {
    id: settingsFlick
    anchors.fill: parent
    anchors.margins: Style.space(4)
    z: 1
    contentWidth: width
    contentHeight: settingsColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height

    Column {
      id: settingsColumn
      width: parent.width
      spacing: Style.space(12)

      Item {
        width: parent.width
        height: Style.space(48)

        Column {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          Text {
            textFormat: Text.PlainText
            text: panel.i18n("settings")
            color: panel.foreground
            font.family: panel.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            textFormat: Text.PlainText
            text: panel.settingsPage === "shortcuts" ? panel.i18n("shortcutsSubtitle")
              : (panel.settingsPage === "general" ? panel.i18n("generalSubtitle")
              : (panel.settingsPage === "sources" ? panel.i18n("sourcesSubtitle")
              : panel.settingsPage === "sounds" ? panel.i18n("soundsSubtitle")
                : panel.i18n(panel.settingsTargetSurface + "Settings")))
            color: panel.mutedText
            font.family: panel.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        TimeIconButton {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          panel: settingsView.panel
          glyph: "✕"
          glyphSize: Style.font.body
          onActivated: panel.settingsOpen = false
        }
      }

      // Pages, styled like the view's tabs so they read as navigation.
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(5)

        Repeater {
          model: panel.settingsPages

          Rectangle {
            required property string modelData
            readonly property bool selected: panel.settingsPage === modelData
            // Five pages share the popup's width: narrower than 96 when
            // needed, never narrower than the name.
            width: Math.max(pageLabel.implicitWidth + Style.space(12), Math.min(Style.space(96),
              Math.max(pageLabel.implicitWidth + Style.space(20),
                (settingsColumn.width - Style.space(5) * (panel.settingsPages.length - 1)) / panel.settingsPages.length)))
            height: Style.space(28)
            radius: Style.cornerRadius
            color: selected || pageMouse.containsMouse ? Style.hoverFillFor(panel.foreground, Color.accent) : "transparent"

            Text {
              textFormat: Text.PlainText
              id: pageLabel
              anchors.centerIn: parent
              text: panel.upperLabel(panel.i18n("settingsPage_" + parent.modelData))
              color: parent.selected ? Style.hoverStateColor(panel.foreground, Color.accent) : panel.mutedText
              font.family: panel.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: parent.selected
              font.letterSpacing: 1
            }

            MouseArea {
              id: pageMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                panel.settingsPage = parent.modelData
                settingsView.focusId = ""
              }
            }
          }
        }
      }

      Text {
        textFormat: Text.PlainText
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: panel.i18n("settingsPagesKeysHint")
        color: panel.hintText
        font.family: panel.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      TimeShortcutsPage {
        visible: panel.settingsPage === "shortcuts"
        width: parent.width
        panel: settingsView.panel
      }

      TimeSourcesPage {
        visible: panel.settingsPage === "sources"
        width: parent.width
        panel: settingsView.panel
      }

      // ================= General =================

      Text {
        textFormat: Text.PlainText
        visible: panel.settingsPage === "general" || panel.settingsPage === "sounds"
        width: parent.width
        text: panel.i18n("settingsGeneralKeysHint")
        color: panel.hintText
        font.family: panel.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      Card {
        visible: panel.settingsPage === "general"

        Column {
          width: parent.width
          spacing: Style.space(6)

          SectionTitle { text: panel.upperLabel(panel.i18n("general")) }

          Repeater {
            model: settingsView.generalPageEntries
            delegate: settingRow
          }

          TimeSwitchRow {
            panel: settingsView.panel
            title: panel.i18n("autoContinue")
            indented: false
            switchState: panel.generalSetting("pomodoroAuto", true)
            kbFocused: settingsView.focusId === "pomodoroAuto"
            onKbFocusedChanged: if (kbFocused) settingsView.ensureVisible(this)
            onToggled: function(value) { panel.displayOptionsStore.setGeneralSetting("pomodoroAuto", value) }
          }
          Hint { text: panel.i18n("autoContinueHint") }

          SectionTitle { topPadding: Style.space(10); text: panel.upperLabel(panel.i18n("app")) }

          // Adds the standalone app to the app launcher. Off by default: the
          // plugin writes nothing outside its own settings without consent.
          TimeSwitchRow {
            panel: settingsView.panel
            kbFocused: settingsView.focusId === "launcher"
            onKbFocusedChanged: if (kbFocused) settingsView.ensureVisible(this)
            title: panel.i18n("appLauncherEntry")
            switchState: panel.appLauncherEntry.installed
            indented: false
            rowEnabled: !panel.appLauncherEntry.busy
            onToggled: function(value) { panel.appLauncherEntry.setInstalled(value) }
          }
          Hint { text: panel.i18n("appLauncherEntryHint") }

          SectionTitle { topPadding: Style.space(10); text: panel.upperLabel(panel.i18n("settingsTransfer")) }

          Text {
            textFormat: Text.PlainText
            text: panel.i18n("settingsTransferFile")
            color: panel.mutedText
            font.family: panel.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          TextField {
            id: transferPathField
            width: Math.min(parent.width, Style.space(460))
            text: panel.settingsTransfer.shown(panel.settingsTransfer.defaultPath)
            foreground: panel.foreground
            font.family: panel.fontFamily
            hasCursor: settingsView.focusId === "transferPath"
            onHasCursorChanged: if (hasCursor) settingsView.ensureVisible(this)
            // Enter or Esc hand the keys back to the settings.
            onAccepted: panel.restoreKeyFocus()
            Keys.onEscapePressed: panel.restoreKeyFocus()
          }

          Row {
            spacing: Style.space(10)

            TimeButton {
              id: exportButton
              panel: settingsView.panel
              enabled: !panel.settingsTransfer.busy
              label: panel.i18n("settingsExport")
              kbFocused: settingsView.focusId === "exportSettings"
              onKbFocusedChanged: if (kbFocused) settingsView.ensureVisible(this)
              onActivated: panel.settingsTransfer.exportTo(transferPathField.text)
            }

            TimeButton {
              id: importButton
              panel: settingsView.panel
              enabled: !panel.settingsTransfer.busy
              label: panel.i18n("settingsImport")
              confirmLabel: panel.i18n("settingsImportConfirm")
              kbFocused: settingsView.focusId === "importSettings"
              onKbFocusedChanged: if (kbFocused) settingsView.ensureVisible(this)
              onActivated: panel.settingsTransfer.importFrom(transferPathField.text)
            }
          }

          Text {
            textFormat: Text.PlainText
            readonly property var status: panel.settingsTransfer.status
            visible: status !== null
            width: parent.width
            text: status ? panel.i18n(status.key, { path: panel.settingsTransfer.shown(status.path),
              backup: panel.settingsTransfer.shown(panel.settingsTransfer.backupPath) }) : ""
            color: status && status.error ? Color.urgent : panel.foreground
            font.family: panel.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WrapAnywhere
          }

          Hint { text: panel.i18n("settingsTransferHint", { backup: panel.settingsTransfer.shown(panel.settingsTransfer.backupPath) }) }

          // Places: More Weather's saved places as cities.
          SectionTitle { topPadding: Style.space(10); text: panel.upperLabel(panel.i18n("placesSettings")) }

          TimeButton {
            id: importPlacesButton
            panel: settingsView.panel
            enabled: panel.placesImport.available && !panel.placesImport.busy
            label: panel.i18n("importPlacesFromWeather")
            kbFocused: settingsView.focusId === "importPlaces"
            onKbFocusedChanged: if (kbFocused) settingsView.ensureVisible(this)
            onActivated: panel.placesImport.run()
          }

          // How the last import went.
          Text {
            textFormat: Text.PlainText
            readonly property var status: panel.placesImport.status
            visible: status !== null || panel.placesImport.busy
            width: parent.width
            text: panel.placesImport.busy ? panel.i18n("searching")
              : (status ? panel.i18n("importCitiesResult", { added: status.added, existing: status.existing })
                + (status.full ? "  ·  " + panel.i18n("citiesFull") : "") : "")
            color: panel.foreground
            font.family: panel.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
          }

          Hint { text: panel.i18n(panel.placesImport.available ? "importPlacesHint" : "importPlacesMissing") }

          TimeButton {
            id: restoreGeneralButton
            visible: !panel.displayOptionsStore.generalIsDefault()
            panel: settingsView.panel
            label: panel.i18n("restoreGeneralDefaults")
            confirmLabel: panel.i18n("restoreConfirm")
            kbFocused: settingsView.focusId === "restoreGeneral"
            onKbFocusedChanged: if (kbFocused) settingsView.ensureVisible(this)
            onActivated: panel.displayOptionsStore.restoreGeneralDefaults()
          }
        }
      }

      // ================= Sounds =================

      Card {
        visible: panel.settingsPage === "sounds"

        Column {
          width: parent.width
          spacing: Style.space(6)

          Repeater {
            model: settingsView.soundsPageEntries
            delegate: settingRow
          }
        }
      }

      // ================= Display =================

      // Menu bar, widget, app: the profile these cards edit.
      Item {
        visible: panel.settingsPage === "display"
        width: parent.width
        height: Style.space(30)

        Row {
          anchors.fill: parent

          Repeater {
            model: ["menubar", "widget", "app"]

            Item {
              required property string modelData
              readonly property bool selected: panel.settingsTargetSurface === modelData
              width: settingsColumn.width / 3
              height: parent.height

              Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                text: panel.i18n(parent.modelData)
                color: parent.selected || surfaceMouse.containsMouse
                  ? Style.hoverStateColor(panel.foreground, Color.accent) : panel.mutedText
                font.family: panel.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: parent.selected
              }

              Rectangle {
                visible: parent.selected
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Style.space(2)
                color: Color.accent
              }

              MouseArea {
                id: surfaceMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  panel.settingsTargetSurface = parent.modelData
                  settingsView.focusId = ""
                }
              }
            }
          }
        }
      }

      Text {
        textFormat: Text.PlainText
        visible: panel.settingsPage === "display"
        width: parent.width
        text: panel.i18n("settingsKeysHint")
        color: panel.hintText
        font.family: panel.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      Text {
        textFormat: Text.PlainText
        visible: panel.settingsPage === "display"
        width: parent.width
        text: panel.i18n("displaySettingsHint") + " " + panel.i18n(panel.settingsTargetSurface === "menubar"
          ? "menubarHoverHint" : "displayTabsHint")
        color: panel.mutedText
        font.family: panel.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }

      // Menu bar: one card with the entries in the bar's order.
      Card {
        visible: panel.settingsPage === "display" && panel.settingsTargetSurface === "menubar"
        readonly property bool rowsEnabled: panel.settingsDisplaySetting("showClock", true)

        TimeSwitchRow {
          panel: settingsView.panel
          settingKey: "showClock"
          title: panel.upperLabel(panel.i18n("menubar"))
          emphasized: true
          kbFocused: settingsView.focusId === "master:showClock"
          onKbFocusedChanged: if (kbFocused) settingsView.ensureVisible(this)
        }

        Hint { text: panel.i18n("menubarRelevantHint"); bottomPadding: Style.space(8) }

        Rectangle { width: parent.width; height: Style.spacing.hairline; color: panel.foreground; opacity: 0.12 }

        Item {
          width: parent.width
          height: Style.space(24)
          opacity: parent.parent.rowsEnabled ? 1 : 0.42

          Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            Repeater {
              model: [panel.i18n("showAlways"), panel.i18n("showWhenRelevant"), panel.i18n("showOnHover")]

              Text {
                textFormat: Text.PlainText
                required property string modelData
                width: settingsView.switchColumnWidth
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: panel.mutedText
                font.family: panel.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }
          }
        }

        Repeater {
          model: settingsView.menubarOptions

          TimeSwitchRow {
            required property var modelData
            panel: settingsView.panel
            settingKey: modelData.key
            title: modelData.title
            relevantKey: modelData.relevant ? modelData.key + "WhenRelevant" : ""
            hoverKey: modelData.key + "OnHover"
            orderListKey: modelData.orderable ? "entryOrder" : ""
            orderEntry: modelData.orderable ? modelData.key : ""
            kbFocused: settingsView.focusId === "switch:" + modelData.key
            kbColumn: settingsView.focusColumn
            onKbFocusedChanged: if (kbFocused) settingsView.ensureVisible(this)
            columnWidth: settingsView.switchColumnWidth
            rowEnabled: panel.settingsDisplaySetting("showClock", true)
          }
        }

        Rectangle { width: parent.width; height: Style.spacing.hairline; color: panel.foreground; opacity: 0.12 }

        TimeSwitchRow {
          panel: settingsView.panel
          settingKey: "boldOnHover"
          title: panel.i18n("boldOnHover")
          kbFocused: settingsView.focusId === "switch:boldOnHover"
          onKbFocusedChanged: if (kbFocused) settingsView.ensureVisible(this)
          rowEnabled: panel.settingsDisplaySetting("showClock", true)
        }

        // Coloured values: off, while hovered, always.
        TimeOptionDropdown {
          panel: settingsView.panel
          settings: settingsView
          option: settingsView.menubarChoices[0]
          rowEnabled: panel.settingsDisplaySetting("showClock", true)
        }

        Hint {
          leftPadding: Style.space(12)
          bottomPadding: Style.space(6)
          text: panel.i18n("menubarAccentsHint")
          opacity: panel.settingsDisplaySetting("showClock", true) ? 1 : 0.42
        }

        TimeSwitchRow {
          panel: settingsView.panel
          settingKey: "hoverTooltip"
          title: panel.i18n("hoverTooltip")
          kbFocused: settingsView.focusId === "switch:hoverTooltip"
          onKbFocusedChanged: if (kbFocused) settingsView.ensureVisible(this)
          rowEnabled: panel.settingsDisplaySetting("showClock", true)
        }

        Hint {
          leftPadding: Style.space(12)
          bottomPadding: Style.space(6)
          text: panel.i18n("hoverTooltipHint")
          opacity: panel.settingsDisplaySetting("showClock", true) ? 1 : 0.42
        }

        TimeSwitchRow {
          panel: settingsView.panel
          settingKey: "openWidgetOnHover"
          title: panel.i18n("openWidgetOnHover")
          kbFocused: settingsView.focusId === "switch:openWidgetOnHover"
          onKbFocusedChanged: if (kbFocused) settingsView.ensureVisible(this)
          rowEnabled: panel.settingsDisplaySetting("showClock", true)
        }

        TimeOptionDropdown {
          panel: settingsView.panel
          settings: settingsView
          option: settingsView.menubarChoices[1]
          rowEnabled: panel.settingsDisplaySetting("showClock", true)
        }
      }

      // Widget and app: the clock on top, then a card per tab in tab order.
      Card {
        visible: panel.settingsPage === "display" && panel.settingsTargetSurface !== "menubar"

        SectionTitle {
          height: Style.space(34)
          verticalAlignment: Text.AlignVCenter
          text: panel.upperLabel(panel.i18n("clockSection"))
        }

        Rectangle { width: parent.width; height: Style.spacing.hairline; color: panel.foreground; opacity: 0.12 }

        Repeater {
          model: settingsView.heroOptions

          Column {
            id: heroOptionRow
            required property var modelData
            width: parent.width

            TimeSwitchRow {
              visible: !heroOptionRow.modelData.choices
              panel: settingsView.panel
              settingKey: heroOptionRow.modelData.key
              title: heroOptionRow.modelData.title
              kbFocused: settingsView.focusId === "switch:" + heroOptionRow.modelData.key
              onKbFocusedChanged: if (kbFocused) settingsView.ensureVisible(this)
            }
            TimeOptionDropdown {
              visible: !!heroOptionRow.modelData.choices
              panel: settingsView.panel
              settings: settingsView
              option: heroOptionRow.modelData
              rowEnabled: settingsView.optionAvailable(heroOptionRow.modelData)
            }

            Hint {
              visible: !!heroOptionRow.modelData.hint
              leftPadding: Style.space(12)
              bottomPadding: Style.space(4)
              text: visible ? panel.i18n(heroOptionRow.modelData.hint) : ""
            }
          }
        }
      }

      Repeater {
        model: panel.settingsPage === "display" && panel.settingsTargetSurface !== "menubar"
          ? panel.settingsOrderFor("tabOrder") : []

        Card {
          id: tabCard
          required property string modelData
          readonly property string masterKey: panel.tabMasterKeys[modelData]
          readonly property bool shown: panel.settingsDisplaySetting(masterKey, true)

          TimeSwitchRow {
            panel: settingsView.panel
            settingKey: tabCard.masterKey
            title: panel.upperLabel(panel.i18n(tabCard.modelData + "Tab"))
            emphasized: true
            orderListKey: "tabOrder"
            orderEntry: tabCard.modelData
            kbFocused: settingsView.focusId === "master:" + tabCard.masterKey
            onKbFocusedChanged: if (kbFocused) settingsView.ensureVisible(this)
          }

          Hint {
            text: panel.i18n(tabCard.modelData + "TabHint")
            bottomPadding: settingsView.tabOptions[tabCard.modelData].length ? Style.space(8) : 0
          }

          Rectangle {
            visible: settingsView.tabOptions[tabCard.modelData].length > 0
            width: parent.width
            height: Style.spacing.hairline
            color: panel.foreground
            opacity: 0.12
          }

          Repeater {
            model: settingsView.tabOptions[tabCard.modelData]

            Column {
              id: optionRow
              required property var modelData
              readonly property bool available: tabCard.shown && settingsView.optionAvailable(modelData)
              width: parent.width

              TimeSwitchRow {
                visible: !optionRow.modelData.choices
                panel: settingsView.panel
                settingKey: optionRow.modelData.key
                title: optionRow.modelData.title
                kbFocused: settingsView.focusId === "switch:" + optionRow.modelData.key
                onKbFocusedChanged: if (kbFocused) settingsView.ensureVisible(this)
                rowEnabled: optionRow.available
              }
              TimeOptionDropdown {
                visible: !!optionRow.modelData.choices
                panel: settingsView.panel
                settings: settingsView
                option: optionRow.modelData
                rowEnabled: optionRow.available
              }
              Hint {
                visible: !!optionRow.modelData.hint
                text: optionRow.modelData.hint || ""
                leftPadding: Style.space(12)
                bottomPadding: Style.space(6)
                opacity: optionRow.available ? 1 : 0.42
              }
            }
          }
        }
      }

      Item {
        visible: panel.settingsPage === "display" && panel.settingsTargetSurface !== "menubar" && panel.settingsTabs.length > 1
        width: parent.width
        height: Style.space(40)

        Text {
          textFormat: Text.PlainText
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: panel.i18n("defaultTab")
          color: panel.foreground
          font.family: panel.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Dropdown {
          id: defaultTabDropdown
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(180)
          showLabel: false
          fontFamily: panel.fontFamily
          hasCursor: settingsView.focusId === "defaultTab"
          onHasCursorChanged: if (hasCursor) settingsView.ensureVisible(this)
          onPopupOpenChanged: if (!popupOpen) panel.restoreKeyFocus()
          value: panel.settingsDefaultTab
          options: panel.settingsTabs.map(function(key) { return { value: key, label: panel.i18n(key + "Tab") } })
          onChanged: function(value) { panel.displayOptionsStore.setSettingsDisplaySetting("defaultTab", value) }
          Component.onCompleted: {
            var items = Object.assign({}, settingsView.dropdownItems)
            items.defaultTab = defaultTabDropdown
            settingsView.dropdownItems = items
          }
        }
      }

      Row {
        visible: panel.settingsPage === "display"
        spacing: Style.space(10)

        TimeButton {
          id: restoreOrderButton
          visible: !panel.settingsOrderIsDefault
          panel: settingsView.panel
          label: panel.i18n("restoreOrder")
          kbFocused: settingsView.focusId === "restoreOrder"
          onKbFocusedChanged: if (kbFocused) settingsView.ensureVisible(this)
          onActivated: panel.displayOptionsStore.restoreSettingsDisplayOrder()
        }

        TimeButton {
          id: restoreDefaultsButton
          visible: !panel.displayOptionsStore.settingsDisplayIsDefault()
          panel: settingsView.panel
          label: panel.i18n("restoreDefaults")
          confirmLabel: panel.i18n("restoreConfirm")
          kbFocused: settingsView.focusId === "restoreDefaults"
          onKbFocusedChanged: if (kbFocused) settingsView.ensureVisible(this)
          onActivated: panel.displayOptionsStore.restoreSettingsDisplayDefaults()
        }
      }

      Item { width: 1; height: Style.space(8) }
    }
  }
}
