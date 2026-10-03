// AstroRotation.js: sidereal time, frames and the IAU rotation model. The
// references are published values (Meeus' worked example, the IAU 2009
// tables, the axial tilts on Wikipedia's "Axial tilt" page) and JPL
// Horizons' sub-observer points (tests/fixtures/astro-horizons.json).
import { test } from "node:test"
import assert from "node:assert"
import { readFileSync } from "node:fs"
import { join } from "node:path"
import { load, root } from "./load.mjs"

const R = load("AstroRotation.js")
const A = R.Astro
const S = load("Sky.js")
const V = load("AstroView.js")
const G = load("Globe.js")
const E = load("AstroEvents.js")
const H = JSON.parse(readFileSync(join(root, "tests/fixtures/astro-horizons.json"), "utf8"))
const RAD = Math.PI / 180
const DAY = 86400000
const near = (a, b, eps, what = "") => assert.ok(Math.abs(a - b) <= eps, `${what} ${a} != ${b} (±${eps})`)
const angle = (a, b) => ((a - b) % 360 + 540) % 360 - 180
const MONTHS = { Jan: 0, Feb: 1, Mar: 2, Apr: 3, May: 4, Jun: 5, Jul: 6, Aug: 7, Sep: 8, Oct: 9, Nov: 10, Dec: 11 }
const horizonsDate = (s) => {
  const m = s.match(/(\d+)-(\w+)-(\d+) (\d+):(\d+)/)
  return Date.UTC(+m[1], MONTHS[m[2]], +m[3], +m[4], +m[5])
}

test("GMST: J2000.0 and Meeus' example 12.a", () => {
  near(R.gmst(Date.UTC(2000, 0, 1, 12)), 280.46061837, 1e-8, "J2000")
  // Meeus, Astronomical Algorithms, example 12.a: 1987 April 10, 0h UT,
  // mean sidereal time 13h 10m 46.3668s.
  near(R.gmst(Date.UTC(1987, 3, 10)), (13 + 10 / 60 + 46.3668 / 3600) * 15, 1e-5, "1987-04-10")
  // A sidereal day later the same angle; a solar day later ~0.9856° on.
  const t = Date.UTC(2026, 9, 3, 7)
  near(angle(R.gmst(t + DAY), R.gmst(t)), 0.98564736629, 1e-6, "a day on")
})

test("Earth rotation angle: J2000 value, and GMST runs ahead by the precession", () => {
  near(R.earthRotationAngle(Date.UTC(2000, 0, 1, 12)), 0.7790572732640 * 360, 1e-9)
  // GMST − ERA is the accumulated precession in right ascension (about
  // 4612″ a century → 0.33° by 2026), within a hundredth of a degree.
  const t = Date.UTC(2026, 9, 3)
  const T = A.julianCenturies(t)
  near(angle(R.gmst(t), R.earthRotationAngle(t)), 4612.16 / 3600 * T, 0.01, "GMST − ERA")
})

test("frames: ecliptic ↔ equatorial round trip, and the poles", () => {
  const v = R.norm({ x: 0.3, y: -0.5, z: 0.8 })
  const back = R.equatorialToEcliptic(R.eclipticToEquatorial(v))
  near(back.x, v.x, 1e-15); near(back.y, v.y, 1e-15); near(back.z, v.z, 1e-15)
  // The ecliptic's north pole sits at RA 270°, Dec 90° − ε.
  const pole = R.toSpherical(R.eclipticToEquatorial({ x: 0, y: 0, z: 1 }))
  near(pole.lon, 270, 1e-9); near(pole.lat, 90 - 23.4392911, 1e-9)
  // The vernal point is on both.
  const x = R.eclipticToEquatorial({ x: 1, y: 0, z: 0 })
  near(x.x, 1, 1e-15)
})

test("obliquities from the IAU poles and the JPL orbits", () => {
  // Axial tilts as tabled on https://en.wikipedia.org/wiki/Axial_tilt
  // (IAU 2009 poles; spin axis by the right-hand rule), retrieved
  // 2026-10-03.
  const known = { earth: 23.44, mars: 25.19, jupiter: 3.13, saturn: 26.73, uranus: 97.77, neptune: 28.32, venus: 177.36, mercury: 0.03, sun: 7.25 }
  for (const body in known) near(R.obliquityOf(body), known[body], 0.5, body)
  // The Moon's equator against the ecliptic: 1.54° (Cassini's laws).
  near(R.obliquityOf("moon", Date.UTC(2026, 9, 3)), 1.54, 0.1, "moon")
  // IAU north vs spin: Venus and Uranus turn backwards.
  near(R.angleBetween(R.poleVector("venus"), R.spinPoleVector("venus")), 180, 1e-9)
  near(R.angleBetween(R.poleVector("mars"), R.spinPoleVector("mars")), 0, 1e-9)
})

