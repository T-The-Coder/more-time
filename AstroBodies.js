.pragma library
.import "Astro.js" as Astro
.import "AstroRotation.js" as AstroRotation

// The Astro tab's extra objects: the dwarf planets Ceres, Pluto and Eris,
// comet 1P/Halley, the asteroid and Kuiper belts as sample points, the
// large moons of Jupiter and Saturn, and the spacecraft Voyager 1 and 2,
// New Horizons and JWST. Positions are heliocentric (planet-centric for
// the moons), in the ecliptic and equinox of J2000, in au, as in Astro.js.
// Pure functions, so the tests load them in Node; every table says where
// its numbers come from.

var RAD = Math.PI / 180
var DAY_MS = 86400000

// Julian date of a moment (UTC taken for TT/TDB, as in Astro.js; the
// minute between them moves none of these visibly).
function julianDate(utcMs) {
  return utcMs / DAY_MS + 2440587.5
}

function wrap360(deg) {
  return (deg % 360 + 360) % 360
}

function spherical(p) {
  var r = Math.sqrt(p.x * p.x + p.y * p.y + p.z * p.z)
  return { r: r, lon: wrap360(Math.atan2(p.y, p.x) / RAD), lat: r > 0 ? Math.asin(p.z / r) / RAD : 0 }
}

// ---- Small bodies on Kepler orbits ----

// Osculating heliocentric elements, ecliptic and equinox J2000: epoch (JD
// TDB), a (au), e, i, node Ω, peri ω (argument of perihelion), M (mean
// anomaly at the epoch), all angles in degrees, n the mean motion in
// degrees per day. Propagated as a two-body orbit from the epoch, so the
// planets' pull is left out; the error against JPL Horizons over ±10 years
// from the epoch (the tests check it) is what `error` states.
//   - Ceres, Eris: JPL Small-Body Database, solutions JPL#48 (Ceres, dated
//     2021-04-13) and JPL#103 (Eris, 2026-06-06), epoch JD 2461200.5
//     (2026-06-14.0 TDB). Pluto: SBDB orbit JPL#1, epoch JD 2457588.5
//     (2016-07-31.0 TDB). https://ssd-api.jpl.nasa.gov/sbdb.api?sstr=<name>&full-prec=1,
//     retrieved 2026-10-03.
//   - 1P/Halley: SBDB's own epoch is 1968, too far back for a two-body
//     orbit; these are JPL Horizons' osculating elements from the same
//     solution (JPL#75) at JD 2461041.5 (2026-01-01.0 TDB),
//     https://ssd.jpl.nasa.gov/api/horizons.api (EPHEM_TYPE=ELEMENTS,
//     CENTER=500@10, ecliptic J2000), retrieved 2026-10-03. Next
//     perihelion (tp) JD 2474050.62, 2061-07-28.
var SMALL_BODIES = {
  ceres: { kind: "dwarf", epoch: 2461200.5, a: 2.765552595034094, e: 0.07969229514816586, i: 10.58802780183462,
    node: 80.24862682043221, peri: 73.29421453021587, M: 274.4193463761342, n: 0.21430445064843,
    radiusKm: 469.7, source: "JPL SBDB, solution JPL#48, epoch JD 2461200.5", error: "under 0.7° over ±10 years (Jupiter's pull)" },
  pluto: { kind: "dwarf", epoch: 2457588.5, a: 39.58862938517124, e: 0.2518378778576892, i: 17.14771140999114,
    node: 110.2923840543057, peri: 113.7090015158565, M: 38.68366347318184, n: 0.003956838955553025,
    radiusKm: 1188.3, source: "JPL SBDB, orbit JPL#1, epoch JD 2457588.5", error: "under 0.1° from 2016 to 2036" },
  eris: { kind: "dwarf", epoch: 2461200.5, a: 67.93394687853566, e: 0.4382385347971672, i: 43.9258279471791,
    node: 36.00477044417249, peri: 150.7949235840312, M: 211.774434275007, n: 0.001760247770619088,
    radiusKm: 1163, source: "JPL SBDB, solution JPL#103, epoch JD 2461200.5", error: "under 0.01° over ±10 years" },
  halley: { kind: "comet", epoch: 2461041.5, a: 17.85891278452395, e: 0.9679618548756710, i: 162.1617653940762,
    node: 59.49066227156327, peri: 112.3892314940491, M: 190.1093624929431, n: 0.01305934963652482,
    radiusKm: 5.5, source: "JPL Horizons osculating elements, solution JPL#75, epoch JD 2461041.5", error: "under 0.1° over ±10 years" }
}

