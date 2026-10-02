.pragma library

// The world map of the World tab: Equal Earth projection, the sun's position
// and the day/night line. data/worldmap.json is projected already (see
// tools/build-worldmap.py, which holds the same formula); cities and the
// night side are projected here. Coordinates are projected units, y to the
// north; the view flips y when it draws.

var A1 = 1.340264
var A2 = -0.081106
var A3 = 0.000893
var A4 = 0.003796
var M = Math.sqrt(3) / 2
var RAD = Math.PI / 180

// Half width and half height of the whole map in projected units.
var X_MAX = 2.7066299836960743
var Y_MAX = 1.3173627591574133

function project(lat, lon) {
  var lam = lon * RAD
  var phi = Math.max(-90, Math.min(90, lat)) * RAD
  var theta = Math.asin(M * Math.sin(phi))
  var t2 = theta * theta
  var t6 = t2 * t2 * t2
  var x = 2 * Math.sqrt(3) * lam * Math.cos(theta) / (3 * (A1 + 3 * A2 * t2 + t6 * (7 * A3 + 9 * A4 * t2)))
  var y = theta * (A1 + A2 * t2 + t6 * (A3 + A4 * t2))
  return { x: x, y: y }
}

// The inverse, for hovering over the map: Newton's method on y, as in the
// published reference implementation. Null outside the map's outline.
function unproject(x, y) {
  var theta = y
  for (var i = 0; i < 12; i++) {
    var t2 = theta * theta
    var t6 = t2 * t2 * t2
    var fy = theta * (A1 + A2 * t2 + t6 * (A3 + A4 * t2)) - y
    var fpy = A1 + 3 * A2 * t2 + t6 * (7 * A3 + 9 * A4 * t2)
    var delta = fy / fpy
    theta -= delta
    if (Math.abs(delta) < 1e-9) break
  }
  var u2 = theta * theta
  var u6 = u2 * u2 * u2
  var lam = M * x * (A1 + 3 * A2 * u2 + u6 * (7 * A3 + 9 * A4 * u2)) / Math.cos(theta)
  var s = Math.sin(theta) / M
  if (Math.abs(s) > 1 || Math.abs(lam) > Math.PI + 1e-9) return null
  return { lat: Math.asin(s) / RAD, lon: lam / RAD }
}

// The map's outline: the ±180° meridians and the flat poles.
function outline() {
  var points = []
  for (var lat = -90; lat <= 90; lat += 2) points.push(project(lat, 180))
  for (lat = 90; lat >= -90; lat -= 2) points.push(project(lat, -180))
  return points
}

// Meridians every 15° (one per hour of the ideal zones) and parallels every
// 30°, as point lists.
function graticule() {
  var lines = []
  for (var lon = -165; lon <= 165; lon += 15) {
    var meridian = []
    for (var lat = -90; lat <= 90; lat += 3) meridian.push(project(lat, lon))
    lines.push(meridian)
  }
  for (lat = -60; lat <= 60; lat += 30) {
    var parallel = []
    for (lon = -180; lon <= 180; lon += 3) parallel.push(project(lat, lon))
    lines.push(parallel)
  }
  return lines
}

// Where the sun stands overhead: the sun's position from the low-precision
// formulas of the Astronomical Almanac (good to about 0.01° in declination
// for this century), its longitude against Greenwich sidereal time.
function subsolarPoint(utcMs) {
  var n = (utcMs - Date.UTC(2000, 0, 1, 12)) / 86400000
  var L = 280.460 + 0.9856474 * n
  var g = (357.528 + 0.9856003 * n) * RAD
  var lambda = (L + 1.915 * Math.sin(g) + 0.020 * Math.sin(2 * g)) * RAD
  var epsilon = (23.439 - 0.0000004 * n) * RAD
  var alpha = Math.atan2(Math.cos(epsilon) * Math.sin(lambda), Math.cos(lambda)) / RAD
  var decl = Math.asin(Math.sin(epsilon) * Math.sin(lambda)) / RAD
  var gmst = 280.46061837 + 360.98564736629 * n
  var lon = ((alpha - gmst) % 360 + 540) % 360 - 180
  return { lat: decl, lon: lon }
}

