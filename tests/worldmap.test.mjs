import { test } from "node:test"
import assert from "node:assert"
import { readFileSync, statSync } from "node:fs"
import { join } from "node:path"
import { load, root } from "./load.mjs"

const W = load("WorldMap.js")
const file = join(root, "data/worldmap.json")
const data = JSON.parse(readFileSync(file, "utf8"))
const near = (a, b, eps = 1e-9) => assert.ok(Math.abs(a - b) < eps, `${a} != ${b}`)
// Whether a point (lat, lon) lies in a flat-map polygon (projected points),
// by the even-odd rule the map fills with.
const insideFlat = (polygon, lat, lon) => {
  const p = W.project(lat, lon)
  return W.ringContains(polygon.flatMap((q) => [q.x, q.y]), p.x, p.y, 1)
}

test("projection matches tools/build-worldmap.py", () => {
  // Values printed by the Python build's project().
  near(W.project(52.5, 13.4).x, 0.1627644995627186)
  near(W.project(52.5, 13.4).y, 0.9803646718999339)
  near(W.project(40.7, -74).x, -0.9818620901576243)
  near(W.project(0, 180).x, W.X_MAX)
  near(W.project(90, 0).y, W.Y_MAX)
})

test("inverse projection round trips", () => {
  for (const [lat, lon] of [[0, 0], [52.5, 13.4], [-33.9, 151.2], [70, -150]]) {
    const p = W.project(lat, lon)
    const back = W.unproject(p.x, p.y)
    near(back.lat, lat, 1e-6)
    near(back.lon, lon, 1e-6)
  }
  assert.equal(W.unproject(W.X_MAX * 0.99, W.Y_MAX * 0.99), null)
})

test("map data: size, shape, zones", () => {
  assert.ok(statSync(file).size < 400 * 1024)
  assert.equal(data.projection, "equal-earth")
  assert.ok(data.land.length > 100)
  const offsets = data.zones.map(z => z.o)
  for (const o of [0, 60, 330, 345, -210, 840, -720]) assert.ok(offsets.includes(o), `zone ${o}`)
  for (const ring of data.land) assert.equal(ring.length % 2, 0)
})

test("zone lookup on the map", () => {
  const at = (lat, lon) => { const p = W.project(lat, lon); return W.zoneAt(data, p.x, p.y) }
  assert.equal(at(52.5, 13.4), 60)
  assert.equal(at(28.6, 77.2), 330)
  assert.equal(at(27.7, 85.3), 345)
  assert.equal(at(35.7, 139.7), 540)
  assert.equal(at(40.7, -74), -300)
  assert.equal(at(0, -30), -120)
})

test("night side", () => {
  const night = W.nightPolygon(Date.UTC(2026, 5, 21, 12))
  assert.ok(night.length > 100)
  // At that moment midnight is at 180°: the date line is dark, Greenwich not.
  const ring = night.flatMap(p => [p.x, p.y])
  assert.ok(W.ringContains(ring, W.project(0, 179).x, 0, 1))
  assert.ok(!W.ringContains(ring, W.project(0, 1).x, 0, 1))
})

test("the sun's names delegate to Sky.js", () => {
  const ms = Date.UTC(2026, 9, 2, 15, 44)
  const S = load("Sky.js")
  assert.deepEqual({ ...W.subsolarPoint(ms) }, { ...S.subsolarPoint(ms) })
  assert.equal(W.sunElevation(48, 11, ms), S.sunElevation(48, 11, ms))
  assert.deepEqual(JSON.stringify(W.sunTimes(48, 11, ms, 7200)), JSON.stringify(S.sunTimes(48, 11, ms, 7200)))
  assert.equal(W.twilightRings(ms, -4)[0].length, S.twilightRings(ms, -4)[0].length)
  assert.equal(W.skyColor(-3), S.skyColor(-3))
  assert.equal(W.twilightLayers({ night: true }, [1, 1, 1]).length, 3)
})

test("zebra bands", () => {
  assert.equal(W.zebraBand(60), 1)
  assert.equal(W.zebraBand(-60), 1)
  assert.equal(W.zebraBand(120), 0)
  assert.equal(W.zebraBand(330), 2)
})

