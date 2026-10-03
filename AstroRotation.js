.pragma library
.import "Astro.js" as Astro

// How the bodies of the Astro tab turn: Earth by its sidereal time, the
// Sun, the planets and the Moon by the IAU rotation model (the pole's right
// ascension and declination and the prime meridian W = W0 + Ẇ·d). All
// directions are unit vectors { x, y, z } in the ecliptic and equinox of
// J2000 (as in Astro.js: x towards the vernal point, z to the ecliptic's
// north pole), unless a name says equatorial. A body-fixed frame has x
// through the prime meridian on the equator and z along the IAU north pole.
// Pure functions, so the tests load them in Node.

var RAD = Math.PI / 180

// J2000.0 (2000-01-01 12:00 TT, taken as UTC like Astro.js) in Unix ms.
var J2000_MS = Date.UTC(2000, 0, 1, 12)

// The obliquity of the ecliptic at J2000, 84381.448″ (IAU 1976; the value
// that defines the "Ecliptic of J2000.0" of JPL Horizons and Meeus eq. 22.2).
// Sources: Meeus, Astronomical Algorithms (2nd ed.) eq. 22.2;
// https://ssd.jpl.nasa.gov/horizons/manual.html ("Ecliptic of J2000.0",
// obliquity 84381.448″); retrieved 2026-10-03.
var OBLIQUITY_J2000 = 23.4392911

// TT − UTC in seconds: 32.184 s (TT − TAI) + 37 s (TAI − UTC since
// 2017-01-01, IERS Bulletin C, https://hpiers.obspm.fr/iers/bul/bulc/bulletinc.dat,
// retrieved 2026-10-03). The IAU rotation model counts days of TT; for
// Jupiter (870°/day) the 69 s turn it by 0.7°. Before 2017 TT − UTC was a
// few seconds less, which no drawing shows.
var TT_MINUS_UTC_S = 69.184

// Days since J2000.0: in UT (for the sidereal time) and in TT (for the IAU
// model).
function daysUT(utcMs) {
  return (utcMs - J2000_MS) / 86400000
}

function daysTT(utcMs) {
  return (utcMs + TT_MINUS_UTC_S * 1000 - J2000_MS) / 86400000
}

function wrap360(deg) {
  return (deg % 360 + 360) % 360
}

function wrap180(deg) {
  return ((deg + 180) % 360 + 360) % 360 - 180
}

// ---- Earth's rotation ----

// Greenwich mean sidereal time in degrees (0–360), IAU 1982 expression as
// given by Meeus (Astronomical Algorithms, eq. 12.4):
//   θ0 = 280.46061837° + 360.98564736629° · d + 0.000387933° · T² − T³ / 38710000
// with d the days of UT1 (here UTC, within 0.9 s) since J2000.0 and T = d /
// 36525. The same linear terms as USNO's 18.697374558 h + 24.06570982441908 h · D
// (https://aa.usno.navy.mil/faq/GAST, retrieved 2026-10-03).
function gmst(utcMs) {
  var d = daysUT(utcMs)
  var T = d / 36525
  return wrap360(280.46061837 + 360.98564736629 * d + 0.000387933 * T * T - T * T * T / 38710000)
}

// The Earth rotation angle (IERS 2010 conventions) in degrees (0–360):
// θ = 360° · (0.7790572732640 + 1.00273781191135448 · Du), Du the days of
// UT1 since J2000.0 (https://en.wikipedia.org/wiki/Sidereal_time#ERA,
// retrieved 2026-10-03). The fractional days are split off first, so the
// large product loses no precision.
function earthRotationAngle(utcMs) {
  var du = daysUT(utcMs)
  var whole = Math.floor(du)
  var frac = du - whole
  return wrap360(360 * (0.7790572732640 + 0.00273781191135448 * du + frac))
}

// ---- Vectors and frames ----

function vec(x, y, z) {
  return { x: x, y: y, z: z }
}

function dot(a, b) {
  return a.x * b.x + a.y * b.y + a.z * b.z
}

