# Astro modules for phases P2–P4

Pure JS modules for the Astro tab (`TimeAstro.qml`), each `.pragma library`, ES5 style, tested in Node (`tests/astro-*.test.mjs`, loaded through `tests/load.mjs`). Nothing here is wired into QML yet.

**Conventions.** Positions and directions are in the ecliptic and equinox of J2000 (as in `Astro.js`): x towards the vernal point, z to the ecliptic's north pole. Positions are in au and are heliocentric unless a function says otherwise. Angles are in degrees and times in UTC ms. UTC stands in for TT/TDB everywhere, except the IAU rotation model, which adds TT − UTC = 69.184 s because Jupiter turns 0.7° in that time. Vectors are `{ x, y, z }`. Matrices are flat row-major 3×3 arrays.

## AstroRotation.js (imports Astro.js)

| Export | Meaning |
|---|---|
| `gmst(ms)`, `earthRotationAngle(ms)` | GMST (Meeus 12.4 / IAU 1982) and ERA (IERS 2010), 0–360° |
| `eclipticToEquatorial(v)`, `equatorialToEcliptic(v)` | J2000 frames, ε = 23.4392911° (`OBLIQUITY_J2000`) |
| `fromSpherical(lon, lat)`, `toSpherical(v)`, `dot`, `cross`, `norm`, `angleBetween`, `apply`, `applyTransposed` | vector helpers |
| `IAU`, `BODIES` | pole RA/Dec `[J2000, per century]` and W `[W0, °/day]` for sun, mercury, venus, earth, moon, mars, jupiter, saturn, uranus, neptune |
| `poleRaDec(body, ms)`, `poleVector(body, ms)` | IAU north pole (ICRF RA/Dec; unit vector in the ecliptic) |
| `spinPoleVector(body, ms)` | right-hand-rule spin axis (flipped for Venus and Uranus) |
| `primeMeridian(body, ms)` | W in degrees |
| `rotationPeriodHours(body)` | 360/Ẇ in hours, negative for retrograde rotation (Earth 23.9345, Venus −5832.4, Uranus −17.24) |
| `orbitNormal(body, ms)`, `obliquityOf(body, ms)` | orbit normal from the Astro.js elements; tilt between the spin axis and the orbit normal (Venus 177.4°, Uranus 97.8°; Sun and Moon measured against the ecliptic pole) |
| `bodyMatrix(body, ms)` | body-fixed → ecliptic J2000 (x = prime meridian on the equator, z = IAU north, y = east). For Earth: GMST, then the obliquity, then the precession back to J2000 |
| `subPoint(body, dir, ms)` | `{ lat, lon }` under a direction: **planetocentric** latitude on a sphere, **east** longitude −180…180 |
| `surfaceVector(body, lat, lon, ms)` | the reverse: a surface point as an ecliptic unit vector |
| `cameraAxes(AstroView.camera(az, el))` | `{ right, up, toward }`, the same as `AstroView.view` |
| `bodyViewMatrix(bodyMatrix, axes)` | a view matrix for `Globe.projectView`, `capPolygonView` and the other view functions |
| `ringPlaneNormal("saturn", ms)` | Saturn's pole (the ring plane normal) |
| `RING_RADII`, `RING_EDGES_KM`, `SATURN_EQUATORIAL_RADIUS_KM` | ring edges in units of the 60 268 km equatorial radius: C 1.239–1.526, B 1.526–1.950, A 2.030–2.270 |

**Accuracy.** The rotation model includes the periodic terms for Neptune (0.7°) and the Moon (13 terms; without them the lunar pole would sit on the ecliptic pole instead of 1.54° from it). Against JPL Horizons, the sub-Earth longitude of Mars, Jupiter and Saturn agrees within 0.3° once light time is applied, and the Moon's sub-Earth point agrees within 0.5° (the librations come out of the geometry). Earth's sub-solar point agrees with `Sky.subsolarPoint` within 0.15°. Saturn's W is the Voyager radio period. The IAU calls it uncertain, so treat it as a drawing aid. Uranus and Neptune also use radio periods.

## AstroBodies.js (imports Astro.js, AstroRotation.js)

