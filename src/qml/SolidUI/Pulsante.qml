// Pulsante compatto: normale (grigio), principale (accento) o pericoloso (rosso).
import QtQuick
import QtQuick.Controls

Button {
    id: pulsante
    property bool principale: false
    property bool pericoloso: false
    property string icona: ""
    font.family: Tema.font
    font.pixelSize: 13
    font.weight: Font.Medium
    leftPadding: 14
    rightPadding: 14
    topPadding: 5
    bottomPadding: 5
    hoverEnabled: true

    contentItem: Row {
        spacing: 6
        Icona { nome: pulsante.icona; lato: 16; visible: pulsante.icona !== ""; anchors.verticalCenter: parent.verticalCenter }
        Text {
            text: pulsante.text
            font: pulsante.font
            color: (pulsante.principale || pulsante.pericoloso) ? "#FFFFFF" : Tema.testo
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    background: Rectangle {
        implicitHeight: 28
        implicitWidth: 64
        radius: 7
        color: pulsante.pericoloso ? (pulsante.down ? Qt.darker(Tema.pericolo, 1.15) : Tema.pericolo)
             : pulsante.principale ? (pulsante.down ? Tema.accentoScuro : Tema.accento)
             : (pulsante.down ? Qt.darker(Tema.superficieAlta, Tema.chiaro ? 1.08 : 0.85) : (pulsante.hovered ? Qt.lighter(Tema.superficieAlta, Tema.chiaro ? 1.0 : 1.12) : Tema.superficieAlta))
        border.color: (pulsante.principale || pulsante.pericoloso) ? "transparent" : (Tema.chiaro ? "#D1D1D6" : "#00000000")
        border.width: Tema.chiaro ? 0.5 : 0
        opacity: pulsante.enabled ? 1 : 0.45
        Behavior on color { enabled: Tema.animazioni; ColorAnimation { duration: 120 } }
    }
}
