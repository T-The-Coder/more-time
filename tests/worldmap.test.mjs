import { test } from "node:test"
import assert from "node:assert"
import { readFileSync, statSync } from "node:fs"
import { join } from "node:path"
import { load, root } from "./load.mjs"

const W = load("WorldMap.js")
const file = join(root, "data/worldmap.json")
const data = JSON.parse(readFileSync(file, "utf8"))
const near = (a, b, eps = 1e-9) => assert.ok(Math.abs(a - b) < eps, `${a} != ${b}`)

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

test("sun and night side", () => {
  // June solstice noon UTC: sun over the Tropic of Cancer near Greenwich.
  const june = W.subsolarPoint(Date.UTC(2026, 5, 21, 12))
  near(june.lat, 23.44, 0.2)
  near(june.lon, 0, 1)
  const december = W.subsolarPoint(Date.UTC(2026, 11, 21, 0))
  near(december.lat, -23.44, 0.2)
  near(Math.abs(december.lon), 180, 1)
  const night = W.nightPolygon(Date.UTC(2026, 5, 21, 12))
  assert.ok(night.length > 100)
  // At that moment midnight is at 180°: the date line is dark, Greenwich not.
  const ring = night.flatMap(p => [p.x, p.y])
  assert.ok(W.ringContains(ring, W.project(0, 179).x, 0, 1))
  assert.ok(!W.ringContains(ring, W.project(0, 1).x, 0, 1))
})

test("zebra bands", () => {
  assert.equal(W.zebraBand(60), 1)
  assert.equal(W.zebraBand(-60), 1)
  assert.equal(W.zebraBand(120), 0)
  assert.equal(W.zebraBand(330), 2)
})

// ---- The sky colour of the menu bar time ----

// Bobingen near Augsburg, 2 October 2026 (CEST = UTC+2).
const place = [48.27, 10.83]
const at = (h, m = 0) => Date.UTC(2026, 9, 2, h - 2, m)
const elevation = (ms) => W.sunElevation(place[0], place[1], ms)
const strongest = (mix) => Object.entries(mix).sort((a, b) => b[1] - a[1])[0][0]

test("sun elevation: noon high, sunset near zero, midnight deep", () => {
  // Solar noon here is about 13:10 CEST; early October the sun stands at
  // about 90 − 48.3 − 3.6 ≈ 38°.
  near(elevation(at(13, 10)), 38.2, 1)
  // Sunset about 18:58 CEST.
  near(elevation(at(18, 58)), -0.6, 1)
  assert.ok(elevation(at(1, 10)) < -40)
  // The equator at an equinox noon: nearly overhead.
  assert.ok(W.sunElevation(0, 0, Date.UTC(2026, 2, 20, 12, 7)) > 89)
})

test("sky mix: day, golden hour, blue hour, night", () => {
  for (const e of [-30, -14, -10, -6, -4, -1, 2, 5, 8, 40]) {
    const mix = W.skyMix(e)
    near(mix.day + mix.golden + mix.blue + mix.night, 1, 1e-9)
  }
  assert.equal(strongest(W.skyMix(elevation(at(13)))), "day")
  assert.equal(strongest(W.skyMix(elevation(at(19)))), "golden")
  assert.equal(W.skyMix(-6).blue, 1)
  assert.equal(strongest(W.skyMix(elevation(at(23)))), "night")
  assert.equal(W.skyMix(-14).night, 1)
  assert.equal(W.skyMix(8).day, 1)
  // Monotone from day to night: as the sun sinks, the weight moves only
  // towards later phases.
  const rank = (mix) => mix.golden * 1 + mix.blue * 2 + mix.night * 3
  let previous = -1
  for (let e = 12; e >= -16; e -= 0.25) {
    const r = rank(W.skyMix(e))
    assert.ok(r >= previous - 1e-9, `rank falls at ${e}°`)
    previous = r
  }
})

test("sky colour: base colours, softened and readable", () => {
  assert.equal(W.skyColor(40), "#5ea8e8")
  assert.equal(W.skyColor(-30), "#4a3c9a")
  assert.equal(W.skyColor(0), "#e3a447")
  // On a dark theme the night is lifted towards the text until it reads.
  const darkBg = W.hexRgb("#1e1e2e")
  const darkFg = W.hexRgb("#cdd6f4")
  const lightBg = W.hexRgb("#eff1f5")
  const lightFg = W.hexRgb("#4c4f69")
  for (const e of [40, 0, -6, -30]) {
    assert.ok(W.contrast(W.hexRgb(W.skyColor(e, darkFg, darkBg)), darkBg) >= 3, `dark ${e}`)
    assert.ok(W.contrast(W.hexRgb(W.skyColor(e, lightFg, lightBg)), lightBg) >= 3, `light ${e}`)
  }
})