| Export | Meaning |
|---|---|
| `SMALL_BODIES`, `SMALL_BODY_KEYS` | ceres, pluto, eris, halley: osculating elements with epoch, `radiusKm`, `source`, `error` |
| `position(body, ms)` | two-body propagation: `{ x, y, z, r, lon, lat }` |
| `orbit(body, count)`, `periodDays(body)`, `elementsFor(body, ms)` | the orbit drawing. Use ≥ 200 points for Halley |
| `tailDirection(p)` | anti-solar unit vector |
| `BELTS`, `beltElements(name, n)`, `beltPoints(name, ms, n)` | `"asteroids"` (a 2.1–3.3 au, e ≤ 0.2, i ≤ 15°) and `"kuiper"` (a 30–50 au, e ≤ 0.2, i ≤ 20°): seeded Park–Miller, so the points are stable, a shorter list is a prefix of a longer one, and each point moves with its own Kepler period |
| `MOONS`, `MOON_KEYS`, `moonPosition(key, ms)` | io, europa, ganymede, callisto, titan. Returns the position relative to the planet in au, plus `angle`, `phaseKnown: true` and `planet`. Circles in the Laplace plane |
| `moonOrbitNormal(key)`, `moonPeriodDays(key)`, `epochLongitude(m)` | |
| `SPACECRAFT`, `SPACECRAFT_KEYS`, `spacecraftPosition(key, ms)` | voyager1, voyager2, newhorizons, jwst: `{ x, y, z, r, lon, lat, speed (au/yr) }` |
| `l2Point(earthPos)` | Earth's position × 1.01 |

**Measured errors** against Horizons, 2016–2036 (also asserted in the tests):

- Ceres: under 0.7°. This model leaves out Jupiter's pull.
- Pluto: under 0.1°.
- Eris: under 0.01°.
- Halley: under 0.06°.
- Galilean moons: within 1.5°.
- Titan: within 3.5°, because its eccentricity is left out.
- Voyager 1 and 2: within 0.02° in direction and 0.12 au in distance.
- New Horizons: within 0.12° and 0.72 au.

The spacecraft move on straight lines from Horizons' 2026-01-01 state vectors, so their distance grows by v·Δt as asked, but in 3D.

## AstroEvents.js (imports Astro.js, Moon.js)

| Export | Meaning |
|---|---|
| `moonGeocentric(ms)` | the Moon from Earth's centre: `{ lon, lat, distanceKm, x, y, z }`. It uses Moon.js's own place, converted to ecliptic J2000 by undoing its sidereal time and obliquity and removing the precession |
| `moonDistanceKm(ms)` | Meeus table 47.A distance terms. Within 50 km of DE441 (tested) |
| `moonInfo(ms)` | `{ phase, key, illuminated, waxing, ageDays, distanceKm, lastNew, nextNew, nextFull }`. `key` is one of `PHASE_KEYS` (new, waxingCrescent, firstQuarter, waxingGibbous, full, waningGibbous, lastQuarter, waningCrescent), each covering an eighth of the cycle centred on its point. `ageDays` counts from the last new moon |
| `nextPhase(fromMs, 0 or 0.5)` | the next new or full moon. Within 30 min of the USNO's 2026 moments; the test allows 45 min |
| `elongation(planet, ms)` | `{ angle, side: "east"/"west", lonDiff, distance }`, geocentric |
| `visibility(ms)` | Mercury to Saturn: `"evening"`, `"morning"` or `"none"` |
| `VISIBLE_ELONGATION` | the thresholds: Venus 10°, all others 15°. A rule of thumb, not a measured constant |
| `nextOpposition(planet, ms)`, `nextConjunction(planet, ms)` | outer planets, within 2 years, 0 if there is none. Geometric, so within hours of published moments |
| `nextSeasonEvent(ms)` | `{ key, utcMs }` from `Astro.seasonMarks` |

Both opposition functions scan day by day: about 1500 Kepler solves per call. Compute them once a day, not per frame.

Near opposition a planet is up all night. The `side` flips there from west ("morning") to east ("evening").

## AstroClock.js

| Export | Meaning |
|---|---|
| `steps(nowMs)` | 733 moments, now ± 366 days in whole-day steps, keeping now's time of day. Now is at `NOW_INDEX` (366); the last index is `LAST_INDEX` (732) |
| `SPEEDS`, `timing(i)` | `{ step, delay }`: 1 day/s → 1 per 1000 ms, 7 → 1 per 143 ms, 30 → 1 per 33 ms |
| `advance(index, speed, direction)` | `{ index, stopped }`. Stops at either end |
| `nearestIndex(nowMs, ms)`, `isNow(index)`, `daysFromNow(nowMs, ms)` | |
| `label(ms, offsetSeconds)` | `{ year, month, day, weekday, hour, minute }` in local time from a zone offset. Built without Intl |

## Sources (all retrieved 2026-10-03)