// The same areas as lat/lon rings, for the globe (TimeGlobe.qml): the area
// where the sun stands below `elevationDeg`, as lat/lon rings
// [{lat, lon}, ...] to fill with the even-odd rule. It is a spherical cap
// around the antisolar point with an angular radius of 90° + elevation:
//  - holding one pole (always at 0°): one ring, the boundary from west to
//    east sampled every 2° of longitude, closed along the dark pole and the
//    ±180° meridians (the flat map's curved edge);
//  - holding no pole (−4°, −8° near the equinoxes): one oval with
//    continuous longitudes, which may run past ±180°;
//  - holding both poles (+6° near the equinoxes): the whole globe as a
//    rectangle, then the oval of the sunlit rest (even-odd leaves it out).
function twilightRings(utcMs, elevationDeg) {
  var sun = subsolarPoint(utcMs)
  var e = Number(elevationDeg) || 0
  // A boundary right through a pole leaves the longitude undefined there
  // (and at 0° the old tangent formula infinite): keep the declination off it.
  var decl = sun.lat
  if (Math.abs(decl - e) < 0.05) decl = e + (decl < e ? -0.05 : 0.05)
  if (Math.abs(decl + e) < 0.05) decl = -e + (decl < -e ? -0.05 : 0.05)
  var latA = -decl
  var lonA = ((sun.lon + 360) % 360) - 180
  var rho = (90 + e) * RAD
  var north = decl < e
  var south = decl > -e
  var points = []
  var lat
  var lon
  if (north !== south) {
    // a sin(phi) + b cos(phi) = cos(rho): one crossing per meridian.
    var a = Math.sin(latA * RAD)
    var s = Math.cos(rho)
    var boundaryLat = function(lon) {
      var b = Math.cos(latA * RAD) * Math.cos((lon - lonA) * RAD)
      var r = Math.sqrt(a * a + b * b)
      var psi = Math.atan2(b, a)
      var base = Math.asin(Math.max(-1, Math.min(1, s / r)))
      var candidates = [base - psi, Math.PI - base - psi]
      for (var i = 0; i < 2; i++) {
        var c = Math.atan2(Math.sin(candidates[i]), Math.cos(candidates[i]))
        if (c >= -Math.PI / 2 - 1e-9 && c <= Math.PI / 2 + 1e-9) return Math.max(-90, Math.min(90, c / RAD))
      }
      return 0
    }
    for (lon = -180; lon <= 180; lon += 2) points.push({ lat: boundaryLat(lon), lon: lon })
    var pole = north ? 90 : -90
    var step = pole < 0 ? -2 : 2
    for (lat = boundaryLat(180); (lat - pole) * step < 0; lat += step) points.push({ lat: lat, lon: 180 })
    for (lon = 180; lon >= -180; lon -= 4) points.push({ lat: pole, lon: lon })
    var end = boundaryLat(-180)
    for (lat = pole; (lat - end) * -step < 0; lat -= step) points.push({ lat: lat, lon: -180 })
    return [points]
  }
  // The oval: points at rho from the antisolar point, azimuth every 2°.
  // With both poles inside, it is drawn around the sun instead.
  var cLat = north ? -latA : latA
  var cLon = north ? lonA + 180 : lonA
  var radius = north ? Math.PI - rho : rho
  var sinC = Math.sin(cLat * RAD)
  var cosC = Math.cos(cLat * RAD)
  for (var az = 0; az < 360; az += 2) {
    var t = az * RAD
    var sinLat = sinC * Math.cos(radius) + cosC * Math.sin(radius) * Math.cos(t)
    var pLat = Math.asin(Math.max(-1, Math.min(1, sinLat)))
    var dLon = Math.atan2(Math.sin(t) * Math.sin(radius) * cosC, Math.cos(radius) - sinC * sinLat)
    points.push({ lat: pLat / RAD, lon: cLon + dLon / RAD })
  }
  if (!north) return [points]
  var whole = []
  for (lat = -90; lat <= 90; lat += 2) whole.push({ lat: lat, lon: -180 })
  for (lat = 90; lat >= -90; lat -= 2) whole.push({ lat: lat, lon: 180 })
  return [whole, points]
}

