.pragma library
.import "Astro.js" as Astro
.import "AstroEvents.js" as AstroEvents
.import "Moon.js" as Moon
.import "AstroEclipses.js" as AstroEclipses

// The sky's events in a span of time, for the Astro tab's almanac list:
// eclipses, equinoxes and solstices, the Moon's phases, the planets'
// oppositions and conjunctions with the Sun, Mercury's and Venus' greatest
// elongations, close planet–planet conjunctions and Earth's perihelion and
// aphelion, merged and sorted by time. Numbers and keys only; the QML side
// words them.
//
// An event: { kind, bodies: [keys], utcMs, detail: { numbers and keys } }
//   kind "eclipse":            bodies ["sun", "moon"], detail { eclipseKind
//                              ("solar" | "lunar"), type, magnitude, lat,
//                              lon, approximate } (AstroEclipses)
//   kind "season":             bodies ["sun"], detail { key } (marchEquinox,
//                              juneSolstice, septemberEquinox, decemberSolstice)
//   kind "moonPhase":          bodies ["moon"], detail { phase: "new" |
//                              "firstQuarter" | "full" | "lastQuarter" }
//   kind "opposition":         bodies [planet], detail { distanceAu }
//   kind "conjunction":        bodies [planet, "sun"], detail { inferior
//                              (Mercury, Venus between Earth and Sun),
//                              distanceAu, separation (° from the Sun) }
//   kind "greatestElongation": bodies [planet], detail { angle (°), side
//                              ("east": evening, "west": morning) }
//   kind "planetConjunction":  bodies [a, b], detail { separation (°, least
//                              geocentric), elongation (° of the pair from
//                              the Sun) }
//   kind "perihelion" | "aphelion": bodies ["earth"], detail { distanceAu }
//
// Method: geocentric places from Astro.js (geometric, no light time or
// aberration), sampled once a day, each event refined by bisection or a
// golden-section search to about a minute. Light time moves the published
// moments of conjunctions and elongations by minutes to an hour, which is
// below the list's precision of a day and a time. A year takes about 50 ms
// in Node; cache the list (it changes only when the span does).

var RAD = Math.PI / 180
var DAY_MS = 86400000

// The planets as seen from Earth (Astro.js's keys).
var SKY_BODIES = ["mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune"]
var INNER = ["mercury", "venus"]
var OUTER = ["mars", "jupiter", "saturn", "uranus", "neptune"]
var KINDS = ["eclipse", "season", "moonPhase", "opposition", "conjunction", "greatestElongation",
  "planetConjunction", "perihelion", "aphelion"]

// The least separation (degrees) for a planet–planet conjunction to be listed.
var PLANET_CONJUNCTION_MAX = 2

// The Moon's share of the Earth–Moon barycentre: GM(Moon) / (GM(Earth) +
// GM(Moon)) from JPL's DE440 constants (4902.800118 and 398600.435507
// km³/s², https://ssd.jpl.nasa.gov/astro_par.html, retrieved 2026-10-05).
// Earth's centre lies this fraction of the Moon's geocentric vector on the
// far side of the barycentre, which Astro.js's "earth" is; this moves
// perihelion and aphelion by hours.
var MOON_MASS_FRACTION = 4902.800118 / (398600.435507 + 4902.800118)

function wrap180(deg) {
  return ((deg + 180) % 360 + 360) % 360 - 180
}

// Earth's centre, heliocentric, ecliptic J2000, au.
function earthCentre(utcMs) {
  var b = Astro.position("earth", utcMs)
  var g = AstroEvents.moonGeocentric(utcMs)
  return { x: b.x - MOON_MASS_FRACTION * g.x, y: b.y - MOON_MASS_FRACTION * g.y, z: b.z - MOON_MASS_FRACTION * g.z }
}

// A planet's geocentric unit vector and distance, given Earth's position.
function geocentric(planet, utcMs, earth) {
  var p = Astro.position(planet, utcMs)
  var x = p.x - earth.x, y = p.y - earth.y, z = p.z - earth.z
  var r = Math.sqrt(x * x + y * y + z * z)
  return { x: x / r, y: y / r, z: z / r, r: r }
}