// radiusKm, mean radii for the drawn size (AstroView.bodyRadius): Ceres
// 939.4 km effective diameter and Halley 11.0 km (SBDB physical data,
// phys-par=1, retrieved 2026-10-03); Pluto 1188.3 km (IAU WGCCRE 2015, NAIF
// pck00011.tpc BODY999_RADII); Eris 1163 ± 6 km (Sicardy et al. 2011, as
// on https://en.wikipedia.org/wiki/Eris_(dwarf_planet), retrieved
// 2026-10-03; SBDB lists no diameter).

var SMALL_BODY_KEYS = ["ceres", "pluto", "eris", "halley"]

// The elements in Astro.js's form at a moment: { a, e, I, L, peri (longitude
// of perihelion ϖ = Ω + ω), node } and the mean anomaly M (degrees).
function elementsFor(body, utcMs) {
  var el = SMALL_BODIES[body]
  if (!el) return null
  var M = wrap360(el.M + el.n * (julianDate(utcMs) - el.epoch))
  var peri = el.node + el.peri
  return { a: el.a, e: el.e, I: el.i, node: el.node, peri: peri, L: peri + M, M: M }
}

// Where a dwarf planet or the comet stands: { x, y, z, r, lon, lat } as in
// Astro.position.
function position(body, utcMs) {
  var el = elementsFor(body, utcMs)
  if (!el) return null
  var M = ((el.M + 180) % 360 - 180) * RAD
  var p = Astro.orbitPoint(el, Astro.solveKepler(M, el.e))
  var s = spherical(p)
  return { x: p.x, y: p.y, z: p.z, r: s.r, lon: s.lon, lat: s.lat }
}

// The orbit as `count` points, evenly spaced in eccentric anomaly (as
// Astro.orbit). For Halley (e 0.97) most points then gather at the far
// end; `count` 200 or more keeps the perihelion turn smooth.
function orbit(body, count) {
  var el = elementsFor(body, julianDateToMs(SMALL_BODIES[body] ? SMALL_BODIES[body].epoch : 2451545))
  if (!el) return []
  var n = Math.max(8, count || 128)
  var points = []
  for (var i = 0; i < n; i++) points.push(Astro.orbitPoint(el, 2 * Math.PI * i / n))
  return points
}

function julianDateToMs(jd) {
  return (jd - 2440587.5) * DAY_MS
}

// The orbital period in days, from the mean motion.
function periodDays(body) {
  var el = SMALL_BODIES[body]
  return el ? 360 / el.n : 0
}

// A comet's tail points away from the Sun: the unit vector along its
// heliocentric position (any { x, y, z }).
function tailDirection(p) {
  var r = Math.sqrt(p.x * p.x + p.y * p.y + p.z * p.z)
  return r > 0 ? { x: p.x / r, y: p.y / r, z: p.z / r } : { x: 0, y: 0, z: 0 }
}

// ---- The belts ----

// Park–Miller "minimal standard" generator (16807 · s mod 2³¹ − 1): exact
// in doubles, so QML's engine and Node give the same numbers.
function generator(seed) {
  var s = (Math.floor(Math.abs(seed)) % 2147483646) + 1
  return function() {
    s = (s * 16807) % 2147483647
    return (s - 1) / 2147483646
  }
}

