.pragma library
.import "AstroDate.js" as AstroDate

// Time-lapse autoplay for the Astro view and the Earth globe/map: named
// speeds, how far the shown moment moves for the real time that passed,
// the label's parts (numbers and unit keys; the QML side words them) and
// how often a frame is worth drawing. Pure functions, tested in Node.
//
// A year here is the Julian year of exactly 365.25 days of 86 400 s (the
// IAU's unit "a", https://en.wikipedia.org/wiki/Julian_year_(astronomy),
// retrieved 2026-10-05): "a year in a minute" is 365.25 × 86 400 / 60 =
// 525 960 simulated seconds per second. The seasons repeat with the
// tropical year (365.2422 d), 11 minutes shorter; over one lapse that
// is invisible.

var DAY_S = 86400
var YEAR_S = 365.25 * DAY_S
var DAY_MS = 86400000

// The presets. simulatedSecondsPerSecond: shown time per real time.
// sampleMs (0 for none): the shown time moves only in whole steps of this
// size from where it started, so the globe shows the same clock time every
// day and only the seasons change. amount/unit and inAmount/inUnit are the
// label's parts ("1 year in 1 hour"). views: where a preset is offered.
var PRESETS = [
  { id: "realTime", simulatedSecondsPerSecond: 1, sampleMs: 0, amount: 1, unit: "second", inAmount: 1, inUnit: "second", views: ["astro", "globe"] },
  { id: "dayInMinute", simulatedSecondsPerSecond: DAY_S / 60, sampleMs: 0, amount: 1, unit: "day", inAmount: 1, inUnit: "minute", views: ["astro", "globe"] },
  { id: "dayIn10Seconds", simulatedSecondsPerSecond: DAY_S / 10, sampleMs: 0, amount: 1, unit: "day", inAmount: 10, inUnit: "second", views: ["globe"] },
  { id: "monthInMinute", simulatedSecondsPerSecond: YEAR_S / 12 / 60, sampleMs: 0, amount: 1, unit: "month", inAmount: 1, inUnit: "minute", views: ["astro"] },
  { id: "yearInHour", simulatedSecondsPerSecond: YEAR_S / 3600, sampleMs: 0, amount: 1, unit: "year", inAmount: 1, inUnit: "hour", views: ["astro"] },
  { id: "yearIn10Minutes", simulatedSecondsPerSecond: YEAR_S / 600, sampleMs: 0, amount: 1, unit: "year", inAmount: 10, inUnit: "minute", views: ["astro"] },
  { id: "yearInMinute", simulatedSecondsPerSecond: YEAR_S / 60, sampleMs: 0, amount: 1, unit: "year", inAmount: 1, inUnit: "minute", views: ["astro"] },
  { id: "seasonsInMinute", simulatedSecondsPerSecond: YEAR_S / 60, sampleMs: DAY_MS, amount: 1, unit: "year", inAmount: 1, inUnit: "minute", views: ["globe"] }
]

// The preset with an id, or null.
function preset(id) {
  for (var i = 0; i < PRESETS.length; i++) if (PRESETS[i].id === id) return PRESETS[i]
  return null
}

// The presets offered in a view ("astro" or "globe"), in order of speed.
function presetsFor(view) {
  var out = []
  for (var i = 0; i < PRESETS.length; i++) if (PRESETS[i].views.indexOf(view) >= 0) out.push(PRESETS[i])
  return out
}

// The Astro tab's range (AstroDate.MIN_YEAR … MAX_YEAR) in ms.
function yearStartMs(year) {
  var d = new Date(Date.UTC(2000, 0, 1))
  d.setUTCFullYear(year, 0, 1)
  return d.getTime()
}

var MIN_MS = yearStartMs(AstroDate.MIN_YEAR)
var MAX_MS = yearStartMs(AstroDate.MAX_YEAR + 1) - 1

// One step of the lapse: the shown moment after `elapsedRealMs` of real
// time, forwards (direction 1, the default) or backwards (−1).
//   { shownMs, carryMs, stopped }
// carryMs: for a sampled preset, the simulated time not yet shown (less
// than a sample); pass it back in on the next call (0 to start). The
// moment stops at the range's ends (stopped: true).
function advance(shownMs, p, elapsedRealMs, carryMs, direction) {
  var dir = direction === -1 ? -1 : 1
  var move = dir * p.simulatedSecondsPerSecond * Math.max(0, Number(elapsedRealMs) || 0)
  var carry = (Number(carryMs) || 0) + move
  var step = move
  if (p.sampleMs > 0) {
    var whole = carry >= 0 ? Math.floor(carry / p.sampleMs) : Math.ceil(carry / p.sampleMs)
    step = whole * p.sampleMs
    carry -= step
  } else {
    carry = 0
  }
  var next = shownMs + step
  if (next > MAX_MS) return { shownMs: MAX_MS, carryMs: 0, stopped: true }
  if (next < MIN_MS) return { shownMs: MIN_MS, carryMs: 0, stopped: true }
  return { shownMs: Math.round(next), carryMs: carry, stopped: false }
}

// The label's parts: { amount, unit, inAmount, inUnit, sampled } with unit
// keys "second", "minute", "hour", "day", "month", "year".
function label(p) {
  return { amount: p.amount, unit: p.unit, inAmount: p.inAmount, inUnit: p.inUnit, sampled: p.sampleMs > 0 }
}

// The real ms between frames worth drawing at up to `fps` frames a second:
// 1000 / fps, or longer for a sampled preset whose picture changes only
// once per sample (a day every 164 ms for "seasonsInMinute").
function frameInterval(p, fps) {
  var base = 1000 / Math.max(1, Number(fps) || 60)
  if (p.sampleMs > 0) return Math.max(base, p.sampleMs / p.simulatedSecondsPerSecond)
  return base
}

if (typeof module !== "undefined") module.exports = {
  DAY_S: DAY_S, YEAR_S: YEAR_S, PRESETS: PRESETS, MIN_MS: MIN_MS, MAX_MS: MAX_MS, preset: preset,
  presetsFor: presetsFor, advance: advance, label: label, frameInterval: frameInterval
}
