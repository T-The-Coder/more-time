import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Everything that happens when time is up: alarms and timers ring, a
// pomodoro phase ends. Bar and app both run this, and the bar runs once per
// monitor, but only one instance may ring: the leader. Leadership and what
// is ringing right now live in a small file in the runtime directory (gone
// after a reboot, like the processes that wrote it):
//
//   { leader: { id, kind: "shell" | "app", beat },
//     ringing: [{ key, kind, itemId, title, body, at }],
//     chimedAt: start of the last minute that chimed }
//
// When the last check ran and the keys of everything already fired outlive
// a reboot in the state directory, so an alarm due while the computer was
// off is reported as missed (and a once-alarm switched off) at the next
// start:
//
//   ~/.local/state/omarchy/settings/more-time-ringer.json
//   { lastCheck, fired: { key: at } }
//
// An instance leads while its heartbeat is fresh; a bar instance takes over
// from the app. Every instance shows what is ringing and can stop it; only
// the leader plays the sound and sends notifications.
//
// The chimes (Settings → Sounds → Chimes) are played by the leader too, on
// the minute turn. The minute it last chimed for goes into the runtime file,
// so a leader taking over within the same minute does not chime again.
// Their tones are generated once into ~/.cache/more-time.
Item {
  id: ringer
  required property var panel

  readonly property string instanceId: (panel.standaloneMode ? "app-" : "shell-")
    + Math.floor(Math.random() * 2176782336).toString(36)
  readonly property string kind: panel.standaloneMode ? "app" : "shell"
  readonly property string runtimeDir: (Quickshell.env("XDG_RUNTIME_DIR") || (Quickshell.env("HOME") + "/.cache"))
    + "/more-time"
  readonly property int heartbeatMs: 15000
  readonly property int leaderTimeoutMs: 45000
  // How far back the very first check looks, when no check has ever been
  // recorded: an alarm due shortly before still rings if it is this recent
  // (Model.ALARM_LATE_RING_MS). Later starts look back to the last check.
  readonly property int startupLookbackMs: 10 * 60000
  // The last check goes to disk with every event, otherwise at most this
  // often: what fired in between is on disk already, so the next start
  // looking back a little too far rings nothing twice.
  readonly property int persistEveryMs: 5 * 60000

  property bool dirReady: false
  // No check before the persistent state is read, or it would start over
  // from the short first-start lookback.
  property bool persistReady: false
  property bool isLeader: false
  property var ringing: []
  // The shared state as last read or written: leader and ringing from the
  // runtime file, lastCheck and fired from the persistent one.
  property var state: ({ leader: null, ringing: [], chimedAt: 0, lastCheck: 0, fired: {} })

  readonly property var soundFiles: ({
    alarm: "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga",
    bell: "/usr/share/sounds/freedesktop/stereo/bell.oga",
    complete: "/usr/share/sounds/freedesktop/stereo/complete.oga",
    message: "/usr/share/sounds/freedesktop/stereo/message.oga",
    phone: "/usr/share/sounds/freedesktop/stereo/phone-incoming-call.oga"
  })
  readonly property var soundIds: ["alarm", "bell", "complete", "message", "phone", "none"]

  Component.onCompleted: mkdirProc.running = true

  property Process mkdirProc: Process {
    command: ["mkdir", "-p", "-m", "700", ringer.runtimeDir]
    onExited: {
      ringer.dirReady = true
      runtimeFile.reload()
    }
  }

  property FileView runtimeFile: FileView {
    path: ringer.dirReady ? ringer.runtimeDir + "/runtime.json" : ""
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      // An older write of ours reported after a newer one is an echo.
      var echo = ringer.recentWrites.indexOf(text())
      if (echo >= 0 && echo < ringer.recentWrites.length - 1) return
      ringer.adopt(ringer.mergedWith(ringer.parseRuntime(text())))
    }
    onLoadFailed: ringer.adopt(ringer.mergedWith(ringer.parseRuntime("")))
  }

  property FileView persistFile: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/more-time-ringer.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var echo = ringer.recentPersistWrites.indexOf(text())
      if (echo >= 0 && echo < ringer.recentPersistWrites.length - 1) return
      ringer.adoptPersisted(ringer.parsePersisted(text()))
    }
    onLoadFailed: ringer.adoptPersisted(ringer.parsePersisted(""))
  }

  function parseObject(raw) {
    var parsed
    try { parsed = JSON.parse(String(raw || "")) } catch (e) { parsed = null }
    return parsed && typeof parsed === "object" ? parsed : {}
  }

  function parseRuntime(raw) {
    var parsed = parseObject(raw)
    return {
      leader: parsed.leader && typeof parsed.leader.id === "string" ? parsed.leader : null,
      ringing: parsed.ringing && parsed.ringing.length !== undefined ? parsed.ringing : [],
      chimedAt: Number(parsed.chimedAt) || 0
    }
  }

  function parsePersisted(raw) {
    var parsed = parseObject(raw)
    return {
      lastCheck: Number(parsed.lastCheck) || 0,
      fired: parsed.fired && typeof parsed.fired === "object" ? parsed.fired : {}
    }
  }

  // The runtime part read from the file, with the persistent part in memory.
  function mergedWith(runtime) {
    return { leader: runtime.leader, ringing: runtime.ringing, chimedAt: runtime.chimedAt,
      lastCheck: state.lastCheck, fired: state.fired }
  }

  // The shared state as last read or written. The file watches bring in the
  // other instances' writes; reading the files again here would race this
  // instance's own asynchronous writes (see TimeItemsStore).
  function read() {
    return JSON.parse(JSON.stringify(state))
  }

  property var recentWrites: []
  property var recentPersistWrites: []
  // What is on disk in the persistent file, as written or read last.
  property double persistedLastCheck: 0
  property string persistedFired: "{}"

  function write(next) {
    if (!dirReady) return
    var text = JSON.stringify({ leader: next.leader, ringing: next.ringing, chimedAt: next.chimedAt || 0 }) + "\n"
    recentWrites = recentWrites.concat([text]).slice(-8)
    runtimeFile.setText(text)
    var fired = JSON.stringify(next.fired)
    if (persistReady && (fired !== persistedFired || next.lastCheck - persistedLastCheck >= persistEveryMs)) {
      var persistText = JSON.stringify({ lastCheck: next.lastCheck, fired: next.fired }) + "\n"
      recentPersistWrites = recentPersistWrites.concat([persistText]).slice(-8)
      persistedLastCheck = next.lastCheck
      persistedFired = fired
      persistFile.setText(persistText)
    }
    adopt(next)
  }

  // Another instance's (or an earlier run's) last check and fired keys.
  function adoptPersisted(persisted) {
    persistedLastCheck = persisted.lastCheck
    persistedFired = JSON.stringify(persisted.fired)
    var next = read()
    next.lastCheck = Math.max(next.lastCheck, persisted.lastCheck)
    next.fired = persisted.fired
    state = next
    persistReady = true
  }

  // Takes in the shared state: what rings, and whether this instance still
  // leads. The leader starts and stops sound and notifications to match.
  function adopt(next) {
    state = next
    isLeader = !!next.leader && next.leader.id === instanceId
    var keys = next.ringing.map(function(r) { return r.key }).join("|")
    if (keys !== ringing.map(function(r) { return r.key }).join("|")) ringing = next.ringing
    if (isLeader) syncEffects()
    else if (soundProc.running && !testingSound) soundProc.running = false
  }

  // ---- Leadership and the check, from the panel's clock tick ----

  function tick(nowMs) {
    // Not before the persistent state and the items are read: an earlier
    // check would start over from the short lookback, or pass a missed
    // alarm unseen.
    if (!dirReady || !persistReady || !panel.itemsStore.loaded) return
    var current = read()
    var leader = current.leader
    var leaderAlive = leader && nowMs - Number(leader.beat || 0) < leaderTimeoutMs
    var mine = leader && leader.id === instanceId
    var takeOver = !leaderAlive || (leader.kind === "app" && kind === "shell")
    if (!mine && !takeOver) {
      if (isLeader) adopt(current)
      return
    }
    var changed = false
    if (!mine || nowMs - Number(leader.beat || 0) >= heartbeatMs) {
      current.leader = { id: instanceId, kind: kind, beat: nowMs }
      changed = true
    }
    if (check(current, nowMs)) changed = true
    if (chime(current, nowMs)) changed = true
    if (changed) write(current)
    else adopt(current)
  }

  // Finds what came due since the last check; returns true when `current`
  // was changed. Item changes are written to the items file in one go.
  function check(current, nowMs) {
    var items = panel.itemsStore.items
    var from = current.lastCheck > 0 ? Math.max(current.lastCheck, nowMs - 7 * 86400000) : nowMs - startupLookbackMs
    if (from > nowMs) from = nowMs - 1000
    var fired = current.fired
    var events = []
    var changes = []
    var alarms = items.alarms
    // An alarm at a city's time needs that zone's table. Until the table's
    // first read (a moment after a start) such alarms are skipped and the
    // last check stays where it is, so they are not passed by; timers and
    // pomodoros go on. A zone the system does not know is skipped for good.
    var holdCheck = false
    for (var a = 0; a < alarms.length; a++) {
      var zone = panel.alarmZone(alarms[a])
      if (alarms[a].tz && !zone) {
        if (!panel.zoneTable.fetched) holdCheck = true
        continue
      }
      var due = Model.dueAlarmEvents(alarms[a], from, nowMs, zone)
      for (var d = 0; d < due.length; d++) {
        if (fired[due[d].key]) continue
        events.push({ key: due[d].key, kind: due[d].kind === "missed" ? "missedAlarm" : "alarm",
          item: alarms[a], at: due[d].at })
        changes.push({ kind: "alarms", id: alarms[a].id, fn: Model.alarmAfterRing })
      }
    }
    var timers = items.timers
    for (var t = 0; t < timers.length; t++) {
      if (!Model.timerDue(timers[t], nowMs)) continue
      var timerKey = timers[t].id + "@" + timers[t].endsAt
      changes.push({ kind: "timers", id: timers[t].id, fn: Model.timerFinished })
      if (!fired[timerKey]) events.push({ key: timerKey, kind: "timer", item: timers[t], at: timers[t].endsAt })
    }
    var pomodoros = items.pomodoros
    for (var p = 0; p < pomodoros.length; p++) {
      if (!Model.pomodoroDue(pomodoros[p], nowMs)) continue
      var endedAt = pomodoros[p].endsAt
      var pomodoroKey = pomodoros[p].id + "@" + endedAt
      changes.push({ kind: "pomodoros", id: pomodoros[p].id,
        fn: (function(at) { return function(item) { return Model.pomodoroAdvanced(item, at, nowMs) } })(endedAt) })
      if (!fired[pomodoroKey]) {
        events.push({ key: pomodoroKey, kind: "pomodoro", item: pomodoros[p], at: endedAt })
        // A finished focus round counts on its day (the tally).
        if (pomodoros[p].phase === "work") changes.push({ kind: "pomodoroLog",
          fn: (function(at) { return function(log) { return Model.pomodoroLogged(log, at, nowMs) } })(endedAt) })
      }
    }

    // Kept in memory; written with the next event, or with a heartbeat once
    // persistEveryMs has passed. Fired keys guard against a check window
    // that starts a little early.
    if (!holdCheck) current.lastCheck = nowMs
    if (!events.length && !changes.length) return false
    // Keys are only needed while their moment can still come round in a
    // check window; two days covers suspend and restarts.
    var pruned = {}
    for (var key in fired) if (nowMs - Number(fired[key]) < 2 * 86400000) pruned[key] = fired[key]
    for (var e = 0; e < events.length; e++) {
      pruned[events[e].key] = nowMs
      var ev = events[e]
      if (ev.kind === "alarm" || ev.kind === "timer") {
        current.ringing = current.ringing.concat([{ key: ev.key, kind: ev.kind, itemId: ev.item.id,
          title: panel.ringTitle(ev.kind, ev.item), body: panel.ringBody(ev.kind, ev.item, ev.at), at: nowMs }])
      }
    }
    current.fired = pruned
    if (changes.length) panel.itemsStore.updateMany(changes)
    for (var n = 0; n < events.length; n++) announce(events[n])
    return true
  }

  // The chimes of the minute nowMs falls in, once per minute across all
  // instances, and only while the minute is at most Model.CHIME_LATE_MS old;
  // returns true when `current` was changed. Muted, or while something
  // rings, the minute counts as done without a sound.
  function chime(current, nowMs) {
    if (!panel.displayOptionsStore.generalLoaded) return false
    var minute = Model.chimeMinuteFor(nowMs)
    if (!minute || minute <= Number(current.chimedAt || 0)) return false
    var plan = Model.chimePlan(panel.chimeSettings, minute)
    if (!plan.intervalBeeps && !plan.hourBeeps) return false
    current.chimedAt = minute
    if (!panel.chimesMuted && !current.ringing.length) playChime(plan.intervalBeeps, plan.hourBeeps)
    return true
  }

  // One-off notices; ringing ones go through syncEffects.
  function announce(event) {
    if (event.kind === "missedAlarm") {
      notify(panel.i18n("missedAlarmTitle"), panel.ringBody("alarm", event.item, event.at), "normal")
    } else if (event.kind === "pomodoro") {
      var next = Model.pomodoroAdvanced(event.item, event.at, Date.now())
      notify(panel.pomodoroPhaseTitle(next), panel.pomodoroPhaseBody(next), "normal")
      playCue(panel.soundFor("pomodoro"))
    }
  }

  // ---- Sound and notifications (leader only) ----

  property var notifiers: ({})
  property bool testingSound: false

  function syncEffects() {
    var wantKeys = {}
    for (var i = 0; i < ringing.length; i++) {
      var ring = ringing[i]
      wantKeys[ring.key] = true
      if (!notifiers[ring.key]) startNotifier(ring)
    }
    for (var key in notifiers) {
      if (wantKeys[key]) continue
      closeNotifier(key)
    }
    // The sound starts with each new ring and then runs its course: alarms
    // for up to five minutes, timers for one, unless stopped first.
    var newest = ringing.length ? ringing[ringing.length - 1] : null
    var newestKey = newest ? newest.key : ""
    if (newestKey === soundKey) return
    soundKey = newestKey
    if (newest) {
      var alarmRinging = ringing.some(function(r) { return r.kind === "alarm" })
      playSound(panel.soundFor(alarmRinging ? "alarm" : "timer"), alarmRinging ? 300 : 60)
    } else if (soundProc.running && !testingSound) {
      soundProc.running = false
    }
  }

  property string soundKey: ""

  // MORE_TIME_SOUND_DRY_RUN=1 logs what would play instead of playing it.
  readonly property bool soundDryRun: (Quickshell.env("MORE_TIME_SOUND_DRY_RUN") || "") !== ""

  function playSound(file, seconds) {
    testingSound = false
    if (soundProc.running) soundProc.running = false
    if (!file) return
    soundProc.file = file
    soundProc.command = ["bash", "-c",
      "end=$((SECONDS + $1)); while :; do pw-play --volume=\"$2\" \"$3\" || exit 0; "
        + "[ \"$SECONDS\" -ge \"$end\" ] && exit 0; sleep 0.7; done",
      "more-time-sound", String(seconds), String(panel.soundVolume), file]
    if (soundDryRun) {
      console.log("more-time: dry run:", soundProc.command.slice(3).join(" "))
      return
    }
    soundProc.running = true
  }

  // A one-off sound (a pomodoro phase ending) in its own process, so a
  // ringing alarm's or timer's sound keeps going.
  function playCue(file) {
    if (!file) return
    var command = ["pw-play", "--volume=" + panel.soundVolume, file]
    if (soundDryRun) {
      console.log("more-time: dry run:", command.join(" "))
      return
    }
    if (cueProc.running) cueProc.running = false
    cueProc.command = command
    cueProc.running = true
  }

  property Process cueProc: Process {}

  // ---- Chime beeps ----
  // Five synthesized tones (data/chime-tones.py): each an interval tone and,
  // a fifth lower, an hour tone. Written once by python3 (part of every
  // Omarchy install) into the cache and played with pw-play, about 200 ms of
  // silence between beeps (pw-play itself takes some 140 ms longer than the
  // tone; the ringing tones get a little more so the beeps stay countable)
  // and half a second between the series.
  readonly property var chimeTones: ["beep", "bell", "wood", "chirp", "glass"]
  readonly property var chimeGaps: ({ beep: 0.08, bell: 0.14, wood: 0.08, chirp: 0.08, glass: 0.12 })
  readonly property string chimeDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache"))
    + "/more-time"
  readonly property string chimeGenerator: String(Qt.resolvedUrl("data/chime-tones.py")).replace(/^file:\/\//, "")

  function chimeFile(tone, role) {
    return chimeDir + "/chime-" + tone + "-" + role + ".wav"
  }

  // intervalBeeps high beeps, a pause, hourBeeps low ones, in the chosen tone.
  function playChime(intervalBeeps, hourBeeps) {
    var a = Math.max(0, Math.floor(Number(intervalBeeps) || 0))
    var b = Math.max(0, Math.floor(Number(hourBeeps) || 0))
    if (!a && !b) return
    var tone = chimeTones.indexOf(panel.chimeTone) >= 0 ? panel.chimeTone : "beep"
    var gap = chimeGaps[tone]
    if (chimeProc.running) chimeProc.running = false
    var beep = soundDryRun ? "echo pw-play --volume=\"$v\" \"$1\"" : "pw-play --volume=\"$v\" \"$1\""
    chimeProc.command = ["bash", "-c",
      "v=$1 high=$2 a=$3 low=$4 b=$5 gap=$8\n"
        + "[ -s \"$high\" ] && [ -s \"$low\" ] || python3 \"$7\" \"$6\" \"$9\" || exit 0\n"
        + "beep() { " + beep + "; }\n"
        + "series() { local i; for ((i = 0; i < $2; i++)); do ((i)) && sleep \"$gap\"; beep \"$1\" || return 1; done; }\n"
        + "series \"$high\" \"$a\" || exit 0\n"
        + "((a && b)) && sleep 0.4\n"
        + "series \"$low\" \"$b\"\n",
      "more-time-chime", String(panel.chimeVolume), chimeFile(tone, "interval"), String(a), chimeFile(tone, "hour"),
      String(b), chimeDir, chimeGenerator, String(gap), tone]
    if (soundDryRun) console.log("more-time: chime dry run:", tone, a, "high,", b, "low, gap", gap, "volume", panel.chimeVolume)
    chimeProc.running = true
  }

  // The settings' test buttons, from whichever instance is open: one
  // interval beep, or the hour chime of the current hour.
  function testChime(which) {
    if (which === "hourChime") {
      var settings = Object.assign({}, panel.chimeSettings, { chimeInterval: "off" })
      var hour = new Date()
      hour.setMinutes(0, 0, 0)
      playChime(0, Model.chimePlan(settings, hour.getTime()).hourBeeps)
    } else {
      playChime(1, 0)
    }
  }

  property Process chimeProc: Process {
    stdout: SplitParser {
      onRead: function(line) { if (ringer.soundDryRun) console.log("more-time: dry run:", line) }
    }
  }

  // The settings' test button: once, from whichever instance is open.
  function testSound(soundId) {
    playSound(soundFiles[soundId] || "", 0)
    testingSound = true
  }

  property Process soundProc: Process {
    property string file: ""
    onExited: if (ringer.testingSound) ringer.testingSound = false
  }

  property Component notifierComponent: Component {
    Process {
      id: notifier
      property string ringKey: ""
      property string notificationId: ""
      property bool closing: false
      stdout: SplitParser {
        onRead: function(line) {
          var value = String(line).trim()
          if (value === "") return
          if (notifier.notificationId === "" && /^\d+$/.test(value)) {
            notifier.notificationId = value
            return
          }
          if (value === "snooze") ringer.snooze(notifier.ringKey)
          else ringer.stop(notifier.ringKey)
        }
      }
      // Closing the notification without a choice stops the ringing too.
      onExited: {
        if (!notifier.closing) ringer.stop(notifier.ringKey)
        ringer.forgetNotifier(notifier.ringKey, notifier)
      }
    }
  }

  function startNotifier(ring) {
    var args = ["notify-send", "--app-name=More Time", "--icon=more-time", "--urgency=critical",
      "--print-id", "--wait", "--action=stop=" + Model.notificationText(panel.i18n("stop"))]
    if (ring.kind === "alarm") args.push("--action=snooze=" + Model.notificationText(panel.i18n("snoozeFor",
      { minutes: panel.alarmSnoozeMinutes(ring.itemId) })))
    args.push(Model.notificationText(ring.title), Model.notificationText(ring.body))
    var proc = notifierComponent.createObject(ringer, { ringKey: ring.key, command: args })
    var next = Object.assign({}, notifiers)
    next[ring.key] = proc
    notifiers = next
    proc.running = true
  }

  function closeNotifier(key) {
    var proc = notifiers[key]
    if (!proc) return
    proc.closing = true
    if (proc.notificationId !== "") {
      Quickshell.execDetached(["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications",
        "--object-path", "/org/freedesktop/Notifications",
        "--method", "org.freedesktop.Notifications.CloseNotification", proc.notificationId])
    } else {
      proc.running = false
    }
  }

  function forgetNotifier(key, proc) {
    if (notifiers[key] !== proc) return
    var next = Object.assign({}, notifiers)
    delete next[key]
    notifiers = next
    proc.destroy()
  }

  function notify(title, body, urgency) {
    Quickshell.execDetached(["notify-send", "--app-name=More Time", "--icon=more-time",
      "--urgency=" + (urgency || "normal"), Model.notificationText(title), Model.notificationText(body)])
  }

  // ---- Stop and snooze, from any instance ----

  function stop(key) {
    var current = read()
    var next = current.ringing.filter(function(r) { return r.key !== key })
    if (next.length === current.ringing.length) return
    current.ringing = next
    write(current)
  }

  function stopAll() {
    var current = read()
    if (!current.ringing.length) return
    current.ringing = []
    write(current)
  }

  function snooze(key) {
    var current = read()
    var ring = null
    for (var i = 0; i < current.ringing.length; i++) if (current.ringing[i].key === key) ring = current.ringing[i]
    if (!ring) return
    if (ring.kind === "alarm") {
      var now = Date.now()
      panel.itemsStore.update("alarms", ring.itemId, function(alarm) {
        return Model.alarmSnoozed(alarm, now, alarm.snoozeMinutes)
      })
    }
    current.ringing = current.ringing.filter(function(r) { return r.key !== key })
    write(current)
  }

  // Space or `s` in the panel, the bar's middle click: the newest ring.
  function stopNewest() {
    if (ringing.length) stop(ringing[ringing.length - 1].key)
  }

  function snoozeNewest() {
    for (var i = ringing.length - 1; i >= 0; i--) {
      if (ringing[i].kind === "alarm") {
        snooze(ringing[i].key)
        return true
      }
    }
    stopNewest()
    return false
  }

  Component.onDestruction: {
    for (var key in notifiers) if (notifiers[key]) notifiers[key].running = false
    if (soundProc.running) soundProc.running = false
    if (chimeProc.running) chimeProc.running = false
    if (cueProc.running) cueProc.running = false
  }
}
