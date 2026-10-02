import { test } from "node:test"
// Loose comparison: arrays made inside the loaded file belong to another
// context, so their prototype differs from this one's.
import assert from "node:assert"
import { readFileSync } from "node:fs"
import { join } from "node:path"
import { load, root } from "./load.mjs"

// Alarms ring on this computer's wall clock; the tests pin it to Berlin so
// the DST cases below mean the same everywhere.
process.env.TZ = "Europe/Berlin"
const M = load("Model.js")
const P = load("PlaceSearch.js")
const dump = readFileSync(join(root, "tests/fixtures/zdump.txt"), "utf8")
const zones = M.parseZoneDump(dump)
const utc = (...args) => Date.UTC(...args)
const local = (...args) => new Date(...args).getTime()

test("zone dump: headers and transitions", () => {
  assert.deepEqual(Object.keys(zones).sort(),
    ["America/New_York", "Asia/Kathmandu", "Asia/Tokyo", "Australia/Lord_Howe", "Europe/Berlin"])
  assert.equal(zones["Asia/Kathmandu"].offset, 5 * 3600 + 45 * 60)
  assert.equal(zones["Asia/Kathmandu"].transitions.length, 0)
  // Two lines per change, two changes a year, 2026 and 2027.
  assert.equal(zones["Europe/Berlin"].transitions.length, 8)
})

test("zone offsets across DST", () => {
  const berlin = zones["Europe/Berlin"]
  assert.equal(M.zoneOffsetAt(berlin, utc(2026, 0, 15)), 3600)
  assert.equal(M.zoneOffsetAt(berlin, utc(2026, 2, 29, 0, 59, 59)), 3600)
  assert.equal(M.zoneOffsetAt(berlin, utc(2026, 2, 29, 1, 0, 0)), 7200)
  assert.equal(M.zoneOffsetAt(berlin, utc(2026, 6, 1)), 7200)
  assert.equal(M.zoneOffsetAt(berlin, utc(2026, 9, 25, 1, 0, 0)), 3600)
  assert.equal(M.zoneStateAt(berlin, utc(2026, 6, 1)).abbr, "CEST")
  const ny = zones["America/New_York"]
  assert.equal(M.zoneOffsetAt(ny, utc(2026, 0, 15)), -5 * 3600)
  assert.equal(M.zoneOffsetAt(ny, utc(2026, 6, 15)), -4 * 3600)
  // Lord Howe moves by half an hour.
  const lh = zones["Australia/Lord_Howe"]
  assert.equal(M.zoneOffsetAt(lh, utc(2026, 1, 1)), 11 * 3600)
  assert.equal(M.zoneOffsetAt(lh, utc(2026, 5, 1)), 10.5 * 3600)
  assert.equal(M.zoneOffsetAt(zones["Asia/Kathmandu"], utc(2026, 5, 1)), 20700)
})

test("next zone change and table expiry", () => {
  const berlin = zones["Europe/Berlin"]
  assert.equal(M.nextZoneChange(berlin, utc(2026, 5, 1)), utc(2026, 9, 25, 1))
  assert.equal(M.nextZoneChange(zones["Asia/Tokyo"], utc(2026, 5, 1)), 0)
  assert.ok(M.zoneTableExpires(zones) >= utc(2027, 9, 31))
})

test("zoned parts and day difference", () => {
  const at = utc(2026, 9, 2, 21, 0)
  const tokyo = M.zonedParts(at, 9 * 3600)
  assert.equal(tokyo.day, 3)
  assert.equal(tokyo.hour, 6)
  assert.equal(M.dayDifference(at, 9 * 3600, 7200), 1)
  assert.equal(M.dayDifference(utc(2026, 9, 2, 1), -7 * 3600, 7200), -1)
})

test("offset and clock texts", () => {
  assert.equal(M.offsetText(20700), "+5:45")
  assert.equal(M.offsetText(-3 * 3600), "−3")
  assert.equal(M.offsetText(0), "±0")
  assert.equal(M.utcOffsetLabel(0), "UTC")
  assert.equal(M.utcOffsetLabel(-9.5 * 3600), "UTC−9:30")
  const parts = { hour: 0, minute: 5, second: 9 }
  assert.equal(M.clockText(parts, false, false), "00:05")
  assert.equal(M.clockText(parts, true, true, ["am", "pm"]), "12:05:09 am")
  assert.equal(M.clockText({ hour: 14, minute: 0, second: 0 }, true, false), "2:00 PM")
})

