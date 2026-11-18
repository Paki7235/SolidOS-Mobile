// Barra per scrivere un messaggio, con il tasto Invia.
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: barra
    property alias text: campo.text
    signal invia(string testo)
    height: Math.min(140, campo.implicitHeight + 26) + (tel.imp.navigazione === "tasti" ? 44 : 22)
    color: tel.pal.sfondo
    Rectangle { width: parent.width; height: 1; color: tel.pal.bordo }
    Rectangle {
        x: 12; y: 8
        width: parent.width - 70; height: Math.min(130, campo.implicitHeight + 10)
        radius: 20
        color: "transparent"
        border.color: campo.activeFocus ? tel.pal.testo2 : tel.pal.bordo
        TextArea {
            id: campo
            anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6
            wrapMode: TextArea.Wrap
            placeholderText: I18n.t("Messaggio"); placeholderTextColor: tel.pal.testo2
            color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16)
            background: Item {}
        }
    }
    TastoTondo {
        anchors.right: parent.right; anchors.rightMargin: 12; y: 10
        lato: 40; icona: "go-up-symbolic"
        pieno: campo.text.trim() !== ""
        opacity: pieno ? 1 : 0.6
        onTocco: if (campo.text.trim()) { barra.invia(campo.text); campo.text = "" }
    }
}
