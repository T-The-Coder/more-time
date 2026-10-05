import QtQuick
import qs.Commons

// Settings page describing where More Time's data comes from: the system's
// time zone database (offsets and the offline city list), Open-Meteo's
// geocoder and Nominatim (other places), Natural Earth (the map), where "here" is (IP
// geolocation only with "Detect my location" on), the freedesktop sounds
// and the chime beeps generated on this computer.
Column {
  id: sourcesPage
  required property var panel
  width: parent ? parent.width : 0
  spacing: Style.space(12)

  Component.onCompleted: panel.zoneTable.versionWanted = true

  function label(key) { return panel.i18n(key) }

  // The licence of the constellation figures and names (BSD 3-Clause),
  // which asks for its notice to be shown with them.
  readonly property string d3CelestialLicence: "Constellation figures and names: d3-celestial\n"
    + "Copyright (c) 2015, Olaf Frohn\nAll rights reserved.\n\n"
    + "Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:\n\n"
    + "1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.\n\n"
    + "2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.\n\n"
    + "3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.\n\n"
    + "THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS \"AS IS\" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."

  readonly property var groups: [
    {
      title: "sourceGroupZones", details: "sourceGroupZonesDetails",
      inUse: panel.zoneTable.databaseVersion !== "" ? "TZDATA " + panel.zoneTable.databaseVersion : "",
      links: [["IANA tz database", "https://www.iana.org/time-zones"]]
    },
    {
      title: "sourceGroupGeocoding", details: "sourceGroupGeocodingDetails",
      inUse: panel.citySearch.answeredBy === "nominatim" ? "NOMINATIM"
        : (panel.citySearch.answeredBy === "open-meteo" ? "OPEN-METEO" : ""),
      links: [["Open-Meteo", "https://open-meteo.com/en/docs/geocoding-api"],
        ["Nominatim (OpenStreetMap)", "https://nominatim.org/"]]
    },
    {
      title: "sourceGroupMap", details: "sourceGroupMapDetails",
      inUse: "NATURAL EARTH · EQUAL EARTH",
      links: [["Natural Earth", "https://www.naturalearthdata.com/"],
        ["Equal Earth", "https://equal-earth.com/"]]
    },
    {
      title: "sourceGroupAstro", details: "sourceGroupAstroDetails",
      inUse: "JPL · KEPLERIAN ELEMENTS",
      links: [["JPL: Approximate Positions of the Planets", "https://ssd.jpl.nasa.gov/planets/approx_pos.html"]]
    },
    {
      title: "sourceGroupAstroBodies", details: "sourceGroupAstroBodiesDetails",
      inUse: "JPL SBDB · HORIZONS · SAT ELEMENTS",
      links: [["JPL SBDB", "https://ssd.jpl.nasa.gov/tools/sbdb_lookup.html"], ["JPL Horizons", "https://ssd.jpl.nasa.gov/horizons/"],
        ["JPL: Planetary Satellite Mean Elements", "https://ssd.jpl.nasa.gov/sats/elem/sep.html"]]
    },
    {
      title: "sourceGroupIss", details: "sourceGroupIssDetails",
      inUse: panel.displaySetting("astroIss", false) === true ? "CELESTRAK · SGP4" : "",
      links: [["CelesTrak", "https://celestrak.org/NORAD/elements/gp.php?CATNR=25544&FORMAT=TLE"],
        ["Revisiting Spacetrack Report #3", "https://celestrak.org/publications/AIAA/2006-6753/"]]
    },
    {
      title: "sourceGroupAstroRotation", details: "sourceGroupAstroRotationDetails",
      inUse: "IAU WGCCRE · NAIF PCK00010",
      links: [["NAIF pck00010.tpc", "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/pck00010.tpc"],
        ["JPL Horizons", "https://ssd.jpl.nasa.gov/horizons/"], ["JPL SBDB", "https://ssd.jpl.nasa.gov/tools/sbdb_lookup.html"],
        ["NSSDCA: Saturn's rings", "https://nssdc.gsfc.nasa.gov/planetary/factsheet/satringfact.html"]]
    },
    {
      title: "sourceGroupStars", details: "sourceGroupStarsDetails",
      inUse: panel.displaySetting("astroStars", true) === true || panel.displaySetting("astroConstellations", false) === true
        ? "BSC5 · IAU WGSN · D3-CELESTIAL" : "",
      links: [["Yale Bright Star Catalogue (CDS V/50)", "https://cdsarc.cds.unistra.fr/ftp/V/50/"],
        ["IAU WGSN Catalog of Star Names", "https://www.pas.rochester.edu/~emamajek/WGSN/IAU-CSN.txt"],
        ["d3-celestial", "https://github.com/ofrohn/d3-celestial"],
        ["Roman 1987 (CDS VI/42)", "https://cdsarc.cds.unistra.fr/viz-bin/cat/VI/42"]],
      notice: sourcesPage.d3CelestialLicence
    },
    {
      title: "sourceGroupMoonView", details: "sourceGroupMoonViewDetails",
      inUse: "MEEUS",
      links: [["PyMeeus (tables 47.A, 47.B)", "https://github.com/architest/pymeeus"],
        ["JPL Horizons", "https://ssd.jpl.nasa.gov/horizons/"]]
    },
    {
      title: "sourceGroupLocation", details: "sourceGroupLocationDetails",
      inUse: !panel.here.detect ? ""
        : (panel.here.place && panel.here.place.source === "ip" && panel.here.ipPlace
          ? panel.here.ipPlace.provider.toUpperCase() : "IPWHO.IS · IPAPI.CO · GEOJS"),
      links: [["ipwho.is", "https://ipwho.is/"], ["ipapi.co", "https://ipapi.co/"], ["GeoJS", "https://www.geojs.io/"]]
    },
    {
      title: "sourceGroupSounds", details: "sourceGroupSoundsDetails",
      inUse: "PIPEWIRE · PW-PLAY",
      links: [["freedesktop sound theme", "https://www.freedesktop.org/wiki/Specifications/sound-theme-spec/"]]
    }
  ]

  Repeater {
    model: sourcesPage.groups

    Rectangle {
      id: sourceCard
      required property var modelData
      width: sourcesPage.width
      height: sourceContent.implicitHeight + Style.space(20)
      radius: Style.cornerRadius
      color: "transparent"
      border.color: sourcesPage.panel.subtleText
      border.width: Style.spacing.hairline

      Column {
        id: sourceContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(10)
        spacing: Style.space(5)

        Item {
          width: parent.width
          height: Math.max(sourceTitle.implicitHeight, inUseText.implicitHeight)

          Text {
            textFormat: Text.PlainText
            id: sourceTitle
            anchors.left: parent.left
            anchors.right: inUseText.left
            anchors.rightMargin: Style.space(8)
            text: sourcesPage.label(sourceCard.modelData.title)
            color: sourcesPage.panel.foreground
            font.family: sourcesPage.panel.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            elide: Text.ElideRight
          }

          // The provider serving this data at the moment.
          Text {
            textFormat: Text.PlainText
            id: inUseText
            anchors.right: parent.right
            anchors.verticalCenter: sourceTitle.verticalCenter
            width: Math.min(implicitWidth, parent.width * 0.55)
            horizontalAlignment: Text.AlignRight
            text: sourceCard.modelData.inUse !== ""
              ? sourcesPage.label("sourceInUse") + " · " + sourceCard.modelData.inUse
              : sourcesPage.label("sourceNotInUse")
            color: sourceCard.modelData.inUse !== ""
              ? Color.accent : sourcesPage.panel.subtleText
            font.family: sourcesPage.panel.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: sourceCard.modelData.inUse !== ""
            elide: Text.ElideRight
          }
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: sourcesPage.label(sourceCard.modelData.details)
          color: sourcesPage.panel.mutedText
          font.family: sourcesPage.panel.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        // A licence notice to show with the data, as it is (English).
        Text {
          textFormat: Text.PlainText
          visible: !!sourceCard.modelData.notice
          width: parent.width
          text: sourceCard.modelData.notice || ""
          color: sourcesPage.panel.subtleText
          font.family: sourcesPage.panel.fontFamily
          font.pixelSize: Math.max(9, Style.font.caption - 2)
          wrapMode: Text.WordWrap
        }

        Flow {
          visible: sourceCard.modelData.links.length > 0
          width: parent.width
          spacing: Style.space(10)

          Repeater {
            model: sourceCard.modelData.links

            Text {
              textFormat: Text.PlainText
              required property var modelData
              text: modelData[0] + " ↗"
              color: linkMouse.containsMouse
                ? Style.hoverStateColor(sourcesPage.panel.foreground, Color.accent)
                : sourcesPage.panel.subtleText
              font.family: sourcesPage.panel.fontFamily
              font.pixelSize: Style.font.caption
              font.underline: linkMouse.containsMouse

              MouseArea {
                id: linkMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Qt.openUrlExternally(parent.modelData[1])
              }
            }
          }
        }
      }
    }
  }
}
