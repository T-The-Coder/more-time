import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Where "here" is, for the clock's place name, sunrise and sunset and the
// sky colour of the time in the bar. In this order:
//   1. Omarchy's shared weather location (settings/weather.json), only read;
//   2. with "Detect my location" on: an IP geolocation service (ipwho.is,
//      then ipapi.co, then GeoJS, as More Weather asks them), the answer
//      kept for six hours in
//        ~/.local/state/omarchy/settings/more-time-here.json
//        { name, lat, lon, at, route, provider }
//      and asked again when the network changes (another default route);
//      only the ringing instance (TimeRinger.isLeader) asks;
//   3. the city of this computer's time zone (zone1970.tab).
// The zone of "here" is always this computer's.
Item {
  id: here
  required property var panel

  readonly property int cacheMs: 6 * 3600000
  readonly property int retryMs: 10 * 60000
  readonly property bool detect: panel.generalSetting("detectLocation", false) === true

  property var weatherPlace: null
  property var ipPlace: null
  property bool cacheLoaded: false
  property string route: ""
  property double failedAt: 0
  property int providerIndex: 0

  // { name, lat, lon, source: "weather" | "ip" | "zone" }, or null.
  readonly property var place: {
    if (weatherPlace) return { name: weatherPlace.name, lat: weatherPlace.lat, lon: weatherPlace.lon, source: "weather" }
    if (detect && ipPlace) return { name: ipPlace.name, lat: ipPlace.lat, lon: ipPlace.lon, source: "ip" }
    var home = panel.zoneTable.home
    var fromZone = home ? Model.placeFrom(home.name, home.lat, home.lon) : null
    if (fromZone) return { name: fromZone.name, lat: fromZone.lat, lon: fromZone.lon, source: "zone" }
    return null
  }
  // The name to show: the place's, else the zone's city, else "Here".
  readonly property string name: place && place.name ? place.name
    : (panel.zoneTable.localTz !== "" ? Model.zoneCityName(panel.zoneTable.localTz) : panel.i18n("here"))

  property FileView weatherFile: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/weather.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: here.weatherPlace = Model.weatherLocation(text())
    onLoadFailed: here.weatherPlace = null
  }

  property FileView cacheFile: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/more-time-here.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: here.adoptCache(text())
    onLoadFailed: here.adoptCache("")
  }

  function adoptCache(raw) {
    var parsed = null
    try { parsed = JSON.parse(String(raw || "")) } catch (e) { parsed = null }
    var place = parsed ? Model.placeFrom(parsed.name, parsed.lat, parsed.lon) : null
    ipPlace = place ? { name: place.name, lat: place.lat, lon: place.lon,
      at: Number(parsed.at) || 0, route: String(parsed.route || ""), provider: String(parsed.provider || "") } : null
    cacheLoaded = true
    panel.defer(maybeLookup)
  }

  onDetectChanged: panel.defer(maybeLookup)
  onWeatherPlaceChanged: panel.defer(maybeLookup)
  onRouteChanged: panel.defer(maybeLookup)

  Connections {
    target: here.panel.ringer
    function onIsLeaderChanged() { if (here.panel.ringer.isLeader) routeProc.running = true }
  }

  // The default route names the network; a new one may mean a new place.
  property Process routeProc: Process {
    command: ["ip", "-o", "route", "show", "default"]
    stdout: StdioCollector {
      onStreamFinished: here.route = text.trim().split("\n")[0] || ""
    }
  }

  property Timer routeTimer: Timer {
    interval: 60000
    repeat: true
    running: here.detect && !here.weatherPlace && here.panel.ringer.isLeader
    triggeredOnStart: true
    onTriggered: {
      if (!routeProc.running) routeProc.running = true
      here.maybeLookup()
    }
  }

  function maybeLookup() {
    if (!detect || weatherPlace || !cacheLoaded || !panel.ringer.isLeader || request.running) return
    var now = Date.now()
    var fresh = ipPlace && now - ipPlace.at < cacheMs && ipPlace.at <= now && ipPlace.route === route
    if (fresh || now - failedAt < retryMs) return
    providerIndex = 0
    ask()
  }

  function ask() {
    request.request = { url: Model.IP_PLACE_PROVIDERS[providerIndex].url, timeoutMs: 6000, maxBytes: 64 * 1024 }
    request.running = true
  }

  property TimeRequest request: TimeRequest {
    onFinished: function(text) {
      var provider = Model.IP_PLACE_PROVIDERS[here.providerIndex]
      var place = Model.ipPlace(provider.id, text)
      if (place) {
        var entry = { name: place.name, lat: place.lat, lon: place.lon, at: Date.now(), route: here.route, provider: provider.id }
        here.ipPlace = entry
        here.cacheFile.setText(JSON.stringify(entry) + "\n")
        return
      }
      if (here.providerIndex + 1 < Model.IP_PLACE_PROVIDERS.length) {
        here.providerIndex++
        here.panel.defer(here.ask)
        return
      }
      console.warn("more-time: location lookup failed")
      here.failedAt = Date.now()
    }
  }
}