// Where the sun stands below `elevationDeg`, as one closed polygon in
// projected units, for an even-odd fill clipped to the map's outline: 0 is
// the night side, −4 the end of the golden hour, −8 the end of the blue hour.
// The area is a cap around the point opposite the sun, of angular radius
// 90° + elevation. Its edge is traced every 2° of bearing with continuous
// longitudes; three copies, 360° apart, cover the map whatever the edge
// crosses (the outline clips them), joined by bridges that are walked there
// and back so they cancel out. An edge round a pole is closed along that
// pole; a cap holding both poles is the whole map minus the edge's loop.
// The signature is shared with the globe view; keep it stable.
function twilightPolygon(utcMs, elevationDeg) {
  var sun = subsolarPoint(utcMs)
  var lat0 = -sun.lat * RAD
  var lon0 = ((sun.lon + 360) % 360 - 180) * RAD
  var radius = Math.max(0.5, Math.min(179.5, 90 + Number(elevationDeg || 0))) * RAD
  // Points from the antisolar point at `radius`, longitudes unwrapped.
  var edge = []
  var previous = null
  var turn = 0
  for (var b = 0; b < 360; b += 2) {
    var bearing = b * RAD
    var lat = Math.asin(Math.sin(lat0) * Math.cos(radius) + Math.cos(lat0) * Math.sin(radius) * Math.cos(bearing))
    var lon = lon0 + Math.atan2(Math.sin(bearing) * Math.sin(radius) * Math.cos(lat0),
      Math.cos(radius) - Math.sin(lat0) * Math.sin(lat))
    lon = lon / RAD
    if (previous !== null) {
      while (lon - previous > 180) lon -= 360
      while (lon - previous < -180) lon += 360
      turn += lon - previous
    }
    edge.push({ lat: lat / RAD, lon: lon })
    previous = lon
  }
  var closing = edge[0].lon - previous
  while (closing > 180) closing -= 360
  while (closing < -180) closing += 360
  turn += closing

  var ring = edge
  var northInside = 90 - lat0 / RAD < 90 + Number(elevationDeg || 0)
  var southInside = 90 + lat0 / RAD < 90 + Number(elevationDeg || 0)
  if (Math.abs(turn) > 180) {
    // Round one pole: close along it, back to where the edge started.
    var pole = northInside ? 90 : -90
    var end = edge[edge.length - 1].lon + closing
    // Down the meridian, along the pole, up again: sampled, since a
    // meridian is curved on the map and copies meet along it.
    var down = pole > edge[0].lat ? 2 : -2
    ring = edge.slice()
    for (var m = edge[0].lat; (pole - m) * down > 0; m += down) ring.push({ lat: m, lon: end })
    var step = end > edge[0].lon ? -4 : 4
    for (var l = end; (l - edge[0].lon) * step < 0; l += step) ring.push({ lat: pole, lon: l })
    for (var u = pole; (u - edge[0].lat) * down > 0; u -= down) ring.push({ lat: u, lon: edge[0].lon })
  }

  var copies = []
  for (var c = -1; c <= 1; c++) {
    var copy = []
    for (var i = 0; i < ring.length; i++) copy.push(project(ring[i].lat, ring[i].lon + 360 * c))
    copy.push(copy[0])
    copies.push(copy)
  }
  var points = []
  // Holding both poles: the whole map, with the loop cut out.
  if (Math.abs(turn) <= 180 && northInside && southInside) {
    points.push({ x: -3 * X_MAX, y: -2 * Y_MAX }, { x: 3 * X_MAX, y: -2 * Y_MAX },
      { x: 3 * X_MAX, y: 2 * Y_MAX }, { x: -3 * X_MAX, y: 2 * Y_MAX }, { x: -3 * X_MAX, y: -2 * Y_MAX })
  }
  var anchors = []
  for (var k = 0; k < copies.length; k++) {
    anchors.push(copies[k][0])
    points = points.concat(copies[k])
  }
  // Back along the bridges to the start.
  for (var a = anchors.length - 2; a >= 0; a--) points.push(anchors[a])
  if (points.length && (points[0] !== anchors[0])) points.push(points[0])
  return points
}

// The night side (the sun below the horizon), see twilightPolygon.
function nightPolygon(utcMs) {
  return twilightPolygon(utcMs, 0)
}

// Whether a projected point lies inside a ring [x0, y0, x1, y1, ...] given in
// projected units times `scale`.
function ringContains(ring, x, y, scale) {
  var inside = false
  var px = x * scale
  var py = y * scale
  for (var i = 0, j = ring.length - 2; i < ring.length; j = i, i += 2) {
    var xi = ring[i], yi = ring[i + 1], xj = ring[j], yj = ring[j + 1]
    if ((yi > py) !== (yj > py) && px < (xj - xi) * (py - yi) / (yj - yi) + xi) inside = !inside
  }
  return inside
}

