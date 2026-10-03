import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "more-time"

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  // Shape contract for shell.summon/hide/toggle routing (Bar.findPanelWidget
  // requires open/close/opened on the bar-widget root). Open maps to the
  // panel's hotkey path so summoning suppresses the center hover reveal.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  // Forwarded so this widget can stand in for the panel as the bar's popout
  // identity: Bar.requestPopout prefers closeForPopoutSwitch over close, and
  // KeyboardPanel reads popoutSwitchClosing back off its owner.
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  // --- hover ------------------------------------------------------------
  // Hover entries, opening on hover and closing again (TimeBarHover, shared
  // with More Weather). The button goes in as its own property: inside the
  // component `button: button` would name the component's own property.
  readonly property var barButton: button
  TimeBarHover {
    id: barHover
    panel: panelLoader.item
    button: root.barButton
    opened: root.opened
    editingBlocksClose: !!panelLoader.item && (panelLoader.item.settingsOpen || panelLoader.item.editingText
      || panelLoader.item.editingId !== "")
  }
  // Bold and coloured values "while hovered" follow the pointer at once
  // (hoverNow), unlike the "on hover" entries, which wait for its timers.
  readonly property bool hoverBold: !!panelLoader.item && panelLoader.item.menubarBoldOnHover && barHover.hoverNow

  Binding {
    target: panelLoader.item
    property: "menubarAccentHover"
    value: barHover.hoverNow
    when: !!panelLoader.item
  }

  // An entry's colour role (Panel.menubarEntries) as a colour; "sky#rrggbb"
  // carries its colour.
  function roleColor(role) {
    if (String(role).indexOf("sky#") === 0) return String(role).slice(3)
    return role === "accent" ? Color.accent : (role === "urgent" ? Color.urgent
      : (role === "muted" && panelLoader.item ? panelLoader.item.mutedText : button.foreground))
  }

  visible: !!panelLoader.item && (root.vertical
    ? panelLoader.item.menubarShowClock : panelLoader.item.menubarHasVisibleContent)
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      injectAgainTimer.start()
    }
  }

  // Once more after this event, from a Timer rather than Qt.callLater so a
  // widget removed with its monitor never runs the call without its root.
  Timer {
    id: injectAgainTimer
    interval: 0
    onTriggered: root.injectPanel()
  }

  // The bell blinks while something rings.
  property bool blinkOn: true
  Timer {
    interval: 500
    repeat: true
    running: !!panelLoader.item && panelLoader.item.ringer.ringing.length > 0
    onTriggered: root.blinkOn = !root.blinkOn
    onRunningChanged: root.blinkOn = true
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: root.visible
    fixedWidth: root.vertical ? Style.bar.iconSlot : clockBarContent.implicitWidth + Style.spaceReal(17.5)
    fixedHeight: root.vertical ? verticalClock.implicitHeight + Style.space(12) : -1
    horizontalMargin: 8.75
    verticalPadding: 8.75
    // Tooltip suppressed because the panel is the detail view.
    tooltipText: ""

    Row {
      id: clockBarContent
      visible: !root.vertical
      anchors.centerIn: parent
      spacing: Style.space(7)

      // Entries in the order chosen under Settings → Display → Menu bar.
      Repeater {
        model: panelLoader.item ? panelLoader.item.menubarEntries : []

        Row {
          id: entryRow
          required property var modelData
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(3)

          Text {
            textFormat: Text.PlainText
            visible: entryRow.modelData.glyph !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: entryRow.modelData.glyph
            color: entryRow.modelData.urgent ? Color.urgent : root.roleColor(entryRow.modelData.color)
            opacity: entryRow.modelData.urgent && !root.blinkOn ? 0.25 : 1
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            renderType: Text.NativeRendering
          }

          // The text in parts, each in its own colour (a city by day or
          // night, the seconds muted).
          Row {
            visible: entryRow.modelData.text !== ""
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
              model: entryRow.modelData.parts || []

              Text {
                textFormat: Text.PlainText
                required property var modelData
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.text
                color: root.roleColor(modelData.color)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.body
                font.bold: root.hoverBold
                renderType: Text.NativeRendering
              }
            }
          }
        }
      }
    }

    // A bar on a screen edge: hours over minutes, and the bell when it rings.
    Column {
      id: verticalClock
      visible: root.vertical
      anchors.centerIn: parent
      spacing: 0

      Repeater {
        model: {
          var panel = panelLoader.item
          if (!panel || !root.vertical) return []
          var parts = panel.localParts
          var hour = panel.hour12 ? ((parts.hour % 12) || 12) : parts.hour
          var lines = [panel.hour12 ? String(hour) : (hour < 10 ? "0" : "") + hour,
            (parts.minute < 10 ? "0" : "") + parts.minute]
          if (panel.ringer.ringing.length) lines.push("\u{f009e}")
          return lines
        }

        Text {
          textFormat: Text.PlainText
          required property string modelData
          required property int index
          anchors.horizontalCenter: parent.horizontalCenter
          text: modelData
          color: index === 2 ? Color.urgent : button.foreground
          opacity: index === 2 && !root.blinkOn ? 0.25 : 1
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
          font.bold: root.hoverBold
          renderType: Text.NativeRendering
        }
      }
    }

    onPressed: function(b) {
      var panel = panelLoader.item
      if (!root.bar || !panel) return
      if (b === Qt.RightButton) {
        var lines = panel.statusSummary()
        Quickshell.execDetached(["omarchy-notification-send", "-g", "\u{f0150}", Model.notificationText(lines[0]), Model.notificationText(lines.slice(1).join("\n"))])
      } else if (b === Qt.MiddleButton) {
        // Stops what rings; otherwise starts or pauses the first pomodoro.
        if (panel.ringer.ringing.length) panel.ringer.stopNewest()
        else {
          var pomodoros = panel.itemsStore.items.pomodoros
          if (pomodoros.length) panel.toggleItem("pomodoros", pomodoros[0].id)
        }
      }
      // A click on a popup opened by hover keeps it open.
      else if (barHover.openedByHover && root.opened) barHover.openedByHover = false
      else root.togglePanel()
    }
  }
}
