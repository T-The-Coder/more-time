.pragma library

// The Astro tab's time line: a scrubber of whole days over a year either
// side of now, played at one day, one week or one month per second. The
// steps keep now's time of day, so stepping by days leaves the Sun over the
// same meridian (the Earth globe turns once a sidereal day, 4 minutes
// short: about a degree a day, which is the year's motion and right).
// Labels are built by hand: QML's engine has no Intl. Pure functions,
// tested in Node.

var DAY_MS = 86400000

// Days either side of now: a full year and a day, so the same date a year
// on and a year back are both in reach.
var RANGE_DAYS = 366

// The playback speeds: days per second of play, and how the timer meets
// them: a tick every `delay` ms (no faster than about 30 a second, 33 ms),
// moving `step` days. key names the i18n string.
var SPEEDS = [
  { key: "day", daysPerSecond: 1 },
  { key: "week", daysPerSecond: 7 },
  { key: "month", daysPerSecond: 30 }
]
var MIN_DELAY_MS = 33

// The timer for a speed index: { step (days per tick, whole), delay (ms) }.
// One day per tick when that is slow enough, else whole days per 33 ms or
// so, the delay stretched to keep the rate (to within its whole
// milliseconds, 1 % at 30 days a second): 1 → 1 day / 1000 ms,
// 7 → 1 day / 143 ms, 30 → 1 day / 33 ms.
function timing(speedIndex) {
  var s = SPEEDS[Math.max(0, Math.min(SPEEDS.length - 1, Math.floor(Number(speedIndex) || 0)))]
  var step = Math.max(1, Math.ceil(s.daysPerSecond * MIN_DELAY_MS / 1000))
  return { step: step, delay: Math.round(1000 * step / s.daysPerSecond) }
}

// The scrubber's moments: now + k days for k = −RANGE_DAYS … RANGE_DAYS
// (2 · 366 + 1 entries), now at index RANGE_DAYS.
function steps(nowMs) {
  var out = []
  for (var k = -RANGE_DAYS; k <= RANGE_DAYS; k++) out.push(nowMs + k * DAY_MS)
  return out
}

var NOW_INDEX = RANGE_DAYS
var LAST_INDEX = 2 * RANGE_DAYS

// The index nearest a moment on the scrubber built at nowMs, clamped to it.
function nearestIndex(nowMs, ms) {
  var k = Math.round((ms - nowMs) / DAY_MS) + RANGE_DAYS
  return Math.max(0, Math.min(LAST_INDEX, k))
}

// One tick of playback: { index, stopped }. direction +1 forwards, −1
// back; at either end it stops there.
function advance(index, speedIndex, direction) {
  var t = timing(speedIndex)
  var next = index + (direction < 0 ? -t.step : t.step)
  if (next <= 0) return { index: 0, stopped: true }
  if (next >= LAST_INDEX) return { index: LAST_INDEX, stopped: true }
  return { index: next, stopped: false }
}

// Whether an index is now: the scrubber's own now, so live following and
// the "now" key (n) both land here.
function isNow(index) {
  return index === NOW_INDEX
}

// The days between a moment and now, rounded to whole days (negative in
// the past): for "+12 days" and "−3 days" next to the date.
function daysFromNow(nowMs, ms) {
  return Math.round((ms - nowMs) / DAY_MS)
}

// A moment's local calendar parts for the label, by a UTC offset in
// seconds (the zone's, from zdump as elsewhere in the plugin):
// { year, month (0–11), day, weekday (0 Sunday … 6), hour, minute }.
function label(ms, offsetSeconds) {
  var d = new Date(ms + (Number(offsetSeconds) || 0) * 1000)
  return { year: d.getUTCFullYear(), month: d.getUTCMonth(), day: d.getUTCDate(), weekday: d.getUTCDay(),
    hour: d.getUTCHours(), minute: d.getUTCMinutes() }
}

if (typeof module !== "undefined") module.exports = {
  DAY_MS: DAY_MS, RANGE_DAYS: RANGE_DAYS, SPEEDS: SPEEDS, MIN_DELAY_MS: MIN_DELAY_MS, NOW_INDEX: NOW_INDEX, LAST_INDEX: LAST_INDEX,
  timing: timing, steps: steps, nearestIndex: nearestIndex, advance: advance, isNow: isNow, daysFromNow: daysFromNow, label: label
}
