import QtQuick
import qs.Commons
import qs.Ui

// A display option with a few values (`choices`) in a tab's settings card,
// lined up with the switches around it: its title, then the dropdown. It
// registers with the settings so the keys open and step it like the others.
Item {
  id: optionDropdown
  required property var panel
  required property var settings
  property var option: ({})
  property bool rowEnabled: true
  readonly property string key: option.key || ""

  width: parent ? parent.width : 0
  height: Style.space(40)
  enabled: rowEnabled
  opacity: rowEnabled ? 1 : 0.42

  Text {
    anchors.left: parent.left
    anchors.leftMargin: Style.space(12)
    anchors.right: dropdown.left
    anchors.rightMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    text: optionDropdown.option.title || ""
    color: optionDropdown.panel.foreground
    font.family: optionDropdown.panel.fontFamily
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideRight
  }

  Dropdown {
    id: dropdown
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(180)
    showLabel: false
    fontFamily: optionDropdown.panel.fontFamily
    hasCursor: optionDropdown.settings.focusId === optionDropdown.key
    onHasCursorChanged: if (hasCursor) optionDropdown.settings.ensureVisible(this)
    onPopupOpenChanged: if (!popupOpen) optionDropdown.panel.restoreKeyFocus()
    value: optionDropdown.key !== "" ? String(optionDropdown.panel.settingsDisplaySetting(optionDropdown.key, "")) : ""
    options: optionDropdown.option.choices || []
    onChanged: function(value) { optionDropdown.panel.displayOptionsStore.setSettingsDisplaySetting(optionDropdown.key, value) }
    Component.onCompleted: {
      if (optionDropdown.key === "" || !optionDropdown.option.choices) return
      var items = Object.assign({}, optionDropdown.settings.dropdownItems)
      items[optionDropdown.key] = dropdown
      optionDropdown.settings.dropdownItems = items
    }
  }
}
