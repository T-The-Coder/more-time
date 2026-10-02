// Pure time math for More Time: zone offsets, formatting, and the state
// machines of alarms, timers, stopwatches and pomodoros. Nothing here touches
// Qt, so the same file runs under Node's test runner (tests/model.test.mjs).
//
// Every running thing is stored as instants, never as a counter that ticks:
// a timer keeps the moment it ends, a stopwatch the moment it was started.
// That way a shell restart, a second instance (bar and app) or a suspended
// laptop all read the same, correct state from the file.

var MS_PER_SECOND = 1000
var MS_PER_MINUTE = 60000
var MS_PER_HOUR = 3600000
var MS_PER_DAY = 86400000

// A missed alarm (suspend, shell not running) still rings if it is at most
// this late; an older one only leaves a "missed" notification.
var ALARM_LATE_RING_MS = 10 * MS_PER_MINUTE

function pad2(value) {
  var n = Math.floor(Math.abs(Number(value) || 0))
  return (n < 10 ? "0" : "") + n
}

function clamp(value, low, high) {
  return Math.max(low, Math.min(high, value))
}

// ---- Calendar ------------------------------------------------------------

function isoWeek(year, month, day) {
  var date = new Date(Date.UTC(year, month, day))
  var weekday = date.getUTCDay() || 7
  date.setUTCDate(date.getUTCDate() + 4 - weekday)
  var yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1))
  return Math.ceil(((date.getTime() - yearStart.getTime()) / MS_PER_DAY + 1) / 7)
}

function dayOfYear(year, month, day) {
  return Math.round((Date.UTC(year, month, day) - Date.UTC(year, 0, 1)) / MS_PER_DAY) + 1
}

// "yyyy-MM-dd" of a local day, the identity alarms use for "already rang today".
function dayKey(year, month, day) {
  return year + "-" + pad2(Number(month) + 1) + "-" + pad2(day)
}

function localDayKey(ms) {
  var date = new Date(ms)
  return dayKey(date.getFullYear(), date.getMonth(), date.getDate())
}

// ---- Zones ---------------------------------------------------------------

// Wall-clock fields of an instant at a fixed UTC offset. QML's JavaScript has
// no Intl and Date only knows this computer's zone, so other zones are done
// by shifting the instant and reading it back as UTC.
function zonedParts(utcMs, offsetSeconds) {
  var date = new Date(Number(utcMs) + Number(offsetSeconds || 0) * 1000)
  return {
    year: date.getUTCFullYear(),
    month: date.getUTCMonth(),
    day: date.getUTCDate(),
    weekday: date.getUTCDay(),
    hour: date.getUTCHours(),
    minute: date.getUTCMinutes(),
    second: date.getUTCSeconds(),
    millisecond: date.getUTCMilliseconds()
  }
}

// This computer's offset at an instant, in seconds east of UTC.
function localOffsetSeconds(utcMs) {
  return -new Date(utcMs).getTimezoneOffset() * 60
}

// Days between the wall-clock dates of two zones at one instant: -1, 0 or +1
// (Kiribati and Baker Island can reach ±2 against each other).
function dayDifference(utcMs, offsetSeconds, referenceOffsetSeconds) {
  var a = zonedParts(utcMs, offsetSeconds)
  var b = zonedParts(utcMs, referenceOffsetSeconds)
  return Math.round((Date.UTC(a.year, a.month, a.day) - Date.UTC(b.year, b.month, b.day)) / MS_PER_DAY)
}

var MONTHS = { Jan: 0, Feb: 1, Mar: 2, Apr: 3, May: 4, Jun: 5, Jul: 6, Aug: 7, Sep: 8, Oct: 9, Nov: 10, Dec: 11 }

// Reads the output of TimeZoneTable's helper: per zone a header line
//   == Area/City +0545 +0545
// (offset and abbreviation right now, from `date`), then `zdump -v -c` lines
//   Area/City  Sun Mar 29 01:00:00 2026 UT = Sun Mar 29 03:00:00 2026 CEST isdst=1 gmtoff=7200
// Lines outside four-digit years (zdump's range markers) are skipped. Returns
// { zone: { offset, abbr, transitions: [{ at, offset, abbr, dst }] } }.
function parseZoneDump(text) {
  var zones = {}
  var lines = String(text || "").split("\n")
  var header = /^== (\S+) ([+-])(\d\d)(\d\d) (\S*)\s*$/
  var line = /^(\S+)\s+\w{3} (\w{3})\s+(\d{1,2}) (\d\d):(\d\d):(\d\d) (\d{4}) UT = .* (\S+) isdst=(\d) gmtoff=(-?\d+)\s*$/
  for (var i = 0; i < lines.length; i++) {
    var h = header.exec(lines[i])
    if (h) {
      var sign = h[2] === "-" ? -1 : 1
      zones[h[1]] = {
        offset: sign * (Number(h[3]) * 3600 + Number(h[4]) * 60),
        abbr: h[5] || "",
        transitions: []
      }
      continue
    }
    var m = line.exec(lines[i])
    if (!m || MONTHS[m[2]] === undefined) continue
    var zone = zones[m[1]]
    if (!zone) zone = zones[m[1]] = { offset: Number(m[10]), abbr: m[8], transitions: [] }
    zone.transitions.push({
      at: Date.UTC(Number(m[7]), MONTHS[m[2]], Number(m[3]), Number(m[4]), Number(m[5]), Number(m[6])),
      offset: Number(m[10]),
      abbr: m[8],
      dst: m[9] === "1"
    })
  }
  for (var key in zones) zones[key].transitions.sort(function(a, b) { return a.at - b.at })
  return zones
}

// The zone's state at an instant. zdump prints each change as two lines,
// the last second before it and the first second after, so the latest line
// at or before the instant is always right; before the first line its old
// offset still applies.
function zoneStateAt(zone, utcMs) {
  if (!zone) return null
  var list = zone.transitions || []
  if (!list.length || utcMs < list[0].at)
    return list.length ? { offset: list[0].offset, abbr: list[0].abbr, dst: list[0].dst }
      : { offset: zone.offset, abbr: zone.abbr, dst: false }
  var low = 0
  var high = list.length - 1
  while (low < high) {
    var mid = (low + high + 1) >> 1
    if (list[mid].at <= utcMs) low = mid
    else high = mid - 1
  }
  return { offset: list[low].offset, abbr: list[low].abbr, dst: list[low].dst }
}

function zoneOffsetAt(zone, utcMs) {
  var state = zoneStateAt(zone, utcMs)
  return state ? state.offset : null
}

// The next instant after utcMs at which the zone's offset changes, or 0.
function nextZoneChange(zone, utcMs) {
  var list = zone && zone.transitions || []
  var current = zoneOffsetAt(zone, utcMs)
  for (var i = 0; i < list.length; i++)
    if (list[i].at > utcMs && list[i].offset !== current) return list[i].at
  return 0
}