test("durations", () => {
  assert.equal(M.durationText(299001, { countdown: true }), "5:00")
  assert.equal(M.durationText(299001), "4:59")
  assert.equal(M.durationText(3723000), "1:02:03")
  assert.equal(M.durationText(12345, { hundredths: true }), "0:12.34")
  assert.equal(M.durationText(0, { countdown: true }), "0:00")
  assert.equal(M.parseDuration("90"), 90 * 60000)
  assert.equal(M.parseDuration("1:30"), 90000)
  assert.equal(M.parseDuration("1:00:00"), 3600000)
  assert.equal(M.parseDuration("1h30m"), 5400000)
  assert.equal(M.parseDuration("1h30"), 5400000)
  assert.equal(M.parseDuration("45s"), 45000)
  assert.equal(M.parseDuration("2,5"), 150000)
  assert.equal(M.parseDuration("abc"), 0)
})

test("timer entry: a length, then an optional name", () => {
  const entry = (text) => JSON.parse(JSON.stringify(M.parseTimerEntry(text)))
  assert.deepEqual(entry("10"), { ms: 600000, label: "" })
  assert.deepEqual(entry("10 Tee"), { ms: 600000, label: "Tee" })
  assert.deepEqual(entry("  1h30   Pasta al dente "), { ms: 5400000, label: "Pasta al dente" })
  assert.deepEqual(entry("1h 30 Pasta"), { ms: 5400000, label: "Pasta" })
  assert.deepEqual(entry("1:30 Eggs"), { ms: 90000, label: "Eggs" })
  assert.deepEqual(entry("45s"), { ms: 45000, label: "" })
  assert.equal(entry("10 " + "x".repeat(80)).label.length, 60)
  assert.deepEqual(entry("Tee 10"), { ms: 0, label: "" })
  assert.deepEqual(entry(""), { ms: 0, label: "" })
})

test("alarm occurrences: once, weekdays, after switching on", () => {
  const now = local(2026, 9, 2, 7, 30) // Friday
  const once = M.makeAlarm(7, 0, now)
  assert.equal(M.alarmNextOccurrence(once, now), local(2026, 9, 3, 7, 0))
  const later = M.makeAlarm(8, 15, now)
  assert.equal(M.alarmNextRing(later, now), local(2026, 9, 2, 8, 15))
  const weekdays = Object.assign(M.makeAlarm(7, 0, now), { days: [1, 2, 3, 4, 5] })
  // Friday 7:30 → Monday 7:00.
  assert.equal(M.alarmNextOccurrence(weekdays, now), local(2026, 9, 5, 7, 0))
})

test("alarm on the spring-forward night rings an hour later", () => {
  const before = local(2026, 2, 28, 22, 0)
  const alarm = M.makeAlarm(2, 30, before)
  assert.equal(new Date(M.alarmNextOccurrence(alarm, before)).getHours(), 3)
})

test("due alarm events: ring, late ring, missed, snooze", () => {
  const set = local(2026, 9, 2, 6, 0)
  const alarm = M.makeAlarm(7, 0, set)
  assert.equal(M.dueAlarmEvents(alarm, set, local(2026, 9, 2, 6, 59)).length, 0)
  const ring = M.dueAlarmEvents(alarm, local(2026, 9, 2, 6, 59, 59), local(2026, 9, 2, 7, 0, 1))
  assert.equal(ring.length, 1)
  assert.equal(ring[0].kind, "ring")
  assert.equal(ring[0].key, alarm.id + "@" + local(2026, 9, 2, 7, 0))
  assert.equal(M.dueAlarmEvents(alarm, set, local(2026, 9, 2, 7, 9))[0].kind, "ring")
  assert.equal(M.dueAlarmEvents(alarm, set, local(2026, 9, 2, 9, 0))[0].kind, "missed")
  const after = M.alarmAfterRing(alarm)
  assert.equal(after.enabled, false)
  const snoozed = M.alarmSnoozed(alarm, local(2026, 9, 2, 7, 0), 9)
  assert.equal(M.alarmNextRing(snoozed, local(2026, 9, 2, 7, 1)), local(2026, 9, 2, 7, 9))
  const snoozeEvents = M.dueAlarmEvents(snoozed, local(2026, 9, 2, 7, 8), local(2026, 9, 2, 7, 9))
  assert.equal(snoozeEvents[0].key, alarm.id + "@snooze@" + local(2026, 9, 2, 7, 9))
  // A week of a daily alarm missed is one notice.
  const daily = Object.assign(M.makeAlarm(7, 0, set), { days: [0, 1, 2, 3, 4, 5, 6] })
  const week = M.dueAlarmEvents(daily, set, local(2026, 9, 9, 12, 0))
  assert.equal(week.length, 1)
  assert.equal(week[0].at, local(2026, 9, 9, 7, 0))
})

