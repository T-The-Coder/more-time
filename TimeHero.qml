import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// The clock itself, on top, for the current place (here, or the city
// picked in the World tab): the place's name, the time large, seconds,
// date, week, day of the year, its zone, sunrise and sunset with the golden
// and blue hour, and the next alarm; optionally a dial. With a city current,
// a line keeps the time here in view. The
// chime mute, the app and the settings sit in the corner, as in More
// Weather; in the widget a click on the time opens the app as well.
Item {
  id: hero
  required property var panel
  implicitHeight: Math.max(textColumn.implicitHeight, dial.visible ? dial.height : 0) + Style.space(8)

  readonly property var parts: panel.currentParts
  readonly property bool showSeconds: panel.displaySetting("heroSeconds", true)
  readonly property var zoneState: ({ abbr: panel.currentAbbr(), offset: panel.currentOffset })
  readonly property color timeColor: timeOpenMouse.containsMouse
    ? Style.hoverStateColor(panel.foreground, Color.accent) : panel.foreground

  // Hours and minutes large, seconds small beside them; AM/PM after that.
  readonly property string mainText: {
    var text = panel.clockFor(panel.nowMs, panel.currentOffset, false)
    return panel.hour12 ? text.replace(/\s*\S+$/, "") : text
  }

  // The current place's clock face, in its style (e in the World tab).
  TimeDial {
    id: dial
    visible: hero.panel.displaySetting("heroAnalog", true)
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(96)
    panel: hero.panel
    // Settings → Display → Clock → Clock face: the place's own, or one for
    // all places.
    readonly property string chosen: String(hero.panel.displaySetting("heroDial", "place"))
    style: chosen === "place" ? hero.panel.dialStyleFor(hero.panel.selectedCity) : Model.dialStyle(chosen)
    parts: hero.parts
    showSeconds: hero.showSeconds
    offset: hero.panel.currentOffset
    sun: style === "twentyFour" ? hero.panel.sunTimesFor(hero.panel.currentCoordinates, hero.panel.currentOffset, hero.panel.nowMs) : null
  }

  Column {
    id: textColumn
    anchors.left: dial.visible ? dial.right : parent.left
    anchors.leftMargin: dial.visible ? Style.space(18) : 0
    anchors.right: corner.left
    anchors.rightMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(3)

    // The place: the pin goes back to here, the name and ▾ open the World
    // tab; separate hit areas, as in More Weather.
    Row {
      id: placeRow
      spacing: Style.space(6)

      Item {
        width: Style.space(16)
        height: Style.space(18)
        anchors.verticalCenter: parent.verticalCenter

        // More Weather's location pin (nf-fa-map_marker).
        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          text: "\uf041"
          color: pinMouse.containsMouse ? Style.hoverStateColor(hero.panel.foreground, Color.accent) : hero.panel.mutedText
          font.family: hero.panel.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        MouseArea {
          id: pinMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: hero.panel.setCurrentPlace(-1)

          PanelToolTip {
            visible: pinMouse.containsMouse && !!hero.panel.currentCity
            text: hero.panel.i18n("shortcutPlaceHere")
            fontFamily: hero.panel.fontFamily
          }
        }
      }

      Text {
        textFormat: Text.PlainText
        width: Math.min(implicitWidth, Math.max(Style.space(90), textColumn.width - Style.space(40)))
        anchors.verticalCenter: parent.verticalCenter
        text: hero.panel.upperLabel(hero.panel.currentName)
        color: nameHover.hovered ? Style.hoverStateColor(hero.panel.foreground, Color.accent) : hero.panel.mutedText
        font.family: hero.panel.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.letterSpacing: 1
        elide: Text.ElideRight

        TapHandler { onTapped: hero.panel.showTab("places") || hero.panel.showTab("world") }
        HoverHandler { id: nameHover; cursorShape: Qt.PointingHandCursor }
      }

      Item {
        width: Style.space(14)
        height: Style.space(18)
        anchors.verticalCenter: parent.verticalCenter

        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          text: "▾"
          color: hero.panel.mutedText
          font.family: hero.panel.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: hero.panel.showTab("places") || hero.panel.showTab("world")
        }
      }
    }

    // Times read left to right in every language.
    Item {
      implicitWidth: timeRow.implicitWidth
      implicitHeight: timeRow.implicitHeight
      width: implicitWidth
      height: implicitHeight

      Row {
        id: timeRow
        spacing: Style.space(4)
        LayoutMirroring.enabled: false
        LayoutMirroring.childrenInherit: true

        Text {
          textFormat: Text.PlainText
          id: bigTime
          text: hero.mainText
          color: hero.timeColor
          font.family: hero.panel.fontFamily
          font.pixelSize: Math.round(Style.font.displayLarge * 1.55)
          font.bold: true
        }

        Text {
          textFormat: Text.PlainText
          visible: hero.showSeconds
          anchors.baseline: bigTime.baseline
          text: ":" + Model.pad2(hero.parts.second)
          color: timeOpenMouse.containsMouse ? hero.timeColor : hero.panel.mutedText
          font.family: hero.panel.fontFamily
          font.pixelSize: Style.font.display
        }

        Text {
          textFormat: Text.PlainText
          visible: hero.panel.hour12
          anchors.baseline: bigTime.baseline
          leftPadding: Style.space(4)
          text: hero.panel.hour12 ? (hero.parts.hour < 12 ? hero.panel.amPm[0] : hero.panel.amPm[1]) : ""
          color: timeOpenMouse.containsMouse ? hero.timeColor : hero.panel.mutedText
          font.family: hero.panel.fontFamily
          font.pixelSize: Style.font.title
        }
      }

      // In the widget the time opens the app, like the temperature in
      // More Weather.
      MouseArea {
        id: timeOpenMouse
        anchors.fill: parent
        enabled: !hero.panel.standaloneMode
        hoverEnabled: enabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: hero.panel.openApp()

        PanelToolTip {
          visible: timeOpenMouse.containsMouse
          text: hero.panel.i18n("openInApp")
          fontFamily: hero.panel.fontFamily
        }
      }
    }

    Text {
      textFormat: Text.PlainText
      visible: hero.panel.displaySetting("heroDate", true)
      width: parent.width
      text: hero.panel.dateFor(hero.panel.nowMs, hero.panel.currentOffset, "long")
      color: hero.panel.foreground
      font.family: hero.panel.fontFamily
      font.pixelSize: Style.font.subtitle
      elide: Text.ElideRight
    }

    // Sunrise and sunset, the golden and the blue hour, at the current
    // place: More Weather's drawn arrows in the Sun's gold, the hours with
    // their glyphs; a line breaks between the pieces, never inside one.
    Flow {
      id: sunFlow
      readonly property var pieces: hero.panel.sunPieces(hero.panel.currentCoordinates, hero.panel.currentOffset,
        hero.panel.displaySetting("heroSun", true), hero.panel.displaySetting("heroGoldenHour", false),
        hero.panel.displaySetting("heroBlueHour", false), hero.panel.displaySetting("heroSunNext", false))
      visible: pieces.length > 0
      width: parent.width
      spacing: Style.space(4)

      Repeater {
        model: sunFlow.pieces
        Row {
          id: sunPiece
          required property var modelData
          required property int index
          spacing: Style.space(4)
          Repeater {
            model: sunPiece.modelData
            Row {
              id: sunPart
              required property var modelData
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)
              TimeSunIcon {
                visible: sunPart.modelData.icon === "rise" || sunPart.modelData.icon === "set"
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(11)
                height: Style.space(11)
                rising: sunPart.modelData.icon === "rise"
                iconColor: hero.panel.sunColor
              }
              Text {
                textFormat: Text.PlainText
                visible: !!sunPart.modelData.icon && !(sunPart.modelData.icon === "rise" || sunPart.modelData.icon === "set")
                anchors.verticalCenter: parent.verticalCenter
                text: hero.panel.sunGlyphs[sunPart.modelData.icon] || ""
                color: sunPart.modelData.icon === "golden" || sunPart.modelData.icon === "day" ? hero.panel.sunColor : hero.panel.mutedText
                font.family: hero.panel.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
              Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: sunPart.modelData.text
                color: hero.panel.mutedText
                font.family: hero.panel.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
            }
          }
          // The separator stays with the piece before it, so a wrapped
          // line never starts with it.
          Text {
            textFormat: Text.PlainText
            visible: sunPiece.index < sunFlow.pieces.length - 1
            anchors.verticalCenter: parent.verticalCenter
            text: "·"
            color: hero.panel.mutedText
            font.family: hero.panel.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }
      }
    }

    Text {
      textFormat: Text.PlainText
      readonly property var pieces: {
        var list = []
        var p = hero.parts
        if (hero.panel.displaySetting("heroWeek", true))
          list.push(hero.panel.i18n("weekLong", { week: Model.isoWeek(p.year, p.month, p.day) }))
        if (hero.panel.displaySetting("heroDayOfYear", true))
          list.push(hero.panel.i18n("dayOfYear", { day: Model.dayOfYear(p.year, p.month, p.day) }))
        if (hero.panel.displaySetting("heroZone", true))
          list.push((hero.zoneState.abbr ? hero.zoneState.abbr + " " : "") + Model.utcOffsetLabel(hero.zoneState.offset))
        return list
      }
      visible: pieces.length > 0
      width: parent.width
      text: pieces.join("  ·  ")
      color: hero.panel.mutedText
      font.family: hero.panel.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
    }

    // A city is current: the time here stays in view.
    Text {
      textFormat: Text.PlainText
      visible: !!hero.panel.currentCity
      width: parent.width
      text: "\uf041  " + hero.panel.i18n("hereClock", { time: hero.panel.localClock(false) })
      color: hero.panel.mutedText
      font.family: hero.panel.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
    }

    // Focus rounds today and this week (heroPomodoroTally).
    Text {
      textFormat: Text.PlainText
      visible: hero.panel.displaySetting("heroPomodoroTally", false)
      width: parent.width
      text: "\u{f0996}  " + hero.panel.i18n("pomodoroTally", hero.panel.pomodoroTally)
      color: hero.panel.mutedText
      font.family: hero.panel.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
    }

    Text {
      textFormat: Text.PlainText
      visible: hero.panel.displaySetting("heroNextAlarm", true) && hero.panel.nextAlarm !== null
      width: parent.width
      text: hero.panel.nextAlarm
        ? "\u{f0020}  " + hero.panel.i18n("nextAlarmAt", { time: hero.panel.wallClockAt(hero.panel.nextAlarm.at),
          until: hero.panel.untilText(hero.panel.nextAlarm.at - hero.panel.nowMs) }) : ""
      color: hero.panel.mutedText
      font.family: hero.panel.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
    }
  }

  Row {
    id: corner
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: Style.space(2)

    // Mutes and unmutes the chimes everywhere (also `m`); only while a
    // chime is set up.
    TimeIconButton {
      visible: hero.panel.chimesActive
      panel: hero.panel
      glyph: hero.panel.chimesMuted ? "\u{f009b}" : "\u{f009a}"
      onActivated: hero.panel.setChimesMuted(!hero.panel.chimesMuted)

      HoverHandler { id: muteHover }

      PanelToolTip {
        visible: muteHover.hovered
        text: hero.panel.i18n(hero.panel.chimesMuted ? "chimesUnmuteTip" : "chimesMuteTip")
        fontFamily: hero.panel.fontFamily
      }
    }

    TimeIconButton {
      visible: !hero.panel.standaloneMode
      panel: hero.panel
      glyph: "\u{f03cc}"
      onActivated: hero.panel.openApp()
    }

    TimeIconButton {
      panel: hero.panel
      glyph: "\u{f0493}"
      onActivated: hero.panel.openSettings()
    }
  }
}
