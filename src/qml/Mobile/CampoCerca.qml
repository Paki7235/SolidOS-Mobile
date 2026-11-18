// Campo di ricerca grigio con la lente (Messaggi, Contatti, Libreria…)
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: cc
    property alias text: campo.text
    property string suggerimento: I18n.t("Cerca")
    function attiva() { campo.forceActiveFocus() }
    height: 40; radius: 12
    color: tel.pal.superficie2
    Row {
        anchors.fill: parent; anchors.leftMargin: 12; spacing: 8
        Icona { nome: "system-search-symbolic"; lato: 16; anchors.verticalCenter: parent.verticalCenter; opacity: 0.6 }
        TextField {
            id: campo
            anchors.verticalCenter: parent.verticalCenter
            width: cc.width - 50; height: cc.height
            leftPadding: 0; rightPadding: 0; topPadding: 0; bottomPadding: 0
            verticalAlignment: TextInput.AlignVCenter
            placeholderText: cc.suggerimento; placeholderTextColor: tel.pal.testo2
            color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15)
            background: Item {}
        }
    }
}