// TimeRinger keeps its last check across a reboot, so the first check
// after a start looks back to it rather than ten minutes.
test("due alarm events: a once-alarm due while the computer was off", () => {
  const set = local(2026, 9, 1, 22, 0)
  const alarm = M.makeAlarm(7, 0, set)
  const lastCheck = local(2026, 9, 2, 6, 30) // shut down
  const boot = local(2026, 9, 2, 9, 0) // two hours after the alarm
  const events = M.dueAlarmEvents(alarm, lastCheck, boot)
  assert.equal(events.length, 1)
  assert.equal(events[0].kind, "missed")
  assert.equal(events[0].at, local(2026, 9, 2, 7, 0))
  assert.equal(M.alarmAfterRing(alarm).enabled, false)
  // The ten-minute first-start lookback alone would not see it, and the
  // alarm would ring the next morning.
  assert.equal(M.dueAlarmEvents(alarm, boot - 10 * 60000, boot).length, 0)
  assert.equal(M.alarmNextRing(alarm, boot), local(2026, 9, 3, 7, 0))
})

test("timers: start, pause, extend, finish", () => {
  const now = 1000000
  let t = M.makeTimer(300000, now)
  assert.equal(M.timerRemaining(t, now), 300000)
  t = M.timerStarted(t, now)
  assert.equal(M.timerRemaining(t, now + 60000), 240000)
  t = M.timerPaused(t, now + 60000)
  assert.equal(t.state, "paused")
  assert.equal(M.timerRemaining(t, now + 999999), 240000)
  t = M.timerToggled(t, now + 100000)
  assert.equal(t.endsAt, now + 340000)
  assert.ok(!M.timerDue(t, now + 339999))
  assert.ok(M.timerDue(t, now + 340000))
  t = M.timerFinished(t)
  assert.equal(t.state, "done")
  t = M.timerExtended(t, 60000, now + 400000)
  assert.equal(t.state, "running")
  assert.equal(t.endsAt, now + 460000)
  assert.equal(M.timerReset(t).state, "idle")
})

test("stopwatch: elapsed, laps, flags", () => {
  let s = M.makeStopwatch(0)
  s = M.stopwatchToggled(s, 1000)
  assert.equal(M.stopwatchElapsed(s, 6000), 5000)
  s = M.stopwatchLapped(s, 3000)
  s = M.stopwatchLapped(s, 7000)
  s = M.stopwatchLapped(s, 8000)
  s = M.stopwatchToggled(s, 9000)
  assert.equal(M.stopwatchElapsed(s, 99999), 8000)
  const rows = M.stopwatchLapRows(s)
  assert.equal(rows[0].number, 3)
  assert.equal(rows[0].split, 1000)
  assert.ok(rows[0].fastest)
  assert.ok(rows[1].slowest)
  assert.equal(M.stopwatchReset(s).laps.length, 0)
})

test("pomodoro: phases, long breaks, auto continue, skip", () => {
  const min = 60000
  let p = M.makePomodoro(0, { longEvery: 2 })
  assert.equal(p.work, 25)
  assert.equal(p.shortBreak, 5)
  p = M.pomodoroToggled(p, 0)
  assert.equal(p.endsAt, 25 * min)
  assert.ok(M.pomodoroDue(p, 25 * min))
  p = M.pomodoroAdvanced(p, p.endsAt, 25 * min)
  assert.equal(p.phase, "break")
  assert.equal(p.completed, 1)
  assert.equal(p.endsAt, 30 * min)
  p = M.pomodoroAdvanced(p, p.endsAt, 30 * min)
  assert.equal(p.phase, "work")
  p = M.pomodoroAdvanced(p, p.endsAt, 55 * min)
  assert.equal(p.phase, "longBreak")
  assert.equal(p.endsAt, 70 * min)
  // Woken long after: the next phase starts from now.
  p = M.pomodoroAdvanced(p, p.endsAt, 200 * min)
  assert.equal(p.endsAt, 225 * min)
  // Without auto continue it waits.
  let q = M.pomodoroToggled(M.makePomodoro(0, { autoContinue: false }), 0)
  q = M.pomodoroAdvanced(q, q.endsAt, q.endsAt)
  assert.equal(q.state, "idle")
  assert.equal(M.pomodoroRemaining(q, 0), 5 * min)
  // Skipping an idle work phase goes to the break, still idle.
  const s = M.pomodoroSkipped(M.makePomodoro(0), 0)
  assert.equal(s.phase, "break")
  assert.equal(s.state, "idle")
})

test("items file is sanitized", () => {
  const items = M.parseItems(JSON.stringify({
    alarms: [{ id: "a", hour: 99, minute: -3, days: [1, 1, 9, 3] }, null],
    timers: [{ state: "bogus", duration: "x" }],
    stopwatches: [{ laps: [1, "2", "x"] }],
    pomodoros: [{ work: 0, phase: "nap" }]
  }))
  assert.equal(items.alarms.length, 1)
  assert.equal(items.alarms[0].hour, 23)
  assert.equal(items.alarms[0].minute, 0)
  assert.deepEqual(Array.from(items.alarms[0].days), [1, 3])
  assert.equal(items.timers[0].state, "idle")
  assert.equal(items.timers[0].duration, 300000)
  assert.deepEqual(Array.from(items.stopwatches[0].laps), [1, 2])
  assert.equal(items.pomodoros[0].work, 1)
  assert.equal(items.pomodoros[0].phase, "work")
  assert.equal(M.parseItems("not json").alarms.length, 0)
})

