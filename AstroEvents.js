.pragma library
.import "Astro.js" as Astro
.import "Moon.js" as Moon

// What the Astro tab's info line tells: the Moon (phase, age, distance,
// the next new and full moon), which planets show in the evening or the
// morning sky (their elongation from the Sun), the outer planets' next
// opposition and conjunction, and the next equinox or solstice. Positions
// come from Astro.js (heliocentric, ecliptic J2000, au) and Moon.js; the
// Moon's geocentric place is also given in the ecliptic J2000, for the
// Earth–Moon close-up. Pure functions, so the tests load them in Node.

var RAD = Math.PI / 180
var DAY_MS = 86400000

// The astronomical unit in km (IAU 2012 resolution B2: 149 597 870 700 m
// exactly; https://www.iau.org/static/resolutions/IAU2012_English.pdf,
// retrieved 2026-10-03).
var AU_KM = 149597870.7

// The mean synodic month in days at J2000 (29.5305888531 + 0.00000021621 T,
// https://en.wikipedia.org/wiki/Lunar_month#Synodic_month, after Chapront-
// Touzé & Chapront; retrieved 2026-10-03): how far apart the searches for
// the last new moon look.
var SYNODIC_MONTH_DAYS = 29.5305888531

function wrap360(deg) {
  return (deg % 360 + 360) % 360
}

function wrap180(deg) {
  return ((deg + 180) % 360 + 360) % 360 - 180
}

// ---- The Moon ----

// The Moon's distance from Earth's centre in km: Meeus, Astronomical
// Algorithms (2nd ed.), ch. 47: 385 000.56 km plus the distance terms Σr of
// table 47.A (every row with a distance coefficient, in 0.001 km), as
// reproduced in PyMeeus (https://github.com/architest/pymeeus,
// pymeeus/Moon.py PERIODIC_TERMS_LR_TABLE, retrieved 2026-10-03). Rows:
// [D, M, M′, F multipliers, Σr]; terms with M are scaled by E (E² for 2M)
// for the shrinking eccentricity of Earth's orbit. Meeus gives about 10 km;
// the arguments here lack their T², T³ terms, which adds under a km this
// century. The tests hold it to JPL Horizons (DE441).
var MOON_DISTANCE_TERMS = [
  [0, 0, 1, 0, -20905355], [2, 0, -1, 0, -3699111], [2, 0, 0, 0, -2955968], [0, 0, 2, 0, -569925],
  [0, 1, 0, 0, 48888], [0, 0, 0, 2, -3149], [2, 0, -2, 0, 246158], [2, -1, -1, 0, -152138],
  [2, 0, 1, 0, -170733], [2, -1, 0, 0, -204586], [0, 1, -1, 0, -129620], [1, 0, 0, 0, 108743],
  [0, 1, 1, 0, 104755], [2, 0, 0, -2, 10321], [0, 0, 1, -2, 79661], [4, 0, -1, 0, -34782],
  [0, 0, 3, 0, -23210], [4, 0, -2, 0, -21636], [2, 1, -1, 0, 24208], [2, 1, 0, 0, 30824],
  [1, 0, -1, 0, -8379], [1, 1, 0, 0, -16675], [2, -1, 1, 0, -12831], [2, 0, 2, 0, -10445],
  [4, 0, 0, 0, -11650], [2, 0, -3, 0, 14403], [0, 1, -2, 0, -7003], [2, -1, -2, 0, 10056],
  [1, 0, 1, 0, 6322], [2, -2, 0, 0, -9884], [0, 1, 2, 0, 5751], [2, -2, -1, 0, -4950],
  [2, 0, 1, -2, 4130], [4, -1, -1, 0, -3958], [3, 0, -1, 0, 3258], [2, 1, 1, 0, 2616],
  [4, -1, -2, 0, -1897], [0, 2, -1, 0, -2117], [2, 2, -1, 0, 2354], [4, 0, 1, 0, -1423],
  [0, 0, 4, 0, -1117], [4, -1, 0, 0, -1571], [1, 0, -2, 0, -1739], [0, 0, 2, -2, -4421],
  [0, 2, 1, 0, 1165], [2, 0, -1, -2, 8752]
]

function moonDistanceKm(utcMs) {
  var T = (utcMs - Date.UTC(2000, 0, 1, 12)) / DAY_MS / 36525
  var D = (297.8501921 + 445267.1114034 * T) * RAD
  var M = (357.5291092 + 35999.0502909 * T) * RAD
  var Mp = (134.9633964 + 477198.8675055 * T) * RAD
  var F = (93.2720950 + 483202.0175233 * T) * RAD
  var E = 1 - 0.002516 * T
  var sum = 0
  for (var i = 0; i < MOON_DISTANCE_TERMS.length; i++) {
    var t = MOON_DISTANCE_TERMS[i]
    var scale = t[1] === 0 ? 1 : (Math.abs(t[1]) === 1 ? E : E * E)
    sum += t[4] * scale * Math.cos(t[0] * D + t[1] * M + t[2] * Mp + t[3] * F)
  }
  return 385000.56 + sum / 1000
}

