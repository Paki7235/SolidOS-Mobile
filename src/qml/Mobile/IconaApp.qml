// Icona di un'app come su SolidOS per PC (stesso tema di icone) con il nome sotto.
import QtQuick
import SolidUI

Item {
    id: ic
    property var app: ({})
    property bool conNome: true
    width: tel.latoIcona + 22
    height: tel.latoIcona + (conNome ? tel.px(22) : 0)

    Icona {
        id: immagine
        anchors.horizontalCenter: parent.horizontalCenter
        nome: ic.app.icona || "application-x-executable"
        lato: tel.latoIcona
        scale: area.pressed ? 0.9 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
    }
    Text {
        visible: ic.conNome
        anchors.top: immagine.bottom; anchors.topMargin: 5
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: ic.app.nome || ""
        color: tel.pal.testo
        style: tel.chiaro ? Text.Normal : Text.Raised; styleColor: "#40000000"
        font.family: Tema.font; font.pixelSize: tel.px(12); font.weight: Font.Medium
    }
    MouseArea { id: area; anchors.fill: parent; onClicked: tel.apri(ic.app) }
}
