.pragma library

// The ISS for the Astro tab: its two-line element set (TLE) read and
// checked, and propagated with SGP4 (near-Earth branch only: periods under
// 225 minutes, which the ISS's 92 minutes are), as in Vallado, Crawford,
// Hujsak and Kelso, "Revisiting Spacetrack Report #3" (AIAA 2006-6753) and
// Hoots & Roehrich, Spacetrack Report #3 (1980), with the WGS-72 constants
// those use. Positions are in the TEME frame (km), turned into the place
// under the station by the sidereal time (IAU 1982). Pure functions, tested
// in Node (tests/astro-iss.test.mjs) against Spacetrack Report #3's test
// case and positions of the ISS from a second source.

var PI2 = 2 * Math.PI
var DEG = Math.PI / 180
// WGS-72 (as SGP4 is fitted): μ (km³/s²), equatorial radius (km), J2–J4.
var MU = 398600.8
var RE = 6378.135
var XKE = 60 / Math.sqrt(RE * RE * RE / MU)
var J2 = 0.001082616
var J3 = -0.00000253881
var J4 = -0.00000165597
var J3OJ2 = J3 / J2
var ISS_CATALOG = 25544

// The TLE's checksum digit: the sum of the first 68 columns' digits, a
// minus counting 1, modulo 10.
function checksum(line) {
  var sum = 0
  for (var i = 0; i < 68 && i < line.length; i++) {
    var c = line.charAt(i)
    if (c >= "0" && c <= "9") sum += c.charCodeAt(0) - 48
    else if (c === "-") sum += 1
  }
  return sum % 10
}

// " 98343-4" → 0.98343e-4: a decimal point assumed before the digits.
function impliedDecimal(text) {
  var t = String(text).trim()
  if (t === "" || /^[+-]?0+[+-]?0*$/.test(t.replace(/\s/g, ""))) return 0
  var m = t.match(/^([+-]?)(\d+)([+-]\d+)$/)
  if (!m) return NaN
  return (m[1] === "-" ? -1 : 1) * Number("0." + m[2]) * Math.pow(10, Number(m[3]))
}

// A TLE's two lines (a name line before them is allowed) read into
// elements, or { error } when it is not one: a wrong length, checksum or
// line number, or (with `catalog`) another satellite.
function parseTle(text, catalog) {
  var lines = String(text || "").split(/\r?\n/).map(function(l) { return l.replace(/\s+$/, "") })
    .filter(function(l) { return l.length > 0 })
  var l1 = null, l2 = null
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].charAt(0) === "1" && lines[i].charAt(1) === " " && i + 1 < lines.length && lines[i + 1].charAt(0) === "2") {
      l1 = lines[i]
      l2 = lines[i + 1]
      break
    }
  }
  if (!l1 || l1.length < 69 || l2.length < 69) return { error: "format" }
  if (checksum(l1) !== Number(l1.charAt(68)) || checksum(l2) !== Number(l2.charAt(68))) return { error: "checksum" }
  var number = Number(l1.slice(2, 7))
  if (number !== Number(l2.slice(2, 7))) return { error: "format" }
  if (catalog !== undefined && number !== catalog) return { error: "catalog" }
  var yy = Number(l1.slice(18, 20))
  var day = Number(l1.slice(20, 32))
  var year = yy < 57 ? 2000 + yy : 1900 + yy
  var epochMs = Date.UTC(year, 0, 1) + (day - 1) * 86400000
  var el = {
    catalog: number, epochMs: epochMs,
    bstar: impliedDecimal(l1.slice(53, 61)),
    inclo: Number(l2.slice(8, 16)) * DEG,
    nodeo: Number(l2.slice(17, 25)) * DEG,
    ecco: Number("0." + l2.slice(26, 33).trim()),
    argpo: Number(l2.slice(34, 42)) * DEG,
    mo: Number(l2.slice(43, 51)) * DEG,
    // Revolutions a day to radians a minute.
    noKozai: Number(l2.slice(52, 63)) * PI2 / 1440
  }
  for (var k in el) if (!isFinite(el[k])) return { error: "format" }
  return el
}

function fmod(a, b) {
  return a - b * Math.floor(a / b)
}

