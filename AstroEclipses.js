.pragma library
.import "Moon.js" as Moon
.import "Sky.js" as Sky
.import "AstroEvents.js" as AstroEvents

// Solar and lunar eclipses from 2000 BC to 3000 AD for the Astro tab: the
// next, the previous, those in a span, and whether one shows from a place.
//
// The tables (data/astro-eclipses-<kind>-<first year>.json, one per kind
// and millennium, from tools/build-astro-eclipses.py) are NASA's Five
// Millennium Catalogs of Solar and Lunar Eclipses (Espenak & Meeus,
// https://eclipse.gsfc.nasa.gov/SEcat5/ and /LEcat5/, retrieved
// 2026-10-05): 11 898 solar and 12 064 lunar eclipses from −1999 to +3000.
// Acknowledgment, as the pages ask: "Eclipse Predictions by Fred Espenak
// (NASA's GSFC)".
//
// Loading: TimeAstro.qml asks chunksFor(fromMs, toMs) which files a span
// needs, reads each with a FileView and hands the parsed object to
// addChunk() (once per file; again is harmless). Queries answer only from
// what is loaded: next() and previous() return null rather than skip over a
// millennium that is not loaded yet, and missingChunks() tells which.
//
// An eclipse: { kind: "solar" | "lunar", type, utcMs, tdMs, deltaT,
// approximate, magnitude, gamma, lat, lon, umbralMagnitude and
// penumbralMagnitude (lunar only) }
//  - type: solar "total", "annular", "hybrid", "partial"; lunar "total",
//    "partial", "penumbral";
//  - utcMs: greatest eclipse in UT (the catalogue's TD − its ΔT), as a
//    JavaScript (proleptic Gregorian) instant, as AstroDate.js uses; the
//    catalogue's Julian-calendar dates before 1582-10-15 are converted
//    through the Julian Day. tdMs = utcMs + deltaT (s) × 1000.
//  - approximate: before 1600 or after 2100, where ΔT is not measured and
//    the UT instant (and with it the longitude of the place) carries its
//    uncertainty. NASA's standard error of ΔT
//    (https://eclipse.gsfc.nasa.gov/SEcat5/uncertainty.html, retrieved
//    2026-10-05): 54 s at 1000 AD, 139 s at 500 AD, 265 s at 0, 622 s at
//    1000 BC, 3732 s (1 h, 15.6° of longitude) at 2000 BC, 1885 s at
//    3000 AD. The TD instant is the catalogue's own;
//  - magnitude: solar, the fraction of the Sun's diameter covered at
//    greatest eclipse (above 1 for total); lunar, the umbral magnitude for
//    total and partial ones and the penumbral magnitude for penumbral ones;
//  - gamma: the shadow axis' least distance from Earth's centre in Earth
//    radii (signed, north positive);
//  - lat, lon: solar, the point of greatest eclipse; lunar, where the Moon
//    stands in the zenith at greatest eclipse (whole degrees, east +).

var RAD = Math.PI / 180
var HOUR_MS = 3600000
var DAY_MS = 86400000

var SOLAR_TYPES = ["partial", "annular", "total", "hybrid"]
var LUNAR_TYPES = ["penumbral", "partial", "total"]
var KINDS = ["solar", "lunar"]

// The millennium files: key (first year, as in the file name) and years.
var CHUNKS = [
  { key: "-1999", first: -1999, last: -1000 }, { key: "-0999", first: -999, last: 0 },
  { key: "0001", first: 1, last: 1000 }, { key: "1001", first: 1001, last: 2000 },
  { key: "2001", first: 2001, last: 3000 }
]

function yearStartMs(year) {
  var d = new Date(Date.UTC(2000, 0, 1))
  d.setUTCFullYear(year, 0, 1)
  return d.getTime()
}

// A chunk's span in ms, widened by 60 days: the Julian calendar's dates
// lie up to 16 days from the Gregorian ones in these years.
function chunkSpan(c) {
  return [yearStartMs(c.first) - 60 * DAY_MS, yearStartMs(c.last + 1) + 60 * DAY_MS]
}

