import QtQuick
import qs.Commons
import qs.Ui

// A row of toggle chips under a view (the World tab's map or globe, the
// Astro tab's solar system), like More Weather's globe legend: a glyph and
// a short name, the active ones filled like the selected tab, the names
// left out where the row is narrow (then the name shows above the chip
// under the pointer). The chips switch the same display options as the
// Display cards. chips: [{ id, glyph, label (i18n key), on, divider }];
// a click emits toggled(id).
Item {
  id: bar
  required property var panel
  property var chips: []
  signal toggled(string id)

  readonly property bool glyphOnly: width < Style.space(420)
  height: flow.implicitHeight

  Flow {
    id: flow
    width: parent.width
    spacing: Style.space(4)

    Repeater {
      model: bar.chips

      Row {
        id: slot
        required property var modelData
        spacing: Style.space(4)

        // A thin divider before a new group.
        Rectangle {
          visible: !!slot.modelData.divider
          width: 1
          height: Style.space(16)
          anchors.verticalCenter: parent.verticalCenter
          color: bar.panel.mutedText
          opacity: 0.5
        }
        Item {
          visible: !!slot.modelData.divider
          width: Style.space(2)
          height: 1
        }

        Rectangle {
          id: chip
          readonly property bool on: !!slot.modelData.on
          width: chipRow.implicitWidth + Style.space(14)
          height: Style.space(24)
          radius: Style.cornerRadius
          // On: the selected fill and accent text (as a toggled icon
          // button), clear on light and dark themes; hover: the hover fill.
          color: on ? Style.selectedFillFor(bar.panel.foreground, Color.accent)
            : (chipMouse.containsMouse ? Style.hoverFillFor(bar.panel.foreground, Color.accent) : "transparent")
          border.color: on ? "transparent" : Qt.rgba(bar.panel.foreground.r, bar.panel.foreground.g,
            bar.panel.foreground.b, 0.18)
          border.width: Style.spacing.hairline

          Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: Style.space(4)

            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: slot.modelData.glyph
              color: chip.on ? Color.accent : bar.panel.mutedText
              font.family: bar.panel.fontFamily
              font.pixelSize: Style.font.body
            }
            Text {
              textFormat: Text.PlainText
              visible: !bar.glyphOnly
              anchors.verticalCenter: parent.verticalCenter
              text: bar.panel.i18n(slot.modelData.label)
              color: chip.on ? Color.accent : bar.panel.mutedText
              font.family: bar.panel.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: chip.on
            }
          }

          MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: bar.toggled(slot.modelData.id)
          }

          // The name above a glyph-only chip under the pointer.
          Rectangle {
            visible: bar.glyphOnly && chipMouse.containsMouse
            y: -height - Style.space(4)
            x: (parent.width - width) / 2
            z: 10
            width: tipText.implicitWidth + Style.space(10)
            height: tipText.implicitHeight + Style.space(4)
            radius: Style.cornerRadius
            color: Color.popups.background
            border.color: Color.popups.border
            border.width: Style.spacing.hairline

            Text {
              id: tipText
              textFormat: Text.PlainText
              anchors.centerIn: parent
              text: bar.panel.i18n(slot.modelData.label)
              color: Color.popups.text
              font.family: bar.panel.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }
    }
  }
}
