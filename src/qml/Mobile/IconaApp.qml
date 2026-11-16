// Icona di un'app: l'icona del tema di sistema (la stessa del PC) su una tessera
// arrotondata uguale per tutte, così la griglia è ordinata. Nome sotto.
import QtQuick
import SolidUI

Item {
    id: ic
    property var app: ({})
    property bool conNome: true
    property int lato: tel.latoIcona
    width: lato + 24
    height: lato + (conNome ? 26 : 0)

    Rectangle {
        id: tessera
        anchors.horizontalCenter: parent.horizontalCenter
        width: ic.lato; height: ic.lato
        radius: Math.round(ic.lato * 0.27)
        color: tel.pal.tessera
        border.color: tel.pal.vetroBordo; border.width: 1
        scale: area.pressed ? 0.92 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        Icona {
            anchors.centerIn: parent
            nome: ic.app.icona || "application-x-executable"
            lato: Math.round(ic.lato * 0.68)
        }
    }
    Text {
        visible: ic.conNome
        anchors.top: tessera.bottom; anchors.topMargin: 7
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width + 6
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: ic.app.nome || ""
        color: tel.pal.testo
        font.family: Tema.font; font.pixelSize: tel.px(12); font.weight: Font.Medium
    }
    MouseArea { id: area; anchors.fill: parent; onClicked: tel.apri(ic.app) }
}
