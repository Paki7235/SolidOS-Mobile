// Barra per scrivere un messaggio, con il tasto Invia.
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: barra
    property alias text: campo.text
    signal invia(string testo)
    height: Math.min(140, campo.implicitHeight + 26) + (tel.imp.navigazione === "tasti" ? 44 : 22)
    color: tel.pal.superficie
    Rectangle { width: parent.width; height: 1; color: tel.pal.bordo }
    Rectangle {
        x: 12; y: 8
        width: parent.width - 70; height: Math.min(130, campo.implicitHeight + 10)
        radius: 20
        color: "transparent"
        border.color: tel.chiaro ? Qt.rgba(0, 0, 0, 0.15) : Qt.rgba(1, 1, 1, 0.18)
        TextArea {
            id: campo
            anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6
            wrapMode: TextArea.Wrap
            placeholderText: I18n.t("Messaggio"); placeholderTextColor: tel.pal.testo2
            color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16)
            background: Item {}
        }
    }
    Rectangle {
        anchors.right: parent.right; anchors.rightMargin: 12; y: 10
        width: 40; height: 40; radius: 20
        color: campo.text.trim() ? tel.accento : (tel.chiaro ? "#d4d8e4" : "#3a4050")
        Icona { anchors.centerIn: parent; nome: "go-up-symbolic"; lato: 20 }
        MouseArea { anchors.fill: parent; onClicked: if (campo.text.trim()) { barra.invia(campo.text); campo.text = "" } }
    }
}