// The Moon seen from Earth's centre: { lon, lat } its ecliptic longitude
// and latitude referred to the J2000 equinox (degrees), distanceKm, and
// { x, y, z } the geocentric vector in au, ecliptic J2000. Moon.js gives
// the sub-lunar point (declination, and right ascension less its Greenwich
// sidereal time); this undoes those steps with Moon.js's own sidereal time
// and obliquity, so the place is exactly Moon.js's (good to a few tenths of
// a degree, parallax aside), then moves the longitude from the equinox of
// date back to J2000 by the precession (Astro.precession).
function moonGeocentric(utcMs) {
  var n = (utcMs - Date.UTC(2000, 0, 1, 12)) / DAY_MS
  var sub = Moon.moonPosition(utcMs)
  var alpha = (sub.lon + 280.46061837 + 360.98564736629 * n) * RAD
  var delta = sub.lat * RAD
  var eps = (23.439 - 0.0000004 * n) * RAD
  var lambda = Math.atan2(Math.sin(alpha) * Math.cos(eps) + Math.tan(delta) * Math.sin(eps), Math.cos(alpha)) / RAD
  var beta = Math.asin(Math.sin(delta) * Math.cos(eps) - Math.cos(delta) * Math.sin(eps) * Math.sin(alpha)) / RAD
  var lon = wrap360(lambda - Astro.precession(Astro.julianCenturies(utcMs)))
  var km = moonDistanceKm(utcMs)
  var r = km / AU_KM
  var l = lon * RAD, b = beta * RAD
  return { lon: lon, lat: beta, distanceKm: km,
    x: r * Math.cos(b) * Math.cos(l), y: r * Math.cos(b) * Math.sin(l), z: r * Math.sin(b) }
}

// The phase names, every eighth of the cycle centred on its point: new
// (0), waxing crescent, first quarter (0.25), waxing gibbous, full (0.5),
// waning gibbous, last quarter (0.75), waning crescent.
var PHASE_KEYS = ["new", "waxingCrescent", "firstQuarter", "waxingGibbous", "full", "waningGibbous", "lastQuarter", "waningCrescent"]

function phaseKey(phase) {
  return PHASE_KEYS[Math.floor(wrap360(phase * 360) / 45 + 0.5) % 8]
}

// The next moment after `fromMs` when the phase (Moon.moonPhaseFraction,
// 0–1) reaches `target`: in steps of six hours (the phase moves 0.0085
// per step), then by bisection to the second.
function nextPhase(fromMs, target) {
  var step = 6 * 3600000
  var ahead = function(ms) { return wrap180((Moon.moonPhaseFraction(ms) - target) * 360) }
  var a = fromMs
  var va = ahead(a)
  for (var i = 0; i < 130; i++) {
    var b = a + step
    var vb = ahead(b)
    if (va < 0 && vb >= 0) {
      for (var k = 0; k < 30; k++) {
        var mid = (a + b) / 2
        if (ahead(mid) < 0) a = mid
        else b = mid
      }
      return Math.round((a + b) / 2)
    }
    a = b
    va = vb
  }
  return 0
}

// The Moon at a moment:
//   { phase (0 new … 0.5 full … 1), key (PHASE_KEYS), illuminated (0–1),
//     waxing, ageDays (days since the last new moon, lastNew),
//     distanceKm, lastNew, nextNew, nextFull (UTC ms) }
function moonInfo(utcMs) {
  var lastNew = nextPhase(utcMs - SYNODIC_MONTH_DAYS * DAY_MS - DAY_MS, 0)
  for (var i = 0; i < 2; i++) {
    var later = nextPhase(lastNew + DAY_MS, 0)
    if (later > utcMs) break
    lastNew = later
  }
  var phase = Moon.moonPhaseFraction(utcMs)
  return {
    phase: phase,
    key: phaseKey(phase),
    illuminated: (1 - Math.cos(2 * Math.PI * phase)) / 2,
    waxing: phase < 0.5,
    ageDays: (utcMs - lastNew) / DAY_MS,
    distanceKm: moonDistanceKm(utcMs),
    lastNew: lastNew,
    nextNew: nextPhase(utcMs, 0),
    nextFull: nextPhase(utcMs, 0.5)
  }
}

// ---- The planets in Earth's sky ----

// The planets that can be told evening or morning.
var SKY_PLANETS = ["mercury", "venus", "mars", "jupiter", "saturn"]

// The least elongation from the Sun (degrees) at which a planet is called
// visible in the twilight. A rule of thumb for the info line, not a
// measured constant: the brighter the planet, the closer to the Sun it
// shows (Venus at magnitude −4 from about 10°, the others from about 15°;
// Mercury is hard to see below 15° even at its brightest). Real visibility
// also depends on the season, the latitude and the angle of the ecliptic
// to the horizon, which this ignores.
var VISIBLE_ELONGATION = { mercury: 15, venus: 10, mars: 15, jupiter: 15, saturn: 15 }

