import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Timers, as many as needed. A preset starts one at once; the field takes
// any length ("10" minutes, "1:30", "1h30", "45s"), optionally followed by a
// name ("10 Tea"). Each runs, pauses,
// gains or loses a minute and resets on its own, and rings when it runs
// out (TimeRinger).
Column {
  id: view
  required property var panel
  spacing: Style.space(8)

  readonly property var list: panel.itemsStore.items.timers
  readonly property string selectedId: {
    var item = panel.selectedItem("timers")
    return item ? item.id : ""
  }
  readonly property var presets: panel.timerPresets

  TimeTabHeader {
    width: parent.width
    panel: view.panel
    hint: view.panel.i18n("timerKeysHint")
  }

  // Presets and the free entry.
  Flow {
    width: parent.width
    spacing: Style.space(5)

    Repeater {
      model: view.presets

      TimeButton {
        required property int modelData
        panel: view.panel
        label: modelData >= 60 ? view.panel.i18n("hoursShort", { hours: modelData / 60 })
          : view.panel.i18n("minutesShort", { minutes: modelData })
        onActivated: view.panel.startTimer(modelData * 60000, "")
      }
    }

    // Wide enough for the whole placeholder in every language.
    TextMetrics {
      id: placeholderMetrics
      font: entry.font
      text: entry.placeholderText
    }

    TextField {
      id: entry
      width: Math.min(view.width, Math.max(Style.space(150),
        Math.ceil(placeholderMetrics.advanceWidth) + leftPadding + rightPadding + Style.space(4)))
      height: Style.space(32)
      foreground: view.panel.foreground
      font.family: view.panel.fontFamily
      font.pixelSize: Style.font.bodySmall
      placeholderText: view.panel.i18n("timerEntryPlaceholder")
      readonly property var parsedEntry: Model.parseTimerEntry(text)
      readonly property int parsed: parsedEntry.ms

      Connections {
        target: view.panel
        function onNewTimerOpenChanged() {
          if (view.panel.newTimerOpen) {
            entry.forceActiveFocus()
            entry.selectAll()
          }
        }
      }
      onAccepted: {
        if (parsed > 0) {
          view.panel.startTimer(parsed, parsedEntry.label)
          text = ""
        }
        view.panel.newTimerOpen = false
        view.panel.restoreKeyFocus()
      }
      onActiveFocusChanged: {
        if (activeFocus) view.panel.activeTextField = entry
        else {
          if (view.panel.activeTextField === entry) view.panel.activeTextField = null
          view.panel.newTimerOpen = false
        }
      }
    }

    Text {
      visible: entry.text !== ""
      height: Style.space(32)
      verticalAlignment: Text.AlignVCenter
      text: entry.parsed > 0
        ? "= " + view.panel.durationText(entry.parsed) + (entry.parsedEntry.label ? " · " + entry.parsedEntry.label : "")
        : view.panel.i18n("timerEntryInvalid")
      color: entry.parsed > 0 ? view.panel.mutedText : Color.urgent
      font.family: view.panel.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  Text {
    visible: view.list.length === 0
    width: parent.width
    text: view.panel.i18n("noTimers")
    color: view.panel.mutedText
    font.family: view.panel.fontFamily
    font.pixelSize: Style.font.bodySmall
    font.italic: true
    wrapMode: Text.WordWrap
  }

  Repeater {
    model: view.list

    TimeCard {
      id: card
      required property var modelData
      panel: view.panel
      selected: modelData.id === view.selectedId
      armed: view.panel.armedDeleteId === modelData.id
      highlighted: modelData.state === "done"
      readonly property double remaining: Model.timerRemaining(modelData, view.panel.nowMs)
      onClicked: view.panel.select("timers", modelData.id)

      Item {
        width: parent.width
        height: Math.max(textColumn.implicitHeight, buttons.height)

        Column {
          id: textColumn
          anchors.left: parent.left
          anchors.right: buttons.left
          anchors.verticalCenter: parent.verticalCenter

          TimeLabelField {
            panel: view.panel
            width: parent.width
            editing: view.panel.editingId === card.modelData.id
            text: view.panel.itemTitle("timers", card.modelData)
              + (card.modelData.state === "running"
                ? "  ·  " + view.panel.i18n("endsAt", { time: view.panel.wallClockAt(card.modelData.endsAt) }) : "")
            value: card.modelData.label
            onCommitted: function(value) { view.panel.updateItem("timers", card.modelData.id, { label: value }) }
          }

          Text {
            text: card.modelData.state === "done" ? view.panel.i18n("timerExpired")
              : view.panel.durationText(card.remaining, { countdown: true })
            color: card.modelData.state === "done" ? Color.urgent
              : (card.modelData.state === "running" ? view.panel.foreground : view.panel.mutedText)
            font.family: view.panel.fontFamily
            font.pixelSize: Style.font.displayLarge
            font.bold: true
          }
        }

        Row {
          id: buttons
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(4)

          TimeIconButton {
            panel: view.panel
            glyph: card.modelData.state === "running" ? "\u{f03e4}" : "\u{f040a}"
            active: card.modelData.state === "running"
            onActivated: {
              view.panel.select("timers", card.modelData.id)
              view.panel.toggleItem("timers", card.modelData.id)
            }
          }
          TimeIconButton {
            panel: view.panel
            glyph: "\u{f0415}"
            onActivated: view.panel.extendTimer(card.modelData.id, 60000)
          }
          TimeIconButton {
            panel: view.panel
            glyph: "\u{f0450}"
            onActivated: view.panel.resetItem("timers", card.modelData.id)
          }
          TimeIconButton {
            panel: view.panel
            glyph: "\u{f0a7a}"
            armed: card.armed
            onActivated: {
              view.panel.select("timers", card.modelData.id)
              view.panel.deleteItem("timers", card.modelData.id)
            }
          }
        }
      }

      TimeProgressBar {
        panel: view.panel
        width: parent.width
        progress: Model.timerProgress(card.modelData, view.panel.nowMs)
        tint: card.modelData.state === "done" ? Color.urgent : Color.accent
      }
    }
  }
}
