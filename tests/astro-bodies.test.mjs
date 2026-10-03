// AstroBodies.js: dwarf planets, Halley, the belts, the large moons and the
// spacecraft, held to JPL Horizons positions fetched on 2026-10-03
// (tests/fixtures/astro-horizons.json, which names each solution).
import { test } from "node:test"
import assert from "node:assert"
import { readFileSync } from "node:fs"
import { join } from "node:path"
import { load, root } from "./load.mjs"

const B = load("AstroBodies.js")
const A = B.Astro
const R = B.AstroRotation
const H = JSON.parse(readFileSync(join(root, "tests/fixtures/astro-horizons.json"), "utf8"))
const DAY = 86400000
const near = (a, b, eps, what = "") => assert.ok(Math.abs(a - b) <= eps, `${what} ${a} != ${b} (±${eps})`)
const msOfJd = (jd) => (jd - 2440587.5) * DAY
const vecOf = (row) => ({ x: row[1], y: row[2], z: row[3] })
const len = (p) => Math.hypot(p.x, p.y, p.z)

test("dwarf planets and Halley: two-body orbits against Horizons, 2016–2036", () => {
  // The stated errors over ±10 years: direction (degrees) and distance (au).
  const bounds = { ceres: [0.7, 0.02], pluto: [0.1, 0.06], eris: [0.01, 0.04], halley: [0.06, 0.02] }
  for (const body of B.SMALL_BODY_KEYS) {
    for (const row of H.heliocentric[body]) {
      const p = B.position(body, msOfJd(row[0]))
      const h = vecOf(row)
      near(R.angleBetween(p, h), 0, bounds[body][0], `${body} ${row[0]} direction`)
      near(p.r, len(h), bounds[body][1], `${body} ${row[0]} distance`)
      near(Math.hypot(p.x, p.y, p.z), p.r, 1e-12)
    }
  }
  // Periods: Ceres 4.6 years, Pluto 249, Eris 560, Halley 75.5.
  near(B.periodDays("ceres") / 365.25, 4.60, 0.01)
  near(B.periodDays("pluto") / 365.25, 249, 1)
  near(B.periodDays("eris") / 365.25, 560, 2)
  near(B.periodDays("halley") / 365.25, 75.5, 0.5)
})

test("Halley: perihelion in July 2061 inside Venus' orbit, the tail away from the Sun", () => {
  // JPL#75 gives perihelion JD 2474050.62 (2061-07-28) at q = 0.572 au.
  let best = { t: 0, r: Infinity }
  for (let t = Date.UTC(2061, 5, 1); t < Date.UTC(2061, 8, 30); t += DAY / 4) {
    const r = B.position("halley", t).r
    if (r < best.r) best = { t, r }
  }
  near(best.t, msOfJd(2474050.62), 1 * DAY, "perihelion")
  near(best.r, 0.5722, 0.001, "q")
  // Retrograde: inclination over 90°, so its longitude falls near perihelion.
  const a = B.position("halley", best.t - 10 * DAY), b = B.position("halley", best.t + 10 * DAY)
  assert.ok(((b.lon - a.lon + 540) % 360) - 180 < 0, "moves backwards")
  const p = B.position("halley", Date.UTC(2026, 9, 3))
  const tail = B.tailDirection(p)
  near(len(tail), 1, 1e-12)
  near(R.angleBetween(tail, p), 0, 1e-9, "anti-solar")
  // The orbit holds its own positions.
  const orbit = B.orbit("halley", 720)
  const nearest = Math.min(...orbit.map((q) => A.distance(p, q)))
  assert.ok(nearest < 0.2, `on its orbit ${nearest}`)
})

test("belts: stable, in their ranges, each point on its Kepler orbit", () => {
  const t = Date.UTC(2026, 9, 3)
  const a = B.beltPoints("asteroids", t, 400)
  const b = B.beltPoints("asteroids", t, 400)
  assert.equal(a.length, 400)
  assert.deepEqual(a, b, "same seed, same points")
  // A shorter list is the start of the longer one.
  assert.deepEqual(B.beltPoints("asteroids", t, 50), a.slice(0, 50))
  for (const name of ["asteroids", "kuiper"]) {
    const belt = B.BELTS[name]
    for (const el of B.beltElements(name, 300)) {
      assert.ok(el.a >= belt.aMin && el.a <= belt.aMax && el.e >= 0 && el.e <= belt.eMax && el.I >= 0 && el.I <= belt.iMax)
      near(el.periodDays, 365.25 * Math.pow(el.a, 1.5), 1e-9)
    }
    for (const p of B.beltPoints(name, t, 300)) {
      const r = len(p)
      assert.ok(r >= belt.aMin * (1 - belt.eMax) - 1e-9 && r <= belt.aMax * (1 + belt.eMax) + 1e-9, `${name} r ${r}`)
    }
  }
  // After one of its own periods every point is back where it was.
  const el = B.beltElements("asteroids", 1)[0]
  const p0 = B.beltPoints("asteroids", t, 1)[0]
  const p1 = B.beltPoints("asteroids", t + el.periodDays * DAY, 1)[0]
  near(A.distance(p0, p1), 0, 1e-6, "periodic")
  // Inner points move faster: over 30 days the asteroids turn more than
  // the Kuiper belt.
  const turn = (name) => {
    const before = B.beltPoints(name, t, 100), after = B.beltPoints(name, t + 30 * DAY, 100)
    return before.reduce((s, p, i) => s + R.angleBetween(p, after[i]), 0) / 100
  }
  assert.ok(turn("asteroids") > 10 * turn("kuiper"))
  assert.deepEqual(B.beltPoints("nowhere", t, 10), [])
})