// The table only reaches a few years ahead; past its last change it must be
// fetched again.
function zoneTableExpires(zones) {
  var latest = 0
  for (var key in zones) {
    var list = zones[key].transitions || []
    if (list.length) latest = Math.max(latest, list[list.length - 1].at)
  }
  return latest
}

// "+5:45", "−3", "±0": an offset in hours, with a real minus sign.
function offsetText(seconds) {
  var total = Math.round(Number(seconds || 0) / 60)
  if (total === 0) return "±0"
  var sign = total < 0 ? "−" : "+"
  total = Math.abs(total)
  var hours = Math.floor(total / 60)
  var minutes = total % 60
  return sign + hours + (minutes ? ":" + pad2(minutes) : "")
}

function utcOffsetLabel(seconds) {
  var text = offsetText(seconds)
  return "UTC" + (text === "±0" ? "" : text)
}

// ---- Formatting ----------------------------------------------------------

// "14:05", "14:05:09", "2:05 PM". `amPm` holds the locale's two markers.
function clockText(parts, hour12, seconds, amPm) {
  var hour = parts.hour
  var suffix = ""
  if (hour12) {
    var markers = amPm || ["AM", "PM"]
    suffix = " " + (hour < 12 ? markers[0] : markers[1])
    hour = hour % 12
    if (hour === 0) hour = 12
  }
  var text = (hour12 ? String(hour) : pad2(hour)) + ":" + pad2(parts.minute)
  if (seconds) text += ":" + pad2(parts.second)
  return text + suffix
}

// Durations for timers and stopwatches: "4:59", "1:02:03", with hundredths
// "0:12.34". Counting down rounds up, so a timer never shows 0:00 while it
// still runs and starts on its full length.
function durationText(ms, options) {
  var opts = options || {}
  var value = Math.max(0, Number(ms) || 0)
  var hundredths = !!opts.hundredths
  var totalUnits = opts.countdown
    ? Math.ceil(value / (hundredths ? 10 : 1000))
    : Math.floor(value / (hundredths ? 10 : 1000))
  var totalSeconds = hundredths ? Math.floor(totalUnits / 100) : totalUnits
  var hours = Math.floor(totalSeconds / 3600)
  var minutes = Math.floor(totalSeconds / 60) % 60
  var secs = totalSeconds % 60
  var text = hours > 0 || opts.alwaysHours
    ? hours + ":" + pad2(minutes) + ":" + pad2(secs)
    : minutes + ":" + pad2(secs)
  if (hundredths) text += "." + pad2(totalUnits % 100)
  return text
}

// Splits a typed duration: "90" (minutes), "1:30" (minutes:seconds),
// "1:00:00", "1h30", "45s", "2h". Returns milliseconds, 0 if unreadable.
function parseDuration(text) {
  var value = String(text || "").trim().toLowerCase().replace(/\s+/g, "")
  if (value === "") return 0
  var units = /^(?:(\d+(?:[.,]\d+)?)h)?(?:(\d+(?:[.,]\d+)?)m(?:in)?)?(?:(\d+(?:[.,]\d+)?)s)?$/.exec(value)
  if (units && (units[1] || units[2] || units[3])) {
    var number = function(part) { return part ? Number(part.replace(",", ".")) : 0 }
    return Math.round((number(units[1]) * 3600 + number(units[2]) * 60 + number(units[3])) * 1000)
  }
  var hm = /^(\d+)h(\d+)$/.exec(value)
  if (hm) return (Number(hm[1]) * 3600 + Number(hm[2]) * 60) * 1000
  if (/^\d+(?:[.,]\d+)?$/.test(value)) return Math.round(Number(value.replace(",", ".")) * 60000)
  var colon = /^(\d+):(\d{1,2})(?::(\d{1,2}))?$/.exec(value)
  if (colon) {
    if (colon[3] !== undefined) return (Number(colon[1]) * 3600 + Number(colon[2]) * 60 + Number(colon[3])) * 1000
    return (Number(colon[1]) * 60 + Number(colon[2])) * 1000
  }
  return 0
}

// The timer field: a length, optionally followed by a name ("10 Tea",
// "1h30 Pasta"). The longest run of leading words that reads as a length is
// the length ("1h 30 Pasta" is 90 minutes), the rest the name, at most 60
// characters like a name typed into the card. No length: { ms: 0 }.
function parseTimerEntry(text) {
  var words = String(text || "").trim().split(/\s+/)
  for (var count = words.length; count >= 1; count--) {
    var ms = parseDuration(words.slice(0, count).join(""))
    if (ms > 0) return { ms: ms, label: words.slice(count).join(" ").slice(0, 60) }
  }
  return { ms: 0, label: "" }
}

// ---- Ids -------------------------------------------------------------------

function newId(prefix, nowMs) {
  return String(prefix || "x") + "-" + Number(nowMs).toString(36)
    + "-" + Math.floor(Math.random() * 1679616).toString(36)
}

// ---- Alarms ----------------------------------------------------------------
// { id, label, hour, minute, days: [0..6] (0 = Sunday; empty = once), enabled,
//   sound, snoozeMinutes, armedAt, snoozeUntil }
// Alarms ring on this computer's wall clock.

function normalizedDays(days) {
  var result = []
  var list = days && days.length !== undefined ? days : []
  for (var i = 0; i < list.length; i++) {
    var day = Math.round(Number(list[i]))
    if (day >= 0 && day <= 6 && result.indexOf(day) < 0) result.push(day)
  }
  return result.sort(function(a, b) { return a - b })
}

function makeAlarm(hour, minute, nowMs, defaults) {
  var opts = defaults || {}
  return {
    id: newId("alarm", nowMs),
    label: "",
    hour: clamp(Math.round(Number(hour) || 0), 0, 23),
    minute: clamp(Math.round(Number(minute) || 0), 0, 59),
    days: [],
    enabled: true,
    sound: "",
    snoozeMinutes: Number(opts.snoozeMinutes) || 9,
    armedAt: nowMs,
    snoozeUntil: 0,
    tz: "",
    placeName: ""
  }
}

// The instant a wall-clock time (year, month 0–11, day, hour, minute) has in
// a zone (parseZoneDump), with the offsets the zone has around it, so
// summer time is right on both sides of a change. A time the spring change
// skips comes out an hour later (the offset from before the change); one
// the autumn change doubles takes the later of its two instants.
function zonedInstant(zone, year, month, day, hour, minute) {
  var wall = Date.UTC(year, month, day, hour, minute)
  var before = zoneOffsetAt(zone, wall - MS_PER_DAY)
  var offsets = [before, zoneOffsetAt(zone, wall), zoneOffsetAt(zone, wall + MS_PER_DAY)]
  var best = 0
  for (var i = 0; i < offsets.length; i++) {
    var instant = wall - offsets[i] * 1000
    if (zoneOffsetAt(zone, instant) === offsets[i] && instant > best) best = instant
  }
  return best || wall - before * 1000
}