test("item list helpers", () => {
  const list = [{ id: "a" }, { id: "b" }, { id: "c" }]
  assert.deepEqual(M.moveItem(list, "c", -1).map(x => x.id), ["a", "c", "b"])
  assert.equal(M.moveItem(list, "a", -1), list)
  assert.deepEqual(M.removeItem(list, "b").map(x => x.id), ["a", "c"])
})

test("cities: defaults, empty list, bad entries", () => {
  assert.equal(M.parseCities("", true).length, 4)
  assert.equal(M.parseCities("[]", false).length, 0)
  // The clock face style per city: one of five, else classic.
  const dials = M.parseCities(JSON.stringify([{ tz: "Asia/Tokyo", dial: "roman" }, { tz: "Europe/Paris", dial: "fancy" },
    { tz: "Europe/Rome" }, { tz: "UTC", dial: "twentyFour" }]))
  assert.deepEqual(dials.map((c) => c.dial), ["roman", "classic", "classic", "twentyFour"])
  assert.equal(M.dialStyle(undefined), "classic")
  assert.equal(M.parseCities("", true)[0].dial, "classic")
  const cities = M.parseCities(JSON.stringify([{ tz: "Asia/Tokyo" }, { tz: "x; rm -rf" }, { tz: "Europe/Paris", name: "Paris", lat: 48.85, lon: 2.35 }]))
  assert.equal(cities.length, 2)
  assert.equal(cities[0].name, "Tokyo")
  assert.equal(cities[0].lat, null)
  assert.equal(cities[1].lat, 48.85)
})

test("zone index and search", () => {
  assert.deepEqual(JSON.parse(JSON.stringify(M.parseIso6709("+404251-0740023"))),
    { lat: 40 + 42 / 60 + 51 / 3600, lon: -(74 + 0 / 60 + 23 / 3600) })
  const index = M.parseZoneIndex(
    "#c\nAD\t+4230+00131\tEurope/Andorra\nAR\t-3436-05827\tAmerica/Argentina/Buenos_Aires\nCI,BF\t+0519-00402\tAfrica/Abidjan\nDE,DK\t+5230+01322\tEurope/Berlin\tmost",
    "#c\nAD\tAndorra\nAR\tArgentina\nCI\tCôte d'Ivoire\nDE\tGermany")
  assert.equal(index.length, 4)
  assert.equal(index[1].name, "Buenos Aires")
  assert.equal(index[2].country, "Côte d'Ivoire")
  assert.equal(M.searchZoneIndex(index, "aires")[0].tz, "America/Argentina/Buenos_Aires")
  assert.equal(M.searchZoneIndex(index, "ber")[0].tz, "Europe/Berlin")
  assert.equal(M.searchZoneIndex(index, "germ")[0].tz, "Europe/Berlin")
  assert.equal(M.searchZoneIndex(index, "cote")[0].tz, "Africa/Abidjan")
  assert.equal(M.searchZoneIndex(index, "").length, 0)
})


test("calendar helpers", () => {
  assert.equal(M.isoWeek(2026, 0, 1), 1)
  assert.equal(M.isoWeek(2027, 0, 1), 53)
  assert.equal(M.dayOfYear(2026, 9, 2), 275)
})

// ---- Chimes ----

const chimes = (interval, extra) => Object.assign({ chimeInterval: interval, hourChime: "off" }, extra || {})
const plan = (settings, h, m) => {
  const p = M.chimePlan(settings, local(2026, 9, 2, h, m))
  return [p.intervalBeeps, p.hourBeeps]
}

test("chimes: quarter hours count 1 2 3 4 (the default pattern)", () => {
  const s = chimes("quarter")
  assert.deepEqual(plan(s, 10, 15), [1, 0])
  assert.deepEqual(plan(s, 10, 30), [2, 0])
  assert.deepEqual(plan(s, 10, 45), [3, 0])
  assert.deepEqual(plan(s, 11, 0), [4, 0])
  assert.deepEqual(plan(s, 11, 1), [0, 0])
  assert.deepEqual(plan(s, 11, 14), [0, 0])
})

test("chimes: off, every minute, every hour", () => {
  assert.deepEqual(plan(chimes("off"), 11, 0), [0, 0])
  assert.deepEqual(plan(chimes("minute"), 11, 7), [1, 0])
  assert.deepEqual(plan(chimes("minute"), 11, 0), [1, 0])
  assert.deepEqual(plan(chimes("hour"), 11, 0), [1, 0])
  assert.deepEqual(plan(chimes("hour"), 11, 30), [0, 0])
  assert.deepEqual(plan(chimes("bogus"), 11, 0), [0, 0])
})

