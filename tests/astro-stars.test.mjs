// AstroStars.js and its data: star places against SIMBAD, the figures, the
// IAU constellation lookup against Roman's (1987) published examples and
// the BSC's own Bayer/Flamsteed constellations, and the Sun's zodiac
// constellation against EarthSky's 2021 list (after Ottewell) and
// Wikipedia's "Zodiac" table.
import { test } from "node:test"
import assert from "node:assert"
import { readFileSync, statSync } from "node:fs"
import { join } from "node:path"
import { load, root } from "./load.mjs"

const S = load("AstroStars.js")
const R = S.AstroRotation
const A = load("Astro.js")
const RAW = JSON.parse(readFileSync(join(root, "data/astro-stars.json"), "utf8"))
const CONS = JSON.parse(readFileSync(join(root, "data/astro-constellations.json"), "utf8"))
const STARS = S.stars(RAW)
const near = (a, b, eps, what = "") => assert.ok(Math.abs(a - b) <= eps, `${what} ${a} != ${b} (±${eps})`)
const DAY = 86400000
const hms = (h, m, s) => (h + m / 60 + s / 3600) * 15
const dms = (sign, d, m, s) => sign * (d + m / 60 + s / 3600)
const byHr = (hr) => STARS.hr.indexOf(hr)

test("data files: sizes and counts", () => {
  assert.ok(statSync(join(root, "data/astro-stars.json")).size < 80 * 1024)
  assert.ok(statSync(join(root, "data/astro-constellations.json")).size < 60 * 1024)
  // The BSC has 1 600–1 650 stars to V = 5.0, plus a few fainter figure stars.
  const toFive = S.countTo(STARS, 5.0)
  assert.ok(toFive > 1550 && toFive < 1700, `to 5.0: ${toFive}`)
  assert.ok(STARS.count >= toFive && STARS.count < toFive + 60)
  assert.equal(CONS.abbr.length, 88)
  assert.equal(new Set(CONS.abbr).size, 88)
  // Brightest first.
  for (let i = 1; i < STARS.count; i++) assert.ok(STARS.mag[i] >= STARS.mag[i - 1])
  assert.ok(RAW.names.length >= 50)
})

// SIMBAD (ICRS, epoch J2000), https://simbad.cds.unistra.fr/simbad/sim-id?Ident=<name>,
// retrieved 2026-10-05. The BSC's J2000 places agree to about an arcsecond.
test("Sirius, Vega, Polaris, Betelgeuse against SIMBAD", () => {
  const cases = [
    ["Sirius", 2491, hms(6, 45, 8.91728), dms(-1, 16, 42, 58.0171), -1.46],
    ["Vega", 7001, hms(18, 36, 56.33635), dms(1, 38, 47, 1.2802), 0.03],
    ["Polaris", 424, hms(2, 31, 49.09456), dms(1, 89, 15, 50.7923), 2.02],
    ["Betelgeuse", 2061, hms(5, 55, 10.30536), dms(1, 7, 24, 25.4304), 0.5]
  ]
  for (const [name, hr, ra, dec, mag] of cases) {
    const i = byHr(hr)
    assert.ok(i >= 0, name)
    near(STARS.dec[i], dec, 0.002, `${name} dec`)
    near(STARS.ra[i] * Math.cos(dec * Math.PI / 180), ra * Math.cos(dec * Math.PI / 180), 0.002, `${name} ra`)
    near(STARS.mag[i], mag, 0.1, `${name} mag`)
    if (name !== "Betelgeuse") assert.equal(STARS.names[i], name)
  }
  // Sirius is the brightest and white, Betelgeuse orange-red.
  assert.equal(STARS.names[0], "Sirius")
  assert.equal(S.COLOR_KEYS[STARS.color[byHr(2061)]], "orange")
  assert.equal(S.COLOR_KEYS[STARS.color[byHr(2491)]], "white")
})

