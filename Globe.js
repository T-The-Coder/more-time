.pragma library

// The globe of the World tab: an orthographic view of the earth with the
// equator through the middle, turned about the polar axis so that longitude
// `centerLon` faces the viewer. Coordinates are relative to the globe's
// centre, y to the north; the view flips y when it draws.
//
// Horizon clipping: with the view on the equator, the front hemisphere is
// exactly the band of longitudes centerLon ± 90°, at every latitude, and its
// horizon (the rim) is the pair of meridians centerLon ± 90°. So polygons are
// clipped in latitude/longitude, as on a plain lat/lon grid, against that
// band (once for each copy of it 360° apart that a ring touches):
//  - fills (zones, land, night, twilight): Sutherland–Hodgman against the
//    two meridians; the cut runs along the rim, where the new edges are
//    sampled every few degrees so they follow the circle. A concave ring
//    may leave a zero-width bridge along the rim; it has no area and lies
//    under the rim's stroke. Clipping commutes with the even-odd rule, so
//    holes and the twilight bands stay right.
//  - strokes (coastlines): the ring is cut into the visible runs of its
//    edges, never joined along the rim, and edges that are seams of the
//    data (along ±180° or a pole) are left out.
// Every edge is sampled to at most STEP degrees before projecting, so
// parallels and meridians (straight in the data) come out as curves.

var RAD = Math.PI / 180
var STEP = 2

// Longitude in [-180, 180).
function wrapLon(lon) {
  return ((lon + 180) % 360 + 360) % 360 - 180
}

function projectOrtho(lat, lon, centerLon, radius) {
  var phi = lat * RAD
  var d = (lon - centerLon) * RAD
  var c = Math.cos(phi)
  return { x: radius * c * Math.sin(d), y: radius * Math.sin(phi), visible: c * Math.cos(d) >= -1e-9 }
}

// The place under a point of the view, null off the globe.
function unprojectOrtho(x, y, centerLon, radius) {
  if (!(radius > 0)) return null
  var r2 = x * x + y * y
  if (r2 > radius * radius) return null
  var z = Math.sqrt(radius * radius - r2)
  var lat = Math.asin(Math.max(-1, Math.min(1, y / radius))) / RAD
  return { lat: lat, lon: wrapLon(centerLon + Math.atan2(x, z) / RAD) }
}

// The signed turn from one longitude to another the short way round.
function shortestTurn(fromLon, toLon) {
  return wrapLon(toLon - fromLon)
}

// ---- The data file's rings, once in lat/lon ----

// A ring of data/worldmap.json (projected integers × scale) as a flat
// [lat0, lon0, lat1, lon1, ...] array, edges sampled to STEP degrees.
// `unproject` is WorldMap.unproject; points a rounding step outside the
// map's outline are pulled in.
function ringLatLon(ring, scale, unproject) {
  var out = []
  var last = null
  for (var i = 0; i < ring.length; i += 2) {
    var x = ring[i] / scale
    var y = ring[i + 1] / scale
    var p = unproject(x, y)
    if (!p) p = unproject(x * 0.9999, y * 0.9999)
    if (!p) continue
    var lat = Math.max(-90, Math.min(90, p.lat))
    var lon = Math.max(-180, Math.min(180, p.lon))
    if (Math.abs(lon) > 179.95) lon = lon < 0 ? -180 : 180
    if (Math.abs(lat) > 89.95) lat = lat < 0 ? -90 : 90
    if (last) appendSampled(out, last[0], last[1], lat, lon)
    out.push(lat, lon)
    last = [lat, lon]
  }
  if (last && out.length > 2) appendSampled(out, last[0], last[1], out[0], out[1])
  return out
}

// The points strictly between two, every STEP degrees at most.
function appendSampled(out, lat0, lon0, lat1, lon1) {
  var n = Math.ceil(Math.max(Math.abs(lat1 - lat0), Math.abs(lon1 - lon0)) / STEP)
  for (var k = 1; k < n; k++) out.push(lat0 + (lat1 - lat0) * k / n, lon0 + (lon1 - lon0) * k / n)
}

// A prepared ring: the flat array and its longitude range.
function prepare(flat) {
  var lo = Infinity
  var hi = -Infinity
  for (var i = 1; i < flat.length; i += 2) {
    if (flat[i] < lo) lo = flat[i]
    if (flat[i] > hi) hi = flat[i]
  }
  // Sines and cosines per point, so a ring wholly on the front projects
  // with multiplications only, frame after frame.
  var n = flat.length / 2
  var cosLat = new Array(n), sinLat = new Array(n), cosLon = new Array(n), sinLon = new Array(n)
  for (var k = 0; k < n; k++) {
    cosLat[k] = Math.cos(flat[k * 2] * RAD)
    sinLat[k] = Math.sin(flat[k * 2] * RAD)
    cosLon[k] = Math.cos(flat[k * 2 + 1] * RAD)
    sinLon[k] = Math.sin(flat[k * 2 + 1] * RAD)
  }
  var seams = false
  for (var m = 0; m < n && !seams; m++) {
    var m2 = (m + 1) % n
    seams = seam(flat[m * 2], flat[m * 2 + 1], flat[m2 * 2], flat[m2 * 2 + 1])
  }
  return { p: flat, lo: lo, hi: hi, seams: seams, cosLat: cosLat, sinLat: sinLat, cosLon: cosLon, sinLon: sinLon }
}

