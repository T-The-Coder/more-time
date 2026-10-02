import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

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
  // Entries set to "on hover" show while the pointer rests on the widget,
  // the text can turn bold, and the popup can open from hover alone. Once the
  // popup is open it covers the bar, so the panel's hover zones (widget
  // spot, and the stretch from it to the card) stand in for the button.
  readonly property bool pointerOnWidget: button.tooltipHovered
  // Opened while the pointer was on the widget; holds until the popup's
  // zones have seen the pointer, since they only learn of it once it moves.
  property bool hoverLatched: false
  property bool popupZoneSeen: false
  property bool openedByHover: false
  // Closed with the pointer still on the widget: no reopening until it
  // has left.
  property bool hoverOpenBlocked: false
  readonly property bool pointerNear: pointerOnWidget || (opened && !!panelLoader.item
    && (panelLoader.item.popupPointerInside || (hoverLatched && !popupZoneSeen)))
  // Bold follows the pointer at once, unlike the "on hover" entries, which
  // wait for the enter / leave timers below.
  readonly property bool boldOnHover: !!panelLoader.item && panelLoader.item.menubarBoldOnHover
  readonly property bool hoverNow: pointerOnWidget
    || (opened && !!panelLoader.item && panelLoader.item.popupPointerOnAnchor)
  readonly property bool hoverBold: boldOnHover && hoverNow

  // Coloured values "while hovered" follow the same condition as bold.
  Binding {
    target: panelLoader.item
    property: "menubarAccentHover"
    value: root.hoverNow
    when: !!panelLoader.item
  }

  // An entry's colour role (Panel.menubarEntries) as a colour; "sky#rrggbb"
  // carries its colour.
  function roleColor(role) {
    if (String(role).indexOf("sky#") === 0) return String(role).slice(3)
    return role === "accent" ? Color.accent : (role === "urgent" ? Color.urgent
      : (role === "muted" && panelLoader.item ? panelLoader.item.mutedText : button.foreground))
  }

  onPointerNearChanged: {
    if (pointerNear) {
      hoverLeaveTimer.stop()
      hoverEnterTimer.start()
    } else {
      hoverEnterTimer.stop()
      hoverLeaveTimer.start()
    }
  }
  onPointerOnWidgetChanged: if (!pointerOnWidget && !opened) hoverOpenBlocked = false
  onOpenedChanged: {
    if (opened) {
      hoverLatched = pointerOnWidget || (!!panelLoader.item && panelLoader.item.menubarHovered)
    } else {
      hoverOpenBlocked = pointerOnWidget
        || (!!panelLoader.item && panelLoader.item.popupPointerOnAnchor)
        || (hoverLatched && !popupZoneSeen)
      hoverLatched = false
      openedByHover = false
    }
    popupZoneSeen = false
  }

  Connections {
    target: panelLoader.item
    ignoreUnknownSignals: true
    function onPopupPointerInsideChanged() {
      if (panelLoader.item.popupPointerInside) root.popupZoneSeen = true
    }
  }

  Timer {
    id: hoverEnterTimer
    interval: 120
    onTriggered: if (panelLoader.item) panelLoader.item.menubarHovered = true
  }

  Timer {
    id: hoverLeaveTimer
    interval: 400
    onTriggered: {
      var panel = panelLoader.item
      if (!panel) return
      panel.menubarHovered = false
      // A popup opened by hover closes again once the pointer has left it,
      // unless something in it is being edited.
      if (root.openedByHover && root.opened && root.popupZoneSeen
          && !panel.settingsOpen && !panel.editingText && panel.editingId === "")
        panel.close()
    }
  }

  Timer {
    id: hoverOpenTimer
    interval: 250
    running: !!panelLoader.item && panelLoader.item.menubarOpenWidgetOnHover
      && root.pointerOnWidget && !root.opened && !root.hoverOpenBlocked
    onTriggered: {
      if (!panelLoader.item || root.opened) return
      root.openedByHover = true
      panelLoader.item.openFromHotkey()
    }
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
        Quickshell.execDetached(["omarchy-notification-send", "-g", "\u{f0150}", lines[0], lines.slice(1).join("\n")])
      } else if (b === Qt.MiddleButton) {
        // Stops what rings; otherwise starts or pauses the first pomodoro.
        if (panel.ringer.ringing.length) panel.ringer.stopNewest()
        else {
          var pomodoros = panel.itemsStore.items.pomodoros
          if (pomodoros.length) panel.toggleItem("pomodoros", pomodoros[0].id)
        }
      }
      // A click on a popup opened by hover keeps it open.
      else if (root.openedByHover && root.opened) root.openedByHover = false
      else root.togglePanel()
    }
  }
}
