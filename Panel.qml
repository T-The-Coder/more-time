import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "WorldMap.js" as WorldMap
import "Moon.js" as Moon
import "MoonView.js" as MoonView
import "I18n.js" as I18n

// Controller and view of More Time, in two places: the bar's popup
// (KeyboardPanel, loaded by BarWidget.qml) and the standalone app
// (FloatingWindow, standaloneMode from app/shell.qml). One content tree is
// reparented into whichever is used, so every feature lands in both.
Panel {
  id: root
  moduleName: "more-time"
  ipcTarget: "more-time"
  manageIpc: false
  LayoutMirroring.enabled: I18n.isRightToLeft(interfaceLanguage)
  LayoutMirroring.childrenInherit: true

  // Work for "after this event" goes through defer() rather than
  // Qt.callLater: the shell rebuilds its panels when a monitor goes away,
  // and a queued Qt.callLater then ran against the destroyed panel. The
  // Timer dies with the panel, so its queue does too.
  property bool panelAlive: true
  property var deferredCalls: []

  function defer(fn) {
    if (!panelAlive || typeof fn !== "function") return
    if (deferredCalls.indexOf(fn) >= 0) return
    deferredCalls = deferredCalls.concat([fn])
    if (!deferredCallTimer.running) deferredCallTimer.start()
  }

  function runDeferredCalls() {
    var calls = deferredCalls
    deferredCalls = []
    for (var i = 0; i < calls.length && panelAlive; ++i) {
      try {
        calls[i]()
      } catch (e) {
        console.warn("more-time: deferred call failed:", e, e && e.stack)
      }
    }
  }

  Timer {
    id: deferredCallTimer
    interval: 0
    onTriggered: root.runDeferredCalls()
  }

  Component.onDestruction: {
    panelAlive = false
    deferredCalls = []
    deferredCallTimer.stop()
  }

  property var anchorItem: null
  property bool openedFromHotkey: false
  property bool standaloneMode: false
  readonly property string activeSurface: standaloneMode ? "app" : "widget"
  onStandaloneModeChanged: {
    settingsTargetSurface = activeSurface
    root.defer(function() { displayOptionsStore.reloadAll() })
  }
  readonly property color foreground: root.bar ? root.bar.foreground : Color.popups.text
  readonly property string fontFamily: root.bar && root.bar.fontFamily
    ? root.bar.fontFamily : Style.font.family
  // The two secondary text tones used everywhere: muted for labels and
  // supporting values, subtle for tertiary hints and hairline borders.
  readonly property color mutedText: Qt.darker(foreground, 1.35)
  // The Sun wherever it is drawn (the maps' sun marker, the Astro tab): the
  // golden hour's gold, softened towards the text and kept at 3:1 on the
  // background like the sky-coloured time (WorldMap.skyColor at 0°).
  readonly property color sunColor: WorldMap.sunColor(rgbOf(foreground), rgbOf(Color.popups.background))
  readonly property color subtleText: Qt.darker(foreground, 1.7)
  // Key hints: the text colour faded towards the background.
  readonly property color hintText: Qt.tint(foreground,
    Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 0.55))

  function canvasFont(pixelSize, bold, italic) {
    return (italic ? "italic " : "") + (bold ? "bold " : "")
      + Math.round(pixelSize) + "px \"" + fontFamily + "\""
  }

  // The bar tracks the widget in its slot (BarWidget.qml), not this nested
  // panel; everything the bar identifies a panel by has to be that widget.
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  function open() {
    openedFromHotkey = false
    prepareOpen()
    setCenterHoverRevealSuppressed(false)
    root.controller.show()
  }

  function openFromHotkey() {
    openedFromHotkey = true
    prepareOpen()
    root.controller.show()
    // Set after showing: showing hands the popout coordinator over, which
    // closes the previous panel, and that close clears the shared flag.
    root.defer(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function prepareOpen() {
    settingsOpen = false
    activeTab = defaultTab
    nowMs = Date.now()
    displayOptionsStore.reloadAll()
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    closeEditors()
    settingsOpen = false
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && typeof root.bar.setCenterHoverRevealSuppressed === "function")
      root.bar.setCenterHoverRevealSuppressed(value)
    else if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  // The launcher of the standalone app, next to this file.
  function appLauncherPath() {
    return String(Qt.resolvedUrl("app/more-time")).replace(/^file:\/\//, "")
  }

  function openApp() {
    Quickshell.execDetached([appLauncherPath()])
    if (!standaloneMode) close()
  }

  // ---- Clock -------------------------------------------------------------
  // Bindings do not notice time passing, so everything that shows time reads
  // nowMs. It moves every second while seconds or running things are on
  // screen, and once a minute otherwise. The timer is re-armed against the
  // real clock each time, so it lands on the second and a suspended laptop
  // shows the right time a second after waking.
  property double nowMs: Date.now()
  property double lastRingerTickMs: 0
  readonly property bool anyRunning: {
    var items = itemsStore.items
    for (var t = 0; t < items.timers.length; t++) if (items.timers[t].state === "running") return true
    for (var s = 0; s < items.stopwatches.length; s++) if (items.stopwatches[s].running) return true
    for (var p = 0; p < items.pomodoros.length; p++) if (items.pomodoros[p].state === "running") return true
    return false
  }
  readonly property bool fastTick: opened || anyRunning || menubarSecondsShown || ringer.ringing.length > 0
  // The next moment something is due (timer or pomodoro end), so the check
  // runs right then rather than at the next heartbeat.
  readonly property double nextDueMs: {
    var items = itemsStore.items
    var next = 0
    function consider(ms) { if (ms > 0 && (next === 0 || ms < next)) next = ms }
    for (var t = 0; t < items.timers.length; t++) if (items.timers[t].state === "running") consider(items.timers[t].endsAt)
    for (var p = 0; p < items.pomodoros.length; p++)
      if (items.pomodoros[p].state === "running") consider(items.pomodoros[p].endsAt)
    return next
  }

  // For the picture runs only (tests/ui-showcase.sh): what the views show
  // is this far from the real clock. The ringer and the chimes keep the real
  // one, so nothing rings for the shown time.
  property double clockOffsetMs: 0
  onClockOffsetMsChanged: {
    nowMs = Date.now() + clockOffsetMs
    fineNowMs = nowMs
  }

  function tick() {
    var real = Date.now()
    var shown = real + clockOffsetMs
    if (fastTick || Math.floor(shown / 60000) !== Math.floor(nowMs / 60000)) nowMs = shown
    var now = real
    var minuteTurned = Math.floor(now / 60000) !== Math.floor(lastRingerTickMs / 60000)
    if (minuteTurned || (nextDueMs > 0 && now >= nextDueMs) || now - lastRingerTickMs >= 5000) {
      lastRingerTickMs = now
      ringer.tick(now)
      zoneTable.check(now)
    }
    clockTimer.interval = 1000 - (Date.now() % 1000) + 3
    clockTimer.restart()
  }

  Timer {
    id: clockTimer
    interval: 1000
    running: true
    repeat: false
    onTriggered: root.tick()
  }

  // Hundredths for a running stopwatch on screen.
  property double fineNowMs: nowMs
  Timer {
    interval: 33
    repeat: true
    running: root.opened && root.currentTab === "stopwatches" && root.displaySetting("stopwatchHundredths", true)
      && root.itemsStore.items.stopwatches.some(function(s) { return s.running })
    onTriggered: root.fineNowMs = Date.now() + root.clockOffsetMs
    onRunningChanged: root.fineNowMs = Date.now() + root.clockOffsetMs
  }

  readonly property int localOffset: Model.localOffsetSeconds(nowMs)
  readonly property var localParts: Model.zonedParts(nowMs, localOffset)

  // ---- Language and formats ------------------------------------------------

  readonly property string localeName: String(Qt.locale().name || "")
  readonly property string interfaceLanguage: I18n.resolvedLanguage(generalSetting("language", "auto"), localeName)
  readonly property var interfaceLocale: Qt.locale(I18n.localeName(interfaceLanguage))

  function i18n(key, values) {
    return I18n.text(interfaceLanguage, key, values)
  }

  // 24 or 12 hours: chosen, or the short time format of the interface
  // language (which is the system's while the language is automatic), so a
  // German interface on an en_US system shows 14:30, not 2:30 PM.
  readonly property string timeFormatSetting: String(generalSetting("timeFormat", "auto"))
  readonly property bool hour12: timeFormatSetting === "12"
    || (timeFormatSetting === "auto" && /a/i.test(formatLocale.timeFormat(Locale.ShortFormat)))
  readonly property var amPm: [interfaceLocale.amText || "AM", interfaceLocale.pmText || "PM"]

  function clockFor(utcMs, offset, seconds) {
    return latinDigits(Model.clockText(Model.zonedParts(utcMs, offset), hour12, seconds, amPm))
  }

  function localClock(seconds) {
    return clockFor(nowMs, localOffset, seconds)
  }

  // A local wall-clock time of the day (alarms), in the chosen format.
  function wallClock(hour, minute) {
    return latinDigits(Model.clockText({ hour: hour, minute: minute, second: 0 }, hour12, false, amPm))
  }

  // Dates in the interface language. Qt formats Date objects in this
  // computer's zone, so a zoned date is rebuilt as a local noon first.
  function dateFor(utcMs, offset, style) {
    var p = Model.zonedParts(utcMs, offset)
    if (style === "weekday") return interfaceLocale.dayName(p.weekday, Locale.LongFormat)
    if (style === "weekdayShort") return interfaceLocale.dayName(p.weekday, Locale.ShortFormat)
    var noon = new Date(p.year, p.month, p.day, 12)
    var format = style === "long" ? interfaceLocale.dateFormat(Locale.LongFormat) : i18n("dateShortFormat")
    return latinDigits(interfaceLocale.toString(noon, format))
  }

  function weekdayName(day, short) {
    return interfaceLocale.dayName(day, short ? Locale.NarrowFormat : Locale.ShortFormat)
  }

  // The locale that shapes times and weeks: the interface language's, or the
  // system's while the language is automatic.
  readonly property var formatLocale: generalSetting("language", "auto") === "auto" ? Qt.locale() : interfaceLocale

  // Weekdays in the locale's order, for the alarm editor.
  readonly property var weekdayOrder: {
    var first = formatLocale.firstDayOfWeek % 7
    var days = []
    for (var i = 0; i < 7; i++) days.push((first + i) % 7)
    return days
  }

  function durationText(ms, options) {
    return latinDigits(Model.durationText(ms, options))
  }

  function localizedNumber(value) {
    return latinDigits(interfaceLocale.toString(Number(value), "f", 0))
  }

  // Arabic and Persian locales format numbers with their own digits; keep
  // one digit set so a row never mixes them.
  function latinDigits(text) {
    return String(text).replace(/[٠-٩]/g, function(d) {
      return String(d.charCodeAt(0) - 0x0660)
    }).replace(/[۰-۹]/g, function(d) {
      return String(d.charCodeAt(0) - 0x06F0)
    }).replace(/٫/g, ".").replace(/٬/g, ",")
  }

  // Short, upper-case label; Greek capitals drop the tonos accent.
  function upperLabel(text) {
    var upper = String(text || "").toLocaleUpperCase()
    if (interfaceLanguage === "el" && typeof upper.normalize === "function")
      upper = upper.normalize("NFD").replace(/\u0301/g, "").normalize("NFC")
    return upper
  }

  // "in 2 h 5 min" / "in 40 min" / "in 30 s".
  function untilText(ms) {
    var total = Math.max(0, Math.round(ms / 60000))
    if (ms < 60000) return i18n("inSeconds", { seconds: Math.max(1, Math.ceil(ms / 1000)) })
    if (total < 60) return i18n("inMinutes", { minutes: total })
    var hours = Math.floor(total / 60)
    var minutes = total % 60
    return minutes ? i18n("inHoursMinutes", { hours: hours, minutes: minutes }) : i18n("inHours", { hours: hours })
  }

  // "+6 h", "−9:30 h", "same time".
  function offsetDifferenceText(seconds) {
    if (seconds === 0) return i18n("sameTime")
    return Model.offsetText(seconds) + " h"
  }

  // ---- General settings ------------------------------------------------------

  property var generalOptions: ({})
  function generalSetting(key, fallback) {
    var value = generalOptions ? generalOptions[key] : undefined
    return value === undefined ? fallback : value
  }
  readonly property real soundVolume: Number(generalSetting("volume", 75)) / 100

  // kind: "alarm", "timer" or "pomodoro".
  function soundFor(kind) {
    var id = String(generalSetting(kind + "Sound", kind === "alarm" ? "alarm" : (kind === "timer" ? "bell" : "complete")))
    return ringer.soundFiles[id] || ""
  }

  // The chimes (Settings → Sounds → Chimes), for Model.chimePlan.
  readonly property var chimeSettings: ({
    chimeInterval: generalSetting("chimeInterval", "quarter"),
    chimeMinutes: generalSetting("chimeMinutes", 30),
    chimeDailyHour: generalSetting("chimeDailyHour", 12),
    hourChime: generalSetting("hourChime", "off")
  })
  readonly property bool chimesActive: Model.chimesActive(chimeSettings)
  readonly property bool chimesMuted: generalSetting("chimesMuted", false) === true
  readonly property real chimeVolume: Number(generalSetting("chimeVolume", 50)) / 100
  readonly property string chimeTone: String(generalSetting("chimeTone", "beep"))

  // Mute is a general setting, so every instance (bar, app) follows at once.
  function setChimesMuted(muted) {
    displayOptionsStore.setGeneralSetting("chimesMuted", !!muted)
  }

  // Finished focus rounds today and this week (from the locale's first
  // weekday): { today, week }, from the items file's pomodoroLog.
  readonly property var pomodoroTally: Model.pomodoroTally(itemsStore.items.pomodoroLog, nowMs, formatLocale.firstDayOfWeek)

  // The Timers tab's preset row (Settings → General → Timers), in minutes.
  readonly property var timerPresets: Model.parseTimerPresets(generalSetting("timerPresets", Model.DEFAULT_TIMER_PRESETS))
    || Model.parseTimerPresets(Model.DEFAULT_TIMER_PRESETS)

  function alarmSnoozeMinutes(alarmId) {
    var alarm = itemsStore.find("alarms", alarmId)
    return alarm ? alarm.snoozeMinutes : Number(generalSetting("snoozeMinutes", 9))
  }

  // ---- Display options ---------------------------------------------------------
  // Three profiles: the app, the bar popup (widget) and the menu bar. The
  // popup opens over other windows, so it starts with less.

  property bool settingsOpen: false
  readonly property var settingsPages: ["general", "display", "sounds", "shortcuts", "sources"]
  property string settingsPage: "general"
  property string settingsTargetSurface: activeSurface
  property bool appDisplayOptionsLoaded: false
  property bool widgetDisplayOptionsLoaded: false
  property bool menubarDisplayOptionsLoaded: false
  property var appDisplayOptions: defaultDisplayOptions()
  property var widgetDisplayOptions: defaultWidgetDisplayOptions()
  property var menubarDisplayOptions: defaultMenubarDisplayOptions()

  function stepSettingsPage(delta) {
    var index = settingsPages.indexOf(settingsPage)
    settingsPage = settingsPages[(index + delta + settingsPages.length) % settingsPages.length]
  }

  function openSettings(page) {
    closeEditors()
    settingsPage = page || "general"
    settingsTargetSurface = activeSurface
    displayOptionsStore.reloadAll()
    settingsOpen = true
  }

  function defaultTabOrder() {
    return ["world", "alarms", "timers", "stopwatches", "pomodoros", "astro"]
  }

  function defaultEntryOrder() {
    return ["ringing", "weekday", "date", "week", "time", "cities", "nextAlarm", "timers", "stopwatches", "pomodoros",
      "pomodoroTally"]
  }

  function defaultDisplayOptions() {
    return {
      heroSeconds: true,
      heroDate: true,
      heroWeek: true,
      heroDayOfYear: true,
      heroZone: true,
      heroAnalog: true,
      heroDial: "place",
      heroNextAlarm: true,
      heroPomodoroTally: false,
      heroSun: true,
      heroSunNext: false,
      heroGoldenHour: false,
      heroBlueHour: false,
      showWorld: true,
      worldMap: true,
      worldStyle: "map",
      worldNight: true,
      worldRuler: true,
      worldMapLabels: true,
      globeAutoRotate: false,
      worldMoon: false,
      worldMoonStyle: "space",
      worldList: true,
      worldDifference: true,
      worldDials: true,
      worldSunrise: false,
      worldSunset: false,
      worldSunNext: true,
      showAlarms: true,
      showTimers: true,
      showStopwatches: true,
      stopwatchHundredths: true,
      showPomodoros: true,
      showAstro: true,
      astroOrbits: true,
      astroNames: true,
      astroMonthRing: true,
      astroRotation: true,
      astroTimeline: true,
      astroBelts: true,
      astroDwarfs: true,
      astroComets: false,
      astroMoons: false,
      astroSpacecraft: false,
      astroIss: false,
      astroStars: true,
      astroConstellations: false,
      astroInfo: true,
      astroEarthInset: true,
      astroAutoRotate: false,
      tabOrder: defaultTabOrder(),
      defaultTab: "world"
    }
  }

  function defaultWidgetDisplayOptions() {
    var options = defaultDisplayOptions()
    options.heroDayOfYear = false
    options.heroAnalog = false
    options.heroSun = false
    options.worldSunNext = false
    options.worldDials = false
    options.heroGoldenHour = false
    options.heroBlueHour = false
    options.worldRuler = false
    // The solar system wants room: the app shows it, the widget not.
    options.showAstro = false
    return options
  }

  function defaultMenubarDisplayOptions() {
    var options = {
      showClock: true,
      entryOrder: defaultEntryOrder(),
      citiesCount: "2",
      boldOnHover: true,
      hoverTooltip: false,
      menubarAccents: "hover",
      openWidgetOnHover: false
    }
    // Each entry: always, when relevant, on hover (see menubarEntryShown).
    var defaults = {
      time: "always", seconds: "hover", weekday: "", date: "", week: "", cities: "hover",
      nextAlarm: "relevant", timers: "relevant", stopwatches: "relevant", pomodoros: "relevant", ringing: "relevant",
      pomodoroTally: ""
    }
    for (var key in defaults) {
      options[key] = defaults[key] === "always"
      options[key + "WhenRelevant"] = defaults[key] === "relevant"
      options[key + "OnHover"] = defaults[key] === "hover"
    }
    return options
  }

  function defaultOptionsFor(surface) {
    return surface === "menubar" ? defaultMenubarDisplayOptions()
      : (surface === "widget" ? defaultWidgetDisplayOptions() : defaultDisplayOptions())
  }

  // An order keeps the keys it knows, in its order, and gains new ones at
  // their default place.
  function sanitizedOrder(value, orderKey) {
    var defaults = orderKey === "entryOrder" ? defaultEntryOrder() : defaultTabOrder()
    var result = []
    var list = value && value.length !== undefined && typeof value !== "string" ? value : []
    for (var i = 0; i < list.length; i++) {
      var key = String(list[i])
      if (defaults.indexOf(key) >= 0 && result.indexOf(key) < 0) result.push(key)
    }
    for (var d = 0; d < defaults.length; d++) {
      if (result.indexOf(defaults[d]) >= 0) continue
      var before = d > 0 ? result.indexOf(defaults[d - 1]) : -1
      result.splice(before + 1, 0, defaults[d])
    }
    return result
  }

  function optionValue(options, surface, key, fallback) {
    var value = options ? options[key] : undefined
    if (value !== undefined) return value
    var defaults = defaultOptionsFor(surface)
    return defaults[key] !== undefined ? defaults[key] : fallback
  }

  readonly property var displayOptions: standaloneMode ? appDisplayOptions : widgetDisplayOptions
  function displaySetting(key, fallback) {
    return optionValue(displayOptions, activeSurface, key, fallback)
  }
  function menubarDisplaySetting(key, fallback) {
    return optionValue(menubarDisplayOptions, "menubar", key, fallback)
  }
  function settingsDisplaySetting(key, fallback) {
    return optionValue(displayOptionsStore.optionsFor(settingsTargetSurface), settingsTargetSurface, key, fallback)
  }
  function settingsOrderFor(orderKey) {
    return sanitizedOrder(settingsDisplaySetting(orderKey, null), orderKey)
  }

  // ---- Tabs ----

  readonly property var tabMasterKeys: ({
    world: "showWorld", alarms: "showAlarms", timers: "showTimers",
    stopwatches: "showStopwatches", pomodoros: "showPomodoros", astro: "showAstro"
  })
  readonly property var displayTabs: sanitizedOrder(displaySetting("tabOrder", null), "tabOrder")
    .filter(function(key) { return displaySetting(tabMasterKeys[key], true) })
  readonly property string defaultTab: {
    var wanted = String(displaySetting("defaultTab", "world"))
    return displayTabs.indexOf(wanted) >= 0 ? wanted : (displayTabs.length ? displayTabs[0] : "")
  }
  property string activeTab: ""
  readonly property string currentTab: displayTabs.indexOf(activeTab) >= 0 ? activeTab : defaultTab
  onCurrentTabChanged: closeEditors()

  // The same for the profile the settings edit.
  readonly property var settingsTabs: settingsOrderFor("tabOrder")
    .filter(function(key) { return settingsDisplaySetting(tabMasterKeys[key], true) })
  readonly property string settingsDefaultTab: {
    var wanted = String(settingsDisplaySetting("defaultTab", "world"))
    return settingsTabs.indexOf(wanted) >= 0 ? wanted : (settingsTabs.length ? settingsTabs[0] : "")
  }
  readonly property bool settingsOrderIsDefault: settingsTargetSurface === "menubar"
    ? String(settingsOrderFor("entryOrder")) === String(defaultEntryOrder())
    : String(settingsOrderFor("tabOrder")) === String(defaultTabOrder())

  function tabLabel(key) {
    return upperLabel(i18n(key + "Tab"))
  }

  function tabGlyph(key) {
    return key === "world" ? "\u{f01e7}" : (key === "alarms" ? "\u{f0020}"
      : (key === "timers" ? "\u{f051f}" : (key === "stopwatches" ? "\u{f13ab}"
      : (key === "astro" ? "\u{f15db}" : "\u{f0996}"))))
  }

  // A display option of the surface shown now (the chips under the views),
  // as the Display cards would set it for that surface.
  function setViewDisplaySetting(key, value) {
    var surface = settingsTargetSurface
    settingsTargetSurface = activeSurface
    displayOptionsStore.setSettingsDisplaySetting(key, value)
    settingsTargetSurface = surface
  }

  function showTab(key) {
    if (displayTabs.indexOf(key) < 0) return false
    activeTab = key
    return true
  }

  // ---- Menu bar --------------------------------------------------------------
  // Each entry shows always ("<key>"), only when it matters ("<key>WhenRelevant")
  // or only while the pointer rests on the widget ("<key>OnHover").

  property bool menubarHovered: false
  readonly property var menubarEntryKeys: ["time", "seconds", "weekday", "date", "week", "cities", "pomodoroTally",
    "nextAlarm", "timers", "stopwatches", "pomodoros", "ringing"]
  readonly property bool menubarShowClock: menubarDisplaySetting("showClock", true)
  readonly property bool menubarBoldOnHover: menubarDisplaySetting("boldOnHover", true)
  // Coloured values: "off", "hover" (while the pointer is on the clock, the
  // same immediate condition as bold; BarWidget sets menubarAccentHover) or
  // "always".
  property bool menubarAccentHover: false
  readonly property string menubarAccents: String(menubarDisplaySetting("menubarAccents", "hover"))
  readonly property bool menubarAccentsOn: menubarAccents === "always"
    || (menubarAccents === "hover" && menubarAccentHover)

  // [r, g, b] in 0–1 of a colour, for WorldMap's colour helpers.
  function rgbOf(c) { return [c.r, c.g, c.b] }

  // The time in the colour of the sky here (WorldMap.skyColor): day, golden
  // hour, blue hour, night, at the place TimeHere finds; "#rrggbb", or ""
  // without a place.
  function skyColorAt(utcMs) {
    var place = here.place
    if (!place) return ""
    return WorldMap.skyColor(WorldMap.sunElevation(place.lat, place.lon, utcMs),
      rgbOf(foreground), rgbOf(Color.popups.background))
  }
  readonly property bool menubarOpenWidgetOnHover: !standaloneMode && menubarDisplaySetting("openWidgetOnHover", false)
  readonly property int menubarCitiesCount: Number(menubarDisplaySetting("citiesCount", "2")) || 2

  // hovered: as if the pointer rested on the widget (the tooltip), else
  // as it does now.
  function menubarEntryShown(key, hovered) {
    if (!menubarShowClock) return false
    if (menubarDisplaySetting(key, false) === true) return true
    var isHovered = hovered === undefined ? menubarHovered : hovered
    if (isHovered && menubarDisplaySetting(key + "OnHover", false) === true) return true
    return menubarDisplaySetting(key + "WhenRelevant", false) === true && menubarEntryRelevant(key)
  }

  // What "when relevant" means per entry. Entries without a rule offer the
  // choice greyed out in settings.
  readonly property var relevantEntries: ["nextAlarm", "timers", "stopwatches", "pomodoros", "ringing", "pomodoroTally"]
  function menubarEntryRelevant(key) {
    var items = itemsStore.items
    if (key === "nextAlarm") return nextAlarm !== null && nextAlarm.at - nowMs <= 12 * 3600000
    if (key === "timers") return items.timers.some(function(t) { return t.state === "running" || t.state === "paused" })
    if (key === "stopwatches") return items.stopwatches.some(function(s) { return s.running })
    if (key === "pomodoros") return items.pomodoros.some(function(p) { return p.state === "running" || p.state === "paused" })
    if (key === "pomodoroTally") return pomodoroTally.today > 0
    if (key === "ringing") return ringer.ringing.length > 0
    return false
  }

  // Nothing always shown but something on hover: the clock glyph stays as
  // the spot to point at.
  readonly property bool menubarHoverHandle: {
    if (!menubarShowClock) return false
    var anyHover = false
    for (var i = 0; i < menubarEntryKeys.length; i++) {
      var key = menubarEntryKeys[i]
      if (key === "seconds") continue
      if (menubarDisplaySetting(key, false) || menubarDisplaySetting(key + "WhenRelevant", false)) return false
      if (menubarDisplaySetting(key + "OnHover", false)) anyHover = true
    }
    return anyHover
  }
  readonly property bool menubarSecondsShown: menubarEntryShown("seconds")
    && (menubarEntryShown("time") || menubarHovered)

  // The entries the bar draws, in order: [{ key, text, glyph, urgent,
  // color, parts: [{ text, color }] }]. A colour is a role, "" for the bar's
  // text colour or "accent", "urgent", "muted", or "sky#rrggbb" (the time in
  // the colour of the sky); while coloured values are off
  // (menubarAccentsOn) every role is "". The parts make up the text; the
  // glyph takes the entry's colour.
  readonly property var menubarEntries: menubarEntryList(menubarHovered)
  function menubarEntryList(hovered) {
    var result = []
    var secondsShown = menubarEntryShown("seconds", hovered) && (menubarEntryShown("time", hovered) || hovered)
    var order = sanitizedOrder(menubarDisplaySetting("entryOrder", null), "entryOrder")
    var items = itemsStore.items
    var now = nowMs
    var accents = menubarAccentsOn
    function role(name) { return accents ? name : "" }
    for (var i = 0; i < order.length; i++) {
      var key = order[i]
      if (!menubarEntryShown(key, hovered)) continue
      var entry = { key: key, text: "", glyph: "", urgent: false, color: "", parts: null, label: "" }
      if (key === "time") {
        // Hours and minutes in the colour of the sky, the seconds muted,
        // then AM / PM.
        var clock = localClock(false)
        var skyHex = accents ? skyColorAt(now) : ""
        var sky = skyHex !== "" ? "sky" + skyHex : ""
        if (secondsShown) {
          var suffix = hour12 ? (clock.match(/\s*\S+$/) || [""])[0] : ""
          var hm = suffix ? clock.slice(0, clock.length - suffix.length) : clock
          entry.parts = [{ text: hm, color: sky }, { text: ":" + Model.pad2(localParts.second), color: role("muted") }]
          if (suffix) entry.parts.push({ text: suffix, color: sky })
        } else {
          entry.parts = [{ text: clock, color: sky }]
        }
      } else if (key === "weekday") {
        entry.text = dateFor(now, localOffset, "weekdayShort")
      } else if (key === "date") {
        entry.text = dateFor(now, localOffset, "short")
      } else if (key === "week") {
        entry.text = i18n("weekShort", { week: Model.isoWeek(localParts.year, localParts.month, localParts.day) })
        entry.color = role("muted")
      } else if (key === "cities") {
        // Each city in the accent colour by day (06–18 there), muted at night.
        var parts = []
        for (var c = 0; c < cityList.length && parts.length < menubarCitiesCount; c++) {
          var offset = cityOffset(cityList[c])
          if (offset === null) continue
          var cityHour = Model.zonedParts(now, offset).hour
          parts.push({ text: (parts.length ? "  " : "") + cityList[c].name + " " + clockFor(now, offset, false),
            color: role(cityHour >= 6 && cityHour < 18 ? "accent" : "muted") })
        }
        entry.parts = parts
      } else if (key === "nextAlarm") {
        if (nextAlarm) {
          entry.glyph = "\u{f0020}"
          entry.text = wallClockAt(nextAlarm.at)
          var untilAlarm = nextAlarm.at - now
          entry.color = role(untilAlarm <= 10 * 60000 ? "urgent" : (untilAlarm <= 3600000 ? "accent" : ""))
        }
      } else if (key === "timers") {
        var timer = null
        for (var t = 0; t < items.timers.length; t++) {
          var candidate = items.timers[t]
          if (candidate.state !== "running" && candidate.state !== "paused") continue
          if (!timer || Model.timerRemaining(candidate, now) < Model.timerRemaining(timer, now)) timer = candidate
        }
        if (timer) {
          var timerLeft = Model.timerRemaining(timer, now)
          entry.label = timer.label || ""
          entry.glyph = "\u{f051f}"
          entry.text = durationText(timerLeft, { countdown: true })
          entry.color = role(timer.state === "paused" ? "muted" : (timerLeft <= 60000 ? "urgent" : "accent"))
        }
      } else if (key === "stopwatches") {
        for (var s = 0; s < items.stopwatches.length; s++) {
          if (!items.stopwatches[s].running) continue
          entry.glyph = "\u{f13ab}"
          entry.text = durationText(Model.stopwatchElapsed(items.stopwatches[s], now))
          entry.color = role("accent")
          break
        }
      } else if (key === "pomodoros") {
        for (var p = 0; p < items.pomodoros.length; p++) {
          var pomodoro = items.pomodoros[p]
          if (pomodoro.state === "idle") continue
          var pomodoroLeft = Model.pomodoroRemaining(pomodoro, now)
          entry.glyph = pomodoro.phase === "work" ? "\u{f0996}" : "\u{f0176}"
          entry.label = pomodoroPhaseName(pomodoro.phase)
          entry.text = durationText(pomodoroLeft, { countdown: true })
          // Focus in the accent colour, breaks muted like the phase label in
          // the popup, the last minute of a running phase urgent.
          entry.color = role(pomodoro.state !== "running" ? "muted"
            : (pomodoroLeft <= 60000 ? "urgent" : (pomodoro.phase === "work" ? "accent" : "muted")))
          break
        }
      } else if (key === "pomodoroTally") {
        // Focus rounds today · this week.
        entry.glyph = "\u{f0996}"
        entry.text = latinDigits(pomodoroTally.today + " · " + pomodoroTally.week)
      } else if (key === "ringing") {
        if (ringer.ringing.length) {
          entry.glyph = "\u{f009e}"
          entry.urgent = true
        }
      }
      if (entry.parts) entry.text = entry.parts.map(function(p) { return p.text }).join("")
      else entry.parts = entry.text !== "" ? [{ text: entry.text, color: entry.color }] : []
      if (entry.text !== "" || entry.glyph !== "") result.push(entry)
    }
    if (!result.length && menubarHoverHandle)
      result.push({ key: "handle", text: "", glyph: "\u{f0150}", urgent: false, color: "", parts: [], label: "" })
    return result
  }

  // The bar's own tooltip (menu bar option "hoverTooltip"): every entry the
  // bar shows while hovered, in its order, one per line, with a word where
  // the bar shows only a glyph. Plain text, as the shell's tooltip is;
  // nothing while the popup is open.
  readonly property bool menubarTooltipOn: !standaloneMode && menubarDisplaySetting("hoverTooltip", false)
  readonly property string menubarTooltipText: !menubarTooltipOn || opened ? "" : menubarTooltipLines().join("\n")
  function menubarTooltipLines() {
    var lines = []
    var entries = menubarEntryList(true)
    for (var i = 0; i < entries.length; i++) {
      var e = entries[i]
      if (e.key === "cities") {
        for (var c = 0; c < e.parts.length; c++) lines.push(e.parts[c].text.trim())
      } else if (e.key === "nextAlarm" || e.key === "stopwatches" || e.key === "pomodoroTally") {
        lines.push(i18n("entry_" + e.key) + " " + e.text)
      } else if (e.key === "timers") {
        lines.push(i18n("entry_timers") + (e.label ? " " + e.label : "") + " " + e.text)
      } else if (e.key === "pomodoros") {
        lines.push(e.label + " " + e.text)
      } else if (e.key === "ringing") {
        // What rings, by its title ("Tea is up").
        for (var r = 0; r < ringer.ringing.length; r++) lines.push(ringer.ringing[r].title)
      } else if (e.key !== "handle" && e.text !== "") {
        lines.push(e.text)
      }
    }
    return lines
  }
  readonly property bool menubarHasVisibleContent: menubarEntries.length > 0

  // Right click on the widget: what is coming up, as a notification.
  function statusSummary() {
    var lines = [dateFor(nowMs, localOffset, "long") + " · " + localClock(false)]
    if (nextAlarm) lines.push(i18n("nextAlarmAt", { time: wallClockAt(nextAlarm.at), until: untilText(nextAlarm.at - nowMs) }))
    var items = itemsStore.items
    items.timers.forEach(function(t) {
      if (t.state === "running") lines.push(i18n("timerRunsOut", { name: itemTitle("timers", t),
        time: durationText(Model.timerRemaining(t, nowMs), { countdown: true }) }))
    })
    items.pomodoros.forEach(function(p) {
      if (p.state === "running") lines.push(pomodoroPhaseName(p.phase) + " · "
        + durationText(Model.pomodoroRemaining(p, nowMs), { countdown: true }))
    })
    for (var c = 0; c < cityList.length && c < 4; c++) {
      var offset = cityOffset(cityList[c])
      if (offset !== null) lines.push(cityList[c].name + " " + clockFor(nowMs, offset, false))
    }
    if (chimesActive && chimesMuted) lines.push(i18n("chimesMutedStatus"))
    return lines
  }

  // ---- Stores --------------------------------------------------------------------

  property TimeDisplayOptionsStore displayOptionsStore: TimeDisplayOptionsStore { panel: root }
  property TimeItemsStore itemsStore: TimeItemsStore { panel: root }
  property TimeCities citiesStore: TimeCities { panel: root }
  property TimeZoneTable zoneTable: TimeZoneTable { panel: root }
  property TimeRinger ringer: TimeRinger { panel: root }
  property TimeSettingsTransfer settingsTransfer: TimeSettingsTransfer { panel: root }
  property TimeAppLauncherEntry appLauncherEntry: TimeAppLauncherEntry { panel: root }
  property TimeBarPlacement barPlacement: TimeBarPlacement { panel: root }
  property TimeCitySearch citySearch: TimeCitySearch { panel: root }
  property TimeHere here: TimeHere { panel: root }
  property TimePlacesImport placesImport: TimePlacesImport { panel: root }
  property TimePlaceStore placeStore: TimePlaceStore { panel: root }
  // The ISS's orbit data (Astro tab, option astroIss): fetched only while
  // the option is on and the tab shows.
  property TimeIssStore issStore: TimeIssStore {
    panel: root
    wanted: root.displaySetting("astroIss", false) === true && root.opened && root.currentTab === "astro"
  }

  readonly property var cityList: citiesStore.list
  readonly property var wantedZones: cityList.map(function(c) { return c.tz })
    .concat(zoneTable.localTz !== "" ? [zoneTable.localTz] : [])
    .concat(itemsStore.items.alarms.map(function(a) { return a.tz }).filter(function(tz) { return tz !== "" }))

  // The zone table of an alarm's place, or null (this computer's clock, or
  // not read yet).
  function alarmZone(alarm) {
    return alarm && alarm.tz && zoneTable.revision >= 0 ? zoneTable.zones[alarm.tz] || null : null
  }
  // An alarm whose place's zone the system does not know (marked in its
  // card; it cannot ring).
  function alarmZoneUnknown(alarm) {
    return !!alarm && !!alarm.tz && zoneTable.fetched && !alarmZone(alarm)
  }
  onWantedZonesChanged: zoneTable.want(wantedZones)
  // A new zone for this computer (omarchy-menu-timezone) shows as a new
  // offset; read which one it is.
  onLocalOffsetChanged: zoneTable.localTzProc.running = true

  function cityOffset(city) {
    // Depends on the table's revision so the binding updates when it arrives.
    return zoneTable.revision >= 0 && city ? zoneTable.offsetFor(city.tz, nowMs) : null
  }

  // ---- Items: titles and texts shared by views, notifications and the bar ----

  function itemTitle(kind, item) {
    if (item && item.label) return item.label
    if (kind === "alarms") return i18n("alarm")
    if (kind === "timers") return i18n("timerNamed", { duration: durationText(item ? item.duration : 0) })
    if (kind === "stopwatches") return i18n("stopwatch")
    return i18n("pomodoro")
  }

  function wallClockAt(ms) {
    var date = new Date(ms)
    return wallClock(date.getHours(), date.getMinutes())
  }

  // The alarm that rings next, { alarm, at }, or null.
  readonly property var nextAlarm: {
    var best = null
    var alarms = itemsStore.items.alarms
    for (var i = 0; i < alarms.length; i++) {
      var at = Model.alarmNextRing(alarms[i], nowMs, alarmZone(alarms[i]))
      if (at && (!best || at < best.at)) best = { alarm: alarms[i], at: at }
    }
    return best
  }

  // "Mon Tue Fri", "Every day", "Weekdays", "Once".
  function alarmDaysText(days) {
    if (!days || !days.length) return i18n("once")
    if (days.length === 7) return i18n("everyDay")
    if (String(days) === "1,2,3,4,5") return i18n("weekdays")
    if (String(days) === "0,6") return i18n("weekends")
    return weekdayOrder.filter(function(d) { return days.indexOf(d) >= 0 })
      .map(function(d) { return weekdayName(d, false) }).join(" ")
  }

  function pomodoroPhaseName(phase) {
    return i18n(phase === "work" ? "focusPhase" : (phase === "longBreak" ? "longBreakPhase" : "breakPhase"))
  }

  function ringTitle(kind, item) {
    if (kind === "alarm") return item.label || i18n("alarm")
    return i18n("timerDone", { name: itemTitle("timers", item) })
  }

  function ringBody(kind, item, at) {
    if (kind === "alarm") return wallClock(item.hour, item.minute) + (item.tz ? " " + item.placeName : "")
      + " · " + alarmDaysText(item.days)
    return i18n("timerDoneBody", { duration: durationText(item.duration) })
  }

  function pomodoroPhaseTitle(pomodoro) {
    return itemTitle("pomodoros", pomodoro) + ": " + pomodoroPhaseName(pomodoro.phase)
  }

  function pomodoroPhaseBody(pomodoro) {
    var minutes = Model.pomodoroPhaseLength(pomodoro, pomodoro.phase) / 60000
    return pomodoro.state === "running"
      ? i18n("pomodoroRunsFor", { minutes: minutes, count: pomodoro.completed })
      : i18n("pomodoroWaits", { minutes: minutes, count: pomodoro.completed })
  }

  // ---- Selection, editing and actions per tab ------------------------------------

  readonly property var tabKinds: ({ alarms: "alarms", timers: "timers", stopwatches: "stopwatches", pomodoros: "pomodoros" })
  // Selected item id per tab, and the selected city's index.
  property var selection: ({})
  // The World tab's selection is the current place as well: -1 is here,
  // 0… a city. The clock on top shows the current place; alarms, chimes and
  // the menu bar stay on this computer's clock.
  property int selectedCity: -1
  // A city armed for deletion is disarmed once the selection leaves it,
  // as select() does for the other tabs.
  onSelectedCityChanged: {
    dialChooserOpen = false
    if (armedDeleteId.indexOf("city:") === 0 && armedDeleteId !== cityDeleteId(selectedCity))
      armedDeleteId = ""
    // From the index itself: currentPlace may not have caught up yet.
    placeStore.remember(selectedCity >= 0 && selectedCity < cityList.length ? Model.cityKey(cityList[selectedCity]) : "here")
  }
  property string editingId: ""
  property int editField: 0
  // Delete takes two presses; the first arms it for four seconds.
  property string armedDeleteId: ""
  Timer {
    id: armedDeleteTimer
    interval: 4000
    onTriggered: root.armedDeleteId = ""
  }
  // The text entries of the tabs (city search, new timer), and their state.
  property bool searchOpen: false
  property bool newTimerOpen: false
  property var activeTextField: null
  // The World tab's globe while it shows (its `perf` for the status), or
  // the flat map's.
  property var globeItem: null
  readonly property bool editingText: !!activeTextField && activeTextField.activeFocus

  function closeEditors() {
    dialChooserOpen = false
    editingId = ""
    editField = 0
    armedDeleteId = ""
    searchOpen = false
    newTimerOpen = false
  }

  function listFor(tab) {
    return tabKinds[tab] ? itemsStore.items[tabKinds[tab]] : []
  }

  function selectedIndex(tab) {
    var list = listFor(tab)
    var id = selection[tab]
    for (var i = 0; i < list.length; i++) if (list[i].id === id) return i
    return list.length ? 0 : -1
  }

  function selectedItem(tab) {
    var index = selectedIndex(tab)
    return index >= 0 ? listFor(tab)[index] : null
  }

  function select(tab, id) {
    var next = Object.assign({}, selection)
    next[tab] = id
    selection = next
    if (armedDeleteId !== id) armedDeleteId = ""
  }

  function stepSelection(tab, delta) {
    if (tab === "world") {
      selectedCity = Math.max(-1, Math.min(cityList.length - 1, selectedCity + delta))
      return
    }
    var list = listFor(tab)
    if (!list.length) return
    var index = Math.max(0, Math.min(list.length - 1, selectedIndex(tab) + delta))
    select(tab, list[index].id)
  }

  function moveSelected(tab, delta) {
    if (tab === "world") {
      // The place store follows the selected city to its new index.
      if (selectedCity >= 0) citiesStore.move(selectedCity, delta)
      return
    }
    var item = selectedItem(tab)
    if (item) itemsStore.move(tabKinds[tab], item.id, delta)
  }

  function addItem(tab) {
    var now = Date.now()
    nowMs = now
    if (tab === "world") {
      openCitySearch()
    } else if (tab === "alarms") {
      var next = new Date(now + 3600000)
      var alarm = Model.makeAlarm(next.getHours(), 0, now, { snoozeMinutes: generalSetting("snoozeMinutes", 9) })
      itemsStore.add("alarms", alarm)
      select("alarms", alarm.id)
      editingId = alarm.id
      editField = 0
    } else if (tab === "timers") {
      newTimerOpen = true
    } else if (tab === "stopwatches") {
      var watch = Model.stopwatchToggled(Model.makeStopwatch(now), now)
      itemsStore.add("stopwatches", watch)
      select("stopwatches", watch.id)
    } else if (tab === "pomodoros") {
      var pomodoro = Model.makePomodoro(now, {
        work: generalSetting("pomodoroWork", 25), shortBreak: generalSetting("pomodoroBreak", 5),
        longBreak: generalSetting("pomodoroLongBreak", 15), longEvery: generalSetting("pomodoroLongEvery", 0),
        autoContinue: generalSetting("pomodoroAuto", true)
      })
      itemsStore.add("pomodoros", pomodoro)
      select("pomodoros", pomodoro.id)
    }
  }

  // Starts a timer of the given length, from the presets, the entry or IPC.
  function startTimer(ms, label) {
    if (!(ms > 0)) return
    var now = Date.now()
    var timer = Model.timerStarted(Model.makeTimer(ms, now, label), now)
    itemsStore.add("timers", timer)
    select("timers", timer.id)
    newTimerOpen = false
  }

  function toggleItem(tab, id) {
    var now = Date.now()
    if (tab === "alarms") itemsStore.update("alarms", id, function(a) { return Model.alarmToggled(a, now) })
    else if (tab === "timers") itemsStore.update("timers", id, function(t) {
      return t.state === "done" ? Model.timerStarted(Model.timerReset(t), now) : Model.timerToggled(t, now)
    })
    else if (tab === "stopwatches") itemsStore.update("stopwatches", id, function(s) { return Model.stopwatchToggled(s, now) })
    else if (tab === "pomodoros") itemsStore.update("pomodoros", id, function(p) { return Model.pomodoroToggled(p, now) })
    nowMs = now
  }

  function resetItem(tab, id) {
    if (tab === "timers") itemsStore.update("timers", id, Model.timerReset)
    else if (tab === "stopwatches") itemsStore.update("stopwatches", id, Model.stopwatchReset)
    else if (tab === "pomodoros") itemsStore.update("pomodoros", id, Model.pomodoroReset)
  }

  function lapStopwatch(id) {
    var now = Date.now()
    itemsStore.update("stopwatches", id, function(s) { return Model.stopwatchLapped(s, now) })
  }

  function skipPomodoro(id) {
    var now = Date.now()
    itemsStore.update("pomodoros", id, function(p) { return Model.pomodoroSkipped(p, now) })
  }

  function extendTimer(id, deltaMs) {
    var now = Date.now()
    itemsStore.update("timers", id, function(t) { return Model.timerExtended(t, deltaMs, now) })
  }

  function updateItem(tab, id, fields) {
    itemsStore.update(tabKinds[tab], id, function(item) {
      var next = JSON.parse(JSON.stringify(item))
      for (var key in fields) next[key] = fields[key]
      return next
    })
  }

  // First press arms, the second (within four seconds) deletes.
  function deleteItem(tab, id) {
    if (armedDeleteId !== id) {
      armedDeleteId = id
      armedDeleteTimer.restart()
      return
    }
    armedDeleteId = ""
    if (tab === "world") {
      // "city:<index>": the selected city, or the one marked in the search.
      var at = Number(String(id).split(":")[1])
      if (!(at >= 0 && at < cityList.length)) return
      // The place store re-indexes the current place (TimePlaceStore.apply);
      // a removed current city falls back to here.
      citiesStore.removeAt(at)
      return
    }
    // Something ringing for the item stops with it.
    for (var i = 0; i < ringer.ringing.length; i++)
      if (ringer.ringing[i].itemId === id) ringer.stop(ringer.ringing[i].key)
    itemsStore.remove(tabKinds[tab], id)
    if (editingId === id) editingId = ""
  }

  // The Moon's tooltip on the map and the globe: "Moon · 61 % · waxing",
  // and under it how it stands at the current place at that moment (ms).
  function moonText(moon, ms) {
    var line = i18n(moon.waxing ? "moonWaxing" : "moonWaning", { percent: Math.round(moon.illuminated * 100) })
    var place = moonPlaceLine(ms === undefined ? nowMs : ms)
    return place ? line + "\n" + place : line
  }

  // How the map and the globe draw the Moon (Display → Moon view):
  // "space" lit towards the Sun (spaceAngle, Moon.moonLitAngle); "earth" as
  // it stands in the sky of the current place at ms (MoonView.js): the true
  // tilt of its lit limb, earthshine on a thin crescent, dimmed while below
  // the horizon. { angle, illuminated, earthshine, alpha }
  function moonLook(style, moon, spaceAngle, ms) {
    var c = currentCoordinates
    if (style !== "earth" || !c)
      return { angle: Moon.moonLitAngleFor(style, moon, spaceAngle, c ? Number(c.lat) : 0), illuminated: moon.illuminated,
        earthshine: false, alpha: 1 }
    var v = MoonView.view(Number(c.lat), Number(c.lon), ms, { riseSet: false })
    return { angle: v.litAngle, illuminated: v.illuminated, earthshine: v.earthshine, alpha: v.aboveHorizon ? 1 : 0.4 }
  }

  // The Moon at the current place at ms, worded: "Berlin: 23° high · SE ·
  // rises 6:42 PM · sets 7:10 AM" or "…: below the horizon · rises …", the
  // times in that place's clock; "" without a place. Kept per minute (the
  // rise and set search costs a few milliseconds).
  readonly property var moonPlaceCache: ({ key: "", text: "" })
  // quick: without rise and set (while time runs, a frame at a time).
  function moonPlaceLine(ms, quick) {
    var c = currentCoordinates
    if (!c) return ""
    var minute = Math.floor(ms / 60000) * 60000
    var key = minute + "|" + c.lat + "|" + c.lon + "|" + interfaceLanguage + "|" + currentName + "|" + !!quick
    if (moonPlaceCache.key === key) return moonPlaceCache.text
    var v = MoonView.view(Number(c.lat), Number(c.lon), minute, { riseSet: !quick })
    var offset = currentCity ? currentOffset : Model.localOffsetSeconds(minute)
    var parts = [v.aboveHorizon
      ? i18n("moonAboveHorizon", { altitude: Math.max(0, Math.round(v.apparentAltitude)), direction: i18n("compass_" + Moon.compassPoint(v.azimuth)) })
      : i18n("moonBelowHorizon")]
    var events = []
    if (v.rise) events.push({ at: v.rise, key: "moonRises" })
    if (v.set) events.push({ at: v.set, key: "moonSets" })
    events.sort(function(a, b) { return a.at - b.at })
    for (var i = 0; i < events.length; i++) parts.push(i18n(events[i].key, { time: clockFor(events[i].at, offset, false) }))
    var text = i18n("moonFromPlace", { place: currentName, details: parts.join(" · ") })
    // Changed in place: no binding hears of it.
    moonPlaceCache.key = key
    moonPlaceCache.text = text
    return text
  }

  // The label of the flat map and the globe (TimeMapHoverLabel.qml).
  function mapHoverText(hover) {
    if (!hover) return ""
    if (hover.text) return hover.text
    if (hover.moon) return moonText(hover.moon, hover.ms)
    return Model.utcOffsetLabel(hover.minutes * 60) + "  ·  " + clockFor(nowMs, hover.minutes * 60, false)
      + "  " + i18n("standardTime")
  }

  // What the pointer at (x, y) rests on over a map: the Moon where it was
  // drawn (moonHit), else the zone zoneAt(x, y) gives (minutes or null).
  function mapHoverAt(moonHit, x, y, zoneAt) {
    if (moonHit && Math.hypot(moonHit.x - x, moonHit.y - y) <= Style.space(8)) return { moon: moonHit.moon, ms: moonHit.ms, x: x, y: y }
    var minutes = zoneAt(x, y)
    return minutes === null ? null : { minutes: minutes, x: x, y: y }
  }

  // ---- Clock faces per place (TimeDial.qml) ----
  // -1 here (kept in more-time-place.json), 0… a city (in the cities file).
  function dialStyleFor(index) {
    if (index >= 0 && index < cityList.length) return Model.dialStyle(cityList[index].dial)
    return placeStore.hereDial
  }

  function setDialStyle(index, style) {
    if (index >= 0) citiesStore.setDial(index, style)
    else placeStore.setHereDial(style)
  }

  // The chooser under the selected row of the World list (e, or the pencil).
  property bool dialChooserOpen: false
  function stepDialStyle(delta) {
    var styles = Model.DIAL_STYLES
    var index = styles.indexOf(dialStyleFor(selectedCity))
    setDialStyle(selectedCity, styles[Math.max(0, Math.min(styles.length - 1, index + delta))])
  }

  // -1 here, 0… a city; an index past the list is ignored.
  function setCurrentPlace(index) {
    if (index >= -1 && index < cityList.length) selectedCity = index
  }

  // Here, the cities, here again.
  function cyclePlace(delta) {
    var count = cityList.length + 1
    selectedCity = ((selectedCity + 1 + delta) % count + count) % count - 1
  }

  // ---- The current place, for the clock on top ----
  readonly property var currentCity: selectedCity >= 0 && selectedCity < cityList.length ? cityList[selectedCity] : null
  readonly property string currentPlace: currentCity ? Model.cityKey(currentCity) : "here"
  // Its offset; a city whose zone is not read yet shows this computer's.
  readonly property int currentOffset: {
    var offset = currentCity ? cityOffset(currentCity) : null
    return offset === null ? localOffset : offset
  }
  readonly property var currentParts: currentCity ? Model.zonedParts(nowMs, currentOffset) : localParts
  readonly property string currentName: currentCity ? currentCity.name : here.name
  // Coordinates for the sun line, or null.
  readonly property var currentCoordinates: currentCity
    ? Model.placeFrom(currentCity.name, currentCity.lat, currentCity.lon) : here.place
  // The current place's zone abbreviation ("CEST"), or "".
  function currentAbbr() {
    if (!currentCity) {
      var name = Qt.formatDateTime(new Date(nowMs), "t")
      return /^[A-Za-z]{2,5}$/.test(name) ? name : ""
    }
    var state = zoneTable.revision >= 0 ? zoneTable.stateFor(currentCity.tz, nowMs) : null
    return state && state.abbr && !/^[+-]/.test(state.abbr) ? state.abbr : ""
  }

  // Sunrise, sunset, golden and blue hour of a place's day (WorldMap.sunTimes),
  // kept per place and day so the clock's tick does not recompute them.
  // A plain object, changed in place: filling it notifies no binding.
  readonly property var sunCache: ({})
  function sunTimesFor(coordinates, offset, utcMs) {
    if (!coordinates) return null
    var day = Math.floor((utcMs + offset * 1000) / 86400000)
    var key = coordinates.lat.toFixed(3) + "," + coordinates.lon.toFixed(3) + "," + offset + "," + day
    if (sunCache[key]) return sunCache[key]
    var keys = Object.keys(sunCache)
    // A few places a day: keep it small.
    if (keys.length >= 64) for (var i = 0; i < keys.length; i++) delete sunCache[keys[i]]
    sunCache[key] = WorldMap.sunTimes(coordinates.lat, coordinates.lon, utcMs, offset)
    return sunCache[key]
  }

  // The sun line: "󰖜 07:10 – 󰖛 18:50 · 󰖙 Golden 18:12–18:50 · 󰖔 Blue …",
  // the morning's golden and blue hour before noon there, the evening's
  // after. Which pieces show: sun, golden, blue. "" when there is nothing.
  // `next`: the next sunrise or sunset alone (tomorrow's sunrise once
  // today's are over).
  function sunLine(coordinates, offset, sun, golden, blue, next) {
    if (!coordinates || !(sun || golden || blue || next)) return ""
    var times = sunTimesFor(coordinates, offset, nowMs)
    if (!times) return ""
    var pieces = []
    var at = function(ms) { return clockFor(ms, offset, false) }
    if (sun) {
      if (times.polar === "day") pieces.push("\u{f0599} " + i18n("sunUpAllDay"))
      else if (times.polar === "night") pieces.push("\u{f0594} " + i18n("sunDownAllDay"))
      else if (times.sunrise || times.sunset)
        pieces.push("\u{f059c} " + (times.sunrise ? at(times.sunrise) : "–") + " – \u{f059b} " + (times.sunset ? at(times.sunset) : "–"))
    }
    if (next && !(sun && times.polar !== "")) {
      var event = null
      if (times.sunrise && nowMs < times.sunrise) event = { glyph: "\u{f059c}", at: times.sunrise }
      else if (times.sunset && nowMs < times.sunset) event = { glyph: "\u{f059b}", at: times.sunset }
      else {
        var tomorrow = sunTimesFor(coordinates, offset, nowMs + 86400000)
        event = { glyph: "\u{f059c}", at: tomorrow ? tomorrow.sunrise : 0 }
      }
      pieces.push(event.glyph + " " + (event.at ? at(event.at) : "—"))
    }
    var morning = Model.zonedParts(nowMs, offset).hour < 12
    var goldenRange = morning ? times.goldenMorning : times.goldenEvening
    var blueRange = morning ? times.blueMorning : times.blueEvening
    var ranges = []
    if (golden && goldenRange[0]) ranges.push({ at: goldenRange[0],
      text: "\u{f0599} " + i18n("goldenHourRange", { from: at(goldenRange[0]), to: at(goldenRange[1]) }) })
    if (blue && blueRange[0]) ranges.push({ at: blueRange[0],
      text: "\u{f0594} " + i18n("blueHourRange", { from: at(blueRange[0]), to: at(blueRange[1]) }) })
    ranges.sort(function(a, b) { return a.at - b.at })
    for (var i = 0; i < ranges.length; i++) pieces.push(ranges[i].text)
    // A line breaks between the pieces, never inside one.
    return pieces.map(function(p) { return p.replace(/ /g, "\u00a0") }).join("  ·  ")
  }

  function cityDeleteId(index) {
    return "city:" + index
  }

  function openCitySearch() {
    searchOpen = true
    citySearch.query = ""
  }

  // A full list (Model.MAX_CITIES) keeps the search open with its notice.
  function addCity(city) {
    if (!city) return
    var at = citiesStore.add(city)
    if (at < 0) return
    selectedCity = at
    searchOpen = false
    restoreKeyFocus()
  }

  // ---- Keyboard ----------------------------------------------------------------------
  // One map for popup and app (keep TimeShortcutsPage.qml in sync):
  //   Esc            close the editor, the search or the settings, then the panel
  //   Ctrl+,         settings              1–9   tabs
  //   Tab / ⇧Tab     next / previous bar panel (popup)
  //   o              open the app (popup)
  //   ↑ ↓ / j k      select                ⇧↑ ⇧↓ / J K   move the selection
  //   n / +          new item (World: add a city)
  //   Space / Enter  start / pause, alarm on / off
  //   e              edit                  r     reset
  //   l              lap (stopwatch)       s     skip phase (pomodoro), snooze
  //   x / Delete     delete (press twice)
  //   ← → / h l      World: city; Timers: one minute less / more
  //   / (World)      search a city
  //   Alt+0 / Alt+1–9 / Alt ← →   current place: here / city / round them
  //   In the search: ↑ ↓ within a section, Tab results ↔ cities, Enter pick,
  //   + add the marked result, − remove the marked city (TimeWorld.qml)
  //   m              mute / unmute the chimes
  //   PgUp PgDn Home End   scroll
  // While something rings, Space / Enter stop it and s snoozes.
  function handlePanelKey(event) {
    var key = event.key
    var text = String(event.text || "")
    var control = !!(event.modifiers & Qt.ControlModifier)
    var alt = !!(event.modifiers & Qt.AltModifier)
    var shift = !!(event.modifiers & Qt.ShiftModifier)

    if (key === Qt.Key_Escape) {
      // The Astro tab first: a travel stops, the date field is left.
      if (currentTab === "astro" && !settingsOpen && contentLoader.item && contentLoader.item.handleAstroEscape
          && contentLoader.item.handleAstroEscape()) {
        event.accepted = true
        return
      }
      if (dialChooserOpen) dialChooserOpen = false
      else if (editingId !== "") editingId = ""
      else if (searchOpen) searchOpen = false
      else if (newTimerOpen) newTimerOpen = false
      else if (settingsOpen && settingsLoader.item && settingsLoader.item.clearSearch()) {}
      else if (settingsOpen) settingsOpen = false
      else close()
      restoreKeyFocus()
      event.accepted = true
      return
    }
    if (control && (key === Qt.Key_Comma || text === ",")) {
      if (settingsOpen) settingsOpen = false
      else openSettings()
      event.accepted = true
      return
    }
    if (settingsOpen) {
      if (settingsLoader.item && settingsLoader.item.handleKey(event)) event.accepted = true
      return
    }
    // Typing goes to the field; Enter there is the field's own business.
    if (editingText) return
    // The Astro tab's camera: Ctrl + arrows turn and tilt, + − zoom, 0
    // back to the start (TimeAstro.handleAstroKey).
    if (currentTab === "astro" && !alt && contentLoader.item && contentLoader.item.handleAstroKey
        && contentLoader.item.handleAstroKey(event)) {
      event.accepted = true
      return
    }
    // The World tab's globe or map: + − zoom, 0 the whole earth, Ctrl +
    // arrows turn (TimeWorld.handleMapKey).
    if (currentTab === "world" && !alt && !searchOpen && !dialChooserOpen && contentLoader.item
        && contentLoader.item.handleMapKey && contentLoader.item.handleMapKey(event)) {
      event.accepted = true
      return
    }
    if (control) return

    if (ringer.ringing.length) {
      if (key === Qt.Key_Space || key === Qt.Key_Return || key === Qt.Key_Enter) {
        ringer.stopNewest()
        event.accepted = true
        return
      }
      if (text === "s") {
        ringer.snoozeNewest()
        event.accepted = true
        return
      }
    }

    var tab = currentTab
    if (editingId !== "" && tabKinds[tab]) {
      if (contentLoader.item && contentLoader.item.handleEditorKey && contentLoader.item.handleEditorKey(event)) {
        event.accepted = true
        return
      }
    }

    // The current place, from any tab: Alt 0 here, Alt 1–9 a city, Alt ← →
    // round here and the cities.
    if (alt && key >= Qt.Key_0 && key <= Qt.Key_9) {
      setCurrentPlace(key - Qt.Key_1)
      event.accepted = true
      return
    }
    if (alt && (key === Qt.Key_Left || key === Qt.Key_Right)) {
      cyclePlace((key === Qt.Key_Right ? 1 : -1) * (LayoutMirroring.enabled ? -1 : 1))
      event.accepted = true
      return
    }
    if (alt) return

    if (key === Qt.Key_Tab || key === Qt.Key_Backtab) {
      if (!standaloneMode) switchPanel(key === Qt.Key_Backtab || shift ? -1 : 1)
      event.accepted = true
      return
    }
    if (!shift && text >= "1" && text <= "9" && text.length === 1) {
      var tabIndex = Number(text) - 1
      if (tabIndex < displayTabs.length) activeTab = displayTabs[tabIndex]
      event.accepted = true
      return
    }
    if (text === "o" && !standaloneMode) {
      openApp()
      event.accepted = true
      return
    }
    if (text === "m") {
      setChimesMuted(!chimesMuted)
      event.accepted = true
      return
    }

    var down = key === Qt.Key_Down || text === "j" || text === "J"
    var up = key === Qt.Key_Up || text === "k" || text === "K"
    if (down || up) {
      if (shift || text === "J" || text === "K") moveSelected(tab, down ? 1 : -1)
      else stepSelection(tab, down ? 1 : -1)
      event.accepted = true
      return
    }
    if (key === Qt.Key_PageDown || key === Qt.Key_PageUp) {
      scrollBy((key === Qt.Key_PageDown ? 1 : -1) * contentScroll.height * 0.9)
      event.accepted = true
      return
    }
    if (key === Qt.Key_Home || key === Qt.Key_End) {
      scrollBy(key === Qt.Key_Home ? -contentScroll.contentHeight : contentScroll.contentHeight)
      event.accepted = true
      return
    }

    if (text === "n" || text === "+") {
      addItem(tab)
      event.accepted = true
      return
    }

    var left = key === Qt.Key_Left || text === "h"
    var right = key === Qt.Key_Right || text === "l"
    if (tab === "world") {
      // The clock face chooser: ← → style, Enter / Space / Esc close.
      if (dialChooserOpen) {
        if (left || right) stepDialStyle((right ? 1 : -1) * (LayoutMirroring.enabled ? -1 : 1))
        else if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space || text === "e") dialChooserOpen = false
        else if (key === Qt.Key_Up || key === Qt.Key_Down || text === "j" || text === "k") return
        event.accepted = true
        return
      }
      if (text === "e") {
        dialChooserOpen = true
        event.accepted = true
        return
      }
      if (text === "/") {
        openCitySearch()
        event.accepted = true
      } else if (left || right) {
        stepSelection("world", (right ? 1 : -1) * (LayoutMirroring.enabled ? -1 : 1))
        event.accepted = true
      } else if (key === Qt.Key_Delete || text === "x") {
        if (selectedCity >= 0 && selectedCity < cityList.length) deleteItem("world", cityDeleteId(selectedCity))
        event.accepted = true
      }
      return
    }

    var item = selectedItem(tab)
    if (!item) return
    if (key === Qt.Key_Space || key === Qt.Key_Return || key === Qt.Key_Enter) {
      toggleItem(tab, item.id)
    } else if (text === "e") {
      editingId = item.id
      editField = 0
    } else if (text === "r") {
      resetItem(tab, item.id)
    } else if (text === "l" && tab === "stopwatches") {
      lapStopwatch(item.id)
    } else if (text === "s" && tab === "pomodoros") {
      skipPomodoro(item.id)
    } else if (key === Qt.Key_Delete || text === "x") {
      deleteItem(tab, item.id)
    } else if ((left || right) && tab === "timers") {
      extendTimer(item.id, (right ? 1 : -1) * 60000)
    } else {
      return
    }
    event.accepted = true
  }

  // ---- Wheel and touchpad, as in More Weather (Panel.wheelPixels) ----
  // Omarchy scales touchpad scrolling down to 0.4, which made the view
  // crawl; pixel deltas are scaled back up. A mouse wheel scrolls a fixed
  // step per notch. Flickable's own wheel handling is not used.
  readonly property real touchpadScrollFactor: 2.5
  function wheelPixels(wheel, horizontal) {
    var pixels = horizontal ? wheel.pixelDelta.x : wheel.pixelDelta.y
    if (pixels !== 0) return pixels * touchpadScrollFactor
    var angle = horizontal ? wheel.angleDelta.x : wheel.angleDelta.y
    return angle / 120 * Style.space(60)
  }
  function wheelIsSideways(wheel) {
    if (wheel.modifiers & Qt.ShiftModifier) return true
    if (wheel.pixelDelta.x !== 0 || wheel.pixelDelta.y !== 0)
      return Math.abs(wheel.pixelDelta.x) > Math.abs(wheel.pixelDelta.y)
    return Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y)
  }
  // Sideways distance of a wheel step: Shift turns a vertical wheel sideways.
  function wheelSidewaysPixels(wheel) {
    var sideways = wheelPixels(wheel, true)
    return sideways !== 0 ? sideways : wheelPixels(wheel, false)
  }
  // Areas inside the page that take the wheel themselves (the steppers'
  // value, the globe sideways): each has wantsWheel(wheel).
  property var wheelAreas: []
  function registerWheelArea(item) {
    if (wheelAreas.indexOf(item) < 0) wheelAreas = wheelAreas.concat([item])
  }
  function unregisterWheelArea(item) {
    wheelAreas = wheelAreas.filter(function(area) { return area !== item })
  }
  // An area under the wheel hears of it (noticeWheel, if it has one) and,
  // when it wants it, takes it.
  function wheelTakenBelow(wheel, source) {
    for (var i = 0; i < wheelAreas.length; i++) {
      var area = wheelAreas[i]
      if (!area || !area.visible) continue
      var p = area.mapFromItem(source, wheel.x, wheel.y)
      if (p.x < 0 || p.y < 0 || p.x >= area.width || p.y >= area.height) continue
      if (typeof area.noticeWheel === "function") area.noticeWheel(wheel)
      if (area.wantsWheel(wheel)) return true
    }
    return false
  }

  function scrollBy(delta) {
    var maximum = Math.max(0, contentScroll.contentHeight - contentScroll.height)
    contentScroll.contentY = Math.max(0, Math.min(maximum, contentScroll.contentY + delta))
  }

  // Back to the panel's key handling, e.g. after a field or dropdown.
  function restoreKeyFocus() {
    root.defer(function() { keyCatcher.forceActiveFocus() })
  }

  // ---- IPC -------------------------------------------------------------------------

  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.openFromHotkey() }
    function close(): void { root.close() }
    function show(): void { root.openFromHotkey() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function settings(): void { root.openFromHotkey(); root.openSettings() }
    // A tab by name (world, alarms, timers, stopwatches, pomodoros, astro).
    function tab(name: string): void { root.openFromHotkey(); root.showTab(name) }
    // The World tab with city n (1-based) selected; the next / previous city.
    // The current place: city n (from 1), the next / previous one, or here.
    function city(n: int): void {
      root.openFromHotkey()
      root.showTab("world")
      if (n >= 1 && n <= root.cityList.length) root.selectedCity = n - 1
    }
    function here(): void { root.openFromHotkey(); root.showTab("world"); root.setCurrentPlace(-1) }
    function nextCity(): void { root.openFromHotkey(); root.showTab("world"); root.cyclePlace(1) }
    function previousCity(): void { root.openFromHotkey(); root.showTab("world"); root.cyclePlace(-1) }
    function stopRinging(): void { root.ringer.stopAll() }
    function snooze(): void { root.ringer.snoozeNewest() }
    // The chimes, for every instance (a general setting).
    function muteChimes(): void { root.setChimesMuted(true) }
    function unmuteChimes(): void { root.setChimesMuted(false) }
    function toggleChimes(): void { root.setChimesMuted(!root.chimesMuted) }
    // A timer of this many minutes, started at once.
    function startTimer(minutes: int): void { root.startTimer(minutes * 60000, "") }
    function toggleStopwatch(): void {
      var list = root.itemsStore.items.stopwatches
      if (list.length) root.toggleItem("stopwatches", list[0].id)
      else root.addItem("stopwatches")
    }
    function togglePomodoro(): void {
      var list = root.itemsStore.items.pomodoros
      if (!list.length) root.addItem("pomodoros")
      list = root.itemsStore.items.pomodoros
      if (list.length) root.toggleItem("pomodoros", list[0].id)
    }
    function status(): string {
      return JSON.stringify({
        instance: root.ringer.instanceId,
        leader: root.ringer.isLeader,
        ringing: root.ringer.ringing,
        language: root.interfaceLanguage,
        hour12: root.hour12,
        localOffset: root.localOffset,
        // The World tab's globe or map: GPU surface or Canvas, frames a
        // second, CPU (this process), and the last minute turning by itself.
        globe: root.globeItem ? root.globeItem.perf : null,
        zones: Object.keys(root.zoneTable.zones).length,
        zonesFetchedAt: root.zoneTable.fetchedAt,
        cities: root.cityList.map(function(c) {
          return { name: c.name, tz: c.tz, offset: root.cityOffset(c) }
        }),
        items: {
          alarms: root.itemsStore.items.alarms.length,
          timers: root.itemsStore.items.timers.length,
          stopwatches: root.itemsStore.items.stopwatches.length,
          pomodoros: root.itemsStore.items.pomodoros.length
        },
        nextAlarm: root.nextAlarm ? new Date(root.nextAlarm.at).toISOString() : null,
        here: { name: root.here.name, place: root.here.place, detect: root.here.detect,
          zone: root.zoneTable.localTz },
        currentPlace: root.currentPlace,
        chimes: {
          interval: root.chimeSettings.chimeInterval,
          minutes: root.chimeSettings.chimeInterval === "custom" ? root.chimeSettings.chimeMinutes : undefined,
          dailyHour: root.chimeSettings.chimeInterval === "daily" ? root.chimeSettings.chimeDailyHour : undefined,
          hourChime: root.chimeSettings.hourChime,
          tone: root.chimeTone,
          muted: root.chimesMuted,
          nextAt: (function() {
            var at = Model.nextChimeAt(root.chimeSettings, Date.now())
            return at ? new Date(at).toISOString() : null
          })()
        },
        tabs: root.displayTabs,
        currentTab: root.currentTab,
        menubar: root.menubarEntries,
        fastTick: root.fastTick
      })
    }
  }

  // ---- Popup and window ---------------------------------------------------------------

  // The bar's popup (TimePopup.qml), loaded by URL so the app, which has its
  // own window, never resolves the layer-shell types.
  Loader {
    id: popupLoader
    active: !root.standaloneMode
    Component.onCompleted: setSource(Qt.resolvedUrl("TimePopup.qml"), { timePanel: root })
  }
  readonly property Item popupContentHost: popupLoader.item ? popupLoader.item.contentHost : null
  readonly property real contentHeight: contentColumn.implicitHeight
  // Whether anything may move by itself (the globe and the solar system
  // turning): the popup open in the bar, or the app's window shown and
  // focused. An app window left open in the background, unfocused or on
  // another workspace, stays still. motionForced: the screenshot harness,
  // whose offscreen window never has the focus.
  property bool motionForced: false
  readonly property bool motionAllowed: opened && (!standaloneMode
    || (standaloneWindow.visible && (keyCatcher.Window.active || motionForced)))
  // The height the content shows at once, and where the tab's content
  // starts in it: the World tab fits its globe or map into what is visible.
  // In the popup its cap, not its height, which follows the content.
  readonly property real viewportHeight: standaloneMode ? contentScroll.height
    : (popupLoader.item ? popupLoader.item.contentCap : Style.space(720))
  readonly property real tabContentTop: contentLoader.y

  readonly property bool popupPointerInside: !standaloneMode && opened && !!popupLoader.item && popupLoader.item.spanHovered
  readonly property bool popupPointerOnAnchor: !standaloneMode && !!popupLoader.item && popupLoader.item.anchorHovered

  FloatingWindow {
    id: standaloneWindow
    visible: root.standaloneMode && root.opened
    title: root.i18n("appTitle")
    color: Color.popups.background
    implicitWidth: Style.space(620)
    implicitHeight: Style.space(820)
    minimumSize: Qt.size(Style.space(420), Style.space(480))

    onVisibleChanged: {
      if (!visible && root.standaloneMode && root.opened) root.close()
      else if (visible) root.defer(function() { keyCatcher.forceActiveFocus() })
    }

    Item {
      id: standaloneContentHost
      anchors.fill: parent
      anchors.margins: Style.spacing.popupPadding
    }
  }

  function tabComponent(key) {
    if (key === "world") return worldComponent
    if (key === "alarms") return alarmsComponent
    if (key === "timers") return timersComponent
    if (key === "stopwatches") return stopwatchesComponent
    if (key === "astro") return astroComponent
    return pomodorosComponent
  }

  Component { id: worldComponent; TimeWorld { panel: root } }
  Component { id: alarmsComponent; TimeAlarms { panel: root } }
  Component { id: timersComponent; TimeTimers { panel: root } }
  Component { id: stopwatchesComponent; TimeStopwatches { panel: root } }
  Component { id: pomodorosComponent; TimePomodoros { panel: root } }
  Component { id: astroComponent; TimeAstro { panel: root } }

  // The visible tree, for test screenshots (tests/ui-shots.sh).
  readonly property Item contentRoot: keyCatcher
  readonly property Item settingsItem: settingsLoader.item

  // One visual tree, reparented into either the popup card or the window.
  Item {
    id: keyCatcher
    parent: root.standaloneMode ? standaloneContentHost : root.popupContentHost
    anchors.fill: parent
    focus: true
    // Reparented outside this item, so right-to-left mirroring is set again.
    LayoutMirroring.enabled: I18n.isRightToLeft(root.interfaceLanguage)
    LayoutMirroring.childrenInherit: true
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) { root.handlePanelKey(event) }

    // A click on empty space takes the keys back from a text field.
    MouseArea {
      anchors.fill: parent
      onPressed: function(mouse) {
        root.restoreKeyFocus()
        mouse.accepted = false
      }
    }

    Flickable {
      id: contentScroll
      anchors.fill: parent
      contentWidth: width
      contentHeight: contentColumn.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height

      Column {
        id: contentColumn
        width: contentScroll.width
        spacing: Style.space(12)

        TimeRingBanner { panel: root; width: parent.width }
        TimeHero { panel: root; width: parent.width }
        TimeTabs { panel: root; width: parent.width }

        Loader {
          id: contentLoader
          width: parent.width
          active: root.currentTab !== ""
          sourceComponent: root.currentTab !== "" ? root.tabComponent(root.currentTab) : null
        }
      }
    }

    // Every wheel and touchpad scroll over the page goes through
    // wheelPixels, unless an area below takes it (wheelAreas).
    MouseArea {
      anchors.fill: contentScroll
      z: 2
      acceptedButtons: Qt.NoButton
      onWheel: function(wheel) {
        if (root.wheelTakenBelow(wheel, this)) {
          wheel.accepted = false
          return
        }
        root.scrollBy(-root.wheelPixels(wheel, false))
        wheel.accepted = true
      }
    }

    Loader {
      id: settingsLoader
      anchors.fill: parent
      z: 100
      active: root.settingsOpen
      sourceComponent: Component { TimeSettings { panel: root } }
    }
  }
}