// SGP4's initialisation for the near-Earth case: the constants of the
// propagation from the elements.
function init(el) {
  var s = {}
  var x2o3 = 2 / 3
  var ecco = el.ecco, inclo = el.inclo
  var eccsq = ecco * ecco
  var omeosq = 1 - eccsq
  var rteosq = Math.sqrt(omeosq)
  var cosio = Math.cos(inclo)
  var cosio2 = cosio * cosio
  // Un-Kozai the mean motion.
  var ak = Math.pow(XKE / el.noKozai, x2o3)
  var d1 = 0.75 * J2 * (3 * cosio2 - 1) / (rteosq * omeosq)
  var del = d1 / (ak * ak)
  var adel = ak * (1 - del * del - del * (1 / 3 + 134 * del * del / 81))
  del = d1 / (adel * adel)
  var no = el.noKozai / (1 + del)
  var ao = Math.pow(XKE / no, x2o3)
  var sinio = Math.sin(inclo)
  var po = ao * omeosq
  var con42 = 1 - 5 * cosio2
  var con41 = -con42 - cosio2 - cosio2
  var posq = po * po
  var rp = ao * (1 - ecco)

  var ss = 78 / RE + 1
  var qzms2t = Math.pow((120 - 78) / RE, 4)
  s.isimp = rp < 220 / RE + 1
  var sfour = ss
  var qzms24 = qzms2t
  var perige = (rp - 1) * RE
  if (perige < 156) {
    sfour = perige - 78
    if (perige < 98) sfour = 20
    qzms24 = Math.pow((120 - sfour) / RE, 4)
    sfour = sfour / RE + 1
  }
  var pinvsq = 1 / posq
  var tsi = 1 / (ao - sfour)
  var eta = ao * ecco * tsi
  var etasq = eta * eta
  var eeta = ecco * eta
  var psisq = Math.abs(1 - etasq)
  var coef = qzms24 * Math.pow(tsi, 4)
  var coef1 = coef / Math.pow(psisq, 3.5)
  var cc2 = coef1 * no * (ao * (1 + 1.5 * etasq + eeta * (4 + etasq))
    + 0.375 * J2 * tsi / psisq * con41 * (8 + 3 * etasq * (8 + etasq)))
  var cc1 = el.bstar * cc2
  var cc3 = ecco > 1e-4 ? -2 * coef * tsi * J3OJ2 * no * sinio / ecco : 0
  var x1mth2 = 1 - cosio2
  var cc4 = 2 * no * coef1 * ao * omeosq * (eta * (2 + 0.5 * etasq) + ecco * (0.5 + 2 * etasq)
    - J2 * tsi / (ao * psisq) * (-3 * con41 * (1 - 2 * eeta + etasq * (1.5 - 0.5 * eeta))
      + 0.75 * x1mth2 * (2 * etasq - eeta * (1 + etasq)) * Math.cos(2 * el.argpo)))
  var cc5 = 2 * coef1 * ao * omeosq * (1 + 2.75 * (etasq + eeta) + eeta * etasq)
  var cosio4 = cosio2 * cosio2
  var temp1 = 1.5 * J2 * pinvsq * no
  var temp2 = 0.5 * temp1 * J2 * pinvsq
  var temp3 = -0.46875 * J4 * pinvsq * pinvsq * no
  s.mdot = no + 0.5 * temp1 * rteosq * con41 + 0.0625 * temp2 * rteosq * (13 - 78 * cosio2 + 137 * cosio4)
  s.argpdot = -0.5 * temp1 * con42 + 0.0625 * temp2 * (7 - 114 * cosio2 + 395 * cosio4)
    + temp3 * (3 - 36 * cosio2 + 49 * cosio4)
  var xhdot1 = -temp1 * cosio
  s.nodedot = xhdot1 + (0.5 * temp2 * (4 - 19 * cosio2) + 2 * temp3 * (3 - 7 * cosio2)) * cosio
  s.omgcof = el.bstar * cc3 * Math.cos(el.argpo)
  s.xmcof = ecco > 1e-4 ? -x2o3 * coef * el.bstar / eeta : 0
  s.nodecf = 3.5 * omeosq * xhdot1 * cc1
  s.t2cof = 1.5 * cc1
  s.xlcof = Math.abs(cosio + 1) > 1.5e-12
    ? -0.25 * J3OJ2 * sinio * (3 + 5 * cosio) / (1 + cosio)
    : -0.25 * J3OJ2 * sinio * (3 + 5 * cosio) / 1.5e-12
  s.aycof = -0.5 * J3OJ2 * sinio
  s.delmo = Math.pow(1 + eta * Math.cos(el.mo), 3)
  s.sinmao = Math.sin(el.mo)
  s.x7thm1 = 7 * cosio2 - 1
  if (!s.isimp) {
    var cc1sq = cc1 * cc1
    s.d2 = 4 * ao * tsi * cc1sq
    var temp = s.d2 * tsi * cc1 / 3
    s.d3 = (17 * ao + sfour) * temp
    s.d4 = 0.5 * temp * ao * tsi * (221 * ao + 31 * sfour) * cc1
    s.t3cof = s.d2 + 2 * cc1sq
    s.t4cof = 0.25 * (3 * s.d3 + cc1 * (12 * s.d2 + 10 * cc1sq))
    s.t5cof = 0.2 * (3 * s.d4 + 12 * cc1 * s.d3 + 6 * s.d2 * s.d2 + 15 * cc1sq * (2 * s.d2 + cc1sq))
  }
  s.no = no
  s.cc1 = cc1
  s.cc4 = cc4
  s.cc5 = cc5
  s.eta = eta
  s.con41 = con41
  s.x1mth2 = x1mth2
  s.el = el
  return s
}

