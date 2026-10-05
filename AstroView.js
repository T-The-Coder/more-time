.pragma library

// The Astro tab's picture of the solar system (TimeAstro.qml): the model
// scale, the bodies' drawn sizes, the camera and the projection to the
// canvas. Pure functions, tested in Node.
//
// Model scale: a position's distance from the Sun r (au) is drawn as
// r^0.45, its direction kept, so Mercury to Neptune fit in about 1:7 and
// every orbit keeps its true shape around the Sun's focus.
//
// Camera: it circles the Sun at `azimuth` degrees (0: looking along +y,
// the vernal point to the right; growing turns the system the other way,
// as a globe turns east) and looks down on the ecliptic from `elevation`
// degrees above it (10–80). View coordinates: x right, y up, depth towards
// the viewer.

var RAD = Math.PI / 180
var EXPONENT = 0.45
var ELEVATION_MIN = 10
var ELEVATION_MAX = 80
var ELEVATION_DEFAULT = 30

// The zoom steps: the whole system (out to Neptune), the inner system (out
// to Mars and the asteroid belt), and Earth with the Moon (for now the
// inner planets closer up; its own view comes later). extent: the model
// radius that fits the view's half size.
var ZOOMS = [
  { key: "system", extent: Math.pow(30.4, EXPONENT) * 1.04 },
  { key: "inner", extent: Math.pow(3.3, EXPONENT) * 1.04 },
  { key: "earth", extent: Math.pow(1.1, EXPONENT) * 1.08 }
]

// A distance in au as drawn (model units).
function modelDistance(r) {
  return r > 0 ? Math.pow(r, EXPONENT) : 0
}

// A position in au (from the Sun) at its model distance, same direction.
function modelPoint(p) {
  var r = Math.sqrt(p.x * p.x + p.y * p.y + p.z * p.z)
  if (!(r > 0)) return { x: 0, y: 0, z: 0 }
  var k = modelDistance(r) / r
  return { x: p.x * k, y: p.y * k, z: p.z * k }
}

// A body's drawn radius in px from its true radius in km, on a log scale:
// Mercury 4, Earth about 6, Jupiter 11, the Sun about 16.
function bodyRadius(radiusKm) {
  var r = 4 + 4.8 * Math.log(Math.max(1, radiusKm) / 2439.4) / Math.LN10
  return Math.max(3, Math.min(18, r))
}

function clampElevation(deg) {
  return Math.max(ELEVATION_MIN, Math.min(ELEVATION_MAX, Number(deg)))
}

// The camera for azimuth and elevation (degrees): sines and cosines once.
function camera(azimuth, elevation) {
  var a = Number(azimuth) * RAD
  var e = clampElevation(elevation) * RAD
  return { ca: Math.cos(a), sa: Math.sin(a), ce: Math.cos(e), se: Math.sin(e) }
}

// A model point in view coordinates: { x, y, depth }, unscaled.
function view(p, cam) {
  var x1 = p.x * cam.ca + p.y * cam.sa
  var y1 = -p.x * cam.sa + p.y * cam.ca
  return { x: x1, y: y1 * cam.se + p.z * cam.ce, depth: -y1 * cam.ce + p.z * cam.se }
}

// On the canvas: `scale` px per model unit around (cx, cy), y down.
function project(p, cam, scale, cx, cy) {
  var v = view(p, cam)
  return { x: cx + v.x * scale, y: cy - v.y * scale, depth: v.depth }
}

// Far first: the order to draw in.
function depthSorted(items) {
  return items.slice().sort(function(a, b) { return a.depth - b.depth })
}

// The signed turn from one azimuth to another the short way round.
function shortestTurn(from, to) {
  return ((to - from) % 360 + 540) % 360 - 180
}

// The body under (x, y): the nearest whose disc (radius + slack px) holds
// the point, the front one when two overlap. bodies: [{ key, x, y, r, depth }].
function hitTest(bodies, x, y, slack) {
  var best = null
  var bestScore = Infinity
  for (var i = 0; i < bodies.length; i++) {
    var b = bodies[i]
    var d = Math.sqrt((b.x - x) * (b.x - x) + (b.y - y) * (b.y - y))
    if (d > b.r + (slack || 0)) continue
    // Nearer the centre wins; at the same distance the one in front.
    var score = d - b.depth * 1e-3
    if (score < bestScore) {
      bestScore = score
      best = b
    }
  }
  return best
}

