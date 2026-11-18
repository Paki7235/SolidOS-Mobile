// Tasto tondo con un'icona a linea: grigio scuro, oppure pieno (bianco nel tema scuro)
import QtQuick
import SolidUI

Rectangle {
    id: tt
    property string icona: ""
    property bool pieno: false
    property int lato: 44
    property int latoIcona: Math.round(lato * 0.45)
    signal tocco()
    width: lato; height: lato; radius: lato / 2
    color: pieno ? tel.pal.pieno : tel.pal.superficie2
    scale: toccoTt.pressed ? 0.92 : 1
    Behavior on scale { NumberAnimation { duration: tel.tVeloce; easing.type: Easing.OutQuad } }
    Behavior on color { ColorAnimation { duration: tel.tVeloce } }
    Icona { anchors.centerIn: parent; nome: tt.icona; lato: tt.latoIcona; tema: tt.pieno ? (tel.chiaro ? "scuro" : "chiaro") : "" }
    MouseArea { id: toccoTt; anchors.fill: parent; anchors.margins: -4; onClicked: tt.tocco() }
}
