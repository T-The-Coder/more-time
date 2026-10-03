// Astro.js: the planets from JPL's approximate Keplerian elements (Standish,
// "Approximate Positions of the Planets", table 1, 1800–2050). Every
// reference below says where it comes from; none is a copied ephemeris
// value that could not be derived or checked independently.
import { test } from "node:test"
import assert from "node:assert"
import { load } from "./load.mjs"

const A = load("Astro.js")
const RAD = Math.PI / 180
const near = (a, b, eps, what = "") => assert.ok(Math.abs(a - b) <= eps, `${what} ${a} != ${b} (±${eps})`)
const angle = (a, b) => ((a - b) % 360 + 540) % 360 - 180
const day = 86400000

test("julian centuries: J2000.0 and a century later", () => {
  assert.equal(A.julianCenturies(Date.UTC(2000, 0, 1, 12)), 0)
  near(A.julianCenturies(Date.UTC(2100, 0, 1, 12)), 1, 1e-12, "36525 days")
})

test("Kepler's equation: solved to 1e-8 for any eccentricity", () => {
  for (const e of [0, 0.0167, 0.2056, 0.5, 0.9, 0.97]) {
    for (let M = -Math.PI; M <= Math.PI; M += 0.37) {
      const E = A.solveKepler(M, e)
      near(E - e * Math.sin(E), M, 1e-8, `e ${e} M ${M.toFixed(2)}`)
    }
  }
})

test("Earth against the Sun: opposite the Sun's longitude, at its distance", () => {
  // The Sun's apparent geocentric longitude and distance from the low-
  // precision formulas of the Astronomical Almanac (section C, good to
  // 0.01° and 0.0003 au from 1950 to 2050; the same formula Sky.js uses for
  // the subsolar point): Earth stands 180° away, referred back from the
  // equinox of date to J2000 by the precession, the aberration added back.
  for (const ms of [Date.UTC(2000, 0, 1, 12), Date.UTC(2015, 2, 20, 9, 45), Date.UTC(2026, 5, 21, 12), Date.UTC(2026, 9, 3), Date.UTC(2049, 6, 1)]) {
    const n = (ms - Date.UTC(2000, 0, 1, 12)) / day
    const L = 280.460 + 0.9856474 * n
    const g = (357.528 + 0.9856003 * n) * RAD
    const sunLon = L + 1.915 * Math.sin(g) + 0.020 * Math.sin(2 * g)
    const sunDistance = 1.00014 - 0.01671 * Math.cos(g) - 0.00014 * Math.cos(2 * g)
    const earth = A.position("earth", ms)
    near(angle(earth.lon, A.earthLonFor(sunLon, A.julianCenturies(ms))), 0, 0.02, "longitude")
    near(earth.r, sunDistance, 0.0003, "distance")
    // The J2000 ecliptic: the orbit tilts from it by 0.013° a century.
    near(earth.lat, 0, Math.abs(A.elementsAt("earth", A.julianCenturies(ms)).I) + 1e-9, "on the ecliptic")
  }
})

test("Earth's perihelion 2026: 3 January, 0.98330 au", () => {
  // Perihelion of the Earth–Moon barycentre: q = a(1 − e) from the
  // elements; the Earth itself passes perihelion on 3 January 2026
  // (USNO/IMCCE almanacs give 3 Jan 2026 about 17 h UTC); the Moon shifts
  // the Earth's own moment by up to a day, so ±1.5 days.
  let best = { ms: 0, r: Infinity }
  for (let ms = Date.UTC(2025, 11, 20); ms < Date.UTC(2026, 0, 20); ms += 3600000) {
    const r = A.position("earth", ms).r
    if (r < best.r) best = { ms, r }
  }
  near(best.ms, Date.UTC(2026, 0, 3, 17), 1.5 * day, "moment")
  const el = A.elementsAt("earth", A.julianCenturies(best.ms))
  near(best.r, el.a * (1 - el.e), 1e-6, "q")
  near(best.r, 0.98330, 0.00005, "distance")
})

