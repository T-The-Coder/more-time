import QtQuick
import "AstroLapse.js" as AstroLapse

// The time lapse's clock (AstroLapse.js), for the Astro tab and the World
// map: while running, every frame worth drawing it moves the shown moment
// (shownMs, read on each tick) by the real time that passed at the preset's
// speed and reports the new one; `stopped` at the range's ends.
Timer {
  id: lapse
  property var preset: null
  property int fps: 15
  property double shownMs: 0
  signal advanced(double ms, bool stopped)

  interval: preset ? Math.max(16, Math.round(AstroLapse.frameInterval(preset, fps))) : 1000
  repeat: true
  property double last: 0
  property double carry: 0
  onRunningChanged: {
    last = Date.now()
    carry = 0
  }
  onTriggered: {
    if (!preset) return
    var now = Date.now()
    var r = AstroLapse.advance(shownMs, preset, Math.min(1000, now - last), carry, 1)
    last = now
    carry = r.carryMs
    advanced(r.shownMs, r.stopped)
  }
}
