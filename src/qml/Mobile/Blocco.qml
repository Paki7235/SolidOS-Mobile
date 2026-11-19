// Schermata di blocco: data e ora grandi al centro sullo sfondo del PC, le notifiche in basso
// in pannelli di vetro, torcia e fotocamera. Si sblocca scorrendo in su dalla barretta: il
// contenuto segue il dito.
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

    // Data e ora grandi al centro
    Column {
        id: orologio
        transform: spinta; opacity: blocco.presenza
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(Math.min(86, blocco.height * 0.1))
        spacing: 0
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tel.giorno()
            color: tel.chiaro ? "#1D1D1F" : "#FFFFFF"; opacity: 0.9
            font.family: Tema.font; font.pixelSize: tel.px(19); font.weight: Font.DemiBold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tel.ora()
            color: tel.chiaro ? "#1D1D1F" : "#FFFFFF"
            font.family: tel.fontOra; font.pixelSize: Math.min(104, Math.round(blocco.width * 0.26)); font.weight: Font.DemiBold
            font.letterSpacing: -4
        }
        Row {
            id: pillole
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            visible: tel.imp.non_disturbare === true
            Icona { anchors.verticalCenter: parent.verticalCenter; nome: "weather-clear-night-symbolic"; lato: 14; tema: tel.chiaro ? "chiaro" : "scuro" }
            Text { text: I18n.t("Non disturbare"); color: tel.chiaro ? "#1D1D1F" : "#FFFFFF"; opacity: 0.85; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.Medium }
        }
        // Widget della schermata di blocco (scelti dalla galleria dei widget)
        Row {
            id: widgetBlocco
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 8; spacing: 8
            visible: (tel.imp.widget_blocco || []).length > 0
            property var meteo: ({})
            Component.onCompleted: if ((tel.imp.widget_blocco || []).indexOf("meteo") >= 0) ponte.avvia("meteo", [], "blocco-meteo")
            Connections { target: ponte; function onCompletato(id, r) { if (id === "blocco-meteo") widgetBlocco.meteo = r } }
            Repeater {
                model: tel.imp.widget_blocco || []
                Vetro {
                    id: wb
                    required property string modelData
                    readonly property string testo: modelData === "meteo" ? (widgetBlocco.meteo.ok ? widgetBlocco.meteo.gradi + "° " + (widgetBlocco.meteo.citta || "") : "—")
                                                  : modelData === "batterie" ? ((tel.stato && tel.stato.batteria ? tel.stato.batteria.livello : 100) + "%")
                                                  : modelData === "musica" ? (tel.musica.titolo || I18n.t("Musica"))
                                                  : ((tel.elencoNotifiche || []).length ? (tel.elencoNotifiche[0].titolo || "") : I18n.t("Nessun impegno"))
                    width: Math.min(150, rigaWb.implicitWidth + 24); height: 34; radius: 17
                    Row {
                        id: rigaWb
                        anchors.centerIn: parent; spacing: 6
                        Icona { anchors.verticalCenter: parent.verticalCenter; lato: 15; tema: tel.chiaro ? "chiaro" : "scuro"
                                nome: ({ meteo: "linea-" + (widgetBlocco.meteo.icona || "sole"), batterie: "linea-batteria", musica: "linea-musica", oggi: "linea-calendario" })[wb.modelData] }
                        Text { anchors.verticalCenter: parent.verticalCenter; width: Math.min(implicitWidth, 110); elide: Text.ElideRight; text: wb.testo; color: tel.chiaro ? "#1D1D1F" : "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                    }
                }
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
            color: tel.chiaro ? "#1D1D1F" : "#FFFFFF"; opacity: 0.8; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.Medium
        }
    }

    // Torcia e fotocamera
    Row {
        transform: spinta; opacity: blocco.presenza
        anchors.left: parent.left; anchors.right: parent.right
        anchors.bottom: parent.bottom; anchors.bottomMargin: 42
        leftPadding: 36; rightPadding: 36
        spacing: parent.width - 72 - 104
        Repeater {
            model: [{ i: "torcia", t: I18n.t("Torcia") }, { i: "camera-photo-symbolic", t: I18n.t("Fotocamera") }]
            Vetro {
                required property var modelData
                width: 52; height: 52; radius: 26
                Icona { anchors.centerIn: parent; nome: parent.modelData.i; lato: 21 }
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
            color: tel.chiaro ? "#1D1D1F" : "#FFFFFF"; opacity: 0.75
            font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.Medium
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 8
            width: 134; height: 5; radius: 3
            color: tel.chiaro ? "#1D1D1F" : "#FFFFFF"
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
        color: tel.chiaro ? Qt.rgba(0.95, 0.95, 0.97, 0.96) : Qt.rgba(0.07, 0.08, 0.11, 0.95)
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
                    color: modelData === "" || modelData === "⌫" ? "transparent" : (tasto.pressed ? tel.accento : tel.pal.superficie2)
                    Behavior on color { ColorAnimation { duration: tel.tVeloce } }
                    Text { anchors.centerIn: parent; text: parent.modelData; color: tasto.pressed && parent.modelData !== "⌫" ? "#FFFFFF" : tel.pal.testo; font.family: Tema.font; font.pixelSize: parent.modelData === "⌫" ? 24 : 30; font.weight: Font.Medium }
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