test("chimes: daily at the chosen hour", () => {
  const s = chimes("daily", { chimeDailyHour: 7 })
  assert.deepEqual(plan(s, 7, 0), [1, 0])
  assert.deepEqual(plan(s, 7, 15), [0, 0])
  assert.deepEqual(plan(s, 19, 0), [0, 0])
  assert.deepEqual(plan(chimes("daily", { chimeDailyHour: 0 }), 0, 0), [1, 0])
})

test("chimes: custom intervals start again each hour, longer ones count from midnight", () => {
  const twenty = chimes("custom", { chimeMinutes: 20 })
  assert.deepEqual([0, 20, 40, 10, 59].map((m) => plan(twenty, 9, m)[0]), [1, 1, 1, 0, 0])
  // 7 does not divide 60: :56, then :00 again.
  const seven = chimes("custom", { chimeMinutes: "7" })
  assert.deepEqual([0, 7, 56, 57, 3].map((m) => plan(seven, 9, m)[0]), [1, 1, 1, 0, 0])
  const ninety = chimes("custom", { chimeMinutes: 90 })
  assert.deepEqual([[0, 0], [1, 30], [3, 0], [1, 0], [22, 30]].map(([h, m]) => plan(ninety, h, m)[0]), [1, 1, 1, 0, 1])
  assert.deepEqual(plan(chimes("custom", { chimeMinutes: 1440 }), 0, 0), [1, 0])
  assert.deepEqual(plan(chimes("custom", { chimeMinutes: 1440 }), 12, 0), [0, 0])
  assert.deepEqual(plan(chimes("custom", { chimeMinutes: 0 }), 12, 0), [0, 0])
  assert.deepEqual(plan(chimes("custom", { chimeMinutes: "x" }), 12, 0), [0, 0])
})

test("chimes: custom minutes are validated", () => {
  assert.equal(M.chimeMinutesValue("20"), 20)
  assert.equal(M.chimeMinutesValue(" 1440 "), 1440)
  assert.equal(M.chimeMinutesValue("1441"), 0)
  assert.equal(M.chimeMinutesValue("0"), 0)
  assert.equal(M.chimeMinutesValue("2.5"), 0)
  assert.equal(M.chimeMinutesValue("-5"), 0)
  assert.equal(M.chimeMinutesValue(""), 0)
  assert.equal(M.chimeMinutesValue(undefined), 0)
})

test("chimes: the hour chime on a 12- and a 24-hour dial", () => {
  const twelve = chimes("off", { hourChime: "12" })
  assert.deepEqual(plan(twelve, 0, 0), [0, 12])
  assert.deepEqual(plan(twelve, 1, 0), [0, 1])
  assert.deepEqual(plan(twelve, 12, 0), [0, 12])
  assert.deepEqual(plan(twelve, 15, 0), [0, 3])
  assert.deepEqual(plan(twelve, 15, 30), [0, 0])
  const day = chimes("quarter", { hourChime: "24" })
  assert.deepEqual(plan(day, 0, 0), [4, 24])
  assert.deepEqual(plan(day, 15, 0), [4, 15])
  assert.deepEqual(plan(day, 23, 0), [4, 23])
  assert.deepEqual(plan(day, 23, 45), [3, 0])
})

test("chimes: the next one", () => {
  const at = (h, m) => local(2026, 9, 2, h, m)
  assert.equal(M.nextChimeAt(chimes("quarter"), at(10, 15) + 1000), at(10, 30))
  assert.equal(M.nextChimeAt(chimes("quarter"), at(10, 14) + 59000), at(10, 15))
  assert.equal(M.nextChimeAt(chimes("minute"), at(10, 14) + 30000), at(10, 15))
  assert.equal(M.nextChimeAt(chimes("daily", { chimeDailyHour: 12 }), at(13, 0)), local(2026, 9, 3, 12, 0))
  assert.equal(M.nextChimeAt(chimes("custom", { chimeMinutes: 90 }), at(23, 0)), local(2026, 9, 3, 0, 0))
  assert.equal(M.nextChimeAt(chimes("off", { hourChime: "24" }), at(10, 1)), at(11, 0))
  assert.equal(M.nextChimeAt(chimes("off"), at(10, 1)), 0)
  assert.equal(M.chimesActive(chimes("off")), false)
  assert.equal(M.chimesActive(chimes("custom", { chimeMinutes: "" })), false)
  assert.equal(M.chimesActive(chimes("off", { hourChime: "12" })), true)
})

test("chimes: a minute more than 15 s old is skipped", () => {
  const minute = local(2026, 9, 2, 10, 15)
  assert.equal(M.chimeMinuteFor(minute + 300), minute)
  assert.equal(M.chimeMinuteFor(minute + 15000), minute)
  assert.equal(M.chimeMinuteFor(minute + 15001), 0)
  assert.equal(M.chimeMinuteFor(minute + 59000), 0)
})

// ---- Here ----

