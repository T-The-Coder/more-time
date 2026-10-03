.pragma library

// The solar system for the Astro tab: where the planets stand, from the
// Keplerian elements of JPL's "Approximate Positions of the Planets"
// (E. M. Standish, table 1, valid 1800–2050, good to about an arcminute for
// the inner planets and a few for the outer ones). Positions are
// heliocentric, in the ecliptic and equinox of J2000, in astronomical
// units: x towards the vernal point, z to the ecliptic's north pole.
// "earth" is the Earth–Moon barycentre, as in the table. Pure functions, so
// the tests load them in Node.

var RAD = Math.PI / 180

// The planets in order from the Sun.
var PLANETS = ["mercury", "venus", "earth", "mars", "jupiter", "saturn", "uranus", "neptune"]

// Table 1: [a (au), e, I (°), L (°), ϖ long. of perihelion (°), Ω long. of
// the ascending node (°)] and their rates per Julian century.
var ELEMENTS = {
  mercury: [[0.38709927, 0.20563593, 7.00497902, 252.25032350, 77.45779628, 48.33076593],
    [0.00000037, 0.00001906, -0.00594749, 149472.67411175, 0.16047689, -0.12534081]],
  venus: [[0.72333566, 0.00677672, 3.39467605, 181.97909950, 131.60246718, 76.67984255],
    [0.00000390, -0.00004107, -0.00078890, 58517.81538729, 0.00268329, -0.27769418]],
  earth: [[1.00000261, 0.01671123, -0.00001531, 100.46457166, 102.93768193, 0.0],
    [0.00000562, -0.00004392, -0.01294668, 35999.37244981, 0.32327364, 0.0]],
  mars: [[1.52371034, 0.09339410, 1.84969142, -4.55343205, -23.94362959, 49.55953891],
    [0.00001847, 0.00007882, -0.00813131, 19140.30268499, 0.44441088, -0.29257343]],
  jupiter: [[5.20288700, 0.04838624, 1.30439695, 34.39644051, 14.72847983, 100.47390909],
    [-0.00011607, -0.00013253, -0.00183714, 3034.74612775, 0.21252668, 0.20469106]],
  saturn: [[9.53667594, 0.05386179, 2.48599187, 49.95424423, 92.59887831, 113.66242448],
    [-0.00125060, -0.00050991, 0.00193609, 1222.49362201, -0.41897216, -0.28867794]],
  uranus: [[19.18916464, 0.04725744, 0.77263783, 313.23810451, 170.95427630, 74.01692503],
    [-0.00196176, -0.00004397, -0.00242939, 428.48202785, 0.40805281, 0.04240589]],
  neptune: [[30.06992276, 0.00859048, 1.77004347, -55.12002969, 44.96476227, 131.78422574],
    [0.00026291, 0.00005105, 0.00035372, 218.45945325, -0.32241464, -0.00508664]]
}

// Mean radii in km (IAU WGCCRE 2015), for the drawing's sizes.
var RADIUS_KM = { sun: 695700, mercury: 2439.4, venus: 6051.8, earth: 6371.0, mars: 3389.5,
  jupiter: 69911, saturn: 58232, uranus: 25362, neptune: 24622 }

// Light time for one astronomical unit, in minutes (499.004784 s).
var LIGHT_MINUTES_PER_AU = 499.004784 / 60

// Julian centuries since J2000.0 (2000-01-01 12:00 TT). UTC is taken for
// TT: the minute or so between them moves no planet visibly.
function julianCenturies(utcMs) {
  return (utcMs / 86400000 + 2440587.5 - 2451545.0) / 36525
}

function wrap180(deg) {
  return ((deg + 180) % 360 + 360) % 360 - 180
}

function wrap360(deg) {
  return (deg % 360 + 360) % 360
}

// The elements at T centuries: { a, e, I, L, peri, node } (degrees).
function elementsAt(planet, T) {
  var el = ELEMENTS[planet]
  if (!el) return null
  var v = []
  for (var i = 0; i < 6; i++) v.push(el[0][i] + el[1][i] * T)
  return { a: v[0], e: v[1], I: v[2], L: v[3], peri: v[4], node: v[5] }
}

// Kepler's equation M = E − e·sin E for the eccentric anomaly E (radians),
// by Newton's method to 1e-8.
function solveKepler(M, e) {
  var E = M + e * Math.sin(M)
  for (var i = 0; i < 50; i++) {
    var delta = (E - e * Math.sin(E) - M) / (1 - e * Math.cos(E))
    E -= delta
    if (Math.abs(delta) < 1e-8) break
  }
  return E
}

// From the orbit's plane to the ecliptic: the position at eccentric anomaly
// E (radians) on the orbit of elements el.
function orbitPoint(el, E) {
  var xp = el.a * (Math.cos(E) - el.e)
  var yp = el.a * Math.sqrt(1 - el.e * el.e) * Math.sin(E)
  var w = (el.peri - el.node) * RAD
  var O = el.node * RAD
  var I = el.I * RAD
  var cw = Math.cos(w), sw = Math.sin(w), cO = Math.cos(O), sO = Math.sin(O), cI = Math.cos(I), sI = Math.sin(I)
  return {
    x: (cw * cO - sw * sO * cI) * xp + (-sw * cO - cw * sO * cI) * yp,
    y: (cw * sO + sw * cO * cI) * xp + (-sw * sO + cw * cO * cI) * yp,
    z: (sw * sI) * xp + (cw * sI) * yp
  }
}

