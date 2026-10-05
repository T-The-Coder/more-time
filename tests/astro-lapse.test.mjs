// AstroLapse.js: time-lapse presets, stepping, labels and frame pacing.
import { test } from "node:test"
import assert from "node:assert"
import { load } from "./load.mjs"

const L = load("AstroLapse.js")
const DAY = 86400000
const near = (a, b, eps, what = "") => assert.ok(Math.abs(a - b) <= eps, `${what} ${a} != ${b} (±${eps})`)

test("preset speeds", () => {
  near(L.preset("yearInHour").simulatedSecondsPerSecond, 8766, 1e-9)
  near(L.preset("yearIn10Minutes").simulatedSecondsPerSecond, 52596, 1e-9)
  near(L.preset("yearInMinute").simulatedSecondsPerSecond, 525960, 1e-9)
  near(L.preset("dayInMinute").simulatedSecondsPerSecond, 1440, 1e-9)
  near(L.preset("dayIn10Seconds").simulatedSecondsPerSecond, 8640, 1e-9)
  assert.equal(L.preset("nope"), null)
  assert.deepEqual(L.presetsFor("globe").map((p) => p.id), ["realTime", "dayInMinute", "dayIn10Seconds", "seasonsInMinute"])
  assert.ok(L.presetsFor("astro").every((p) => p.sampleMs === 0))
  const ids = L.PRESETS.map((p) => p.id)
  assert.equal(new Set(ids).size, ids.length)
})

test("advance: continuous presets", () => {
  const t0 = Date.UTC(2026, 9, 5, 12)
  // An hour of "a year in an hour" is a Julian year.
  let r = L.advance(t0, L.preset("yearInHour"), 3600000)
  assert.equal(r.shownMs, t0 + 365.25 * DAY)
  assert.equal(r.stopped, false)
  // Sixty frames of a second each add up the same as one minute.
  let t = t0
  for (let i = 0; i < 60; i++) t = L.advance(t, L.preset("dayInMinute"), 1000).shownMs
  assert.equal(t, t0 + DAY)
  // Backwards.
  assert.equal(L.advance(t0, L.preset("dayInMinute"), 60000, 0, -1).shownMs, t0 - DAY)
  // Negative or missing elapsed time does nothing.
  assert.equal(L.advance(t0, L.preset("dayInMinute"), -5).shownMs, t0)
})

test("advance: sampled seasons keep the clock time", () => {
  const p = L.preset("seasonsInMinute")
  const t0 = Date.UTC(2026, 2, 20, 9, 30)
  let state = { shownMs: t0, carryMs: 0 }
  // 60 fps for a minute: a year, in whole days only.
  for (let i = 0; i < 3600; i++) {
    state = L.advance(state.shownMs, p, 1000 / 60, state.carryMs)
    assert.equal((state.shownMs - t0) % DAY, 0)
  }
  near(state.shownMs - t0, 365.25 * DAY, DAY)
  assert.equal(new Date(state.shownMs).getUTCHours(), 9)
  assert.equal(new Date(state.shownMs).getUTCMinutes(), 30)
  // A frame shorter than a sample keeps the time, carrying the remainder.
  const one = L.advance(t0, p, 100, 0)
  assert.equal(one.shownMs, t0)
  near(one.carryMs, 100 * 525960, 1e-6)
  // Backwards too.
  const back = L.advance(t0, p, 1000, 0, -1)
  assert.equal((t0 - back.shownMs) % DAY, 0)
  assert.ok(back.shownMs < t0)
})

test("advance stops at the range's ends", () => {
  const r = L.advance(L.MAX_MS - DAY, L.preset("yearInMinute"), 60000)
  assert.equal(r.stopped, true)
  assert.equal(r.shownMs, L.MAX_MS)
  assert.equal(new Date(L.MAX_MS).getUTCFullYear(), 3000)
  const s = L.advance(L.MIN_MS + DAY, L.preset("yearInMinute"), 60000, 0, -1)
  assert.equal(s.stopped, true)
  assert.equal(new Date(L.MIN_MS).getUTCFullYear(), -2999)
})

test("label and frameInterval", () => {
  assert.deepEqual(L.label(L.preset("yearIn10Minutes")), { amount: 1, unit: "year", inAmount: 10, inUnit: "minute", sampled: false })
  assert.equal(L.label(L.preset("seasonsInMinute")).sampled, true)
  near(L.frameInterval(L.preset("yearInHour"), 60), 1000 / 60, 1e-9)
  near(L.frameInterval(L.preset("dayInMinute"), 30), 1000 / 30, 1e-9)
  // A day every 164 ms.
  near(L.frameInterval(L.preset("seasonsInMinute"), 60), 86400000 / 525960, 1e-9)
  near(L.frameInterval(L.preset("seasonsInMinute"), 60), 164.27, 0.01)
  near(L.frameInterval(L.preset("seasonsInMinute"), 2), 500, 1e-9)
})
