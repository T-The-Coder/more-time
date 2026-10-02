import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// UTC offsets of the zones the world clock shows. QML's JavaScript has no
// Intl, and its Date only knows this computer's zone, so the offsets come
// from the system's tz database: one run of `zdump` over all wanted zones
// gives every change for the next years (Model.parseZoneDump), and from then
// on offsets are looked up without another process. The table is fetched
// again when the zone list changes, when it runs out, and after a day.
Item {
  id: table
  required property var panel

  // { "Area/City": { offset, abbr, transitions } }
  property var zones: ({})
  property var wanted: []
  // Raised with every new table, so bindings that look up offsets update.
  property int revision: 0
  property double fetchedAt: 0
  // A lookup has run at least once (it may have failed): a zone missing
  // after that is not coming.
  property bool fetched: false
  property double expiresAt: 0
  property var pendingZones: []

  readonly property string script: "export LC_ALL=C; y=$(date +%Y); for z in \"$@\"; do "
    + "printf '== %s %s %s\\n' \"$z\" \"$(TZ=$z date +%z)\" \"$(TZ=$z date +%Z)\"; "
    + "zdump -v -c \"$y,$((y + 4))\" \"$z\"; done"

  // The zones to keep offsets for; a change fetches the table again.
  function want(list) {
    var unique = []
    for (var i = 0; i < list.length; i++)
      if (list[i] && unique.indexOf(list[i]) < 0) unique.push(list[i])
    unique.sort()
    if (String(unique) === String(wanted) && !stale(Date.now())) return
    wanted = unique
    fetch()
  }

  function stale(nowMs) {
    return fetchedAt === 0 || nowMs - fetchedAt > 86400000 || (expiresAt > 0 && nowMs > expiresAt)
  }

  // Called from the panel's clock tick; cheap unless a refetch is due.
  function check(nowMs) {
    if (wanted.length && stale(nowMs) && !proc.running) fetch()
  }

  function fetch() {
    if (!wanted.length) return
    if (proc.running) {
      pendingZones = wanted
      return
    }
    // Zone names come from tzdata or the geocoder and were checked against
    // [A-Za-z0-9_+-/]; they travel as arguments, never through the shell.
    proc.command = ["bash", "-c", script, "more-time-zones"].concat(wanted)
    proc.running = true
  }

  function stateFor(tz, utcMs) {
    var zone = zones[tz]
    return zone ? Model.zoneStateAt(zone, utcMs) : null
  }

  // Offset in seconds, or null while the zone is not known yet.
  function offsetFor(tz, utcMs) {
    var state = stateFor(tz, utcMs)
    return state ? state.offset : null
  }

  property Process proc: Process {
    stdout: StdioCollector {
      id: collector
      onStreamFinished: {
        var parsed = Model.parseZoneDump(collector.text)
        var count = 0
        for (var key in parsed) count++
        if (count > 0) {
          table.zones = parsed
          table.fetchedAt = Date.now()
          table.expiresAt = Model.zoneTableExpires(parsed)
          table.revision++
        }
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) console.warn("more-time: zone lookup failed with exit code", exitCode)
      table.fetched = true
      if (table.pendingZones.length) {
        table.pendingZones = []
        table.fetch()
      }
    }
  }

  // ---- This computer's zone (from /etc/localtime), for the home marker on
  //      the map and its zone's highlight.
  property string localTz: ""
  readonly property var home: {
    for (var i = 0; i < index.length; i++) if (index[i].tz === localTz) return index[i]
    return null
  }
  property Process localTzProc: Process {
    running: true
    command: ["readlink", "-f", "/etc/localtime"]
    stdout: StdioCollector {
      onStreamFinished: {
        var m = /zoneinfo\/(?:posix\/|right\/)?([A-Za-z0-9_+\-\/]+)\s*$/.exec(text)
        table.localTz = m ? m[1] : ""
        if (table.localTz !== "") table.indexWanted = true
      }
    }
  }

  // ---- Offline city search: zone1970.tab names a city for every zone that
  //      has had its own clocks since 1970, with coordinates. Read on the
  //      first search only.
  property var index: []
  property bool indexWanted: false
  readonly property string zoneinfo: "/usr/share/zoneinfo"

  property string zoneTabText: ""
  property string isoTabText: ""

  property FileView zoneTabFile: FileView {
    path: table.indexWanted ? table.zoneinfo + "/zone1970.tab" : ""
    printErrors: false
    onLoaded: {
      table.zoneTabText = text()
      table.buildIndex()
    }
  }
  property FileView isoTabFile: FileView {
    path: table.indexWanted ? table.zoneinfo + "/iso3166.tab" : ""
    printErrors: false
    onLoaded: {
      table.isoTabText = text()
      table.buildIndex()
    }
  }

  // Raised when the index arrives, so a search typed before it can run again.
  signal indexReady()

  function buildIndex() {
    if (zoneTabText === "") return
    index = Model.parseZoneIndex(zoneTabText, isoTabText)
    indexReady()
  }

  function search(query) {
    indexWanted = true
    return Model.searchZoneIndex(index, query, 8)
  }

  // The tz database release, for the Sources page: the first line of
  // tzdata.zi reads "# version 2026c".
  property bool versionWanted: false
  property string databaseVersion: ""
  property Process versionProc: Process {
    running: table.versionWanted && table.databaseVersion === ""
    command: ["head", "-n", "1", table.zoneinfo + "/tzdata.zi"]
    stdout: StdioCollector {
      onStreamFinished: {
        var m = /version\s+(\S+)/.exec(text)
        table.databaseVersion = m ? m[1] : "?"
      }
    }
  }
}
