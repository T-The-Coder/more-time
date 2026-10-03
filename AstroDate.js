.pragma library

// The Astro tab's "Go to date": reading a typed date and the time-lapse
// travel to it. Pure functions, tested in Node (tests/astro-date.test.mjs).
//
// Accepted (times are this computer's local time; no time means noon for a
// bare year, midnight otherwise):
//   2026-10-03, 2026-10-03 21:17, 03.10.2026, 03.10.2026 21:17,
//   10/03/2026 and 10/03/2026 21:17 only where the interface language
//   writes month/day/year, and a bare year (1969 → 1 January, noon).
// Years from 3000 BC to 3000 AD (astronomical numbering: 0 is 1 BC, −2999
// is 3000 BC), the range of JPL's long-range elements (Astro.js).

var MIN_YEAR = -2999
var MAX_YEAR = 3000
var TRAVEL_MS = 2500

// "dmy", "mdy" or "ymd" from a Qt date format ("d.M.yyyy", "M/d/yy", …).
function dateOrder(format) {
  var f = String(format || "")
  var d = f.search(/d/), m = f.search(/M/), y = f.search(/y/)
  if (y >= 0 && (d < 0 || y < d) && (m < 0 || y < m)) return "ymd"
  if (m >= 0 && d >= 0 && m < d) return "mdy"
  return "dmy"
}

// Local time of this computer (QML and Node alike), for any year.
function localMs(year, month, day, hour, minute) {
  var d = new Date(2000, 0, 1, 12, 0, 0, 0)
  d.setFullYear(year, month - 1, day)
  d.setHours(hour, minute, 0, 0)
  return d.getTime()
}

function daysInMonth(year, month) {
  var d = new Date(Date.UTC(2000, 0, 1))
  d.setUTCFullYear(year, month, 0)
  return d.getUTCDate()
}

// The text read: { ok: true, ms, year, month, day, hour, minute, hasTime }
// or { ok: false, reason: "empty" | "invalid" | "range" }. order: "dmy",
// "mdy" or "ymd" (dateOrder); toMs(year, month, day, hour, minute) turns
// the parts into a moment (localMs unless given).
function parseDate(text, order, toMs) {
  var t = String(text || "").trim()
  if (t === "") return { ok: false, reason: "empty" }
  var y, mo, d, h = 0, mi = 0, hasTime = false
  var m
  if ((m = t.match(/^(-?\d{1,4})$/))) {
    y = Number(m[1]); mo = 1; d = 1; h = 12
  } else if ((m = t.match(/^(-?\d{1,4})-(\d{1,2})-(\d{1,2})(?:[ T]+(\d{1,2}):(\d{2}))?$/))) {
    y = Number(m[1]); mo = Number(m[2]); d = Number(m[3])
    if (m[4] !== undefined) { h = Number(m[4]); mi = Number(m[5]); hasTime = true }
  } else if ((m = t.match(/^(\d{1,2})\.(\d{1,2})\.(-?\d{1,4})(?:\s+(\d{1,2}):(\d{2}))?$/))) {
    d = Number(m[1]); mo = Number(m[2]); y = Number(m[3])
    if (m[4] !== undefined) { h = Number(m[4]); mi = Number(m[5]); hasTime = true }
  } else if (order === "mdy" && (m = t.match(/^(\d{1,2})\/(\d{1,2})\/(-?\d{1,4})(?:\s+(\d{1,2}):(\d{2}))?$/))) {
    mo = Number(m[1]); d = Number(m[2]); y = Number(m[3])
    if (m[4] !== undefined) { h = Number(m[4]); mi = Number(m[5]); hasTime = true }
  } else {
    return { ok: false, reason: "invalid" }
  }
  if (mo < 1 || mo > 12 || d < 1 || d > daysInMonth(y, mo) || h > 23 || mi > 59) return { ok: false, reason: "invalid" }
  if (y < MIN_YEAR || y > MAX_YEAR) return { ok: false, reason: "range" }
  var ms = (toMs || localMs)(y, mo, d, h, mi)
  return { ok: true, ms: ms, year: y, month: mo, day: d, hour: h, minute: mi, hasTime: hasTime }
}

// Ease in and out (cubic): 0 → 0, 1 → 1, never going back.
function ease(t) {
  var x = Math.max(0, Math.min(1, Number(t) || 0))
  return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2
}

// The moment shown at fraction t of a travel from one moment to another;
// exactly the target at the end.
function travelAt(fromMs, toMs, t) {
  if (t >= 1) return toMs
  return fromMs + (toMs - fromMs) * ease(t)
}

if (typeof module !== "undefined") module.exports = {
  MIN_YEAR: MIN_YEAR, MAX_YEAR: MAX_YEAR, TRAVEL_MS: TRAVEL_MS, dateOrder: dateOrder, localMs: localMs,
  daysInMonth: daysInMonth, parseDate: parseDate, ease: ease, travelAt: travelAt
}
