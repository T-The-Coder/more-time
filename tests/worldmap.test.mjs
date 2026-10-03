import { test } from "node:test"
import assert from "node:assert"
import { readFileSync, statSync } from "node:fs"
import { join } from "node:path"
import { load, root } from "./load.mjs"

const W = load("WorldMap.js")
const file = join(root, "data/worldmap.json")
const data = JSON.parse(readFileSync(file, "utf8"))
const near = (a, b, eps = 1e-9) => assert.ok(Math.abs(a - b) < eps, `${a} != ${b}`)

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

test("the projection's names delegate to EqualEarth.js", () => {
  const E = load("EqualEarth.js")
  assert.deepEqual({ ...W.project(52.5, 13.4) }, { ...E.project(52.5, 13.4) })
  assert.deepEqual({ ...W.unproject(0.3, 0.9) }, { ...E.unproject(0.3, 0.9) })
  assert.equal(W.X_MAX, E.X_MAX)
  assert.equal(W.Y_MAX, E.Y_MAX)
  assert.equal(W.outline().length, E.outline().length)
  assert.equal(W.graticule().length, E.graticule().length)
  const ms = Date.UTC(2026, 9, 2, 15, 44)
  assert.equal(W.twilightPolygon(ms, -4).length, E.twilightPolygon(ms, -4).length)
  assert.equal(W.nightPolygon(ms).length, E.nightPolygon(ms).length)
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

