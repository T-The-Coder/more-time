import QtQuick
import Quickshell
import Quickshell.Io
import "AstroIss.js" as AstroIss

// The ISS's orbit data for the Astro tab (option astroIss, off by default):
// one two-line element set from CelesTrak, checked (checksums, catalogue
// number 25544) and kept in more-time-iss.json with the time it was
// fetched, which every instance reads. Only the leading instance asks, only
// while the option is on and the Astro tab shows, at most every 12 hours
// (an hour after a failure); a failed fetch keeps the old data.
QtObject {
  id: store
  required property var panel
  // Whether the data is wanted now (the option on and the Astro tab shown).
  property bool wanted: false
  readonly property url sourceUrl: "https://celestrak.org/NORAD/elements/gp.php?CATNR=25544&FORMAT=TLE"
  readonly property int refreshMs: 12 * 3600000
  readonly property int retryMs: 3600000

  // The checked elements (AstroIss.parseTle) or null, the TLE's text and
  // when it was fetched (ms).
  property var elements: null
  property string tle: ""
  property double fetchedAt: 0
  property double failedAt: 0
  property bool loaded: false

  // Takes a TLE's text (the cache's or a fetch's): true when it is a valid
  // TLE of the ISS.
  function adoptTle(text, at) {
    var el = AstroIss.parseTle(text, AstroIss.ISS_CATALOG)
    if (el.error) return false
    elements = el
    tle = String(text)
    fetchedAt = Number(at) || 0
    return true
  }

  property TimeEchoGuard echo: TimeEchoGuard {}
  property FileView file: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/more-time-iss.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      if (!store.echo.isEcho(text())) {
        try {
          var parsed = JSON.parse(text())
          store.adoptTle(parsed.tle, parsed.at)
        } catch (e) {}
      }
      store.loaded = true
      store.panel.defer(store.maybeFetch)
    }
    onLoadFailed: {
      store.loaded = true
      store.panel.defer(store.maybeFetch)
    }
  }

  onWantedChanged: if (wanted) panel.defer(maybeFetch)

  function maybeFetch() {
    if (!wanted || !loaded || !panel.ringer.isLeader || request.running) return
    var now = Date.now()
    if (elements && now - fetchedAt < refreshMs && fetchedAt <= now) return
    if (now - failedAt < retryMs) return
    request.request = { url: String(sourceUrl), timeoutMs: 10000, maxBytes: 8 * 1024 }
    request.running = true
  }

  property Timer timer: Timer {
    interval: 10 * 60000
    repeat: true
    running: store.wanted
    onTriggered: store.maybeFetch()
  }

  property TimeRequest request: TimeRequest {
    onFinished: function(text) {
      var at = Date.now()
      if (store.adoptTle(text, at)) {
        var out = JSON.stringify({ at: at, tle: String(text).trim() }) + "\n"
        store.echo.wrote(out)
        store.file.setText(out)
        return
      }
      console.warn("more-time: ISS orbit data not usable")
      store.failedAt = at
    }
  }
}