test("here: IP geolocation answers and the weather location", () => {
  assert.deepEqual({ ...M.ipPlace("ipwho.is", JSON.stringify({ success: true, city: "Augsburg", latitude: 48.37, longitude: 10.9 })) },
    { name: "Augsburg", lat: 48.37, lon: 10.9 })
  assert.equal(M.ipPlace("ipwho.is", JSON.stringify({ success: false, message: "reserved range" })), null)
  assert.equal(M.ipPlace("ipapi.co", JSON.stringify({ error: true, reason: "RateLimited" })), null)
  assert.deepEqual({ ...M.ipPlace("geojs", JSON.stringify({ city: "Munich", latitude: "48.14", longitude: "11.58" })) },
    { name: "Munich", lat: 48.14, lon: 11.58 })
  assert.equal(M.ipPlace("geojs", "<html>"), null)
  assert.equal(M.ipPlace("geojs", JSON.stringify({ city: "Nowhere" })), null)
  assert.deepEqual({ ...M.weatherLocation(JSON.stringify({ name: "Bobingen", latitude: 48.27091, longitude: 10.8339 })) },
    { name: "Bobingen", lat: 48.27091, lon: 10.8339 })
  assert.equal(M.weatherLocation(JSON.stringify({ name: "x", latitude: null, longitude: null })), null)
  assert.equal(M.weatherLocation(JSON.stringify({ latitude: 95, longitude: 0 })), null)
  assert.equal(M.weatherLocation(""), null)
})

// ---- Places without a zone ----

// As parseZoneIndex reads zone1970.tab: Zurich serves CH, DE (Büsingen)
// and LI, Berlin DE, DK, NO, SE, SJ.
const zoneIndex = M.parseZoneIndex([
  "CH,DE,LI\t+4723+00832\tEurope/Zurich\tBüsingen",
  "DE,DK,NO,SE,SJ\t+5230+01322\tEurope/Berlin\tmost of Germany",
  "AT\t+4813+01620\tEurope/Vienna",
  "GB,GG,IM,JE\t+513030-0000731\tEurope/London"
].join("\n"), "DE\tGermany\nCH\tSwitzerland\nAT\tAustria\nGB\tBritain (UK)")

test("places: the nearest zone by great-circle distance", () => {
  assert.ok(Math.abs(M.distanceKm(52.52, 13.405, 48.137, 11.575) - 504) < 5)
  // Bobingen is nearer to Zurich than to Berlin or Vienna.
  assert.equal(M.nearestZone(zoneIndex, 48.27, 10.83).tz, "Europe/Zurich")
  assert.equal(M.nearestZone(zoneIndex, 51.75, -1.25).tz, "Europe/London")
  // With the country: Bobingen (de) is in Europe/Berlin's Germany, although
  // Europe/Zurich (nearer) serves a German enclave too: a zone the country
  // heads wins over one that only serves it.
  assert.equal(M.nearestZone(zoneIndex, 48.27, 10.83, "de").tz, "Europe/Berlin")
  assert.deepEqual([...zoneIndex[0].codes], ["CH", "DE", "LI"])
  // A country without a zone city of its own: the nearest of all.
  assert.equal(M.nearestZone(zoneIndex, 48.27, 10.83, "fr").tz, "Europe/Zurich")
  // Served only, not headed: Liechtenstein takes Europe/Zurich.
  assert.equal(M.nearestZone(zoneIndex, 47.14, 9.52, "li").tz, "Europe/Zurich")
  assert.equal(M.nearestZone(zoneIndex, 48.27, 10.83, "").tz, "Europe/Zurich")
  assert.equal(M.nearestZone([], 0, 0), null)
  // Across the date line the distance still wraps.
  assert.equal(M.nearestZone([{ tz: "A", lat: 0, lon: 179 }, { tz: "B", lat: 0, lon: 170 }], 0, -179).tz, "A")
})

test("places: a search result as a city", () => {
  const withZone = M.cityFromPlace({ name: "Graz", region: "Styria", country: "Austria", lat: 47.0667, lon: 15.45, tz: "Europe/Vienna" }, zoneIndex)
  assert.deepEqual({ ...withZone }, { name: "Graz", country: "Styria, Austria", tz: "Europe/Vienna", lat: 47.067, lon: 15.45, tzGuessed: false })
  const guessed = M.cityFromPlace({ name: "Bobingen", region: "", country: "Deutschland", countryCode: "de", lat: 48.27, lon: 10.83, tz: "" }, zoneIndex)
  assert.equal(guessed.tz, "Europe/Berlin")
  assert.equal(guessed.tzGuessed, true)
  // A Nominatim result without a code: the plain nearest.
  assert.equal(M.cityFromPlace({ name: "Bobingen", lat: 48.27, lon: 10.83, tz: "" }, zoneIndex).tz, "Europe/Zurich")
  assert.equal(M.cityFromPlace({ name: "x", lat: 1, lon: 1, tz: "" }, []), null)
})