test("prime meridians and rotation periods", () => {
  // IAU 2009: Mars W = 176.630° + 350.89198226° d, at J2000.0 TT.
  const j2000tt = R.J2000_MS - R.TT_MINUS_UTC_S * 1000
  near(R.primeMeridian("mars", j2000tt), 176.630, 1e-9, "Mars W0")
  near(R.primeMeridian("jupiter", j2000tt), 284.95, 1e-9, "Jupiter W0")
  near(angle(R.primeMeridian("mars", j2000tt + DAY), 176.630 + 350.89198226), 0, 1e-6, "a day on")
  // Sidereal periods: Earth 23.9345 h, Mars 24.6229 h, Jupiter System III
  // 9 h 55 m 29.7 s, Venus −243.02 d, Uranus −17.24 h.
  near(R.rotationPeriodHours("earth"), 23.9345, 1e-4)
  near(R.rotationPeriodHours("mars"), 24.6229, 1e-4)
  near(R.rotationPeriodHours("jupiter"), 9 + 55 / 60 + 29.7 / 3600, 1e-4)
  near(R.rotationPeriodHours("venus") / 24, -243.02, 0.01)
  near(R.rotationPeriodHours("uranus"), -17.24, 0.01)
  assert.ok(Number.isNaN(R.primeMeridian("pluto", 0)), "unknown body")
})

test("body matrices: rotations, z along the pole, x on the prime meridian", () => {
  const t = Date.UTC(2026, 9, 3, 18, 30)
  for (const body of R.BODIES) {
    const m = R.bodyMatrix(body, t)
    const cols = [0, 1, 2].map((i) => ({ x: m[i], y: m[3 + i], z: m[6 + i] }))
    for (let i = 0; i < 3; i++) {
      near(R.dot(cols[i], cols[i]), 1, 1e-12, `${body} unit`)
      for (let j = i + 1; j < 3; j++) near(R.dot(cols[i], cols[j]), 0, 1e-12, `${body} orthogonal`)
    }
    const det = R.dot(cols[0], R.cross(cols[1], cols[2]))
    near(det, 1, 1e-12, `${body} right-handed`)
    // Earth's pole of date is the IAU pole (with its precession terms)
    // to a few hundredths of a degree; the others exactly.
    near(R.angleBetween(cols[2], R.poleVector(body, t)), 0, body === "earth" ? 0.05 : 1e-9, `${body} pole`)
  }
  // The prime meridian moves W: a quarter Mars day later it lies 90° east.
  const m0 = R.bodyMatrix("mars", t)
  const later = R.subPoint("mars", { x: m0[0], y: m0[3], z: m0[6] }, t + R.rotationPeriodHours("mars") * 3600000 / 4)
  near(later.lon, -90, 0.01, "quarter turn")
  near(later.lat, 0, 0.01)
})

test("Earth: the sub-solar point from its rotation matches Sky.subsolarPoint", () => {
  // Sky.js is good to about 0.01°; the gap is the aberration (20″), the
  // nutation (≤ 17″) and the Earth–Moon barycentre (0.002°).
  for (const t of [Date.UTC(2026, 2, 20, 14, 46), Date.UTC(2026, 5, 21, 8, 24), Date.UTC(2026, 9, 3, 17, 30),
    Date.UTC(2010, 11, 5, 3), Date.UTC(2030, 6, 14, 22, 10), Date.UTC(2001, 0, 1)]) {
    const e = A.position("earth", t)
    const sub = R.subPoint("earth", { x: -e.x, y: -e.y, z: -e.z }, t)
    const sky = S.subsolarPoint(t)
    near(sub.lat, sky.lat, 0.15, "lat")
    near(angle(sub.lon, sky.lon), 0, 0.15, "lon")
  }
  // And the night side turns west: six hours later the sub-solar point is
  // 90° further west (less the Sun's day's motion).
  const t = Date.UTC(2026, 9, 3, 12)
  const e = A.position("earth", t)
  const a = R.subPoint("earth", { x: -e.x, y: -e.y, z: -e.z }, t)
  const b = R.subPoint("earth", { x: -e.x, y: -e.y, z: -e.z }, t + DAY / 4)
  near(angle(b.lon, a.lon), -90.25, 0.05, "6 h")
})

