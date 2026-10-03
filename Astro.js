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

// Table 2a, for 3000 BC – 3000 AD, the same columns; Jupiter to Neptune
// add Table 2b's terms to the mean anomaly: b·T² + c·cos(f·T) + s·sin(f·T)
// (f in degrees per century). Both tables from
// https://ssd.jpl.nasa.gov/planets/approx_pos.html (Standish & Williams
// 1992), checked against the page on 2026-10-03. Nominal errors there:
// Table 1 under 1′ for the inner planets, up to 10′ for Saturn; Table 2
// up to 40″ inner, 10′ for Jupiter, 17′ for Saturn, 33′ for Uranus.
var ELEMENTS_LONG = {
  mercury: [[0.38709843, 0.20563661, 7.00559432, 252.25166724, 77.45771895, 48.33961819],
    [0.00000000, 0.00002123, -0.00590158, 149472.67486623, 0.15940013, -0.12214182]],
  venus: [[0.72332102, 0.00676399, 3.39777545, 181.97970850, 131.76755713, 76.67261496],
    [-0.00000026, -0.00005107, 0.00043494, 58517.81560260, 0.05679648, -0.27274174]],
  earth: [[1.00000018, 0.01673163, -0.00054346, 100.46691572, 102.93005885, -5.11260389],
    [-0.00000003, -0.00003661, -0.01337178, 35999.37306329, 0.31795260, -0.24123856]],
  mars: [[1.52371243, 0.09336511, 1.85181869, -4.56813164, -23.91744784, 49.71320984],
    [0.00000097, 0.00009149, -0.00724757, 19140.29934243, 0.45223625, -0.26852431]],
  jupiter: [[5.20248019, 0.04853590, 1.29861416, 34.33479152, 14.27495244, 100.29282654],
    [-0.00002864, 0.00018026, -0.00322699, 3034.90371757, 0.18199196, 0.13024619]],
  saturn: [[9.54149883, 0.05550825, 2.49424102, 50.07571329, 92.86136063, 113.63998702],
    [-0.00003065, -0.00032044, 0.00451969, 1222.11494724, 0.54179478, -0.25015002]],
  uranus: [[19.18797948, 0.04685740, 0.77298127, 314.20276625, 172.43404441, 73.96250215],
    [-0.00020455, -0.00001550, -0.00180155, 428.49512595, 0.09266985, 0.05739699]],
  neptune: [[30.06952752, 0.00895439, 1.77005520, 304.22289287, 46.68158724, 131.78635853],
    [0.00006447, 0.00000818, 0.00022400, 218.46515314, 0.01009938, -0.00606302]]
}
var EXTRA_TERMS = {
  jupiter: { b: -0.00012452, c: 0.06064060, s: -0.35635438, f: 38.35125000 },
  saturn: { b: 0.00025899, c: -0.13434469, s: 0.87320147, f: 38.35125000 },
  uranus: { b: 0.00058331, c: -0.97731848, s: 0.17689245, f: 7.67025000 },
  neptune: { b: -0.00041348, c: 0.68346318, s: -0.10162547, f: 7.67025000 }
}
// Table 1's span in centuries from J2000 (1800-01-01 … 2050-01-01); Table
// 2's (3000 BC … 3000 AD).
var SHORT_RANGE = [-2.0, 0.5]
var LONG_RANGE = [-50.0, 10.0]

// Whether a moment lies outside Table 1's years, where the positions come
// from the long-range table and are approximate.
function isApproximate(utcMs) {
  var T = julianCenturies(utcMs)
  return T < SHORT_RANGE[0] || T > SHORT_RANGE[1]
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

// The elements at T centuries: { a, e, I, L, peri, node } (degrees), and
// `extra`, the long-range table's addition to the mean anomaly (degrees).
// Table 1 inside 1800–2050, Table 2 outside it; table "long" or "short"
// forces one.
function elementsAt(planet, T, table) {
  var useLong = table === "long" || (table !== "short" && (T < SHORT_RANGE[0] || T > SHORT_RANGE[1]))
  var el = useLong ? ELEMENTS_LONG[planet] : ELEMENTS[planet]
  if (!el) return null
  var v = []
  for (var i = 0; i < 6; i++) v.push(el[0][i] + el[1][i] * T)
  var extra = 0
  var x = useLong ? EXTRA_TERMS[planet] : null
  if (x) extra = x.b * T * T + x.c * Math.cos(x.f * T * RAD) + x.s * Math.sin(x.f * T * RAD)
  return { a: v[0], e: v[1], I: v[2], L: v[3], peri: v[4], node: v[5], extra: extra }
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
function position(planet, utcMs, table) {
  var el = elementsAt(planet, julianCenturies(utcMs), table)
  if (!el) return null
  var M = wrap180(el.L - el.peri + el.extra) * RAD
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
// Date.UTC for any year (it reads 0–99 as 1900–1999).
function utc(year, month, day, hour) {
  var d = new Date(0)
  d.setUTCFullYear(year, month, day)
  d.setUTCHours(hour || 0, 0, 0, 0)
  return d.getTime()
}

function seasonMarks(year) {
  var keys = ["marchEquinox", "juneSolstice", "septemberEquinox", "decemberSolstice"]
  var guesses = [utc(year, 2, 20, 12), utc(year, 5, 21, 6), utc(year, 8, 22, 18), utc(year, 11, 21, 15)]
  var seasons = []
  for (var k = 0; k < 4; k++) {
    var T = julianCenturies(guesses[k])
    var lon = earthLonFor(90 * k, T)
    seasons.push({ key: keys[k], lon: lon, utcMs: earthReaches(lon, guesses[k]) })
  }
  var months = []
  for (var m = 0; m < 12; m++) {
    var at = utc(year, m, 1)
    months.push({ month: m, lon: position("earth", at).lon, utcMs: at })
  }
  return { seasons: seasons, months: months }
}

if (typeof module !== "undefined") module.exports = {
  PLANETS: PLANETS, ELEMENTS: ELEMENTS, RADIUS_KM: RADIUS_KM, LIGHT_MINUTES_PER_AU: LIGHT_MINUTES_PER_AU,
  julianCenturies: julianCenturies, elementsAt: elementsAt, solveKepler: solveKepler, position: position,
  positions: positions, orbit: orbit, periodDays: periodDays, distance: distance, precession: precession,
  earthLonFor: earthLonFor, earthReaches: earthReaches, seasonMarks: seasonMarks,
  ELEMENTS_LONG: ELEMENTS_LONG, EXTRA_TERMS: EXTRA_TERMS, SHORT_RANGE: SHORT_RANGE, LONG_RANGE: LONG_RANGE,
  isApproximate: isApproximate, utc: utc
}
