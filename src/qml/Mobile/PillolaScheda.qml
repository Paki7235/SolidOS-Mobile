// Pillola colorata dietro l'icona della scheda attiva nelle barre in basso delle app:
// lime nelle vesti Prisma, il colore di sistema trasparente in Aurora.
import QtQuick

Rectangle {
    property bool attiva: false
    anchors.horizontalCenter: parent.horizontalCenter
    y: (parent.height - 50) / 2 + 1
    width: 54; height: 30; radius: 15
    visible: attiva
    color: tel.solido ? "#C6F432" : Qt.rgba(tel.accento.r, tel.accento.g, tel.accento.b, 0.28)
}