// The first time strictly after `afterMs` at which the alarm's wall-clock
// time comes round (ignoring snooze). Once alarms count from when they were
// switched on, so switching one on at 7:30 for 7:00 means tomorrow. An
// alarm with a place (alarm.tz) rings at that time there: `zone` is that
// zone's table (TimeZoneTable); without it no time can be told (0).
function alarmNextOccurrence(alarm, afterMs, zone) {
  if (!alarm) return 0
  var from = Math.max(Number(afterMs) || 0, alarm.days && alarm.days.length ? 0 : Number(alarm.armedAt) || 0)
  if (alarm.tz) return zone ? zonedAlarmOccurrence(alarm, from, zone) : 0
  var start = new Date(from)
  for (var add = 0; add <= 8; add++) {
    var candidate = new Date(start.getFullYear(), start.getMonth(), start.getDate() + add,
      alarm.hour, alarm.minute, 0, 0)
    var ms = candidate.getTime()
    // A wall time skipped by a DST change (02:30 on the spring-forward
    // night) comes out an hour later; that is when it should ring.
    if (ms <= from) continue
    if (alarm.days && alarm.days.length && alarm.days.indexOf(candidate.getDay()) < 0) continue
    return ms
  }
  return 0
}

function zonedAlarmOccurrence(alarm, from, zone) {
  var start = zonedParts(from, zoneOffsetAt(zone, from))
  for (var add = 0; add <= 8; add++) {
    var date = new Date(Date.UTC(start.year, start.month, start.day + add))
    var ms = zonedInstant(zone, date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(), alarm.hour, alarm.minute)
    if (ms <= from) continue
    if (alarm.days && alarm.days.length && alarm.days.indexOf(date.getUTCDay()) < 0) continue
    return ms
  }
  return 0
}

// When the alarm rings next, snooze included; 0 if it is off. zone: as for
// alarmNextOccurrence.
function alarmNextRing(alarm, nowMs, zone) {
  if (!alarm || !alarm.enabled) return 0
  var next = alarmNextOccurrence(alarm, nowMs, zone)
  if (alarm.snoozeUntil && alarm.snoozeUntil > nowMs && (!next || alarm.snoozeUntil < next)) return alarm.snoozeUntil
  return next
}

// What became due between the last check and now. Returns events
// { key, kind: "ring" | "missed", at } — the key makes each one fire once,
// even with two instances or a restart in between.
function dueAlarmEvents(alarm, lastCheckMs, nowMs, zone) {
  var events = []
  if (!alarm || !alarm.enabled) return events
  if (alarm.snoozeUntil && alarm.snoozeUntil > lastCheckMs && alarm.snoozeUntil <= nowMs)
    events.push({ key: alarm.id + "@snooze@" + alarm.snoozeUntil, kind: "ring", at: alarm.snoozeUntil })
  var occurrence = alarmNextOccurrence(alarm, lastCheckMs, zone)
  // Only the latest missed occurrence counts: a week asleep is one notice.
  var latest = 0
  while (occurrence && occurrence <= nowMs) {
    latest = occurrence
    occurrence = alarmNextOccurrence(alarm, occurrence, zone)
  }
  if (latest) {
    events.push({
      key: alarm.id + "@" + latest,
      kind: nowMs - latest <= ALARM_LATE_RING_MS ? "ring" : "missed",
      at: latest
    })
  }
  return events
}

// After an alarm rang: a once alarm switches itself off, snooze is spent.
function alarmAfterRing(alarm) {
  var next = copy(alarm)
  next.snoozeUntil = 0
  if (!next.days || !next.days.length) next.enabled = false
  return next
}

function alarmSnoozed(alarm, nowMs, minutes) {
  var next = copy(alarm)
  next.snoozeUntil = nowMs + Math.max(1, Number(minutes || alarm.snoozeMinutes || 9)) * MS_PER_MINUTE
  next.enabled = true
  return next
}

function alarmToggled(alarm, nowMs) {
  var next = copy(alarm)
  next.enabled = !alarm.enabled
  next.snoozeUntil = 0
  if (next.enabled) next.armedAt = nowMs
  return next
}

// ---- Timers ----------------------------------------------------------------
// { id, label, duration, state: "idle" | "running" | "paused" | "done",
//   endsAt, remaining, doneAt, sound }

function makeTimer(durationMs, nowMs, label) {
  return {
    id: newId("timer", nowMs),
    label: String(label || ""),
    duration: Math.max(1000, Number(durationMs) || 0),
    state: "idle",
    endsAt: 0,
    remaining: 0,
    doneAt: 0,
    sound: ""
  }
}

function timerRemaining(timer, nowMs) {
  if (!timer) return 0
  if (timer.state === "running") return Math.max(0, timer.endsAt - nowMs)
  if (timer.state === "paused") return Math.max(0, timer.remaining)
  if (timer.state === "done") return 0
  return timer.duration
}

// 0 at the start, 1 when it has run out.
function timerProgress(timer, nowMs) {
  if (!timer || !timer.duration) return 0
  return clamp(1 - timerRemaining(timer, nowMs) / timer.duration, 0, 1)
}

function timerStarted(timer, nowMs) {
  var next = copy(timer)
  var left = timer.state === "paused" ? timer.remaining : timer.duration
  next.state = "running"
  next.endsAt = nowMs + Math.max(0, left)
  next.remaining = 0
  next.doneAt = 0
  return next
}

function timerPaused(timer, nowMs) {
  if (timer.state !== "running") return timer
  var next = copy(timer)
  next.state = "paused"
  next.remaining = Math.max(0, timer.endsAt - nowMs)
  next.endsAt = 0
  return next
}

function timerToggled(timer, nowMs) {
  return timer.state === "running" ? timerPaused(timer, nowMs) : timerStarted(timer, nowMs)
}

function timerReset(timer) {
  var next = copy(timer)
  next.state = "idle"
  next.endsAt = 0
  next.remaining = 0
  next.doneAt = 0
  return next
}

// Adds (or with a negative value takes off) time; a finished timer starts
// again with the added time.
function timerExtended(timer, deltaMs, nowMs) {
  var next = copy(timer)
  if (timer.state === "running") next.endsAt = Math.max(nowMs, timer.endsAt + deltaMs)
  else if (timer.state === "paused") next.remaining = Math.max(0, timer.remaining + deltaMs)
  else if (timer.state === "done") {
    next.state = "running"
    next.endsAt = nowMs + Math.max(0, deltaMs)
    next.doneAt = 0
  } else next.duration = Math.max(1000, timer.duration + deltaMs)
  return next
}