function fileName(kind, key) {
  return "astro-eclipses-" + kind + "-" + key + ".json"
}

var loaded = {}
var solar = []
var lunar = []
var all = []

// The files (relative to data/) a span needs: [{ kind, key, file }] for
// both kinds (or only `kind` when given), oldest first.
function chunksFor(fromMs, toMs, kind) {
  var out = []
  for (var k = 0; k < KINDS.length; k++) {
    if (kind && kind !== KINDS[k]) continue
    for (var i = 0; i < CHUNKS.length; i++) {
      var span = chunkSpan(CHUNKS[i])
      if (span[1] >= fromMs && span[0] <= toMs) out.push({ kind: KINDS[k], key: CHUNKS[i].key, file: fileName(KINDS[k], CHUNKS[i].key) })
    }
  }
  return out
}

// Those of chunksFor() not yet passed to addChunk().
function missingChunks(fromMs, toMs, kind) {
  var need = chunksFor(fromMs, toMs, kind)
  var out = []
  for (var i = 0; i < need.length; i++) if (!loaded[need[i].kind + need[i].key]) out.push(need[i])
  return out
}

function byTime(a, b) {
  return a.utcMs - b.utcMs
}

// Adds one parsed file; returns how many eclipses are loaded in all.
function addChunk(data) {
  if (!data || !data.data || !data.kind) return all.length
  var id = data.kind + data.key
  if (loaded[id]) return all.length
  loaded[id] = true
  var d = data.data, n = data.stride, t = data.t0, list = data.kind === "solar" ? solar : lunar
  for (var i = 0; i + n <= d.length; i += n) {
    t += d[i]
    var utcMs = t * 1000
    var e
    if (data.kind === "solar") {
      e = { kind: "solar", type: SOLAR_TYPES[d[i + 1]], utcMs: utcMs, magnitude: d[i + 2] / 10000,
        gamma: d[i + 3] / 10000, lat: d[i + 4], lon: d[i + 5], deltaT: d[i + 6] }
    } else {
      var type = LUNAR_TYPES[d[i + 1]]
      e = { kind: "lunar", type: type, utcMs: utcMs,
        magnitude: type === "penumbral" ? d[i + 3] / 10000 : d[i + 2] / 10000,
        umbralMagnitude: d[i + 2] / 10000, penumbralMagnitude: d[i + 3] / 10000, gamma: d[i + 4] / 10000,
        lat: d[i + 5], lon: d[i + 6], deltaT: d[i + 7] }
    }
    e.tdMs = utcMs + e.deltaT * 1000
    var year = new Date(utcMs).getUTCFullYear()
    e.approximate = year < 1600 || year > 2100
    list.push(e)
  }
  solar.sort(byTime)
  lunar.sort(byTime)
  all = solar.concat(lunar)
  all.sort(byTime)
  return all.length
}

// Forgets everything loaded (for tests and memory).
function clear() {
  loaded = {}
  solar = []
  lunar = []
  all = []
}

function listFor(kind) {
  return kind === "solar" ? solar : (kind === "lunar" ? lunar : all)
}

// The index of the first eclipse in `list` at or after `utcMs`.
function firstAtOrAfter(list, utcMs) {
  var lo = 0, hi = list.length
  while (lo < hi) {
    var mid = (lo + hi) >> 1
    if (list[mid].utcMs < utcMs) lo = mid + 1
    else hi = mid
  }
  return lo
}

// Whether every file between two moments is loaded (for kind, or both).
function covered(fromMs, toMs, kind) {
  return missingChunks(Math.min(fromMs, toMs), Math.max(fromMs, toMs), kind === "solar" || kind === "lunar" ? kind : "").length === 0
}

