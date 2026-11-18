// Tasto tondo con un'icona: grigio, oppure pieno nel blu di SolidOS (icona bianca)
import QtQuick
import SolidUI

Rectangle {
    id: tt
    property string icona: ""
    property bool pieno: false
    property int lato: 40
    property int latoIcona: Math.round(lato * 0.45)
    signal tocco()
    width: lato; height: lato; radius: lato / 2
    color: pieno ? tel.accento : tel.pal.superficie2
    scale: toccoTt.pressed ? 0.92 : 1
    Behavior on scale { NumberAnimation { duration: tel.tVeloce; easing.type: Easing.OutQuad } }
    Behavior on color { ColorAnimation { duration: tel.tVeloce } }
    Icona { anchors.centerIn: parent; nome: tt.icona; lato: tt.latoIcona; tema: tt.pieno ? "scuro" : "" }
    MouseArea { id: toccoTt; anchors.fill: parent; anchors.margins: -4; onClicked: tt.tocco() }
}