// px per model unit for a zoom step in a view of the given size: the
// step's extent fits the half width, and the half height as the ecliptic
// is foreshortened by the elevation (plus room for orbits' tilt).
function scaleFor(extent, width, height, elevation) {
  var e = clampElevation(elevation) * RAD
  var vertical = Math.sin(e) + 0.12 * Math.cos(e)
  return Math.max(1, Math.min(width / 2 / extent, height / 2 / (extent * vertical)))
}

// ---- The sky behind the model: directions on a sphere at infinity ----
// The view of the stars spans SKY_FIELD degrees across the canvas
// diagonal, at every zoom step.
var SKY_FIELD = 110

// Directions (unit vectors in the ecliptic J2000, arrays xs, ys, zs of
// length n) on a canvas w × h for the camera alone: no scale, no shift, so
// the stars turn with the view but never move with the zoom or the time.
// The camera looks along −toward (depth < 0 is ahead), so this is the sky
// behind the model as seen from the viewer, in a stereographic projection
// (shapes stay true near the edges). Returns { x, y, on }: canvas points
// and whether each is ahead and on the canvas (with `margin` px around).
// reuse: an earlier result whose arrays are filled again (no new garbage
// while the view turns).
function skyProjection(xs, ys, zs, n, cam, w, h, margin, reuse) {
  var half = Math.sqrt(w * w + h * h) / 2
  var k = half / Math.tan(SKY_FIELD / 4 * RAD)
  var cx = w / 2, cy = h / 2
  var m = margin || 0
  var out = reuse && reuse.x.length === n ? reuse : { x: new Array(n), y: new Array(n), on: new Array(n) }
  for (var i = 0; i < n; i++) {
    var x1 = xs[i] * cam.ca + ys[i] * cam.sa
    var y1 = -xs[i] * cam.sa + ys[i] * cam.ca
    var vy = y1 * cam.se + zs[i] * cam.ce
    var ahead = y1 * cam.ce - zs[i] * cam.se
    var f = k / (1 + ahead)
    var px = cx + x1 * f, py = cy - vy * f
    out.x[i] = px
    out.y[i] = py
    out.on[i] = ahead > -0.2 && px >= -m && px <= w + m && py >= -m && py <= h + m
  }
  return out
}

// The stars a figure uses, each once: [i, ...] from its segments [[i, j],
// ...] (AstroStars.figureSegments); worked out once per figure.
function figureStars(segments) {
  var seen = {}
  var out = []
  for (var s = 0; s < segments.length; s++) {
    for (var e = 0; e < 2; e++) {
      var i = segments[s][e]
      if (seen[i]) continue
      seen[i] = true
      out.push(i)
    }
  }
  return out
}

// Where a constellation's name goes: the mean of its stars (figureStars)
// that are on the canvas (projection from skyProjection), or null when
// fewer than half of them are.
function figureAnchor(stars, projection) {
  var sx = 0, sy = 0, on = 0
  for (var k = 0; k < stars.length; k++) {
    var i = stars[k]
    if (!projection.on[i]) continue
    sx += projection.x[i]
    sy += projection.y[i]
    on++
  }
  if (!on || on * 2 < stars.length) return null
  return { x: sx / on, y: sy / on }
}

if (typeof module !== "undefined") module.exports = {
  EXPONENT: EXPONENT, ELEVATION_MIN: ELEVATION_MIN, ELEVATION_MAX: ELEVATION_MAX, ELEVATION_DEFAULT: ELEVATION_DEFAULT,
  ZOOMS: ZOOMS, modelDistance: modelDistance, modelPoint: modelPoint, bodyRadius: bodyRadius,
  clampElevation: clampElevation, camera: camera, view: view, project: project, depthSorted: depthSorted,
  shortestTurn: shortestTurn, hitTest: hitTest, scaleFor: scaleFor,
  SKY_FIELD: SKY_FIELD, skyProjection: skyProjection, figureStars: figureStars, figureAnchor: figureAnchor
}
