.pragma library
.import "Sky.js" as Sky

// The world map of the World tab: Equal Earth projection and the day/night
// line on it (the sun itself is in Sky.js). data/worldmap.json is projected already (see
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

// ---- The sun and the sky: Sky.js (shared with More Weather) ----
// The names stay here for the views and tests that use WorldMap.

function subsolarPoint(utcMs) { return Sky.subsolarPoint(utcMs) }
function twilightRings(utcMs, elevationDeg, sampleDeg) { return Sky.twilightRings(utcMs, elevationDeg, sampleDeg) }
function sunElevation(lat, lon, utcMs) { return Sky.sunElevation(lat, lon, utcMs) }
function sunTimes(lat, lon, utcMs, offsetSeconds) { return Sky.sunTimes(lat, lon, utcMs, offsetSeconds) }
function skyMix(elevationDeg) { return Sky.skyMix(elevationDeg) }
function skyColor(elevationDeg, foreground, background) { return Sky.skyColor(elevationDeg, foreground, background) }
function hexRgb(hex) { return Sky.hexRgb(hex) }
function rgbHex(rgb) { return Sky.rgbHex(rgb) }
function contrast(a, b) { return Sky.contrast(a, b) }
function bandFill(name) { return Sky.bandFill(name) }
function nightFill(background) { return Sky.nightFill(background) }
function twilightLayers(options, background) { return Sky.twilightLayers(options, background) }
function twilightElevations(layers) { return Sky.twilightElevations(layers) }
function paintSun(ctx, x, y, color) { Sky.paintSun(ctx, x, y, color) }

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

if (typeof module !== "undefined") module.exports = {
  project: project, unproject: unproject, outline: outline, graticule: graticule,
  subsolarPoint: subsolarPoint, nightPolygon: nightPolygon, twilightPolygon: twilightPolygon, twilightRings: twilightRings, ringContains: ringContains,
  zoneAt: zoneAt, zebraBand: zebraBand, X_MAX: X_MAX, Y_MAX: Y_MAX,
  sunElevation: sunElevation, sunTimes: sunTimes, nightFill: nightFill, bandFill: bandFill, twilightLayers: twilightLayers, twilightElevations: twilightElevations,  skyMix: skyMix, skyColor: skyColor, contrast: contrast,
  hexRgb: hexRgb, rgbHex: rgbHex
}
