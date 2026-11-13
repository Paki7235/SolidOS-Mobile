// Messaggio temporaneo («toast») in basso al centro.
import QtQuick

Rectangle {
    id: toast
    property alias testo: etichetta.text
    function mostra(t) { etichetta.text = t; opacity = 1; timer.restart() }
    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
    anchors.bottom: parent ? parent.bottom : undefined
    anchors.bottomMargin: 24
    width: Math.min(etichetta.implicitWidth + 40, 520)
    height: etichetta.implicitHeight + 20
    radius: 10
    color: Tema.superficieAlta
    border.color: Tema.bordo
    opacity: 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 150 } }
    Testo { id: etichetta; anchors.centerIn: parent; width: parent.width - 40; horizontalAlignment: Text.AlignHCenter }
    Timer { id: timer; interval: 3500; onTriggered: toast.opacity = 0 }
}