test("places: the zone of an imported place", () => {
  const results = [{ name: "Bobingen", lat: 48.271, lon: 10.834, tz: "Europe/Berlin" }]
  assert.equal(M.zoneForPlace(results, 48.27, 10.83, zoneIndex), "Europe/Berlin")
  // A first result far away (another Bobingen) is not trusted.
  assert.equal(M.zoneForPlace([{ name: "Bobingen", lat: 40, lon: -100, tz: "America/Denver" }], 48.27, 10.83, zoneIndex), "Europe/Zurich")
  // A close result without a zone (Nominatim) lends its country.
  assert.equal(M.zoneForPlace([{ name: "Bobingen", countryCode: "de", lat: 48.271, lon: 10.834, tz: "" }], 48.27, 10.83, zoneIndex), "Europe/Berlin")
  assert.equal(M.zoneForPlace([], 51.5, 0, zoneIndex), "Europe/London")
  assert.equal(M.zoneForPlace([], 51.5, 0, []), "")
})

test("places: More Weather's list merged into the cities", () => {
  const raw = JSON.stringify([{ name: "Bobingen", latitude: 48.27091, longitude: 10.8339 },
    { name: " ", latitude: 1, longitude: 1 }, { name: "Nowhere" }, { name: "London", latitude: 51.5072, longitude: -0.1276 },
    { name: "Reykjavík", latitude: 64.1466, longitude: -21.9426 }])
  const places = M.parseWeatherPlaces(raw)
  assert.deepEqual(places.map((p) => p.name), ["Bobingen", "London", "Reykjavík"])
  assert.deepEqual(M.parseWeatherPlaces("{"), [])
  const cities = [{ name: "London", country: "GB", tz: "Europe/London", lat: 51.508, lon: -0.126 },
    { name: "Reykjavik", country: "IS", tz: "Atlantic/Reykjavik", lat: null, lon: null }]
  const merged = M.mergeImportedPlaces(cities, [
    { ...places[0], tz: "Europe/Berlin" }, { ...places[1], tz: "Europe/London" },
    { ...places[2], tz: "Atlantic/Reykjavik" }, { name: "Bobingen", lat: 48.2709, lon: 10.834, tz: "Europe/Berlin" },
    { name: "Nozone", lat: 1, lon: 1, tz: "" }], P.samePlace)
  assert.equal(merged.added, 1)
  // London by coordinates, Reykjavík by name and zone, Bobingen twice.
  assert.equal(merged.existing, 3)
  assert.deepEqual(merged.list.map((c) => c.name), ["London", "Reykjavik", "Bobingen"])
  assert.equal(merged.list[2].lat, 48.271)
  // PlaceSearch.samePlace: the same name a few kilometres off is the same
  // place, though its coordinates round differently.
  const near = M.mergeImportedPlaces(merged.list, [{ name: "Bobingen", lat: 48.30, lon: 10.86, tz: "Europe/Zurich" }], P.samePlace)
  assert.equal(near.added, 0)
  assert.equal(near.existing, 1)
  // At most MAX_CITIES: the rest counts as full, and parseCities keeps them all.
  const many = Array.from({ length: 30 }, (_, i) => ({ name: "P" + i, lat: i, lon: i, tz: "UTC" }))
  const capped = M.mergeImportedPlaces([], many, P.samePlace)
  assert.equal(capped.added, M.MAX_CITIES)
  assert.equal(capped.full, 30 - M.MAX_CITIES)
  assert.equal(M.parseCities(JSON.stringify(capped.list)).length, M.MAX_CITIES)
})

// ---- Alarms at a place's time ----

