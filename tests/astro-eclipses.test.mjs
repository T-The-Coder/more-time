// AstroEclipses.js and data/astro-eclipses-*.json (NASA's Five Millennium
// Catalogs, Espenak & Meeus): well-known eclipses, the chunk loading, the
// calendar conversion of ancient dates, a geometric self-check against
// Moon.js/Sky.js, and the visibility test against NASA's Besselian elements.
import { test } from "node:test"
import assert from "node:assert"
import { readFileSync, statSync } from "node:fs"
import { join } from "node:path"
import { load, root } from "./load.mjs"

const E = load("AstroEclipses.js")
const M = E.Moon
const S = E.Sky
const DAY = 86400000
const RAD = Math.PI / 180
const near = (a, b, eps, what = "") => assert.ok(Math.abs(a - b) <= eps, `${what} ${a} != ${b} (±${eps})`)
const readChunk = (c) => JSON.parse(readFileSync(join(root, "data", c.file), "utf8"))
const loadAll = () => { for (const c of E.chunksFor(-1e15, 1e15)) E.addChunk(readChunk(c)) }
const sep = (a, b) => {
  const c = Math.sin(a.lat * RAD) * Math.sin(b.lat * RAD) + Math.cos(a.lat * RAD) * Math.cos(b.lat * RAD) * Math.cos((a.lon - b.lon) * RAD)
  return Math.acos(Math.max(-1, Math.min(1, c))) / RAD
}
const onDay = (y, m, d, kind) => E.between(Date.UTC(y, m - 1, d), Date.UTC(y, m - 1, d + 1)).filter((e) => e.kind === kind)

test("files: ten chunks, each well under the 512 KiB limit; NASA's totals", () => {
  const chunks = E.chunksFor(-1e15, 1e15)
  assert.equal(chunks.length, 10)
  let solar = 0, lunar = 0
  for (const c of chunks) {
    assert.ok(statSync(join(root, "data", c.file)).size < 128 * 1024, c.file)
    const d = readChunk(c)
    if (d.kind === "solar") solar += d.count; else lunar += d.count
    assert.equal(d.data.length, d.count * d.stride)
  }
  // The catalogues' own counts for −1999 … +3000.
  assert.equal(solar, 11898)
  assert.equal(lunar, 12064)
})

test("chunksFor and lazy loading", () => {
  E.clear()
  const now = Date.UTC(2026, 9, 5)
  const need = E.chunksFor(now - 365 * DAY, now + 365 * DAY)
  assert.deepEqual(need.map((c) => c.file), ["astro-eclipses-solar-2001.json", "astro-eclipses-lunar-2001.json"])
  // Near 2000/2001 both neighbouring millennia.
  assert.equal(E.chunksFor(Date.UTC(2000, 11, 1), Date.UTC(2001, 1, 1), "solar").length, 2)
  // Nothing loaded: no answers, and next() does not jump over a gap.
  assert.equal(E.next("solar", now), null)
  E.addChunk(readChunk(need[0]))
  assert.equal(E.missingChunks(now, now + DAY, "solar").length, 0)
  assert.equal(E.missingChunks(now, now + DAY).length, 1)
  assert.equal(E.next("solar", now).type, "annular") // 2027-02-06 annular
  assert.equal(E.next("lunar", now), null)
  assert.equal(E.previous("solar", Date.UTC(2001, 0, 2)), null) // 1001–2000 not loaded
  // Adding the same file twice changes nothing.
  const n = E.addChunk(readChunk(need[0]))
  assert.equal(E.addChunk(readChunk(need[0])), n)
  E.clear()
  loadAll()
})