// The first eclipse of a kind ("solar", "lunar", or anything else for
// both) strictly after `utcMs`; null past 3000 or when the files between
// are not loaded.
function next(kind, utcMs) {
  var list = listFor(kind)
  var i = firstAtOrAfter(list, utcMs + 1)
  if (i >= list.length) return null
  return covered(utcMs, list[i].utcMs, kind) ? list[i] : null
}

// The last one strictly before `utcMs`; null before 2000 BC or when not loaded.
function previous(kind, utcMs) {
  var list = listFor(kind)
  var i = firstAtOrAfter(list, utcMs) - 1
  if (i < 0) return null
  return covered(list[i].utcMs, utcMs, kind) ? list[i] : null
}

// Every loaded eclipse with fromMs ≤ utcMs < toMs, in order.
function between(fromMs, toMs) {
  var out = []
  for (var i = firstAtOrAfter(all, fromMs); i < all.length && all[i].utcMs < toMs; i++) out.push(all[i])
  return out
}

// The eclipse of either kind nearest in time to `utcMs`.
function nearest(utcMs) {
  var a = previous("", utcMs + 1)
  var b = next("", utcMs)
  if (!a) return b
  if (!b) return a
  return utcMs - a.utcMs <= b.utcMs - utcMs ? a : b
}

// ---- Seen from a place ----

function unitFromLatLon(lat, lon) {
  var p = lat * RAD, l = lon * RAD
  return [Math.cos(p) * Math.cos(l), Math.cos(p) * Math.sin(l), Math.sin(p)]
}

function dot3(a, b) {
  return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
}

// Earth's equatorial radius (WGS 84, 6378.137 km) and the radii of the Sun
// and the Moon (IAU 2015 nominal solar radius 695 700 km; Moon 1737.4 km,
// NASA Moon fact sheet https://nssdc.gsfc.nasa.gov/planetary/factsheet/moonfact.html,
// retrieved 2026-10-05).
var EARTH_RADIUS_KM = 6378.137
var SUN_RADIUS_KM = 695700
var MOON_RADIUS_KM = 1737.4
var AU_KM = 149597870.7

// The geocentric altitude (degrees) of the eclipsed Moon at greatest
// eclipse, seen from (lat, lon), and the same corrected for the Moon's
// parallax (the topocentric altitude, about 0.95° lower at the horizon).
function lunarAltitude(eclipse, lat, lon) {
  var m = Moon.moonPosition(eclipse.utcMs)
  var c = dot3(unitFromLatLon(lat, lon), unitFromLatLon(m.lat, m.lon))
  var geo = Math.asin(Math.max(-1, Math.min(1, c))) / RAD
  var hp = Math.asin(EARTH_RADIUS_KM / AstroEvents.moonDistanceKm(eclipse.utcMs)) / RAD
  return { geocentric: geo, topocentric: geo - hp * Math.cos(geo * RAD) }
}

// Where the shadow axis meets the fundamental plane (through Earth's centre,
// perpendicular to the Sun's direction), in Earth-fixed coordinates and
// Earth radii, from Moon.js and Sky.js at a moment: { axis: [x, y, z],
// sun: unit vector, moonKm }.
function shadowAxis(utcMs) {
  var s = Sky.subsolarPoint(utcMs)
  var sun = unitFromLatLon(s.lat, s.lon)
  var mp = Moon.moonPosition(utcMs)
  var km = AstroEvents.moonDistanceKm(utcMs)
  var m = unitFromLatLon(mp.lat, mp.lon)
  var r = km / EARTH_RADIUS_KM
  var k = dot3(m, sun) * r
  return { axis: [m[0] * r - k * sun[0], m[1] * r - k * sun[1], m[2] * r - k * sun[2]], sun: sun, moonKm: km }
}