function timerDue(timer, nowMs) {
  return !!timer && timer.state === "running" && timer.endsAt <= nowMs
}

function timerFinished(timer) {
  var next = copy(timer)
  next.state = "done"
  next.doneAt = timer.endsAt
  next.remaining = 0
  return next
}

// ---- Stopwatches -------------------------------------------------------------
// { id, label, running, startedAt, accumulated, laps: [total ms at each lap] }

function makeStopwatch(nowMs, label) {
  return { id: newId("stopwatch", nowMs), label: String(label || ""), running: false,
    startedAt: 0, accumulated: 0, laps: [] }
}

function stopwatchElapsed(watch, nowMs) {
  if (!watch) return 0
  return Math.max(0, Number(watch.accumulated) || 0) + (watch.running ? Math.max(0, nowMs - watch.startedAt) : 0)
}

function stopwatchToggled(watch, nowMs) {
  var next = copy(watch)
  if (watch.running) {
    next.accumulated = stopwatchElapsed(watch, nowMs)
    next.running = false
    next.startedAt = 0
  } else {
    next.running = true
    next.startedAt = nowMs
  }
  return next
}

function stopwatchLapped(watch, nowMs) {
  var elapsed = stopwatchElapsed(watch, nowMs)
  if (elapsed <= 0) return watch
  var next = copy(watch)
  next.laps = (watch.laps || []).concat([elapsed])
  return next
}

function stopwatchReset(watch) {
  var next = copy(watch)
  next.running = false
  next.startedAt = 0
  next.accumulated = 0
  next.laps = []
  return next
}

// Laps newest first, each with its own length and the running total; the
// fastest and slowest get flagged once there are three or more.
function stopwatchLapRows(watch) {
  var laps = watch && watch.laps || []
  var rows = []
  var shortest = -1
  var longest = -1
  for (var i = 0; i < laps.length; i++) {
    var split = laps[i] - (i > 0 ? laps[i - 1] : 0)
    rows.push({ number: i + 1, split: split, total: laps[i], fastest: false, slowest: false })
    if (shortest < 0 || split < rows[shortest].split) shortest = i
    if (longest < 0 || split > rows[longest].split) longest = i
  }
  if (rows.length >= 3) {
    rows[shortest].fastest = true
    rows[longest].slowest = true
  }
  return rows.reverse()
}

// ---- Pomodoros ---------------------------------------------------------------
// { id, label, work, shortBreak, longBreak, longEvery (0 = no long breaks),
//   autoContinue, phase: "work" | "break" | "longBreak",
//   state: "idle" | "running" | "paused", endsAt, remaining, completed }
// Lengths are in minutes.

function makePomodoro(nowMs, defaults) {
  var opts = defaults || {}
  return {
    id: newId("pomodoro", nowMs),
    label: "",
    work: Number(opts.work) || 25,
    shortBreak: Number(opts.shortBreak) || 5,
    longBreak: Number(opts.longBreak) || 15,
    longEvery: Math.max(0, Number(opts.longEvery) || 0),
    autoContinue: opts.autoContinue !== false,
    phase: "work",
    state: "idle",
    endsAt: 0,
    remaining: 0,
    completed: 0
  }
}

function pomodoroPhaseLength(pomodoro, phase) {
  var minutes = phase === "work" ? pomodoro.work
    : (phase === "longBreak" ? pomodoro.longBreak : pomodoro.shortBreak)
  return Math.max(1, Number(minutes) || 1) * MS_PER_MINUTE
}

function pomodoroRemaining(pomodoro, nowMs) {
  if (!pomodoro) return 0
  if (pomodoro.state === "running") return Math.max(0, pomodoro.endsAt - nowMs)
  if (pomodoro.state === "paused") return Math.max(0, pomodoro.remaining)
  return pomodoroPhaseLength(pomodoro, pomodoro.phase)
}

function pomodoroProgress(pomodoro, nowMs) {
  var length = pomodoroPhaseLength(pomodoro, pomodoro.phase)
  return clamp(1 - pomodoroRemaining(pomodoro, nowMs) / length, 0, 1)
}

function pomodoroToggled(pomodoro, nowMs) {
  var next = copy(pomodoro)
  if (pomodoro.state === "running") {
    next.state = "paused"
    next.remaining = Math.max(0, pomodoro.endsAt - nowMs)
    next.endsAt = 0
  } else {
    var left = pomodoro.state === "paused" ? pomodoro.remaining : pomodoroPhaseLength(pomodoro, pomodoro.phase)
    next.state = "running"
    next.endsAt = nowMs + left
    next.remaining = 0
  }
  return next
}

// The phase after the current one: work alternates with breaks, and every
// longEvery-th work session ends in the long break.
function pomodoroNextPhase(pomodoro, completedAfter) {
  if (pomodoro.phase !== "work") return "work"
  var every = Number(pomodoro.longEvery) || 0
  return every > 0 && completedAfter > 0 && completedAfter % every === 0 ? "longBreak" : "break"
}

// Ends the current phase at `endedAt` (on schedule, or now when skipped).
// With autoContinue the next phase runs on from that moment; otherwise it
// waits for a start. A phase that ended long ago (suspend) restarts from now
// rather than racing through the ones missed.
function pomodoroAdvanced(pomodoro, endedAt, nowMs) {
  var next = copy(pomodoro)
  var completed = pomodoro.completed + (pomodoro.phase === "work" ? 1 : 0)
  next.completed = completed
  next.phase = pomodoroNextPhase(pomodoro, completed)
  next.remaining = 0
  if (pomodoro.autoContinue && pomodoro.state === "running") {
    var start = nowMs - endedAt > MS_PER_MINUTE ? nowMs : endedAt
    next.state = "running"
    next.endsAt = start + pomodoroPhaseLength(next, next.phase)
  } else {
    next.state = "idle"
    next.endsAt = 0
  }
  return next
}

function pomodoroSkipped(pomodoro, nowMs) {
  var running = copy(pomodoro)
  if (running.state !== "running") running.state = "idle"
  return pomodoroAdvanced(running, nowMs, nowMs)
}

function pomodoroDue(pomodoro, nowMs) {
  return !!pomodoro && pomodoro.state === "running" && pomodoro.endsAt <= nowMs
}

function pomodoroReset(pomodoro) {
  var next = copy(pomodoro)
  next.phase = "work"
  next.state = "idle"
  next.endsAt = 0
  next.remaining = 0
  next.completed = 0
  return next
}

// ---- Items file --------------------------------------------------------------

function emptyItems() {
  return { version: 1, alarms: [], timers: [], stopwatches: [], pomodoros: [], pomodoroLog: {} }
}

