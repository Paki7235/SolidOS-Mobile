// Icona del dispositivo: telefono e tablet disegnati qui (non tutti i temi di icone li hanno),
// computer e portatili dal tema.
import QtQuick
import SolidUI

Item {
    id: radice
    property string tipo: "computer"       // computer | portatile | telefono | tablet
    property string icona: "computer"       // nome dal tema, per computer e portatili
    property int lato: 24
    property color colore: "#3A3F4B"
    width: lato
    height: lato
    readonly property bool disegnata: tipo === "telefono" || tipo === "tablet"

    Icona { anchors.centerIn: parent; visible: !radice.disegnata; nome: radice.icona; lato: radice.lato }

    // Telefono (verticale, stretto) o tablet (più largo): scocca, schermo, tasto
    Rectangle {
        visible: radice.disegnata
        anchors.centerIn: parent
        height: radice.lato * 0.92
        width: height * (radice.tipo === "tablet" ? 0.74 : 0.5)
        radius: width * 0.18
        color: radice.colore
        Rectangle {
            anchors.fill: parent
            anchors.margins: Math.max(1.5, parent.width * 0.1)
            anchors.topMargin: parent.height * 0.1
            anchors.bottomMargin: parent.height * 0.12
            radius: parent.radius * 0.5
            gradient: Gradient {
                GradientStop { position: 0; color: "#7FB2FF" }
                GradientStop { position: 1; color: "#4C7DFF" }
            }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.035
            width: parent.width * 0.3; height: Math.max(1, parent.height * 0.04); radius: height / 2
            color: "#CCFFFFFF"
        }
    }
}