// NASA's catalogue rows (eclipse.gsfc.nasa.gov/SEcat5/SE2001-2100.html,
// LEcat5/LE2001-2100.html, SE1901-2000.html, retrieved 2026-10-05), UT =
// TD − ΔT. Cross-checked with Wikipedia: 2024-04-08 greatest eclipse at
// 25.3° N 104.1° W, magnitude 1.0566
// (https://en.wikipedia.org/wiki/Solar_eclipse_of_April_8,_2024); 2026-08-12
// at 17:45:53 UTC, 65°30′ N 25°25′ W, magnitude 1.0386
// (https://en.wikipedia.org/wiki/Solar_eclipse_of_August_12,_2026).
test("well-known eclipses", () => {
  loadAll()
  const cases = [
    ["solar", [2024, 4, 8], "total", Date.UTC(2024, 3, 8, 18, 17, 15), 1.0566, 25, -104],
    ["solar", [2026, 8, 12], "total", Date.UTC(2026, 7, 12, 17, 45, 51), 1.0386, 65, -25],
    ["solar", [1999, 8, 11], "total", Date.UTC(1999, 7, 11, 11, 3, 5), 1.0286, 45, 24],
    ["solar", [1919, 5, 29], "total", Date.UTC(1919, 4, 29, 13, 8, 34), 1.0719, 4, -17],
    ["lunar", [2025, 9, 7], "total", Date.UTC(2025, 8, 7, 18, 11, 43), 1.3619, -6, 87],
    ["lunar", [2026, 3, 3], "total", Date.UTC(2026, 2, 3, 11, 33, 37), 1.1507, 6, -171]
  ]
  for (const [kind, [y, m, d], type, ms, mag, lat, lon] of cases) {
    const found = onDay(y, m, d, kind)
    assert.equal(found.length, 1, `${kind} ${y}-${m}-${d}`)
    const e = found[0]
    assert.equal(e.type, type)
    assert.equal(e.utcMs, ms)
    near(e.magnitude, mag, 1e-9)
    assert.equal(e.lat, lat)
    assert.equal(e.lon, lon)
    assert.equal(e.approximate, false)
  }
  near(onDay(2026, 8, 12, "solar")[0].utcMs, Date.UTC(2026, 7, 12, 17, 45, 53), 5000, "Wikipedia 2026")
  // next / previous / nearest around the 2024 eclipse.
  const t = Date.UTC(2024, 3, 8, 18, 17, 15)
  assert.equal(E.next("solar", t - DAY).utcMs, t)
  assert.equal(E.previous("solar", t + DAY).utcMs, t)
  assert.equal(E.nearest(t + 3 * DAY).utcMs, t)
  assert.equal(E.next("lunar", t).type, "partial") // 2024-09-18 partial lunar
  // An annular, a hybrid and a penumbral one.
  assert.equal(onDay(2023, 10, 14, "solar")[0].type, "annular")
  assert.equal(onDay(2023, 4, 20, "solar")[0].type, "hybrid")
  assert.equal(onDay(2023, 5, 5, "lunar")[0].type, "penumbral")
})

test("counts per year and between()", () => {
  loadAll()
  for (let y = 1900; y < 2100; y++) {
    const list = E.between(Date.UTC(y, 0, 1), Date.UTC(y + 1, 0, 1))
    const solar = list.filter((e) => e.kind === "solar").length
    const lunar = list.length - solar
    assert.ok(solar >= 2 && solar <= 5, `${y} solar ${solar}`)
    assert.ok(lunar >= 2 && lunar <= 5, `${y} lunar ${lunar}`)
    for (let i = 1; i < list.length; i++) assert.ok(list[i].utcMs >= list[i - 1].utcMs)
  }
  // NASA: 224 solar eclipses in 2001–2100.
  assert.equal(E.between(Date.UTC(2001, 0, 1), Date.UTC(2101, 0, 1)).filter((e) => e.kind === "solar").length, 224)
})

// The Julian Day of a Julian-calendar date (Meeus ch. 7, B = 0).
function julianCalendarJd(y, m, d) {
  if (m <= 2) { y -= 1; m += 12 }
  return Math.floor(365.25 * (y + 4716)) + Math.floor(30.6001 * (m + 1)) + d - 1524.5
}

