// Barra in alto: ora a sinistra (con la chiamata in corso, se ridotta), a destra rete, Wi-Fi
// e la batteria disegnata (rossa se sta finendo, verde mentre si carica).
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
            color: tel.inchiostroSopra
            font.family: Tema.font; font.pixelSize: 15; font.weight: Font.DemiBold
        }
        // Chiamata ridotta: una pillola verde con la durata, si tocca per tornare alla chiamata
        Rectangle {
            visible: barra.inChiamata
            anchors.verticalCenter: parent.verticalCenter
            height: 24; radius: 12; width: durata.implicitWidth + 34
            color: tel.pal.successo
            Rectangle { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: "#ffffff" }
            Text { id: durata; x: 24; anchors.verticalCenter: parent.verticalCenter; text: tel.chiamataInfo.testo || ""; color: "#ffffff"; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold }
            MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: tel.chiamataRidotta = false }
        }
    }

    Row {
        anchors.right: parent.right; anchors.rightMargin: tel.margine + 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Icona { anchors.verticalCenter: parent.verticalCenter; nome: "network-cellular-symbolic"; lato: 15 }
        Icona { anchors.verticalCenter: parent.verticalCenter; visible: barra.st.rete && barra.st.rete.connesso; nome: "network-wireless-symbolic"; lato: 15 }
        // Batteria
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 27; height: 13
            Rectangle {
                width: 24; height: 13; radius: 4
                color: "transparent"
                border.color: Qt.rgba(tel.inchiostroSopra.r, tel.inchiostroSopra.g, tel.inchiostroSopra.b, 0.5); border.width: 1.2
                Rectangle {
                    x: 2; y: 2; height: parent.height - 4; radius: 2
                    width: Math.max(2, (parent.width - 4) * barra.bat.livello / 100)
                    color: barra.bat.livello <= 20 && !barra.bat.carica ? tel.rosso
                           : (barra.bat.carica && barra.bat.livello < 100 ? tel.pal.successo : tel.inchiostroSopra)
                }
            }
            Rectangle { x: 25; anchors.verticalCenter: parent.verticalCenter; width: 2; height: 5; radius: 1; color: Qt.rgba(tel.inchiostroSopra.r, tel.inchiostroSopra.g, tel.inchiostroSopra.b, 0.5) }
        }
    }
}
