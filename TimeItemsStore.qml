import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Alarms, timers, stopwatches and pomodoros, in one file that the bar and
// the app both read and write. Running things are stored as instants (see
// Model.js), so whichever instance reads the file shows the same state.
//
// Changes build on the state in memory, which the file watch keeps in step
// with the other instance's writes. Re-reading the file right before a
// change was tried and lost items: setText writes asynchronously, so a
// second change in the same event read the file from before the first.
Item {
  id: store
  required property var panel

  property var items: Model.emptyItems()
  property bool loaded: false
  readonly property var kinds: ["alarms", "timers", "stopwatches", "pomodoros"]

  property FileView file: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/more-time-items.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: store.apply(text())
    onLoadFailed: store.apply("")
  }

  // Late reports of this instance's own older writes are skipped.
  property TimeEchoGuard echo: TimeEchoGuard {}

  function apply(raw) {
    if (echo.isEcho(raw)) return
    var next = Model.parseItems(raw)
    // Unchanged content keeps the arrays, so list delegates stay put.
    if (loaded && JSON.stringify(next) === JSON.stringify(items)) return
    items = next
    var first = !loaded
    loaded = true
    if (first) flushPending()
  }

  // Changes asked for before the file was read (an IPC startTimer right
  // after a start) wait for it: written on top of an empty list they would
  // wipe the file.
  property var pending: []

  function later(fn) {
    pending = pending.concat([fn])
  }

  function flushPending() {
    var queued = pending
    pending = []
    for (var i = 0; i < queued.length; i++) queued[i]()
  }

  function current() {
    return Model.parseItems(JSON.stringify(items))
  }

  function write(next) {
    items = next
    loaded = true
    var text = JSON.stringify(next, null, 1) + "\n"
    echo.wrote(text)
    file.setText(text)
  }

  // Applies fn(list) → list to one kind and writes the result.
  function change(kind, fn) {
    if (kinds.indexOf(kind) < 0) return
    if (!loaded) return later(function() { store.change(kind, fn) })
    var next = current()
    next[kind] = fn(next[kind])
    write(next)
  }

  function add(kind, item) {
    change(kind, function(list) { return list.concat([item]) })
  }

  function remove(kind, id) {
    change(kind, function(list) { return Model.removeItem(list, id) })
  }

  function move(kind, id, delta) {
    change(kind, function(list) { return Model.moveItem(list, id, delta) })
  }

  // Replaces one item by fn(item) → item, working on the item as it is on
  // disk now.
  function update(kind, id, fn) {
    change(kind, function(list) {
      var item = Model.findItem(list, id)
      return item ? Model.replaceItem(list, fn(item)) : list
    })
  }

  // Several items of several kinds at once, from the ringer: one write for
  // everything due in the same second.
  function updateMany(changes) {
    if (!changes.length) return
    if (!loaded) return later(function() { store.updateMany(changes) })
    var next = current()
    for (var i = 0; i < changes.length; i++) {
      var c = changes[i]
      // The pomodoro tally is one object, not a list.
      if (c.kind === "pomodoroLog") {
        next.pomodoroLog = c.fn(next.pomodoroLog)
        continue
      }
      var item = Model.findItem(next[c.kind] || [], c.id)
      if (item) next[c.kind] = Model.replaceItem(next[c.kind], c.fn(item))
    }
    write(next)
  }

  function find(kind, id) {
    return Model.findItem(items[kind] || [], id)
  }

  // Replaces everything, for settings import.
  function replaceAll(raw) {
    if (!loaded) return later(function() { store.replaceAll(raw) })
    write(Model.parseItems(JSON.stringify(raw || {})))
  }
}
