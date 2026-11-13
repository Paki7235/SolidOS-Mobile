// Campo di testo compatto, riempito, con anello di focus nel colore d'accento.
import QtQuick
import QtQuick.Controls

TextField {
    id: campo
    color: Tema.testo
    placeholderTextColor: Tema.testoSecondario
    selectionColor: Tema.accento
    selectedTextColor: "#FFFFFF"
    font.family: Tema.font
    font.pixelSize: 13
    leftPadding: 10
    rightPadding: 10
    topPadding: 4
    bottomPadding: 4
    background: Rectangle {
        implicitHeight: 28
        implicitWidth: 220
        radius: 7
        color: Tema.chiaro ? "#FFFFFF" : Tema.superficieAlta
        border.width: campo.activeFocus ? 3 : (Tema.chiaro ? 0.5 : 0)
        border.color: campo.activeFocus ? "#73" + Tema.accento.substring(1) : "#C7C7CC"
    }
}
