// Schermata di blocco. Aurora: data e ora sottili e grandi al centro, sulla luce colorata.
// Prisma: fondo viola con forme lime e corallo, l'ora gigante su due righe a sinistra.
// Sotto: il brano in riproduzione, le notifiche, torcia e fotocamera. Si sblocca scorrendo in su dalla barretta: il
// contenuto segue il dito.
import QtQuick
import SolidUI

Item {
    id: blocco
    signal sblocca()
    property bool chiedeCodice: false       // tastierino del codice visibile
    property bool chiedeSolidId: false      // modalità smarrito: serve la password del Solid ID
    // Il numero nel messaggio del proprietario (per «Chiama il proprietario»)
    readonly property string numeroProprietario: { var m = (tel.messaggioRemoto || "").match(/\+?\d[\d\s.\/-]{6,}\d/); return m ? m[0] : "" }
    property string codice: ""
    property string errore: ""
    // Sblocco che segue il dito: il contenuto sale e sfuma mentre si trascina in su
    property real trascinamento: 0
    readonly property real presenza: Math.max(0, 1 + trascinamento / (height * 0.45))
    // Vesti Prisma: fondo pieno con le forme; il testo in basso sta sopra la forma lime
    readonly property bool prisma: tel.solido
    readonly property color inchiostroBasso: prisma ? "#141414" : "#FFFFFF"

    // ── Fondo delle vesti Prisma ───────────────────────────────────────────
    Item {
        anchors.fill: parent; clip: true; visible: blocco.prisma
        Rectangle { anchors.fill: parent; color: tel.veste === "notte" ? "#141414" : "#8B6CFF" }
        Rectangle { // corallo a destra
            width: blocco.width * 0.67; height: width; radius: width / 2; color: "#FF6B4A"
            x: blocco.width - width * 0.7; y: blocco.height * 0.36
        }
        Rectangle { // lime in basso a sinistra
            width: blocco.width * 1.33; height: width; radius: width / 2; color: "#C6F432"
            x: -blocco.width * 0.46; y: blocco.height - width * 0.62
        }
    }
    Translate { id: spinta; y: blocco.trascinamento * 0.8 }
    NumberAnimation { id: ritorno; target: blocco; property: "trascinamento"; to: 0; duration: tel.tEntrata; easing.type: Easing.OutQuint }
    SequentialAnimation {
        id: uscita
        NumberAnimation { target: blocco; property: "trascinamento"; to: -blocco.height * 0.5; duration: tel.tNormale; easing.type: Easing.InCubic }
        ScriptAction { script: { blocco.trascinamento = 0; blocco.entra() } }
    }
    // Si entra: con il codice se impostato, poi si toglie l'eventuale blocco di «Dov'è»
    function entra() {
        if (tel.perso) { chiedeSolidId = true; errore = ""; passwordSid.text = ""; return }
        if (ponte.chiama0("haCodice")) { chiedeCodice = true; codice = ""; errore = ""; return }
        fatto()
    }
    function fatto() {
        chiedeCodice = false; chiedeSolidId = false; codice = ""; errore = ""
        if (tel.messaggioRemoto) { ponte.chiama0("sbloccatoRemoto"); tel.messaggioRemoto = ""; tel.perso = false }
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

    // Data e ora: al centro e sottili (Aurora), a sinistra e giganti su due righe (Prisma)
    Column {
        id: orologio
        transform: spinta; opacity: blocco.presenza
        x: blocco.prisma ? 26 : (blocco.width - width) / 2
        y: Math.round(Math.min(blocco.prisma ? 78 : 92, blocco.height * 0.1))
        spacing: 0
        Text {
            anchors.horizontalCenter: blocco.prisma ? undefined : parent.horizontalCenter
            text: blocco.prisma ? tel.adesso.toLocaleDateString(Qt.locale("it_IT"), "ddd d MMM") : tel.giorno()
            color: "#FFFFFF"; opacity: blocco.prisma ? 1 : 0.85
            font.family: Tema.font; font.pixelSize: tel.px(blocco.prisma ? 18 : 17); font.weight: blocco.prisma ? Font.Bold : Font.Medium
        }
        Text {
            visible: !blocco.prisma
            anchors.horizontalCenter: parent.horizontalCenter
            text: tel.ora()
            color: "#FFFFFF"
            font.family: tel.fontOra; font.pixelSize: Math.min(128, Math.round(blocco.width * 0.33)); font.weight: Font.ExtraLight
            font.letterSpacing: -7
        }
        Text {
            visible: blocco.prisma
            topPadding: 8
            text: Qt.formatTime(tel.adesso, "HH") + "\n" + Qt.formatTime(tel.adesso, "mm")
            color: "#FFFFFF"; lineHeight: 0.8
            font.family: tel.fontOra; font.pixelSize: Math.min(170, Math.round(blocco.width * 0.43)); font.weight: Font.Black
            font.letterSpacing: -8
        }
        Row {
            id: pillole
            anchors.horizontalCenter: blocco.prisma ? undefined : parent.horizontalCenter
            spacing: 6
            visible: tel.imp.non_disturbare === true
            Icona { anchors.verticalCenter: parent.verticalCenter; nome: "weather-clear-night-symbolic"; lato: 14; tema: "scuro" }
            Text { text: I18n.t("Non disturbare"); color: "#FFFFFF"; opacity: 0.85; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.Medium }
        }
        // Widget della schermata di blocco (scelti dalla galleria dei widget)
        Row {
            id: widgetBlocco
            anchors.horizontalCenter: blocco.prisma ? undefined : parent.horizontalCenter
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
        visible: !blocco.chiedeCodice && !blocco.chiedeSolidId
        // Il brano in riproduzione
        Vetro {
            visible: !!tel.musica.titolo && !tel.messaggioRemoto
            width: parent.width; height: 80; radius: 28
            tinta: "#FF6B4A"
            Rectangle {
                x: 14; anchors.verticalCenter: parent.verticalCenter; width: 52; height: 52; radius: 14
                gradient: Gradient { GradientStop { position: 0; color: "#FFD36E" } GradientStop { position: 0.5; color: "#FF3D8B" } GradientStop { position: 1; color: "#7B3CFF" } }
            }
            Column {
                x: 80; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 80 - 60
                Text { width: parent.width; elide: Text.ElideRight; text: tel.musica.titolo || ""; color: blocco.prisma ? "#FFFFFF" : tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.DemiBold }
                Text { width: parent.width; elide: Text.ElideRight; text: tel.musica.artista || I18n.t("In riproduzione"); color: blocco.prisma ? "#D9FFFFFF" : tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13) }
            }
            Icona {
                anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter
                nome: tel.musica.suona ? "linea-pausa" : "linea-play"; lato: 26; tema: "scuro"
                MouseArea { anchors.fill: parent; anchors.margins: -12; onClicked: tel.comandoMusica("play") }
            }
        }
        // Messaggio del proprietario mandato da «Dov'è»
        Vetro {
            visible: tel.messaggioRemoto !== ""
            width: parent.width; height: remoto.implicitHeight + 40; radius: 24
            Column {
                id: remoto
                x: 20; y: 20; width: parent.width - 40; spacing: 8
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 52; height: 52; radius: 26; color: tel.rosso
                    Icona { anchors.centerIn: parent; nome: "system-lock-screen-symbolic"; lato: 26; tema: "scuro" }
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: tel.perso ? I18n.t("Telefono smarrito") : I18n.t("Telefono bloccato dal proprietario"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(18); font.weight: Font.Bold }
                Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: tel.messaggioRemoto; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15) }
                Rectangle {
                    visible: blocco.numeroProprietario !== ""
                    width: parent.width; height: 46; radius: 23; color: tel.chiaro ? "#1D1D1F" : "#FFFFFF"
                    Row {
                        anchors.centerIn: parent; spacing: 8
                        Icona { anchors.verticalCenter: parent.verticalCenter; nome: "call-start-symbolic"; lato: 18; tema: tel.chiaro ? "scuro" : "chiaro" }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Chiama il proprietario"); color: tel.chiaro ? "#FFFFFF" : "#1D1D1F"; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.DemiBold }
                    }
                    MouseArea { anchors.fill: parent; onClicked: tel.chiama(blocco.numeroProprietario) }
                }
                Text {
                    visible: tel.perso
                    width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                    text: I18n.t("Questo telefono è collegato a un Solid ID. Per sbloccarlo serve la sua password.")
                    color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12)
                }
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
            color: blocco.inchiostroBasso; opacity: 0.8; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.Medium
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
                width: 54; height: 54; radius: blocco.prisma ? 19 : 27
                tinta: "#FFFFFF"
                Icona { anchors.centerIn: parent; nome: parent.modelData.i; lato: 21; tema: blocco.prisma ? "chiaro" : "scuro" }
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
            color: blocco.inchiostroBasso; opacity: 0.75
            font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.Medium
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 8
            width: 134; height: 5; radius: 3
            color: blocco.inchiostroBasso
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

    // ── Modalità smarrito: sblocco con la password del Solid ID ───────────
    Rectangle {
        anchors.fill: parent
        visible: blocco.chiedeSolidId
        color: tel.chiaro ? Qt.rgba(0.95, 0.95, 0.97, 0.97) : Qt.rgba(0.07, 0.08, 0.11, 0.96)
        MouseArea { anchors.fill: parent }
        Column {
            x: 28; y: 140; width: parent.width - 56; spacing: 14
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 64; height: 64; radius: 20
                gradient: Gradient { GradientStop { position: 0; color: "#4C7DFF" } GradientStop { position: 1; color: "#8B5CF6" } }
                Icona { anchors.centerIn: parent; nome: "system-lock-screen-symbolic"; lato: 30; tema: "scuro" }
            }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Sblocca con il Solid ID"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(21); font.weight: Font.Bold }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                   text: { var e = ponte.chiama0("emailSolidId"); return I18n.t("Il telefono è in modalità smarrito. Scrivi la password del Solid ID") + (e ? " " + e : "") + "." }
                   color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(14) }
            CampoTesto { id: passwordSid; width: parent.width; echoMode: TextInput.Password; placeholderText: I18n.t("Password del Solid ID"); onAccepted: sbloccaSid.clicked() }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: blocco.errore; color: tel.rosso; font.family: Tema.font; font.pixelSize: tel.px(13) }
            Pulsante {
                id: sbloccaSid
                width: parent.width; text: I18n.t("Sblocca"); principale: true
                onClicked: { var r = ponte.chiama("verificaSolidId", [passwordSid.text]); passwordSid.text = ""; if (r.ok) blocco.fatto(); else blocco.errore = r.messaggio }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 50
            text: I18n.t("Annulla"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16)
            MouseArea { anchors.fill: parent; anchors.margins: -12; onClicked: blocco.chiedeSolidId = false }
        }
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
