// Orologio del telefono: stessa logica del PC (nucleo/apps/orologio.py). Quattro schede in
// basso: Ora nel mondo, Sveglie (con i giorni), Cronometro (con i giri) e Timer (con l'anello).
// Sveglie e timer suonano anche ad app chiusa: li controlla la shell (controllaOrologio).
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: app
    color: tel.pal.sfondo
    property string scheda: "sveglie"
    property var mondo: []
    property var sveglie: []
    property var timer: ({ attivo: false })
    property bool aggiungiCitta: false
    property var trovate: []
    function pc(m, a) { return ponte.chiama("appPc", ["orologio", m, a || []]) }
    function aggiorna() { mondo = pc("mondo") || []; sveglie = pc("sveglie") || []; timer = pc("timer") || { attivo: false } }
    onVisibleChanged: if (visible) aggiorna()
    Component.onCompleted: aggiorna()
    Timer { interval: 1000; running: app.visible; repeat: true; onTriggered: { app.timer = app.pc("timer") || { attivo: false }; if (app.scheda === "mondo") app.mondo = app.pc("mondo") || [] } }
    function dueCifre(n) { return ("0" + n).slice(-2) }
    function testoTempo(s) { s = Math.max(0, Math.ceil(s)); var h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60); return (h ? h + ":" + dueCifre(m) : m) + ":" + dueCifre(s % 60) }

    Punti { x: 20; y: 60; text: ({ mondo: I18n.t("Ora nel mondo"), sveglie: I18n.t("Sveglie"), cronometro: I18n.t("Cronometro"), timer: I18n.t("Timer") })[app.scheda] }
    TastoTondo {
        visible: app.scheda === "mondo" || app.scheda === "sveglie"
        anchors.right: parent.right; anchors.rightMargin: 18; y: 62; icona: "linea-piu"
        onTocco: app.scheda === "mondo" ? (app.aggiungiCitta = true, campoCitta.text = "", app.trovate = []) : modSveglia.apri(null)
    }

    // ── Ora nel mondo ─────────────────────────────────────────────────────
    ListView {
        visible: app.scheda === "mondo"
        anchors.fill: parent; anchors.topMargin: 116; anchors.bottomMargin: 92
        clip: true; model: app.mondo
        delegate: Item {
            required property var modelData
            width: ListView.view.width; height: 84
            Column { x: 20; anchors.verticalCenter: parent.verticalCenter
                     Text { text: modelData.giorno + ", " + modelData.differenza; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 13 }
                     Text { text: modelData.citta; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 22; font.weight: Font.DemiBold } }
            Text { anchors.right: parent.right; anchors.rightMargin: 56; anchors.verticalCenter: parent.verticalCenter; text: modelData.ora; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 44; font.weight: Font.Light }
            Icona { anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter; nome: modelData.notte ? "linea-luna" : "linea-sole"; lato: 22; colore: modelData.notte ? "#A78BFA" : "#F59E0B" }
            Rectangle { x: 20; anchors.bottom: parent.bottom; width: parent.width - 40; height: 1; color: tel.pal.bordo }
            MouseArea { anchors.fill: parent; onPressAndHold: { app.pc("togliCitta", [modelData.citta]); app.aggiorna(); tel.avviso(modelData.citta + ": " + I18n.t("tolta")) } }
        }
        Text { anchors.centerIn: parent; visible: parent.count === 0; text: I18n.t("Premi + per aggiungere una città"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 15 }
    }

    // ── Sveglie ───────────────────────────────────────────────────────────
    ListView {
        visible: app.scheda === "sveglie"
        anchors.fill: parent; anchors.topMargin: 116; anchors.bottomMargin: 92
        clip: true; model: app.sveglie
        delegate: Item {
            required property var modelData
            width: ListView.view.width; height: 96
            Column {
                x: 20; anchors.verticalCenter: parent.verticalCenter
                opacity: modelData.attiva ? 1 : 0.45
                Text { text: modelData.ora; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 52; font.weight: Font.Light }
                Text { text: (modelData.etichetta ? modelData.etichetta + " · " : "") + modelData.ripeti; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 14 }
            }
            Interruttore { anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter
                           checked: modelData.attiva; onToggled: { app.pc("attivaSveglia", [modelData.id, checked]); app.aggiorna() } }
            Rectangle { x: 20; anchors.bottom: parent.bottom; width: parent.width - 40; height: 1; color: tel.pal.bordo }
            MouseArea { anchors.fill: parent; anchors.rightMargin: 90; onClicked: modSveglia.apri(modelData) }
        }
        Text { anchors.centerIn: parent; visible: parent.count === 0; text: I18n.t("Nessuna sveglia: premi + per aggiungerne una"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 15 }
    }

    // ── Cronometro ────────────────────────────────────────────────────────
    Item {
        id: crono
        visible: app.scheda === "cronometro"
        anchors.fill: parent; anchors.topMargin: 116; anchors.bottomMargin: 92
        property real base: 0          // ms accumulati prima dell'ultimo avvio
        property real partito: 0       // Date.now() dell'ultimo avvio (0 = fermo)
        property real ora: 0
        property var giri: []
        readonly property real totale: base + (partito ? ora - partito : 0)
        function testo(ms) { var c = Math.floor(ms / 10) % 100, s = Math.floor(ms / 1000); return app.dueCifre(Math.floor(s / 60)) + ":" + app.dueCifre(s % 60) + "," + app.dueCifre(c) }
        Timer { interval: 30; running: crono.partito > 0; repeat: true; onTriggered: crono.ora = Date.now() }
        Text { anchors.horizontalCenter: parent.horizontalCenter; y: 40; text: crono.testo(crono.totale); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 72; font.weight: Font.Light }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter; y: 170; spacing: parent.width - 2 * 84 - 60
            Rectangle { width: 84; height: 84; radius: 42; color: tel.pal.superficie2
                        Text { anchors.centerIn: parent; text: crono.partito ? I18n.t("Giro") : I18n.t("Azzera"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.DemiBold }
                        MouseArea { anchors.fill: parent; onClicked: { if (crono.partito) crono.giri = [crono.totale].concat(crono.giri); else { crono.base = 0; crono.giri = [] } } } }
            Rectangle { width: 84; height: 84; radius: 42; color: crono.partito ? "#E5484D" : tel.coloreChiama
                        Text { anchors.centerIn: parent; text: crono.partito ? I18n.t("Ferma") : I18n.t("Avvia"); color: !crono.partito && tel.solido ? "#141414" : "#FFFFFF"; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.Bold }
                        MouseArea { anchors.fill: parent; onClicked: { if (crono.partito) { crono.base = crono.totale; crono.partito = 0 } else { crono.ora = Date.now(); crono.partito = crono.ora } } } }
        }
        ListView {
            x: 20; y: 280; width: parent.width - 40; height: parent.height - 280; clip: true
            model: crono.giri
            delegate: Item {
                required property real modelData
                required property int index
                width: ListView.view.width; height: 46
                Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Giro") + " " + (crono.giri.length - index); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 16 }
                Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: crono.testo(modelData - (index + 1 < crono.giri.length ? crono.giri[index + 1] : 0)); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 16 }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: tel.pal.bordo }
            }
        }
    }

    // ── Timer ─────────────────────────────────────────────────────────────
    Item {
        visible: app.scheda === "timer"
        anchors.fill: parent; anchors.topMargin: 116; anchors.bottomMargin: 92
        // Anello che si svuota
        Canvas {
            id: anello
            visible: app.timer.attivo === true
            anchors.horizontalCenter: parent.horizontalCenter; y: 20; width: 280; height: 280
            property real frazione: app.timer.attivo ? app.timer.resto / Math.max(1, app.timer.durata) : 0
            onFrazioneChanged: requestPaint()
            onPaint: { var g = getContext("2d"); g.reset(); g.lineWidth = 10; g.lineCap = "round"
                       g.strokeStyle = tel.pal.traccia; g.beginPath(); g.arc(140, 140, 130, 0, 2 * Math.PI); g.stroke()
                       g.strokeStyle = tel.solido ? "#FFB443" : String(tel.accento); g.beginPath(); g.arc(140, 140, 130, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * frazione); g.stroke() }
            Column { anchors.centerIn: parent
                     Text { anchors.horizontalCenter: parent.horizontalCenter; text: app.testoTempo(app.timer.resto || 0); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 58; font.weight: Font.Light }
                     Text { anchors.horizontalCenter: parent.horizontalCenter; text: app.timer.etichetta || ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 15 } }
        }
        // Scelta della durata (ore, minuti, secondi) quando il timer è fermo
        Row {
            visible: !app.timer.attivo
            anchors.horizontalCenter: parent.horizontalCenter; y: 40; spacing: 10
            Repeater {
                model: [{ t: I18n.t("ore"), max: 24 }, { t: I18n.t("min"), max: 60 }, { t: I18n.t("sec"), max: 60 }]
                Column {
                    required property var modelData
                    required property int index
                    spacing: 4
                    Tumbler { id: rullo; width: 88; height: 200; model: modelData.max; visibleItemCount: 5; currentIndex: index === 1 ? 5 : 0
                              Component.onCompleted: sceltaTimer.rulli[index] = rullo
                              delegate: Text { required property int index; required property var modelData; text: index; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                               color: tel.pal.testo; opacity: 1.0 - Math.abs(Tumbler.displacement) / 3; font.family: Tema.font; font.pixelSize: 30 } }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.t; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 14 }
                }
            }
        }
        QtObject { id: sceltaTimer; property var rulli: [null, null, null]
                   function secondi() { return (rulli[0] ? rulli[0].currentIndex : 0) * 3600 + (rulli[1] ? rulli[1].currentIndex : 0) * 60 + (rulli[2] ? rulli[2].currentIndex : 0) } }
        CampoTesto { id: etichettaTimer; visible: !app.timer.attivo; x: 40; y: 270; width: parent.width - 80; placeholderText: I18n.t("Etichetta (facoltativa)") }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter; y: 340; spacing: parent.width - 2 * 84 - 60
            Rectangle { width: 84; height: 84; radius: 42; color: tel.pal.superficie2; opacity: app.timer.attivo ? 1 : 0.4
                        Text { anchors.centerIn: parent; text: I18n.t("Annulla"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.DemiBold }
                        MouseArea { anchors.fill: parent; enabled: app.timer.attivo === true; onClicked: app.timer = app.pc("fermaTimer") || { attivo: false } } }
            Rectangle { width: 84; height: 84; radius: 42; color: app.timer.attivo && !app.timer.inPausa ? "#FFB443" : tel.coloreChiama
                        Text { anchors.centerIn: parent; text: !app.timer.attivo ? I18n.t("Avvia") : (app.timer.inPausa ? I18n.t("Riprendi") : I18n.t("Pausa"))
                               color: tel.solido || (app.timer.attivo && !app.timer.inPausa) ? "#141414" : "#FFFFFF"; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.Bold }
                        MouseArea { anchors.fill: parent
                                    onClicked: {
                                        if (!app.timer.attivo) { var s = sceltaTimer.secondi(); if (s > 0) app.timer = app.pc("avviaTimer", [s, etichettaTimer.text]); else tel.avviso(I18n.t("Scegli quanto tempo")) }
                                        else app.timer = app.pc("pausaTimer", [!app.timer.inPausa])
                                    } } }
        }
    }

    // ── Schede in basso ──────────────────────────────────────────────────
    Rectangle {
        anchors.bottom: parent.bottom; width: parent.width; height: 84; color: tel.pal.sfondo
        Rectangle { width: parent.width; height: 1; color: tel.pal.bordo; visible: !tel.solido }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter; y: 8
            Repeater {
                model: [{ s: "mondo", t: I18n.t("Mondo"), i: "linea-globo" }, { s: "sveglie", t: I18n.t("Sveglie"), i: "linea-sveglia" },
                        { s: "cronometro", t: I18n.t("Cronometro"), i: "linea-cronometro" }, { s: "timer", t: I18n.t("Timer"), i: "linea-clessidra" }]
                Item {
                    id: tabO
                    required property var modelData
                    readonly property bool attiva: app.scheda === modelData.s
                    width: (app.width - 20) / 4; height: 50
                    PillolaScheda { attiva: tabO.attiva }
                    Column { anchors.centerIn: parent; spacing: 3; opacity: tabO.attiva ? 1 : 0.55
                             Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: tabO.modelData.i; lato: 22; colore: tabO.attiva && tel.solido ? "#141414" : tel.pal.testo }
                             Text { anchors.horizontalCenter: parent.horizontalCenter; text: tabO.modelData.t; color: tabO.attiva && !tel.solido ? tel.accento : tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(11); font.weight: tabO.attiva ? Font.Bold : Font.DemiBold } }
                    MouseArea { anchors.fill: parent; onClicked: { app.scheda = tabO.modelData.s; app.aggiorna() } }
                }
            }
        }
    }

    // ── Nuova sveglia / modifica ─────────────────────────────────────────
    Rectangle {
        id: modSveglia
        anchors.fill: parent; visible: false; color: tel.pal.sfondo
        property var sv: null
        property var giorni: []
        function apri(s) {
            sv = s; giorni = s ? (s.giorni || []).slice() : []
            var p = (s ? s.ora : "07:00").split(":")
            oraS.currentIndex = parseInt(p[0]); minS.currentIndex = parseInt(p[1])
            etichettaS.text = s ? (s.etichetta || "") : ""
            visible = true
        }
        MouseArea { anchors.fill: parent }
        Text { x: 20; y: 64; text: I18n.t("Annulla"); color: tel.accento; font.family: Tema.font; font.pixelSize: 16
               MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: modSveglia.visible = false } }
        Text { anchors.horizontalCenter: parent.horizontalCenter; y: 64; text: modSveglia.sv ? I18n.t("Modifica sveglia") : I18n.t("Nuova sveglia"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.Bold }
        Text { anchors.right: parent.right; anchors.rightMargin: 20; y: 64; text: I18n.t("Salva"); color: tel.accento; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.Bold
               MouseArea { anchors.fill: parent; anchors.margins: -10
                           onClicked: { app.pc("salvaSveglia", [{ id: modSveglia.sv ? modSveglia.sv.id : "", ora: app.dueCifre(oraS.currentIndex) + ":" + app.dueCifre(minS.currentIndex),
                                                                  etichetta: etichettaS.text, giorni: modSveglia.giorni, attiva: true }]); modSveglia.visible = false; app.aggiorna() } } }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter; y: 110; spacing: 8
            Tumbler { id: oraS; width: 100; height: 220; model: 24; visibleItemCount: 5
                      delegate: Text { required property int index; text: app.dueCifre(index); horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; color: tel.pal.testo; opacity: 1.0 - Math.abs(Tumbler.displacement) / 3; font.family: Tema.font; font.pixelSize: 40; font.weight: Font.Light } }
            Text { anchors.verticalCenter: parent.verticalCenter; text: ":"; color: tel.pal.testo; font.pixelSize: 40 }
            Tumbler { id: minS; width: 100; height: 220; model: 60; visibleItemCount: 5
                      delegate: Text { required property int index; text: app.dueCifre(index); horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; color: tel.pal.testo; opacity: 1.0 - Math.abs(Tumbler.displacement) / 3; font.family: Tema.font; font.pixelSize: 40; font.weight: Font.Light } }
        }
        Column {
            x: 16; y: 350; width: parent.width - 32; spacing: 14
            Text { text: I18n.t("Ripeti"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.DemiBold }
            Row {
                spacing: 6
                Repeater {
                    model: ["L", "M", "M", "G", "V", "S", "D"]
                    Rectangle {
                        required property string modelData
                        required property int index
                        readonly property bool scelto: modSveglia.giorni.indexOf(index) >= 0
                        width: (modSveglia.width - 32 - 36) / 7; height: width; radius: width / 2
                        color: scelto ? (tel.solido ? "#C6F432" : tel.accento) : tel.pal.superficie
                        Text { anchors.centerIn: parent; text: parent.modelData; color: parent.scelto ? (tel.solido ? "#141414" : "#FFFFFF") : tel.pal.testo; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.Bold }
                        MouseArea { anchors.fill: parent; onClicked: { var g = modSveglia.giorni.slice(), i = g.indexOf(parent.index); if (i >= 0) g.splice(i, 1); else g.push(parent.index); modSveglia.giorni = g } }
                    }
                }
            }
            CampoTesto { id: etichettaS; width: parent.width; placeholderText: I18n.t("Etichetta") }
            Pulsante { visible: modSveglia.sv !== null; width: parent.width; text: I18n.t("Elimina sveglia"); pericoloso: true
                       onClicked: { app.pc("togliSveglia", [modSveglia.sv.id]); modSveglia.visible = false; app.aggiorna() } }
        }
    }

    // ── Aggiungi una città ───────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent; visible: app.aggiungiCitta; color: tel.pal.sfondo
        MouseArea { anchors.fill: parent }
        Punti { x: 20; y: 60; text: I18n.t("Scegli una città") }
        Text { anchors.right: parent.right; anchors.rightMargin: 20; y: 72; text: I18n.t("Fine"); color: tel.accento; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.DemiBold
               MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: app.aggiungiCitta = false } }
        CampoCerca { id: campoCitta; x: 16; y: 118; width: parent.width - 32; onTextChanged: app.trovate = app.pc("citta", [text]) || [] }
        ListView {
            x: 16; y: 176; width: parent.width - 32; height: parent.height - 200; clip: true
            model: app.trovate
            delegate: Item {
                required property string modelData
                width: ListView.view.width; height: 50
                Text { anchors.verticalCenter: parent.verticalCenter; text: modelData; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 17 }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: tel.pal.bordo }
                MouseArea { anchors.fill: parent; onClicked: { app.pc("aggiungiCitta", [modelData]); app.aggiungiCitta = false; app.aggiorna() } }
            }
        }
    }
}