function angle(a, b) {
  var c = a.x * b.x + a.y * b.y + a.z * b.z
  return Math.acos(Math.max(-1, Math.min(1, c))) / RAD
}

function sunDirection(earth) {
  var r = Math.sqrt(earth.x * earth.x + earth.y * earth.y + earth.z * earth.z)
  return { x: -earth.x / r, y: -earth.y / r, z: -earth.z / r }
}

// The geocentric longitude of a planet minus the Sun's (−180…180).
function lonDiff(planet, utcMs) {
  var e = Astro.position("earth", utcMs)
  var p = Astro.position(planet, utcMs)
  return wrap180(Math.atan2(p.y - e.y, p.x - e.x) / RAD - Math.atan2(-e.y, -e.x) / RAD)
}

// The moment in [a, b] where f (continuous there) changes sign, by bisection.
function bisect(f, a, b) {
  var fa = f(a)
  for (var k = 0; k < 24 && b - a > 30000; k++) {
    var mid = (a + b) / 2
    var fm = f(mid)
    if ((fm < 0) === (fa < 0)) { a = mid; fa = fm } else b = mid
  }
  return Math.round((a + b) / 2)
}

// The moment of the least f in [a, b] by golden-section search.
function minimize(f, a, b) {
  var g = 0.6180339887
  var c = b - g * (b - a), d = a + g * (b - a)
  var fc = f(c), fd = f(d)
  for (var k = 0; k < 40 && b - a > 30000; k++) {
    if (fc < fd) { b = d; d = c; fd = fc; c = b - g * (b - a); fc = f(c) }
    else { a = c; c = d; fc = fd; d = a + g * (b - a); fd = f(d) }
  }
  return Math.round((a + b) / 2)
}

// A planet's elements for a span, for the daily scan: Astro.elementsAt at
// the span's middle with the mean longitude L then advanced at its rate.
// The other elements change by under 0.002° in a year, so the scan's
// places differ from Astro.position by about that; every event is then
// refined with Astro.position itself.
function scanElements(planet, midMs) {
  var T = Astro.julianCenturies(midMs)
  var useLong = Astro.isApproximate(midMs)
  var el = Astro.elementsAt(planet, T)
  var rate = (useLong ? Astro.ELEMENTS_LONG : Astro.ELEMENTS)[planet][1][3]
  var w = (el.peri - el.node) * RAD, O = el.node * RAD, I = el.I * RAD
  var cw = Math.cos(w), sw = Math.sin(w), cO = Math.cos(O), sO = Math.sin(O), cI = Math.cos(I), sI = Math.sin(I)
  return { T: T, M0: el.L - el.peri + el.extra, rate: rate, a: el.a, e: el.e, b: el.a * Math.sqrt(1 - el.e * el.e),
    xx: cw * cO - sw * sO * cI, xy: -sw * cO - cw * sO * cI, yx: cw * sO + sw * cO * cI, yy: -sw * sO + cw * cO * cI,
    zx: sw * sI, zy: cw * sI }
}

// The position for scanElements at a moment, written into `out`.
function scanPosition(k, utcMs, out) {
  var M = (k.M0 + k.rate * (Astro.julianCenturies(utcMs) - k.T)) % 360
  if (M > 180) M -= 360
  if (M < -180) M += 360
  var E = Astro.solveKepler(M * RAD, k.e)
  var xp = k.a * (Math.cos(E) - k.e), yp = k.b * Math.sin(E)
  out.x = k.xx * xp + k.xy * yp
  out.y = k.yx * xp + k.yy * yp
  out.z = k.zx * xp + k.zy * yp
}

