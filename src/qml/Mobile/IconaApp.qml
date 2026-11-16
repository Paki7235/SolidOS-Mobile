// Icona di un'app: la stessa di SolidOS per PC (tema di icone di sistema), con il nome sotto.
import QtQuick
import SolidUI

Item {
    id: ic
    property var app: ({})
    property bool conNome: true
    property int lato: tel.latoIcona
    width: lato + 24
    height: lato + (conNome ? 26 : 0)

    // Le stesse icone di SolidOS per PC, a grandezza piena (come nel Dock del PC)
    Icona {
        id: tessera
        anchors.horizontalCenter: parent.horizontalCenter
        nome: ic.app.icona || "application-x-executable"
        lato: ic.lato
        scale: area.pressed ? 0.92 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
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
