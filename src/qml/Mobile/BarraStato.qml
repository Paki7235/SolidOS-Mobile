// Barra in alto del telefono: ora (o operatore sul blocco), segnale, Wi-Fi, batteria.
// Al centro la «pillola» nera della fotocamera frontale.
import QtQuick

Item {
    id: barra
    height: 50
    readonly property var st: tel.stato || ({})
    readonly property var bat: st.batteria || ({ livello: 100, carica: true })

    Text {
        anchors.left: parent.left; anchors.leftMargin: 30
        anchors.verticalCenter: pillola.verticalCenter
        text: tel.schermata === "blocco" ? "SolidOS" : tel.ora()
        color: tel.pal.testo
        font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.DemiBold
    }
    Rectangle {
        id: pillola
        anchors.horizontalCenter: parent.horizontalCenter
        y: 11
        width: 124; height: 36; radius: 18
        color: "#000000"
    }
    Row {
        anchors.right: parent.right; anchors.rightMargin: 28
        anchors.verticalCenter: pillola.verticalCenter
        spacing: 6
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
        // Batteria
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 25; height: 12; radius: 4
            color: "transparent"
            border.color: tel.pal.testo; border.width: 1.5
            Rectangle {
                x: 2; y: 2; height: parent.height - 4; radius: 2
                width: Math.max(2, (parent.width - 4) * barra.bat.livello / 100)
                color: barra.bat.livello <= 20 && !barra.bat.carica ? "#ef4444" : (barra.bat.carica && barra.bat.livello < 100 ? "#22c55e" : tel.pal.testo)
            }
        }
    }
}
