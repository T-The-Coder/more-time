// AstroIss.js: the ISS's TLE read and checked, SGP4 against Spacetrack
// Report #3's test case and against the ISS's place from a second source.
import { test } from "node:test"
import assert from "node:assert"
import { readFileSync } from "node:fs"
import { join } from "node:path"
import { load, root } from "./load.mjs"

const I = load("AstroIss.js")
const fixture = JSON.parse(readFileSync(join(root, "tests/fixtures/iss-tle.json"), "utf8"))
const near = (a, b, eps, what = "") => assert.ok(Math.abs(a - b) <= eps, `${what} ${a} != ${b} (±${eps})`)

test("TLE: checksums, implied decimals, the catalogue number", () => {
  const [, l1, l2] = fixture.tle.split("\n")
  assert.equal(I.checksum(l1), 5)
  assert.equal(I.checksum(l2), 1)
  near(I.impliedDecimal(" 98343-4"), 0.98343e-4, 1e-12)
  near(I.impliedDecimal("-11606-4"), -0.11606e-4, 1e-12)
  assert.equal(I.impliedDecimal(" 00000+0"), 0)
  const el = I.parseTle(fixture.tle, 25544)
  assert.equal(el.error, undefined)
  assert.equal(el.catalog, 25544)
  // Epoch 26278.04655461: day 278 of 2026 (5 October) at 01:07:02.318 UTC.
  assert.equal(new Date(el.epochMs).toISOString(), "2026-10-05T01:07:02.318Z")
  near(el.ecco, 0.0006856, 1e-12)
  near(el.inclo * 180 / Math.PI, 51.6316, 1e-9)
  // A wrong digit, another satellite, a truncated line: refused.
  assert.equal(I.parseTle(fixture.tle.replace("51.6316", "51.6317"), 25544).error, "checksum")
  assert.equal(I.parseTle(fixture.tle, 20580).error, "catalog")
  assert.equal(I.parseTle(l1 + "\n" + l2.slice(0, 50)).error, "format")
  assert.equal(I.parseTle("<html>error</html>").error, "format")
})

test("SGP4: Spacetrack Report #3's near-Earth test case (88888)", () => {
  // Hoots & Roehrich, Spacetrack Report #3 (1980), test TLE for SGP4; the
  // expected TEME positions and velocities are those of Vallado et al.,
  // "Revisiting Spacetrack Report #3" (AIAA 2006-6753), tcppver.out: at 0
  // and 360 minutes, to the metre.
  const pad = (l) => { l = l.padEnd(69, " ").slice(0, 68); return l + I.checksum(l) }
  const el = I.parseTle(pad("1 88888U          80275.98708465  .00073094  13844-3  66816-4 0    8") + "\n"
    + pad("2 88888  72.8435 115.9689 0086731  52.6988 110.5714 16.05824518   105"))
  assert.equal(el.error, undefined)
  const s = I.init(el)
  const expected = [
    [0, [2328.96975262, -5995.22051338, 1719.97297192], [2.91207225, -0.98341535, -7.09081703]],
    [360, [2456.10706533, -6071.93855503, 1222.89768554], [2.67938906, -0.44829101, -7.22879259]]
  ]
  for (const [t, r, v] of expected) {
    const pv = I.propagate(s, t)
    for (let k = 0; k < 3; k++) {
      near(pv.r[k], r[k], 0.01, `r${k} at ${t} min`)
      near(pv.v[k], v[k], 1e-5, `v${k} at ${t} min`)
    }
  }
})

test("SGP4: the ISS where api.wheretheiss.at puts it, within a kilometre", () => {
  const el = I.parseTle(fixture.tle, 25544)
  const rad = Math.PI / 180
  for (const p of fixture.positions) {
    const s = I.stationAt(el, p.timestamp * 1000)
    const cosd = Math.sin(p.latitude * rad) * Math.sin(s.lat * rad)
      + Math.cos(p.latitude * rad) * Math.cos(s.lat * rad) * Math.cos((p.longitude - s.lon) * rad)
    const km = Math.acos(Math.min(1, cosd)) * (6371 + p.altitude)
    assert.ok(km < 1, `${p.timestamp}: ${km.toFixed(2)} km apart`)
    near(s.altitude, p.altitude, 0.5, "altitude")
    near(s.periodMinutes, 1440 / 15.48738655, 0.2, "period")
  }
  // One orbit's ground track: back near the start after a period, shifted
  // west by the Earth's turn (about 23°).
  const track = I.groundTrack(el, fixture.positions[0].timestamp * 1000, 96)
  assert.equal(track.length, 97)
  near(track[96].lat, track[0].lat, 1, "latitude after one orbit")
  near(((track[0].lon - track[96].lon) + 540) % 360 - 180, 23, 2, "westward shift")
})
