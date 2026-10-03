import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Pomodoros, as many as needed, each with its own focus and break lengths
// (25/5 to begin with, from Settings → General), an optional long break
// every few rounds, and whether the next phase starts by itself.
Column {
  id: view
  required property var panel
  spacing: Style.space(8)

  readonly property var list: panel.itemsStore.items.pomodoros
  readonly property string selectedId: {
    var item = panel.selectedItem("pomodoros")
    return item ? item.id : ""
  }
  readonly property var editing: panel.editingId !== "" ? panel.itemsStore.find("pomodoros", panel.editingId) : null

  // Editor fields, in the order ← → walk them.
  readonly property var fields: ["work", "shortBreak", "longBreak", "longEvery", "autoContinue", "label"]
  readonly property var limits: ({ work: [1, 240], shortBreak: [1, 120], longBreak: [1, 120], longEvery: [0, 12] })

  function stepField(field, delta) {
    if (!editing) return
    if (field === "autoContinue") {
      panel.updateItem("pomodoros", editing.id, { autoContinue: !editing.autoContinue })
      return
    }
    var limit = limits[field]
    if (!limit) return
    // Lengths move by five beyond ten minutes.
    var step = field !== "longEvery" && editing[field] + (delta > 0 ? 0 : -1) >= 10 ? 5 : 1
    var value = Math.max(limit[0], Math.min(limit[1], editing[field] + delta * step))
    var fields = {}
    fields[field] = value
    panel.updateItem("pomodoros", editing.id, fields)
  }

  // ← → field, ↑ ↓ value, Space switches, Enter names it or closes.
  function handleEditorKey(event) {
    if (!editing) return false
    var text = String(event.text || "")
    var key = event.key
    var field = fields[panel.editField] || "work"
    if (key === Qt.Key_Left || key === Qt.Key_Right || text === "h" || text === "l") {
      var delta = (key === Qt.Key_Right || text === "l") ? 1 : -1
      if (LayoutMirroring.enabled) delta = -delta
      panel.editField = Math.max(0, Math.min(fields.length - 1, panel.editField + delta))
      return true
    }
    if (key === Qt.Key_Up || key === Qt.Key_Down || text === "k" || text === "j") {
      stepField(field, key === Qt.Key_Up || text === "k" ? 1 : -1)
      return true
    }
    if (key === Qt.Key_Space) {
      if (field === "autoContinue") stepField(field, 1)
      return true
    }
    if (key === Qt.Key_Return || key === Qt.Key_Enter) {
      if (field === "label") labelEditing = true
      else panel.editingId = ""
      return true
    }
    return false
  }

  // The name field takes the keys only once Enter (or a click) opens it,
  // so ← → can pass over it.
  property bool labelEditing: false
  Connections {
    target: view.panel
    function onEditingIdChanged() { view.labelEditing = false }
  }

  TimeTabHeader {
    width: parent.width
    panel: view.panel
    hint: view.panel.i18n("pomodoroKeysHint")
    addLabel: view.panel.i18n("newPomodoro")
    onAdd: view.panel.addItem("pomodoros")
  }

  Text {
    textFormat: Text.PlainText
    visible: view.list.length === 0
    width: parent.width
    text: view.panel.i18n("noPomodoros")
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
      required property int index
      panel: view.panel
      selected: modelData.id === view.selectedId
      armed: view.panel.armedDeleteId === modelData.id
      readonly property bool editingThis: view.panel.editingId === modelData.id
      readonly property bool onBreak: modelData.phase !== "work"
      onClicked: view.panel.select("pomodoros", modelData.id)

      Item {
        width: parent.width
        height: Math.max(textColumn.implicitHeight, buttons.height)

        Column {
          id: textColumn
          anchors.left: parent.left
          anchors.right: buttons.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: (card.modelData.label || view.panel.itemTitle("pomodoros", card.modelData)
                + (view.list.length > 1 ? " " + (card.index + 1) : ""))
              + "  ·  " + card.modelData.work + "/" + card.modelData.shortBreak
              + (card.modelData.longEvery > 0 ? "/" + card.modelData.longBreak : "")
            color: view.panel.mutedText
            font.family: view.panel.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }

          Row {
            spacing: Style.space(10)

            Text {
              textFormat: Text.PlainText
              id: remainingText
              text: view.panel.durationText(Model.pomodoroRemaining(card.modelData, view.panel.nowMs), { countdown: true })
              color: card.modelData.state === "running" ? view.panel.foreground : view.panel.mutedText
              font.family: view.panel.fontFamily
              font.pixelSize: Style.font.displayLarge
              font.bold: true
            }

            Text {
              textFormat: Text.PlainText
              anchors.baseline: remainingText.baseline
              text: view.panel.upperLabel(view.panel.pomodoroPhaseName(card.modelData.phase))
              color: card.onBreak ? Color.accent : view.panel.foreground
              font.family: view.panel.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1
            }
          }

          // One dot per finished focus round; a long break resets the row.
          Row {
            spacing: Style.space(3)
            visible: card.modelData.completed > 0

            Repeater {
              model: Math.min(12, card.modelData.completed)
              Rectangle {
                width: Style.space(6)
                height: width
                radius: width / 2
                color: Color.accent
              }
            }
            Text {
              textFormat: Text.PlainText
              visible: card.modelData.completed > 12
              text: "+" + (card.modelData.completed - 12)
              color: view.panel.mutedText
              font.family: view.panel.fontFamily
              font.pixelSize: Style.font.caption
            }
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
              view.panel.select("pomodoros", card.modelData.id)
              view.panel.toggleItem("pomodoros", card.modelData.id)
            }
          }
          TimeIconButton {
            panel: view.panel
            glyph: "\u{f04ad}"
            onActivated: view.panel.skipPomodoro(card.modelData.id)
          }
          TimeIconButton {
            panel: view.panel
            glyph: "\u{f0450}"
            onActivated: view.panel.resetItem("pomodoros", card.modelData.id)
          }
          TimeIconButton {
            panel: view.panel
            glyph: "\u{f03eb}"
            active: card.editingThis
            onActivated: {
              view.panel.select("pomodoros", card.modelData.id)
              view.panel.editingId = card.editingThis ? "" : card.modelData.id
              view.panel.editField = 0
            }
          }
          TimeIconButton {
            panel: view.panel
            glyph: "\u{f0a7a}"
            armed: card.armed
            onActivated: {
              view.panel.select("pomodoros", card.modelData.id)
              view.panel.deleteItem("pomodoros", card.modelData.id)
            }
          }
        }
      }

      TimeProgressBar {
        panel: view.panel
        width: parent.width
        progress: Model.pomodoroProgress(card.modelData, view.panel.nowMs)
        tint: card.onBreak ? view.panel.mutedText : Color.accent
      }

      // The editor (e): lengths, long breaks, auto start, name.
      Flow {
        visible: card.editingThis
        width: parent.width
        spacing: Style.space(8)

        TimeStepper {
          panel: view.panel
          title: view.panel.i18n("focusPhase")
          valueText: view.panel.i18n("minutesShort", { minutes: card.modelData.work })
          kbFocused: view.panel.editField === 0
          onFocusRequested: view.panel.editField = 0
          onStep: function(delta) { view.stepField("work", delta) }
        }
        TimeStepper {
          panel: view.panel
          title: view.panel.i18n("breakPhase")
          valueText: view.panel.i18n("minutesShort", { minutes: card.modelData.shortBreak })
          kbFocused: view.panel.editField === 1
          onFocusRequested: view.panel.editField = 1
          onStep: function(delta) { view.stepField("shortBreak", delta) }
        }
        TimeStepper {
          panel: view.panel
          title: view.panel.i18n("longBreakPhase")
          valueText: view.panel.i18n("minutesShort", { minutes: card.modelData.longBreak })
          kbFocused: view.panel.editField === 2
          opacity: card.modelData.longEvery > 0 ? 1 : 0.5
          onFocusRequested: view.panel.editField = 2
          onStep: function(delta) { view.stepField("longBreak", delta) }
        }
        TimeStepper {
          panel: view.panel
          title: view.panel.i18n("longBreakEvery")
          valueText: card.modelData.longEvery > 0
            ? view.panel.i18n("everyRounds", { count: card.modelData.longEvery }) : view.panel.i18n("never")
          kbFocused: view.panel.editField === 3
          onFocusRequested: view.panel.editField = 3
          onStep: function(delta) { view.stepField("longEvery", delta) }
        }

        TimeSwitchRow {
          panel: view.panel
          width: Style.space(220)
          title: view.panel.i18n("autoContinue")
          indented: false
          switchState: card.modelData.autoContinue
          kbFocused: view.panel.editField === 4
          onToggled: {
            view.panel.editField = 4
            view.stepField("autoContinue", 1)
          }
        }

        TimeLabelField {
          id: pomodoroLabel
          panel: view.panel
          width: parent.width
          editing: card.editingThis && view.labelEditing
          kbFocused: card.editingThis && view.panel.editField === 5
          text: view.panel.i18n("nameField") + ": " + (card.modelData.label || "—")
          value: card.modelData.label
          onCommitted: function(value) {
            view.panel.updateItem("pomodoros", card.modelData.id, { label: value })
          }

          MouseArea {
            anchors.fill: parent
            enabled: !pomodoroLabel.editing
            onClicked: {
              view.panel.editField = 5
              view.labelEditing = true
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: view.panel.i18n("editorKeysHint")
          color: view.panel.hintText
          font.family: view.panel.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }
  }

  // Focus rounds today and this week, from the pomodoro log.
  Text {
    textFormat: Text.PlainText
    visible: view.list.length > 0 || view.panel.pomodoroTally.week > 0
    width: parent.width
    text: view.panel.i18n("pomodoroTally", view.panel.pomodoroTally)
    color: view.panel.mutedText
    font.family: view.panel.fontFamily
    font.pixelSize: Style.font.caption
  }
}