test("twilight bands: nested caps around the point opposite the sun", () => {
  // An equinox (both poles in the +6° cap), a solstice and today.
  for (const ms of [Date.UTC(2026, 2, 20, 9, 30), Date.UTC(2026, 5, 21, 18), Date.UTC(2026, 9, 2, 15, 44)]) {
    const golden = W.twilightPolygon(ms, 6)
    const blue = W.twilightPolygon(ms, -4)
    const deep = W.twilightPolygon(ms, -8)
    const sun = W.subsolarPoint(ms)
    for (const poly of [golden, blue, deep, W.nightPolygon(ms)]) assert.ok(!insideFlat(poly, sun.lat, sun.lon), "sun outside")
    const anti = { lat: -sun.lat, lon: sun.lon > 0 ? sun.lon - 180 : sun.lon + 180 }
    for (const poly of [golden, blue, deep]) assert.ok(insideFlat(poly, anti.lat, anti.lon), "antipode inside")
    // Every point agrees with the sun's elevation there, and the caps nest.
    for (let lat = -84; lat <= 84; lat += 6) {
      for (let lon = -177; lon <= 177; lon += 6) {
        const e = W.sunElevation(lat, lon, ms)
        const inGolden = insideFlat(golden, lat, lon)
        const inBlue = insideFlat(blue, lat, lon)
        const inDeep = insideFlat(deep, lat, lon)
        if (Math.abs(e - 6) > 0.5) assert.equal(inGolden, e < 6, `+6° at ${lat},${lon} (${e.toFixed(1)}°)`)
        if (Math.abs(e + 4) > 0.5) assert.equal(inBlue, e < -4, `−4° at ${lat},${lon}`)
        if (Math.abs(e + 8) > 0.5) assert.equal(inDeep, e < -8, `−8° at ${lat},${lon}`)
        if (inDeep) assert.ok(inBlue)
        if (inBlue) assert.ok(inGolden)
      }
    }
  }
})

test("twilight: the flat map's polygon and the globe's rings cover the same area", () => {
  // One pole in the cap: the night side always, the bands at a solstice.
  // The flat polygon is traced differently (copies and bridges), so the
  // areas are compared point by point, away from the edge: the rings take a
  // point every 2° of longitude, coarse where the edge runs nearly north–south.
  const cases = [[Date.UTC(2026, 9, 2, 15, 44), 0], [Date.UTC(2026, 5, 21, 18), 0],
    [Date.UTC(2026, 5, 21, 18), 6], [Date.UTC(2026, 5, 21, 18), -4], [Date.UTC(2026, 11, 21, 6), -8]]
  for (const [ms, e] of cases) {
    const rings = W.twilightRings(ms, e)
    assert.equal(rings.length, 1, `one ring at ${e}°`)
    const ring = rings[0].map((p) => W.project(p.lat, p.lon))
    const polygon = W.twilightPolygon(ms, e)
    for (let lat = -84; lat <= 84; lat += 6) {
      for (let lon = -177; lon <= 177; lon += 6) {
        if (Math.abs(W.sunElevation(lat, lon, ms) - e) < 3) continue
        assert.equal(insideFlat(polygon, lat, lon), insideFlat(ring, lat, lon), `${e}° at ${lat},${lon}`)
      }
    }
  }
})

test("twilight bands along the map's outline: only where the sun is in range", () => {
  // The flat map fills a band as the even-odd of two caps; at the outline
  // (±179°) and inside (0°) membership must equal the elevation test. At
  // 17:17 UTC on 2 October the morning line runs at about −172°, nearly
  // parallel to the western outline: the gold rim seen there is real, and
  // so are the gold south and blue north pole regions near the equinoxes.
  const bands = [[6, 0], [0, -8]]
  for (const ms of [Date.UTC(2026, 5, 21, 17, 17), Date.UTC(2026, 2, 20, 17, 17), Date.UTC(2026, 9, 2, 17, 17)]) {
    for (const [high, low] of bands) {
      const upper = W.twilightPolygon(ms, high)
      const lower = W.twilightPolygon(ms, low)
      for (const lon of [-179.5, -179, -170, 0, 170, 179, 179.5]) {
        for (let lat = -89.5; lat <= 89.5; lat += 0.5) {
          const e = W.sunElevation(lat, lon, ms)
          // The edges are traced every 2° of bearing: half a degree of
          // elevation off them (more right at the poles) is left out.
          if (Math.abs(e - high) < 0.6 || Math.abs(e - low) < 0.6 || Math.abs(lat) > 88) continue
          const inBand = insideFlat(upper, lat, lon) !== insideFlat(lower, lat, lon)
          assert.equal(inBand, e < high && e >= low,
            `${new Date(ms).toISOString().slice(0, 10)} band ${high}…${low} at ${lat},${lon}: ${e.toFixed(2)}°`)
        }
      }
    }
  }
})

test("twilight layers: every cap matches the sun's elevation on the map", () => {
  for (const ms of [Date.UTC(2026, 5, 21, 18), Date.UTC(2026, 2, 20, 9, 30)]) {
    for (const e of [4, 2, -3, -6, -12]) {
      const polygon = W.twilightPolygon(ms, e)
      for (let lat = -84; lat <= 84; lat += 12) {
        for (let lon = -177; lon <= 177; lon += 12) {
          const elevation = W.sunElevation(lat, lon, ms)
          if (Math.abs(elevation - e) < 0.6) continue
          assert.equal(insideFlat(polygon, lat, lon), elevation < e, `${e}° at ${lat},${lon}`)
        }
      }
    }
  }
})