test("equinoxes and solstices 2026 within half an hour", () => {
  // Moments as published by the US Naval Observatory (Earth's seasons
  // 2026, UTC): 20 Mar 14:46, 21 Jun 08:24, 23 Sep 00:05, 21 Dec 20:50.
  // Nutation (up to ±17″, about 7 minutes) is left out, and the elements
  // are good to well under an arcminute for Earth: half an hour is ample.
  const marks = A.seasonMarks(2026)
  const expected = [Date.UTC(2026, 2, 20, 14, 46), Date.UTC(2026, 5, 21, 8, 24), Date.UTC(2026, 8, 23, 0, 5), Date.UTC(2026, 11, 21, 20, 50)]
  assert.deepEqual(marks.seasons.map((s) => s.key), ["marchEquinox", "juneSolstice", "septemberEquinox", "decemberSolstice"])
  marks.seasons.forEach((s, i) => {
    near(s.utcMs, expected[i], 30 * 60000, s.key)
    near(angle(A.position("earth", s.utcMs).lon, s.lon), 0, 1e-4, `${s.key} on its mark`)
    // 90° apart, Earth opposite the Sun: the March equinox near 180°.
    near(angle(s.lon, 180 + 90 * i), 0, 0.5, `${s.key} longitude`)
  })
  assert.equal(marks.months.length, 12)
  marks.months.forEach((m, i) => {
    assert.equal(m.utcMs, Date.UTC(2026, i, 1))
    near(angle(m.lon, A.position("earth", m.utcMs).lon), 0, 1e-9)
  })
  // Earth moves about a degree a day: the month marks a month apart.
  near(angle(marks.months[1].lon, marks.months[0].lon), 31 * 360 / 365.25, 1.2, "January's length")
})

test("Mars opposition 2027-02-19: Earth between the Sun and Mars", () => {
  // Opposition is when Mars stands opposite the Sun seen from Earth, i.e.
  // Earth and Mars at the same heliocentric longitude (to within Mars'
  // latitude). Widely published date: 19 February 2027.
  let crossing = null
  for (let ms = Date.UTC(2027, 1, 5); ms < Date.UTC(2027, 2, 5); ms += 3600000) {
    const before = angle(A.position("mars", ms).lon, A.position("earth", ms).lon)
    const after = angle(A.position("mars", ms + 3600000).lon, A.position("earth", ms + 3600000).lon)
    if (before >= 0 && after < 0) crossing = ms
  }
  assert.ok(crossing !== null, "a crossing")
  near(crossing, Date.UTC(2027, 1, 19, 12), 2 * day, "opposition")
})

test("Jupiter and Saturn at J2000: the elements' own mean longitude", () => {
  // At T = 0 the mean anomaly is L − ϖ; the true longitude differs from L
  // by the equation of the centre, at most 2e radians (≈ 5.5° for Jupiter,
  // 6.2° for Saturn), and the radius lies between q and Q.
  for (const planet of ["jupiter", "saturn"]) {
    const el = A.elementsAt(planet, 0)
    const p = A.position(planet, Date.UTC(2000, 0, 1, 12))
    const M = (el.L - el.peri) * RAD
    // The equation of the centre to second order in e (Brouwer & Clemence).
    const centre = (2 * el.e * Math.sin(M) + 1.25 * el.e * el.e * Math.sin(2 * M)) / RAD
    near(angle(p.lon, el.L + centre), 0, 0.15, planet)
    near(p.lat, 0, el.I + 1e-9, `${planet} latitude within the inclination`)
  }
  // Commonly quoted heliocentric longitudes at J2000: Jupiter about 36.3°,
  // Saturn about 45.7° (both near Aries/Taurus in early 2000).
  near(A.position("jupiter", Date.UTC(2000, 0, 1, 12)).lon, 36.3, 0.3, "Jupiter")
  near(A.position("saturn", Date.UTC(2000, 0, 1, 12)).lon, 45.7, 0.3, "Saturn")
})