// A planet as seen from Earth (geocentric, from Astro.js's Earth–Moon
// barycentre; the Moon moves Earth by up to 4700 km, 0.002° at 1 au):
//   { angle: the elongation Sun–Earth–planet (0–180°),
//     side: "east" (evening sky: it sets after the Sun) | "west" (morning),
//     lonDiff: geocentric ecliptic longitude of the planet minus the Sun's
//       (−180…180, east positive),
//     distance: au from Earth }
function elongation(planet, utcMs) {
  var e = Astro.position("earth", utcMs)
  var p = Astro.position(planet, utcMs)
  if (!e || !p) return null
  var g = { x: p.x - e.x, y: p.y - e.y, z: p.z - e.z }
  var s = { x: -e.x, y: -e.y, z: -e.z }
  var gl = Math.sqrt(g.x * g.x + g.y * g.y + g.z * g.z)
  var sl = Math.sqrt(s.x * s.x + s.y * s.y + s.z * s.z)
  var c = (g.x * s.x + g.y * s.y + g.z * s.z) / (gl * sl)
  var lonDiff = wrap180(Math.atan2(g.y, g.x) / RAD - Math.atan2(s.y, s.x) / RAD)
  return { angle: Math.acos(Math.max(-1, Math.min(1, c))) / RAD, side: lonDiff >= 0 ? "east" : "west",
    lonDiff: lonDiff, distance: gl }
}

// Mercury to Saturn: "evening" (east of the Sun, at least its
// VISIBLE_ELONGATION), "morning" (west of it) or "none".
function visibility(utcMs) {
  var out = {}
  for (var i = 0; i < SKY_PLANETS.length; i++) {
    var key = SKY_PLANETS[i]
    var el = elongation(key, utcMs)
    out[key] = el.angle < VISIBLE_ELONGATION[key] ? "none" : (el.side === "east" ? "evening" : "morning")
  }
  return out
}

// The planets beyond Earth's orbit, which have oppositions.
var OUTER_PLANETS = ["mars", "jupiter", "saturn", "uranus", "neptune"]

// The first moment after `fromMs`, within `days`, when f (degrees, −180…180)
// passes from positive to negative, refined by bisection to the second; 0
// when it does not. A daily scan: no outer planet's f turns faster.
function nextDownCrossing(f, fromMs, days) {
  var a = fromMs
  var va = f(a)
  for (var i = 0; i < days; i++) {
    var b = a + DAY_MS
    var vb = f(b)
    // A real crossing, not the jump from −180 to +180.
    if (va > 0 && vb <= 0 && va - vb < 90) {
      for (var k = 0; k < 30; k++) {
        var mid = (a + b) / 2
        if (f(mid) > 0) a = mid
        else b = mid
      }
      return Math.round((a + b) / 2)
    }
    a = b
    va = vb
  }
  return 0
}

// The next opposition (Earth between the Sun and the planet: geocentric
// longitudes 180° apart) of an outer planet within two years after
// `fromMs`, in UTC ms, 0 when none (Jupiter to Neptune have one every
// 13 months or less; Mars every 26 months). Geometric positions: light
// time and aberration move the published moments by minutes to an hour.
function nextOpposition(planet, fromMs) {
  if (OUTER_PLANETS.indexOf(planet) < 0) return 0
  return nextDownCrossing(function(ms) { return wrap180(elongation(planet, ms).lonDiff - 180) }, fromMs, 731)
}

// The next conjunction with the Sun (the planet behind the Sun:
// geocentric longitudes equal) of an outer planet within two years.
function nextConjunction(planet, fromMs) {
  if (OUTER_PLANETS.indexOf(planet) < 0) return 0
  return nextDownCrossing(function(ms) { return elongation(planet, ms).lonDiff }, fromMs, 731)
}

// ---- The year ----

// The next equinox or solstice after `utcMs`: { key, utcMs } (Astro.seasonMarks).
function nextSeasonEvent(utcMs) {
  var year = new Date(utcMs).getUTCFullYear()
  for (var y = year; y <= year + 1; y++) {
    var seasons = Astro.seasonMarks(y).seasons
    for (var i = 0; i < seasons.length; i++)
      if (seasons[i].utcMs > utcMs) return { key: seasons[i].key, utcMs: seasons[i].utcMs }
  }
  return null
}

if (typeof module !== "undefined") module.exports = {
  AU_KM: AU_KM, SYNODIC_MONTH_DAYS: SYNODIC_MONTH_DAYS, PHASE_KEYS: PHASE_KEYS, SKY_PLANETS: SKY_PLANETS,
  VISIBLE_ELONGATION: VISIBLE_ELONGATION, OUTER_PLANETS: OUTER_PLANETS,
  MOON_DISTANCE_TERMS: MOON_DISTANCE_TERMS, moonDistanceKm: moonDistanceKm, moonGeocentric: moonGeocentric, phaseKey: phaseKey, nextPhase: nextPhase,
  moonInfo: moonInfo, elongation: elongation, visibility: visibility, nextOpposition: nextOpposition,
  nextConjunction: nextConjunction, nextSeasonEvent: nextSeasonEvent
}
