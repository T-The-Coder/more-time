// AstroAlmanac.js: the merged list of sky events against published moments.
import { test } from "node:test"
import assert from "node:assert"
import { readFileSync } from "node:fs"
import { join } from "node:path"
import { load, root } from "./load.mjs"

const A = load("AstroAlmanac.js")
const Ecl = A.AstroEclipses
const Ev = A.AstroEvents
for (const c of Ecl.chunksFor(Date.UTC(2015, 0, 1), Date.UTC(2030, 0, 1)))
  Ecl.addChunk(JSON.parse(readFileSync(join(root, "data", c.file), "utf8")))
const DAY = 86400000
const HOUR = 3600000
const near = (a, b, eps, what = "") => assert.ok(Math.abs(a - b) <= eps, `${what} ${new Date(a).toISOString()} != ${new Date(b).toISOString()} (±${eps / HOUR} h)`)
const year = (y) => A.events(Date.UTC(y, 0, 1), Date.UTC(y + 1, 0, 1))
const of = (list, kind, ...bodies) => list.filter((e) => e.kind === kind && bodies.every((b) => e.bodies.includes(b)))

// Wikipedia, "Great conjunction" (https://en.wikipedia.org/wiki/Great_conjunction,
// retrieved 2026-10-05): closest on 21 December 2020 at 18:20 UTC, 6.1′.
// Astro.js puts it 10 h later (its Saturn is good to a few arcminutes, and
// the two close at only 0.02° a day near the minimum) at 6.0′.
test("the 2020 Jupiter–Saturn great conjunction", () => {
  const list = of(year(2020), "planetConjunction", "jupiter", "saturn")
  assert.equal(list.length, 1)
  near(list[0].utcMs, Date.UTC(2020, 11, 21, 18, 20), 12 * HOUR)
  assert.ok(Math.abs(list[0].detail.separation - 6.1 / 60) < 0.02, `${list[0].detail.separation}`)
})

// Venus' greatest elongations in 2025: east on 10 January (47.2°), west on
// 1 June at about 04 UTC (46°). EarthSky, https://earthsky.org/?p=384305
// and https://earthsky.org/?p=379683; Star Walk's 2025 calendar,
// https://starwalk.space/en/news/astronomy-calendar-2025 (retrieved
// 2026-10-05).
test("Venus' greatest elongations 2025", () => {
  const list = of(year(2025), "greatestElongation", "venus")
  assert.equal(list.length, 2)
  near(list[0].utcMs, Date.UTC(2025, 0, 10, 12), DAY, "east")
  assert.equal(list[0].detail.side, "east")
  assert.ok(Math.abs(list[0].detail.angle - 47.2) < 0.2)
  near(list[1].utcMs, Date.UTC(2025, 5, 1, 4), DAY, "west")
  assert.equal(list[1].detail.side, "west")
  assert.ok(Math.abs(list[1].detail.angle - 45.9) < 0.2)
})

// USNO, Earth's seasons and apsides (https://aa.usno.navy.mil/api/seasons?year=2025
// and year=2026, retrieved 2026-10-05): perihelion 2025-01-04 13:28,
// 2026-01-03 17:15; aphelion 2025-07-03 19:55, 2026-07-06 17:30 UTC. The
// perihelion is flat (the distance changes by 1 km in an hour there), so
// the Moon's pull and Astro.js's elements move it by up to 2.5 hours.
test("perihelion and aphelion against the USNO", () => {
  const cases = [[2025, "perihelion", Date.UTC(2025, 0, 4, 13, 28)], [2025, "aphelion", Date.UTC(2025, 6, 3, 19, 55)],
    [2026, "perihelion", Date.UTC(2026, 0, 3, 17, 15)], [2026, "aphelion", Date.UTC(2026, 6, 6, 17, 30)]]
  for (const [y, kind, ms] of cases) {
    const list = of(year(y), kind)
    assert.equal(list.length, 1, `${y} ${kind}`)
    near(list[0].utcMs, ms, 3 * HOUR, `${y} ${kind}`)
  }
})

