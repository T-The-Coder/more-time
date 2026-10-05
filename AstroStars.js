.pragma library
.import "AstroRotation.js" as AstroRotation

// The stars behind the Astro tab's solar system: the naked-eye stars, the
// constellation figures and the constellation a direction lies in. Pure
// functions over the two data files, which TimeAstro.qml reads with a
// FileView and passes in as parsed objects:
//
//  - data/astro-stars.json: the Yale Bright Star Catalogue (5th rev. ed.,
//    Hoffleit & Warren 1991; public domain, NASA HEASARC) to V = 5.0, plus
//    the fainter stars the figures need, brightest first. RA/Dec J2000 in
//    0.001°, V in 0.01 mag, a colour class from B−V, and the IAU (WGSN)
//    proper names of the stars to V = 2.5.
//  - data/astro-constellations.json: the 88 IAU abbreviations, Latin names
//    and genitives, the stick figures as polylines of star indices (from
//    d3-celestial, © 2015 Olaf Frohn, BSD 3-Clause, after the IAU charts),
//    and the IAU 1930 boundaries in B1875 coordinates as arranged by Roman
//    (1987, PASP 99, 695; CDS VI/42).
//
// Both files come from tools/build-astro-stars.py. Directions are unit
// vectors in the ecliptic and equinox of J2000 (as AstroView and Astro.js
// use): x to the vernal point, z to the ecliptic's north pole.

var RAD = Math.PI / 180

// Colour classes (data `color`): B−V < 0, < 0.3, < 0.6, < 1.1, ≥ 1.1.
var COLOR_KEYS = ["blue", "white", "yellowWhite", "yellow", "orange"]

// A unit vector in the ecliptic J2000 from right ascension and declination
// (ICRF/J2000, degrees): the equatorial vector turned by the J2000
// obliquity (AstroRotation.OBLIQUITY_J2000, 23.4392911°).
function eclipticDirection(raDeg, decDeg) {
  return AstroRotation.equatorialToEcliptic(AstroRotation.fromSpherical(raDeg, decDeg))
}

// The star file as plain arrays in degrees and magnitudes, with each star's
// ecliptic direction (x, y, z arrays) worked out once:
//   { count, hr, ra, dec, mag, color, x, y, z, names: { index: name },
//     nameList: [{ index, name }] }
// Brightest first, so the stars to a magnitude are a prefix.
function stars(data) {
  var n = data && data.ra ? data.ra.length : 0
  var out = { count: n, hr: [], ra: [], dec: [], mag: [], color: [], x: [], y: [], z: [], names: {}, nameList: [] }
  for (var i = 0; i < n; i++) {
    var ra = data.ra[i] / 1000
    var dec = data.dec[i] / 1000
    var v = eclipticDirection(ra, dec)
    out.hr.push(data.hr ? data.hr[i] : 0)
    out.ra.push(ra)
    out.dec.push(dec)
    out.mag.push(data.mag[i] / 100)
    out.color.push(data.color[i])
    out.x.push(v.x)
    out.y.push(v.y)
    out.z.push(v.z)
  }
  var names = data && data.names ? data.names : []
  for (var k = 0; k < names.length; k++) {
    out.names[names[k][0]] = names[k][1]
    out.nameList.push({ index: names[k][0], name: names[k][1] })
  }
  return out
}

// How many stars (a prefix of `s`, from stars()) are at most `limitMag`.
function countTo(s, limitMag) {
  var lo = 0, hi = s.count
  while (lo < hi) {
    var mid = (lo + hi) >> 1
    if (s.mag[mid] <= limitMag) lo = mid + 1
    else hi = mid
  }
  return lo
}

// The stars to `limitMag` for drawing: [{ index, x, y, z, mag, color,
// size, name }] (name "" when none). `s` is the result of stars().
function visibleStars(s, limitMag) {
  var n = countTo(s, limitMag)
  var out = []
  for (var i = 0; i < n; i++)
    out.push({ index: i, x: s.x[i], y: s.y[i], z: s.z[i], mag: s.mag[i], color: s.color[i],
      size: starSize(s.mag[i]), name: s.names[i] || "" })
  return out
}