// Where a planet stands at a moment: { x, y, z } in au and its ecliptic
// { lon, lat } in degrees (lon 0–360) and r in au.
function position(planet, utcMs) {
  var el = elementsAt(planet, julianCenturies(utcMs))
  if (!el) return null
  var M = wrap180(el.L - el.peri) * RAD
  var p = orbitPoint(el, solveKepler(M, el.e))
  var r = Math.sqrt(p.x * p.x + p.y * p.y + p.z * p.z)
  return { x: p.x, y: p.y, z: p.z, r: r,
    lon: wrap360(Math.atan2(p.y, p.x) / RAD), lat: Math.asin(p.z / r) / RAD }
}

// Every planet at a moment, by name.
function positions(utcMs) {
  var out = {}
  for (var i = 0; i < PLANETS.length; i++) out[PLANETS[i]] = position(PLANETS[i], utcMs)
  return out
}

// The orbit at a moment as `count` points ({ x, y, z } in au), evenly spaced
// in eccentric anomaly (closer near perihelion, where the orbit bends most).
function orbit(planet, utcMs, count) {
  var el = elementsAt(planet, julianCenturies(utcMs))
  if (!el) return []
  var n = Math.max(8, count || 96)
  var points = []
  for (var i = 0; i < n; i++) points.push(orbitPoint(el, 2 * Math.PI * i / n))
  return points
}

// The sidereal period in days, from the rate of the mean longitude.
function periodDays(planet) {
  var el = ELEMENTS[planet]
  return el ? 36000 / el[1][3] * 36525 / 100 : 0
}

// The distance between two positions in au.
function distance(p, q) {
  return Math.sqrt((p.x - q.x) * (p.x - q.x) + (p.y - q.y) * (p.y - q.y) + (p.z - q.z) * (p.z - q.z))
}

// ---- The year on Earth's orbit ----

// General precession in longitude (IAU 2006, Capitaine et al. 2003):
// how far the equinox of date has moved along the ecliptic from J2000's,
// in degrees.
function precession(T) {
  return (5028.796195 * T + 1.1054348 * T * T) / 3600
}

// Earth's heliocentric longitude (J2000) when the Sun's apparent geocentric
// longitude of date is `sunLon`: opposite the Sun, moved back by the
// precession, plus the aberration (20.496″) that makes the Sun appear
// behind its true place. Nutation (up to ±17″, a few minutes) is left out.
function earthLonFor(sunLon, T) {
  return wrap360(sunLon + 180 + 20.496 / 3600 - precession(T))
}

// The moment Earth reaches heliocentric longitude `lon` near `guessMs`
// (within about a month), by bisection on its position.
function earthReaches(lon, guessMs) {
  var lo = guessMs - 20 * 86400000
  var hi = guessMs + 20 * 86400000
  var ahead = function(ms) { return wrap180(position("earth", ms).lon - lon) }
  for (var i = 0; i < 40; i++) {
    var mid = (lo + hi) / 2
    if (ahead(mid) < 0) lo = mid
    else hi = mid
  }
  return Math.round((lo + hi) / 2)
}

// The marks of a year for the month ring:
//   seasons: [{ key, lon, utcMs }] the March equinox, the June solstice,
//     the September equinox and the December solstice (Sun at 0°, 90°,
//     180°, 270° of apparent longitude), with Earth's heliocentric
//     longitude there and the moment;
//   months: [{ month (0–11), lon, utcMs }] Earth's longitude at 00:00 UTC
//     on each month's first day.
function seasonMarks(year) {
  var keys = ["marchEquinox", "juneSolstice", "septemberEquinox", "decemberSolstice"]
  var guesses = [Date.UTC(year, 2, 20, 12), Date.UTC(year, 5, 21, 6), Date.UTC(year, 8, 22, 18), Date.UTC(year, 11, 21, 15)]
  var seasons = []
  for (var k = 0; k < 4; k++) {
    var T = julianCenturies(guesses[k])
    var lon = earthLonFor(90 * k, T)
    seasons.push({ key: keys[k], lon: lon, utcMs: earthReaches(lon, guesses[k]) })
  }
  var months = []
  for (var m = 0; m < 12; m++) {
    var at = Date.UTC(year, m, 1)
    months.push({ month: m, lon: position("earth", at).lon, utcMs: at })
  }
  return { seasons: seasons, months: months }
}

if (typeof module !== "undefined") module.exports = {
  PLANETS: PLANETS, ELEMENTS: ELEMENTS, RADIUS_KM: RADIUS_KM, LIGHT_MINUTES_PER_AU: LIGHT_MINUTES_PER_AU,
  julianCenturies: julianCenturies, elementsAt: elementsAt, solveKepler: solveKepler, position: position,
  positions: positions, orbit: orbit, periodDays: periodDays, distance: distance, precession: precession,
  earthLonFor: earthLonFor, earthReaches: earthReaches, seasonMarks: seasonMarks
}