- **IAU rotation (WGCCRE 2009, Archinal et al. 2011):** NAIF `pck00010.tpc`, https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/pck00010.tpc. This supplies the poles, W, the Moon and Neptune periodic terms, the radii of the large moons, and the moons' rates (the W of synchronous rotators). Mars W0 = 176.630°.
- **Axial tilts for the tests:** https://en.wikipedia.org/wiki/Axial_tilt
- **GMST:** Meeus, *Astronomical Algorithms* eq. 12.4 and example 12.a, and USNO https://aa.usno.navy.mil/faq/GAST.
- **ERA:** https://en.wikipedia.org/wiki/Sidereal_time
- **TAI − UTC:** IERS Bulletin C, https://hpiers.obspm.fr/iers/bul/bulc/bulletinc.dat
- **Saturn's rings:** NASA NSSDCA, https://nssdc.gsfc.nasa.gov/planetary/factsheet/satringfact.html
- **Ceres, Pluto, Eris:** JPL SBDB, `https://ssd-api.jpl.nasa.gov/sbdb.api?sstr=<name>&full-prec=1`. This also gives the Ceres and Halley diameters.
- **Halley:** osculating elements from the JPL Horizons API, https://ssd.jpl.nasa.gov/api/horizons.api
- **Spacecraft:** state vectors from the JPL Horizons API.
- **Moons:** JPL "Planetary Satellite Mean Elements", https://ssd.jpl.nasa.gov/sats/elem/sep.html. Titan's epoch longitude comes from Horizons instead, because the table's Ω, ω and M did not reproduce Titan's place.
- **Moon distance:** Meeus table 47.A, as in PyMeeus `Moon.py`.
- **Synodic month:** https://en.wikipedia.org/wiki/Lunar_month
- **Eris radius:** https://en.wikipedia.org/wiki/Eris_(dwarf_planet)
- **Test references:**
  - New and full moons 2026: USNO, https://aa.usno.navy.mil/api/moon/phases/year?year=2026
  - Oppositions: EarthSky and in-the-sky.org.
  - Saturn ring-plane crossing on 2025-03-23: in-the-sky.org.
  - Horizons fixtures: `tests/fixtures/astro-horizons.json`.

## Wiring notes for TimeAstro.qml

- **Earth as a globe.** Per frame:
  1. `var axes = AstroRotation.cameraAxes(AstroView.camera(sky.azimuth, sky.elevation))`
  2. `var vm = AstroRotation.bodyViewMatrix(AstroRotation.bodyMatrix("earth", ms), axes)`
  3. Draw with the Globe view functions (`projectView`, `frontPolygonsView` on `prepareLand(data)`, `gridLinesView`), all with matrix `vm` and the drawn radius in px. y is up, so flip it as the globe does.
  4. For the night cap, the sub-solar point is `AstroRotation.subPoint("earth", sunDir, ms)` with `sunDir = −Astro.position("earth", ms)`. Then call `Globe.capPolygonView(-sub.lat, sub.lon + 180, 90 + elevation, vm, r)` (the antisolar cap) for each `Sky.twilightLayers` elevation, as More Weather's WeatherGlobe.qml does.
  5. Because the matrix comes from the real camera, the visible face, the tilt of the axis and the day side all match the orbit view.
- **Other planets.** Draw a shaded sphere and a meridian stroke:
  - For the stroke, use `surfaceVector(body, lat, 0, ms)` for lat −80…80, projected with `AstroView.view` around the body's screen centre (×radius). Keep only the points whose depth is towards the viewer, i.e. `dot(v, axes.toward) > 0`.
  - The pole tick is the projection of `poleVector(body, ms)`.
- **Saturn's rings.** Take the ring plane normal n = `ringPlaneNormal("saturn", ms)` and two in-plane axes u = `norm(cross(n, axes.toward))` and w = `cross(n, u)`. For radius k·R (k from `RING_RADII`), the ring is the ellipse c + R·k·(u cos t + w sin t) in screen terms. Split it into a far half and a near half by the sign of `dot(point, axes.toward)`:
  1. Draw the far half.
  2. Draw the planet.
  3. Draw the near half.

  The open angle is B = 90° − `angleBetween(toViewer, n)`. The ring shadow is optional.
- **The Moon.**
  - Earth–Moon close-up: `g = AstroEvents.moonGeocentric(ms)` gives the Moon at Earth + g in au. Use your own close-up scale, since the real 0.00257 au is too small.
  - Near-side mark: `AstroRotation.subPoint("moon", {−g}, ms)` stays within ±8° of (0°, 0°), and the libration is visible. Put the mark at `surfaceVector("moon", 0, 0, ms)` and draw it only when its depth faces the viewer.
  - The phase comes from the geometry (the Sun direction relative to the Moon). `moonInfo` gives the info line.
- **Large moons.** Draw `moonPosition(key, ms)` around the planet in its own close-up scale. All five have `phaseKnown: true`.
- **Spacecraft.** `spacecraftPosition` gives true distances of 60–170 au, beyond the model's edge. Draw an arrow at the view's rim in the direction of `AstroView.view(spacecraft)` and label it with `r` in au.
- **Belts.** `beltPoints("asteroids", ms, 400)` and `beltPoints("kuiper", ms, 600)` → `AstroView.modelPoint` each. Cache per day while scrubbing.
- **Time line.**
  - Each `Timer` tick: `interval: AstroClock.timing(speed).delay`, then `advance(index, speed, dir)`. Stop when `stopped` is true.
  - Keep `steps(now)` fixed while scrubbing, and rebuild it when the user returns to now. `nearestIndex` maps a dragged position back to an index.