// The belts' sample orbits. These are a picture, not a catalogue: the
// ranges are design choices that keep each band where its objects
// mostly are (a, e, i ranges below), not fitted to any survey.
//   - asteroids: a 2.1–3.3 au (the main belt between Mars and the 2:1
//     resonance with Jupiter), e 0–0.2, i 0–15°;
//   - kuiper: a 30–50 au (Neptune's orbit to the classical belt's outer
//     edge), e 0–0.2, i 0–20°.
var BELTS = {
  asteroids: { seed: 20260103, aMin: 2.1, aMax: 3.3, eMax: 0.2, iMax: 15 },
  kuiper: { seed: 19920830, aMin: 30, aMax: 50, eMax: 0.2, iMax: 20 }
}

var beltCache = {}

// The belt's first `count` sample orbits, cached: the same seed gives the
// same orbits, and a longer list starts with the shorter one.
function beltElements(name, count) {
  var belt = BELTS[name]
  if (!belt) return []
  var cached = beltCache[name]
  if (cached && cached.length >= count) return cached.slice(0, count)
  var random = generator(belt.seed)
  var out = []
  for (var k = 0; k < count; k++) {
    var a = belt.aMin + (belt.aMax - belt.aMin) * random()
    var e = belt.eMax * random()
    // Inclinations bunched towards the ecliptic: the square of a uniform.
    var u = random()
    var I = belt.iMax * u * u
    var node = 360 * random()
    var peri = node + 360 * random()
    var M0 = 360 * random()
    // Kepler's third law: the period in days for a in au.
    out.push({ a: a, e: e, I: I, node: node, peri: peri, M0: M0, periodDays: 365.25 * Math.pow(a, 1.5) })
  }
  beltCache[name] = out
  return out.slice(0, count)
}

// `count` points of a belt at a moment ({ x, y, z } in au), each on its
// orbit with its own period; its mean anomaly M0 holds at J2000.
function beltPoints(name, utcMs, count) {
  var els = beltElements(name, count || 0)
  var days = julianDate(utcMs) - 2451545.0
  var out = []
  for (var k = 0; k < els.length; k++) {
    var el = els[k]
    var M = (((el.M0 + 360 * days / el.periodDays) % 360 + 540) % 360 - 180) * RAD
    out.push(Astro.orbitPoint(el, Astro.solveKepler(M, el.e)))
  }
  return out
}

// ---- Large moons ----

// The large moons of Jupiter and Saturn as circles in their Laplace plane
// (within 0.6° of the planet's equator; the drawing may put them in the
// equator). Sources, retrieved 2026-10-03:
//   - JPL Solar System Dynamics, "Planetary Satellite Mean Elements"
//     (https://ssd.jpl.nasa.gov/sats/elem/sep.html; Jupiter: JUP365,
//     Jacobson 2021; Saturn: SAT441, Jacobson 2022), epoch 2000-01-01.5
//     TDB: aKm the semi-major axis, the Laplace plane's pole (right
//     ascension, declination, ICRF), and for the Galilean moons the mean
//     longitude at the epoch L0 = Ω + ω + M (the table's node, argument of
//     periapsis and mean anomaly, each to 0.1°), counted in the Laplace
//     plane from its ascending node on the ICRF equator.
//   - Titan: that table's Ω, ω and M do not reproduce Titan's place in this
//     reading (156° off at the epoch, against 1° for the Galilean moons),
//     so its epoch longitude comes from JPL Horizons' osculating elements
//     for Titan about Saturn at JD 2451545.0 (SAT441, ecliptic J2000:
//     Ω 169.2391602866279°, i 27.71833887311165°, ω 164.4091285733822°,
//     M 163.4361974944248°), as the direction of the mean place ω + M on
//     that orbit, carried into the Laplace plane.
//   - rate: the mean motion in longitude (°/day), equal to the IAU
//     rotation rate Ẇ of these synchronously turning moons (NAIF
//     pck00010.tpc, BODY501…504 and BODY606 _PM, IAU 2009).
// The tests check the directions against JPL Horizons over 2000–2036.
// Eccentricities (up to 0.029 for Titan, 3° in the place) are left out.
// radiusKm: the mean of the three radii in NAIF pck00010.tpc (IAU 2009;
// BODY501…504 and BODY606 _RADII), to 0.1 km.
var MOONS = {
  io: { planet: "jupiter", aKm: 421800, L0: 0.0 + 49.1 + 330.9, rate: 203.4889538, poleRa: 268.1, poleDec: 64.5, radiusKm: 1821.5 },
  europa: { planet: "jupiter", aKm: 671100, L0: 184.0 + 45.0 + 345.4, rate: 101.3747235, poleRa: 268.1, poleDec: 64.5, radiusKm: 1560.8 },
  ganymede: { planet: "jupiter", aKm: 1070400, L0: 58.5 + 198.3 + 324.8, rate: 50.3176081, poleRa: 268.2, poleDec: 64.6, radiusKm: 2631.2 },
  callisto: { planet: "jupiter", aKm: 1882700, L0: 309.1 + 43.8 + 87.4, rate: 21.5710715, poleRa: 268.7, poleDec: 64.8, radiusKm: 2410.3 },
  titan: { planet: "saturn", aKm: 1221900, rate: 22.5769768, poleRa: 36.4, poleDec: 84.0, radiusKm: 2574.8,
    osculating: { node: 169.2391602866279, i: 27.71833887311165, peri: 164.4091285733822, M: 163.4361974944248 } }
}

