// Barra per scrivere un messaggio, con il tasto Invia (pieno nel colore di sistema).
// Nelle vesti Prisma il campo è una pillola bianca senza bordo.
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: barra
    property alias text: campo.text
    signal invia(string testo)
    height: Math.min(140, campo.implicitHeight + 26) + (tel.imp.navigazione === "tasti" ? 44 : 22)
    color: tel.pal.sfondo
    Rectangle { width: parent.width; height: 1; color: tel.pal.bordo; visible: !tel.solido }
    Rectangle {
        x: 12; y: 8
        width: parent.width - 74; height: Math.min(130, campo.implicitHeight + 12)
        radius: 22
        color: tel.solido ? tel.pal.superficie : "transparent"
        border.width: tel.solido ? 0 : 1
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
        lato: 44; icona: "linea-invia"
        pieno: true
        opacity: campo.text.trim() !== "" ? 1 : 0.45
        onTocco: if (campo.text.trim()) { barra.invia(campo.text); campo.text = "" }
    }
}
