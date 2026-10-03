// AstroView.js: the Astro tab's model scale, sizes, camera and projection.
import { test } from "node:test"
import assert from "node:assert"
import { load } from "./load.mjs"

const V = load("AstroView.js")
const near = (a, b, eps = 1e-9) => assert.ok(Math.abs(a - b) <= eps, `${a} != ${b}`)

test("model scale: monotone, direction kept, 1 au stays 1", () => {
  let previous = -1
  for (const r of [0, 0.39, 0.72, 1, 1.52, 5.2, 9.5, 19.2, 30.1]) {
    const m = V.modelDistance(r)
    assert.ok(m > previous)
    previous = m
  }
  near(V.modelDistance(1), 1)
  // Mercury to Neptune within about 1:7.
  const ratio = V.modelDistance(30.07) / V.modelDistance(0.387)
  assert.ok(ratio > 6.5 && ratio < 7.5, `ratio ${ratio}`)
  const p = V.modelPoint({ x: 3, y: 4, z: 0 })
  near(Math.hypot(p.x, p.y, p.z), Math.pow(5, 0.45))
  near(p.y / p.x, 4 / 3)
  assert.deepEqual({ ...V.modelPoint({ x: 0, y: 0, z: 0 }) }, { x: 0, y: 0, z: 0 })
})

test("body sizes: log scale, Mercury 4 px up to the Sun about 16", () => {
  near(V.bodyRadius(2439.4), 4)
  const earth = V.bodyRadius(6371), jupiter = V.bodyRadius(69911), sun = V.bodyRadius(695700)
  assert.ok(earth > 5.5 && earth < 7.5)
  assert.ok(jupiter > 10 && jupiter < 12)
  assert.ok(sun > 15 && sun <= 18)
  assert.ok(V.bodyRadius(24622) < V.bodyRadius(25362) && V.bodyRadius(25362) < V.bodyRadius(58232))
})

test("camera: the ecliptic pole and the vernal point", () => {
  // The pole is straight up, shortened by the elevation; it leans towards
  // the viewer.
  for (const [az, el] of [[0, 30], [77, 10], [-140, 80]]) {
    const cam = V.camera(az, el)
    const pole = V.view({ x: 0, y: 0, z: 1 }, cam)
    near(pole.x, 0)
    near(pole.y, Math.cos(el * Math.PI / 180))
    near(pole.depth, Math.sin(el * Math.PI / 180))
  }
  // Azimuth 0: the vernal point to the right, level with the Sun.
  const v0 = V.view({ x: 1, y: 0, z: 0 }, V.camera(0, 30))
  near(v0.x, 1)
  near(v0.y, 0)
  near(v0.depth, 0)
  // Azimuth 90: it has turned towards the viewer, below the Sun.
  const v90 = V.view({ x: 1, y: 0, z: 0 }, V.camera(90, 30))
  near(v90.x, 0, 1e-12)
  near(v90.y, -0.5)
  near(v90.depth, Math.cos(30 * Math.PI / 180))
  // On the canvas y grows downwards.
  const p = V.project({ x: 0, y: 0, z: 1 }, V.camera(0, 30), 100, 200, 150)
  near(p.x, 200)
  near(p.y, 150 - 100 * Math.cos(30 * Math.PI / 180))
  // The elevation stays within 10–80°.
  near(V.clampElevation(0), 10)
  near(V.clampElevation(95), 80)
})

test("depth: what is nearer the viewer is drawn later", () => {
  const cam = V.camera(0, 30)
  // At azimuth 0 the camera stands on the −y side: −y is in front.
  const front = V.view({ x: 0, y: -1, z: 0 }, cam)
  const back = V.view({ x: 0, y: 1, z: 0 }, cam)
  assert.ok(front.depth > 0 && back.depth < 0)
  // In front also means lower on the canvas when looking down.
  assert.ok(front.y < back.y)
  const sorted = V.depthSorted([{ key: "front", depth: front.depth }, { key: "sun", depth: 0 }, { key: "back", depth: back.depth }])
  assert.deepEqual(sorted.map((b) => b.key), ["back", "sun", "front"])
})

test("turns the short way and hits the front body", () => {
  near(V.shortestTurn(170, -170), 20)
  near(V.shortestTurn(-170, 170), -20)
  near(V.shortestTurn(10, 50), 40)
  const bodies = [{ key: "a", x: 10, y: 10, r: 5, depth: -1 }, { key: "b", x: 11, y: 10, r: 8, depth: 1 }, { key: "c", x: 100, y: 100, r: 4, depth: 0 }]
  assert.equal(V.hitTest(bodies, 11, 10, 2).key, "b")
  assert.equal(V.hitTest(bodies, 102, 101, 2).key, "c")
  assert.equal(V.hitTest(bodies, 50, 50, 2), null)
})

test("zoom steps: whole system, inner system, Earth; the extent fits", () => {
  assert.deepEqual(V.ZOOMS.map((z) => z.key), ["system", "inner", "earth"])
  assert.ok(V.ZOOMS[0].extent > V.modelDistance(30.3))
  assert.ok(V.ZOOMS[1].extent > V.modelDistance(1.67) && V.ZOOMS[1].extent < V.ZOOMS[0].extent)
  assert.ok(V.ZOOMS[2].extent > V.modelDistance(1.017) && V.ZOOMS[2].extent < V.ZOOMS[1].extent)
  // The extent fits the width and, foreshortened, the height.
  const s = V.scaleFor(5, 600, 300, 30)
  assert.ok(5 * s <= 300 + 1e-9)
  assert.ok(5 * s * (Math.sin(Math.PI / 6) + 0.12 * Math.cos(Math.PI / 6)) <= 150 + 1e-9)
})
