.pragma library

// The sky events list in the Astro tab: its filters, which rows show, and
// what each event (AstroAlmanac.events) is called, as an i18n key with
// the values to fill in. No text here; TimeAstro.qml words it.

// The filters: id and the almanac kinds they show (null: all).
var FILTERS = [
  { id: "all", kinds: null },
  { id: "eclipses", kinds: ["eclipse"] },
  { id: "planets", kinds: ["opposition", "conjunction", "greatestElongation", "planetConjunction"] },
  { id: "moon", kinds: ["moonPhase"] },
  { id: "seasons", kinds: ["season", "perihelion", "aphelion"] }
]

// AstroAlmanac options for a filter id ({} for all or an unknown id).
function optionsFor(filterId) {
  for (var i = 0; i < FILTERS.length; i++)
    if (FILTERS[i].id === filterId && FILTERS[i].kinds) return { kinds: FILTERS[i].kinds.slice() }
  return {}
}

// The rows shown from AstroAlmanac.nearest(…, 6): the last `before` of
// the previous events and the first `after` of the next.
function rowsAround(near, before, after) {
  var prev = near && near.previous ? near.previous : []
  var next = near && near.next ? near.next : []
  return prev.slice(Math.max(0, prev.length - before)).concat(next.slice(0, after))
}

// An event's words: { key, bodies: { name: bodyKey }, numbers: { name:
// value }, approximate }. bodies are filled in as "astroBody_" + key,
// numbers as numbers; season and moon phase keys come whole.
function words(e) {
  var d = e.detail || {}
  var b = e.bodies || []
  switch (e.kind) {
  case "eclipse": return { key: "eclipse_" + d.eclipseKind + "_" + d.type, bodies: {}, numbers: {}, approximate: !!d.approximate }
  case "season": return { key: "astroSeason_" + d.key, bodies: {}, numbers: {}, approximate: false }
  case "moonPhase": return { key: "moonPhase_" + d.phase, bodies: {}, numbers: {}, approximate: false }
  case "opposition": return { key: "eventOpposition", bodies: { planet: b[0] }, numbers: {}, approximate: false }
  case "conjunction":
    return { key: d.inferior ? "eventConjunctionInferior" : "eventConjunctionSuperior", bodies: { planet: b[0] }, numbers: {}, approximate: false }
  case "greatestElongation":
    return { key: d.side === "east" ? "eventElongationEast" : "eventElongationWest", bodies: { planet: b[0] },
      numbers: { angle: d.angle }, approximate: false }
  case "planetConjunction":
    return { key: "eventPlanetPair", bodies: { a: b[0], b: b[1] }, numbers: { separation: d.separation }, approximate: false }
  case "perihelion": return { key: "eventPerihelion", bodies: {}, numbers: {}, approximate: false }
  case "aphelion": return { key: "eventAphelion", bodies: {}, numbers: {}, approximate: false }
  }
  return { key: "", bodies: {}, numbers: {}, approximate: false }
}

if (typeof module !== "undefined") module.exports = { FILTERS: FILTERS, optionsFor: optionsFor, rowsAround: rowsAround, words: words }
