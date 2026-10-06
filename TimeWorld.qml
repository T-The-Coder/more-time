import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "AstroLapse.js" as AstroLapse

// The world clock: the map with the time zones, then "Here" and the
// favourite cities with their time, their day against here, and their
// offset. The selected row is the current place the clock on top shows. Cities come
// from the search (/ or +): the system's zone list offline, any place
// through Open-Meteo's geocoder.
Column {
  id: view
  objectName: "timeWorld"
  required property var panel
  spacing: Style.space(10)

  readonly property var cities: panel.cityList
  readonly property var search: panel.citySearch
  readonly property bool showDials: panel.displaySetting("worldDials", true)
  // Sunrise, sunset, the next of the two per row (More Weather's entries).
  readonly property bool sunrise: panel.displaySetting("worldSunrise", false)
  readonly property bool sunset: panel.displaySetting("worldSunset", false)
  readonly property bool sunNext: panel.displaySetting("worldSunNext", true)

  // The pencil on the selected row: opens and closes the clock face chooser
  // (also e).
  component DialButton: TimeIconButton {
    panel: view.panel
    glyph: "\u{f03eb}"
    active: view.panel.dialChooserOpen
    onActivated: view.panel.dialChooserOpen = !view.panel.dialChooserOpen
  }

  // The five clock face styles as small dials under the selected row: a
  // click or ← → picks, Enter or Esc close (Panel.handlePanelKey).
  component DialChooser: Row {
    id: chooser
    property int placeIndex: -1
    property var parts: ({ hour: 10, minute: 9, second: 0 })
    property var sun: null
    property int offset: 0
    spacing: Style.space(10)
    leftPadding: Style.space(10)

    Repeater {
      model: Model.DIAL_STYLES

      Column {
        id: choice
        required property string modelData
        readonly property bool picked: view.panel.dialStyleFor(chooser.placeIndex) === modelData
        spacing: Style.space(2)

        Rectangle {
          width: Style.space(40)
          height: width
          radius: Style.cornerRadius
          color: choiceMouse.containsMouse ? Style.hoverFillFor(view.panel.foreground, Color.accent) : "transparent"
          border.color: choice.picked ? Color.accent : "transparent"
          border.width: Style.spacing.hairline

          TimeDial {
            anchors.centerIn: parent
            width: Style.space(32)
            panel: view.panel
            style: choice.modelData
            parts: chooser.parts
            offset: chooser.offset
            sun: chooser.sun
          }

          MouseArea {
            id: choiceMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: view.panel.setDialStyle(chooser.placeIndex, choice.modelData)
          }
        }

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: view.panel.i18n("dial_" + choice.modelData)
          color: choice.picked ? Style.hoverStateColor(view.panel.foreground, Color.accent) : view.panel.mutedText
          font.family: view.panel.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }

  TimeTabHeader {
    width: parent.width
    panel: view.panel
    hint: view.panel.i18n("worldKeysHint") + (view.panel.displaySetting("worldMap", true)
      ? " · " + view.panel.i18n("globeKeysHint") : "")
      + (view.panel.displaySetting("worldMap", true) && view.timelineOn ? " · " + view.panel.i18n("worldTimeKeysHint") : "")
    addLabel: view.panel.i18n("addCity")
    onAdd: view.panel.openCitySearch()
  }

  // The search: a field, then the matches. ↑ ↓ move within the matches or
  // the cities below, Tab switches between them, Enter adds the match or
  // makes the city current; in the cities (after Tab) + adds the marked
  // match and − removes the marked city (twice); Esc closes; as in More
  // Weather.
  Column {
    visible: view.panel.searchOpen
    width: parent.width
    spacing: Style.space(4)

    TextField {
      id: searchField
      width: parent.width
      foreground: view.panel.foreground
      font.family: view.panel.fontFamily
      font.pixelSize: Style.font.bodySmall
      placeholderText: view.panel.i18n("citySearchPlaceholder")
      onTextChanged: view.search.query = text

      Connections {
        target: view.panel
        function onSearchOpenChanged() {
          if (view.panel.searchOpen) {
            searchField.text = ""
            searchField.forceActiveFocus()
          } else if (searchField.activeFocus) {
            view.panel.restoreKeyFocus()
          }
        }
      }
      Keys.onUpPressed: view.search.step(-1)
      Keys.onDownPressed: view.search.step(1)
      Keys.onPressed: function(event) {
        var text = String(event.text || "")
        var plain = !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
          view.search.switchSection()
          event.accepted = true
        } else if (view.search.section === "saved" && plain && (event.key === Qt.Key_Plus || text === "+")) {
          // + and − act in the saved cities only (after Tab); among the
          // results they are typed ("Saint-Denis").
          view.search.addMarked()
          event.accepted = true
        } else if (view.search.section === "saved" && plain
            && (event.key === Qt.Key_Minus || text === "-" || text === "−")) {
          view.search.removeMarked()
          event.accepted = true
        }
      }
      onAccepted: view.search.pick()
      onActiveFocusChanged: {
        if (activeFocus) view.panel.activeTextField = searchField
        else if (view.panel.activeTextField === searchField) view.panel.activeTextField = null
      }
    }

    Repeater {
      model: view.search.results

      Rectangle {
        required property var modelData
        required property int index
        readonly property bool current: index === view.search.index && view.search.section === "results"
        width: parent.width
        height: Style.space(30)
        radius: Style.cornerRadius
        color: current || resultMouse.containsMouse ? Style.hoverFillFor(view.panel.foreground, Color.accent) : "transparent"
        border.color: current ? Color.accent : "transparent"
        border.width: Style.spacing.hairline

        Text {
          textFormat: Text.PlainText
          anchors.left: parent.left
          anchors.leftMargin: Style.space(10)
          anchors.right: zoneText.left
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          text: parent.modelData.name + (parent.modelData.country ? "  ·  " + parent.modelData.country : "")
          color: view.panel.foreground
          font.family: view.panel.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }

        // A zone guessed from the nearest zone1970 city (Nominatim names
        // none) is marked "≈".
        Text {
          textFormat: Text.PlainText
          id: zoneText
          anchors.right: parent.right
          anchors.rightMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          text: (parent.modelData.tzGuessed ? "≈ " : "") + parent.modelData.tz
          color: view.panel.mutedText
          font.family: view.panel.fontFamily
          font.pixelSize: Style.font.caption
        }

        MouseArea {
          id: resultMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: view.search.pick(parent.index)
        }
      }
    }

    // The list is full (Model.MAX_CITIES): adding waits for a removal.
    Text {
      textFormat: Text.PlainText
      visible: view.cities.length >= Model.MAX_CITIES
      width: parent.width
      text: view.panel.i18n("citiesFull")
      color: Color.urgent
      font.family: view.panel.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Text {
      textFormat: Text.PlainText
      visible: view.search.query.trim() !== "" && view.search.results.length === 0
      // Nothing in the zone list or from Open-Meteo: Enter also asks
      // Nominatim, once; after that, nothing found.
      text: view.search.busy ? view.panel.i18n("searching")
        : view.panel.i18n(view.search.online.fallbackQuery === view.search.query.trim() ? "noCityFound" : "searchEnterNominatim")
      color: view.panel.mutedText
      font.family: view.panel.fontFamily
      font.pixelSize: Style.font.caption
      font.italic: true
    }
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
    running: view.playing && view.panel.opened && view.panel.currentTab === "world"
    onAdvanced: function(ms, stopped) {
      view.showAt(ms)
      if (stopped) view.playing = false
    }
  }
  // The shown instant in this computer's local time.
  function shownText() {
    var ms = panel.worldMinuteMs
    var offset = Model.localOffsetSeconds(ms)
    return panel.dateFor(ms, offset, "long") + " · " + panel.clockFor(ms, offset, false)
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
          readonly property bool picked: view.lapseId === modelData
          width: speedLabel.implicitWidth + Style.space(10)
          height: Style.space(20)
          radius: Style.cornerRadius
          color: picked ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22) : "transparent"
          border.color: picked ? Color.accent : view.panel.subtleText
          border.width: Style.spacing.hairline
          Text {
            id: speedLabel
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: view.panel.i18n("lapseShort_" + parent.modelData)
            color: parent.picked ? Color.accent : view.panel.mutedText
            font.family: view.panel.fontFamily
            font.pixelSize: Style.font.caption
          }
          MouseArea {
            anchors.fill: parent
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

  Text {
    textFormat: Text.PlainText
    visible: view.cities.length === 0
    width: parent.width
    text: view.panel.i18n("noCities")
    color: view.panel.mutedText
    font.family: view.panel.fontFamily
    font.pixelSize: Style.font.bodySmall
    font.italic: true
    wrapMode: Text.WordWrap
  }

  // Here, then the cities, in their order (⇧↑ ⇧↓ move the selected one).
  Column {
    visible: view.panel.displaySetting("worldList", true)
    width: parent.width
    spacing: Style.space(4)

    // This computer's place and zone; selected, the clock shows here.
    Rectangle {
      id: hereRow
      readonly property bool selected: view.panel.selectedCity < 0
      width: parent.width
      height: Math.max(Style.space(48), hereColumn.implicitHeight + Style.space(12))
      radius: Style.cornerRadius
      color: hereMouse.containsMouse ? Style.hoverFillFor(view.panel.foreground, Color.accent) : "transparent"
      border.color: selected ? Color.accent : view.panel.subtleText
      border.width: Style.spacing.hairline

      MouseArea {
        id: hereMouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: view.panel.setCurrentPlace(-1)
      }

      TimeDial {
        id: hereDial
        visible: view.showDials
        anchors.left: parent.left
        anchors.leftMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(32)
        panel: view.panel
        style: view.panel.dialStyleFor(-1)
        parts: view.panel.localParts
        offset: view.panel.localOffset
        sun: style === "twentyFour" ? view.panel.sunTimesFor(view.panel.here.place, view.panel.localOffset, view.panel.nowMs) : null
      }

      Text {
        textFormat: Text.PlainText
        id: hereGlyph
        anchors.left: hereDial.visible ? hereDial.right : parent.left
        anchors.leftMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        // More Weather's location pin, in place of a word.
        text: "\uf041"
        color: view.panel.mutedText
        font.family: view.panel.fontFamily
        font.pixelSize: Style.font.title
      }

      Column {
        id: hereColumn
        anchors.left: hereGlyph.right
        anchors.leftMargin: Style.space(10)
        anchors.right: hereTime.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(1)

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: view.panel.here.name
          color: view.panel.foreground
          font.family: view.panel.fontFamily
          font.pixelSize: Style.font.body
          font.bold: hereRow.selected
          elide: Text.ElideRight
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: [view.panel.zoneTable.localTz,
            Model.utcOffsetLabel(view.panel.localOffset)]
            .filter(function(t) { return t }).join("  ·  ")
          color: view.panel.mutedText
          font.family: view.panel.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }

        TimeSunFields {
          panel: view.panel
          coordinates: view.panel.here.place
          offset: view.panel.localOffset
          showSunrise: view.sunrise
          showSunset: view.sunset
          showNext: view.sunNext
        }
      }

      Text {
        textFormat: Text.PlainText
        id: hereTime
        anchors.right: parent.right
        anchors.rightMargin: Style.space(10) + Style.space(28)
        anchors.verticalCenter: parent.verticalCenter
        text: view.panel.localClock(false)
        color: view.panel.foreground
        font.family: view.panel.fontFamily
        font.pixelSize: Style.font.heading
        font.bold: true
      }

      DialButton {
        visible: hereRow.selected
        anchors.right: parent.right
        anchors.rightMargin: Style.space(6)
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    DialChooser {
      visible: view.panel.dialChooserOpen && view.panel.selectedCity < 0
      placeIndex: -1
      parts: view.panel.localParts
      offset: view.panel.localOffset
      sun: view.panel.sunTimesFor(view.panel.here.place, view.panel.localOffset, view.panel.nowMs)
    }

    Repeater {
      model: view.cities

      Column {
        id: cityItem
        required property var modelData
        required property int index
        width: parent.width
        spacing: Style.space(4)

      Rectangle {
        id: row
        readonly property var modelData: cityItem.modelData
        readonly property int index: cityItem.index
        readonly property bool selected: index === view.panel.selectedCity
        // Marked by the search's keys (Tab to the cities).
        readonly property bool marked: view.panel.searchOpen && view.search.section === "saved" && index === view.search.savedIndex
        readonly property bool armed: view.panel.armedDeleteId === view.panel.cityDeleteId(index)
        readonly property var offset: view.panel.cityOffset(modelData)
        readonly property var zoneState: view.panel.zoneTable.revision >= 0
          ? view.panel.zoneTable.stateFor(modelData.tz, view.panel.nowMs) : null
        readonly property var parts: offset === null ? null : Model.zonedParts(view.panel.nowMs, offset)
        readonly property int dayShift: offset === null ? 0 : Model.dayDifference(view.panel.nowMs, offset, view.panel.localOffset)
        readonly property bool daytime: parts !== null && parts.hour >= 6 && parts.hour < 18
        width: parent.width
        height: Math.max(Style.space(48), nameColumn.implicitHeight + Style.space(12))
        radius: Style.cornerRadius
        color: rowMouse.containsMouse || marked ? Style.hoverFillFor(view.panel.foreground, Color.accent) : "transparent"
        border.color: armed ? Color.urgent : (selected || marked ? Color.accent : view.panel.subtleText)
        border.width: Style.spacing.hairline

        MouseArea {
          id: rowMouse
          anchors.fill: parent
          hoverEnabled: true
          onClicked: view.panel.selectedCity = row.index
        }

        TimeDial {
          id: rowDial
          visible: view.showDials
          anchors.left: parent.left
          anchors.leftMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(32)
          panel: view.panel
          style: Model.dialStyle(row.modelData.dial)
          parts: row.parts || ({ hour: 0, minute: 0, second: 0 })
          offset: row.offset === null ? 0 : row.offset
          sun: style === "twentyFour" && row.offset !== null
            ? view.panel.sunTimesFor(Model.placeFrom(row.modelData.name, row.modelData.lat, row.modelData.lon), row.offset, view.panel.nowMs) : null
        }

        Text {
          textFormat: Text.PlainText
          id: dayGlyph
          anchors.left: rowDial.visible ? rowDial.right : parent.left
          anchors.leftMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          text: row.parts === null ? "" : (row.daytime ? "\u{f0599}" : "\u{f0594}")
          color: row.daytime ? view.panel.sunColor : view.panel.mutedText
          font.family: view.panel.fontFamily
          font.pixelSize: Style.font.title
        }

        Column {
          id: nameColumn
          anchors.left: dayGlyph.right
          anchors.leftMargin: Style.space(10)
          anchors.right: timeColumn.left
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(1)

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: row.modelData.name
            color: view.panel.foreground
            font.family: view.panel.fontFamily
            font.pixelSize: Style.font.body
            font.bold: row.selected
            elide: Text.ElideRight
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: [row.modelData.country,
              row.zoneState ? (row.zoneState.abbr && !/^[+-]/.test(row.zoneState.abbr) ? row.zoneState.abbr + " " : "")
                + Model.utcOffsetLabel(row.zoneState.offset) : ""].filter(function(t) { return t }).join("  ·  ")
            color: view.panel.mutedText
            font.family: view.panel.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }

          TimeSunFields {
            panel: view.panel
            coordinates: row.offset !== null ? Model.placeFrom(row.modelData.name, row.modelData.lat, row.modelData.lon) : null
            offset: row.offset === null ? 0 : row.offset
            showSunrise: view.sunrise
            showSunset: view.sunset
            showNext: view.sunNext
          }
        }

        Column {
          id: timeColumn
          anchors.right: dialButton.visible ? dialButton.left : removeButton.left
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(1)

          Text {
            textFormat: Text.PlainText
            anchors.right: parent.right
            text: row.offset === null ? "…" : view.panel.clockFor(view.panel.nowMs, row.offset, false)
            color: view.panel.foreground
            font.family: view.panel.fontFamily
            font.pixelSize: Style.font.heading
            font.bold: true
          }

          Text {
            textFormat: Text.PlainText
            visible: view.panel.displaySetting("worldDifference", true) && row.offset !== null
            anchors.right: parent.right
            text: (row.dayShift === 0 ? view.panel.i18n("today")
                : (row.dayShift > 0 ? view.panel.i18n("tomorrow") : view.panel.i18n("yesterday")))
              + "  ·  " + view.panel.offsetDifferenceText(row.offset === null ? 0 : row.offset - view.panel.localOffset)
            color: row.dayShift !== 0 ? Color.accent : view.panel.mutedText
            font.family: view.panel.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        DialButton {
          id: dialButton
          visible: row.selected
          anchors.right: removeButton.left
          anchors.verticalCenter: parent.verticalCenter
        }

        TimeIconButton {
          id: removeButton
          anchors.right: parent.right
          anchors.rightMargin: Style.space(6)
          anchors.verticalCenter: parent.verticalCenter
          panel: view.panel
          glyph: "\u{f0a7a}"
          armed: row.armed
          onActivated: {
            view.panel.selectedCity = row.index
            view.panel.deleteItem("world", view.panel.cityDeleteId(row.index))
          }
        }
      }

      DialChooser {
        visible: view.panel.dialChooserOpen && row.selected
        placeIndex: row.index
        parts: row.parts || ({ hour: 0, minute: 0, second: 0 })
        offset: row.offset === null ? 0 : row.offset
        sun: row.offset !== null ? view.panel.sunTimesFor(Model.placeFrom(row.modelData.name, row.modelData.lat, row.modelData.lon), row.offset, view.panel.nowMs) : null
      }
      }
    }
  }
}