// The eclipse of Thales, 585 BC May 28 (Julian; astronomical year −584):
// NASA's catalogue row 03379 "-0584 May 28 19:28:50 TD, ΔT 18384 s, total"
// (https://eclipse.gsfc.nasa.gov/SEcat5/SE-0599--0500.html, retrieved
// 2026-10-05). Stored as the same instant in JavaScript's proleptic
// Gregorian time line (22 May), with UT = TD − ΔT, marked approximate.
test("an ancient eclipse: Thales, 585 BC", () => {
  loadAll()
  const jd = julianCalendarJd(-584, 5, 28)
  const tdMs = (jd - 2440587.5) * DAY + ((19 * 60 + 28) * 60 + 50) * 1000
  const list = E.between(tdMs - 2 * DAY, tdMs + DAY).filter((e) => e.kind === "solar")
  assert.equal(list.length, 1)
  const e = list[0]
  assert.equal(e.type, "total")
  assert.equal(e.tdMs, tdMs)
  assert.equal(e.deltaT, 18384)
  assert.equal(e.utcMs, tdMs - 18384000)
  assert.equal(e.approximate, true)
  const d = new Date(e.utcMs)
  assert.deepEqual([d.getUTCFullYear(), d.getUTCMonth() + 1, d.getUTCDate()], [-584, 5, 22])
  // The Gregorian reform: 1582-10-04 (Julian) is followed by 1582-10-15.
  assert.equal(julianCalendarJd(1582, 10, 4) + 1, (Date.UTC(1582, 9, 15) / DAY) + 2440587.5)
})

// Geometry: at greatest eclipse the Sun and the Moon of Moon.js/Sky.js
// (each good to a few tenths of a degree) must be together for a solar
// eclipse and opposite for a lunar one. The separation at greatest eclipse
// grows with |gamma| (up to about 1.55° for the most grazing partial ones),
// so the 1.5°/178.5° bounds hold for the central and umbral eclipses and
// 1.6°/178.4° for all. 1900–2100: worst 1.54° and 178.42°.
test("self-check against Moon.js and Sky.js, 1900–2100", () => {
  loadAll()
  for (const e of E.between(Date.UTC(1900, 0, 1), Date.UTC(2101, 0, 1))) {
    const d = sep(M.moonPosition(e.utcMs), S.subsolarPoint(e.utcMs))
    if (e.kind === "solar") {
      assert.ok(d < (e.type === "partial" ? 1.6 : 1.5), `solar ${new Date(e.utcMs).toISOString()} ${d}`)
    } else {
      assert.ok(180 - d < (e.type === "penumbral" ? 1.6 : 1.5), `lunar ${new Date(e.utcMs).toISOString()} ${d}`)
    }
  }
})

// The catalogue's own sub-lunar point (whole degrees) and Moon.js agree, so
// lunarAltitude can use either.
test("lunar visibility: the Moon's altitude at greatest eclipse", () => {
  loadAll()
  for (const e of E.between(Date.UTC(1900, 0, 1), Date.UTC(2101, 0, 1)).filter((x) => x.kind === "lunar")) {
    const m = M.moonPosition(e.utcMs)
    assert.ok(sep(m, e) < 1.2, `${new Date(e.utcMs).toISOString()}`)
  }
  const sept = onDay(2025, 9, 7, "lunar")[0]
  const march = onDay(2026, 3, 3, "lunar")[0]
  assert.equal(E.visibleFrom(sept, 52.52, 13.40), true) // Berlin: rising at 20:11 CEST
  assert.equal(E.visibleFrom(sept, 40.71, -74.01), false) // New York: 14:11 EDT
  assert.equal(E.visibleFrom(sept, -33.87, 151.21), true) // Sydney: 04:11 AEST
  assert.equal(E.visibleFrom(march, 34.05, -118.24), true) // Los Angeles: 03:33 PST
  assert.equal(E.visibleFrom(march, 52.52, 13.40), false) // Berlin: 12:33 CET
  const alt = E.lunarAltitude(sept, -6, 87)
  near(alt.geocentric, 90, 1.2, "zenith")
})