// The daily samples: per day the time, the Earth–Moon barycentre's
// distance from the Sun (earthR), the Sun's direction, and per planet its
// geocentric direction (p) and longitude minus the Sun's (d, −180…180).
function samples(fromMs, toMs) {
  var mid = (fromMs + toMs) / 2
  var keys = ["earth"].concat(SKY_BODIES)
  var el = {}
  for (var i = 0; i < keys.length; i++) el[keys[i]] = scanElements(keys[i], mid)
  var out = []
  var e = { x: 0, y: 0, z: 0 }
  var q = { x: 0, y: 0, z: 0 }
  for (var t = fromMs - DAY_MS; t <= toMs + DAY_MS; t += DAY_MS) {
    scanPosition(el.earth, t, e)
    var er = Math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z)
    var sunLon = Math.atan2(-e.y, -e.x) / RAD
    var row = { t: t, earthR: er, sun: { x: -e.x / er, y: -e.y / er, z: -e.z / er }, p: {}, d: {} }
    for (i = 0; i < SKY_BODIES.length; i++) {
      scanPosition(el[SKY_BODIES[i]], t, q)
      var x = q.x - e.x, y = q.y - e.y, z = q.z - e.z
      var r = Math.sqrt(x * x + y * y + z * z)
      row.p[SKY_BODIES[i]] = { x: x / r, y: y / r, z: z / r, r: r }
      row.d[SKY_BODIES[i]] = wrap180(Math.atan2(y, x) / RAD - sunLon)
    }
    out.push(row)
  }
  return out
}

function inSpan(ms, fromMs, toMs) {
  return ms >= fromMs && ms < toMs
}

function wanted(options, kind) {
  if (!options || !options.kinds) return true
  return options.kinds.indexOf(kind) >= 0
}

// Oppositions and conjunctions with the Sun: where the longitude
// difference crosses 180° (outer planets) or 0° (all; for Mercury and
// Venus inferior or superior by the distance).
function sunEvents(rows, fromMs, toMs, options, out) {
  for (var i = 0; i < SKY_BODIES.length; i++) {
    var key = SKY_BODIES[i]
    var outer = OUTER.indexOf(key) >= 0
    var prev = null
    for (var k = 0; k < rows.length; k++) {
      var d = rows[k].d[key]
      if (prev !== null) {
        var a = rows[k - 1].t, b = rows[k].t
        // Conjunction: 0° crossed (not the ±180° wrap).
        if ((prev < 0) !== (d < 0) && Math.abs(prev - d) < 90 && wanted(options, "conjunction")) {
          var tc = bisect(function(ms) { return lonDiff(key, ms) }, a, b)
          if (inSpan(tc, fromMs, toMs)) {
            var e = Astro.position("earth", tc)
            var g = geocentric(key, tc, e)
            out.push({ kind: "conjunction", bodies: [key, "sun"], utcMs: tc,
              detail: { inferior: !outer && g.r < Math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z), distanceAu: g.r,
                separation: angle(g, sunDirection(e)) } })
          }
        }
        // Opposition: 180° crossed (the difference falls through −180 to +180).
        if (outer && prev < -90 && d > 90 && wanted(options, "opposition")) {
          var to = bisect(function(ms) { return wrap180(lonDiff(key, ms) - 180) }, a, b)
          if (inSpan(to, fromMs, toMs))
            out.push({ kind: "opposition", bodies: [key], utcMs: to,
              detail: { distanceAu: geocentric(key, to, Astro.position("earth", to)).r } })
        }
      }
      prev = d
    }
  }
}

function elongationAt(planet, ms) {
  var e = Astro.position("earth", ms)
  return angle(geocentric(planet, ms, e), sunDirection(e))
}

// Greatest elongations of Mercury and Venus: local maxima of the angle
// from the Sun in the daily samples, refined.
function elongationEvents(rows, fromMs, toMs, out) {
  for (var i = 0; i < INNER.length; i++) {
    var key = INNER[i]
    var el = []
    for (var k = 0; k < rows.length; k++) el.push(angle(rows[k].p[key], rows[k].sun))
    for (k = 1; k + 1 < rows.length; k++) {
      if (!(el[k] >= el[k - 1] && el[k] > el[k + 1])) continue
      var t = minimize(function(ms) { return -elongationAt(key, ms) }, rows[k - 1].t, rows[k + 1].t)
      if (!inSpan(t, fromMs, toMs)) continue
      out.push({ kind: "greatestElongation", bodies: [key], utcMs: t,
        detail: { angle: elongationAt(key, t), side: lonDiff(key, t) >= 0 ? "east" : "west" } })
    }
  }
}