var MOON_KEYS = ["io", "europa", "ganymede", "callisto", "titan"]

// The Laplace plane's axes in the ICRF: node (its ascending node on the
// ICRF equator), the direction 90° on in the plane, and the pole.
function laplaceAxes(m) {
  var a0 = m.poleRa * RAD
  var pole = AstroRotation.fromSpherical(m.poleRa, m.poleDec)
  var node = { x: Math.cos(a0 + Math.PI / 2), y: Math.sin(a0 + Math.PI / 2), z: 0 }
  return { node: node, y: AstroRotation.cross(pole, node), pole: pole }
}

// The epoch longitude in the Laplace plane (degrees): L0, or from the
// osculating ecliptic elements, the direction of argument of latitude
// ω + M on that orbit.
function epochLongitude(m) {
  if (m.L0 !== undefined) return m.L0
  var o = m.osculating
  var u = (o.peri + o.M) * RAD, O = o.node * RAD, I = o.i * RAD
  var ecl = { x: Math.cos(O) * Math.cos(u) - Math.sin(O) * Math.sin(u) * Math.cos(I),
    y: Math.sin(O) * Math.cos(u) + Math.cos(O) * Math.sin(u) * Math.cos(I), z: Math.sin(u) * Math.sin(I) }
  var eq = AstroRotation.eclipticToEquatorial(ecl)
  var ax = laplaceAxes(m)
  return wrap360(Math.atan2(AstroRotation.dot(eq, ax.y), AstroRotation.dot(eq, ax.node)) / RAD)
}

// A moon's place relative to its planet at a moment:
//   { x, y, z } in au (ecliptic J2000), the circle's radius times the
//   direction; angle: its mean longitude in the Laplace plane (degrees,
//   0–360); phaseKnown: true (every epoch longitude here is JPL's);
//   planet: "jupiter" | "saturn".
function moonPosition(key, utcMs) {
  var m = MOONS[key]
  if (!m) return null
  var days = julianDate(utcMs) - 2451545.0
  var L = wrap360(epochLongitude(m) + m.rate * days)
  var ax = laplaceAxes(m)
  var c = Math.cos(L * RAD), s = Math.sin(L * RAD)
  var eq = { x: ax.node.x * c + ax.y.x * s, y: ax.node.y * c + ax.y.y * s, z: ax.node.z * c + ax.y.z * s }
  var d = AstroRotation.equatorialToEcliptic(eq)
  var r = m.aKm / 149597870.7
  return { x: d.x * r, y: d.y * r, z: d.z * r, angle: L, phaseKnown: true, planet: m.planet }
}

// The orbital period in days (sidereal, from the rate).
function moonPeriodDays(key) {
  var m = MOONS[key]
  return m ? 360 / m.rate : 0
}

// The moon's orbit plane normal (the Laplace pole) in the ecliptic J2000.
function moonOrbitNormal(key) {
  var m = MOONS[key]
  return m ? AstroRotation.equatorialToEcliptic(AstroRotation.fromSpherical(m.poleRa, m.poleDec)) : null
}