test("sun times: Berlin, 2 October 2026 (CEST)", () => {
  const berlin = [52.52, 13.405]
  const cest = 2 * 3600
  const local = (h, m) => Date.UTC(2026, 9, 2, h - 2, m)
  const t = W.sunTimes(berlin[0], berlin[1], local(12, 0), cest)
  const minutes = (ms) => Math.round((ms - Date.UTC(2026, 9, 1, 22, 0)) / 60000)
  const hm = (h, m) => h * 60 + m
  assert.equal(t.polar, "")
  // Almanac values for Berlin that day: sunrise 07:09, sunset 18:42, solar
  // noon 12:55 (±3 min).
  assert.ok(Math.abs(minutes(t.sunrise) - hm(7, 9)) <= 3, `sunrise ${minutes(t.sunrise)}`)
  assert.ok(Math.abs(minutes(t.sunset) - hm(18, 42)) <= 3, `sunset ${minutes(t.sunset)}`)
  assert.ok(Math.abs((minutes(t.sunrise) + minutes(t.sunset)) / 2 - hm(12, 55)) <= 2)
  // Evening golden hour from +6° to −4°, then the blue hour to −8°.
  assert.ok(minutes(t.goldenEvening[0]) >= hm(17, 50) && minutes(t.goldenEvening[0]) <= hm(18, 5))
  assert.ok(minutes(t.goldenEvening[1]) >= hm(18, 55) && minutes(t.goldenEvening[1]) <= hm(19, 10))
  assert.equal(t.blueEvening[0], t.goldenEvening[1])
  assert.ok(minutes(t.blueEvening[1]) > minutes(t.blueEvening[0]) + 15)
  assert.ok(minutes(t.blueEvening[1]) <= hm(19, 45))
  // The morning mirrors it: blue, then golden across sunrise.
  assert.equal(t.blueMorning[1], t.goldenMorning[0])
  assert.ok(t.goldenMorning[0] < t.sunrise && t.sunrise < t.goldenMorning[1])
  assert.ok(t.goldenEvening[0] < t.sunset && t.sunset < t.goldenEvening[1])
  // The same day whatever moment of it is asked for.
  assert.deepEqual(W.sunTimes(berlin[0], berlin[1], local(0, 5), cest), t)
  // The limits are the sky colour's: golden at the start of the golden hour
  // changes to blue in the middle of the stops.
  near(W.sunElevation(berlin[0], berlin[1], t.goldenEvening[1]), -4, 0.05)
})

test("sun times: polar night and midnight sun", () => {
  // Longyearbyen (78° N): no sunrise in December, no sunset in June.
  const night = W.sunTimes(78.22, 15.65, Date.UTC(2026, 11, 21, 12), 3600)
  assert.equal(night.polar, "night")
  assert.equal(night.sunrise, 0)
  assert.equal(night.sunset, 0)
  assert.deepEqual([...night.goldenEvening], [0, 0])
  const day = W.sunTimes(78.22, 15.65, Date.UTC(2026, 5, 21, 12), 7200)
  assert.equal(day.polar, "day")
  assert.equal(day.sunset, 0)
})

test("twilight bands: nested caps around the point opposite the sun", () => {
  const inside = (polygon, lat, lon) => {
    const p = W.project(lat, lon)
    return W.ringContains(polygon.flatMap((q) => [q.x, q.y]), p.x, p.y, 1)
  }
  // An equinox (both poles in the +6° cap), a solstice and today.
  for (const ms of [Date.UTC(2026, 2, 20, 9, 30), Date.UTC(2026, 5, 21, 18), Date.UTC(2026, 9, 2, 15, 44)]) {
    const golden = W.twilightPolygon(ms, 6)
    const blue = W.twilightPolygon(ms, -4)
    const deep = W.twilightPolygon(ms, -8)
    const sun = W.subsolarPoint(ms)
    for (const poly of [golden, blue, deep, W.nightPolygon(ms)]) assert.ok(!inside(poly, sun.lat, sun.lon), "sun outside")
    const anti = { lat: -sun.lat, lon: sun.lon > 0 ? sun.lon - 180 : sun.lon + 180 }
    for (const poly of [golden, blue, deep]) assert.ok(inside(poly, anti.lat, anti.lon), "antipode inside")
    // Every point agrees with the sun's elevation there, and the caps nest.
    for (let lat = -84; lat <= 84; lat += 6) {
      for (let lon = -177; lon <= 177; lon += 6) {
        const e = W.sunElevation(lat, lon, ms)
        const inGolden = inside(golden, lat, lon)
        const inBlue = inside(blue, lat, lon)
        const inDeep = inside(deep, lat, lon)
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
  const flat = (poly, lat, lon) => {
    const p = W.project(lat, lon)
    return W.ringContains(poly.flatMap((q) => [q.x, q.y]), p.x, p.y, 1)
  }
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
        assert.equal(flat(polygon, lat, lon), flat(ring, lat, lon), `${e}° at ${lat},${lon}`)
      }
    }
  }
})

test("night fill: 70 % black and 30 % night sky, stronger on dark themes", () => {
  const light = W.nightFill(W.hexRgb("#eff1f5"))
  const dark = W.nightFill(W.hexRgb("#1e1e2e"))
  near(light.r, 0x4a / 255 * 0.3, 1e-9)
  near(light.b, 0x9a / 255 * 0.3, 1e-9)
  assert.equal(light.a, 0.30)
  assert.equal(dark.a, 0.38)
  assert.equal(dark.r, light.r)
})

test("twilight bands along the map's outline: only where the sun is in range", () => {
  // The flat map fills a band as the even-odd of two caps; at the outline
  // (±179°) and inside (0°) membership must equal the elevation test. At
  // 17:17 UTC on 2 October the morning line runs at about −172°, nearly
  // parallel to the western outline: the gold rim seen there is real, and
  // so are the gold south and blue north pole regions near the equinoxes.
  const inside = (poly, lat, lon) => {
    const p = W.project(lat, lon)
    return W.ringContains(poly.flatMap((q) => [q.x, q.y]), p.x, p.y, 1)
  }
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
          const inBand = inside(upper, lat, lon) !== inside(lower, lat, lon)
          assert.equal(inBand, e < high && e >= low,
            `${new Date(ms).toISOString().slice(0, 10)} band ${high}…${low} at ${lat},${lon}: ${e.toFixed(2)}°`)
        }
      }
    }
  }
})
