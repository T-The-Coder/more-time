import QtQuick
import Quickshell.Io
import qs.Commons
import "Changelog.js" as Changelog

// Settings page "What's new": the plugin's own CHANGELOG.md, read from its
// folder when the page opens (nothing is fetched), parsed by Changelog.js:
// a card per version, newest first, each change as a row with its bold
// lead as title and the rest as hint text. Versions after the first three
// wait behind "Show older versions" (a click or Enter). The log is
// English; a line says so in other languages.
Column {
  id: changesPage
  required property var panel
  width: parent ? parent.width : 0
  spacing: Style.space(12)

  // Read again each time the page shows.
  property bool active: visible
  onActiveChanged: if (active) {
    showOlder = false
    logFile.reload()
    manifestFile.reload()
  }

  property var sections: []
  property bool loaded: false
  property string installedVersion: ""
  property bool showOlder: false
  readonly property int firstShown: 3
  readonly property var shownSections: showOlder ? sections : sections.slice(0, firstShown)

  function filePath(name) { return String(Qt.resolvedUrl(name)).replace(/^file:\/\//, "") }

  FileView {
    id: logFile
    path: changesPage.filePath("CHANGELOG.md")
    printErrors: false
    onLoaded: {
      try { changesPage.sections = Changelog.parse(text()) } catch (e) { changesPage.sections = [] }
      changesPage.loaded = true
    }
    onLoadFailed: {
      changesPage.sections = []
      changesPage.loaded = true
    }
  }
  FileView {
    id: manifestFile
    path: changesPage.filePath("manifest.json")
    printErrors: false
    onLoaded: {
      try { changesPage.installedVersion = String(JSON.parse(text()).version || "") } catch (e) { changesPage.installedVersion = "" }
    }
  }

  // Enter on the page (TimeSettings.handleKey): the older versions.
  function activate() {
    if (!showOlder && sections.length > firstShown) {
      showOlder = true
      return true
    }
    return false
  }

  Text {
    textFormat: Text.PlainText
    visible: changesPage.panel.interfaceLanguage !== "en"
    width: parent.width
    text: changesPage.panel.i18n("changesEnglishNote")
    color: changesPage.panel.mutedText
    font.family: changesPage.panel.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  Text {
    textFormat: Text.PlainText
    visible: changesPage.loaded && changesPage.sections.length === 0
    width: parent.width
    text: changesPage.panel.i18n("changesNone")
    color: changesPage.panel.mutedText
    font.family: changesPage.panel.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
  }

  Repeater {
    model: changesPage.shownSections

    Rectangle {
      id: versionCard
      required property var modelData
      readonly property bool installed: !modelData.unreleased && modelData.version === changesPage.installedVersion
      width: changesPage.width
      height: versionContent.implicitHeight + Style.space(20)
      radius: Style.cornerRadius
      color: "transparent"
      border.color: changesPage.panel.subtleText
      border.width: Style.spacing.hairline

      Column {
        id: versionContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(10)
        spacing: Style.space(8)

        Item {
          width: parent.width
          height: Math.max(versionTitle.implicitHeight, installedTag.implicitHeight)

          Text {
            id: versionTitle
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.right: installedTag.visible ? installedTag.left : parent.right
            anchors.rightMargin: Style.space(8)
            text: versionCard.modelData.unreleased ? changesPage.panel.i18n("changesUnreleased")
              : versionCard.modelData.version + (versionCard.modelData.date ? " · " + versionCard.modelData.date : "")
            color: changesPage.panel.foreground
            font.family: changesPage.panel.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            id: installedTag
            textFormat: Text.PlainText
            visible: versionCard.installed
            anchors.right: parent.right
            anchors.verticalCenter: versionTitle.verticalCenter
            text: changesPage.panel.i18n("changesCurrent")
            color: Color.accent
            font.family: changesPage.panel.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }

        Repeater {
          model: versionCard.modelData.items

          Column {
            id: change
            required property var modelData
            width: versionContent.width
            spacing: Style.space(2)

            Text {
              textFormat: Text.PlainText
              visible: change.modelData.title !== ""
              width: parent.width
              text: change.modelData.title
              color: changesPage.panel.foreground
              font.family: changesPage.panel.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }
            Text {
              textFormat: Text.PlainText
              visible: change.modelData.text !== ""
              width: parent.width
              text: change.modelData.text
              color: changesPage.panel.mutedText
              font.family: changesPage.panel.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }
        }
      }
    }
  }

  TimeButton {
    visible: !changesPage.showOlder && changesPage.sections.length > changesPage.firstShown
    panel: changesPage.panel
    label: changesPage.panel.i18n("changesShowOlder")
    onActivated: changesPage.showOlder = true
  }
}
