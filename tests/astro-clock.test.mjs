// AstroClock.js: the Astro tab's time line.
import { test } from "node:test"
import assert from "node:assert"
import { load } from "./load.mjs"

const C = load("AstroClock.js")
const DAY = 86400000
const now = Date.UTC(2026, 9, 3, 17, 42, 13)

test("steps: whole days a year and a day either side, now in the middle", () => {
  const s = C.steps(now)
  assert.equal(s.length, 2 * 366 + 1)
  assert.equal(s[C.NOW_INDEX], now)
  assert.equal(s[0], now - 366 * DAY)
  assert.equal(s[C.LAST_INDEX], now + 366 * DAY)
  for (let i = 1; i < s.length; i++) assert.equal(s[i] - s[i - 1], DAY)
  // The same date a year on and back is in reach.
  assert.ok(s[0] <= Date.UTC(2025, 9, 3, 17, 42, 13) && s[C.LAST_INDEX] >= Date.UTC(2027, 9, 3, 17, 42, 13))
})

test("nearestIndex: rounds to the nearest day and clamps", () => {
  assert.equal(C.nearestIndex(now, now), C.NOW_INDEX)
  assert.equal(C.nearestIndex(now, now + 11 * 3600000), C.NOW_INDEX)
  assert.equal(C.nearestIndex(now, now + 13 * 3600000), C.NOW_INDEX + 1)
  assert.equal(C.nearestIndex(now, now - 40 * DAY), C.NOW_INDEX - 40)
  assert.equal(C.nearestIndex(now, now + 5000 * DAY), C.LAST_INDEX)
  assert.equal(C.nearestIndex(now, now - 5000 * DAY), 0)
  const s = C.steps(now)
  for (const i of [0, 17, 366, 500, 732]) assert.equal(C.nearestIndex(now, s[i]), i)
})

test("speeds: 1, 7 and 30 days a second, no tick faster than 33 ms", () => {
  assert.deepEqual(C.SPEEDS.map((s) => s.daysPerSecond), [1, 7, 30])
  for (let i = 0; i < C.SPEEDS.length; i++) {
    const t = C.timing(i)
    assert.ok(t.delay >= C.MIN_DELAY_MS && Number.isInteger(t.step) && t.step >= 1)
    // The rate comes out right to within the whole-ms delay (1 % at 30/s).
    const rate = t.step * 1000 / t.delay
    assert.ok(Math.abs(rate - C.SPEEDS[i].daysPerSecond) / C.SPEEDS[i].daysPerSecond < 0.015, `speed ${i}: ${rate}`)
  }
  assert.deepEqual({ ...C.timing(0) }, { step: 1, delay: 1000 })
  assert.deepEqual({ ...C.timing(1) }, { step: 1, delay: 143 })
  assert.deepEqual({ ...C.timing(2) }, { step: 1, delay: 33 })
  // Out-of-range indices fall back to the ends.
  assert.deepEqual({ ...C.timing(-3) }, { ...C.timing(0) })
  assert.deepEqual({ ...C.timing(9) }, { ...C.timing(2) })
})

test("advance: steps both ways and stops at the ends", () => {
  assert.deepEqual({ ...C.advance(C.NOW_INDEX, 0, 1) }, { index: C.NOW_INDEX + 1, stopped: false })
  assert.deepEqual({ ...C.advance(C.NOW_INDEX, 2, -1) }, { index: C.NOW_INDEX - 1, stopped: false })
  assert.deepEqual({ ...C.advance(C.LAST_INDEX - 1, 0, 1) }, { index: C.LAST_INDEX, stopped: true })
  assert.deepEqual({ ...C.advance(1, 1, -1) }, { index: 0, stopped: true })
  // A year forward at a month a second takes about twelve seconds.
  let state = { index: C.NOW_INDEX, stopped: false }
  let ms = 0
  while (!state.stopped) {
    state = C.advance(state.index, 2, 1)
    ms += C.timing(2).delay
  }
  assert.equal(state.index, C.LAST_INDEX)
  assert.ok(Math.abs(ms / 1000 - 366 / 30) < 0.2, `${ms} ms`)
})

test("now detection and days from now", () => {
  assert.equal(C.isNow(C.NOW_INDEX), true)
  assert.equal(C.isNow(C.NOW_INDEX + 1), false)
  assert.equal(C.daysFromNow(now, now + 12 * DAY), 12)
  assert.equal(C.daysFromNow(now, now - 3 * DAY), -3)
  assert.equal(C.daysFromNow(now, now + 2 * 3600000), 0)
})

test("label: local calendar parts by the zone's offset, no Intl", () => {
  // 2026-10-03 17:42 UTC is a Saturday; in Tokyo (+9 h) already Sunday the 4th.
  assert.deepEqual({ ...C.label(now, 0) }, { year: 2026, month: 9, day: 3, weekday: 6, hour: 17, minute: 42 })
  assert.deepEqual({ ...C.label(now, 9 * 3600) }, { year: 2026, month: 9, day: 4, weekday: 0, hour: 2, minute: 42 })
  assert.deepEqual({ ...C.label(now, -7 * 3600) }, { year: 2026, month: 9, day: 3, weekday: 6, hour: 10, minute: 42 })
  // New Year across the offset.
  assert.deepEqual({ ...C.label(Date.UTC(2026, 11, 31, 23, 30), 3600) }, { year: 2027, month: 0, day: 1, weekday: 5, hour: 0, minute: 30 })
  assert.equal(C.label(now).hour, 17, "no offset: UTC")
})