test("ecliptic directions: the vernal point, the celestial pole, Polaris", () => {
  const v = S.eclipticDirection(0, 0)
  near(v.x, 1, 1e-12); near(v.y, 0, 1e-12); near(v.z, 0, 1e-12)
  // The celestial north pole lies at ecliptic longitude 90°, latitude 90° − ε.
  const p = R.toSpherical(S.eclipticDirection(0, 90))
  near(p.lon, 90, 1e-9); near(p.lat, 90 - 23.4392911, 1e-9)
  // RA 90°, Dec ε is on the ecliptic at longitude 90° (the June solstice point… nearly):
  // sin β = sin δ cos ε − cos δ sin ε sin α → β = 0 for δ = ε, α = 90°.
  const s = R.toSpherical(S.eclipticDirection(90, 23.4392911))
  near(s.lat, 0, 1e-9); near(s.lon, 90, 1e-9)
  // The stars() arrays hold the same unit vectors.
  const i = byHr(7001)
  const w = S.eclipticDirection(STARS.ra[i], STARS.dec[i])
  near(STARS.x[i], w.x, 1e-12); near(STARS.z[i], w.z, 1e-12)
  near(STARS.x[i] ** 2 + STARS.y[i] ** 2 + STARS.z[i] ** 2, 1, 1e-12)
})

test("visibleStars and starSize", () => {
  const three = S.visibleStars(STARS, 3)
  assert.ok(three.length > 150 && three.length < 200, `${three.length}`)
  assert.ok(three.every((s) => s.mag <= 3))
  assert.equal(three[0].name, "Sirius")
  assert.ok(S.starSize(-1.46) > S.starSize(0) && S.starSize(0) > S.starSize(5))
  near(S.starSize(5), 0.6, 1e-9)
  assert.ok(S.starSize(-1.46) <= 3.5 && S.starSize(8) >= 0.5)
})

test("figures: Orion's belt, the Big Dipper, all indices valid", () => {
  const ori = S.figureSegments(CONS, "Ori")
  const has = (a, b) => ori.some(([i, j]) => (i === a && j === b) || (i === b && j === a))
  const alnitak = byHr(1948), alnilam = byHr(1903), mintaka = byHr(1852)
  assert.ok(has(alnitak, alnilam), "Alnitak–Alnilam")
  assert.ok(has(alnilam, mintaka), "Alnilam–Mintaka")
  const uma = S.figureSegments(CONS, "UMa").flat()
  for (const hr of [4301, 4295, 4554, 4660, 4905, 5054, 5191]) assert.ok(uma.includes(byHr(hr)), `UMa HR ${hr}`)
  const all = S.allFigures(CONS)
  assert.equal(all.length, 88)
  for (const f of all) {
    assert.ok(f.segments.length > 0, f.abbr)
    for (const [i, j] of f.segments) assert.ok(i >= 0 && i < STARS.count && j >= 0 && j < STARS.count)
  }
  assert.equal(CONS.latin[S.constellationIndex(CONS, "UMa")], "Ursa Major")
  assert.equal(CONS.latin[S.constellationIndex(CONS, "Oph")], "Ophiuchus")
})

// Roman 1987 (CDS VI/42 ReadMe, https://cdsarc.cds.unistra.fr/ftp/VI/42/ReadMe,
// retrieved 2026-10-05): the program's example output, positions for 1950.
test("constellationOf: Roman's examples", () => {
  const ex = [[9, 65, "UMa"], [23.5, -20, "Aqr"], [5.12, 9.12, "Ori"], [9.4555, -19.9, "Hya"],
    [12.8888, 22, "Com"], [15.6687, -12.1234, "Lib"], [19, -40, "CrA"], [6.2222, -81.1234, "Men"]]
  for (const [ra, dec, abbr] of ex) assert.equal(S.constellationOf(CONS, ra * 15, dec, 1950), abbr)
  assert.equal(S.constellationOf(CONS, STARS.ra[0], STARS.dec[0]), "CMa")
  assert.equal(S.constellationOf(CONS, STARS.ra[byHr(424)], STARS.dec[byHr(424)]), "UMi")
  assert.equal(S.constellationOf(CONS, 0, -90), "Oct")
})

test("constellationOf agrees with the named stars' constellations", () => {
  // Constellation of each named star from the IAU-CSN list (column Con),
  // spot-checked here for the zodiac and some far-south and far-north ones.
  const cases = { 2491: "CMa", 7001: "Lyr", 5340: "Boo", 1457: "Tau", 6134: "Sco", 5056: "Vir",
    3982: "Leo", 2990: "Gem", 2943: "CMi", 7557: "Aql", 8728: "PsA", 472: "Eri", 2326: "Car", 4730: "Cru",
    5459: "Cen", 6556: "Oph", 7121: "Sgr", 8322: "Cap", 8232: "Aqr", 617: "Ari", 3449: "Cnc", 5685: "Lib" }
  for (const [hr, abbr] of Object.entries(cases)) {
    const i = byHr(+hr)
    if (i < 0) continue
    assert.equal(S.constellationOf(CONS, STARS.ra[i], STARS.dec[i]), abbr, `HR ${hr}`)
  }
})

