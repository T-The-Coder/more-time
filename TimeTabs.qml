import QtQuick
import qs.Commons
import qs.Ui

// The tab strip: world clock, alarms, timers, stopwatches, pomodoros, in the
// order chosen under Settings → Display. The number keys pick them the same
// way. The picked tab's content is created below by the panel.
Column {
  id: tabsSection
  required property var panel
  visible: panel.displayTabs.length > 0
  spacing: Style.space(10)

  Rectangle {
    width: parent.width
    height: Style.spacing.hairline
    color: tabsSection.panel.foreground
    opacity: 0.12
  }

  Row {
    id: tabStrip
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: Style.space(5)
    readonly property real tabWidth: Math.min(Style.space(96),
      (tabsSection.width - spacing * Math.max(0, tabsSection.panel.displayTabs.length - 1))
        / Math.max(1, tabsSection.panel.displayTabs.length))
    // Narrower than this, a tab shows its glyph only (the same rule as in
    // More Weather, so the strips stay alike).
    readonly property bool glyphOnly: tabWidth < Style.space(80)

    Repeater {
      model: tabsSection.panel.displayTabs

      Rectangle {
        id: tabItem
        required property string modelData
        readonly property bool selected: modelData === tabsSection.panel.currentTab
        width: tabStrip.tabWidth
        height: Style.space(28)
        radius: Style.cornerRadius
        color: selected || tabMouse.containsMouse
          ? Style.hoverFillFor(tabsSection.panel.foreground, Color.accent) : "transparent"

        Row {
          anchors.centerIn: parent
          spacing: Style.space(4)
          width: Math.min(implicitWidth, parent.width - Style.space(8))

          Text {
            textFormat: Text.PlainText
            id: tabGlyph
            anchors.verticalCenter: parent.verticalCenter
            text: tabsSection.panel.tabGlyph(parent.parent.modelData)
            color: parent.parent.selected
              ? Style.hoverStateColor(tabsSection.panel.foreground, Color.accent)
              : tabsSection.panel.mutedText
            font.family: tabsSection.panel.fontFamily
            font.pixelSize: Style.font.body
          }

          Text {
            textFormat: Text.PlainText
            visible: !tabStrip.glyphOnly
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.parent.width - Style.space(8) - tabGlyph.width - parent.spacing)
            text: tabsSection.panel.tabLabel(parent.parent.modelData)
            color: parent.parent.selected
              ? Style.hoverStateColor(tabsSection.panel.foreground, Color.accent)
              : tabsSection.panel.mutedText
            font.family: tabsSection.panel.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: parent.parent.selected
            elide: Text.ElideRight
          }
        }

        MouseArea {
          id: tabMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: tabsSection.panel.activeTab = parent.modelData
        }

        // Glyph only: the name on hover.
        PanelToolTip {
          visible: tabStrip.glyphOnly && tabMouse.containsMouse
          text: tabsSection.panel.tabLabel(tabItem.modelData)
          fontFamily: tabsSection.panel.fontFamily
        }
      }
    }
  }
}
