// Schermata di blocco: data, ora grande (carattere e colore da Personalizza),
// widget in vetro, torcia e fotocamera. Si sblocca scorrendo in su dalla barretta.
import QtQuick
import SolidUI

Item {
    id: blocco
    signal sblocca()
    property bool chiedeCodice: false       // tastierino del codice visibile
    property string codice: ""
    property string errore: ""
    // Si entra: con il codice se impostato, poi si toglie l'eventuale blocco di «Dov'è»
    function entra() {
        if (ponte.chiama0("haCodice")) { chiedeCodice = true; codice = ""; errore = ""; return }
        fatto()
    }
    function fatto() {
        chiedeCodice = false; codice = ""; errore = ""
        if (tel.messaggioRemoto) { ponte.chiama0("sbloccatoRemoto"); tel.messaggioRemoto = "" }
        blocco.sblocca()
    }
    function cifra(c) {
        if (codice.length >= 8) return
        codice += c; errore = ""
        if (codice.length >= ponte.chiama0("lunghezzaCodice")) {
            var r = ponte.chiama("verificaCodice", [codice])
            if (r.ok) fatto()
            else { errore = r.messaggio; codice = "" }
        }
    }

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

    Column {
        x: 14; y: 370
        width: parent.width - 28
        spacing: 8
        visible: !blocco.chiedeCodice
        // Messaggio del proprietario mandato da «Dov'è»
        Rectangle {
            visible: tel.messaggioRemoto !== ""
            width: parent.width; height: remoto.implicitHeight + 28; radius: 20
            color: tel.chiaro ? "#fff1f1" : "#3a1c22"
            border.color: "#ef4444"; border.width: 1
            Column {
                id: remoto
                x: 16; y: 14; width: parent.width - 32; spacing: 4
                Text { text: I18n.t("Telefono bloccato dal proprietario"); color: "#ef4444"; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.Bold }
                Text { width: parent.width; wrapMode: Text.Wrap; text: tel.messaggioRemoto; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(17); font.weight: Font.DemiBold }
            }
        }
        Repeater {
            model: tel.messaggioRemoto ? [] : tel.elencoNotifiche.slice(0, 3)
            SchedaNotifica { required property var modelData; n: modelData; compatta: true }
        }
        Text {
            visible: tel.elencoNotifiche.length > 3
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.t("e altre") + " " + (tel.elencoNotifiche.length - 3)
            color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13)
        }
        Text {
            visible: tel.elencoNotifiche.length === 0
            anchors.horizontalCenter: parent.horizontalCenter
            text: tel.imp.non_disturbare ? I18n.t("Non disturbare attivo") : I18n.t("Nessuna notifica")
            color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(14)
        }
    }

    // Torcia e fotocamera
    Row {
        anchors.left: parent.left; anchors.right: parent.right
        anchors.bottom: parent.bottom; anchors.bottomMargin: 44
        leftPadding: 46; rightPadding: 46
        spacing: parent.width - 92 - 104
        Repeater {
            model: [{ i: "torcia", t: I18n.t("Torcia") }, { i: "camera-photo-symbolic", t: I18n.t("Fotocamera") }]
            Vetro {
                required property var modelData
                width: 52; height: 52; radius: 26
                Icona { anchors.centerIn: parent; visible: parent.modelData.i !== "torcia"; nome: parent.modelData.i; lato: 22 }
                // Torcia disegnata (non tutti i temi di icone ce l'hanno)
                Item {
                    visible: parent.modelData.i === "torcia"
                    anchors.centerIn: parent; width: 14; height: 24
                    Rectangle { width: 14; height: 7; radius: 2; color: tel.pal.testo }
                    Rectangle { y: 6; x: 3; width: 8; height: 17; radius: 2; color: tel.pal.testo }
                    Rectangle { y: 10; x: 6; width: 2; height: 4; radius: 1; color: tel.chiaro ? "#ffffff" : "#1b2140" }
                }
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
        visible: !blocco.chiedeCodice
        // Lo spostamento si ricorda mentre il dito si muove: al rilascio Qt lo azzera
        DragHandler {
            target: null; xAxis.enabled: false
            property real ultimaY: 0
            onTranslationChanged: if (active) ultimaY = translation.y
            onActiveChanged: if (active) ultimaY = 0; else if (ultimaY < -40) blocco.entra()
        }
        TapHandler { onDoubleTapped: blocco.entra() }
    }

    // ── Tastierino del codice di sblocco ─────────────────────────────────
    Rectangle {
        anchors.fill: parent
        visible: blocco.chiedeCodice
        color: tel.pal.velo
        MouseArea { anchors.fill: parent }
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 130
            spacing: 16
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Inserisci il codice"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(20); font.weight: Font.DemiBold }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14
                Repeater {
                    model: ponte.chiama0("lunghezzaCodice")
                    Rectangle {
                        required property int index
                        width: 14; height: 14; radius: 7
                        color: index < blocco.codice.length ? tel.pal.testo : "transparent"
                        border.color: tel.pal.testo; border.width: 1.5
                    }
                }
            }
            Text { anchors.horizontalCenter: parent.horizontalCenter; height: 20; text: blocco.errore; color: "#ef4444"; font.family: Tema.font; font.pixelSize: tel.px(14) }
        }
        Grid {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 300
            columns: 3; rowSpacing: 18; columnSpacing: 26
            Repeater {
                model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "⌫"]
                Rectangle {
                    required property string modelData
                    width: 78; height: 78; radius: 39
                    color: modelData === "" || modelData === "⌫" ? "transparent" : tel.pal.vetro
                    border.color: modelData === "" || modelData === "⌫" ? "transparent" : tel.pal.vetroBordo
                    Text { anchors.centerIn: parent; text: parent.modelData; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: parent.modelData === "⌫" ? 26 : 32 }
                    MouseArea {
                        anchors.fill: parent; enabled: parent.modelData !== ""
                        onClicked: parent.modelData === "⌫" ? blocco.codice = blocco.codice.slice(0, -1) : blocco.cifra(parent.modelData)
                    }
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 50
            text: I18n.t("Annulla"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16)
            MouseArea { anchors.fill: parent; anchors.margins: -12; onClicked: blocco.chiedeCodice = false }
        }
    }
}