// The position and velocity t minutes after the epoch: { r: [x, y, z] km,
// v: [x, y, z] km/s } in TEME, or null when the orbit has decayed.
function propagate(s, t) {
  var el = s.el
  var bstar = el.bstar
  var xmdf = el.mo + s.mdot * t
  var argpdf = el.argpo + s.argpdot * t
  var nodedf = el.nodeo + s.nodedot * t
  var argpm = argpdf
  var mm = xmdf
  var t2 = t * t
  var nodem = nodedf + s.nodecf * t2
  var tempa = 1 - s.cc1 * t
  var tempe = bstar * s.cc4 * t
  var templ = s.t2cof * t2
  if (!s.isimp) {
    var delomg = s.omgcof * t
    var delm = s.xmcof * (Math.pow(1 + s.eta * Math.cos(xmdf), 3) - s.delmo)
    var temp = delomg + delm
    mm = xmdf + temp
    argpm = argpdf - temp
    var t3 = t2 * t, t4 = t3 * t
    tempa = tempa - s.d2 * t2 - s.d3 * t3 - s.d4 * t4
    tempe = tempe + bstar * s.cc5 * (Math.sin(mm) - s.sinmao)
    templ = templ + s.t3cof * t3 + t4 * (s.t4cof + t * s.t5cof)
  }
  var am = Math.pow(XKE / s.no, 2 / 3) * tempa * tempa
  var nm = XKE / Math.pow(am, 1.5)
  var em = el.ecco - tempe
  if (em >= 1 || em < -0.001 || am < 0.95) return null
  if (em < 1e-6) em = 1e-6
  mm = mm + s.no * templ
  var xlm = mm + argpm + nodem
  nodem = fmod(nodem, PI2)
  argpm = fmod(argpm, PI2)
  xlm = fmod(xlm, PI2)
  mm = fmod(xlm - argpm - nodem, PI2)
  var inclm = el.inclo
  var sinip = Math.sin(inclm), cosip = Math.cos(inclm)

  // Long-period periodics.
  var axnl = em * Math.cos(argpm)
  var temp0 = 1 / (am * (1 - em * em))
  var aynl = em * Math.sin(argpm) + temp0 * s.aycof
  var xl = mm + argpm + nodem + temp0 * s.xlcof * axnl
  // Kepler's equation in the form u = E + aynl·cos E − axnl·sin E.
  var u = fmod(xl - nodem, PI2)
  var eo1 = u
  var tem5 = 9999.9
  var sineo1 = 0, coseo1 = 0
  for (var ktr = 1; Math.abs(tem5) >= 1e-12 && ktr <= 10; ktr++) {
    sineo1 = Math.sin(eo1)
    coseo1 = Math.cos(eo1)
    tem5 = 1 - coseo1 * axnl - sineo1 * aynl
    tem5 = (u - aynl * coseo1 + axnl * sineo1 - eo1) / tem5
    if (Math.abs(tem5) >= 0.95) tem5 = tem5 > 0 ? 0.95 : -0.95
    eo1 += tem5
  }
  // Short-period periodics.
  var ecose = axnl * coseo1 + aynl * sineo1
  var esine = axnl * sineo1 - aynl * coseo1
  var el2 = axnl * axnl + aynl * aynl
  var pl = am * (1 - el2)
  if (pl < 0) return null
  var rl = am * (1 - ecose)
  var rdotl = Math.sqrt(am) * esine / rl
  var rvdotl = Math.sqrt(pl) / rl
  var betal = Math.sqrt(1 - el2)
  var temp4 = esine / (1 + betal)
  var sinu = am / rl * (sineo1 - aynl - axnl * temp4)
  var cosu = am / rl * (coseo1 - axnl + aynl * temp4)
  var su = Math.atan2(sinu, cosu)
  var sin2u = (cosu + cosu) * sinu
  var cos2u = 1 - 2 * sinu * sinu
  var tp = 1 / pl
  var tp1 = 0.5 * J2 * tp
  var tp2 = tp1 * tp
  var mrt = rl * (1 - 1.5 * tp2 * betal * s.con41) + 0.5 * tp1 * s.x1mth2 * cos2u
  su = su - 0.25 * tp2 * s.x7thm1 * sin2u
  var xnode = nodem + 1.5 * tp2 * cosip * sin2u
  var xinc = inclm + 1.5 * tp2 * cosip * sinip * cos2u
  var mvt = rdotl - nm * tp1 * s.x1mth2 * sin2u / XKE
  var rvdot = rvdotl + nm * tp1 * (s.x1mth2 * cos2u + 1.5 * s.con41) / XKE
  var sinsu = Math.sin(su), cossu = Math.cos(su)
  var snod = Math.sin(xnode), cnod = Math.cos(xnode)
  var sini = Math.sin(xinc), cosi = Math.cos(xinc)
  var xmx = -snod * cosi, xmy = cnod * cosi
  var ux = xmx * sinsu + cnod * cossu
  var uy = xmy * sinsu + snod * cossu
  var uz = sini * sinsu
  var vx = xmx * cossu - cnod * sinsu
  var vy = xmy * cossu - snod * sinsu
  var vz = sini * cossu
  if (mrt < 1) return null
  var vkms = RE * XKE / 60
  return {
    r: [mrt * ux * RE, mrt * uy * RE, mrt * uz * RE],
    v: [(mvt * ux + rvdot * vx) * vkms, (mvt * uy + rvdot * vy) * vkms, (mvt * uz + rvdot * vz) * vkms]
  }
}

