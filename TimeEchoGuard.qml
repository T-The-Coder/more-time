import QtQuick

// For a file this instance writes and also watches (FileView with
// watchChanges): the watch reports each of our own writes, and one that
// reports an older write after a newer one is an echo that would roll the
// newer change back. Call wrote(text) with every write, and skip a load for
// which isEcho(text) is true.
QtObject {
  property var recent: []

  function wrote(text) {
    recent = recent.concat([String(text)]).slice(-8)
  }

  function isEcho(text) {
    var at = recent.indexOf(String(text))
    return at >= 0 && at < recent.length - 1
  }
}
