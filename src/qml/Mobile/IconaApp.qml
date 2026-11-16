// Icona di un'app: le icone di SolidOS (tessera colorata e simbolo bianco) oppure,
// per le app esterne, l'icona del tema su una tessera neutra della stessa forma.
import QtQuick
import SolidUI

Item {
    id: ic
    property var app: ({})
    property bool conNome: true
    property int lato: tel.latoIcona
    width: lato + 24
    height: lato + (conNome ? 26 : 0)

    // Le icone di SolidOS (nucleo-…) hanno già la loro tessera colorata;
    // le app esterne vanno su una tessera neutra della stessa forma
    readonly property bool propria: (ic.app.icona || "").indexOf("nucleo-") === 0
    Rectangle {
        id: tessera
        anchors.horizontalCenter: parent.horizontalCenter
        width: ic.lato; height: ic.lato
        radius: Math.round(ic.lato * 0.27)
        color: ic.propria ? "transparent" : tel.pal.tessera
        border.color: ic.propria ? "transparent" : tel.pal.vetroBordo; border.width: 1
        scale: area.pressed ? 0.92 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        Icona {
            anchors.centerIn: parent
            nome: ic.app.icona || "application-x-executable"
            lato: ic.propria ? ic.lato : Math.round(ic.lato * 0.68)
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
