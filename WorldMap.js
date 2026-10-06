.pragma library
.import "Sky.js" as Sky
.import "EqualEarth.js" as EqualEarth

// The world map of the World tab: its time zones and their shading, over
// the Equal Earth projection (EqualEarth.js) and the sun (Sky.js), whose
// names are kept here too. data/worldmap.json is projected already (see
// tools/build-worldmap.py, which holds the same formula). Coordinates are
// projected units, y to the north; the view flips y when it draws.

// ---- The projection and the flat day/night line: EqualEarth.js (shared
//      with More Weather). The names stay here for the views and tests.

var X_MAX = EqualEarth.X_MAX
var Y_MAX = EqualEarth.Y_MAX
function project(lat, lon) { return EqualEarth.project(lat, lon) }
function unproject(x, y) { return EqualEarth.unproject(x, y) }
function outline() { return EqualEarth.outline() }
function graticule(stepDeg) { return EqualEarth.graticule(stepDeg) }
function twilightPolygon(utcMs, elevationDeg) { return EqualEarth.twilightPolygon(utcMs, elevationDeg) }
function nightPolygon(utcMs) { return EqualEarth.nightPolygon(utcMs) }

// ---- The sun and the sky: Sky.js (shared with More Weather) ----
// The names stay here for the views and tests that use WorldMap.

function subsolarPoint(utcMs) { return Sky.subsolarPoint(utcMs) }
function twilightRings(utcMs, elevationDeg, sampleDeg) { return Sky.twilightRings(utcMs, elevationDeg, sampleDeg) }
function sunElevation(lat, lon, utcMs) { return Sky.sunElevation(lat, lon, utcMs) }
function sunTimes(lat, lon, utcMs, offsetSeconds) { return Sky.sunTimes(lat, lon, utcMs, offsetSeconds) }
function skyMix(elevationDeg) { return Sky.skyMix(elevationDeg) }
function skyColor(elevationDeg, foreground, background) { return Sky.skyColor(elevationDeg, foreground, background) }
function sunColor(foreground, background) { return Sky.sunColor(foreground, background) }
function hexRgb(hex) { return Sky.hexRgb(hex) }
function rgbHex(rgb) { return Sky.rgbHex(rgb) }
function contrast(a, b) { return Sky.contrast(a, b) }
function bandFill(name) { return Sky.bandFill(name) }
function nightFill(background) { return Sky.nightFill(background) }
function twilightLayers(options, background) { return Sky.twilightLayers(options, background) }
function twilightElevations(layers) { return Sky.twilightElevations(layers) }
function paintSun(ctx, x, y, color, background) { Sky.paintSun(ctx, x, y, color, background) }

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
  sunElevation: sunElevation, sunTimes: sunTimes, nightFill: nightFill, bandFill: bandFill, twilightLayers: twilightLayers, twilightElevations: twilightElevations,  skyMix: skyMix, skyColor: skyColor, sunColor: sunColor, contrast: contrast,
  hexRgb: hexRgb, rgbHex: rgbHex
}