function separationAt(a, b, ms) {
  var e = Astro.position("earth", ms)
  return angle(geocentric(a, ms, e), geocentric(b, ms, e))
}

// Close planet–planet conjunctions: local minima of the geocentric
// separation below PLANET_CONJUNCTION_MAX (or options.maxSeparation).
function planetConjunctions(rows, fromMs, toMs, options, out) {
  var limit = options && options.maxSeparation > 0 ? options.maxSeparation : PLANET_CONJUNCTION_MAX
  for (var i = 0; i < SKY_BODIES.length; i++) {
    for (var j = i + 1; j < SKY_BODIES.length; j++) {
      var a = SKY_BODIES[i], b = SKY_BODIES[j]
      var s = []
      for (var k = 0; k < rows.length; k++) s.push(angle(rows[k].p[a], rows[k].p[b]))
      for (k = 1; k + 1 < rows.length; k++) {
        // Mercury moves up to 2.2°/day against another planet: a day's
        // sample can be that far from the minimum.
        if (!(s[k] <= s[k - 1] && s[k] < s[k + 1]) || s[k] > limit + 2.5) continue
        var t = minimize(function(ms) { return separationAt(a, b, ms) }, rows[k - 1].t, rows[k + 1].t)
        var sep = separationAt(a, b, t)
        if (sep > limit || !inSpan(t, fromMs, toMs)) continue
        var e = Astro.position("earth", t)
        out.push({ kind: "planetConjunction", bodies: [a, b], utcMs: t,
          detail: { separation: sep, elongation: angle(geocentric(a, t, e), sunDirection(e)) } })
      }
    }
  }
}

function earthDistance(ms) {
  var c = earthCentre(ms)
  return Math.sqrt(c.x * c.x + c.y * c.y + c.z * c.z)
}

// Earth's perihelion and aphelion: the yearly extremes of the barycentre's
// distance in the daily samples, then the extreme of Earth's centre's
// (barycentre plus the Moon's pull, which moves it by hours)
// by golden section within ±10 days: the Moon's monthly term bends the
// distance less than the orbit does there, so it has one extreme.
function apsides(rows, fromMs, toMs, options, out) {
  for (var k = 1; k + 1 < rows.length; k++) {
    var r = rows[k].earthR
    var peri = r <= rows[k - 1].earthR && r < rows[k + 1].earthR
    var aph = r >= rows[k - 1].earthR && r > rows[k + 1].earthR
    if (!peri && !aph) continue
    var kind = peri ? "perihelion" : "aphelion"
    if (!wanted(options, kind)) continue
    var sign = peri ? 1 : -1
    var t = minimize(function(ms) { return sign * earthDistance(ms) }, rows[k].t - 10 * DAY_MS, rows[k].t + 10 * DAY_MS)
    if (inSpan(t, fromMs, toMs)) out.push({ kind: kind, bodies: ["earth"], utcMs: t, detail: { distanceAu: earthDistance(t) } })
  }
}

var PHASES = [[0, "new"], [0.25, "firstQuarter"], [0.5, "full"], [0.75, "lastQuarter"]]

// The Moon's phase points: Moon.moonPhaseFraction (as AstroEvents.nextPhase
// uses) sampled every 6 hours, each quarter crossing refined by bisection.
function phaseAhead(ms, target) {
  return wrap180((Moon.moonPhaseFraction(ms) - target) * 360)
}

function moonPhases(fromMs, toMs, out) {
  var step = 6 * 3600000
  var prev = Moon.moonPhaseFraction(fromMs)
  for (var t = fromMs; t < toMs; t += step) {
    var b = Math.min(t + step, toMs)
    var cur = Moon.moonPhaseFraction(b)
    for (var i = 0; i < PHASES.length; i++) {
      var target = PHASES[i][0]
      var va = wrap180((prev - target) * 360), vb = wrap180((cur - target) * 360)
      if (!(va < 0 && vb >= 0)) continue
      var lo = t, hi = b
      for (var k = 0; k < 24 && hi - lo > 1000; k++) {
        var mid = (lo + hi) / 2
        if (phaseAhead(mid, target) < 0) lo = mid
        else hi = mid
      }
      var at = Math.round((lo + hi) / 2)
      if (inSpan(at, fromMs, toMs)) out.push({ kind: "moonPhase", bodies: ["moon"], utcMs: at, detail: { phase: PHASES[i][1] } })
    }
    prev = cur
  }
}