test("alarms at a city's local time, across summer time there", () => {
  const ny = zones["America/New_York"]
  const tokyo = zones["Asia/Tokyo"]
  const daily = (tz) => ({ ...M.makeAlarm(7, 0, 0), days: [0, 1, 2, 3, 4, 5, 6], tz, placeName: "x" })
  // 07:00 in New York: 11:00 UTC on summer time, 12:00 UTC once it ends
  // (1 Nov 2026, 02:00).
  assert.equal(M.alarmNextOccurrence(daily("America/New_York"), utc(2026, 9, 31, 1), ny), utc(2026, 9, 31, 11))
  assert.equal(M.alarmNextOccurrence(daily("America/New_York"), utc(2026, 9, 31, 12), ny), utc(2026, 10, 1, 12))
  // 07:00 in Tokyo (UTC+9) is 22:00 UTC the day before.
  assert.equal(M.alarmNextOccurrence(daily("Asia/Tokyo"), utc(2026, 9, 2, 12), tokyo), utc(2026, 9, 2, 22))
  // Weekdays are Tokyo's: a Monday alarm rings Monday 07:00 there, still
  // Sunday in UTC.
  const monday = { ...daily("Asia/Tokyo"), days: [1] }
  assert.equal(M.alarmNextOccurrence(monday, utc(2026, 9, 2, 12), tokyo), utc(2026, 9, 4, 22))
  // A wall time skipped by the spring change rings an hour later: 02:30 on
  // 8 Mar 2026 in New York is 03:30 EDT = 07:30 UTC.
  assert.equal(M.zonedInstant(ny, 2026, 2, 8, 2, 30), utc(2026, 2, 8, 7, 30))
  // A wall time the autumn change doubles takes the later instant: 01:30 on
  // 1 Nov 2026 in New York is 05:30 UTC (EDT) and 06:30 UTC (EST); in Berlin
  // 02:30 on 25 Oct is 00:30 and 01:30 UTC.
  assert.equal(M.zonedInstant(ny, 2026, 10, 1, 1, 30), utc(2026, 10, 1, 6, 30))
  assert.equal(M.zonedInstant(zones["Europe/Berlin"], 2026, 9, 25, 2, 30), utc(2026, 9, 25, 1, 30))
  // Berlin's spring gap: 02:30 on 29 Mar 2026 rings at 03:30 CEST.
  assert.equal(M.zonedInstant(zones["Europe/Berlin"], 2026, 2, 29, 2, 30), utc(2026, 2, 29, 1, 30))
  // Without the zone table no time can be told; without a place, local.
  assert.equal(M.alarmNextOccurrence(daily("America/New_York"), utc(2026, 9, 31, 1), null), 0)
  assert.equal(M.alarmNextOccurrence(daily(""), local(2026, 9, 2, 6), null), local(2026, 9, 2, 7))
  // Ringing: the due event at the place's time.
  const events = M.dueAlarmEvents({ ...daily("Asia/Tokyo"), enabled: true }, utc(2026, 9, 2, 21, 55), utc(2026, 9, 2, 22, 1), tokyo)
  assert.equal(events.length, 1)
  assert.equal(events[0].at, utc(2026, 9, 2, 22))
  // The items file keeps the place, and drops a bad zone name.
  const items = M.parseItems(JSON.stringify({ alarms: [{ hour: 7, tz: "Asia/Tokyo", placeName: "Tokyo" }, { hour: 8, tz: "x; y" }] }))
  assert.deepEqual([items.alarms[0].tz, items.alarms[0].placeName, items.alarms[1].tz], ["Asia/Tokyo", "Tokyo", ""])
})

test("timer presets: a list of minutes, validated", () => {
  assert.deepEqual([...M.parseTimerPresets("1, 3, 5, 10, 15, 25, 60")], [1, 3, 5, 10, 15, 25, 60])
  assert.deepEqual([...M.parseTimerPresets("90 30;30 2")], [2, 30, 90])
  assert.equal(M.parseTimerPresets(""), null)
  assert.equal(M.parseTimerPresets("0, 5"), null)
  assert.equal(M.parseTimerPresets("5, 1441"), null)
  assert.equal(M.parseTimerPresets("5, ten"), null)
  assert.equal(M.parseTimerPresets("1,2,3,4,5,6,7,8,9,10,11,12,13"), null)
  assert.equal(M.parseTimerPresets("1,2,3,4,5,6,7,8,9,10,11,12").length, 12)
  assert.equal(M.timerPresetsText("10, 5"), "5,10")
  assert.equal(M.timerPresetsText("nonsense"), "1,3,5,10,15,25,60")
})

test("pomodoro tally: rounds per day, today and this week", () => {
  // Saturday 3 October 2026.
  const now = local(2026, 9, 3, 15)
  let log = {}
  log = M.pomodoroLogged(log, local(2026, 9, 3, 9), now)
  log = M.pomodoroLogged(log, local(2026, 9, 3, 11), now)
  log = M.pomodoroLogged(log, local(2026, 8, 28, 10), now)
  log = M.pomodoroLogged(log, local(2026, 8, 27, 10), now)
  assert.deepEqual({ ...log }, { "2026-10-03": 2, "2026-09-28": 1, "2026-09-27": 1 })
  // Week from Monday: Mon 28 Sep … Sat 3 Oct; from Sunday: Sun 27 Sep on.
  assert.deepEqual({ ...M.pomodoroTally(log, now, 1) }, { today: 2, week: 3 })
  assert.deepEqual({ ...M.pomodoroTally(log, now, 0) }, { today: 2, week: 4 })
  // Older than 60 days drops out at the next round.
  const old = M.pomodoroLogged({ "2026-07-01": 5 }, local(2026, 9, 3, 9), now)
  assert.deepEqual({ ...old }, { "2026-10-03": 1 })
  // The items file keeps it, sane.
  const items = M.parseItems(JSON.stringify({ pomodoroLog: { "2026-10-03": 4, bad: 2, "2026-10-01": -1 } }))
  assert.deepEqual({ ...items.pomodoroLog }, { "2026-10-03": 4 })
  assert.deepEqual({ ...M.pomodoroTally({}, now, 1) }, { today: 0, week: 0 })
})
