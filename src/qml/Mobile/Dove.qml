// App «Dov'è» sul telefono: mappa con i dispositivi del Solid ID, elenco sotto la mappa
// e, per il dispositivo scelto, Fai suonare, Blocca con un messaggio e Indicazioni.
// Senza Solid ID rimanda a Impostazioni › Solid ID.
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: app
    color: tel.chiaro ? "#f2f3f8" : "#0e1118"
    property var dispositivi: []
    property string scelto: ""
    property bool collegato: false
    property bool caricato: false
    property string errore: ""
    property int comandoId: 0          // comando in attesa di conferma
    property string comandoTipo: ""
    property int tentativi: 0
    readonly property color sezione: tel.chiaro ? "#ffffff" : "#1b1f2b"
    readonly property color linea: tel.chiaro ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.08)
    readonly property var dispositivo: dispositivi.find(function (d) { return d.id === scelto }) || null

    function aggiorna() {
        collegato = ponte.chiama0("solidId").collegato === true
        if (collegato) ponte.avvia("doveDispositivi", [], "dove-elenco")
        else caricato = true
    }
    function scegli(ident) {
        scelto = ident
        var d = dispositivo
        if (d && d.posizione) mappa.centra(d.lat, d.lon, 15)
    }
    function comando(tipo, messaggio) {
        if (!dispositivo) return
        var r = ponte.chiama("doveComando", [dispositivo.id, tipo, messaggio || ""])
        if (!r.ok) { tel.avviso(r.messaggio); return }
        comandoId = r.id; comandoTipo = tipo; tentativi = 0
        tel.avviso(tipo === "suona" ? I18n.t("Richiesta inviata: il dispositivo suonerà appena è in linea")
                                    : I18n.t("Richiesta inviata: il dispositivo si bloccherà appena è in linea"))
    }
    onVisibleChanged: if (visible) aggiorna()
    Component.onCompleted: aggiorna()

    Connections {
        target: ponte
        function onCompletato(id, r) {
            if (id !== "dove-elenco") return
            app.caricato = true
            app.errore = r.ok ? "" : (r.messaggio || "")
            app.dispositivi = r.dispositivi || []
            var conPos = app.dispositivi.filter(function (d) { return d.posizione })
            if (!app.scelto && conPos.length) {
                // Centra sulla media dei dispositivi con posizione
                var la = 0, lo = 0
                conPos.forEach(function (d) { la += d.lat; lo += d.lon })
                mappa.centra(la / conPos.length, lo / conPos.length, 13)
            }
        }
    }
    // Aggiorna l'elenco ogni 30 secondi mentre l'app è aperta
    Timer { interval: 30000; running: app.visible && app.collegato; repeat: true; onTriggered: ponte.avvia("doveDispositivi", [], "dove-elenco") }
    // Conferma dei comandi inviati
    Timer {
        interval: 3000; running: app.comandoId > 0; repeat: true
        onTriggered: {
            var s = ponte.chiama("doveStatoComando", [app.comandoId])
            app.tentativi++
            if (s === "eseguito") {
                tel.avviso(app.comandoTipo === "suona" ? I18n.t("Il dispositivo sta suonando") : I18n.t("Dispositivo bloccato"))
                app.comandoId = 0
            } else if (app.tentativi > 40) app.comandoId = 0
        }
    }

    // ══ Senza Solid ID ═══════════════════════════════════════════════════
    Column {
        visible: app.caricato && !app.collegato
        anchors.centerIn: parent
        width: parent.width - 60
        spacing: 14
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 84; height: 84; radius: 42; color: "#22c55e"
            Icona { anchors.centerIn: parent; nome: "find-location-symbolic"; lato: 42 }
        }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Dov'è"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(26); font.weight: Font.Bold }
        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: I18n.t("Accedi con il tuo Solid ID per vedere sulla mappa il telefono e il PC, farli suonare o bloccarli a distanza."); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(15) }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 220; height: 48; radius: 24; color: tel.accento
            Text { anchors.centerIn: parent; text: I18n.t("Accedi al Solid ID"); color: "#ffffff"; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.DemiBold }
            MouseArea { anchors.fill: parent; onClicked: { tel.appInterna = "impostazioni"; impostazioniApp.apri("solidid") } }
        }
    }

    // ══ Mappa ════════════════════════════════════════════════════════════
    Mappa {
        id: mappa
        visible: app.collegato
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: parent.height * 0.5
        lat: 41.9; lon: 12.49; zoom: 6
        segnaposti: app.dispositivi.filter(function (d) { return d.posizione }).map(function (d) {
            return { id: d.id, lat: d.lat, lon: d.lon, nome: d.nome, tipo: d.tipo, icona: d.icona, precisione: d.precisione, scelto: d.id === app.scelto }
        })
        onSegnapostoScelto: function (ident) { app.scegli(ident) }
    }
    // Titolo sopra la mappa
    Rectangle {
        visible: app.collegato
        x: 16; y: 52
        width: titolo.implicitWidth + 28; height: 40; radius: 20
        color: tel.chiaro ? Qt.rgba(1, 1, 1, 0.92) : Qt.rgba(0.11, 0.12, 0.17, 0.92)
        Text { id: titolo; anchors.centerIn: parent; text: I18n.t("Dov'è"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(18); font.weight: Font.Bold }
    }

    // ══ Pannello sotto la mappa ══════════════════════════════════════════
    Rectangle {
        visible: app.collegato
        anchors.left: parent.left; anchors.right: parent.right
        y: mappa.height - 22
        height: parent.height - y
        radius: 24
        color: app.color

        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 8; width: 40; height: 5; radius: 3; color: tel.pal.traccia }

        // ── Elenco dei dispositivi ───────────────────────────────────────
        Flickable {
            visible: app.dispositivo === null
            anchors.fill: parent; anchors.topMargin: 22; anchors.bottomMargin: 26
            contentHeight: elenco.height
            clip: true
            Column {
                id: elenco
                width: parent.width
                spacing: 10
                Text { x: 20; text: I18n.t("Dispositivi"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(20); font.weight: Font.Bold }
                Text { visible: app.errore !== ""; x: 20; width: parent.width - 40; wrapMode: Text.Wrap; text: app.errore; color: "#ef4444"; font.family: Tema.font; font.pixelSize: tel.px(13) }
                Text { visible: app.caricato && app.errore === "" && app.dispositivi.length === 0; x: 20; text: I18n.t("Nessun dispositivo collegato"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(14) }
                Rectangle {
                    visible: app.dispositivi.length > 0
                    x: 16; width: parent.width - 32; radius: 16
                    height: righe.height; color: app.sezione
                    Column {
                        id: righe
                        width: parent.width
                        Repeater {
                            model: app.dispositivi
                            Item {
                                required property var modelData
                                required property int index
                                width: righe.width; height: 66
                                Rectangle {
                                    x: 14; anchors.verticalCenter: parent.verticalCenter
                                    width: 42; height: 42; radius: 21; color: tel.pal.traccia
                                    IconaDispositivo { anchors.centerIn: parent; tipo: modelData.tipo; icona: modelData.icona; lato: 24; colore: tel.pal.testo }
                                }
                                Column {
                                    x: 68; anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 100
                                    spacing: 2
                                    Text { width: parent.width; elide: Text.ElideRight; text: modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.DemiBold }
                                    Text { width: parent.width; elide: Text.ElideRight; text: modelData.posizione ? modelData.stato : (modelData.stato + " · " + I18n.t("posizione sconosciuta")); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13) }
                                }
                                Text { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: "›"; color: tel.pal.testo2; font.pixelSize: 24 }
                                Rectangle { visible: index < app.dispositivi.length - 1; anchors.bottom: parent.bottom; x: 68; width: parent.width - 68; height: 1; color: app.linea }
                                MouseArea { anchors.fill: parent; onClicked: app.scegli(modelData.id) }
                            }
                        }
                    }
                }
            }
        }

        // ── Scheda del dispositivo scelto ────────────────────────────────
        Column {
            visible: app.dispositivo !== null
            x: 16; y: 22
            width: parent.width - 32
            spacing: 12
            Item {
                width: parent.width; height: 52
                Column {
                    width: parent.width - 50
                    spacing: 2
                    Text { width: parent.width; elide: Text.ElideRight; text: app.dispositivo ? app.dispositivo.nome : ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(22); font.weight: Font.Bold }
                    Text {
                        width: parent.width; elide: Text.ElideRight
                        text: !app.dispositivo ? "" : (app.dispositivo.posizione
                              ? app.dispositivo.stato + " · " + (app.dispositivo.fonte === "gps" ? "GPS" : "Wi-Fi") + " ±" + app.dispositivo.precisione + " m"
                              : app.dispositivo.stato)
                        color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13)
                    }
                }
                Rectangle {
                    anchors.right: parent.right; anchors.top: parent.top
                    width: 34; height: 34; radius: 17; color: tel.pal.traccia
                    Text { anchors.centerIn: parent; text: "×"; color: tel.pal.testo; font.pixelSize: 20 }
                    MouseArea { anchors.fill: parent; onClicked: app.scelto = "" }
                }
            }
            Text {
                visible: app.dispositivo !== null && app.dispositivo.bloccato === true
                text: I18n.t("Bloccato a distanza"); color: "#ef4444"; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold
            }
            Row {
                width: parent.width
                spacing: 10
                Repeater {
                    model: [{ k: "suona", t: I18n.t("Fai suonare"), i: "audio-volume-high-symbolic", c: "#3f7cf5" },
                            { k: "blocca", t: I18n.t("Blocca"), i: "system-lock-screen-symbolic", c: "#ef4444" },
                            { k: "strada", t: I18n.t("Indicazioni"), i: "mark-location-symbolic", c: "#22c55e" }]
                    Rectangle {
                        required property var modelData
                        readonly property bool attivo: !!app.dispositivo && !app.dispositivo.questo && (modelData.k !== "strada" || app.dispositivo.posizione)
                        width: (parent.width - 20) / 3; height: 86; radius: 18
                        color: app.sezione
                        opacity: attivo ? 1 : 0.4
                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 38; height: 38; radius: 19; color: parent.parent.modelData.c
                                Icona { anchors.centerIn: parent; nome: parent.parent.parent.modelData.i; lato: 20 }
                            }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.modelData.t; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                        }
                        MouseArea {
                            anchors.fill: parent; enabled: parent.attivo
                            onClicked: {
                                var k = parent.modelData.k
                                if (k === "suona") app.comando("suona")
                                else if (k === "blocca") bloccaDlg.open()
                                else ponte.chiama("indicazioni", [app.dispositivo.lat, app.dispositivo.lon])
                            }
                        }
                    }
                }
            }
            Text {
                visible: app.dispositivo !== null && app.dispositivo.questo === true
                width: parent.width; wrapMode: Text.Wrap
                text: I18n.t("È il telefono che hai in mano: da qui puoi far suonare o bloccare gli altri dispositivi.")
                color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12)
            }
            Text {
                visible: app.comandoId > 0
                text: I18n.t("In attesa di risposta dal dispositivo…"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13)
            }
        }
    }

    // ── Blocca con un messaggio ──────────────────────────────────────────
    Popup {
        id: bloccaDlg
        anchors.centerIn: parent
        width: parent.width - 40; modal: true; padding: 18
        background: Rectangle { radius: 20; color: app.sezione }
        onOpened: messaggio.text = ""
        Column {
            width: parent.width; spacing: 12
            Text { width: parent.width; wrapMode: Text.Wrap; text: I18n.t("Bloccare") + " «" + (app.dispositivo ? app.dispositivo.nome : "") + "»?"; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(17); font.weight: Font.Bold }
            Text { width: parent.width; wrapMode: Text.Wrap; text: I18n.t("Il messaggio comparirà sulla schermata di blocco, per chi lo trova."); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13) }
            CampoTesto { id: messaggio; width: parent.width; placeholderText: I18n.t("Es. Se lo trovi chiama il 333 …") }
            Row {
                spacing: 10; anchors.right: parent.right
                Pulsante { text: I18n.t("Annulla"); onClicked: bloccaDlg.close() }
                Pulsante { text: I18n.t("Blocca"); pericoloso: true; onClicked: { app.comando("blocca", messaggio.text); bloccaDlg.close() } }
            }
        }
    }
}