function seasons(fromMs, toMs, out) {
  var y0 = new Date(fromMs).getUTCFullYear(), y1 = new Date(toMs).getUTCFullYear()
  for (var y = y0; y <= y1; y++) {
    var marks = Astro.seasonMarks(y).seasons
    for (var i = 0; i < marks.length; i++)
      if (inSpan(marks[i].utcMs, fromMs, toMs))
        out.push({ kind: "season", bodies: ["sun"], utcMs: marks[i].utcMs, detail: { key: marks[i].key } })
  }
}

function eclipses(fromMs, toMs, options, out) {
  var list = options && options.eclipseList ? options.eclipseList : AstroEclipses.between(fromMs, toMs)
  for (var i = 0; i < list.length; i++) {
    var e = list[i]
    if (!inSpan(e.utcMs, fromMs, toMs)) continue
    out.push({ kind: "eclipse", bodies: ["sun", "moon"], utcMs: e.utcMs,
      detail: { eclipseKind: e.kind, type: e.type, magnitude: e.magnitude, lat: e.lat, lon: e.lon,
        approximate: !!e.approximate } })
  }
}

// Every event with fromMs ≤ utcMs < toMs, sorted by time. options:
//   kinds: [kind, ...] to include (all when left out);
//   maxSeparation: degrees for planet–planet conjunctions (2);
//   eclipseList: eclipses to use instead of AstroEclipses' loaded ones.
// Eclipses come from the files the caller has loaded into AstroEclipses
// (chunksFor / addChunk); a span without them simply lists none.
function events(fromMs, toMs, options) {
  var out = []
  if (wanted(options, "eclipse")) eclipses(fromMs, toMs, options, out)
  if (wanted(options, "season")) seasons(fromMs, toMs, out)
  if (wanted(options, "moonPhase")) moonPhases(fromMs, toMs, out)
  var needPlanets = wanted(options, "opposition") || wanted(options, "conjunction") ||
    wanted(options, "greatestElongation") || wanted(options, "planetConjunction")
  var rows = needPlanets || wanted(options, "perihelion") || wanted(options, "aphelion") ? samples(fromMs, toMs) : []
  if (wanted(options, "opposition") || wanted(options, "conjunction")) sunEvents(rows, fromMs, toMs, options, out)
  if (wanted(options, "greatestElongation")) elongationEvents(rows, fromMs, toMs, out)
  if (wanted(options, "planetConjunction")) planetConjunctions(rows, fromMs, toMs, options, out)
  if (wanted(options, "perihelion") || wanted(options, "aphelion")) apsides(rows, fromMs, toMs, options, out)
  out.sort(function(a, b) { return a.utcMs - b.utcMs })
  return out
}

// The `count` events before `utcMs` and the `count` from it on:
// { previous: [... oldest first], next: [...] }. Widens its window (from
// ±60 days, doubling, up to ±4 years) until both sides are full.
function nearest(utcMs, count, options) {
  var n = count > 0 ? count : 5
  var half = 60 * DAY_MS
  var list = []
  for (var k = 0; k < 6; k++) {
    list = events(utcMs - half, utcMs + half, options)
    var before = 0
    for (var i = 0; i < list.length; i++) if (list[i].utcMs < utcMs) before++
    if (before >= n && list.length - before >= n) break
    half *= 2
    if (half > 4 * 366 * DAY_MS) break
  }
  var prev = [], next = []
  for (var j = 0; j < list.length; j++) (list[j].utcMs < utcMs ? prev : next).push(list[j])
  return { previous: prev.slice(Math.max(0, prev.length - n)), next: next.slice(0, n) }
}

if (typeof module !== "undefined") module.exports = {
  KINDS: KINDS, SKY_BODIES: SKY_BODIES, PLANET_CONJUNCTION_MAX: PLANET_CONJUNCTION_MAX,
  MOON_MASS_FRACTION: MOON_MASS_FRACTION, earthCentre: earthCentre, events: events, nearest: nearest
}
