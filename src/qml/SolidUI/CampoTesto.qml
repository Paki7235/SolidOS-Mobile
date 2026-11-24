// Campo di testo riempito, con anello di focus nel colore d'accento. Sul telefono (c'è «tel»)
// è più grande, da dito, e prende i colori della veste.
import QtQuick
import QtQuick.Controls

TextField {
    id: campo
    readonly property bool telefono: typeof tel !== "undefined" && tel !== null
    color: telefono ? tel.pal.testo : Tema.testo
    placeholderTextColor: telefono ? tel.pal.testo3 : Tema.testoSecondario
    selectionColor: telefono ? tel.accento : Tema.accento
    selectedTextColor: "#FFFFFF"
    font.family: Tema.font
    font.pixelSize: telefono ? 16 : 13
    leftPadding: telefono ? 16 : 10
    rightPadding: telefono ? 16 : 10
    topPadding: 4
    bottomPadding: 4
    background: Rectangle {
        implicitHeight: campo.telefono ? 50 : 28
        implicitWidth: 220
        radius: campo.telefono ? 16 : 7
        color: campo.telefono ? tel.pal.superficie : (Tema.chiaro ? "#FFFFFF" : Tema.superficieAlta)
        border.width: campo.activeFocus ? (campo.telefono ? 2 : 3) : (campo.telefono ? (tel.solido ? 0 : 1) : (Tema.chiaro ? 0.5 : 0))
        border.color: campo.activeFocus ? (campo.telefono ? tel.accento : "#73" + Tema.accento.substring(1)) : (campo.telefono ? tel.pal.bordo : "#C7C7CC")
    }
}