// ---- Pomodoro tally: finished focus rounds per local day, { "2026-10-03":
//      4 }, kept for 60 days.
var POMODORO_LOG_DAYS = 60

// The log with one more round on the day of `endedAt`, days older than 60
// before `nowMs` left out.
function pomodoroLogged(log, endedAt, nowMs) {
  var next = {}
  var oldest = localDayKey(nowMs - POMODORO_LOG_DAYS * MS_PER_DAY)
  for (var key in log || {}) if (key >= oldest) next[key] = log[key]
  var day = localDayKey(endedAt)
  if (day >= oldest) next[day] = (Number(next[day]) || 0) + 1
  return next
}

// Rounds today and this week (from the locale's first weekday, 0 = Sunday,
// up to today): { today, week }.
function pomodoroTally(log, nowMs, firstDayOfWeek) {
  var now = new Date(nowMs)
  var back = (now.getDay() - (Number(firstDayOfWeek) || 0) + 7) % 7
  var week = 0
  for (var d = 0; d <= back; d++) {
    var day = new Date(now.getFullYear(), now.getMonth(), now.getDate() - d)
    week += Number((log || {})[dayKey(day.getFullYear(), day.getMonth(), day.getDate())]) || 0
  }
  return { today: Number((log || {})[localDayKey(nowMs)]) || 0, week: week }
}

// Anything unreadable becomes an empty list rather than a crash; fields are
// coerced to their types so the views can trust them.
function parseItems(raw) {
  var parsed
  try { parsed = JSON.parse(String(raw || "")) } catch (e) { parsed = null }
  var items = emptyItems()
  if (!parsed || typeof parsed !== "object") return items
  function list(name) { return parsed[name] && parsed[name].length !== undefined ? parsed[name] : [] }
  function text(value) { return typeof value === "string" ? value.slice(0, 120) : "" }
  function num(value, fallback) { var n = Number(value); return isFinite(n) ? n : fallback }
  function id(value, prefix, index) { return typeof value === "string" && value !== "" ? value : prefix + "-" + index }
  var states = ["idle", "running", "paused", "done"]
  var log = parsed.pomodoroLog && typeof parsed.pomodoroLog === "object" ? parsed.pomodoroLog : {}
  for (var key in log) {
    var rounds = Math.round(num(log[key], 0))
    if (/^\d{4}-\d{2}-\d{2}$/.test(key) && rounds > 0) items.pomodoroLog[key] = Math.min(rounds, 999)
  }
  list("alarms").forEach(function(a, i) {
    if (!a || typeof a !== "object") return
    items.alarms.push({
      id: id(a.id, "alarm", i), label: text(a.label),
      hour: clamp(Math.round(num(a.hour, 7)), 0, 23), minute: clamp(Math.round(num(a.minute, 0)), 0, 59),
      days: normalizedDays(a.days), enabled: a.enabled !== false, sound: text(a.sound),
      snoozeMinutes: clamp(Math.round(num(a.snoozeMinutes, 9)), 1, 60),
      armedAt: num(a.armedAt, 0), snoozeUntil: num(a.snoozeUntil, 0),
      // A place (its zone and name), or "" for this computer.
      tz: typeof a.tz === "string" && /^[A-Za-z0-9_+\-\/]+$/.test(a.tz) ? a.tz : "",
      placeName: typeof a.tz === "string" && a.tz !== "" ? text(a.placeName).slice(0, 60) : ""
    })
  })
  list("timers").forEach(function(t, i) {
    if (!t || typeof t !== "object") return
    items.timers.push({
      id: id(t.id, "timer", i), label: text(t.label), duration: Math.max(1000, num(t.duration, 300000)),
      state: states.indexOf(t.state) >= 0 ? t.state : "idle", endsAt: num(t.endsAt, 0),
      remaining: Math.max(0, num(t.remaining, 0)), doneAt: num(t.doneAt, 0), sound: text(t.sound)
    })
  })
  list("stopwatches").forEach(function(s, i) {
    if (!s || typeof s !== "object") return
    var laps = (s.laps && s.laps.length !== undefined ? s.laps : []).map(Number).filter(isFinite)
    items.stopwatches.push({
      id: id(s.id, "stopwatch", i), label: text(s.label), running: s.running === true,
      startedAt: num(s.startedAt, 0), accumulated: Math.max(0, num(s.accumulated, 0)), laps: laps.slice(-500)
    })
  })
  list("pomodoros").forEach(function(p, i) {
    if (!p || typeof p !== "object") return
    var phases = ["work", "break", "longBreak"]
    items.pomodoros.push({
      id: id(p.id, "pomodoro", i), label: text(p.label),
      work: clamp(Math.round(num(p.work, 25)), 1, 240), shortBreak: clamp(Math.round(num(p.shortBreak, 5)), 1, 120),
      longBreak: clamp(Math.round(num(p.longBreak, 15)), 1, 120), longEvery: clamp(Math.round(num(p.longEvery, 0)), 0, 12),
      autoContinue: p.autoContinue !== false, phase: phases.indexOf(p.phase) >= 0 ? p.phase : "work",
      state: ["idle", "running", "paused"].indexOf(p.state) >= 0 ? p.state : "idle",
      endsAt: num(p.endsAt, 0), remaining: Math.max(0, num(p.remaining, 0)), completed: Math.max(0, Math.round(num(p.completed, 0)))
    })
  })
  return items
}

function replaceItem(list, item) {
  return list.map(function(entry) { return entry.id === item.id ? item : entry })
}

function removeItem(list, itemId) {
  return list.filter(function(entry) { return entry.id !== itemId })
}

function moveItem(list, itemId, delta) {
  var index = -1
  for (var i = 0; i < list.length; i++) if (list[i].id === itemId) index = i
  var target = index + delta
  if (index < 0 || target < 0 || target >= list.length) return list
  var result = list.slice()
  var item = result.splice(index, 1)[0]
  result.splice(target, 0, item)
  return result
}

function findItem(list, itemId) {
  for (var i = 0; i < list.length; i++) if (list[i].id === itemId) return list[i]
  return null
}

function copy(value) {
  return JSON.parse(JSON.stringify(value))
}

// ---- Cities ------------------------------------------------------------------
// { name, country, tz, lat, lon }

function defaultCities() {
  return [
    { name: "New York", country: "US", tz: "America/New_York", lat: 40.714, lon: -74.006, dial: "classic" },
    { name: "London", country: "GB", tz: "Europe/London", lat: 51.508, lon: -0.126, dial: "classic" },
    { name: "Tokyo", country: "JP", tz: "Asia/Tokyo", lat: 35.689, lon: 139.692, dial: "classic" },
    { name: "Sydney", country: "AU", tz: "Australia/Sydney", lat: -33.868, lon: 151.209, dial: "classic" }
  ]
}