// A star's drawn radius in px: 0.6 px at magnitude 5, 1 px more per 2.2
// magnitudes (so the drawn area follows the flux roughly), Sirius (−1.46)
// at 3.5 px.
function starSize(mag) {
  return Math.max(0.5, Math.min(3.5, 0.6 + (5 - mag) * 0.45))
}

// Its opacity 0–1: from 1 at magnitude ≤ 1 down to 0.35 at 5.
function starAlpha(mag) {
  return Math.max(0.25, Math.min(1, 1 - (mag - 1) * 0.1625))
}

// ---- Constellations ----

// Index of an IAU abbreviation (e.g. "Ori") in the constellation file, −1
// when unknown.
function constellationIndex(cons, abbr) {
  return cons.abbr.indexOf(abbr)
}

// A figure as line segments: [[i, j], ...] star index pairs.
function figureSegments(cons, abbr) {
  var k = constellationIndex(cons, abbr)
  var out = []
  if (k < 0) return out
  var polys = cons.figures[k]
  for (var p = 0; p < polys.length; p++)
    for (var i = 0; i + 1 < polys[p].length; i++) out.push([polys[p][i], polys[p][i + 1]])
  return out
}

// Every figure's segments at once: [{ abbr, segments }].
function allFigures(cons) {
  var out = []
  for (var k = 0; k < cons.abbr.length; k++)
    out.push({ abbr: cons.abbr[k], segments: figureSegments(cons, cons.abbr[k]) })
  return out
}

// Herget's precession of a mean place (radians) from one epoch to another
// (years A.D.), as in Roman's (1987) program (CDS VI/42 program.c, after
// Publ. Cincinnati Obs. No. 24). Good to well under an arcsecond over the
// 125 years from 1875 to 2000, which is all it is used for.
function hergetPrecess(ra, dec, epoch1, epoch2) {
  var csr = RAD / 3600
  var T = 0.001 * (epoch2 - epoch1)
  var ST = 0.001 * (epoch1 - 1900)
  var A = csr * T * (23042.53 + ST * (139.75 + 0.06 * ST) + T * (30.23 - 0.27 * ST + 18.0 * T))
  var B = csr * T * T * (79.27 + 0.66 * ST + 0.32 * T) + A
  var C = csr * T * (20046.85 - ST * (85.33 + 0.37 * ST) + T * (-42.67 - 0.37 * ST - 41.8 * T))
  var sA = Math.sin(A), sB = Math.sin(B), sC = Math.sin(C), cA = Math.cos(A), cB = Math.cos(B), cC = Math.cos(C)
  var x1 = Math.cos(dec) * Math.cos(ra), y1 = Math.cos(dec) * Math.sin(ra), z1 = Math.sin(dec)
  var x2 = (cA * cB * cC - sA * sB) * x1 + (-cA * sB - sA * cB * cC) * y1 + (-cB * sC) * z1
  var y2 = (sA * cB + cA * sB * cC) * x1 + (cA * cB - sA * sB * cC) * y1 + (-sB * sC) * z1
  var z2 = (cA * sC) * x1 + (-sA * sC) * y1 + cC * z1
  var ra2 = Math.atan2(y2, x2)
  if (ra2 < 0) ra2 += 2 * Math.PI
  return { ra: ra2, dec: Math.asin(Math.max(-1, Math.min(1, z2))) }
}

// The IAU constellation (abbreviation) holding a direction given as RA/Dec
// in degrees for `epoch` (years A.D., 2000 when left out): precessed to
// B1875, then the first of Roman's rows whose lower declination is below it
// and whose RA range holds it. Exact up to the precession (a few
// hundredths of an arcsecond), so wrong only on a boundary line itself.
function constellationOf(cons, raDeg, decDeg, epoch) {
  var p = hergetPrecess(raDeg * RAD, decDeg * RAD, epoch === undefined ? 2000 : epoch, 1875)
  var ra = p.ra / RAD / 15
  var dec = p.dec / RAD
  var b = cons.bounds
  for (var i = 0; i < b.length; i++) {
    var row = b[i]
    if (row[2] > dec || row[1] <= ra || row[0] > ra) continue
    return cons.abbr[row[3]]
  }
  return ""
}

