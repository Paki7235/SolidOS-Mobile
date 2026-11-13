// Barra superiore di una vista: frecce indietro/avanti facoltative, titolo e area per controlli.
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: barra
    property string titolo: ""
    property bool frecce: false
    property bool puoIndietro: false
    property bool puoAvanti: false
    signal indietro()
    signal avanti()
    default property alias azioni: contenitore.data
    implicitHeight: 52
    color: Tema.chiaro ? "#F6F6F9" : Tema.superficie
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Tema.chiaro ? "#1A000000" : "#66000000" }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 14
        spacing: 14
        Repeater {
            model: barra.frecce ? [{ su: "indietro", attiva: barra.puoIndietro, d: "M10 3 5 8l5 5" }, { su: "avanti", attiva: barra.puoAvanti, d: "M6 3l5 5-5 5" }] : []
            Item {
                width: 22; height: 22
                opacity: modelData.attiva ? 1 : 0.35
                Canvas {
                    anchors.centerIn: parent
                    width: 16; height: 16
                    onPaint: {
                        var c = getContext("2d"); c.reset()
                        c.strokeStyle = Tema.testoSecondario; c.lineWidth = 2; c.lineCap = "round"; c.lineJoin = "round"
                        c.beginPath(); c.path = modelData.d; c.stroke()
                    }
                }
                MouseArea { anchors.fill: parent; enabled: modelData.attiva; cursorShape: Qt.PointingHandCursor; onClicked: modelData.su === "indietro" ? barra.indietro() : barra.avanti() }
            }
        }
        Text { text: barra.titolo; color: Tema.testo; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
        Row { id: contenitore; spacing: 8 }
    }
}
