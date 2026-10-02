import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// The world clock: the map with the time zones, then "Here" and the
// favourite cities with their time, their day against here, and their
// offset. The selected row is the current place the clock on top shows. Cities come
// from the search (/ or +): the system's zone list offline, any place
// through Open-Meteo's geocoder.
Column {
  id: view
  required property var panel
  spacing: Style.space(10)

  readonly property var cities: panel.cityList
  readonly property var search: panel.citySearch
  readonly property bool showDials: panel.displaySetting("worldDials", true)
  // Sunrise, sunset, the next of the two per row (More Weather's entries).
  readonly property bool sunrise: panel.displaySetting("worldSunrise", false)
  readonly property bool sunset: panel.displaySetting("worldSunset", false)
  readonly property bool sunNext: panel.displaySetting("worldSunNext", true)

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
    hint: view.panel.i18n("worldKeysHint")
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

    Text {
      visible: view.search.query.trim() !== "" && view.search.results.length === 0
      text: view.search.busy ? view.panel.i18n("searching") : view.panel.i18n("noCityFound")
      color: view.panel.mutedText
      font.family: view.panel.fontFamily
      font.pixelSize: Style.font.caption
      font.italic: true
    }
  }

  // The flat map or the globe ("worldStyle"); both take the same inputs.
  Loader {
    visible: view.panel.displaySetting("worldMap", true)
    active: visible
    width: parent.width
    height: item ? item.implicitHeight : 0
    sourceComponent: view.panel.displaySetting("worldStyle", "map") === "globe" ? globeView : flatMapView
  }
  Component {
    id: flatMapView
    TimeWorldMap {
      panel: view.panel
      selectedIndex: view.panel.selectedCity
      onCityClicked: function(index) { view.panel.selectedCity = index }
    }
  }
  Component {
    id: globeView
    TimeGlobe {
      panel: view.panel
      selectedIndex: view.panel.selectedCity
      onCityClicked: function(index) { view.panel.selectedCity = index }
    }
  }

  Text {
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
        id: hereGlyph
        anchors.left: hereDial.visible ? hereDial.right : parent.left
        anchors.leftMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{f034e}"
        color: Color.accent
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
          width: parent.width
          text: view.panel.i18n("here") + "  ·  " + view.panel.here.name
          color: view.panel.foreground
          font.family: view.panel.fontFamily
          font.pixelSize: Style.font.body
          font.bold: hereRow.selected
          elide: Text.ElideRight
        }

        Text {
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

      // Its clock face style (also e).
      TimeIconButton {
        visible: hereRow.selected
        anchors.right: parent.right
        anchors.rightMargin: Style.space(6)
        anchors.verticalCenter: parent.verticalCenter
        panel: view.panel
        glyph: "\u{f03eb}"
        active: view.panel.dialChooserOpen
        onActivated: view.panel.dialChooserOpen = !view.panel.dialChooserOpen
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
          id: dayGlyph
          anchors.left: rowDial.visible ? rowDial.right : parent.left
          anchors.leftMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          text: row.parts === null ? "" : (row.daytime ? "\u{f0599}" : "\u{f0594}")
          color: row.daytime ? Color.accent : view.panel.mutedText
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
            width: parent.width
            text: row.modelData.name
            color: view.panel.foreground
            font.family: view.panel.fontFamily
            font.pixelSize: Style.font.body
            font.bold: row.selected
            elide: Text.ElideRight
          }

          Text {
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
            anchors.right: parent.right
            text: row.offset === null ? "…" : view.panel.clockFor(view.panel.nowMs, row.offset, false)
            color: view.panel.foreground
            font.family: view.panel.fontFamily
            font.pixelSize: Style.font.heading
            font.bold: true
          }

          Text {
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

        // Its clock face style (also e).
        TimeIconButton {
          id: dialButton
          visible: row.selected
          anchors.right: removeButton.left
          anchors.verticalCenter: parent.verticalCenter
          panel: view.panel
          glyph: "\u{f03eb}"
          active: view.panel.dialChooserOpen
          onActivated: view.panel.dialChooserOpen = !view.panel.dialChooserOpen
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
