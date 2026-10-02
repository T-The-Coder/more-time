import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Alarms, as many as needed: a time, the weekdays it repeats on (none: once),
// a name and the snooze length. They ring on this computer's clock, with the
// panel closed too (TimeRinger in the bar).
Column {
  id: view
  required property var panel
  spacing: Style.space(8)

  readonly property var list: panel.itemsStore.items.alarms
  readonly property string selectedId: {
    var item = panel.selectedItem("alarms")
    return item ? item.id : ""
  }
  readonly property var editing: panel.editingId !== "" ? panel.itemsStore.find("alarms", panel.editingId) : null
  // Editor fields, in the order ← → walk them: hour, minute, the seven
  // weekdays in the locale's order, snooze, name.
  readonly property int dayFieldStart: 2
  readonly property int snoozeField: 9
  readonly property int labelField: 10
  property bool labelEditing: false
  Connections {
    target: view.panel
    function onEditingIdChanged() { view.labelEditing = false }
  }

  function stepTime(field, delta) {
    if (!editing) return
    if (field === 0) {
      panel.updateItem("alarms", editing.id, { hour: (editing.hour + delta + 24) % 24, armedAt: Date.now(), enabled: true })
    } else {
      // Minutes move by five; a click on − / + or ↑ ↓ with Shift by one.
      var minute = (editing.minute + delta + 60) % 60
      panel.updateItem("alarms", editing.id, { minute: minute, armedAt: Date.now(), enabled: true })
    }
  }

  function toggleDay(day) {
    if (!editing) return
    var days = editing.days.slice()
    var index = days.indexOf(day)
    if (index >= 0) days.splice(index, 1)
    else days.push(day)
    panel.updateItem("alarms", editing.id, { days: Model.normalizedDays(days), armedAt: Date.now(), enabled: true })
  }

  function stepSnooze(delta) {
    if (!editing) return
    panel.updateItem("alarms", editing.id, { snoozeMinutes: Math.max(1, Math.min(60, editing.snoozeMinutes + delta)) })
  }

  // ← → field, ↑ ↓ value (⇧ for single minutes), Space a weekday, Enter
  // names it (on the name) or closes the editor.
  function handleEditorKey(event) {
    if (!editing) return false
    var text = String(event.text || "")
    var key = event.key
    var shift = !!(event.modifiers & Qt.ShiftModifier)
    var field = panel.editField
    if (key === Qt.Key_Left || key === Qt.Key_Right || text === "h" || text === "l") {
      var delta = (key === Qt.Key_Right || text === "l") ? 1 : -1
      if (LayoutMirroring.enabled) delta = -delta
      panel.editField = Math.max(0, Math.min(labelField, field + delta))
      return true
    }
    var up = key === Qt.Key_Up || text === "k" || text === "K"
    var down = key === Qt.Key_Down || text === "j" || text === "J"
    if (up || down) {
      var sign = up ? 1 : -1
      if (field === 0) stepTime(0, sign)
      else if (field === 1) stepTime(1, sign * (shift || text === "K" || text === "J" ? 1 : 5))
      else if (field === snoozeField) stepSnooze(sign)
      else if (field >= dayFieldStart && field < snoozeField) toggleDay(panel.weekdayOrder[field - dayFieldStart])
      return true
    }
    if (key === Qt.Key_Space) {
      if (field >= dayFieldStart && field < snoozeField) toggleDay(panel.weekdayOrder[field - dayFieldStart])
      return true
    }
    if (key === Qt.Key_Return || key === Qt.Key_Enter) {
      if (field === labelField) labelEditing = true
      else panel.editingId = ""
      return true
    }
    // Digits type the time: "730" → 7:30, "1915" → 19:15.
    if (/^[0-9]$/.test(text)) {
      typed = (typed + text).slice(-4)
      typedTimer.restart()
      var value = Number(typed)
      var hour = typed.length <= 2 ? value : Math.floor(value / 100)
      var minute = typed.length <= 2 ? 0 : value % 100
      if (hour <= 23 && minute <= 59)
        panel.updateItem("alarms", editing.id, { hour: hour, minute: minute, armedAt: Date.now(), enabled: true })
      return true
    }
    return false
  }

  property string typed: ""
  Timer {
    id: typedTimer
    interval: 1500
    onTriggered: view.typed = ""
  }

  TimeTabHeader {
    width: parent.width
    panel: view.panel
    hint: view.panel.i18n("alarmKeysHint")
    addLabel: view.panel.i18n("newAlarm")
    onAdd: view.panel.addItem("alarms")
  }

  Text {
    visible: view.list.length === 0
    width: parent.width
    text: view.panel.i18n("noAlarms")
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
      readonly property bool editingThis: view.panel.editingId === modelData.id
      readonly property double nextRing: Model.alarmNextRing(modelData, view.panel.nowMs)
      onClicked: view.panel.select("alarms", modelData.id)

      Item {
        width: parent.width
        height: Math.max(textColumn.implicitHeight, buttons.height)
        opacity: card.modelData.enabled ? 1 : 0.55

        Column {
          id: textColumn
          anchors.left: parent.left
          anchors.right: buttons.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          Text {
            width: parent.width
            text: view.panel.itemTitle("alarms", card.modelData) + "  ·  " + view.panel.alarmDaysText(card.modelData.days)
            color: view.panel.mutedText
            font.family: view.panel.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }

          Text {
            text: view.panel.wallClock(card.modelData.hour, card.modelData.minute)
            color: view.panel.foreground
            font.family: view.panel.fontFamily
            font.pixelSize: Style.font.displayLarge
            font.bold: true
          }

          Text {
            visible: card.nextRing > 0
            text: card.modelData.snoozeUntil > view.panel.nowMs
              ? view.panel.i18n("snoozedUntil", { time: view.panel.wallClockAt(card.modelData.snoozeUntil) })
              : view.panel.untilText(card.nextRing - view.panel.nowMs)
            color: view.panel.mutedText
            font.family: view.panel.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        Row {
          id: buttons
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(6)

          TimeSwitchToggle {
            anchors.verticalCenter: parent.verticalCenter
            panel: view.panel
            checked: card.modelData.enabled

            MouseArea {
              anchors.fill: parent
              anchors.margins: -Style.space(4)
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                view.panel.select("alarms", card.modelData.id)
                view.panel.toggleItem("alarms", card.modelData.id)
              }
            }
          }
          TimeIconButton {
            panel: view.panel
            glyph: "\u{f03eb}"
            active: card.editingThis
            onActivated: {
              view.panel.select("alarms", card.modelData.id)
              view.panel.editingId = card.editingThis ? "" : card.modelData.id
              view.panel.editField = 0
            }
          }
          TimeIconButton {
            panel: view.panel
            glyph: "\u{f0a7a}"
            armed: card.armed
            onActivated: {
              view.panel.select("alarms", card.modelData.id)
              view.panel.deleteItem("alarms", card.modelData.id)
            }
          }
        }
      }

      // The editor (e).
      Column {
        visible: card.editingThis
        width: parent.width
        spacing: Style.space(8)

        Row {
          spacing: Style.space(8)

          TimeStepper {
            panel: view.panel
            title: view.panel.i18n("hourField")
            valueText: Model.pad2(card.modelData.hour)
            kbFocused: view.panel.editField === 0
            onFocusRequested: view.panel.editField = 0
            onStep: function(delta) { view.stepTime(0, delta) }
          }
          TimeStepper {
            panel: view.panel
            title: view.panel.i18n("minuteField")
            valueText: Model.pad2(card.modelData.minute)
            kbFocused: view.panel.editField === 1
            onFocusRequested: view.panel.editField = 1
            onStep: function(delta) { view.stepTime(1, delta) }
          }
          TimeStepper {
            panel: view.panel
            title: view.panel.i18n("snoozeField")
            valueText: view.panel.i18n("minutesShort", { minutes: card.modelData.snoozeMinutes })
            kbFocused: view.panel.editField === view.snoozeField
            onFocusRequested: view.panel.editField = view.snoozeField
            onStep: function(delta) { view.stepSnooze(delta) }
          }
        }

        // Weekdays in the locale's order; none chosen rings once.
        Row {
          spacing: Style.space(4)

          Repeater {
            model: view.panel.weekdayOrder

            Rectangle {
              required property int modelData
              required property int index
              readonly property bool chosen: card.modelData.days.indexOf(modelData) >= 0
              readonly property bool kbFocused: view.panel.editField === view.dayFieldStart + index
              width: Style.space(38)
              height: Style.space(28)
              radius: Style.cornerRadius
              color: chosen ? Style.selectedFillFor(view.panel.foreground, Color.accent)
                : (dayMouse.containsMouse ? Style.hoverFillFor(view.panel.foreground, Color.accent) : "transparent")
              border.color: kbFocused ? Color.accent : view.panel.subtleText
              border.width: Style.spacing.hairline

              Text {
                anchors.centerIn: parent
                text: view.panel.weekdayName(parent.modelData, false)
                color: parent.chosen ? Style.selectedStateColor(view.panel.foreground, Color.accent) : view.panel.foreground
                font.family: view.panel.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: parent.chosen
              }

              MouseArea {
                id: dayMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  view.panel.editField = view.dayFieldStart + parent.index
                  view.toggleDay(parent.modelData)
                }
              }
            }
          }
        }

        TimeLabelField {
          id: alarmLabel
          panel: view.panel
          width: parent.width
          editing: card.editingThis && view.labelEditing
          kbFocused: view.panel.editField === view.labelField
          text: view.panel.i18n("nameField") + ": " + (card.modelData.label || "—")
          value: card.modelData.label
          onCommitted: function(value) { view.panel.updateItem("alarms", card.modelData.id, { label: value }) }

          MouseArea {
            anchors.fill: parent
            enabled: !alarmLabel.editing
            onClicked: {
              view.panel.editField = view.labelField
              view.labelEditing = true
            }
          }
        }

        Text {
          width: parent.width
          text: view.panel.i18n("alarmEditorKeysHint")
          color: view.panel.hintText
          font.family: view.panel.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
