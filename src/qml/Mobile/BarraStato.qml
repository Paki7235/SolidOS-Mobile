// Barra in alto del telefono: ora a sinistra (con la chiamata in corso, se ridotta),
// Wi-Fi e batteria a destra. Niente imitazioni di fotocamere o «isole».
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
            // Sul blocco (come nella prima versione) il nome del sistema: l'ora è già grande al centro
            text: tel.schermata === "blocco" && !tel.appInterna ? "SolidOS" : tel.ora()
            color: tel.pal.testo
            font.family: Tema.font; font.pixelSize: 15; font.weight: Font.DemiBold
        }
        // Chiamata ridotta: una pillola verde con la durata, si tocca per tornare alla chiamata
        Rectangle {
            visible: barra.inChiamata
            anchors.verticalCenter: parent.verticalCenter
            height: 24; radius: 12; width: durata.implicitWidth + 34
            color: tel.pal.successo
            Rectangle { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: "#ffffff" }
            Text { id: durata; x: 24; anchors.verticalCenter: parent.verticalCenter; text: tel.chiamataInfo.testo || ""; color: "#ffffff"; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.DemiBold }
            MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: tel.chiamataRidotta = false }
        }
    }

    Row {
        anchors.right: parent.right; anchors.rightMargin: tel.margine + 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        // Wi-Fi: tre archi
        Canvas {
            width: 17; height: 13
            visible: barra.st.rete && barra.st.rete.connesso
            anchors.verticalCenter: parent.verticalCenter
            property color c: tel.pal.testo
            onCChanged: requestPaint()
            onPaint: {
                var g = getContext("2d"); g.reset(); g.fillStyle = c
                g.beginPath(); g.moveTo(8.5, 12.5); g.arc(8.5, 12.5, 4.2, Math.PI * 1.25, Math.PI * 1.75); g.closePath(); g.fill()
                g.strokeStyle = c; g.lineWidth = 2.2; g.lineCap = "round"
                g.beginPath(); g.arc(8.5, 12.5, 7.6, Math.PI * 1.27, Math.PI * 1.73); g.stroke()
                g.beginPath(); g.arc(8.5, 12.5, 11, Math.PI * 1.28, Math.PI * 1.72); g.stroke()
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: barra.bat.livello + "%"
            color: tel.pal.testo
            font.family: Tema.font; font.pixelSize: 13; font.weight: Font.DemiBold
        }
        // Batteria
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 26; height: 13
            Rectangle {
                width: 23; height: 13; radius: 4
                color: "transparent"
                border.color: Qt.rgba(tel.pal.testo.r, tel.pal.testo.g, tel.pal.testo.b, 0.45); border.width: 1.2
                Rectangle {
                    x: 2; y: 2; height: parent.height - 4; radius: 2
                    width: Math.max(2, (parent.width - 4) * barra.bat.livello / 100)
                    color: barra.bat.livello <= 20 && !barra.bat.carica ? tel.pal.pericolo
                           : (barra.bat.carica && barra.bat.livello < 100 ? tel.pal.successo : tel.pal.testo)
                }
            }
            Rectangle { x: 24; anchors.verticalCenter: parent.verticalCenter; width: 2; height: 5; radius: 1; color: Qt.rgba(tel.pal.testo.r, tel.pal.testo.g, tel.pal.testo.b, 0.45) }
        }
    }
}
