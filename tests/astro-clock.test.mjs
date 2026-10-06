// AstroClock.js: the Astro tab's scrubber.
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