test("sub-Earth points of Mars, Jupiter and Saturn against JPL Horizons", () => {
  // Horizons gives planetographic longitudes (west-positive for these
  // three) and planetodetic latitudes; subPoint is planetocentric east, so
  // the latitude goes through the flattening (NAIF pck00010 radii) and the
  // longitude is negated. The planet is taken where the light left it
  // (light time) and turned as it was then. Horizons uses the IAU 2015
  // Mars model and its own Jupiter/Saturn poles: 0.3° holds them all.
  const radii = { mars: [3396.19, 3376.20], jupiter: [71492, 66854], saturn: [60268, 54364] }
  for (const body of ["mars", "jupiter", "saturn"]) {
    const [a, c] = radii[body]
    for (const [date, lonW, latDetic] of H.subObserver[body]) {
      const t = horizonsDate(date)
      const earth = A.position("earth", t)
      let p = A.position(body, t)
      let lt = 0
      for (let k = 0; k < 3; k++) {
        lt = A.distance(p, earth) * 499.004784 * 1000
        p = A.position(body, t - lt)
      }
      const sub = R.subPoint(body, { x: earth.x - p.x, y: earth.y - p.y, z: earth.z - p.z }, t - lt)
      const latCentric = Math.atan(Math.tan(latDetic * RAD) * (c / a) * (c / a)) / RAD
      near(angle(sub.lon, -lonW), 0, 0.3, `${body} ${date} lon`)
      near(sub.lat, latCentric, 0.3, `${body} ${date} lat`)
    }
  }
})

test("the Moon keeps its face to Earth: sub-Earth point within ±8°, as Horizons", () => {
  // Over a month the optical librations swing it by up to about 7° in
  // longitude and 7° in latitude around (0, 0).
  let most = 0
  for (let t = Date.UTC(2026, 0, 1); t < Date.UTC(2026, 1, 1); t += 6 * 3600000) {
    const g = E.moonGeocentric(t)
    const sub = R.subPoint("moon", { x: -g.x, y: -g.y, z: -g.z }, t)
    assert.ok(Math.abs(sub.lon) <= 8 && Math.abs(sub.lat) <= 8, `${new Date(t).toISOString()} ${sub.lon} ${sub.lat}`)
    most = Math.max(most, Math.abs(sub.lon), Math.abs(sub.lat))
  }
  assert.ok(most > 4, "it does librate")
  // Horizons (DE441, east longitudes): within 0.5°.
  for (const [date, lonE, lat] of H.subObserver.moon) {
    const t = horizonsDate(date)
    const g = E.moonGeocentric(t)
    const sub = R.subPoint("moon", { x: -g.x, y: -g.y, z: -g.z }, t)
    near(angle(sub.lon, lonE), 0, 0.5, `${date} lon`)
    near(sub.lat, lat, 0.5, `${date} lat`)
  }
})

test("Saturn's rings: the plane is the equator, the edges in Saturn radii", () => {
  near(R.angleBetween(R.ringPlaneNormal("saturn"), R.poleVector("saturn")), 0, 1e-12)
  assert.equal(R.ringPlaneNormal("jupiter"), null)
  near(R.RING_RADII.cInner, 1.239, 0.001); near(R.RING_RADII.bOuter, 1.950, 0.001)
  near(R.RING_RADII.aInner, 2.030, 0.001); near(R.RING_RADII.aOuter, 2.270, 0.001)
  assert.ok(R.RING_RADII.cInner < R.RING_RADII.cOuter && R.RING_RADII.bOuter < R.RING_RADII.aInner)
  // Seen from Earth the rings were edge-on on 23 March 2025 (ring-plane
  // crossing); the opening angle is the sub-Earth latitude.
  const t = Date.UTC(2025, 2, 23, 12)
  const earth = A.position("earth", t), saturn = A.position("saturn", t)
  const toEarth = R.norm({ x: earth.x - saturn.x, y: earth.y - saturn.y, z: earth.z - saturn.z })
  near(90 - R.angleBetween(toEarth, R.ringPlaneNormal("saturn", t)), 0, 0.3, "edge-on")
})

test("camera axes match AstroView, and a body's view matrix centres the sub-observer point", () => {
  for (const [az, el] of [[0, 30], [47, 10], [-120, 80], [200, 55]]) {
    const cam = V.camera(az, el)
    const ax = R.cameraAxes(cam)
    const p = { x: 0.3, y: -1.2, z: 0.4 }
    const v = V.view(p, cam)
    near(R.dot(p, ax.right), v.x, 1e-12); near(R.dot(p, ax.up), v.y, 1e-12); near(R.dot(p, ax.toward), v.depth, 1e-12)
    near(R.dot(ax.right, ax.up), 0, 1e-12); near(R.dot(R.cross(ax.right, ax.up), ax.toward), 1, 1e-12)
    const t = Date.UTC(2026, 9, 3, 12)
    for (const body of ["earth", "mars", "saturn"]) {
      const m = R.bodyMatrix(body, t)
      const vm = R.bodyViewMatrix(m, ax)
      const sub = R.subPoint(body, ax.toward, t)
      const c = G.projectView(sub.lat, sub.lon, vm, 100)
      near(c.x, 0, 1e-9); near(c.y, 0, 1e-9); assert.ok(c.visible)
      // The north pole leans on screen the way the body's z axis does.
      const n = G.projectView(90, 0, vm, 1)
      const pole = { x: m[2], y: m[5], z: m[8] }
      near(n.x, R.dot(pole, ax.right), 1e-9); near(n.y, R.dot(pole, ax.up), 1e-9)
    }
  }
})
