.pragma library

// The Astro tab's scrubber: whole days over a year either side of now
// (the time lapse itself is AstroLapse.js). The steps keep now's time of
// day, so stepping by days leaves the Sun over the same meridian (the Earth
// globe turns once a sidereal day, 4 minutes short: about a degree a day,
// which is the year's motion and right). Pure functions, tested in Node.

var DAY_MS = 86400000

// Days either side of now: a full year and a day, so the same date a year
// on and a year back are both in reach.
var RANGE_DAYS = 366

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

if (typeof module !== "undefined") module.exports = {
  DAY_MS: DAY_MS, RANGE_DAYS: RANGE_DAYS, NOW_INDEX: NOW_INDEX, LAST_INDEX: LAST_INDEX, steps: steps, nearestIndex: nearestIndex
}
