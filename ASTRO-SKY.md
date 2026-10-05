# Astro sky modules: stars, eclipses, almanac, the Moon from here, time-lapse

Pure JS modules for the Astro tab, written like those in `ASTRO-MODULES.md`: `.pragma library`, ES5, tested in Node (`tests/astro-stars`, `astro-eclipses`, `astro-almanac`, `moon-view`, `astro-lapse`), loaded through `tests/load.mjs`. None of them is wired into QML yet.

**Conventions.**
- Directions on the sky are unit vectors in the ecliptic and equinox of J2000, the frame `AstroView` and `Astro.js` use: x points to the vernal point, z to the ecliptic's north pole.
- Angles are in degrees unless a name says radians.
- Times are UTC ms (JavaScript's proleptic Gregorian time line, as `AstroDate.js` uses).
- No module returns translated text. Kinds, types and units are keys, and the QML side words them.

Run the tests with `mise x node@24.21.0 -- node --test tests/<file>.test.mjs`.

## AstroStars.js (imports AstroRotation.js)

| Export | Meaning |
|---|---|
| `stars(data)` | Takes the parsed `data/astro-stars.json` and returns plain arrays: `{ count, hr, ra, dec, mag, color, x, y, z, names: {index: name}, nameList }`. The stars are sorted brightest first, so a magnitude cut is a prefix. Call it once after the FileView loads. |
| `countTo(s, limitMag)` | The length of that prefix. |
| `visibleStars(s, limitMag)` | `[{ index, x, y, z, mag, color, size, name }]` |
| `eclipticDirection(raDeg, decDeg)` | J2000 RA/Dec → ecliptic J2000 unit vector, using ε = 23.4392911°. |
| `starSize(mag)`, `starAlpha(mag)` | Drawn radius in px: 0.6 at magnitude 5, 3.5 for Sirius. Opacity from 1 down to 0.25. |
| `COLOR_KEYS` | `blue`, `white`, `yellowWhite`, `yellow`, `orange`: B−V below 0, 0.3, 0.6, 1.1, and above. Stars without B−V take the class of their spectral letter. |
| `figureSegments(cons, abbr)`, `allFigures(cons)` | Stick figures as star index pairs into the star arrays. |
| `constellationIndex(cons, abbr)` | Index into `cons.abbr`, `cons.latin` and `cons.genitive`. |
| `constellationOf(cons, raDeg, decDeg, epoch?)` | The real IAU constellation of a direction: precession to B1875 (Herget, as in Roman's program), then Roman's table lookup. About 9 µs per call. |
| `constellationAtEcliptic(cons, lon, lat)` | The same for ecliptic J2000 coordinates. |
| `ZODIAC`, `zodiacAt(lon)` | The 13 constellations the ecliptic crosses, each with the J2000 ecliptic longitude where the ecliptic enters it. Use `zodiacAt` for "the Sun / a planet is in …". It is exact for the Sun. For a planet or the Moon it gives the zodiac constellation at that longitude, which is what almanacs mean even when the planet's own latitude puts it in Cetus or Orion. `constellationOf` gives that strict answer. |
| `zodiacCrossings(cons, step)` | Recomputes `ZODIAC` from the boundaries. About 0.4 s, so it is for tests only. |

Entry longitudes (J2000, from the boundaries):

| Constellation | Entry longitude |
|---|---|
| Psc | 351.65 |
| Ari | 28.69 |
| Tau | 53.42 |
| Gem | 90.14 |
| Cnc | 117.99 |
| Leo | 138.04 |
| Vir | 173.86 |
| Lib | 217.81 |
| Sco | 241.05 |
| Oph | 247.64 |
| Sgr | 266.24 |
| Cap | 299.66 |
| Aqr | 327.49 |

**Data.**
- `data/astro-stars.json` (41 KB) holds 1,665 stars: 1,630 down to V = 5.0, plus 35 fainter stars that the figures need. Each star has its HR number, RA and Dec in 0.001°, V in 0.01 mag and a colour class. The 84 stars to V = 2.5 that have an IAU name carry it.
- `data/astro-constellations.json` (15 KB) holds:
  - the 88 IAU abbreviations, with Latin names and genitives;
  - the figures, as polylines of star indices;
  - Roman's 357 boundary rows.
- Both files come from `tools/build-astro-stars.py`, which downloads into `tools/.cache/`.

**Verified.**
- Sirius, Vega, Polaris and Betelgeuse agree with SIMBAD within 0.002°.
- `constellationOf` reproduces all 8 of Roman's published examples. It also agrees with the constellation part of the Bayer or Flamsteed designation for all 3,143 designated BSC stars (a one-off check, 0 mismatches).
- The Sun's entry into each constellation in 2021 matches EarthSky's list (after Ottewell) to the day. The Gemini entry on 2021-06-21 at 15 h UTC matches EarthSky's "about 15:00 UTC".
- The middle of each of Wikipedia's 13 date ranges lies in the right constellation.

## AstroEclipses.js (imports Moon.js, Sky.js, AstroEvents.js)

The module covers 11,898 solar and 12,064 lunar eclipses from −1999 to +3000. These are NASA's own totals, and the tests check them.

| Export | Meaning |
|---|---|
| `CHUNKS`, `chunksFor(fromMs, toMs, kind?)` | `[{ kind, key, file }]`: the files (in `data/`) that a span needs. There is one file per kind and millennium, with keys `-1999`, `-0999`, `0001`, `1001` and `2001`. |
| `addChunk(parsed)`, `missingChunks(from, to, kind?)`, `clear()` | Lazy loading. Adding the same file twice does nothing. |
| `next(kind, ms)`, `previous(kind, ms)` | `kind` is `"solar"`, `"lunar"` or anything else for both. They return null rather than skip a millennium that is not loaded. |
| `between(fromMs, toMs)`, `nearest(ms)` | Search the loaded eclipses. |
| `visibleFrom(eclipse, lat, lon)` | For a lunar eclipse: the Moon is above the horizon at greatest eclipse (topocentric altitude above −0.833°). For a solar eclipse: the place passes through the penumbra while the Sun is up. |
| `lunarAltitude(e, lat, lon)` | `{ geocentric, topocentric }`. |
| `solarVisibility(e, lat, lon)` | `{ visible, fromMs, toMs, margin }`. About 14 ms per call. |

An eclipse is `{ kind, type, utcMs, tdMs, deltaT, approximate, magnitude, gamma, lat, lon }`. Lunar eclipses also carry `umbralMagnitude` and `penumbralMagnitude`.
- **type:** total, annular, hybrid or partial for the Sun; total, partial or penumbral for the Moon.
- **utcMs:** UT = TD − ΔT, using the catalogue's own ΔT.
- **approximate:** set before 1600 and after 2100, where ΔT is extrapolated. NASA's standard error of ΔT (https://eclipse.gsfc.nasa.gov/SEcat5/uncertainty.html) is 139 s at 500 AD, 265 s at year 0 and 3732 s (15.6° of longitude) at 2000 BC; after 2100 it is extrapolated, reaching 1885 s by 3000 AD.
- **Calendar:** the catalogue's Julian-calendar dates before 1582-10-15 are converted through the Julian Day. Thales' eclipse of −584 May 28 (Julian) is therefore stored as 22 May on the proleptic Gregorian time line, as `Date` and `AstroDate` count.
- **Place:** whole degrees (the century pages give no more). For a solar eclipse it is the point of greatest eclipse. For a lunar eclipse it is where the Moon is in the zenith.

**Data.**
- 10 files, `data/astro-eclipses-{solar,lunar}-<key>.json`, of 79–100 KB each (915 KB in all), each well under the 512 KiB limit.
- Each file is a flat integer array. Times are seconds since the previous eclipse; magnitude and gamma are ×10⁴.
- `tools/build-astro-eclipses.py` builds them from the 100 century pages, cached in `tools/.cache/`.
- Loading both 2001–3000 files takes 9 ms in Node.

**Solar visibility model.**
- At greatest eclipse the shadow axis is placed where the catalogue says.
- Its motion comes from the change in the Moon.js and Sky.js geometry over ±4 h, using differences, so their constant offset of about 0.2 Earth radii cancels.
- Against NASA's Besselian elements for 2024-04-08:
  - the axis motion agrees within 0.002 R⊕ per hour;
  - the margin to the penumbra's edge agrees within 0.004 R⊕ (25 km) for 8 places;
  - Dallas' partial phase starts and ends within the 2-minute step.
- **Known limits:** the function does not say how much of the Sun is covered. Before 1600 the longitudes inherit ΔT's error.

**Verified.**
- The 2024-04-08, 2026-08-12, 1999-08-11 and 1919-05-29 solar eclipses and the 2025-09-07 and 2026-03-03 lunar eclipses match the catalogue rows.
- Wikipedia agrees: 2026-08-12 at 17:45:53 UTC (2 s from the stored time), at 65°30′N 25°25′W. The 2024 eclipse's point is 25.3°N 104.1°W with magnitude 1.0566.
- Self-check against Moon.js and Sky.js at all 913 eclipses from 1900 to 2100:
  - Solar: the Sun–Moon separation is at most 1.54°. It stays under 1.5° for central eclipses and under 1.6° for grazing partial ones, whose geometric separation alone reaches about 1.55°.
  - Lunar: the elongation is at least 178.42°. The tests use the matching bounds.
  - The catalogue's sub-lunar point agrees with Moon.js within 1.2°.
- Over the whole span the self-check degrades to 5.7° before 1600, because Moon.js has no secular terms. This affects only `visibleFrom` for ancient eclipses.

## AstroAlmanac.js (imports Astro.js, AstroEvents.js, Moon.js, AstroEclipses.js)

`events(fromMs, toMs, options)` returns events sorted by time: `{ kind, bodies, utcMs, detail }`.

| Kind | Detail |
|---|---|
| `eclipse` | `eclipseKind`, `type`, `magnitude`, `lat`, `lon`, `approximate` |
| `season` | `key`, from `Astro.seasonMarks` |
| `moonPhase` | `phase`: `new`, `firstQuarter`, `full` or `lastQuarter` |
| `opposition` | `distanceAu` |
| `conjunction` (planet with the Sun) | `inferior`, `distanceAu`, `separation` |
| `greatestElongation` (Mercury, Venus) | `angle`, `side` |
| `planetConjunction` (least geocentric separation < 2°) | `separation`, `elongation` |
| `perihelion` / `aphelion` (Earth's centre) | `distanceAu` |

**Options:**
- `kinds`: limits the list to these kinds;
- `maxSeparation`: the limit for planet conjunctions;
- `eclipseList`: eclipses to use instead of the ones loaded in AstroEclipses.

`nearest(ms, count, options)` returns `{ previous, next }`. It widens its window from ±60 days until it has enough events.

**Method.**
- The places are geometric (no light time or aberration).
- The scan runs daily. It uses the elements at the middle of the span with the mean longitude propagated, which is within 0.002° of `Astro.position`. Each event is then refined with `Astro.position` by bisection or golden-section search.
- Earth's centre is the barycentre minus μ times the Moon's geocentric vector, with μ = GM☾/(GM⊕+GM☾) from DE440.

**Cost.** About 60 ms per year in Node once warm (the test asserts under 100 ms), and `nearest(…, 5)` takes about 37 ms. The caller caches the list, for example per year, and recomputes when the shown year changes.

**Verified.**

| Event | Result | Published | Error |
|---|---|---|---|
| Jupiter–Saturn 2020 | 6.0′, 2020-12-22 04:35 | Wikipedia: 6.1′ on 2020-12-21 18:20 | 10 h. They close at only 0.02°/day there, and Astro.js' Saturn is good to arcminutes. |
| Venus greatest elongation east, 2025 | 2025-01-10, 47.17° | 10 Jan, 47.2° | Within a day |
| Venus greatest elongation west, 2025 | 2025-06-01 02:05, 45.88° | about 04 UTC | 2 h |
| Perihelion 2025 | | USNO | 2.5 h. The perihelion is flat. |
| Perihelion 2026 | | USNO | 11 min |
| Aphelion 2025 | | USNO | 22 min |
| Aphelion 2026 | | USNO | 39 min |
| Mars opposition 2025 | 2025-01-16 02:37 | in-the-sky.org 02:38 | 1 min |
| Jupiter opposition | 2026-01-10 | 2026-01-10 | |
| Quarters, January 2026 | | USNO | Within 45 min |

Oppositions and outer-planet conjunctions agree with `AstroEvents` within 2 min. The counts per year from 2016 to 2029 are sane, and the tests assert them.

## MoonView.js (imports nothing; shared with More Weather)

`view(lat, lon, utcMs, options)` returns:

| Field | Meaning |
|---|---|
| `altitude`, `azimuth` | Topocentric and airless. Azimuth counts from north through east. |
| `apparentAltitude` | With refraction (Meeus 16.4). |
| `aboveHorizon` | The upper limb is above the refracted horizon. |
| `illuminated`, `phase`, `waxing` | The lit fraction, the phase and the waxing flag. |
| `brightLimbAngle` | χ, east of celestial north. |
| `parallacticAngle` | q. |
| `tilt` | χ − q, measured from the observer's "up" towards the left: 0 means lit on top, +90 lit on the left, −90 lit on the right. |
| `litAngle` | The same in canvas radians, as `Moon.paintMoon` takes it. |
| `distanceKm`, `angularDiameterDeg` | Topocentric. |
| `rise`, `set` | The next times within 24 h, or null. |
| `earthshine` | Illuminated fraction below 0.25. This is a drawing threshold. |

**Options:**
- `heightM`: the observer's height;
- `riseSet: false`: skips the rise/set search, which brings the cost from about 4.5 ms to 0.11 ms.

The building blocks are exported too: `moonEcliptic`, `nutation`, `sunEcliptic`, `geocentric`, `topocentric`, `horizontal`, `parallacticAngle`, `refraction` and `riseSet`.

**Formulas.** All from Meeus, *Astronomical Algorithms*:

| Quantity | Source |
|---|---|
| Moon | ch. 47 with the full tables 47.A and 47.B, transcribed from PyMeeus |
| Sun | ch. 25 (low accuracy) |
| Nutation and obliquity | ch. 22 |
| Sidereal time | eq. 12.4 |
| Parallax | Done with vectors, observer position from ch. 11 |
| Altitude and azimuth | ch. 13 |
| q | eq. 14.1 |
| Lit fraction and χ | eqs. 48.2–48.5 |
| Rise/set | Upper limb with 34′ refraction. An hourly table of the series, a 10-minute scan, then bisection. |

TT = UTC + 69.184 s.

**Verified.**
- Meeus examples 47.a, 22.a, 25.a and 12.a.
- JPL Horizons, airless apparent topocentric, every 3 h on 2026-03-03, 2026-06-15 and 2026-10-05 from Berlin and Sydney (48 rows):

| Quantity | Worst error |
|---|---|
| Altitude | 0.0011° |
| Azimuth (along the sky) | 0.0012° |
| Lit fraction | 0.00004 |
| Bright limb | 0.55° |
| Distance | 34 km |
| Diameter | 0.2″ |

- USNO rise and set for the same six days: worst error 0.37 min.
- The fixture is `tests/fixtures/moonview-reference.json`, fetched by `tools/fetch-moonview-fixture.py`.

## AstroLapse.js (imports AstroDate.js)

| Export | Meaning |
|---|---|
| `PRESETS`, `preset(id)`, `presetsFor("astro" or "globe")` | The ids are listed below. Each preset has `simulatedSecondsPerSecond`, `sampleMs`, the label parts and `views`. |
| `advance(shownMs, preset, elapsedRealMs, carryMs, direction)` | `{ shownMs, carryMs, stopped }`. A sampled preset moves only in whole days and keeps the clock time, so the globe shows the seasons. Pass `carryMs` back in on the next call. The lapse stops at 3000 BC and 3000 AD. |
| `label(preset)` | `{ amount, unit, inAmount, inUnit, sampled }` |
| `frameInterval(preset, fps)` | Real ms between frames worth drawing. For `seasonsInMinute` this is a day every 164 ms. |

The preset ids:
- `realTime`
- `dayInMinute`
- `dayIn10Seconds` (globe)
- `monthInMinute` (Astro)
- `yearInHour`
- `yearIn10Minutes`
- `yearInMinute`
- `seasonsInMinute` (globe; daily samples)

A year is the Julian year of 365.25 days.

## Sources and licences (all retrieved 2026-10-05)

- **Stars:** Yale Bright Star Catalogue, 5th revised ed. (Hoffleit & Warren 1991), CDS V/50, https://cdsarc.cds.unistra.fr/ftp/V/50/. NASA HEASARC lists it as a U.S. Government Work, public domain: https://catalog.data.gov/dataset/bright-star-catalog
- **Star names:** IAU WGSN Catalog of Star Names, https://www.pas.rochester.edu/~emamajek/WGSN/IAU-CSN.txt. Names are facts; the IAU releases its products under CC BY. Credit: "IAU Working Group on Star Names".
- **Constellation figures, Latin names and genitives:** d3-celestial © 2015 Olaf Frohn, **BSD 3-Clause** (https://github.com/ofrohn/d3-celestial, `data/constellations.lines.json` and `constellations.json`). BSD is compatible with MIT, but the copyright notice and the licence text must be shown, for example on the Sources page. Stellarium's `constellationship.fab` was not used because it is GPL.
- **Constellation boundaries:** Roman 1987, PASP 99, 695, CDS VI/42, prepared at NASA's ADC. These are the IAU 1930 (Delporte) boundaries.
- **Eclipses:** NASA Five Millennium Catalogs (Espenak & Meeus), https://eclipse.gsfc.nasa.gov/SEcat5/ and /LEcat5/. The terms ask for this acknowledgement, which the Sources page must carry: **"Eclipse Predictions by Fred Espenak (NASA's GSFC)"**. The Besselian elements of 2024-04-08 used in a test come from https://eclipse.gsfc.nasa.gov/SEbeselm/SEbeselm2001/SE2024Apr08Tbeselm.html.
- **Lunar tables 47.A and 47.B:** Meeus, as transcribed in PyMeeus (LGPL code; the table values are Meeus' published data), https://github.com/architest/pymeeus. Meeus' worked examples are reproduced in PyMeeus' doctests.
- **GM of Earth and Moon:** JPL DE440, https://ssd.jpl.nasa.gov/astro_par.html
- **Moon radius:** NASA fact sheet, https://nssdc.gsfc.nasa.gov/planetary/factsheet/moonfact.html
- **Test references:**
  - SIMBAD
  - EarthSky: sun-in-zodiac-constellations, sun-passes-into-the-constellation-gemini, and Venus 2025 (?p=384305, ?p=379683)
  - Star Walk 2025 calendar
  - Wikipedia: Zodiac; Great conjunction; Solar eclipses of 2024-04-08 and 2026-08-12; Julian year
  - USNO API: seasons and rstt/oneday
  - JPL Horizons API
  - in-the-sky.org (Mars 2025 opposition)

## Wiring notes

- **Star background in TimeAstro.qml.**
  1. Read both star files with FileViews. Call `AstroStars.stars(data)` once and `visibleStars(s, 5)` once.
  2. Each star is a direction, not a point. Project it with the camera only, with no model scale and no translation: `v = AstroView.view({x, y, z}, cam)`. Draw it at `(cx + v.x·R, cy − v.y·R)`, with R larger than the view's half-diagonal, so the stars sit on a sphere at infinity and turn with azimuth and elevation but never shift with zoom.
  3. Skip stars with `v.depth < 0` (behind the viewer) if the sphere's back half would show. With R this large the front half fills the view.
  4. Draw stars and figures first, behind the orbits.
  5. Each figure is `figureSegments` drawn as faint lines between the two projected stars. Draw a segment only if both ends are in front.
  6. Labels: `cons.latin[i]` at the mean of a figure's stars. Star names come from `s.names`.
  7. Cache the projected stars per camera change, not per time step: the stars do not move in J2000.
- **The planet's constellation in the info line.** Use `AstroStars.zodiacAt(geocentric ecliptic longitude)`, taking the longitude from `AstroEvents.elongation` (planet minus Sun) or from Astro positions. Use `constellationOf` for the strict IAU answer.
- **Almanac list UI.**
  1. Load `AstroEclipses.chunksFor(shown ± 2 years)` files lazily.
  2. Compute `AstroAlmanac.nearest(shownMs, 5)` or a year's `events(…)`, and cache it.
  3. Show previous and next events, worded from `kind`, `bodies` and `detail`.
  4. Clicking an event travels there with the existing go-to-date: `AstroDate.travelAt` from now to `utcMs`.
  5. Mark `detail.approximate` eclipses as "± ΔT".
  6. The `.pragma library` instance of AstroEclipses is shared within the QML engine, so chunks added from TimeAstro.qml are the ones AstroAlmanac sees. In Node tests, load chunks through `A.AstroEclipses`.
- **MoonView replaces the "earth" style of `Moon.moonLitAngleFor`.** That style only flips the lit side right or left by hemisphere. Wherever a place is known, both apps should use `MoonView.view(lat, lon, now).litAngle` with `illuminated` for `Moon.paintMoon`, and show `rise`, `set`, `altitude` and `azimuth` in the "as seen from here" card:
  - More Time: the Here card and the Astro info line;
  - More Weather: its moon card.

  Add `MoonView.js` to `tools/sync-shared.sh` and the shared-files test in both repositories (these existing files were not edited here). Call it with `riseSet: false` for per-frame drawing and with rise/set once a minute.
- **Time-lapse.**
  1. Drive a Timer with `AstroLapse.frameInterval(preset, 60)`.
  2. On each tick: `r = advance(shown, preset, elapsed, carry, dir)`, keep `r.carryMs`, and stop when `r.stopped`.
  3. Word the label from `label(preset)` through I18n.