test("zodiac boundaries: the table matches the data", () => {
  const found = S.zodiacCrossings(CONS, 0.01)
  assert.equal(found.length, 13)
  for (const z of S.ZODIAC) {
    const f = found.find((x) => x.abbr === z.abbr)
    assert.ok(f, z.abbr)
    near(f.lon, z.lon, 0.011, z.abbr)
  }
  for (let lon = 0.5; lon < 360; lon += 1)
    assert.equal(S.zodiacAt(lon), S.constellationAtEcliptic(CONS, lon, 0), `lon ${lon}`)
})

const sunLon = (ms) => (A.position("earth", ms).lon + 180) % 360

// When the Sun enters each constellation in a year: { abbr: ms }, hourly.
function entries(year) {
  const out = {}
  let last = null
  for (let ms = Date.UTC(year, 0, 1); ms < Date.UTC(year + 1, 0, 1); ms += 3600000) {
    const z = S.zodiacAt(sunLon(ms))
    if (last && z !== last) out[z] = ms
    last = z
  }
  return out
}

// EarthSky, "Sun in zodiac constellations" (2021 dates from Guy Ottewell's
// Astronomical Calendar 2021, IAU boundaries),
// https://earthsky.org/astronomy-essentials/sun-in-zodiac-constellations/,
// and "Sun passes into Gemini": 2021 June 21 at about 15:00 UTC,
// https://earthsky.org/tonight/sun-passes-into-the-constellation-gemini/,
// both retrieved 2026-10-05. The dates agree within a day (Pisces: 11 March
// there, 12 March 08 h here; Ophiuchus: 30 November there, 29 November 23 h
// here), the Gemini moment within the hour.
test("the Sun's entry dates against EarthSky 2021", () => {
  const published = { Cap: [0, 19], Aqr: [1, 16], Psc: [2, 11], Ari: [3, 18], Tau: [4, 14], Gem: [5, 21],
    Cnc: [6, 20], Leo: [7, 10], Vir: [8, 16], Lib: [9, 31], Sco: [10, 23], Oph: [10, 30], Sgr: [11, 18] }
  const found = entries(2021)
  for (const [abbr, [m, d]] of Object.entries(published)) {
    const day = Date.UTC(2021, m, d)
    assert.ok(found[abbr] > day - DAY && found[abbr] < day + 2 * DAY, `${abbr} ${new Date(found[abbr]).toISOString()}`)
  }
  near(found.Gem, Date.UTC(2021, 5, 21, 15), 2 * 3600000, "Gemini 2021")
})

// Wikipedia, "Zodiac" (https://en.wikipedia.org/wiki/Zodiac, retrieved
// 2026-10-05), the table of the Sun's dates in the 13 constellations (IAU
// boundaries, year not stated; its ends differ from EarthSky's by up to a
// day). Checked in the middle of each range, in 2026.
test("the Sun's constellation in the middle of Wikipedia's ranges", () => {
  const ranges = [["Ari", [3, 19], [4, 13]], ["Tau", [4, 14], [5, 19]], ["Gem", [5, 20], [6, 20]],
    ["Cnc", [6, 21], [7, 9]], ["Leo", [7, 10], [8, 15]], ["Vir", [8, 16], [9, 30]], ["Lib", [9, 31], [10, 22]],
    ["Sco", [10, 23], [10, 29]], ["Oph", [10, 30], [11, 17]], ["Sgr", [11, 18], [0, 18]], ["Cap", [0, 19], [1, 15]],
    ["Aqr", [1, 16], [2, 11]], ["Psc", [2, 12], [3, 18]]]
  for (const [abbr, [m1, d1], [m2, d2]] of ranges) {
    const start = Date.UTC(2026, m1, d1)
    let end = Date.UTC(2026, m2, d2 + 1)
    if (end < start) end = Date.UTC(2027, m2, d2 + 1)
    const mid = (start + end) / 2
    assert.equal(S.zodiacAt(sunLon(mid)), abbr, `${abbr} ${new Date(mid).toISOString()}`)
  }
})