// The same for a direction in ecliptic J2000 longitude and latitude.
function constellationAtEcliptic(cons, lonDeg, latDeg) {
  var v = AstroRotation.eclipticToEquatorial(AstroRotation.fromSpherical(lonDeg, latDeg))
  var s = AstroRotation.toSpherical(v)
  return constellationOf(cons, s.lon, s.lat)
}

// The 13 constellations along the ecliptic, with the J2000 ecliptic
// longitude (degrees) where the ecliptic enters each one, going east: the
// IAU 1930 boundaries (Roman's B1875 table) crossed with the J2000
// ecliptic (latitude 0), found by zodiacCrossings() to 0.01°. The tests
// recompute them from the data file and check the Sun's constellation against the dates in Wikipedia's "Zodiac" table
// (https://en.wikipedia.org/wiki/Zodiac, retrieved 2026-10-05).
// Since the boundaries are fixed to the stars, these longitudes do not
// change with time in the J2000 frame.
var ZODIAC = [
  { abbr: "Psc", lon: 351.65 }, { abbr: "Ari", lon: 28.69 }, { abbr: "Tau", lon: 53.42 },
  { abbr: "Gem", lon: 90.14 }, { abbr: "Cnc", lon: 117.99 }, { abbr: "Leo", lon: 138.04 },
  { abbr: "Vir", lon: 173.86 }, { abbr: "Lib", lon: 217.81 }, { abbr: "Sco", lon: 241.05 },
  { abbr: "Oph", lon: 247.64 }, { abbr: "Sgr", lon: 266.24 }, { abbr: "Cap", lon: 299.66 },
  { abbr: "Aqr", lon: 327.49 }
]

// The crossings of the J2000 ecliptic with the boundaries, from the data:
// [{ abbr, lon }] in the order met going east from 0°, each the longitude
// (to `stepDeg`, 0.01 when left out) where that constellation begins.
// About 36 000 lookups: for the tests and for rebuilding ZODIAC, not per frame.
function zodiacCrossings(cons, stepDeg) {
  var step = stepDeg || 0.01
  var out = []
  var last = constellationAtEcliptic(cons, 360 - step, 0)
  for (var lon = 0; lon < 360; lon += step) {
    var here = constellationAtEcliptic(cons, lon, 0)
    if (here !== last) out.push({ abbr: here, lon: Math.round(lon / step) * step })
    last = here
  }
  return out
}

// The zodiac constellation (abbreviation) at a J2000 ecliptic longitude:
// the stretch of the ecliptic inside it (ZODIAC). Exact on the ecliptic,
// so right for the Sun; for a planet or the Moon, up to 7° or 5° off it,
// it names the constellation along the ecliptic at its longitude, which is
// what almanacs mean by "in Virgo", even where the true IAU constellation
// (constellationOf) is a neighbour such as Cetus, Orion or Sextans.
function zodiacAt(lonDeg) {
  var lon = ((lonDeg % 360) + 360) % 360
  var best = ZODIAC[0].abbr
  // ZODIAC[0] (Pisces) wraps over 0°: below Aries' start it is Pisces.
  for (var i = 1; i < ZODIAC.length; i++) if (lon >= ZODIAC[i].lon) best = ZODIAC[i].abbr
  if (lon >= ZODIAC[0].lon) best = ZODIAC[0].abbr
  return best
}

if (typeof module !== "undefined") module.exports = {
  COLOR_KEYS: COLOR_KEYS, ZODIAC: ZODIAC, eclipticDirection: eclipticDirection, stars: stars, countTo: countTo,
  visibleStars: visibleStars, starSize: starSize, starAlpha: starAlpha, constellationIndex: constellationIndex,
  figureSegments: figureSegments, allFigures: allFigures, hergetPrecess: hergetPrecess,
  constellationOf: constellationOf, constellationAtEcliptic: constellationAtEcliptic,
  zodiacCrossings: zodiacCrossings, zodiacAt: zodiacAt
}
