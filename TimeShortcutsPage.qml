import QtQuick
import qs.Commons

// Settings page listing every keyboard shortcut and the mouse clicks.
// Mirrors Panel.handlePanelKey, the tabs' handleEditorKey,
// TimeSettings.handleKey, TimeHero and BarWidget.onPressed; keep them in
// sync. Group order as in More Weather: general, this plugin's own groups,
// settings, mouse.
Column {
  id: shortcutsPage
  required property var panel
  width: parent ? parent.width : 0
  spacing: Style.space(12)

  readonly property var groups: [
    {
      title: "shortcutsGroupGeneral",
      rows: [
        { keys: ["Esc"], action: "shortcutClose" },
        { keys: ["Tab", "⇧ Tab"], action: "shortcutSwitchPanel" },
        { keys: ["Ctrl ,"], action: "shortcutSettings" },
        { keys: ["1–9"], action: "shortcutTabs" },
        { keys: ["o"], action: "shortcutOpenApp" },
        { keys: ["m"], action: "shortcutMuteChimes" },
        { keys: ["Alt 0"], action: "shortcutPlaceHere" },
        { keys: ["Alt 1–9"], action: "shortcutCityJump" },
        { keys: ["Alt ← →"], action: "shortcutPlaceCycle" },
        { keys: ["PgUp", "PgDn"], action: "shortcutPage" },
        { keys: ["Home", "End"], action: "shortcutJump" }
      ]
    },
    {
      title: "shortcutsGroupItems",
      rows: [
        { keys: ["↑ ↓", "j k"], action: "shortcutSelect" },
        { keys: ["⇧ ↑ ↓", "J K"], action: "shortcutMove" },
        { keys: ["n", "+"], action: "shortcutNew" },
        { keys: ["Space", "Enter"], action: "shortcutToggle" },
        { keys: ["e"], action: "shortcutEdit" },
        { keys: ["r"], action: "shortcutReset" },
        { keys: ["x", "Del"], action: "shortcutDelete" },
        { keys: ["l"], action: "shortcutLap" },
        { keys: ["s"], action: "shortcutSkip" },
        { keys: ["← →", "h l"], action: "shortcutTimerMinute" }
      ]
    },
    {
      title: "shortcutsGroupEditor",
      rows: [
        { keys: ["← →", "h l"], action: "shortcutEditorField" },
        { keys: ["↑ ↓", "j k"], action: "shortcutEditorValue" },
        { keys: ["⇧ ↑ ↓"], action: "shortcutEditorMinute" },
        { keys: ["0–9"], action: "shortcutEditorTypeTime" },
        { keys: ["Space"], action: "shortcutEditorDay" },
        { keys: ["Enter"], action: "shortcutEditorDone" }
      ]
    },
    {
      title: "shortcutsGroupWorld",
      rows: [
        { keys: ["/", "+"], action: "shortcutCitySearch" },
        { keys: ["↑ ↓"], action: "shortcutSearchSelect" },
        { keys: ["Tab", "⇧ Tab"], action: "shortcutSearchSection" },
        { keys: ["Enter"], action: "shortcutSearchPick" },
        { keys: ["+"], action: "shortcutSearchAdd" },
        { keys: ["−"], action: "shortcutSearchRemove" },
        { keys: ["Esc"], action: "shortcutSearchCancel" },
        { keys: ["← →", "h l"], action: "shortcutCity" },
        { keys: ["e"], action: "shortcutDialStyle" },
        { keys: ["x", "Del"], action: "shortcutCityRemove" }
      ]
    },
    {
      title: "shortcutsGroupAstro",
      rows: [
        { keys: ["Ctrl ← →"], action: "shortcutAstroTurn" },
        { keys: ["Ctrl ↑ ↓"], action: "shortcutAstroTilt" },
        { keys: ["+", "−"], action: "shortcutAstroZoom" },
        { keys: ["0"], action: "shortcutAstroReset" }
      ]
    },
    {
      title: "shortcutsGroupRinging",
      rows: [
        { keys: ["Space", "Enter"], action: "shortcutStopRinging" },
        { keys: ["s"], action: "shortcutSnooze" }
      ]
    },
    {
      title: "shortcutsGroupSettings",
      rows: [
        { keys: ["Tab", "⇧ Tab"], action: "shortcutSettingsPages" },
        { keys: ["1", "2", "3"], action: "shortcutSettingsSurface" },
        { keys: ["↑ ↓", "j k"], action: "shortcutSettingsMove" },
        { keys: ["← →", "h l"], action: "shortcutSettingsChange" },
        { keys: ["Space", "Enter"], action: "shortcutSettingsToggle" },
        { keys: ["⇧ ↑ ↓", "J K"], action: "shortcutSettingsReorder" },
        { keys: ["PgUp", "PgDn"], action: "shortcutPage" },
        { keys: ["Esc"], action: "shortcutSettingsClose" }
      ]
    },
    {
      title: "shortcutsGroupMouse",
      rows: [
        { keys: ["mouseLeft"], translateKeys: true, action: "shortcutMouseToggle" },
        { keys: ["mouseLeft"], translateKeys: true, action: "shortcutMouseOpenApp" },
        { keys: ["mouseMiddle"], translateKeys: true, action: "shortcutMiddleClick" },
        { keys: ["mouseRight"], translateKeys: true, action: "shortcutStatus" },
        { keys: ["mousePin"], translateKeys: true, action: "shortcutPlaceHere" },
        { keys: ["mousePlaceName"], translateKeys: true, action: "shortcutPlaceWorld" }
      ]
    }
  ]

  Text {
    textFormat: Text.PlainText
    width: parent.width
    text: shortcutsPage.panel.i18n("shortcutsHint")
    color: shortcutsPage.panel.mutedText
    font.family: shortcutsPage.panel.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
  }

  Repeater {
    model: shortcutsPage.groups

    Rectangle {
      id: groupCard
      required property var modelData
      width: shortcutsPage.width
      height: groupContent.implicitHeight + Style.space(20)
      radius: Style.cornerRadius
      color: "transparent"
      border.color: shortcutsPage.panel.subtleText
      border.width: Style.spacing.hairline

      Column {
        id: groupContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(10)
        spacing: Style.space(6)

        Text {
          textFormat: Text.PlainText
          text: shortcutsPage.panel.upperLabel(shortcutsPage.panel.i18n(groupCard.modelData.title))
          color: shortcutsPage.panel.foreground
          font.family: shortcutsPage.panel.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: true
          font.letterSpacing: 1
        }

        Repeater {
          model: groupCard.modelData.rows

          Item {
            id: shortcutRow
            required property var modelData
            width: groupContent.width
            height: Math.max(keyRow.height, actionText.implicitHeight)

            // Key caps in a fixed-width column so the descriptions line up.
            Row {
              id: keyRow
              width: Math.round(groupContent.width * 0.36)
              spacing: Style.space(4)

              Repeater {
                model: shortcutRow.modelData.keys

                Rectangle {
                  required property string modelData
                  width: keyLabel.implicitWidth + Style.space(12)
                  height: keyLabel.implicitHeight + Style.space(6)
                  radius: Math.min(4, Style.cornerRadius)
                  color: Style.hoverFillFor(shortcutsPage.panel.foreground, Color.accent)
                  border.color: shortcutsPage.panel.subtleText
                  border.width: Style.spacing.hairline

                  Text {
                    textFormat: Text.PlainText
                    id: keyLabel
                    anchors.centerIn: parent
                    text: shortcutRow.modelData.translateKeys
                      ? shortcutsPage.panel.i18n(parent.modelData) : parent.modelData
                    color: shortcutsPage.panel.foreground
                    font.family: shortcutsPage.panel.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
              }
            }

            Text {
              textFormat: Text.PlainText
              id: actionText
              anchors.left: keyRow.right
              anchors.leftMargin: Style.space(8)
              anchors.right: parent.right
              anchors.verticalCenter: keyRow.verticalCenter
              text: shortcutsPage.panel.i18n(shortcutRow.modelData.action)
              color: shortcutsPage.panel.mutedText
              font.family: shortcutsPage.panel.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }
          }
        }
      }
    }
  }
}