test("the large moons: their places against Horizons, their periods", () => {
  // Circles in the Laplace plane: Io, Europa, Ganymede and Callisto within
  // 1.5° (resonant librations, eccentricity), Titan within 3.5° (its
  // eccentricity 0.029 alone shifts it up to 3.3°); the radius is the
  // mean distance, within 3 %.
  const bounds = { io: 1.5, europa: 1.5, ganymede: 1.5, callisto: 1.5, titan: 3.5 }
  for (const key of B.MOON_KEYS) {
    for (const row of H.moons[key]) {
      const p = B.moonPosition(key, msOfJd(row[0]))
      assert.equal(p.phaseKnown, true)
      near(R.angleBetween(p, vecOf(row)), 0, bounds[key], `${key} ${row[0]}`)
      near(len(p) / len(vecOf(row)), 1, 0.035, `${key} radius`)
    }
  }
  // Sidereal periods (days): Io 1.769, Europa 3.551, Ganymede 7.155,
  // Callisto 16.689, Titan 15.945.
  near(B.moonPeriodDays("io"), 1.769, 0.001)
  near(B.moonPeriodDays("europa"), 3.551, 0.001)
  near(B.moonPeriodDays("ganymede"), 7.155, 0.001)
  near(B.moonPeriodDays("callisto"), 16.689, 0.001)
  near(B.moonPeriodDays("titan"), 15.945, 0.001)
  // Each in its plane: perpendicular to the Laplace pole, which lies
  // within a degree of the planet's IAU pole.
  const t = Date.UTC(2026, 9, 3)
  for (const key of B.MOON_KEYS) {
    const p = B.moonPosition(key, t)
    near(R.dot(R.norm(p), B.moonOrbitNormal(key)), 0, 1e-12)
    near(R.angleBetween(B.moonOrbitNormal(key), R.poleVector(p.planet, t)), 0, 1, `${key} plane`)
  }
  assert.equal(B.moonPosition("phobos", t), null)
})

test("spacecraft: straight lines from Horizons' 2026 state, JWST at L2", () => {
  const bounds = { voyager1: [0.02, 0.12], voyager2: [0.02, 0.12], newhorizons: [0.12, 0.75] }
  for (const key of ["voyager1", "voyager2", "newhorizons"]) {
    for (const row of H.heliocentric[key]) {
      const p = B.spacecraftPosition(key, msOfJd(row[0]))
      near(R.angleBetween(p, vecOf(row)), 0, bounds[key][0], `${key} ${row[0]} direction`)
      near(p.r, len(vecOf(row)), bounds[key][1], `${key} ${row[0]} distance`)
    }
  }
  // Early October 2026: Voyager 1 about 172 au out at 3.6 au a year, high
  // in the north (ecliptic latitude 35°); Voyager 2 144 au, far south.
  const v1 = B.spacecraftPosition("voyager1", Date.UTC(2026, 9, 3))
  near(v1.r, 171.94, 0.05); near(v1.speed, 3.57, 0.05); near(v1.lat, 35.2, 0.2)
  const v2 = B.spacecraftPosition("voyager2", Date.UTC(2026, 9, 3))
  near(v2.r, 144.10, 0.05); assert.ok(v2.lat < -38)
  // JWST: 0.01 au beyond Earth, on the Sun–Earth line.
  const t = Date.UTC(2026, 9, 3)
  const earth = A.position("earth", t)
  const jwst = B.spacecraftPosition("jwst", t)
  near(A.distance(jwst, earth), 0.01 * earth.r, 1e-12)
  near(R.angleBetween(jwst, earth), 0, 1e-9)
  assert.equal(B.spacecraftPosition("pioneer10", t), null)
})