// A ring wholly on the front, projected from its cached sines and cosines.
function projectWhole(ring, centerLon, radius) {
  var cc = Math.cos(centerLon * RAD)
  var sc = Math.sin(centerLon * RAD)
  var n = ring.cosLat.length
  var xy = new Array(n * 2)
  for (var i = 0; i < n; i++) {
    xy[i * 2] = radius * ring.cosLat[i] * (ring.sinLon[i] * cc - ring.cosLon[i] * sc)
    xy[i * 2 + 1] = radius * ring.sinLat[i]
  }
  return xy
}

// From a list of {lat, lon} points (WorldMap.twilightRings).
function prepareLatLon(points) {
  var flat = []
  for (var i = 0; i < points.length; i++) {
    if (i > 0) appendSampled(flat, points[i - 1].lat, points[i - 1].lon, points[i].lat, points[i].lon)
    flat.push(points[i].lat, points[i].lon)
  }
  if (points.length > 2) appendSampled(flat, points[points.length - 1].lat, points[points.length - 1].lon, points[0].lat, points[0].lon)
  return prepare(flat)
}

// The whole data file in lat/lon, cached for the process (a .pragma
// library is shared by every view). The key is cheap but tells files apart.
var cache = { key: "", land: null, zones: null }

function dataKey(data) {
  var first = data.land && data.land[0] ? data.land[0].slice(0, 4).join(",") : ""
  return [data.version, data.scale, data.land ? data.land.length : 0, data.zones ? data.zones.length : 0, first].join("|")
}

function prepareData(data, unproject) {
  if (!data || !data.land || !data.zones) return null
  var key = dataKey(data)
  if (cache.key === key && cache.land) return cache
  var scale = data.scale || 10000
  var land = []
  for (var l = 0; l < data.land.length; l++) land.push(prepare(ringLatLon(data.land[l], scale, unproject)))
  var zones = []
  for (var z = 0; z < data.zones.length; z++) {
    var rings = []
    for (var r = 0; r < data.zones[z].r.length; r++) rings.push(prepare(ringLatLon(data.zones[z].r[r], scale, unproject)))
    zones.push({ o: data.zones[z].o, rings: rings })
  }
  cache = { key: key, land: land, zones: zones }
  return cache
}

// ---- Clipping to the front hemisphere ----

// The copies k of the visible band [c − 90 + 360k, c + 90 + 360k] that a
// longitude range touches.
function bands(lo, hi, centerLon) {
  var c = wrapLon(centerLon)
  var list = []
  var first = Math.ceil((lo - c - 90) / 360)
  var last = Math.floor((hi - c + 90) / 360)
  for (var k = first; k <= last; k++) list.push([c - 90 + 360 * k, c + 90 + 360 * k])
  return list
}

// One Sutherland–Hodgman pass over a flat lat/lon ring: keep lon ≥ limit
// (side 1) or lon ≤ limit (side −1).
function clipPass(flat, limit, side) {
  var out = []
  var n = flat.length / 2
  if (n < 3) return out
  for (var i = 0; i < n; i++) {
    var j = (i + n - 1) % n
    var lat0 = flat[j * 2], lon0 = flat[j * 2 + 1]
    var lat1 = flat[i * 2], lon1 = flat[i * 2 + 1]
    var in0 = (lon0 - limit) * side >= 0
    var in1 = (lon1 - limit) * side >= 0
    if (in0 !== in1) {
      var t = (limit - lon0) / (lon1 - lon0)
      out.push(lat0 + (lat1 - lat0) * t, limit)
    }
    if (in1) out.push(lat1, lon1)
  }
  return out
}

// Fills: a prepared ring as polygons on the front, each a flat [x0, y0, ...]
// array relative to the centre, y north. Edges along the cut follow the rim.
function frontPolygons(ring, centerLon, radius) {
  var result = []
  var copies = bands(ring.lo, ring.hi, centerLon)
  for (var b = 0; b < copies.length; b++) {
    var lo = copies[b][0]
    var hi = copies[b][1]
    if (ring.lo >= lo && ring.hi <= hi) {
      var whole = projectWhole(ring, centerLon, radius)
      if (polygonArea(whole) > 1e-6 * radius * radius) result.push(whole)
      continue
    }
    var flat = ring.p
    if (ring.lo < lo) flat = clipPass(flat, lo, 1)
    if (ring.hi > hi) flat = clipPass(flat, hi, -1)
    var n = flat.length / 2
    if (n < 3) continue
    var xy = []
    var cLon = (lo + hi) / 2
    for (var i = 0; i < n; i++) {
      var lat = flat[i * 2], lon = flat[i * 2 + 1]
      var j = (i + 1) % n
      var nextLat = flat[j * 2], nextLon = flat[j * 2 + 1]
      pushOrtho(xy, lat, lon, cLon, radius)
      // Along the rim: sample the cut so it bends with the circle.
      if ((lon === lo && nextLon === lo) || (lon === hi && nextLon === hi)) {
        var steps = Math.ceil(Math.abs(nextLat - lat) / STEP)
        for (var k = 1; k < steps; k++) pushOrtho(xy, lat + (nextLat - lat) * k / steps, lon, cLon, radius)
      }
    }
    if (polygonArea(xy) > 1e-6 * radius * radius) result.push(xy)
  }
  return result
}

