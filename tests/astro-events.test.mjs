// AstroEvents.js: the Moon's phases and distance, the planets' elongations,
// oppositions and the next season mark, against published moments.
import { test } from "node:test"
import assert from "node:assert"
import { readFileSync } from "node:fs"
import { join } from "node:path"
import { load, root } from "./load.mjs"

const E = load("AstroEvents.js")
const A = E.Astro
const H = JSON.parse(readFileSync(join(root, "tests/fixtures/astro-horizons.json"), "utf8"))
const DAY = 86400000
const MIN = 60000
const RAD = Math.PI / 180
const near = (a, b, eps, what = "") => assert.ok(Math.abs(a - b) <= eps, `${what} ${a} != ${b} (±${eps})`)
const msOfJd = (jd) => (jd - 2440587.5) * DAY

// New and full moons of 2026, UTC, from the US Naval Observatory
// (https://aa.usno.navy.mil/api/moon/phases/year?year=2026, retrieved
// 2026-10-03). Moon.js's truncated series puts them within about half an
// hour; 45 minutes is the tolerance.
const NEW_2026 = [[0, 18, 19, 52], [1, 17, 12, 1], [2, 19, 1, 23], [3, 17, 11, 52], [4, 16, 20, 1], [5, 15, 2, 54],
  [6, 14, 9, 43], [7, 12, 17, 37], [8, 11, 3, 27], [9, 10, 15, 50], [10, 9, 7, 2], [11, 9, 0, 52]]
const FULL_2026 = [[0, 3, 10, 3], [1, 1, 22, 9], [2, 3, 11, 38], [3, 2, 2, 12], [4, 1, 17, 23], [4, 31, 8, 45],
  [5, 29, 23, 56], [6, 29, 14, 36], [7, 28, 4, 18], [8, 26, 16, 49], [9, 26, 4, 12], [10, 24, 14, 53], [11, 24, 1, 28]]
const at = ([m, d, h, min]) => Date.UTC(2026, m, d, h, min)

test("new and full moons 2026 within 45 minutes of the USNO's", () => {
  for (const when of NEW_2026) near(E.nextPhase(at(when) - 5 * DAY, 0), at(when), 45 * MIN, `new ${when}`)
  for (const when of FULL_2026) near(E.nextPhase(at(when) - 5 * DAY, 0.5), at(when), 45 * MIN, `full ${when}`)
  // moonInfo's next new and full are the first after the moment.
  const info = E.moonInfo(Date.UTC(2026, 9, 3))
  near(info.nextNew, Date.UTC(2026, 9, 10, 15, 50), 45 * MIN, "next new")
  near(info.nextFull, Date.UTC(2026, 9, 26, 4, 12), 45 * MIN, "next full")
})

test("moonInfo: phase names, lit fraction, age", () => {
  // At the USNO's moments: full and new by name; first quarter 2026-01-26
  // 04:47 and last quarter 2026-01-10 15:48 half lit.
  const full = E.moonInfo(at(FULL_2026[9]))
  assert.equal(full.key, "full"); assert.ok(full.illuminated > 0.999)
  // Its age: the time since the USNO's new moon of 11 September.
  near(full.ageDays, (at(FULL_2026[9]) - at(NEW_2026[8])) / DAY, 0.05)
  near(full.lastNew, at(NEW_2026[8]), 45 * MIN)
  const fresh = E.moonInfo(at(NEW_2026[9]) + 3 * DAY)
  assert.equal(fresh.key, "waxingCrescent"); near(fresh.ageDays, 3, 0.1)
  const first = E.moonInfo(Date.UTC(2026, 0, 26, 4, 47))
  assert.equal(first.key, "firstQuarter"); near(first.illuminated, 0.5, 0.01)
  const last = E.moonInfo(Date.UTC(2026, 0, 10, 15, 48))
  assert.equal(last.key, "lastQuarter"); near(last.illuminated, 0.5, 0.01); assert.equal(last.waxing, false)
  assert.deepEqual([0, 0.06, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9, 0.97].map(E.phaseKey),
    ["new", "new", "firstQuarter", "waxingGibbous", "full", "waningGibbous", "lastQuarter", "waningCrescent", "new"])
})

test("the Moon's distance and place against Horizons (DE441)", () => {
  for (const row of H.moonGeocentric.rows) {
    const t = msOfJd(row[0]) - 69184
    const km = Math.hypot(row[1], row[2], row[3]) * E.AU_KM
    near(E.moonDistanceKm(t), km, 50, `distance ${row[0]}`)
    const g = E.moonGeocentric(t)
    const c = (g.x * row[1] + g.y * row[2] + g.z * row[3]) / Math.hypot(g.x, g.y, g.z) / Math.hypot(row[1], row[2], row[3])
    near(Math.acos(Math.min(1, c)) / RAD, 0, 0.3, `direction ${row[0]}`)
    near(Math.hypot(g.x, g.y, g.z) * E.AU_KM, g.distanceKm, 1e-6)
  }
  // Perigee and apogee bound it: about 356 400 to 406 700 km.
  for (let t = Date.UTC(2026, 0, 1); t < Date.UTC(2027, 0, 1); t += DAY / 2) {
    const km = E.moonDistanceKm(t)
    assert.ok(km > 356000 && km < 407000, `${km}`)
  }
})

