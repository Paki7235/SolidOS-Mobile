// Schermata di blocco: data, ora grande (carattere e colore da Personalizza),
// widget in vetro, torcia e fotocamera. Si sblocca scorrendo in su dalla barretta.
import QtQuick
import SolidUI

Item {
    id: blocco
    signal sblocca()

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 74
        spacing: 2
        Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: "system-lock-screen-symbolic"; lato: 20 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tel.giorno()
            color: tel.pal.testo2
            font.family: Tema.font; font.pixelSize: tel.px(20); font.weight: Font.DemiBold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tel.ora()
            color: tel.pal.testo
            font.family: tel.fontOra; font.pixelSize: 104; font.weight: Font.Bold
            font.letterSpacing: -2
        }
    }

    // Widget: batteria di questo telefono e dei dispositivi del Solid ID
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 270
        spacing: 10
        Vetro {
            width: 72; height: 72; radius: 36
            Column {
                anchors.centerIn: parent
                spacing: 2
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: (tel.stato.batteria ? tel.stato.batteria.livello : 100) + "%"; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.Bold }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("batteria"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(11) }
            }
        }
        Vetro {
            width: 172; height: 72; radius: 22
            Column {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left; anchors.leftMargin: 14
                spacing: 2
                Text { text: tel.stato.rete && tel.stato.rete.connesso ? tel.stato.rete.nome : I18n.t("Nessuna rete"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.DemiBold; width: 144; elide: Text.ElideRight }
                Text { text: tel.stato.bluetooth ? I18n.t("Bluetooth acceso") : I18n.t("Bluetooth spento"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 380
        width: parent.width - 60
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: I18n.t("Nessuna notifica")
        color: tel.pal.testo2
        font.family: Tema.font; font.pixelSize: tel.px(14)
    }

    // Torcia e fotocamera
    Row {
        anchors.left: parent.left; anchors.right: parent.right
        anchors.bottom: parent.bottom; anchors.bottomMargin: 44
        leftPadding: 46; rightPadding: 46
        spacing: parent.width - 92 - 104
        Repeater {
            model: [{ i: "flashlight-symbolic", t: I18n.t("Torcia") }, { i: "camera-photo-symbolic", t: I18n.t("Fotocamera") }]
            Vetro {
                required property var modelData
                width: 52; height: 52; radius: 26
                Icona { anchors.centerIn: parent; nome: parent.modelData.i; lato: 22 }
                MouseArea { anchors.fill: parent; onClicked: tel.avviso(parent.modelData.t + ": " + I18n.t("arriva con il telefono vero")) }
            }
        }
    }

    // Scorri in su (o tocca) per entrare
    Item {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 120
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 22
            text: I18n.t("Scorri in su per entrare")
            color: tel.pal.testo2
            font.family: Tema.font; font.pixelSize: tel.px(13)
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 8
            width: 134; height: 5; radius: 3
            color: tel.pal.testo
        }
        DragHandler { target: null; xAxis.enabled: false; onActiveChanged: if (!active && translation.y < -40) blocco.sblocca() }
        TapHandler { onDoubleTapped: blocco.sblocca() }
    }
}