test("seasons, phases, oppositions agree with Astro.js and AstroEvents", () => {
  const list = year(2026)
  const seasons = of(list, "season")
  assert.deepEqual(seasons.map((e) => e.detail.key), ["marchEquinox", "juneSolstice", "septemberEquinox", "decemberSolstice"])
  const marks = A.Astro.seasonMarks(2026).seasons
  seasons.forEach((e, i) => assert.equal(e.utcMs, marks[i].utcMs))
  // New and full moons as AstroEvents.nextPhase finds them (within its
  // own bisection) and so within 45 minutes of the USNO's.
  for (const e of of(list, "moonPhase").filter((x) => x.detail.phase === "new" || x.detail.phase === "full")) {
    const t = Ev.nextPhase(e.utcMs - 2 * DAY, e.detail.phase === "new" ? 0 : 0.5)
    near(e.utcMs, t, 60000, e.detail.phase)
  }
  // The USNO's first quarter 2026-01-26 04:47 and last quarter 2026-01-10 15:48.
  const quarters = of(list, "moonPhase").filter((x) => x.detail.phase.endsWith("Quarter"))
  near(quarters.find((e) => e.detail.phase === "firstQuarter").utcMs, Date.UTC(2026, 0, 26, 4, 47), 45 * 60000, "first quarter")
  near(quarters.find((e) => e.detail.phase === "lastQuarter").utcMs, Date.UTC(2026, 0, 10, 15, 48), 45 * 60000, "last quarter")
  for (const e of of(list, "opposition")) near(e.utcMs, Ev.nextOpposition(e.bodies[0], e.utcMs - 30 * DAY), 2 * 60000, e.bodies[0])
  for (const e of of(list, "conjunction").filter((x) => Ev.OUTER_PLANETS.includes(x.bodies[0])))
    near(e.utcMs, Ev.nextConjunction(e.bodies[0], e.utcMs - 30 * DAY), 2 * 60000, e.bodies[0])
  // Jupiter at opposition on 10 January 2026 (in-the-sky.org, EarthSky).
  near(of(list, "opposition", "jupiter")[0].utcMs, Date.UTC(2026, 0, 10, 8), 12 * HOUR, "Jupiter")
  // Mars' opposition of 16 January 2025 (02:38 UTC per in-the-sky.org).
  near(of(year(2025), "opposition", "mars")[0].utcMs, Date.UTC(2025, 0, 16, 2, 38), 3 * HOUR, "Mars")
  // The eclipses of 2026 from the catalogue.
  assert.deepEqual(of(list, "eclipse").map((e) => e.detail.eclipseKind + " " + e.detail.type),
    ["solar annular", "lunar total", "solar total", "lunar partial"])
  // Sorted.
  for (let i = 1; i < list.length; i++) assert.ok(list[i].utcMs >= list[i - 1].utcMs)
})

test("counts per year are sane", () => {
  for (let y = 2016; y <= 2029; y++) {
    const list = year(y)
    const n = (kind) => of(list, kind).length
    assert.equal(n("season"), 4, `${y}`)
    assert.equal(n("perihelion"), 1, `${y}`)
    assert.equal(n("aphelion"), 1, `${y}`)
    assert.ok(n("moonPhase") >= 48 && n("moonPhase") <= 51, `${y} phases ${n("moonPhase")}`)
    assert.ok(n("eclipse") >= 4 && n("eclipse") <= 7, `${y} eclipses`)
    // Mars every other year, Jupiter, Saturn, Uranus, Neptune every year
    // (Jupiter's 13-month cycle can skip a calendar year).
    assert.ok(n("opposition") >= 3 && n("opposition") <= 5, `${y} oppositions ${n("opposition")}`)
    // Mercury 6–7, Venus 0–2.
    assert.ok(n("greatestElongation") >= 6 && n("greatestElongation") <= 9, `${y} elongations ${n("greatestElongation")}`)
    const mercury = of(list, "greatestElongation", "mercury").length
    assert.ok(mercury >= 5 && mercury <= 7, `${y} Mercury ${mercury}`)
    assert.ok(n("conjunction") >= 8 && n("conjunction") <= 16, `${y} conjunctions ${n("conjunction")}`)
    assert.ok(of(list, "planetConjunction").every((e) => e.detail.separation < 2))
  }
})

test("options, nearest, and the cost of a year", () => {
  const only = A.events(Date.UTC(2026, 0, 1), Date.UTC(2027, 0, 1), { kinds: ["season", "eclipse"] })
  assert.equal(only.length, 8)
  const wide = A.events(Date.UTC(2026, 0, 1), Date.UTC(2027, 0, 1), { kinds: ["planetConjunction"], maxSeparation: 5 })
  assert.ok(wide.length > of(year(2026), "planetConjunction").length)
  const at = Date.UTC(2026, 9, 5)
  const n = A.nearest(at, 4)
  assert.equal(n.previous.length, 4)
  assert.equal(n.next.length, 4)
  assert.ok(n.previous.every((e) => e.utcMs < at) && n.next.every((e) => e.utcMs >= at))
  assert.ok(n.previous[3].utcMs >= n.previous[0].utcMs)
  year(2024) // warm up
  const t = performance.now()
  year(2027)
  const ms = performance.now() - t
  assert.ok(ms < 100, `a year took ${ms} ms`)
})