// ---- Spacecraft ----

// Heliocentric state vectors (ecliptic J2000, au and au/day) at JD
// 2461041.5 (2026-01-01.0 TDB) from JPL Horizons (Voyager 1: -31, solution
// Voyager_1_ST+refit2022_m; Voyager 2: -32, Voyager_2_ST+refit2022_m; New
// Horizons: -98, NH_merged; CENTER=500@10, VEC_TABLE=2,
// https://ssd.jpl.nasa.gov/api/horizons.api, retrieved 2026-10-03).
// Beyond 60 au the Sun barely bends their paths, so each moves on a
// straight line: p(t) = p0 + v · (t − t0). Against Horizons from 2016 to
// 2036 that stays within 0.02° in direction for the Voyagers and 0.12° for
// New Horizons, and within 0.12 au (Voyagers) and 0.72 au (New Horizons,
// still slowing) in distance.
var SPACECRAFT = {
  voyager1: { epoch: 2461041.5, p: [-31.83641396068854, -134.6784849020786, 97.44480620314309],
    v: [-0.001197151941601862, -0.007861077920510877, 0.005680005847953139] },
  voyager2: { epoch: 2461041.5, p: [39.22753200608659, -103.9915497105585, -87.91865807489688],
    v: [0.002427683335518084, -0.005395071894167568, -0.006538419574529805] },
  newhorizons: { epoch: 2461041.5, p: [20.00963282700209, -60.30445125761598, 2.212929266091343],
    v: [0.003070495059002452, -0.007229267528684547, 0.0002845557306013135] }
}

var SPACECRAFT_KEYS = ["voyager1", "voyager2", "newhorizons", "jwst"]

// A spacecraft at a moment: { x, y, z, r, lon, lat, speed (au/year away
// from the Sun) }. JWST: near the Sun–Earth L2 point (l2Point), speed 0.
function spacecraftPosition(key, utcMs) {
  if (key === "jwst") {
    var l2 = l2Point(Astro.position("earth", utcMs))
    var s2 = spherical(l2)
    return { x: l2.x, y: l2.y, z: l2.z, r: s2.r, lon: s2.lon, lat: s2.lat, speed: 0 }
  }
  var c = SPACECRAFT[key]
  if (!c) return null
  var dt = julianDate(utcMs) - c.epoch
  var p = { x: c.p[0] + c.v[0] * dt, y: c.p[1] + c.v[1] * dt, z: c.p[2] + c.v[2] * dt }
  var s = spherical(p)
  var radial = (p.x * c.v[0] + p.y * c.v[1] + p.z * c.v[2]) / s.r
  return { x: p.x, y: p.y, z: p.z, r: s.r, lon: s.lon, lat: s.lat, speed: radial * 365.25 }
}

// The Sun–Earth L2 point, about 1.5 million km (0.01 au) beyond Earth on
// the Sun–Earth line: Earth's position scaled by 1.01. JWST circles it in
// a halo orbit some 0.005 au wide, which this leaves out.
function l2Point(earth) {
  return { x: earth.x * 1.01, y: earth.y * 1.01, z: earth.z * 1.01 }
}

if (typeof module !== "undefined") module.exports = {
  SMALL_BODIES: SMALL_BODIES, SMALL_BODY_KEYS: SMALL_BODY_KEYS, BELTS: BELTS, MOONS: MOONS, MOON_KEYS: MOON_KEYS,
  SPACECRAFT: SPACECRAFT, SPACECRAFT_KEYS: SPACECRAFT_KEYS,
  julianDate: julianDate, elementsFor: elementsFor, position: position, orbit: orbit, periodDays: periodDays,
  tailDirection: tailDirection, generator: generator, beltElements: beltElements, beltPoints: beltPoints,
  moonPosition: moonPosition, moonPeriodDays: moonPeriodDays, epochLongitude: epochLongitude, moonOrbitNormal: moonOrbitNormal, spacecraftPosition: spacecraftPosition, l2Point: l2Point
}
