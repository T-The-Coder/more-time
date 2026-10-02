import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// The world clock's cities, [{ name, country, tz, lat, lon, dial }] (dial:
// the clock face style, Model.DIAL_STYLES), shared by bar
// and app. A missing file gives four sample cities (Model.defaultCities); a
// list emptied on purpose is written as [] and stays empty.
Item {
  id: cities
  required property var panel

  property var list: []
  property bool loaded: false

  property FileView file: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/more-time-cities.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: cities.apply(Model.parseCities(text(), false))
    onLoadFailed: cities.apply(Model.parseCities("", true))
  }

  function apply(next) {
    if (loaded && JSON.stringify(next) === JSON.stringify(list)) return
    list = next
    loaded = true
  }

  function write(next) {
    apply(next)
    file.setText(JSON.stringify(next, null, 1) + "\n")
  }

  function indexOfCity(city) {
    for (var i = 0; i < list.length; i++)
      if (list[i].tz === city.tz && list[i].name === city.name) return i
    return -1
  }

  // Returns the city's index; a city already in the list is not added twice.
  function add(city) {
    var index = indexOfCity(city)
    if (index >= 0) return index
    write(list.concat([{ name: city.name, country: city.country || "", tz: city.tz,
      lat: city.lat === undefined ? null : city.lat, lon: city.lon === undefined ? null : city.lon,
      dial: Model.dialStyle(city.dial) }]))
    return list.length - 1
  }

  // The clock face style of city `index`.
  function setDial(index, style) {
    if (index < 0 || index >= list.length) return
    var next = JSON.parse(JSON.stringify(list))
    next[index].dial = Model.dialStyle(style)
    write(next)
  }

  function removeAt(index) {
    if (index < 0 || index >= list.length) return
    var next = list.slice()
    next.splice(index, 1)
    write(next)
  }

  function move(index, delta) {
    var target = index + delta
    if (index < 0 || target < 0 || target >= list.length) return false
    var next = list.slice()
    var city = next.splice(index, 1)[0]
    next.splice(target, 0, city)
    write(next)
    return true
  }

  function replaceAll(raw) {
    write(Model.parseCities(JSON.stringify(raw || []), false))
  }
}
