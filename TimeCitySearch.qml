import QtQuick
import Quickshell
import "Model.js" as Model
import "PlaceSearch.js" as PlaceSearch

// Finding a city for the world clock: the system's zone list answers at
// once and offline (zone1970.tab, one city per zone); the shared place
// search (TimePlaceSearch) adds Open-Meteo's places a moment later. Enter
// with nothing found asks Nominatim once (submit()); the next Enter adds what
// it found. Nominatim names no time zone: such a place takes the nearest
// zone1970 city's, marked as a guess (tzGuessed).
//
// While searching, the keys work in two sections, as in More Weather:
// "results" (the matches) and "saved" (the cities below); Tab switches.
Item {
  id: search
  required property var panel

  property string query: ""
  property var offline: []
  property int index: 0
  // "results" or "saved", and the marked saved city.
  property string section: "results"
  property int savedIndex: 0
  readonly property bool busy: online.busy
  // The zone list's matches, then the online ones for the current query;
  // a place already listed (PlaceSearch.samePlace, or the same name in the
  // same zone) only once.
  readonly property var results: {
    var list = []
    var index = panel.zoneTable.index
    var online = search.online.resultsCurrent ? search.online.results : []
    var all = offline.concat(online.map(function(place) { return Model.cityFromPlace(place, index) }))
    for (var i = 0; i < all.length && list.length < 10; i++) {
      if (!all[i]) continue
      if (Model.knownCity(list, all[i], PlaceSearch.samePlace)) continue
      list.push(all[i])
    }
    return list
  }
  // The service that answered last, for the Sources page: "open-meteo",
  // "nominatim" or "".
  readonly property string answeredBy: online.results.length ? online.activeProvider : ""
  onResultsChanged: index = Math.max(0, Math.min(index, results.length - 1))

  onQueryChanged: {
    index = 0
    section = "results"
    offline = panel.zoneTable.search(query)
    online.query = query
  }

  Connections {
    target: search.panel.zoneTable
    function onIndexReady() { search.offline = search.panel.zoneTable.search(search.query) }
  }

  property TimePlaceSearch online: TimePlaceSearch { panel: search.panel }

  // ↑ ↓ within the current section.
  function step(delta) {
    if (section === "saved") {
      var count = panel.cityList.length
      if (count) savedIndex = Math.max(0, Math.min(count - 1, savedIndex + delta))
      return
    }
    if (!results.length) return
    index = Math.max(0, Math.min(results.length - 1, index + delta))
  }

  // Tab / ⇧ Tab: results ↔ saved cities.
  function switchSection() {
    if (section === "results" && panel.cityList.length) {
      section = "saved"
      savedIndex = Math.max(0, Math.min(panel.cityList.length - 1, panel.selectedCity))
    } else {
      section = "results"
    }
  }

  // Enter: add the result, or make the saved city the current place; with
  // nothing found, ask Nominatim (once a second at most).
  function pick(i) {
    if (i === undefined && section === "saved") {
      panel.setCurrentPlace(savedIndex)
      panel.searchOpen = false
      panel.restoreKeyFocus()
      return
    }
    if (i === undefined && !results.length) {
      online.submit()
      return
    }
    var city = results[i === undefined ? index : i]
    if (city) panel.addCity(city)
  }

  // `+` (in the saved cities): add the result marked last and keep
  // searching, marked in the saved list.
  function addMarked() {
    var city = results[index]
    if (!city) return
    var at = panel.citiesStore.add(city)
    section = "saved"
    savedIndex = at
  }

  // `−`: remove the marked saved city, in two presses like `x`.
  function removeMarked() {
    if (section !== "saved" || savedIndex >= panel.cityList.length) return
    panel.deleteItem("world", panel.cityDeleteId(savedIndex))
    if (savedIndex >= panel.cityList.length) savedIndex = Math.max(0, panel.cityList.length - 1)
    if (!panel.cityList.length) section = "results"
  }
}