function cross(a, b) {
  return vec(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
}

function norm(a) {
  var r = Math.sqrt(dot(a, a))
  return r > 0 ? vec(a.x / r, a.y / r, a.z / r) : vec(0, 0, 0)
}

function angleBetween(a, b) {
  var c = dot(norm(a), norm(b))
  return Math.acos(Math.max(-1, Math.min(1, c))) / RAD
}

// A unit vector from a longitude and latitude (or right ascension and
// declination) in degrees.
function fromSpherical(lon, lat) {
  var l = lon * RAD, b = lat * RAD
  return vec(Math.cos(b) * Math.cos(l), Math.cos(b) * Math.sin(l), Math.sin(b))
}

// { lon (0–360), lat } in degrees of a vector.
function toSpherical(v) {
  var r = Math.sqrt(dot(v, v))
  return { lon: wrap360(Math.atan2(v.y, v.x) / RAD), lat: r > 0 ? Math.asin(Math.max(-1, Math.min(1, v.z / r))) / RAD : 0 }
}

// Ecliptic J2000 ↔ equatorial J2000 (ICRF): a turn about x by the obliquity.
function eclipticToEquatorial(v) {
  var e = OBLIQUITY_J2000 * RAD, c = Math.cos(e), s = Math.sin(e)
  return vec(v.x, v.y * c - v.z * s, v.y * s + v.z * c)
}

function equatorialToEcliptic(v) {
  var e = OBLIQUITY_J2000 * RAD, c = Math.cos(e), s = Math.sin(e)
  return vec(v.x, v.y * c + v.z * s, -v.y * s + v.z * c)
}

// 3×3 matrices as flat row-major arrays [m00, m01, m02, m10, ...].
function apply(m, v) {
  return vec(m[0] * v.x + m[1] * v.y + m[2] * v.z, m[3] * v.x + m[4] * v.y + m[5] * v.z, m[6] * v.x + m[7] * v.y + m[8] * v.z)
}

function applyTransposed(m, v) {
  return vec(m[0] * v.x + m[3] * v.y + m[6] * v.z, m[1] * v.x + m[4] * v.y + m[7] * v.z, m[2] * v.x + m[5] * v.y + m[8] * v.z)
}

// The matrix whose columns are the three vectors.
function fromColumns(a, b, c) {
  return [a.x, b.x, c.x, a.y, b.y, c.y, a.z, b.z, c.z]
}

// ---- The IAU rotation model ----

// IAU WGCCRE 2009 report (Archinal et al. 2011, Celest. Mech. Dyn. Astr.
// 109, 101–135), table 1 and 2, as transcribed in NAIF's text kernel
// pck00010.tpc (https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/pck00010.tpc,
// retrieved 2026-10-03; the BODYnnn_POLE_RA, _POLE_DEC and _PM entries).
// ra, dec: the north pole's right ascension and declination in the ICRF
// (J2000 equator) in degrees, [value at J2000, rate per Julian century T];
// w: the prime meridian [W0 (°), Ẇ (°/day)], d in days of TT since J2000.
// The secular terms, plus the periodic ones of Neptune and the Moon
// (PERIODIC below). Left out as too small to draw: Mercury's 88-day
// libration in W (0.01°) and Jupiter's pole terms (0.0001°). The Moon's
// W is its mean rotation: the optical librations (up to 8°) come from its
// orbit, not from this model.
// Jupiter's W is System III (radio); Saturn's W (810.7939024°/day, 10 h 39 min)
// is the Voyager radio period, which the IAU itself calls uncertain: the
// real interior turns some minutes faster, so Saturn's meridian is a
// drawing aid, not a measured longitude. Uranus and Neptune likewise
// follow the Voyager radio periods.
var IAU = {
  sun: { ra: [286.13, 0], dec: [63.87, 0], w: [84.176, 14.1844000] },
  mercury: { ra: [281.0097, -0.0328], dec: [61.4143, -0.0049], w: [329.5469, 6.1385025] },
  venus: { ra: [272.76, 0], dec: [67.16, 0], w: [160.20, -1.4813688] },
  earth: { ra: [0, -0.641], dec: [90, -0.557], w: [190.147, 360.9856235] },
  moon: { ra: [269.9949, 0.0031], dec: [66.5392, 0.0130], w: [38.3213, 13.17635815] },
  mars: { ra: [317.68143, -0.1061], dec: [52.88650, -0.0609], w: [176.630, 350.89198226] },
  jupiter: { ra: [268.056595, -0.006499], dec: [64.495303, 0.002413], w: [284.95, 870.5360000] },
  saturn: { ra: [40.589, -0.036], dec: [83.537, -0.004], w: [38.90, 810.7939024] },
  uranus: { ra: [257.311, 0], dec: [-15.175, 0], w: [203.81, -501.1600928] },
  neptune: { ra: [299.36, 0], dec: [43.46, 0], w: [253.18, 536.3128492] }
}

var BODIES = ["sun", "mercury", "venus", "earth", "moon", "mars", "jupiter", "saturn", "uranus", "neptune"]

// The periodic terms the model keeps, from the same kernel: angles
// [value at J2000 (°), rate (° per Julian century)] (BODY8_ and
// BODY3_NUT_PREC_ANGLES) and per angle the coefficients (°) of sin in the
// right ascension, of cos in the declination and of sin in W
// (BODYnnn_NUT_PREC_RA, _DEC, _PM).
//  - Neptune: one angle N; its pole circles by up to 0.7°.
//  - The Moon: thirteen angles E1…E13. Without them its pole would sit on
//    the ecliptic's pole; with them it circles it at 1.54° every 18.6
//    years (Cassini's laws) and W follows (3.6°).
var PERIODIC = {
  neptune: { angles: [[357.85, 52.316]], ra: [0.70], dec: [-0.51], w: [-0.48] },
  moon: {
    angles: [[125.045, -1935.5364525], [250.089, -3871.072905], [260.008, 475263.3328725], [176.625, 487269.629985],
      [357.529, 35999.0509575], [311.589, 964468.49931], [134.963, 477198.869325], [276.617, 12006.300765],
      [34.226, 63863.5132425], [15.134, -5806.6093575], [119.743, 131.84064], [239.961, 6003.1503825],
      [25.053, 473327.79642]],
    ra: [-3.8787, -0.1204, 0.0700, -0.0172, 0, 0.0072, 0, 0, 0, -0.0052, 0, 0, 0.0043],
    dec: [1.5419, 0.0239, -0.0278, 0.0068, 0, -0.0029, 0.0009, 0, 0, 0.0008, 0, 0, -0.0009],
    w: [3.5610, 0.1208, -0.0642, 0.0158, 0.0252, -0.0066, -0.0047, -0.0046, 0.0028, 0.0052, 0.0040, 0.0019, -0.0044]
  }
}

// The periodic corrections { ra, dec, w } in degrees at T centuries.
function periodic(body, T) {
  var p = PERIODIC[body]
  var out = { ra: 0, dec: 0, w: 0 }
  if (!p) return out
  for (var i = 0; i < p.angles.length; i++) {
    var a = (p.angles[i][0] + p.angles[i][1] * T) * RAD
    out.ra += p.ra[i] * Math.sin(a)
    out.dec += p.dec[i] * Math.cos(a)
    out.w += p.w[i] * Math.sin(a)
  }
  return out
}

// The IAU north pole's right ascension and declination at a moment:
// { ra, dec } in degrees, ICRF.
function poleRaDec(body, utcMs) {
  var m = IAU[body]
  if (!m) return null
  var T = daysTT(utcMs) / 36525
  var p = periodic(body, T)
  return { ra: m.ra[0] + m.ra[1] * T + p.ra, dec: m.dec[0] + m.dec[1] * T + p.dec }
}

// The IAU north pole as a unit vector in the ecliptic J2000. The IAU north
// is the pole on the north side of the invariable plane: for Venus and
// Uranus, which turn backwards, it is not the pole the spin points to (see
// spinPoleVector).
function poleVector(body, utcMs) {
  var p = poleRaDec(body, utcMs === undefined ? J2000_MS : utcMs)
  return p ? equatorialToEcliptic(fromSpherical(p.ra, p.dec)) : null
}

// The spin axis by the right-hand rule: the IAU north pole, turned round
// for the bodies whose W decreases (Venus, Uranus).
function spinPoleVector(body, utcMs) {
  var p = poleVector(body, utcMs)
  if (!p) return null
  return IAU[body].w[1] < 0 ? vec(-p.x, -p.y, -p.z) : p
}

// The prime meridian W in degrees (0–360) at a moment.
function primeMeridian(body, utcMs) {
  var m = IAU[body]
  if (!m) return NaN
  var d = daysTT(utcMs)
  return wrap360(m.w[0] + m.w[1] * d + periodic(body, d / 36525).w)
}

// The sidereal rotation period in hours from Ẇ: negative for the bodies
// that turn backwards (Venus, Uranus). Earth: 23.934 h, the sidereal day.
function rotationPeriodHours(body) {
  var m = IAU[body]
  return m ? 360 / m.w[1] * 24 : NaN
}

// The normal of a planet's orbit (Astro.js elements at the moment) in the
// ecliptic J2000: (sin I sin Ω, −sin I cos Ω, cos I). For the Moon its
// orbit around Earth is not in Astro.js: null.
function orbitNormal(body, utcMs) {
  var el = Astro.elementsAt(body, Astro.julianCenturies(utcMs === undefined ? J2000_MS : utcMs))
  if (!el) return null
  var I = el.I * RAD, O = el.node * RAD
  return vec(Math.sin(I) * Math.sin(O), -Math.sin(I) * Math.cos(O), Math.cos(I))
}

// The obliquity (axial tilt) in degrees: the angle between the spin axis
// (right-hand rule) and the orbit's normal, so Venus 177.4° and Uranus
// 97.8°. The Sun and the Moon: against the ecliptic's pole (7.25°, 1.54°).
function obliquityOf(body, utcMs) {
  var at = utcMs === undefined ? J2000_MS : utcMs
  var pole = spinPoleVector(body, at)
  if (!pole) return NaN
  var normal = body === "sun" || body === "moon" ? vec(0, 0, 1) : orbitNormal(body, at)
  return normal ? angleBetween(pole, normal) : NaN
}

// ---- Body-fixed frames ----

// The rotation taking body-fixed coordinates (x through the prime meridian
// on the equator, z the IAU north pole, y = z × x, east) to the ecliptic
// J2000, as a flat row-major 3×3 matrix M: v_ecliptic = M · v_body.
//   - IAU bodies: the equator's ascending node on the ICRF equator lies at
//     right ascension α0 + 90°; the prime meridian is W east of it.
//   - Earth: the true sidereal motion instead of the IAU's W. The mean
//     equator of date turns by the Greenwich mean sidereal time from the
//     equinox of date; that frame goes to the ecliptic of date by the
//     obliquity and back to the J2000 ecliptic by the general precession
//     in longitude (Astro.precession, the same as Astro.earthLonFor). The
//     small motion of the ecliptic itself (0.013° a century) is left out.
function bodyMatrix(body, utcMs) {
  if (body === "earth") {
    var g = gmst(utcMs) * RAD
    var eps = OBLIQUITY_J2000 * RAD
    var p = -Astro.precession(Astro.julianCenturies(utcMs)) * RAD
    // Rz(p) · Rx(−ε) · Rz(GMST), applied to the body axes.
    var axes = [vec(Math.cos(g), Math.sin(g), 0), vec(-Math.sin(g), Math.cos(g), 0), vec(0, 0, 1)]
    var out = []
    for (var i = 0; i < 3; i++) {
      var a = axes[i]
      // equatorial of date → ecliptic of date
      var e = vec(a.x, a.y * Math.cos(eps) + a.z * Math.sin(eps), -a.y * Math.sin(eps) + a.z * Math.cos(eps))
      // ecliptic of date → ecliptic J2000 (longitudes back by the precession)
      out.push(vec(e.x * Math.cos(p) - e.y * Math.sin(p), e.x * Math.sin(p) + e.y * Math.cos(p), e.z))
    }
    return fromColumns(out[0], out[1], out[2])
  }
  var pole = poleRaDec(body, utcMs)
  if (!pole) return null
  var W = primeMeridian(body, utcMs) * RAD
  var a0 = pole.ra * RAD
  // Equatorial (ICRF) axes of the body's equator: node, then 90° on.
  var node = vec(Math.cos(a0 + Math.PI / 2), Math.sin(a0 + Math.PI / 2), 0)
  var z = fromSpherical(pole.ra, pole.dec)
  var y0 = cross(z, node)
  var x = vec(node.x * Math.cos(W) + y0.x * Math.sin(W), node.y * Math.cos(W) + y0.y * Math.sin(W), node.z * Math.cos(W) + y0.z * Math.sin(W))
  var y = cross(z, x)
  return fromColumns(equatorialToEcliptic(x), equatorialToEcliptic(y), equatorialToEcliptic(z))
}

// The point of a body's surface under a direction (unit or not, ecliptic
// J2000) at a moment: { lat, lon } in degrees, planetocentric on a sphere,
// longitude east-positive in −180…180. Sub-observer point: the direction
// towards the observer; sub-solar point: towards the Sun.
function subPoint(body, direction, utcMs) {
  var m = bodyMatrix(body, utcMs)
  if (!m) return null
  var s = toSpherical(applyTransposed(m, direction))
  return { lat: s.lat, lon: wrap180(s.lon) }
}

// A body-fixed point { lat, lon } (degrees, east) as a unit vector in the
// ecliptic J2000.
function surfaceVector(body, lat, lon, utcMs) {
  var m = bodyMatrix(body, utcMs)
  return m ? apply(m, fromSpherical(lon, lat)) : null
}

// ---- Drawing a body as a globe in the Astro view ----

// The camera's axes in the ecliptic J2000 for an AstroView.camera(azimuth,
// elevation) object: right, up and towards the viewer, the same as
// AstroView.view (x right, y up, depth towards the viewer).
function cameraAxes(cam) {
  return {
    right: vec(cam.ca, cam.sa, 0),
    up: vec(-cam.sa * cam.se, cam.ca * cam.se, cam.ce),
    toward: vec(cam.sa * cam.ce, -cam.ca * cam.ce, cam.se)
  }
}

// The view matrix for Globe.projectView and friends: rows are the camera's
// right, up and towards-the-viewer axes in body-fixed coordinates, so a
// body-fixed unit vector v projects to (row0·v, row1·v) with row2·v ≥ 0 on
// the front, exactly as Globe.viewMatrix(lat, lon) does for a view from
// above (lat, lon). m: bodyMatrix(...); axes: cameraAxes(...).
function bodyViewMatrix(m, axes) {
  var r = applyTransposed(m, axes.right)
  var u = applyTransposed(m, axes.up)
  var t = applyTransposed(m, axes.toward)
  return [r.x, r.y, r.z, u.x, u.y, u.z, t.x, t.y, t.z]
}

// ---- Saturn's rings ----

// The ring plane's normal: Saturn's equator (IAU north pole).
function ringPlaneNormal(body, utcMs) {
  return body === "saturn" ? poleVector("saturn", utcMs === undefined ? J2000_MS : utcMs) : null
}

// Saturn's equatorial radius (1 bar) and ring edges in km, NASA NSSDCA
// Saturnian Rings Fact Sheet
// (https://nssdc.gsfc.nasa.gov/planetary/factsheet/satringfact.html, last
// updated 19 April 2022, retrieved 2026-10-03). RING_RADII are the edges in
// units of the equatorial radius (not Astro.RADIUS_KM.saturn, the mean
// radius 58232 km): C inner 74 658, C outer = B inner 91 975, B outer
// 117 507, Cassini division, A inner 122 340, A outer 136 780 km.
var SATURN_EQUATORIAL_RADIUS_KM = 60268
var RING_EDGES_KM = { cInner: 74658, cOuter: 91975, bInner: 91975, bOuter: 117507, aInner: 122340, aOuter: 136780 }
var RING_RADII = (function() {
  var out = {}
  for (var k in RING_EDGES_KM) out[k] = RING_EDGES_KM[k] / SATURN_EQUATORIAL_RADIUS_KM
  return out
})()

if (typeof module !== "undefined") module.exports = {
  J2000_MS: J2000_MS, OBLIQUITY_J2000: OBLIQUITY_J2000, TT_MINUS_UTC_S: TT_MINUS_UTC_S, IAU: IAU, BODIES: BODIES,
  daysUT: daysUT, daysTT: daysTT, gmst: gmst, earthRotationAngle: earthRotationAngle,
  fromSpherical: fromSpherical, toSpherical: toSpherical, dot: dot, cross: cross, norm: norm, angleBetween: angleBetween,
  eclipticToEquatorial: eclipticToEquatorial, equatorialToEcliptic: equatorialToEcliptic, apply: apply, applyTransposed: applyTransposed,
  poleRaDec: poleRaDec, poleVector: poleVector, spinPoleVector: spinPoleVector, primeMeridian: primeMeridian,
  rotationPeriodHours: rotationPeriodHours, orbitNormal: orbitNormal, obliquityOf: obliquityOf,
  bodyMatrix: bodyMatrix, subPoint: subPoint, surfaceVector: surfaceVector, cameraAxes: cameraAxes, bodyViewMatrix: bodyViewMatrix,
  ringPlaneNormal: ringPlaneNormal, SATURN_EQUATORIAL_RADIUS_KM: SATURN_EQUATORIAL_RADIUS_KM, RING_EDGES_KM: RING_EDGES_KM, RING_RADII: RING_RADII
}