test("elongations and the evening/morning sky against Horizons", () => {
  // Horizons' S-O-T angle, /T (trailing the Sun: evening) or /L (leading:
  // morning). The geometric angle differs from Horizons' apparent one by
  // light time and aberration: within 0.2°.
  H.elongation.dates.forEach((date, i) => {
    const [y, m, d] = date.split("-").map(Number)
    const t = Date.UTC(y, m - 1, d)
    const sky = E.visibility(t)
    for (const planet of E.SKY_PLANETS) {
      const [angle, side] = H.elongation[planet][i]
      const el = E.elongation(planet, t)
      near(el.angle, angle, 0.2, `${planet} ${date}`)
      assert.equal(el.side, side === "T" ? "east" : "west", `${planet} ${date} side`)
      const expected = angle < E.VISIBLE_ELONGATION[planet] ? "none" : (side === "T" ? "evening" : "morning")
      assert.equal(sky[planet], expected, `${planet} ${date}`)
    }
  })
  // 3 October 2026: Mercury and Venus in the evening, Mars, Jupiter and
  // Saturn (at opposition tomorrow) in the morning.
  assert.deepEqual({ ...E.visibility(Date.UTC(2026, 9, 3)) },
    { mercury: "evening", venus: "evening", mars: "morning", jupiter: "morning", saturn: "morning" })
})

test("oppositions as published, conjunctions half a synodic period away", () => {
  // Published opposition moments (UTC): Saturn 4 Oct 2026 (date only),
  // Neptune 26 Sep 2026 02h, Uranus 25 Nov 2026 23h, Jupiter 11 Feb 2027
  // 00:21 (EarthSky, "… at opposition", retrieved 2026-10-03); Jupiter
  // 10 Jan 2026 and Mars 19 Feb 2027 (in-the-sky.org and the Astro.js
  // tests). Geometric longitudes and the Earth–Moon barycentre: within
  // 12 hours, a day for the date-only ones.
  const cases = [
    ["saturn", Date.UTC(2026, 8, 1), Date.UTC(2026, 9, 4, 12), DAY],
    ["neptune", Date.UTC(2026, 6, 1), Date.UTC(2026, 8, 26, 2), DAY / 2],
    ["uranus", Date.UTC(2026, 9, 3), Date.UTC(2026, 10, 25, 23), DAY / 2],
    ["jupiter", Date.UTC(2026, 9, 3), Date.UTC(2027, 1, 11, 0, 21), DAY / 2],
    ["jupiter", Date.UTC(2025, 9, 3), Date.UTC(2026, 0, 10, 12), DAY],
    ["mars", Date.UTC(2026, 9, 3), Date.UTC(2027, 1, 19, 12), DAY]
  ]
  for (const [planet, from, expected, tolerance] of cases) {
    const t = E.nextOpposition(planet, from)
    near(t, expected, tolerance, `${planet} opposition`)
    // Opposite in longitude; the angle itself is 180° less the latitude.
    assert.ok(E.elongation(planet, t).angle > 170, `${planet} opposite the Sun`)
  }
  for (const planet of ["jupiter", "saturn", "uranus", "neptune"]) {
    const opp = E.nextOpposition(planet, Date.UTC(2026, 9, 3))
    const conj = E.nextConjunction(planet, opp)
    const synodic = 1 / (1 / 365.256 - 1 / A.periodDays(planet))
    near((conj - opp) / DAY, synodic / 2, 12, `${planet} conjunction`)
    near(E.elongation(planet, conj).angle, 0, 3, "behind the Sun")
  }
  assert.equal(E.nextOpposition("venus", Date.UTC(2026, 9, 3)), 0)
})

test("the next equinox or solstice", () => {
  // USNO 2026: 20 Mar 14:46, 21 Jun 08:24, 23 Sep 00:05, 21 Dec 20:50.
  const next = E.nextSeasonEvent(Date.UTC(2026, 9, 3))
  assert.equal(next.key, "decemberSolstice")
  near(next.utcMs, Date.UTC(2026, 11, 21, 20, 50), 30 * MIN)
  assert.equal(E.nextSeasonEvent(Date.UTC(2026, 2, 20, 14)).key, "marchEquinox")
  const after = E.nextSeasonEvent(Date.UTC(2026, 11, 22))
  assert.equal(after.key, "marchEquinox")
  assert.equal(new Date(after.utcMs).getUTCFullYear(), 2027)
})
