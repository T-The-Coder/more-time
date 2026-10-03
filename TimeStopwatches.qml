import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Stopwatches, as many as needed: each starts, pauses, takes laps and
// resets on its own. They keep running with the panel closed and across
// restarts (Model.stopwatchElapsed reads the start instant).
Column {
  id: view
  required property var panel
  spacing: Style.space(8)

  readonly property var list: panel.itemsStore.items.stopwatches
  readonly property string selectedId: {
    var item = panel.selectedItem("stopwatches")
    return item ? item.id : ""
  }
  readonly property bool hundredths: panel.displaySetting("stopwatchHundredths", true)

  function elapsedText(watch) {
    var now = watch.running && hundredths ? Math.max(panel.fineNowMs, panel.nowMs) : panel.nowMs
    return panel.durationText(Model.stopwatchElapsed(watch, now), { hundredths: hundredths })
  }

  TimeTabHeader {
    width: parent.width
    panel: view.panel
    hint: view.panel.i18n("stopwatchKeysHint")
    addLabel: view.panel.i18n("newStopwatch")
    onAdd: view.panel.addItem("stopwatches")
  }

  Text {
    textFormat: Text.PlainText
    visible: view.list.length === 0
    width: parent.width
    text: view.panel.i18n("noStopwatches")
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
      onClicked: view.panel.select("stopwatches", modelData.id)

      Item {
        width: parent.width
        height: Math.max(timeText.implicitHeight, buttons.height)

        Column {
          anchors.left: parent.left
          anchors.right: buttons.left
          anchors.verticalCenter: parent.verticalCenter

          TimeLabelField {
            panel: view.panel
            width: parent.width
            editing: view.panel.editingId === card.modelData.id
            text: view.panel.itemTitle("stopwatches", card.modelData)
              + (card.modelData.label === "" && view.list.length > 1 ? " " + (card.index + 1) : "")
            value: card.modelData.label
            onCommitted: function(value) { view.panel.updateItem("stopwatches", card.modelData.id, { label: value }) }
          }

          Text {
            textFormat: Text.PlainText
            id: timeText
            text: view.elapsedText(card.modelData)
            color: card.modelData.running ? view.panel.foreground : view.panel.mutedText
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
            glyph: card.modelData.running ? "\u{f03e4}" : "\u{f040a}"
            active: card.modelData.running
            onActivated: {
              view.panel.select("stopwatches", card.modelData.id)
              view.panel.toggleItem("stopwatches", card.modelData.id)
            }
          }
          TimeIconButton {
            panel: view.panel
            glyph: "\u{f0cb7}"
            enabled: card.modelData.running
            onActivated: view.panel.lapStopwatch(card.modelData.id)
          }
          TimeIconButton {
            panel: view.panel
            glyph: "\u{f0450}"
            onActivated: view.panel.resetItem("stopwatches", card.modelData.id)
          }
          TimeIconButton {
            panel: view.panel
            glyph: "\u{f0a7a}"
            armed: card.armed
            onActivated: {
              view.panel.select("stopwatches", card.modelData.id)
              view.panel.deleteItem("stopwatches", card.modelData.id)
            }
          }
        }
      }

      // Laps, newest first: number, the lap's own time, the running total.
      Column {
        visible: card.modelData.laps.length > 0
        width: parent.width
        spacing: Style.space(2)

        Repeater {
          model: {
            var rows = Model.stopwatchLapRows(card.modelData)
            return view.panel.standaloneMode ? rows.slice(0, 12) : rows.slice(0, 5)
          }

          Row {
            required property var modelData
            width: parent.width
            spacing: Style.space(10)

            Text {
              textFormat: Text.PlainText
              width: Style.space(56)
              text: view.panel.i18n("lapNumber", { number: parent.modelData.number })
              color: view.panel.mutedText
              font.family: view.panel.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            Text {
              textFormat: Text.PlainText
              width: Style.space(90)
              text: view.panel.durationText(parent.modelData.split, { hundredths: view.hundredths })
              color: parent.modelData.fastest ? Color.accent
                : (parent.modelData.slowest ? Color.urgent : view.panel.foreground)
              font.family: view.panel.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: parent.modelData.fastest || parent.modelData.slowest
            }
            Text {
              textFormat: Text.PlainText
              text: view.panel.durationText(parent.modelData.total, { hundredths: view.hundredths })
              color: view.panel.mutedText
              font.family: view.panel.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
        }
      }
    }
  }
}
