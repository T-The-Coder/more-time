import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "AstroLapse.js" as AstroLapse

// The World tab: the map of the time zones (flat or a globe) with its chips
// and, below, the timeline and its time lapse; the places themselves are
// the Places tab (TimePlaces.qml). A click on a place on the map makes it
// the current place, as selecting it there does.
Column {
  id: view
  objectName: "timeWorld"
  required property var panel
  spacing: Style.space(10)

  TimeTabHeader {
    width: parent.width
    panel: view.panel
    hint: view.panel.displaySetting("worldMap", true)
      ? view.panel.i18n("globeKeysHint") + (view.timelineOn ? " · " + view.panel.i18n("worldTimeKeysHint") : "") : ""
  }

  // Zoom and turn keys for the globe or the flat map (Panel.handlePanelKey).
  function handleMapKey(event) {
    // The timeline: , . a day, Space play / pause (unless something
    // rings), Backspace back to now (n stays the city search).
    if (worldTimeline.visible && !(event.modifiers & Qt.ControlModifier)) {
      if (event.text === "," || event.text === ".") {
        stepDays(event.text === "." ? 1 : -1)
        return true
      }
      if (event.key === Qt.Key_Space && !panel.ringer.ringing.length) {
        togglePlay()
        return true
      }
      if (event.key === Qt.Key_Backspace && panel.worldTimePinned) {
        backToNow()
        return true
      }
    }
    var item = worldMapSlot.item
    if (!item || !worldMapSlot.visible) return false
    var target = item.handleMapKey ? item : (item.children.length && item.children[0].handleMapKey ? item.children[0] : null)
    return target ? target.handleMapKey(event) : false
  }

  // The flat map or the globe ("worldStyle"); both take the same inputs.
  Loader {
    id: worldMapSlot
    // The height still visible below the slot's top in the app window or
    // the popup, less a margin: the globe and the map fit into it, down to
    // a minimum below which the page scrolls.
    readonly property real fitHeight: view.panel.viewportHeight - view.panel.tabContentTop - y - Style.space(16)
      - (worldChips.visible ? worldChips.height + view.spacing : 0)
      - (worldTimeline.visible ? worldTimeline.height + view.spacing : 0)
    visible: view.panel.displaySetting("worldMap", true)
    active: visible
    width: parent.width
    height: item ? item.implicitHeight : 0
    sourceComponent: view.panel.displaySetting("worldStyle", "map") === "globe" ? globeView : flatMapView

    // While the timeline shows another instant: which, over the map.
    Rectangle {
      z: 20
      visible: view.panel.worldTimePinned
      x: Style.space(4)
      y: Style.space(4)
      width: shownLabel.implicitWidth + Style.space(12)
      height: shownLabel.implicitHeight + Style.space(6)
      radius: Style.cornerRadius
      color: Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 0.85)
      border.color: Color.accent
      border.width: Style.spacing.hairline
      Text {
        id: shownLabel
        textFormat: Text.PlainText
        anchors.centerIn: parent
        text: view.panel.i18n("astroShown", { date: view.shownText() })
        color: Color.accent
        font.family: view.panel.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }
  }
  // The chips under the map: its shape, the night, the twilight bands, the
  // Moon, the labels, the ruler (flat map); the same options as the World
  // card, for the surface shown.
  TimeChipBar {
    id: worldChips
    visible: worldMapSlot.visible
    width: parent.width
    panel: view.panel
    readonly property bool globeShape: view.panel.displaySetting("worldStyle", "map") === "globe"
    readonly property bool twilightOn: view.panel.displaySetting("heroGoldenHour", false) === true
      || view.panel.displaySetting("heroBlueHour", false) === true
    chips: [
      { id: "map", glyph: "\u{f034d}", label: "mapStyleFlat", on: !globeShape },
      { id: "globe", glyph: "\u{f01e7}", label: "mapStyleGlobe", on: globeShape },
      { id: "night", glyph: "\u{f0594}", label: "chip_night", on: view.panel.displaySetting("worldNight", true) === true, divider: true },
      { id: "twilight", glyph: "\u{f059a}", label: "chip_twilight", on: twilightOn },
      { id: "moon", glyph: "\u{f0f65}", label: "moon", on: view.panel.displaySetting("worldMoon", false) === true },
      { id: "labels", glyph: "\u{f04fc}", label: "chip_labels", on: view.panel.displaySetting("worldMapLabels", true) === true }
    ].concat(globeShape ? [] : [{ id: "ruler", glyph: "\u{f046d}", label: "chip_ruler",
      on: view.panel.displaySetting("worldRuler", true) === true }])
    onToggled: function(id) {
      var p = view.panel
      if (id === "map" || id === "globe") p.setViewDisplaySetting("worldStyle", id === "map" ? "map" : "globe")
      else if (id === "twilight") {
        p.setViewDisplaySetting("heroGoldenHour", !twilightOn)
        p.setViewDisplaySetting("heroBlueHour", !twilightOn)
      } else {
        var key = { night: "worldNight", moon: "worldMoon", labels: "worldMapLabels", ruler: "worldRuler" }[id]
        p.setViewDisplaySetting(key, !(p.displaySetting(key, key !== "worldMoon") === true))
      }
    }
  }
  // ---- The timeline under the map: a time lapse (AstroLapse.js) of the
  //      night, the twilight, the Sun and the Moon; the city list keeps the
  //      real time ----
  readonly property bool timelineOn: panel.displaySetting("worldTimeline", true) === true
  property bool playing: false
  readonly property string lapseId: {
    var id = panel.displaySetting("worldLapse", "dayInMinute")
    var p = AstroLapse.preset(id)
    return p && p.views.indexOf("globe") >= 0 ? id : "dayInMinute"
  }
  readonly property var lapse: AstroLapse.preset(lapseId)
  readonly property int lapseFps: Number(panel.generalSetting("motionFps", "15")) || 15
  function showAt(ms) {
    panel.worldShownMs = ms
    panel.worldTimePinned = true
  }
  function togglePlay() {
    if (!playing && !panel.worldTimePinned) showAt(Date.now())
    playing = !playing
  }
  function stepDays(days) {
    playing = false
    showAt((panel.worldTimePinned ? panel.worldShownMs : Date.now()) + days * 86400000)
  }
  function backToNow() {
    playing = false
    panel.worldTimePinned = false
  }
  // Leaving the tab or switching the timeline off goes back to now.
  onTimelineOnChanged: if (!timelineOn) backToNow()
  Component.onDestruction: {
    panel.worldTimePinned = false
  }
  TimeLapseTimer {
    preset: view.lapse
    fps: view.lapseFps
    shownMs: view.panel.worldShownMs
    running: view.playing && view.panel.motionAllowed && view.panel.currentTab === "world"
    onAdvanced: function(ms, stopped) {
      view.showAt(ms)
      if (stopped) view.playing = false
    }
  }
  // The shown instant in this computer's local time.
  function shownText() {
    return panel.momentWithYear(panel.worldMinuteMs)
  }

  Row {
    id: worldTimeline
    visible: worldMapSlot.visible && view.timelineOn
    width: parent.width
    spacing: Style.space(8)

    TimeIconButton {
      id: worldPlay
      anchors.verticalCenter: parent.verticalCenter
      panel: view.panel
      glyph: view.playing ? "\u{f03e4}" : "\u{f040a}"
      glyphSize: Style.font.body
      tooltip: view.panel.i18n("shortcutWorldPlay")
      active: view.playing
      onActivated: view.togglePlay()
    }
    // The speeds: a day in a minute, a day in ten seconds, the seasons.
    Row {
      id: worldSpeeds
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(4)
      Repeater {
        model: ["dayInMinute", "dayIn10Seconds", "seasonsInMinute"]
        Rectangle {
          required property string modelData
          // The chips' look (TimeChipBar): filled when picked.
          readonly property bool picked: view.lapseId === modelData
          width: speedLabel.implicitWidth + Style.space(14)
          height: Style.space(24)
          radius: Style.cornerRadius
          color: picked ? Style.selectedFillFor(view.panel.foreground, Color.accent)
            : (speedMouse.containsMouse ? Style.hoverFillFor(view.panel.foreground, Color.accent) : "transparent")
          border.color: picked ? "transparent" : Qt.rgba(view.panel.foreground.r, view.panel.foreground.g, view.panel.foreground.b, 0.18)
          border.width: Style.spacing.hairline
          Text {
            id: speedLabel
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: view.panel.i18n("lapseShort_" + parent.modelData)
            color: parent.picked ? Color.accent : view.panel.mutedText
            font.family: view.panel.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: parent.picked
          }
          MouseArea {
            id: speedMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: view.panel.setViewDisplaySetting("worldLapse", parent.modelData)
          }
        }
      }
    }
    Text {
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - worldPlay.width - worldSpeeds.width - worldNow.width - 3 * parent.spacing
      text: view.shownText()
      color: view.panel.worldTimePinned ? Color.accent : view.panel.mutedText
      font.family: view.panel.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
    TimeButton {
      id: worldNow
      anchors.verticalCenter: parent.verticalCenter
      panel: view.panel
      label: view.panel.i18n("astroNow")
      onActivated: view.backToNow()
    }
  }

  Component {
    id: flatMapView
    // Full width, unless the map would not fit the visible height: then
    // narrower, centred, at least Style.space(240) high.
    Item {
      implicitHeight: flatMap.implicitHeight
      TimeWorldMap {
        id: flatMap
        readonly property real fitMapHeight: Math.max(Style.space(240), worldMapSlot.fitHeight - rulerHeight * 2)
        width: Math.min(parent.width, fitMapHeight / aspect)
        x: (parent.width - width) / 2
        panel: view.panel
        selectedIndex: view.panel.selectedCity
        onCityClicked: function(index) { view.panel.selectedCity = index }
      }
    }
  }
  Component {
    id: globeView
    TimeGlobe {
      fitHeight: worldMapSlot.fitHeight
      panel: view.panel
      selectedIndex: view.panel.selectedCity
      onCityClicked: function(index) { view.panel.selectedCity = index }
    }
  }
}
