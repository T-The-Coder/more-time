// AstroDate.js: reading "Go to date" and the time-lapse travel.
import { test } from "node:test"
import assert from "node:assert"
import { load } from "./load.mjs"

const D = load("AstroDate.js")
const A = load("Astro.js")
// Parts to UTC, so the tests do not depend on this computer's zone.
const utc = (y, mo, d, h, mi) => A.utc(y, mo - 1, d) + (h * 60 + mi) * 60000
const parse = (text, order = "dmy") => D.parseDate(text, order, utc)

test("date order from the locale's format", () => {
  assert.equal(D.dateOrder("dd.MM.yyyy"), "dmy")
  assert.equal(D.dateOrder("M/d/yy"), "mdy")
  assert.equal(D.dateOrder("yyyy-MM-dd"), "ymd")
  assert.equal(D.dateOrder("yyyy/M/d"), "ymd")
  assert.equal(D.dateOrder(""), "dmy")
})

test("the accepted formats", () => {
  assert.equal(parse("1969-07-20 20:17").ms, Date.UTC(1969, 6, 20, 20, 17))
  assert.equal(parse("1969-07-20").ms, Date.UTC(1969, 6, 20))
  assert.equal(parse("20.07.1969 20:17").ms, Date.UTC(1969, 6, 20, 20, 17))
  assert.equal(parse("  3.10.2026 ").ms, Date.UTC(2026, 9, 3))
  assert.ok(parse("1969-07-20 20:17").hasTime)
  // A bare year: 1 January at noon.
  const year = parse("1969")
  assert.equal(year.ms, Date.UTC(1969, 0, 1, 12))
  assert.ok(!year.hasTime)
  // Month/day/year only where the language writes dates that way.
  assert.equal(parse("07/20/1969 20:17", "mdy").ms, Date.UTC(1969, 6, 20, 20, 17))
  assert.equal(parse("07/20/1969", "dmy").reason, "invalid")
  // Years before 100 and before Christ (astronomical: 0 is 1 BC).
  assert.equal(parse("0050-03-01").ms, A.utc(50, 2, 1))
  assert.equal(parse("-500").year, -500)
})

test("invalid dates, times and the range", () => {
  assert.equal(parse("").reason, "empty")
  assert.equal(parse("yesterday").reason, "invalid")
  assert.equal(parse("31.02.2020").reason, "invalid")
  assert.equal(parse("29.02.2023").reason, "invalid")
  assert.ok(parse("29.02.2024").ok)
  assert.equal(parse("2026-13-01").reason, "invalid")
  assert.equal(parse("2026-10-03 24:00").reason, "invalid")
  assert.equal(parse("2026-10-03 12:60").reason, "invalid")
  assert.equal(parse("3001").reason, "range")
  assert.equal(parse("-3000").reason, "range")
  assert.ok(parse("3000").ok && parse("-2999").ok)
})

test("local time by default", () => {
  // Without a converter the parts are read in this computer's zone.
  const local = D.parseDate("2026-10-03 12:00", "dmy")
  assert.equal(local.ms, new Date(2026, 9, 3, 12, 0).getTime())
})

test("the travel: eased, never going back, exactly on the target", () => {
  for (const [from, to] of [[0, 1e12], [5e11, -6e13], [1, 1]]) {
    let previous = from
    for (let t = 0; t <= 1.0001; t += 0.01) {
      const v = D.travelAt(from, to, t)
      if (to >= from) assert.ok(v >= previous - 1e-6)
      else assert.ok(v <= previous + 1e-6)
      previous = v
    }
    assert.equal(D.travelAt(from, to, 0), from)
    assert.equal(D.travelAt(from, to, 1), to)
    assert.equal(D.travelAt(from, to, 1.5), to)
  }
  assert.equal(D.ease(0.5), 0.5)
  assert.ok(D.ease(0.1) < 0.1 && D.ease(0.9) > 0.9)
})
