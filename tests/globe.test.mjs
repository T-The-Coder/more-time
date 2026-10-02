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

test("orthographic projection round trips", () => {
  for (const center of [0, 13.4, -150, 179]) {
    for (const [lat, lon] of [[0, center], [52.5, center + 40], [-33.9, center - 70], [80, center + 10]]) {
      const p = G.projectOrtho(lat, lon, center, R)
      assert.ok(p.visible)
      const back = G.unprojectOrtho(p.x, p.y, center, R)
      near(back.lat, lat, 1e-6)
      near(G.shortestTurn(back.lon, lon), 0, 1e-6)
    }
  }
  assert.equal(G.unprojectOrtho(R, R, 0, R), null)
  // The centre faces the viewer; the north pole is at the top of the rim.
  near(G.projectOrtho(0, 30, 30, R).x, 0)
  near(G.projectOrtho(90, 0, 30, R).y, R)
})

test("visible within 90° of the centre", () => {
  for (const center of [0, 100, -170]) {
    assert.ok(G.projectOrtho(0, center + 89, center, R).visible)
    assert.ok(G.projectOrtho(0, center - 89, center, R).visible)
    assert.ok(G.projectOrtho(0, center + 90, center, R).visible, "on the rim")
    assert.ok(!G.projectOrtho(0, center + 91, center, R).visible)
    assert.ok(!G.projectOrtho(40, center - 91, center, R).visible)
    near(Math.abs(G.projectOrtho(0, center + 90, center, R).x), R)
  }
})

test("shortest turn across the date line", () => {
  near(G.shortestTurn(170, -170), 20)
  near(G.shortestTurn(-170, 170), -20)
  near(G.shortestTurn(10, 50), 40)
  near(G.shortestTurn(0, 190), -170)
  near(G.shortestTurn(720 + 5, 0), -5)
  assert.ok(Math.abs(G.shortestTurn(0, 180)) === 180)
})

const square = (lat0, lon0, lat1, lon1) => G.prepareLatLon([
  { lat: lat0, lon: lon0 }, { lat: lat0, lon: lon1 }, { lat: lat1, lon: lon1 }, { lat: lat1, lon: lon0 }])

test("a ring behind the globe yields nothing", () => {
  const ring = square(-20, 150, 20, 170)
  assert.deepEqual(G.frontPolygons(ring, 0, R), [])
  assert.deepEqual(G.frontLines(ring, 0, R), [])
  assert.equal(G.frontPolygons(ring, 160, R).length, 1)
})

test("clipping at the horizon stays on the disc and follows the rim", () => {
  // Half in front, half behind: cut at lon 90, along the rim.
  const ring = square(-60, 40, 60, 140)
  const polys = G.frontPolygons(ring, 0, R)
  assert.equal(polys.length, 1)
  let onRim = 0
  for (let i = 0; i < polys[0].length; i += 2) {
    const r = Math.hypot(polys[0][i], polys[0][i + 1])
    assert.ok(r <= R + 1e-6)
    if (Math.abs(r - R) < 1e-6) onRim++
  }
  assert.ok(onRim > 30, "the cut is sampled along the rim")
  // Lines never run along the rim: no consecutive points both on it.
  for (const line of G.frontLines(ring, 0, R)) {
    for (let i = 2; i < line.length; i += 2) {
      const a = Math.hypot(line[i - 2], line[i - 1]), b = Math.hypot(line[i], line[i + 1])
      assert.ok(!(Math.abs(a - R) < 1e-6 && Math.abs(b - R) < 1e-6))
    }
  }
})

test("a ring across the date line shows whole when facing it", () => {
  // A zone from 170° E to 190° (−170°) as the data would store it, and the
  // same as two halves at ±180°.
  const ring = square(-10, 170, 10, 190)
  const polys = G.frontPolygons(ring, -175, R)
  assert.equal(polys.length, 1)
  near(G.polygonArea(polys[0]), G.polygonArea(G.frontPolygons(square(-10, -15, 10, 5), 0, R)[0]), 1e-6)
})

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

test("twilight areas: night, golden and blue rings", () => {
  // June solstice noon UTC: the night (one pole) as one ring holding 180°.
  const june = Date.UTC(2026, 5, 21, 12)
  const night = W.twilightRings(june, 0)
  assert.equal(night.length, 1)
  assert.deepEqual(W.twilightPolygon(june, 0), W.nightPolygon(june))
  const flat = W.nightPolygon(june).flatMap(p => [p.x, p.y])
  assert.ok(W.ringContains(flat, W.project(0, 179).x, 0, 1))
  // Near the equinox −8° holds no pole (an oval) and +6° both (two rings).
  const equinox = Date.UTC(2026, 2, 20, 15)
  assert.equal(W.twilightRings(equinox, -8).length, 1)
  assert.equal(W.twilightRings(equinox, 6).length, 2)
  // Every boundary point has the sun at that elevation.
  for (const [ms, e] of [[june, 6], [june, -4], [equinox, -8], [equinox, 6], [june, 0]]) {
    const rings = W.twilightRings(ms, e)
    const boundary = rings[rings.length - 1].filter(p => Math.abs(p.lat) < 89 && Math.abs(Math.abs(p.lon) - 180) > 1e-9)
    for (const p of boundary.slice(0, 120)) near(W.sunElevation(p.lat, p.lon, ms), e, 0.2)
  }
  // On the globe, the night facing midnight covers about half the disc.
  const sun = W.subsolarPoint(june)
  const rings = night.map(r => G.prepareLatLon(r))
  let area = 0
  for (const ring of rings) for (const poly of G.frontPolygons(ring, sun.lon + 90, R)) area += G.polygonArea(poly)
  near(area / (Math.PI * R * R), 0.5, 0.03)
})
