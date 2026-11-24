// Pulsante: normale (grigio), principale (accento) o pericoloso (rosso). Sul telefono (c'è
// «tel») è una pillola alta, da dito, nei colori della veste.
import QtQuick
import QtQuick.Controls

Button {
    id: pulsante
    property bool principale: false
    property bool pericoloso: false
    property string icona: ""
    readonly property bool telefono: typeof tel !== "undefined" && tel !== null
    font.family: Tema.font
    font.pixelSize: telefono ? 16 : 13
    font.weight: telefono ? Font.DemiBold : Font.Medium
    leftPadding: telefono ? 20 : 14
    rightPadding: telefono ? 20 : 14
    topPadding: 5
    bottomPadding: 5
    hoverEnabled: true

    contentItem: Item {
        implicitWidth: riga.implicitWidth
        implicitHeight: riga.implicitHeight
        Row {
            id: riga
            anchors.centerIn: parent
            spacing: 6
            Icona { nome: pulsante.icona; lato: 16; visible: pulsante.icona !== ""; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: pulsante.text
                font: pulsante.font
                color: pulsante.telefono
                       ? (pulsante.pericoloso && !pulsante.principale ? tel.rosso : (pulsante.principale ? (tel.solido && tel.chiaro ? "#FFFFFF" : "#FFFFFF") : tel.pal.testo))
                       : ((pulsante.principale || pulsante.pericoloso) ? "#FFFFFF" : Tema.testo)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
    background: Rectangle {
        implicitHeight: pulsante.telefono ? 50 : 28
        implicitWidth: 64
        radius: pulsante.telefono ? height / 2 : 7
        color: pulsante.telefono
               ? (pulsante.principale ? (pulsante.down ? Qt.darker(tel.accento, 1.15) : tel.accento)
                                      : (pulsante.pericoloso ? Qt.rgba(0.9, 0.28, 0.3, pulsante.down ? 0.22 : 0.12) : (pulsante.down ? tel.pal.bordo : tel.pal.superficie)))
               : pulsante.pericoloso ? (pulsante.down ? Qt.darker(Tema.pericolo, 1.15) : Tema.pericolo)
               : pulsante.principale ? (pulsante.down ? Tema.accentoScuro : Tema.accento)
               : (pulsante.down ? Qt.darker(Tema.superficieAlta, Tema.chiaro ? 1.08 : 0.85) : (pulsante.hovered ? Qt.lighter(Tema.superficieAlta, Tema.chiaro ? 1.0 : 1.12) : Tema.superficieAlta))
        border.color: pulsante.telefono ? "transparent" : ((pulsante.principale || pulsante.pericoloso) ? "transparent" : (Tema.chiaro ? "#D1D1D6" : "#00000000"))
        border.width: pulsante.telefono ? 0 : (Tema.chiaro ? 0.5 : 0)
        opacity: pulsante.enabled ? 1 : 0.45
        Behavior on color { enabled: Tema.animazioni; ColorAnimation { duration: 120 } }
    }
}
