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
    // Sblocco che segue il dito: il contenuto sale e sfuma mentre si trascina in su
    property real trascinamento: 0
    readonly property real presenza: Math.max(0, 1 + trascinamento / (height * 0.45))
    Translate { id: spinta; y: blocco.trascinamento * 0.8 }
    NumberAnimation { id: ritorno; target: blocco; property: "trascinamento"; to: 0; duration: tel.tEntrata; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
    SequentialAnimation {
        id: uscita
        NumberAnimation { target: blocco; property: "trascinamento"; to: -blocco.height * 0.5; duration: tel.tNormale; easing.type: Easing.InCubic }
        ScriptAction { script: { blocco.trascinamento = 0; blocco.entra() } }
    }
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

    // Data e ora: orologio grande ma leggero, posizione proporzionale all'altezza
    Column {
        id: orologio
        transform: spinta; opacity: blocco.presenza
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(blocco.height * 0.09)
        spacing: 0
        Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: "system-lock-screen-symbolic"; lato: 16; opacity: 0.8 }
        Item { width: 1; height: 8 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tel.giorno()
            color: tel.pal.testo
            opacity: 0.85
            font.family: Tema.font; font.pixelSize: tel.px(17); font.weight: Font.Medium
            font.capitalization: Font.Capitalize
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tel.ora()
            color: tel.pal.testo
            font.family: tel.fontOra; font.pixelSize: Math.min(92, Math.round(blocco.width * 0.22)); font.weight: Font.Light
            font.letterSpacing: -1
        }
    }

    // Stato in piccolo: batteria e rete
    Row {
        id: pillole
        transform: spinta; opacity: blocco.presenza
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: orologio.bottom; anchors.topMargin: 6
        spacing: 8
        Repeater {
            model: [
                { t: (tel.stato.batteria ? tel.stato.batteria.livello : 100) + "%" + (tel.stato.batteria && tel.stato.batteria.carica ? " · " + I18n.t("in carica") : "") },
                { t: tel.stato.rete && tel.stato.rete.connesso ? tel.stato.rete.nome : I18n.t("Nessuna rete") }
            ]
            Vetro {
                required property var modelData
                height: 28; radius: 14; width: Math.min(blocco.width * 0.42, etichettaPillola.implicitWidth + 24)
                Text { id: etichettaPillola; anchors.centerIn: parent; width: parent.width - 24; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                       text: parent.modelData.t; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(12); font.weight: Font.Medium }
            }
        }
    }

    Column {
        transform: spinta; opacity: blocco.presenza
        x: tel.margine - 4
        anchors.top: pillole.bottom; anchors.topMargin: 28
        width: parent.width - 2 * (tel.margine - 4)
        spacing: 8
        visible: !blocco.chiedeCodice
        // Messaggio del proprietario mandato da «Dov'è»
        Rectangle {
            visible: tel.messaggioRemoto !== ""
            width: parent.width; height: remoto.implicitHeight + 28; radius: tel.r2
            color: tel.chiaro ? "#FFF1F1" : "#2A1517"
            border.color: tel.pal.pericolo; border.width: 1
            Column {
                id: remoto
                x: 16; y: 14; width: parent.width - 32; spacing: 4
                Text { text: I18n.t("Telefono bloccato dal proprietario"); color: tel.pal.pericolo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.Bold }
                Text { width: parent.width; wrapMode: Text.Wrap; text: tel.messaggioRemoto; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(17); font.weight: Font.DemiBold }
            }
        }
        Repeater {
            model: tel.messaggioRemoto ? [] : tel.elencoNotifiche.slice(0, blocco.height < 760 ? 2 : 3)
            SchedaNotifica { required property var modelData; n: modelData; compatta: true }
        }
        Text {
            readonly property int mostrate: blocco.height < 760 ? 2 : 3
            visible: tel.elencoNotifiche.length > mostrate && !tel.messaggioRemoto
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.t("e altre") + " " + (tel.elencoNotifiche.length - mostrate)
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
        transform: spinta; opacity: blocco.presenza
        anchors.left: parent.left; anchors.right: parent.right
        anchors.bottom: parent.bottom; anchors.bottomMargin: 46
        leftPadding: tel.margine + 22; rightPadding: tel.margine + 22
        spacing: parent.width - 2 * (tel.margine + 22) - 96
        Repeater {
            model: [{ i: "torcia", t: I18n.t("Torcia") }, { i: "camera-photo-symbolic", t: I18n.t("Fotocamera") }]
            Vetro {
                required property var modelData
                width: 48; height: 48; radius: 24
                Icona { anchors.centerIn: parent; visible: parent.modelData.i !== "torcia"; nome: parent.modelData.i; lato: 20 }
                // Torcia disegnata (non tutti i temi di icone ce l'hanno)
                Item {
                    visible: parent.modelData.i === "torcia"
                    anchors.centerIn: parent; width: 14; height: 24
                    Rectangle { width: 14; height: 7; radius: 2; color: tel.pal.testo }
                    Rectangle { y: 6; x: 3; width: 8; height: 17; radius: 2; color: tel.pal.testo }
                    Rectangle { y: 10; x: 6; width: 2; height: 4; radius: 1; color: tel.pal.suPieno }
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
            color: tel.pal.testo
            opacity: 0.7
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
            onTranslationChanged: if (active) { ultimaY = translation.y; blocco.trascinamento = Math.min(0, translation.y) }
            onActiveChanged: {
                if (active) { ritorno.stop(); uscita.stop(); ultimaY = 0; return }
                // Oltre la soglia si entra, altrimenti tutto torna al suo posto con una piccola molla
                if (ultimaY < -Math.min(120, blocco.height * 0.15)) { if (tel.movimento) uscita.start(); else blocco.entra(); blocco.trascinamento = tel.movimento ? blocco.trascinamento : 0 }
                else ritorno.start()
            }
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