// The zone (offset in minutes) under a projected point, by the even-odd rule
// over each zone's rings; null over nothing.
function zoneAt(data, x, y) {
  if (!data || !data.zones) return null
  var scale = data.scale || 10000
  for (var z = 0; z < data.zones.length; z++) {
    var zone = data.zones[z]
    var inside = false
    for (var r = 0; r < zone.r.length; r++) if (ringContains(zone.r[r], x, y, scale)) inside = !inside
    if (inside) return zone.o
  }
  return null
}

// Zebra shading: whole-hour zones alternate by the parity of the hour,
// zones off the full hour (India, Nepal, Newfoundland …) get their own
// pattern.
function zebraBand(offsetMinutes) {
  if (offsetMinutes % 60 !== 0) return 2
  return ((offsetMinutes / 60) % 2 + 2) % 2
}

// ---- The sky over a place, for the time in the menu bar ----

// The sun's elevation above the horizon in degrees at a place and moment
// (no refraction): +90 overhead, 0 on the horizon, below zero at night.
function sunElevation(lat, lon, utcMs) {
  var sun = subsolarPoint(utcMs)
  var phi = lat * RAD
  var decl = sun.lat * RAD
  var hourAngle = (lon - sun.lon) * RAD
  var s = Math.sin(phi) * Math.sin(decl) + Math.cos(phi) * Math.cos(decl) * Math.cos(hourAngle)
  return Math.asin(Math.max(-1, Math.min(1, s))) / RAD
}

// The golden hour is the sun between GOLDEN_LOW and GOLDEN_HIGH, the blue
// hour between BLUE_LOW and GOLDEN_LOW; sunrise and sunset are the upper
// limb on the horizon (refraction included). sunTimes and the sky colour
// share these limits.
var GOLDEN_HIGH = 6
var GOLDEN_LOW = -4
var BLUE_LOW = -8
var HORIZON = -0.833

// Day, golden hour, blue hour, night, by elevation: the stops below, linear
// in between, so the colour drifts across the evening instead of jumping.
// Each change is centred on the limits above: day to gold around +6°, gold
// to blue around −4°, then blue from −8° fading into night by −14°.
var SKY_STOPS = [
  [GOLDEN_HIGH + 2, "day"], [GOLDEN_HIGH - 2, "golden"], [GOLDEN_LOW + 1, "golden"], [GOLDEN_LOW - 1, "blue"],
  [BLUE_LOW, "blue"], [BLUE_LOW - 6, "night"]
]
var SKY_COLORS = { day: "#5ea8e8", golden: "#e3a447", blue: "#3b5bd6", night: "#4a3c9a" }

// Weights of the four phases at an elevation; they add up to 1.
function skyMix(elevationDeg) {
  var mix = { day: 0, golden: 0, blue: 0, night: 0 }
  var e = Number(elevationDeg)
  if (!(e < SKY_STOPS[0][0])) { mix.day = 1; return mix }
  var last = SKY_STOPS[SKY_STOPS.length - 1]
  if (!(e > last[0])) { mix[last[1]] = 1; return mix }
  for (var i = 0; i < SKY_STOPS.length - 1; i++) {
    var high = SKY_STOPS[i]
    var low = SKY_STOPS[i + 1]
    if (e > high[0] || e < low[0]) continue
    var t = (high[0] - e) / (high[0] - low[0])
    mix[high[1]] += 1 - t
    mix[low[1]] += t
    return mix
  }
  return mix
}

function hexRgb(hex) {
  var n = parseInt(String(hex).replace("#", ""), 16)
  return [(n >> 16 & 255) / 255, (n >> 8 & 255) / 255, (n & 255) / 255]
}

function rgbHex(rgb) {
  var text = "#"
  for (var i = 0; i < 3; i++) {
    var v = Math.round(Math.max(0, Math.min(1, rgb[i])) * 255)
    text += (v < 16 ? "0" : "") + v.toString(16)
  }
  return text
}

function mixRgb(a, b, t) {
  return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t]
}

// WCAG contrast of two colours given as [r, g, b] in 0–1.
function contrast(a, b) {
  function luminance(c) {
    var l = c.map(function(v) { return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) })
    return 0.2126 * l[0] + 0.7152 * l[1] + 0.0722 * l[2]
  }
  var la = luminance(a)
  var lb = luminance(b)
  return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
}

