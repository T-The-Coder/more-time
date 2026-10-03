import QtQuick
import qs.Commons
import qs.Ui

// An item's name: plain text, or a text field while the item is edited
// (e). Enter keeps the new name, Esc leaves it as it was.
Item {
  id: labelField
  required property var panel
  property bool editing: false
  // The keyboard is on the field, not yet typing in it.
  property bool kbFocused: false
  // What shows when not editing (the name, or a generic title).
  property string text: ""
  // The stored label, empty for the generic title.
  property string value: ""
  signal committed(string value)

  implicitHeight: editing ? field.implicitHeight : label.implicitHeight
  height: implicitHeight

  Text {
    textFormat: Text.PlainText
    id: label
    visible: !labelField.editing
    width: parent.width
    text: labelField.text
    color: labelField.kbFocused ? labelField.panel.foreground : labelField.panel.mutedText
    font.family: labelField.panel.fontFamily
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideRight

    Rectangle {
      visible: labelField.kbFocused
      anchors.top: parent.bottom
      width: Math.min(parent.width, parent.implicitWidth)
      height: Style.space(2)
      color: Color.accent
    }
  }

  TextField {
    id: field
    visible: labelField.editing
    width: Math.min(parent.width, Style.space(260))
    foreground: labelField.panel.foreground
    font.family: labelField.panel.fontFamily
    font.pixelSize: Style.font.bodySmall
    placeholderText: labelField.panel.i18n("labelPlaceholder")
    maximumLength: 60

    onVisibleChanged: {
      if (!visible) return
      text = labelField.value
      forceActiveFocus()
      selectAll()
    }
    onAccepted: {
      labelField.committed(text.trim())
      labelField.panel.editingId = ""
      labelField.panel.restoreKeyFocus()
    }
    onActiveFocusChanged: {
      if (activeFocus) labelField.panel.activeTextField = field
      else if (labelField.panel.activeTextField === field) labelField.panel.activeTextField = null
    }
  }
}
