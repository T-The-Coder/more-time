// The globe with More Time's map data (data/worldmap.json, WorldMap.js):
// not shared, unlike tests/globe.test.mjs.
import { test } from "node:test"
import assert from "node:assert"
import { readFileSync } from "node:fs"
import { join } from "node:path"
import { load, root } from "./load.mjs"

const G = load("Globe.js")
const W = load("WorldMap.js")
const data = JSON.parse(readFileSync(join(root, "data/worldmap.json"), "utf8"))
const near = (a, b, eps = 1e-9) => assert.ok(Math.abs(a - b) < eps, `${a} != ${b}`)
const R = 100

test("the data on the globe: cached, closed, all on the disc", () => {
  const prepared = G.prepareData(data, W.unproject)
  assert.equal(prepared.land.length, data.land.length)
  assert.equal(G.prepareData(JSON.parse(JSON.stringify(data)), W.unproject), prepared, "cached")
  let area = 0
  for (const zone of prepared.zones)
    for (const ring of zone.rings)
      for (const poly of G.frontPolygons(ring, 13, R)) {
        for (let i = 0; i < poly.length; i++) assert.ok(Math.abs(poly[i]) <= R + 1e-6)
        area += G.polygonArea(poly)
      }
  // The zones tile the earth: their front parts cover about the disc.
  near(area / (Math.PI * R * R), 1, 0.05)
  // Berlin's zone at Berlin, through the globe and back to the map.
  const p = G.projectOrtho(52.5, 13.4, 13, R)
  const back = G.unprojectOrtho(p.x, p.y, 13, R)
  const q = W.project(back.lat, back.lon)
  assert.equal(W.zoneAt(data, q.x, q.y), 60)
})

test("twilight areas: the night on the flat map and the globe", () => {
  // June solstice noon UTC: the night (one pole) as one ring holding 180°.
  const june = Date.UTC(2026, 5, 21, 12)
  const night = W.twilightRings(june, 0)
  assert.deepEqual(W.twilightPolygon(june, 0), W.nightPolygon(june))
  const flat = W.nightPolygon(june).flatMap(p => [p.x, p.y])
  assert.ok(W.ringContains(flat, W.project(0, 179).x, 0, 1))
  // On the globe, the night facing midnight covers about half the disc.
  const sun = W.subsolarPoint(june)
  const rings = night.map(r => G.prepareLatLon(r))
  let area = 0
  for (const ring of rings) for (const poly of G.frontPolygons(ring, sun.lon + 90, R)) area += G.polygonArea(poly)
  near(area / (Math.PI * R * R), 0.5, 0.03)
})