// The clock face styles (TimeDial.qml); anything else is the classic one.
var DIAL_STYLES = ["classic", "minimal", "roman", "twentyFour", "dots"]

function dialStyle(value) {
  return DIAL_STYLES.indexOf(String(value)) >= 0 ? String(value) : "classic"
}

// The world clock keeps at most this many cities; adding and importing
// stop there.
var MAX_CITIES = 24

// A missing file gives the sample cities; an emptied list stays empty.
function parseCities(raw, missing) {
  if (missing) return defaultCities()
  var parsed
  try { parsed = JSON.parse(String(raw || "")) } catch (e) { return defaultCities() }
  if (!parsed || parsed.length === undefined) return defaultCities()
  var result = []
  for (var i = 0; i < parsed.length && result.length < MAX_CITIES; i++) {
    var c = parsed[i]
    if (!c || typeof c.tz !== "string" || !/^[A-Za-z0-9_+\-\/]+$/.test(c.tz)) continue
    var lat = Number(c.lat)
    var lon = Number(c.lon)
    result.push({
      name: typeof c.name === "string" && c.name !== "" ? c.name.slice(0, 60) : zoneCityName(c.tz),
      country: typeof c.country === "string" ? c.country.slice(0, 60) : "",
      tz: c.tz,
      lat: isFinite(lat) && c.lat !== null && c.lat !== "" ? clamp(lat, -90, 90) : null,
      lon: isFinite(lon) && c.lon !== null && c.lon !== "" ? clamp(lon, -180, 180) : null,
      dial: dialStyle(c.dial)
    })
  }
  return result
}

function cityKey(city) {
  return city ? city.tz + "|" + city.name : ""
}

// "America/Argentina/Buenos_Aires" → "Buenos Aires".
function zoneCityName(tz) {
  var parts = String(tz || "").split("/")
  return parts[parts.length - 1].replace(/_/g, " ")
}

// ISO 6709 "+4230+00131" or "+404251-0740023" → { lat, lon } in degrees.
function parseIso6709(text) {
  var m = /^([+-])(\d{2})(\d{2})(\d{2})?([+-])(\d{3})(\d{2})(\d{2})?$/.exec(String(text || ""))
  if (!m) return null
  var lat = Number(m[2]) + Number(m[3]) / 60 + Number(m[4] || 0) / 3600
  var lon = Number(m[6]) + Number(m[7]) / 60 + Number(m[8] || 0) / 3600
  return { lat: m[1] === "-" ? -lat : lat, lon: m[5] === "-" ? -lon : lon }
}

// The offline city list: every zone of zone1970.tab, named after its city,
// with the first country's name from iso3166.tab.
function parseZoneIndex(zoneTab, isoTab) {
  var countries = {}
  String(isoTab || "").split("\n").forEach(function(line) {
    if (!line || line.charAt(0) === "#") return
    var cols = line.split("\t")
    if (cols.length >= 2) countries[cols[0]] = cols[1]
  })
  var result = []
  String(zoneTab || "").split("\n").forEach(function(line) {
    if (!line || line.charAt(0) === "#") return
    var cols = line.split("\t")
    if (cols.length < 3) return
    var where = parseIso6709(cols[1])
    if (!where) return
    var codes = cols[0].split(",")
    var code = codes[0]
    result.push({ name: zoneCityName(cols[2]), country: countries[code] || code, codes: codes, tz: cols[2],
      lat: Math.round(where.lat * 1000) / 1000, lon: Math.round(where.lon * 1000) / 1000 })
  })
  return result
}

// Lower case without accents, for matching typed text against names.
function foldText(text) {
  var value = String(text || "").toLowerCase()
  if (typeof value.normalize === "function") value = value.normalize("NFD").replace(/[\u0300-\u036f]/g, "")
  return value.replace(/[_\-]/g, " ")
}

// Offline matches, best first: name starts with the text, a word of it
// does, it contains the text, then country and zone matches.
function searchZoneIndex(index, query, limit) {
  var q = foldText(query).trim()
  if (q === "") return []
  var scored = []
  for (var i = 0; i < index.length; i++) {
    var entry = index[i]
    var name = foldText(entry.name)
    var score = -1
    if (name === q) score = 0
    else if (name.indexOf(q) === 0) score = 1
    else if ((" " + name).indexOf(" " + q) >= 0) score = 2
    else if (name.indexOf(q) >= 0) score = 3
    else if (foldText(entry.country).indexOf(q) === 0) score = 4
    else if (foldText(entry.tz).indexOf(q) >= 0) score = 5
    if (score >= 0) scored.push({ score: score, entry: entry })
  }
  scored.sort(function(a, b) { return a.score - b.score || a.entry.name.localeCompare(b.entry.name) })
  return scored.slice(0, limit || 8).map(function(s) { return s.entry })
}

// ---- Places without a zone: Nominatim results, More Weather's places ----

// Great-circle distance in kilometres.
function distanceKm(lat1, lon1, lat2, lon2) {
  var r = Math.PI / 180
  var a = Math.sin((lat2 - lat1) * r / 2)
  var b = Math.sin((lon2 - lon1) * r / 2)
  var h = a * a + Math.cos(lat1 * r) * Math.cos(lat2 * r) * b * b
  return 2 * 6371 * Math.asin(Math.min(1, Math.sqrt(h)))
}

// The zone1970.tab entry (parseZoneIndex) nearest to a point, or null.
// With a country code ("de"), the nearest entry of that country: first
// among the zones it heads (the first column lists every country a zone
// serves, its own first: Europe/Zurich also serves Büsingen in Germany),
// then among all that serve it; without any, the nearest of all.
function nearestZone(index, lat, lon, countryCode) {
  var code = String(countryCode || "").toUpperCase()
  if (code !== "") {
    var list = index || []
    var heads = list.filter(function(entry) { return entry.codes && entry.codes[0] === code })
    if (heads.length) return nearestZone(heads, lat, lon, "")
    var serves = list.filter(function(entry) { return entry.codes && entry.codes.indexOf(code) >= 0 })
    if (serves.length) return nearestZone(serves, lat, lon, "")
  }
  var best = null
  var bestKm = Infinity
  for (var i = 0; i < (index || []).length; i++) {
    var km = distanceKm(lat, lon, index[i].lat, index[i].lon)
    if (km < bestKm) {
      bestKm = km
      best = index[i]
    }
  }
  return best
}

// A search result (PlaceSearch: { name, region, country, lat, lon, tz }) as
// a city. Without a zone it takes the nearest zone1970 city's, marked as a
// guess (tzGuessed); null when there is none to take.
function cityFromPlace(place, index) {
  if (!place) return null
  var tz = place.tz || ""
  var guessed = false
  if (tz === "") {
    var near = nearestZone(index, place.lat, place.lon, place.countryCode)
    if (!near) return null
    tz = near.tz
    guessed = true
  }
  var where = [place.region, place.country].filter(function(part) { return typeof part === "string" && part !== "" })
  return { name: String(place.name).slice(0, 60), country: where.join(", "), tz: tz,
    lat: Math.round(place.lat * 1000) / 1000, lon: Math.round(place.lon * 1000) / 1000, tzGuessed: guessed }
}