function pushOrtho(xy, lat, lon, centerLon, radius) {
  var phi = lat * RAD
  var c = Math.cos(phi)
  xy.push(radius * c * Math.sin((lon - centerLon) * RAD), radius * Math.sin(phi))
}

function pushCached(xy, ring, i, cc, sc, radius) {
  xy.push(radius * ring.cosLat[i] * (ring.sinLon[i] * cc - ring.cosLon[i] * sc), radius * ring.sinLat[i])
}

function polygonArea(xy) {
  var total = 0
  for (var i = 0, j = xy.length - 2; i < xy.length; j = i, i += 2) total += xy[j] * xy[i + 1] - xy[i] * xy[j + 1]
  return Math.abs(total) / 2
}

// An edge of the data that is a seam, not a coast: along ±180° or a pole.
function seam(lat0, lon0, lat1, lon1) {
  if (Math.abs(lat0) >= 89.99 && Math.abs(lat1) >= 89.99) return true
  return Math.abs(lon0) >= 179.99 && Math.abs(lon1) >= 179.99 && lon0 * lon1 > 0
}

// Strokes: a prepared ring as the visible runs of its edges, each a flat
// [x0, y0, ...] polyline. Nothing is drawn along the rim.
function frontLines(ring, centerLon, radius) {
  var result = []
  var copies = bands(ring.lo, ring.hi, centerLon)
  var flat = ring.p
  var n = flat.length / 2
  for (var b = 0; b < copies.length; b++) {
    var lo = copies[b][0]
    var hi = copies[b][1]
    var cLon = (lo + hi) / 2
    if (ring.lo >= lo && ring.hi <= hi && !ring.seams) {
      var whole = projectWhole(ring, centerLon, radius)
      whole.push(whole[0], whole[1])
      result.push(whole)
      continue
    }
    var line = null
    var cc = Math.cos(centerLon * RAD)
    var sc = Math.sin(centerLon * RAD)
    for (var i = 0; i < n; i++) {
      var j = (i + 1) % n
      var lat0 = flat[i * 2], lon0 = flat[i * 2 + 1]
      var lat1 = flat[j * 2], lon1 = flat[j * 2 + 1]
      var t0 = 0
      var t1 = 1
      if (seam(lat0, lon0, lat1, lon1)) t0 = 2
      else if (lon1 === lon0) {
        if (lon0 < lo || lon0 > hi) t0 = 2
      } else {
        var ta = (lo - lon0) / (lon1 - lon0)
        var tb = (hi - lon0) / (lon1 - lon0)
        t0 = Math.max(0, Math.min(ta, tb))
        t1 = Math.min(1, Math.max(ta, tb))
      }
      if (t0 >= t1) {
        if (line && line.length >= 4) result.push(line)
        line = null
        continue
      }
      if (!line || t0 > 0) {
        if (line && line.length >= 4) result.push(line)
        line = []
        if (t0 === 0) pushCached(line, ring, i, cc, sc, radius)
        else pushOrtho(line, lat0 + (lat1 - lat0) * t0, lon0 + (lon1 - lon0) * t0, cLon, radius)
      }
      if (t1 === 1) pushCached(line, ring, j, cc, sc, radius)
      else pushOrtho(line, lat0 + (lat1 - lat0) * t1, lon0 + (lon1 - lon0) * t1, cLon, radius)
      if (t1 < 1) {
        if (line.length >= 4) result.push(line)
        line = null
      }
    }
    if (line && line.length >= 4) result.push(line)
  }
  return result
}

// The meridians every `step` degrees and the equator, as polylines on the
// front.
function gridLines(centerLon, radius, step) {
  var lines = []
  for (var lon = -180; lon < 180; lon += step) {
    var d = shortestTurn(centerLon, lon)
    if (Math.abs(d) > 90) continue
    var meridian = []
    for (var lat = -90; lat <= 90; lat += 3) pushOrtho(meridian, lat, d, 0, radius)
    lines.push(meridian)
  }
  var equator = []
  for (var e = -90; e <= 90; e += 3) pushOrtho(equator, 0, e, 0, radius)
  lines.push(equator)
  return lines
}

if (typeof module !== "undefined") module.exports = {
  wrapLon: wrapLon, projectOrtho: projectOrtho, unprojectOrtho: unprojectOrtho, shortestTurn: shortestTurn,
  ringLatLon: ringLatLon, prepare: prepare, prepareLatLon: prepareLatLon, prepareData: prepareData,
  frontPolygons: frontPolygons, frontLines: frontLines, gridLines: gridLines, polygonArea: polygonArea
}