// The sky colour for an elevation as "#rrggbb", softened a quarter towards
// the text colour like the other accents, and further (up to 60 %) until it
// reads at 3:1 on the background, so the night stays legible on a dark
// theme and the day on a light one. foreground, background: [r, g, b].
function skyColor(elevationDeg, foreground, background) {
  var mix = skyMix(elevationDeg)
  var rgb = [0, 0, 0]
  for (var phase in mix) {
    var c = hexRgb(SKY_COLORS[phase])
    for (var i = 0; i < 3; i++) rgb[i] += c[i] * mix[phase]
  }
  if (!foreground) return rgbHex(rgb)
  var t = 0.25
  var out = mixRgb(rgb, foreground, t)
  while (background && contrast(out, background) < 3 && t < 0.6) {
    t += 0.05
    out = mixRgb(rgb, foreground, t)
  }
  return rgbHex(out)
}

// The night side's fill: 70 % black and 30 % of the night sky (#4a3c9a),
// so it also shows on dark themes, where its alpha is raised too. Clearly
// darker than the twilight bands, which it covers on the night side.
// background: [r, g, b] in 0–1 (the popup's). { r, g, b, a } in 0–1.
function nightFill(background) {
  var night = hexRgb(SKY_COLORS.night)
  var bg = background || [1, 1, 1]
  var luminance = 0.2126 * bg[0] + 0.7152 * bg[1] + 0.0722 * bg[2]
  return { r: night[0] * 0.3, g: night[1] * 0.3, b: night[2] * 0.3, a: luminance < 0.5 ? 0.38 : 0.30 }
}

// The sun's day at a place: the local day containing `utcMs` (local by
// offsetSeconds), sampled every ten minutes and refined by bisection at each
// crossing. Instants in UTC ms, 0 when it does not happen that day:
//   { sunrise, sunset, goldenMorning: [start, end], goldenEvening,
//     blueMorning, blueEvening, polar: "" | "day" | "night" }
// A morning range rises through its limits, an evening one sinks.
function sunTimes(lat, lon, utcMs, offsetSeconds) {
  var offsetMs = (Number(offsetSeconds) || 0) * 1000
  var dayStart = Math.floor((utcMs + offsetMs) / 86400000) * 86400000 - offsetMs
  var step = 600000
  var samples = []
  var high = -90
  var low = 90
  for (var t = dayStart; t <= dayStart + 86400000; t += step) {
    var e = sunElevation(lat, lon, t)
    samples.push(e)
    high = Math.max(high, e)
    low = Math.min(low, e)
  }
  function crossing(limit, rising) {
    for (var i = 0; i + 1 < samples.length; i++) {
      var a = samples[i] - limit
      var b = samples[i + 1] - limit
      if (rising ? !(a < 0 && b >= 0) : !(a >= 0 && b < 0)) continue
      var from = dayStart + i * step
      var to = from + step
      for (var k = 0; k < 12; k++) {
        var mid = (from + to) / 2
        var above = sunElevation(lat, lon, mid) >= limit
        if (above === rising) to = mid
        else from = mid
      }
      return Math.round((from + to) / 2)
    }
    return 0
  }
  function range(start, end) { return start && end && end > start ? [start, end] : [0, 0] }
  return {
    sunrise: crossing(HORIZON, true),
    sunset: crossing(HORIZON, false),
    goldenMorning: range(crossing(GOLDEN_LOW, true), crossing(GOLDEN_HIGH, true)),
    goldenEvening: range(crossing(GOLDEN_HIGH, false), crossing(GOLDEN_LOW, false)),
    blueMorning: range(crossing(BLUE_LOW, true), crossing(GOLDEN_LOW, true)),
    blueEvening: range(crossing(GOLDEN_LOW, false), crossing(BLUE_LOW, false)),
    polar: low >= HORIZON ? "day" : (high < HORIZON ? "night" : "")
  }
}

if (typeof module !== "undefined") module.exports = {
  project: project, unproject: unproject, outline: outline, graticule: graticule,
  subsolarPoint: subsolarPoint, nightPolygon: nightPolygon, twilightPolygon: twilightPolygon, twilightRings: twilightRings, ringContains: ringContains,
  zoneAt: zoneAt, zebraBand: zebraBand, X_MAX: X_MAX, Y_MAX: Y_MAX,
  sunElevation: sunElevation, sunTimes: sunTimes, nightFill: nightFill, skyMix: skyMix, skyColor: skyColor, contrast: contrast,
  hexRgb: hexRgb, rgbHex: rgbHex
}