test("every planet stays between perihelion and aphelion, below its inclination", () => {
  for (const planet of A.PLANETS) {
    for (let ms = Date.UTC(1990, 0, 1); ms < Date.UTC(2050, 0, 1); ms += 97 * day) {
      const el = A.elementsAt(planet, A.julianCenturies(ms))
      const p = A.position(planet, ms)
      assert.ok(p.r >= el.a * (1 - el.e) - 1e-9 && p.r <= el.a * (1 + el.e) + 1e-9, `${planet} r ${p.r}`)
      assert.ok(Math.abs(p.lat) <= Math.abs(el.I) + 1e-9, `${planet} lat ${p.lat}`)
      near(Math.hypot(p.x, p.y, p.z), p.r, 1e-12)
    }
  }
})

test("orbits: closed, on the orbit, and the periods", () => {
  const ms = Date.UTC(2026, 9, 3)
  for (const planet of A.PLANETS) {
    const el = A.elementsAt(planet, A.julianCenturies(ms))
    const points = A.orbit(planet, ms, 120)
    assert.equal(points.length, 120)
    for (const p of points) {
      const r = Math.hypot(p.x, p.y, p.z)
      assert.ok(r >= el.a * (1 - el.e) - 1e-9 && r <= el.a * (1 + el.e) + 1e-9)
    }
    // The planet itself lies on its orbit: as near a point of it as the
    // spacing allows.
    const p = A.position(planet, ms)
    const nearest = Math.min(...points.map((q) => A.distance(p, q)))
    assert.ok(nearest < 2 * Math.PI * el.a * (1 + el.e) / 120, `${planet} on its orbit`)
  }
  // Sidereal periods (days): Mercury 87.97, Earth 365.26, Jupiter 4332.6,
  // Neptune about 60190 (any astronomy reference).
  near(A.periodDays("mercury"), 87.97, 0.02)
  near(A.periodDays("earth"), 365.26, 0.02)
  near(A.periodDays("jupiter"), 4332.6, 1)
  near(A.periodDays("neptune"), 60190, 100)
})

test("long-range elements: Table 2 agrees with Table 1 inside 1800–2050", () => {
  // The two fits (JPL, approx_pos.html) differ by their nominal errors at
  // most: under 0.01° for the inner planets, a few tenths for the giants.
  const limits = { mercury: 0.01, venus: 0.01, earth: 0.01, mars: 0.05, jupiter: 0.2, saturn: 0.4, uranus: 0.35, neptune: 0.15 }
  for (const planet of A.PLANETS) {
    for (let year = 1800; year <= 2050; year += 10) {
      const ms = A.utc(year, 0, 1)
      near(angle(A.position(planet, ms, "short").lon, A.position(planet, ms, "long").lon), 0, limits[planet], `${planet} ${year}`)
    }
  }
  assert.ok(!A.isApproximate(Date.UTC(2026, 9, 3)))
  assert.ok(A.isApproximate(A.utc(1600, 0, 1)) && A.isApproximate(A.utc(2100, 0, 1)))
})

test("the great conjunction of 2020-12-21: Jupiter and Saturn together, seen from Earth", () => {
  // The closest since 1623: about 0.1° apart in the sky on 21 December
  // 2020 (widely published). Geocentric longitudes from both tables.
  const ms = Date.UTC(2020, 11, 21, 18)
  for (const table of ["short", "long"]) {
    const e = A.position("earth", ms, table)
    const lon = (p) => { const q = A.position(p, ms, table); return Math.atan2(q.y - e.y, q.x - e.x) / RAD }
    near(angle(lon("jupiter"), lon("saturn")), 0, 0.3, table)
  }
})

test("far past and future: positions stay on their orbits", () => {
  for (const year of [-2999, -1000, 1000, 1500, 2500, 3000]) {
    const ms = A.utc(year, 5, 1)
    for (const planet of A.PLANETS) {
      const el = A.elementsAt(planet, A.julianCenturies(ms))
      const p = A.position(planet, ms)
      assert.ok(p.r >= el.a * (1 - el.e) - 1e-9 && p.r <= el.a * (1 + el.e) + 1e-9, `${planet} ${year}`)
    }
  }
  // Seasons in a year before 100 AD are found (Date.UTC would read 50 as 1950).
  const marks = A.seasonMarks(50)
  assert.equal(new Date(marks.seasons[0].utcMs).getUTCFullYear(), 50)
})
