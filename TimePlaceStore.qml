import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// The current place (the clock on top), shared by the bar and the app and
// kept across restarts:
//   ~/.local/state/omarchy/settings/more-time-place.json
//   { "current": "here" | "<tz>|<name>", "hereDial": "classic" | … }
// hereDial: the clock face style of "here" (the cities keep theirs in the
// cities file).
// The panel's selectedCity follows the stored key; a city that is gone
// falls back to here.
Item {
  id: store
  required property var panel

  property string current: "here"
  property string hereDial: "classic"
  property bool loaded: false
  property var recentWrites: []

  property FileView file: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/more-time-place.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: store.adopt(text())
    onLoadFailed: store.adopt("")
  }

  function adopt(raw) {
    // An older write of ours reported after a newer one is an echo.
    var echo = recentWrites.indexOf(String(raw))
    if (echo >= 0 && echo < recentWrites.length - 1) return
    var parsed = null
    try { parsed = JSON.parse(String(raw || "")) } catch (e) { parsed = null }
    current = parsed && typeof parsed.current === "string" && parsed.current !== "" ? parsed.current : "here"
    hereDial = Model.dialStyle(parsed ? parsed.hereDial : "")
    loaded = true
    apply()
  }

  // The stored key as the panel's selection.
  function apply() {
    var list = panel.cityList
    var index = -1
    for (var i = 0; i < list.length; i++) if (Model.cityKey(list[i]) === current) index = i
    if (panel.selectedCity !== index) panel.selectedCity = index
  }

  // The panel's selection changed: store it, unless it is what is stored.
  function remember(key) {
    if (!loaded || key === current) return
    current = key
    save()
  }

  function setHereDial(style) {
    var next = Model.dialStyle(style)
    if (next === hereDial) return
    hereDial = next
    save()
  }

  function save() {
    var text = JSON.stringify({ current: current, hereDial: hereDial }) + "\n"
    recentWrites = recentWrites.concat([text]).slice(-8)
    file.setText(text)
  }

  Connections {
    target: store.panel
    // Reordered, removed, renamed: the stored city keeps its place.
    function onCityListChanged() { if (store.loaded) store.apply() }
  }
}
