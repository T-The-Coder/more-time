import QtQuick
import qs.Commons
import qs.Ui

// The small button cluster over the globe, the flat map and the solar
// system, as on More Weather's globe: the crosshair (back to the middle),
// zoom out, zoom in; the ends of the zoom range grey the buttons out.
BorderSurface {
  id: controls
  required property var panel
  property bool canZoomOut: true
  property bool canZoomIn: true
  signal recenter()
  signal zoomOut()
  signal zoomIn()

  width: zoomRow.implicitWidth + Style.space(10)
  height: Style.space(28)
  radius: Style.cornerRadius
  color: Color.popups.background
  borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Style.normalBorderWidth)

  Row {
    id: zoomRow
    anchors.centerIn: parent
    spacing: Style.space(2)

    Repeater {
      model: [
        { glyph: "\u{f01a4}", action: "recenter", tip: "zoomRecenter", enabled: true },
        { glyph: "−", action: "out", tip: "zoomOut", enabled: controls.canZoomOut },
        { glyph: "+", action: "in", tip: "zoomIn", enabled: controls.canZoomIn }
      ]

      BorderSurface {
        id: zoomButton
        required property var modelData
        width: Style.space(22)
        height: Style.space(20)
        radius: Style.cornerRadius
        enabled: modelData.enabled
        Accessible.role: Accessible.Button
        Accessible.name: controls.panel.i18n(modelData.tip)
        opacity: enabled ? 1 : 0.38
        color: Style.controlFill(false, buttonMouse.containsMouse, Color.popups.text, Color.accent)
        borderSpec: Border.controlSpec(buttonMouse.containsMouse ? "hover-cursor" : "normal", Color.popups.text, Color.accent)

        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          text: zoomButton.modelData.glyph
          color: buttonMouse.containsMouse ? Style.hoverStateColor(Color.popups.text, Color.accent) : Color.popups.text
          font.family: controls.panel.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        MouseArea {
          id: buttonMouse
          anchors.fill: parent
          enabled: parent.enabled
          hoverEnabled: true
          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: {
            var action = zoomButton.modelData.action
            if (action === "recenter") controls.recenter()
            else if (action === "in") controls.zoomIn()
            else controls.zoomOut()
          }

          PanelToolTip {
            visible: buttonMouse.containsMouse
            text: controls.panel.i18n(zoomButton.modelData.tip)
            fontFamily: controls.panel.fontFamily
          }
        }
      }
    }
  }
}
