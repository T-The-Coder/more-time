// AstroEventWords.js: the Astro tab's sky events list, its filters and words.
import { test } from "node:test"
import assert from "node:assert"
import { load } from "./load.mjs"

const W = load("AstroEventWords.js")
const A = load("AstroAlmanac.js")
const english = load("I18n.js").catalog.en

test("filters: the almanac kinds they show", () => {
  assert.deepEqual(W.optionsFor("all"), {})
  assert.deepEqual(W.optionsFor("nonsense"), {})
  assert.deepEqual(W.optionsFor("eclipses"), { kinds: ["eclipse"] })
  // Every almanac kind sits in exactly one filter besides "all".
  const seen = W.FILTERS.filter((f) => f.kinds).flatMap((f) => f.kinds).sort()
  assert.deepEqual(seen, [...A.KINDS].sort())
})

test("rows: three before, six after", () => {
  const near = { previous: [1, 2, 3, 4, 5, 6], next: [7, 8, 9, 10, 11, 12, 13] }
  assert.deepEqual(W.rowsAround(near, 3, 6), [4, 5, 6, 7, 8, 9, 10, 11, 12])
  assert.deepEqual(W.rowsAround({ previous: [1], next: [] }, 3, 6), [1])
})

test("words: every event of a real year has an English text", () => {
  const events = A.events(Date.UTC(2026, 0, 1), Date.UTC(2027, 0, 1), {})
  const kinds = new Set()
  for (const e of events) {
    const w = W.words(e)
    kinds.add(e.kind)
    assert.ok(w.key && w.key in english, `${e.kind} → ${w.key}`)
    for (const body of Object.values(w.bodies)) assert.ok(`astroBody_${body}` in english, body)
  }
  for (const kind of ["season", "moonPhase", "opposition", "conjunction", "greatestElongation", "perihelion", "aphelion"])
    assert.ok(kinds.has(kind), kind)
  const elong = W.words({ kind: "greatestElongation", bodies: ["venus"], detail: { side: "west", angle: 45.9 } })
  assert.deepEqual(elong, { key: "eventElongationWest", bodies: { planet: "venus" }, numbers: { angle: 45.9 }, approximate: false })
  assert.equal(W.words({ kind: "eclipse", bodies: [], detail: { eclipseKind: "solar", type: "total", approximate: true } }).key, "eclipse_solar_total")
})