// The zone for a place known by name and coordinates: the first search
// result's when it lies within 25 km, else the nearest zone1970 city's (of
// that result's country, when it is that close and names one).
function zoneForPlace(results, lat, lon, index) {
  var first = results && results.length ? results[0] : null
  var close = first && distanceKm(lat, lon, first.lat, first.lon) <= 25
  if (close && first.tz) return first.tz
  var near = nearestZone(index, lat, lon, close ? first.countryCode : "")
  return near ? near.tz : ""
}

// More Weather's saved places (more-weather-locations.json):
// [{ name, latitude, longitude }] → [{ name, lat, lon }].
function parseWeatherPlaces(raw) {
  var data
  try { data = JSON.parse(String(raw || "")) } catch (e) { return [] }
  if (!Array.isArray(data)) return []
  var out = []
  for (var i = 0; i < data.length; i++) {
    var entry = data[i]
    var place = entry && typeof entry === "object" ? placeFrom(String(entry.name || "").trim(), entry.latitude, entry.longitude) : null
    if (place && place.name !== "") out.push(place)
  }
  return out
}

// Whether a city is already in the list: the same place by samePlace
// (PlaceSearch.samePlace, passed in: the same spot, or the same name close
// by), or the same name (without case and accents) in the same zone.
function knownCity(cities, city, samePlace) {
  var located = city.lat !== null && city.lat !== undefined
  for (var i = 0; i < (cities || []).length; i++) {
    var c = cities[i]
    if (located && c.lat !== null && c.lat !== undefined && samePlace(c, city)) return true
    if (city.tz && c.tz === city.tz && foldText(c.name) === foldText(city.name)) return true
  }
  return false
}

// Imported places with their zones ([{ name, lat, lon, tz }]) added to the
// cities in their order, skipping known ones (knownCity) and stopping at
// MAX_CITIES: { list, added, existing, full (not added for lack of room) }.
function mergeImportedPlaces(cities, places, samePlace) {
  var list = (cities || []).slice()
  var added = 0
  var existing = 0
  var full = 0
  for (var i = 0; i < (places || []).length; i++) {
    var p = places[i]
    if (!p || !p.tz) continue
    var city = { name: String(p.name).slice(0, 60), country: p.country || "", tz: p.tz,
      lat: Math.round(p.lat * 1000) / 1000, lon: Math.round(p.lon * 1000) / 1000 }
    if (knownCity(list, city, samePlace)) {
      existing++
      continue
    }
    if (list.length >= MAX_CITIES) {
      full++
      continue
    }
    list.push(city)
    added++
  }
  return { list: list, added: added, existing: existing, full: full }
}

// ---- Here: an approximate place from IP geolocation --------------------
// The services More Weather asks too, in its order of fallback.
var IP_PLACE_PROVIDERS = [
  { id: "ipwho.is", url: "https://ipwho.is/" },
  { id: "ipapi.co", url: "https://ipapi.co/json/" },
  { id: "geojs", url: "https://get.geojs.io/v1/ip/geo.json" }
]

// A service's answer → { name, lat, lon }, or null when it holds no place.
function ipPlace(providerId, raw) {
  var data
  try { data = JSON.parse(String(raw || "")) } catch (e) { return null }
  if (!data || typeof data !== "object") return null
  if (providerId === "ipwho.is" && data.success === false) return null
  if (providerId === "ipapi.co" && data.error) return null
  return placeFrom(data.city, data.latitude, data.longitude)
}

// { name, lat, lon } from loose values, or null without usable coordinates.
function placeFrom(name, lat, lon) {
  if (lat === null || lat === undefined || lat === "" || lon === null || lon === undefined || lon === "") return null
  var la = Number(lat)
  var lo = Number(lon)
  if (!isFinite(la) || !isFinite(lo) || Math.abs(la) > 90 || Math.abs(lo) > 180) return null
  return { name: typeof name === "string" ? name.slice(0, 60) : "", lat: la, lon: lo }
}

// Omarchy's shared weather location (settings/weather.json):
// { name, latitude, longitude } → { name, lat, lon }, or null.
function weatherLocation(raw) {
  var data
  try { data = JSON.parse(String(raw || "")) } catch (e) { return null }
  if (!data || typeof data !== "object") return null
  return placeFrom(data.name, data.latitude !== undefined ? data.latitude : data.lat,
    data.longitude !== undefined ? data.longitude : data.lon)
}

// ---- Timer presets ----
// The preset row of the Timers tab: 1 to 12 lengths in minutes, each 1 to
// 1440, typed as "1, 3, 5, 10". Returns them sorted and once each, or null
// when the text is not such a list.
var DEFAULT_TIMER_PRESETS = "1,3,5,10,15,25,60"

function parseTimerPresets(text) {
  var parts = String(text === undefined || text === null ? "" : text).split(/[,;\s]+/)
    .filter(function(part) { return part !== "" })
  if (!parts.length || parts.length > 12) return null
  var minutes = []
  for (var i = 0; i < parts.length; i++) {
    if (!/^\d{1,4}$/.test(parts[i])) return null
    var n = Number(parts[i])
    if (n < 1 || n > 1440) return null
    if (minutes.indexOf(n) < 0) minutes.push(n)
  }
  return minutes.sort(function(a, b) { return a - b })
}

// The stored form: "1,3,5" (or the default when the text is not a list).
function timerPresetsText(text) {
  var minutes = parseTimerPresets(text)
  return minutes ? minutes.join(",") : DEFAULT_TIMER_PRESETS
}

// ---- Chimes ---------------------------------------------------------------
// A short beep series on this computer's wall clock. settings:
//   { chimeInterval: "off" | "minute" | "quarter" | "hour" | "daily" | "custom",
//     chimeMinutes: 1–1440 (custom), chimeDailyHour: 0–23 (daily),
//     hourChime: "off" | "12" | "24" }
// Quarter hours count 1 at :15, 2 at :30, 3 at :45 and 4 at :00; every other
// interval is one beep. A custom interval up to an hour starts again with
// each hour (20 → :00 :20 :40), a longer one counts from midnight. The hour
// chime adds a second series at the full hour: the hour on a 12- or 24-hour
// dial, midnight being 12 or 24.

var CHIME_INTERVALS = ["off", "minute", "quarter", "hour", "daily", "custom"]
var CHIME_MAX_MINUTES = 1440
// A chime due in a minute that is already older than this (late tick,
// waking from suspend) is skipped, never caught up.
var CHIME_LATE_MS = 15 * MS_PER_SECOND