// The NASA Besselian elements of 2024 Apr 08 (t0 = 18:00 TDT, ΔT = 74 s;
// https://eclipse.gsfc.nasa.gov/SEbeselm/SEbeselm2001/SE2024Apr08Tbeselm.html,
// retrieved 2026-10-05): the distance of a place from the penumbra's edge,
// min over the eclipse with the Sun up, with Earth's flattening.
function besselMargin(lat, lon) {
  const X = [-0.318157, 0.5117105, 0.0000326, -0.0000085], Y = [0.219747, 0.2709586, -0.0000594, -0.0000047]
  const D = [7.58620, 0.014844, -0.000002], L1 = [0.535813, 0.0000618, -0.0000128], MU = [89.59122, 15.004084]
  const poly = (c, t) => c.reduce((s, v, i) => s + v * t ** i, 0)
  const u = Math.atan(0.99664719 * Math.tan(lat * RAD))
  const rs = 0.99664719 * Math.sin(u), rc = Math.cos(u)
  let best = Infinity, from = null, to = null
  for (let t = -3.5; t <= 3.5; t += 0.01) {
    const d = poly(D, t) * RAD, H = (poly(MU, t) + lon - 0.00417807 * 74) * RAD
    const xi = rc * Math.sin(H), eta = rs * Math.cos(d) - rc * Math.sin(d) * Math.cos(H)
    const zeta = rs * Math.sin(d) + rc * Math.cos(d) * Math.cos(H)
    if (zeta < -0.0145) continue
    const m = Math.hypot(poly(X, t) - xi, poly(Y, t) - eta) - (poly(L1, t) - zeta * 0.0046683)
    best = Math.min(best, m)
    if (m < 0) { if (from === null) from = t; to = t }
  }
  // t in TDT hours from t0; as UT ms.
  const ut = (t) => Date.UTC(2024, 3, 8, 18) - 74000 + t * 3600000
  return { margin: best, fromMs: from === null ? 0 : ut(from), toMs: to === null ? 0 : ut(to) }
}

test("solar visibility against the Besselian elements and known cases", () => {
  loadAll()
  const e = onDay(2024, 4, 8, "solar")[0]
  const places = [["Dallas", 32.78, -96.8], ["Berlin", 52.52, 13.4], ["Anchorage", 61.22, -149.9], ["Bogotá", 4.71, -74.07],
    ["Lima", -12.05, -77.04], ["Honolulu", 21.31, -157.86], ["London", 51.51, -0.13], ["Reykjavík", 64.15, -21.94]]
  for (const [name, lat, lon] of places) {
    const ours = E.solarVisibility(e, lat, lon)
    const theirs = besselMargin(lat, lon).margin
    near(ours.margin, theirs, 0.03, name)
    if (Math.abs(theirs) > 0.03) assert.equal(ours.visible, theirs < 0, name)
  }
  const dallas = E.solarVisibility(e, 32.78, -96.8)
  // The partial phase in Dallas from the Besselian elements; the 2-minute
  // steps are within 10 minutes of it.
  const ref = besselMargin(32.78, -96.8)
  near(dallas.fromMs, ref.fromMs, 10 * 60000, "Dallas start")
  near(dallas.toMs, ref.toMs, 10 * 60000, "Dallas end")
  const aug = onDay(2026, 8, 12, "solar")[0]
  assert.equal(E.visibleFrom(aug, 40.42, -3.7), true) // Madrid
  assert.equal(E.visibleFrom(aug, -33.87, 151.21), false) // Sydney
  assert.equal(E.visibleFrom(onDay(1999, 8, 11, "solar")[0], 48.14, 11.58), true) // Munich
  assert.equal(E.visibleFrom(onDay(2025, 3, 29, "solar")[0], 51.51, -0.13), true) // London, partial
  assert.equal(E.visibleFrom(onDay(2025, 3, 29, "solar")[0], -33.87, 151.21), false)
})
