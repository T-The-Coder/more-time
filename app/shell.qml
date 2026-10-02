import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Time" as Time

// The standalone More Time window: the plugin's panel in standalone mode,
// with the Omarchy shell's Commons and Ui next to it (see app/more-time).
ShellRoot {
  id: app

  // omarchy-theme-set pushes the new palette over IPC to the Omarchy shell
  // only; this separate process would keep its startup colors. The theme
  // name file is rewritten on every switch, after the new theme directory is
  // in place, so re-read the theme from here the same way the shell's
  // applyTheme does.
  FileView {
    id: themeNameFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
    watchChanges: true
    printErrors: false
    onFileChanged: {
      reload()
      themeReloadDebounce.restart()
    }
  }

  Timer {
    id: themeReloadDebounce
    interval: 250
    onTriggered: {
      Color.colorsFile.reload()
      Color.shellFile.reload()
      Style.scheduleRefresh()
    }
  }

  Time.Panel {
    standaloneMode: true
    Component.onCompleted: open()
  }
}
