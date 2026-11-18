// Barra in alto «Essenziale»: ora in Space Mono a sinistra (con la chiamata in corso, se
// ridotta), a destra rete, Wi-Fi e la batteria scritta in numero (rossa se sta finendo).
import QtQuick
import SolidUI

Item {
    id: barra
    height: 40
    readonly property var st: tel.stato || ({})
    readonly property var bat: st.batteria || ({ livello: 100, carica: true })
    readonly property bool inChiamata: tel.chiamataInfo.attiva === true && tel.chiamataRidotta

    Row {
        anchors.left: parent.left; anchors.leftMargin: tel.margine + 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: tel.ora()
            color: tel.pal.testo
            font.family: tel.fontMono; font.pixelSize: 14; font.bold: true
        }
        // Chiamata ridotta: una pillola verde con la durata, si tocca per tornare alla chiamata
        Rectangle {
            visible: barra.inChiamata
            anchors.verticalCenter: parent.verticalCenter
            height: 24; radius: 12; width: durata.implicitWidth + 34
            color: tel.pal.successo
            Rectangle { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: "#000000" }
            Text { id: durata; x: 24; anchors.verticalCenter: parent.verticalCenter; text: tel.chiamataInfo.testo || ""; color: "#000000"; font.family: tel.fontMono; font.pixelSize: 12; font.bold: true }
            MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: tel.chiamataRidotta = false }
        }
    }

    Row {
        anchors.right: parent.right; anchors.rightMargin: tel.margine + 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Icona { anchors.verticalCenter: parent.verticalCenter; nome: "network-cellular-symbolic"; lato: 15 }
        Icona { anchors.verticalCenter: parent.verticalCenter; visible: barra.st.rete && barra.st.rete.connesso; nome: "network-wireless-symbolic"; lato: 15 }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: barra.bat.livello + (barra.bat.carica && barra.bat.livello < 100 ? "+" : "")
            color: barra.bat.livello <= 20 && !barra.bat.carica ? tel.rosso : tel.pal.testo
            font.family: tel.fontMono; font.pixelSize: 14; font.bold: true
        }
    }
}