// A solar eclipse seen from (lat, lon), approximately:
//   { visible, fromMs, toMs (the first and last 2-minute step inside),
//     margin (Earth radii: the least distance from the penumbra's edge
//     while the Sun is up; negative inside) }
// The shadow axis at greatest eclipse is put where the catalogue says
// (through the point of greatest eclipse, |gamma| from the centre); its
// motion over ±4 hours comes from the change in Moon.js's and Sky.js's
// geometry (differences, so their few-tenths-of-a-degree errors mostly
// cancel). The place sees a partial phase while it lies inside the
// penumbra (radius ≈ 0.27 + Moon distance × (R☉ + R☾)/1 au, about 0.55
// Earth radii, ignoring Earth's flattening and the penumbra's slant) with
// the Sun above the horizon. Against NASA's Besselian elements for
// 2024-04-08 the margin agrees within 0.004 Earth radii (25 km) for eight
// places (the test allows 0.03: the catalogue's whole-degree point alone
// can shift the axis by about 0.02), and the partial phase's start and
// end within the 2-minute step (tests). Still approximate: it does not
// say how much of the Sun is covered, and before 1600 the UT (so the
// longitudes) carries ΔT's error.
// About 10 ms per call: compute it once per eclipse and place.
function solarVisibility(eclipse, lat, lon) {
  var p = unitFromLatLon(lat, lon)
  var g = unitFromLatLon(eclipse.lat, eclipse.lon)
  var at0 = shadowAxis(eclipse.utcMs)
  // The catalogue's axis point: G projected on the plane, scaled to |gamma|.
  var gs = dot3(g, at0.sun)
  var gp = [g[0] - gs * at0.sun[0], g[1] - gs * at0.sun[1], g[2] - gs * at0.sun[2]]
  var gl = Math.sqrt(dot3(gp, gp))
  var scale = gl > 1e-9 ? Math.abs(eclipse.gamma) / gl : 0
  var corr = [at0.axis[0] - gp[0] * scale, at0.axis[1] - gp[1] * scale, at0.axis[2] - gp[2] * scale]
  var horizon = Math.sin(-0.833 * RAD)
  var best = Infinity, from = 0, to = 0
  for (var t = eclipse.utcMs - 4 * HOUR_MS; t <= eclipse.utcMs + 4 * HOUR_MS; t += 120000) {
    var a = shadowAxis(t)
    var s = a.sun
    var cs = dot3(corr, s)
    var ps = dot3(p, s)
    var dx = p[0] - ps * s[0] - (a.axis[0] - (corr[0] - cs * s[0]))
    var dy = p[1] - ps * s[1] - (a.axis[1] - (corr[1] - cs * s[1]))
    var dz = p[2] - ps * s[2] - (a.axis[2] - (corr[2] - cs * s[2]))
    var d = Math.sqrt(dx * dx + dy * dy + dz * dz)
    var radius = (MOON_RADIUS_KM + a.moonKm * (SUN_RADIUS_KM + MOON_RADIUS_KM) / AU_KM) / EARTH_RADIUS_KM
    if (ps > horizon) {
      best = Math.min(best, d - radius)
      if (d < radius) {
        if (!from) from = t
        to = t
      }
    }
  }
  return { visible: from > 0, fromMs: from, toMs: to, margin: best }
}

// Whether an eclipse can be seen from (lat, lon): a lunar one when the
// Moon is above the horizon at greatest eclipse (topocentric altitude
// above −0.833°, the refraction of the horizon as for sunrise); a solar
// one when the place passes through the penumbra in daylight
// (solarVisibility, approximate).
function visibleFrom(eclipse, lat, lon) {
  if (!eclipse) return false
  if (eclipse.kind === "lunar") return lunarAltitude(eclipse, lat, lon).topocentric > -0.833
  return solarVisibility(eclipse, lat, lon).visible
}

if (typeof module !== "undefined") module.exports = {
  SOLAR_TYPES: SOLAR_TYPES, LUNAR_TYPES: LUNAR_TYPES, CHUNKS: CHUNKS, chunksFor: chunksFor,
  missingChunks: missingChunks, addChunk: addChunk, clear: clear, next: next, previous: previous,
  between: between, nearest: nearest, lunarAltitude: lunarAltitude, shadowAxis: shadowAxis,
  solarVisibility: solarVisibility, visibleFrom: visibleFrom
}
