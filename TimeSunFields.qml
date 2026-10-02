import QtQuick
import qs.Commons

// Sunrise, sunset and the next of the two for one place, in that place's
// local time, as More Weather's menu bar entries show them: the drawn arrow
// icon, then the time. Today's events; the next one is tomorrow's sunrise
// once today's are over. Polar days and nights show "—".
Row {
  id: fields
  required property var panel
  property var coordinates: null
  property int offset: 0
  property bool showSunrise: false
  property bool showSunset: false
  property bool showNext: false
  property color textColor: panel.mutedText
  property real fontSize: Style.font.caption
  spacing: Style.space(10)
  visible: !!coordinates && (showSunrise || showSunset || showNext)

  readonly property var today: coordinates ? panel.sunTimesFor(coordinates, offset, panel.nowMs) : null
  readonly property var next: {
    if (!today) return null
    var now = panel.nowMs
    if (today.sunrise && now < today.sunrise) return { rising: true, at: today.sunrise }
    if (today.sunset && now < today.sunset) return { rising: false, at: today.sunset }
    var tomorrow = panel.sunTimesFor(coordinates, offset, now + 86400000)
    return tomorrow && tomorrow.sunrise ? { rising: true, at: tomorrow.sunrise } : { rising: true, at: 0 }
  }

  function at(ms) {
    return ms ? panel.clockFor(ms, offset, false) : "—"
  }

  component Field: Row {
    property bool rising: true
    property string time: ""
    spacing: Style.space(3)

    TimeSunIcon {
      anchors.verticalCenter: parent.verticalCenter
      width: Math.round(fields.fontSize * 0.95)
      height: width
      rising: parent.rising
      iconColor: fields.textColor
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: parent.time
      color: fields.textColor
      font.family: fields.panel.fontFamily
      font.pixelSize: fields.fontSize
    }
  }

  Field {
    visible: fields.showSunrise
    rising: true
    time: fields.today ? fields.at(fields.today.sunrise) : "—"
  }

  Field {
    visible: fields.showSunset
    rising: false
    time: fields.today ? fields.at(fields.today.sunset) : "—"
  }

  Field {
    visible: fields.showNext
    rising: fields.next ? fields.next.rising : true
    time: fields.next ? fields.at(fields.next.at) : "—"
  }
}
