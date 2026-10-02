import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model
import "PlaceSearch.js" as PlaceSearch

// Settings → General → Places: More Weather's saved places taken over as
// world clock cities. Only reads its file; the button waits for it to exist.
// Its places have coordinates but no zone: each new one is looked up by name
// once (the shared place search) and takes the first result's zone when that
// lies within 25 km, else the nearest zone1970 city's (offline too).
Item {
  id: placesImport
  required property var panel

  readonly property string path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/more-weather-locations.json"
  property bool available: false
  property bool busy: false
  // The last run: { added, existing }, or null.
  property var status: null

  // The run in progress: places to look up, and those resolved.
  property var queue: []
  property var resolved: []
  property int existing: 0
  property var current: null
  property bool asking: false

  function run() {
    if (!available || busy) return
    var places = Model.parseWeatherPlaces(file.text())
    var fresh = []
    var known = 0
    for (var i = 0; i < places.length; i++) {
      // Known by coordinates already: no lookup needed.
      if (Model.knownCity(panel.cityList, { name: places[i].name, lat: places[i].lat, lon: places[i].lon, tz: "" },
        PlaceSearch.samePlace)) known++
      else fresh.push(places[i])
    }
    existing = known
    resolved = []
    queue = fresh
    busy = true
    status = null
    // The nearest-zone fallback needs zone1970.tab.
    panel.zoneTable.indexWanted = true
    if (panel.zoneTable.index.length) next()
  }

  Connections {
    target: placesImport.panel.zoneTable
    function onIndexReady() { if (placesImport.busy && !placesImport.current) placesImport.next() }
  }

  function next() {
    if (!queue.length) {
      finish()
      return
    }
    var place = queue[0]
    queue = queue.slice(1)
    // The query is set in steps (TimePlaceSearch's onQueryChanged reads
    // `trimmed` before that binding has caught up, so a jump from "" to a
    // name would be taken for a too short one); the lookup's busy changes
    // meanwhile are not its answer.
    asking = true
    lookup.query = ""
    lookup.query = place.name + " "
    lookup.query = place.name
    asking = false
    current = place
    timeout.restart()
  }

  function resolve(results) {
    if (!current) return
    timeout.stop()
    var place = current
    current = null
    var tz = Model.zoneForPlace(results, place.lat, place.lon, panel.zoneTable.index)
    if (tz !== "") resolved = resolved.concat([{ name: place.name, lat: place.lat, lon: place.lon, tz: tz }])
    panel.defer(next)
  }

  function finish() {
    var merged = Model.mergeImportedPlaces(panel.cityList, resolved, PlaceSearch.samePlace)
    if (merged.added > 0) panel.citiesStore.replaceAll(merged.list)
    status = { added: merged.added, existing: existing + merged.existing }
    busy = false
  }

  // Asked for one name at a time; it answers when it is no longer busy.
  property TimePlaceSearch lookup: TimePlaceSearch {
    panel: placesImport.panel
    onBusyChanged: if (!busy && placesImport.current && !placesImport.asking) placesImport.resolve(results)
  }

  // A lookup that never answers falls back to the nearest zone.
  property Timer timeout: Timer {
    interval: 20000
    onTriggered: placesImport.resolve([])
  }

  property FileView file: FileView {
    path: placesImport.path
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: placesImport.available = true
    onLoadFailed: placesImport.available = false
  }
}
