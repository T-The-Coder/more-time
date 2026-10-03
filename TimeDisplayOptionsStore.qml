import QtQuick
import Quickshell
import Quickshell.Io
import "I18n.js" as I18n
import "Model.js" as Model

// Loads, sanitizes and writes the general options and the per-surface
// display options (app, widget, menu bar). Reading an option stays on the
// panel (generalSetting, displaySetting and friends).
Item {
  id: store
  required property var panel

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/settings/"

  // General options apply to the menu bar, the widget and the app alike.
  // Each takes one of a few values, or is a switch (bool default).
  readonly property var generalChoices: ({
    language: null,
    timeFormat: ["auto", "24", "12"],
    alarmSound: panel.ringer.soundIds,
    timerSound: panel.ringer.soundIds,
    pomodoroSound: panel.ringer.soundIds,
    volume: [25, 50, 75, 100],
    snoozeMinutes: [5, 9, 10, 15],
    pomodoroWork: [15, 20, 25, 30, 45, 50, 60, 90],
    pomodoroBreak: [3, 5, 10, 15, 20],
    pomodoroLongBreak: [10, 15, 20, 30],
    pomodoroLongEvery: [0, 2, 3, 4, 5, 6],
    chimeInterval: Model.CHIME_INTERVALS,
    chimeDailyHour: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23],
    hourChime: ["off", "12", "24"],
    chimeTone: panel.ringer.chimeTones,
    chimeVolume: [25, 50, 75, 100]
  })
  readonly property var generalDefaults: ({
    language: "auto",
    timeFormat: "auto",
    alarmSound: "alarm",
    timerSound: "bell",
    pomodoroSound: "complete",
    volume: 75,
    snoozeMinutes: 9,
    pomodoroWork: 25,
    pomodoroBreak: 5,
    pomodoroLongBreak: 15,
    pomodoroLongEvery: 0,
    pomodoroAuto: true,
    chimeInterval: "quarter",
    chimeMinutes: 30,
    chimeDailyHour: 12,
    hourChime: "off",
    chimeTone: "beep",
    chimeVolume: 50,
    chimesMuted: false,
    detectLocation: false,
    timerPresets: "1,3,5,10,15,25,60"
  })
  // Read once: until then the chimes stay quiet, so a start does not beep
  // with the defaults before the chosen settings are known.
  property bool generalLoaded: false

  property FileView generalOptionsFile: FileView {
    path: store.stateDir + "more-time-general.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: store.loadGeneralOptions(text())
    onLoadFailed: store.loadGeneralOptions("")
  }

  function normalizedGeneral(key, value) {
    var fallback = generalDefaults[key]
    if (key === "language") {
      var language = String(value || "auto")
      return I18n.supportedLanguages().indexOf(language) >= 0 ? language : "auto"
    }
    if (typeof fallback === "boolean") return typeof value === "boolean" ? value : fallback
    // A free number of minutes (custom chime interval), 1–1440.
    if (key === "chimeMinutes") return Model.chimeMinutesValue(value) || fallback
    // The timer presets: "1,3,5" (Model.parseTimerPresets).
    if (key === "timerPresets") return Model.timerPresetsText(value)
    var choices = generalChoices[key] || []
    for (var i = 0; i < choices.length; i++)
      if (String(choices[i]) === String(value)) return choices[i]
    return fallback
  }

  function sanitizedGeneral(raw) {
    var source = raw && typeof raw === "object" ? raw : ({})
    var result = ({})
    for (var key in generalDefaults) result[key] = normalizedGeneral(key, source[key])
    return result
  }

  // Each file this store writes, guarded against late reports of its own
  // older writes (TimeEchoGuard).
  property TimeEchoGuard generalEcho: TimeEchoGuard {}
  property TimeEchoGuard appEcho: TimeEchoGuard {}
  property TimeEchoGuard widgetEcho: TimeEchoGuard {}
  property TimeEchoGuard menubarEcho: TimeEchoGuard {}

  function echoFor(surface) {
    return surface === "app" ? appEcho : (surface === "widget" ? widgetEcho : menubarEcho)
  }

  function writeGeneral(next) {
    panel.generalOptions = next
    var text = JSON.stringify(next) + "\n"
    generalEcho.wrote(text)
    generalOptionsFile.setText(text)
  }

  function loadGeneralOptions(raw) {
    if (generalEcho.isEcho(raw)) return
    var parsed = ({})
    try { parsed = JSON.parse(String(raw || "{}")) || ({}) } catch (e) { parsed = ({}) }
    panel.generalOptions = sanitizedGeneral(parsed)
    generalLoaded = true
  }

  function setGeneralSetting(key, value) {
    var next = sanitizedGeneral(panel.generalOptions)
    next[key] = normalizedGeneral(key, value)
    writeGeneral(next)
  }

  function generalIsDefault() {
    for (var key in generalDefaults)
      if (panel.generalSetting(key, generalDefaults[key]) !== generalDefaults[key]) return false
    return true
  }

  function restoreGeneralDefaults() {
    var next = sanitizedGeneral({})
    writeGeneral(next)
  }

  // ---- Display options per surface ----

  property FileView appDisplayOptionsFile: FileView {
    path: store.stateDir + "more-time-app-display.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: store.loadDisplayOptionsFor("app", text())
    onLoadFailed: store.loadDisplayOptionsFor("app", "")
  }

  property FileView widgetDisplayOptionsFile: FileView {
    path: store.stateDir + "more-time-widget-display.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: store.loadDisplayOptionsFor("widget", text())
    onLoadFailed: store.loadDisplayOptionsFor("widget", "")
  }

  property FileView menubarDisplayOptionsFile: FileView {
    path: store.stateDir + "more-time-menubar-display.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: store.loadDisplayOptionsFor("menubar", text())
    onLoadFailed: store.loadDisplayOptionsFor("menubar", "")
  }

  function reloadAll() {
    appDisplayOptionsFile.reload()
    widgetDisplayOptionsFile.reload()
    menubarDisplayOptionsFile.reload()
  }

  // Settings that take one of a few values, not a switch.
  readonly property var choiceKeys: ({
    citiesCount: ["1", "2", "3", "4"],
    menubarAccents: ["off", "hover", "always"],
    worldStyle: ["map", "globe"],
    worldMoonStyle: ["space", "earth"],
    globeRotateDelay: ["5", "10", "30"],
    globeRotateSpeed: ["1", "2", "4", "8"],
    heroDial: ["place", "classic", "minimal", "roman", "twentyFour", "dots"]
  })

  function normalizedChoice(key, value, fallback) {
    var text = String(value === undefined || value === null ? "" : value)
    return choiceKeys[key].indexOf(text) >= 0 ? text : fallback
  }

  function normalizedTab(value, fallback) {
    var key = String(value || "")
    return panel.defaultTabOrder().indexOf(key) >= 0 ? key : fallback
  }

  function sanitizedDisplayOptions(raw, surface) {
    var defaults = panel.defaultOptionsFor(surface)
    var source = raw && typeof raw === "object" ? raw : ({})
    var result = ({})
    for (var key in defaults) {
      if (key === "defaultTab") result[key] = normalizedTab(source[key], defaults[key])
      else if (key.indexOf("Order") > 0) result[key] = panel.sanitizedOrder(source[key], key)
      else if (choiceKeys[key]) result[key] = normalizedChoice(key, source[key], defaults[key])
      else result[key] = typeof source[key] === "boolean" ? source[key] : defaults[key]
    }
    // The single "worldSun" switch of before: on becomes the next event.
    if (source.worldSun === true && typeof source.worldSunNext !== "boolean" && "worldSunNext" in result)
      result.worldSunNext = true
    return result
  }

  function optionsFor(surface) {
    return surface === "app" ? panel.appDisplayOptions
      : (surface === "widget" ? panel.widgetDisplayOptions : panel.menubarDisplayOptions)
  }

  function assign(surface, next, writeFile) {
    var text = JSON.stringify(next) + "\n"
    if (writeFile) echoFor(surface).wrote(text)
    if (surface === "app") {
      panel.appDisplayOptions = next
      if (writeFile) appDisplayOptionsFile.setText(text)
    } else if (surface === "widget") {
      panel.widgetDisplayOptions = next
      if (writeFile) widgetDisplayOptionsFile.setText(text)
    } else {
      panel.menubarDisplayOptions = next
      if (writeFile) menubarDisplayOptionsFile.setText(text)
    }
  }

  function loadDisplayOptionsFor(surface, raw) {
    if (echoFor(surface).isEcho(raw)) return
    var parsed = ({})
    try { parsed = JSON.parse(String(raw || "{}")) } catch (e) { parsed = ({}) }
    var next = sanitizedDisplayOptions(parsed, surface)
    var firstLoad = surface === "app" ? !panel.appDisplayOptionsLoaded
      : (surface === "widget" ? !panel.widgetDisplayOptionsLoaded : !panel.menubarDisplayOptionsLoaded)
    assign(surface, next, false)
    if (surface === "app") panel.appDisplayOptionsLoaded = true
    else if (surface === "widget") panel.widgetDisplayOptionsLoaded = true
    else panel.menubarDisplayOptionsLoaded = true
    if (firstLoad && panel.opened && surface === panel.activeSurface) panel.activeTab = next.defaultTab
  }

  function setSettingsDisplaySetting(key, value) {
    var surface = panel.settingsTargetSurface
    var next = sanitizedDisplayOptions(optionsFor(surface), surface)
    if (key === "defaultTab") next[key] = normalizedTab(value, next[key])
    else if (choiceKeys[key]) next[key] = normalizedChoice(key, value, next[key])
    else if (key.indexOf("Order") > 0) next[key] = panel.sanitizedOrder(value, key)
    else next[key] = !!value
    // A menu bar entry shows always, when relevant, or on hover: switching
    // one on switches the other two off.
    if (surface === "menubar" && next[key] === true) {
      var base = key.replace(/(WhenRelevant|OnHover)$/, "")
      var siblings = [base, base + "WhenRelevant", base + "OnHover"]
      for (var i = 0; i < siblings.length; i++)
        if (siblings[i] !== key && siblings[i] in next) next[siblings[i]] = false
    }
    assign(surface, next, true)
    if (key === "defaultTab" && surface === panel.activeSurface) panel.activeTab = next.defaultTab
  }

  function restoreSettingsDisplayDefaults() {
    var surface = panel.settingsTargetSurface
    var next = panel.defaultOptionsFor(surface)
    assign(surface, next, true)
    if (surface === panel.activeSurface) panel.activeTab = next.defaultTab
  }

  function restoreSettingsDisplayOrder() {
    if (panel.settingsTargetSurface === "menubar") setSettingsDisplaySetting("entryOrder", panel.defaultEntryOrder())
    else setSettingsDisplaySetting("tabOrder", panel.defaultTabOrder())
  }

  function settingsDisplayIsDefault() {
    var surface = panel.settingsTargetSurface
    var options = optionsFor(surface)
    var defaults = panel.defaultOptionsFor(surface)
    for (var key in defaults) {
      var value = options[key]
      if (typeof defaults[key] === "object") {
        if (String(value) !== String(defaults[key])) return false
      } else if (value !== defaults[key]) return false
    }
    return true
  }

  function moveSettingsDisplayEntry(orderKey, key, delta) {
    var order = panel.sanitizedOrder(panel.settingsDisplaySetting(orderKey, null), orderKey)
    var index = order.indexOf(key)
    var target = index + delta
    if (index < 0 || target < 0 || target >= order.length) return
    order.splice(index, 1)
    order.splice(target, 0, key)
    setSettingsDisplaySetting(orderKey, order)
  }

  // Everything an import brings, for settings import; parts it lacks stay.
  function replaceAll(general, display) {
    if (general && typeof general === "object") {
      writeGeneral(sanitizedGeneral(general))
    }
    var surfaces = ["menubar", "widget", "app"]
    for (var i = 0; i < surfaces.length; i++) {
      var raw = display && typeof display === "object" ? display[surfaces[i]] : null
      if (raw && typeof raw === "object") assign(surfaces[i], sanitizedDisplayOptions(raw, surfaces[i]), true)
    }
  }
}
