// Schermata di blocco «Essenziale»: data in piccolo, ora grande a puntini, una riga di stato
// (novità in rosso, batteria, rete), le notifiche in basso, torcia e fotocamera.
// Si sblocca scorrendo in su dalla barretta: il contenuto segue il dito.
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
    NumberAnimation { id: ritorno; target: blocco; property: "trascinamento"; to: 0; duration: tel.tEntrata; easing.type: Easing.OutQuint }
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

    // Data, ora a puntini e riga di stato, allineate a sinistra
    Column {
        id: orologio
        transform: spinta; opacity: blocco.presenza
        x: 24
        y: Math.round(Math.min(92, blocco.height * 0.105))
        spacing: 6
        Mono { text: tel.adesso.toLocaleDateString(Qt.locale("it_IT"), "dddd · d MMM"); font.pixelSize: tel.px(13) }
        Punti {
            text: tel.ora()
            font.family: tel.fontOra
            font.pixelSize: Math.min(116, Math.round(blocco.width * 0.29))
            font.letterSpacing: -3
        }
        Row {
            id: pillole
            spacing: 8
            topPadding: 4
            Rectangle { visible: tel.elencoNotifiche.length > 0; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: tel.rosso }
            Mono {
                visible: tel.elencoNotifiche.length > 0
                text: tel.elencoNotifiche.length + " " + (tel.elencoNotifiche.length === 1 ? I18n.t("nuova") : I18n.t("nuove"))
                color: tel.pal.testo; font.pixelSize: tel.px(13)
            }
            Mono {
                text: (tel.elencoNotifiche.length > 0 ? "· " : "") + (tel.stato.batteria ? tel.stato.batteria.livello : 100) + "%"
                      + " · " + (tel.stato.rete && tel.stato.rete.connesso ? tel.stato.rete.nome : I18n.t("Nessuna rete"))
                      + (tel.imp.non_disturbare ? " · " + I18n.t("Non disturbare") : "")
                font.pixelSize: tel.px(13)
            }
        }
    }

    Column {
        transform: spinta; opacity: blocco.presenza
        x: 14
        anchors.bottom: parent.bottom; anchors.bottomMargin: 116
        width: parent.width - 28
        spacing: 8
        visible: !blocco.chiedeCodice
        // Messaggio del proprietario mandato da «Dov'è»
        Rectangle {
            visible: tel.messaggioRemoto !== ""
            width: parent.width; height: remoto.implicitHeight + 28; radius: tel.r2
            color: tel.pal.superficie
            border.color: tel.rosso; border.width: 1
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
            color: tel.pal.testo2; font.family: tel.fontMono; font.pixelSize: tel.px(12)
        }
    }

    // Torcia e fotocamera
    Row {
        transform: spinta; opacity: blocco.presenza
        anchors.left: parent.left; anchors.right: parent.right
        anchors.bottom: parent.bottom; anchors.bottomMargin: 42
        leftPadding: 32; rightPadding: 32
        spacing: parent.width - 64 - 108
        Repeater {
            model: [{ i: "torcia", t: I18n.t("Torcia") }, { i: "camera-photo-symbolic", t: I18n.t("Fotocamera") }]
            TastoTondo {
                required property var modelData
                icona: modelData.i; lato: 54; latoIcona: 22
                onTocco: tel.avviso(modelData.t + ": " + I18n.t("arriva con il telefono vero"))
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
            font.family: tel.fontMono; font.pixelSize: tel.px(11); font.capitalization: Font.AllUppercase; font.letterSpacing: 0.6
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 8
            width: 120; height: 4; radius: 2
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
            Mono { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Inserisci il codice"); color: tel.pal.testo; font.pixelSize: tel.px(13) }
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
            Text { anchors.horizontalCenter: parent.horizontalCenter; height: 20; text: blocco.errore; color: tel.rosso; font.family: Tema.font; font.pixelSize: tel.px(14) }
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
                    color: modelData === "" || modelData === "⌫" ? "transparent" : (tasto.pressed ? tel.pal.pieno : tel.pal.superficie2)
                    Behavior on color { ColorAnimation { duration: tel.tVeloce } }
                    Text { anchors.centerIn: parent; text: parent.modelData; color: tasto.pressed && parent.modelData !== "⌫" ? tel.pal.suPieno : tel.pal.testo; font.family: Tema.font; font.pixelSize: parent.modelData === "⌫" ? 24 : 30; font.weight: Font.Medium }
                    MouseArea {
                        id: tasto
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