// A custom interval in minutes, or 0 when the text is not one.
function chimeMinutesValue(value) {
  var text = String(value === undefined || value === null ? "" : value).trim()
  if (!/^\d{1,4}$/.test(text)) return 0
  var minutes = Number(text)
  return minutes >= 1 && minutes <= CHIME_MAX_MINUTES ? minutes : 0
}

// How many beeps of each series the minute starting at (or containing)
// minuteMs plays: { intervalBeeps, hourBeeps }.
function chimePlan(settings, minuteMs) {
  var s = settings || {}
  var date = new Date(Number(minuteMs) || 0)
  var hour = date.getHours()
  var minute = date.getMinutes()
  var ofDay = hour * 60 + minute
  var interval = String(s.chimeInterval || "off")
  var beeps = 0
  if (interval === "minute") beeps = 1
  else if (interval === "quarter") beeps = minute % 15 === 0 ? (minute === 0 ? 4 : minute / 15) : 0
  else if (interval === "hour") beeps = minute === 0 ? 1 : 0
  else if (interval === "daily") beeps = ofDay === clamp(Math.floor(Number(s.chimeDailyHour) || 0), 0, 23) * 60 ? 1 : 0
  else if (interval === "custom") {
    var every = chimeMinutesValue(s.chimeMinutes)
    if (every > 0) beeps = (every <= 60 ? minute % every : ofDay % every) === 0 ? 1 : 0
  }
  var hourBeeps = 0
  var dial = String(s.hourChime || "off")
  if (minute === 0 && dial === "12") hourBeeps = hour % 12 || 12
  else if (minute === 0 && dial === "24") hourBeeps = hour || 24
  return { intervalBeeps: beeps, hourBeeps: hourBeeps }
}

// Whether any chime is set up at all (muted or not).
function chimesActive(settings) {
  var s = settings || {}
  var interval = String(s.chimeInterval || "off")
  var intervalOn = interval !== "off" && (interval !== "custom" || chimeMinutesValue(s.chimeMinutes) > 0)
  return intervalOn || (String(s.hourChime || "off") !== "off")
}

// The start of the next minute after nowMs that chimes, or 0 when none
// does within a day.
function nextChimeAt(settings, nowMs) {
  if (!chimesActive(settings)) return 0
  var date = new Date(Number(nowMs) || 0)
  date.setSeconds(0, 0)
  for (var i = 1; i <= 1441; i++) {
    var candidate = new Date(date.getTime())
    candidate.setMinutes(candidate.getMinutes() + i)
    var plan = chimePlan(settings, candidate.getTime())
    if (plan.intervalBeeps > 0 || plan.hourBeeps > 0) return candidate.getTime()
  }
  return 0
}

// The minute nowMs falls in, when a chime for it may still play: its start,
// or 0 when the minute is more than CHIME_LATE_MS old.
function chimeMinuteFor(nowMs) {
  var start = Math.floor(Number(nowMs) / MS_PER_MINUTE) * MS_PER_MINUTE
  return Number(nowMs) - start <= CHIME_LATE_MS ? start : 0
}

if (typeof module !== "undefined") module.exports = {
  pad2: pad2, isoWeek: isoWeek, dayOfYear: dayOfYear, dayKey: dayKey, localDayKey: localDayKey,
  zonedParts: zonedParts, localOffsetSeconds: localOffsetSeconds, dayDifference: dayDifference,
  parseZoneDump: parseZoneDump, zoneStateAt: zoneStateAt, zoneOffsetAt: zoneOffsetAt,
  nextZoneChange: nextZoneChange, zoneTableExpires: zoneTableExpires,
  offsetText: offsetText, utcOffsetLabel: utcOffsetLabel, clockText: clockText,
  durationText: durationText, parseDuration: parseDuration,
  makeAlarm: makeAlarm, zonedInstant: zonedInstant, alarmNextOccurrence: alarmNextOccurrence, alarmNextRing: alarmNextRing,
  dueAlarmEvents: dueAlarmEvents, alarmAfterRing: alarmAfterRing, alarmSnoozed: alarmSnoozed,
  alarmToggled: alarmToggled, normalizedDays: normalizedDays,
  makeTimer: makeTimer, timerRemaining: timerRemaining, timerProgress: timerProgress,
  timerStarted: timerStarted, timerPaused: timerPaused, timerToggled: timerToggled, timerReset: timerReset,
  timerExtended: timerExtended, timerDue: timerDue, timerFinished: timerFinished,
  makeStopwatch: makeStopwatch, stopwatchElapsed: stopwatchElapsed, stopwatchToggled: stopwatchToggled,
  stopwatchLapped: stopwatchLapped, stopwatchReset: stopwatchReset, stopwatchLapRows: stopwatchLapRows,
  makePomodoro: makePomodoro, pomodoroPhaseLength: pomodoroPhaseLength, pomodoroRemaining: pomodoroRemaining,
  pomodoroProgress: pomodoroProgress, pomodoroToggled: pomodoroToggled, pomodoroAdvanced: pomodoroAdvanced,
  pomodoroSkipped: pomodoroSkipped, pomodoroDue: pomodoroDue, pomodoroReset: pomodoroReset,
  pomodoroNextPhase: pomodoroNextPhase,
  emptyItems: emptyItems, pomodoroLogged: pomodoroLogged, pomodoroTally: pomodoroTally, parseItems: parseItems, replaceItem: replaceItem, removeItem: removeItem,
  moveItem: moveItem, findItem: findItem,
  defaultCities: defaultCities, MAX_CITIES: MAX_CITIES, parseCities: parseCities, cityKey: cityKey, zoneCityName: zoneCityName,
  parseIso6709: parseIso6709, parseZoneIndex: parseZoneIndex, foldText: foldText,
  searchZoneIndex: searchZoneIndex,
  chimeMinutesValue: chimeMinutesValue, chimePlan: chimePlan, chimesActive: chimesActive,
  nextChimeAt: nextChimeAt, parseTimerPresets: parseTimerPresets, timerPresetsText: timerPresetsText,
  DEFAULT_TIMER_PRESETS: DEFAULT_TIMER_PRESETS, chimeMinuteFor: chimeMinuteFor,
  distanceKm: distanceKm, nearestZone: nearestZone, cityFromPlace: cityFromPlace, zoneForPlace: zoneForPlace,
  parseWeatherPlaces: parseWeatherPlaces, DIAL_STYLES: DIAL_STYLES, dialStyle: dialStyle, knownCity: knownCity, mergeImportedPlaces: mergeImportedPlaces,
  IP_PLACE_PROVIDERS: IP_PLACE_PROVIDERS, ipPlace: ipPlace, placeFrom: placeFrom, weatherLocation: weatherLocation
}