// Greenwich mean sidereal time (IAU 1982, as Vallado's gstime), radians.
function gmst(utcMs) {
  var jd = utcMs / 86400000 + 2440587.5
  var t = (jd - 2451545.0) / 36525
  var sec = -6.2e-6 * t * t * t + 0.093104 * t * t + (876600 * 3600 + 8640184.812866) * t + 67310.54841
  return fmod(sec * DEG / 240, PI2)
}

// The place under the station and its height: { lat, lon (degrees, east),
// altitude (km above the WGS-84 ellipsoid) } from a TEME position at a
// moment. Geodetic latitude by a few fixed-point steps.
function subPoint(r, utcMs) {
  var g = gmst(utcMs)
  var x = r[0] * Math.cos(g) + r[1] * Math.sin(g)
  var y = -r[0] * Math.sin(g) + r[1] * Math.cos(g)
  var z = r[2]
  var a = 6378.137, f = 1 / 298.257223563
  var e2 = f * (2 - f)
  var p = Math.sqrt(x * x + y * y)
  var lat = Math.atan2(z, p * (1 - e2))
  var n = a
  for (var i = 0; i < 6; i++) {
    var sl = Math.sin(lat)
    n = a / Math.sqrt(1 - e2 * sl * sl)
    lat = Math.atan2(z + e2 * n * sl, p)
  }
  var altitude = p / Math.cos(lat) - n
  return { lat: lat / DEG, lon: Math.atan2(y, x) / DEG, altitude: altitude }
}

// The station at a moment from parsed elements (and init's constants,
// computed when not given): { lat, lon, altitude, r (TEME km), v, minutes
// since the epoch, periodMinutes } or null.
function stationAt(el, utcMs, state) {
  var s = state || init(el)
  var t = (utcMs - el.epochMs) / 60000
  var pv = propagate(s, t)
  if (!pv) return null
  var sub = subPoint(pv.r, utcMs)
  return { lat: sub.lat, lon: sub.lon, altitude: sub.altitude, r: pv.r, v: pv.v, minutes: t, periodMinutes: PI2 / s.no }
}

// One orbit's ground track from a moment: `count` places { lat, lon }.
function groundTrack(el, utcMs, count, state) {
  var s = state || init(el)
  var n = Math.max(8, count || 90)
  var period = PI2 / s.no
  var out = []
  for (var i = 0; i <= n; i++) {
    var ms = utcMs + i * period / n * 60000
    var pv = propagate(s, (ms - el.epochMs) / 60000)
    if (!pv) break
    var sub = subPoint(pv.r, ms)
    out.push({ lat: sub.lat, lon: sub.lon })
  }
  return out
}

if (typeof module !== "undefined") module.exports = {
  ISS_CATALOG: ISS_CATALOG, RE: RE, XKE: XKE, checksum: checksum, impliedDecimal: impliedDecimal, parseTle: parseTle,
  init: init, propagate: propagate, gmst: gmst, subPoint: subPoint, stationAt: stationAt, groundTrack: groundTrack
}
