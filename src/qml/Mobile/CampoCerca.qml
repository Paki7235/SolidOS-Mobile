// Campo di ricerca a pillola con il bordo sottile (Messaggi, Contatti, Libreria…)
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: cc
    property alias text: campo.text
    property string suggerimento: I18n.t("Cerca")
    function attiva() { campo.forceActiveFocus() }
    height: 44; radius: 22
    color: "transparent"
    border.width: 1; border.color: campo.activeFocus ? tel.pal.testo2 : tel.pal.bordo
    Row {
        anchors.fill: parent; anchors.leftMargin: 16; spacing: 10
        Icona { nome: "system-search-symbolic"; lato: 17; anchors.verticalCenter: parent.verticalCenter; opacity: 0.7 }
        TextField {
            id: campo
            anchors.verticalCenter: parent.verticalCenter
            width: cc.width - 56; height: cc.height
            leftPadding: 0; rightPadding: 0; topPadding: 0; bottomPadding: 0
            verticalAlignment: TextInput.AlignVCenter
            placeholderText: cc.suggerimento; placeholderTextColor: tel.pal.testo2
            color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15)
            background: Item {}
        }
    }
}
