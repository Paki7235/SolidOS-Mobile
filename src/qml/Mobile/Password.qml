// Password del telefono: lo stesso portachiavi cifrato del PC (nucleo/apps/password.py).
// Si apre con la password (la prima volta la si sceglie). Dentro: Tutte, Codici, Sicurezza
// (deboli, ripetute, trapelate) ed Eliminate, la ricerca, la scheda di ogni voce con Copia,
// Mostra, il codice di verifica che scorre e Modifica; + per aggiungere, con il generatore.
// Le password copiate si cancellano da sole dagli appunti.
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: app
    color: tel.pal.sfondo
    property var stato: ({ aperta: false })
    property string filtro: "tutte"
    property var voci: []
    property var conteggi: ({})
    property var voce: null                 // scheda aperta
    property var otp: ({})
    property bool mostra: false
    function pc(m, a) { return ponte.chiama("appPc", ["password", m, a || []]) }
    function aggiorna() {
        stato = pc("stato") || { aperta: false }
        if (stato.aperta) { voci = pc("elenco", [filtro, cerca.text]) || []; conteggi = pc("conteggi") || {} }
    }
    function apriVoce(id) { voce = pc("dettagli", [id]); mostra = false; otp = voce && voce.codice ? (pc("codice", [id]) || {}) : {} }
    onVisibleChanged: if (visible) aggiorna(); else { voce = null }
    Component.onCompleted: aggiorna()
    Timer { interval: 1000; running: app.visible && !!app.voce && !!app.voce.codice; repeat: true; onTriggered: app.otp = app.pc("codice", [app.voce.id]) || {} }
    function copia(campo, nome) { if (app.pc("copiaVoce", [app.voce.id, campo])) tel.avviso(nome + " " + I18n.t("copiato: si cancella dagli appunti tra poco")) }

    // ══ Lucchetto ═════════════════════════════════════════════════════════
    Column {
        visible: !app.stato.aperta
        anchors.centerIn: parent; width: parent.width - 60; spacing: 14
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 84; height: 84; radius: 26; color: tel.solido ? "#FFB443" : "#F59E0B"
                    Icona { anchors.centerIn: parent; nome: "linea-chiave"; lato: 42; colore: tel.solido ? "#141414" : "#FFFFFF" } }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Password"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 26; font.weight: Font.Bold }
        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 14
               text: app.stato.servePassword ? I18n.t("Scrivi la password del portachiavi per aprirlo.") : I18n.t("Scegli una password per proteggere il portachiavi. Le voci sono cifrate.") }
        CampoTesto { id: chiave; width: parent.width; echoMode: TextInput.Password; placeholderText: I18n.t("Password del portachiavi"); onAccepted: entra.clicked() }
        Pulsante {
            id: entra
            width: parent.width; text: I18n.t("Apri"); principale: true
            onClicked: { var r = app.pc("apri", [chiave.text]); chiave.text = ""; if (r && r.ok === false) tel.avviso(r.messaggio || I18n.t("Password sbagliata")); app.aggiorna() }
        }
    }

    // ══ Elenco ════════════════════════════════════════════════════════════
    Item {
        visible: app.stato.aperta === true && app.voce === null
        anchors.fill: parent
        Punti { x: 20; y: 60; text: I18n.t("Password") }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 16; y: 62; spacing: 8
            TastoTondo { icona: "linea-lucchetto"; onTocco: { app.pc("blocca"); app.aggiorna() } }
            TastoTondo { icona: "linea-piu"; pieno: true; onTocco: modulo.apri(null) }
        }
        CampoCerca { id: cerca; x: 16; y: 116; width: parent.width - 32; onTextChanged: app.aggiorna() }
        Row {
            x: 16; y: 168; spacing: 6
            Repeater {
                model: [{ k: "tutte", t: I18n.t("Tutte") }, { k: "codici", t: I18n.t("Codici") }, { k: "sicurezza", t: I18n.t("Sicurezza") }, { k: "eliminate", t: I18n.t("Eliminate") }]
                Rectangle {
                    required property var modelData
                    readonly property bool scelto: app.filtro === modelData.k
                    width: etF.implicitWidth + 24; height: 34; radius: 17
                    color: scelto ? (tel.solido ? "#C6F432" : tel.accento) : tel.pal.superficie
                    Text { id: etF; anchors.centerIn: parent; text: parent.modelData.t + " " + (app.conteggi[parent.modelData.k] || 0)
                           color: parent.scelto ? (tel.solido ? "#141414" : "#FFFFFF") : (parent.modelData.k === "sicurezza" && app.conteggi.sicurezza ? tel.rosso : tel.pal.testo)
                           font.family: Tema.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; onClicked: { app.filtro = parent.modelData.k; app.aggiorna() } }
                }
            }
        }
        ListView {
            id: elenco
            x: 8; y: 214; width: parent.width - 16; height: parent.height - y - 30; clip: true
            model: app.voci
            delegate: Item {
                required property var modelData
                width: elenco.width; height: 64
                Avatar { x: 10; anchors.verticalCenter: parent.verticalCenter; lato: 42; nome: modelData.titolo }
                Column { x: 64; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 110
                         Text { width: parent.width; elide: Text.ElideRight; text: modelData.titolo; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.DemiBold }
                         Text { width: parent.width; elide: Text.ElideRight; text: modelData.eliminata ? I18n.t("si cancella tra") + " " + modelData.giorniRimasti + " " + I18n.t("giorni") : modelData.utente
                                color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 13 } }
                Icona { visible: modelData.problemi.length > 0; anchors.right: parent.right; anchors.rightMargin: 34; anchors.verticalCenter: parent.verticalCenter; nome: "linea-attenzione"; lato: 18; colore: tel.rosso }
                Icona { visible: modelData.codice; anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; nome: "linea-orologio"; lato: 16; colore: tel.pal.testo2 }
                Rectangle { x: 64; anchors.bottom: parent.bottom; width: parent.width - 64; height: 1; color: tel.pal.bordo }
                MouseArea { anchors.fill: parent; onClicked: app.apriVoce(modelData.id) }
            }
            Text { anchors.centerIn: parent; visible: elenco.count === 0; text: app.filtro === "tutte" ? I18n.t("Nessuna password: premi + per aggiungerne una") : I18n.t("Niente qui"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 15 }
        }
    }

    // ══ Scheda di una voce ════════════════════════════════════════════════
    Flickable {
        visible: app.stato.aperta === true && app.voce !== null
        anchors.fill: parent; anchors.topMargin: 54; contentHeight: sch.height + 40; clip: true
        Column {
            id: sch
            x: 16; width: parent.width - 32; spacing: 12
            Item { width: parent.width; height: 40
                   Text { anchors.verticalCenter: parent.verticalCenter; text: "‹ " + I18n.t("Password"); color: tel.accento; font.family: Tema.font; font.pixelSize: 16
                          MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: { app.voce = null; app.aggiorna() } } }
                   Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; visible: app.voce && !app.voce.eliminata; text: I18n.t("Modifica"); color: tel.accento; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.DemiBold
                          MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: modulo.apri(app.voce) } } }
            Row { spacing: 14
                  Avatar { lato: 60; nome: app.voce ? app.voce.titolo : "" }
                  Column { anchors.verticalCenter: parent.verticalCenter
                           Text { text: app.voce ? app.voce.titolo : ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 24; font.weight: Font.Bold }
                           Text { text: app.voce ? I18n.t("Modificata il") + " " + app.voce.quando : ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 13 } } }
            Rectangle {
                width: parent.width; height: campi.height; radius: 20; color: tel.pal.superficie
                Column {
                    id: campi
                    width: parent.width
                    Repeater {
                        model: !app.voce ? [] : [{ k: "utente", t: I18n.t("Nome utente"), v: app.voce.utente },
                                                 { k: "password", t: I18n.t("Password"), v: app.mostra ? app.voce.password : "••••••••••", f: app.voce.forza ? app.voce.forza.testo : "" },
                                                 { k: "sito", t: I18n.t("Sito"), v: app.voce.sito }].filter(function (c) { return c.v })
                        Item {
                            required property var modelData
                            required property int index
                            width: campi.width; height: 66
                            Column { x: 16; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 120
                                     Text { text: modelData.t + (modelData.f ? " · " + modelData.f : ""); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 13 }
                                     Text { width: parent.width; elide: Text.ElideRight; text: modelData.v; color: modelData.k === "sito" ? tel.accento : tel.pal.testo; font.family: Tema.font; font.pixelSize: 17 } }
                            Row { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                                  TastoTondo { visible: modelData.k === "password"; lato: 36; icona: app.mostra ? "linea-occhio-chiuso" : "linea-occhio"; color: "transparent"; onTocco: app.mostra = !app.mostra }
                                  TastoTondo { lato: 36; icona: "linea-copia"; color: "transparent"; onTocco: app.copia(modelData.k, modelData.t) } }
                            Rectangle { visible: index > 0; x: 16; width: parent.width - 16; height: 1; color: tel.pal.bordo }
                            MouseArea { visible: modelData.k === "sito"; anchors.fill: parent; anchors.rightMargin: 60; onClicked: app.pc("apriSito", [app.voce.sito]) }
                        }
                    }
                }
            }
            // Codice di verifica (si rinnova da solo)
            Rectangle {
                visible: !!app.otp.codice
                width: parent.width; height: 76; radius: 20; color: tel.pal.superficie
                Column { x: 16; anchors.verticalCenter: parent.verticalCenter
                         Text { text: I18n.t("Codice di verifica"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 13 }
                         Text { text: (app.otp.codice || "").replace(/(\d{3})(\d{3})/, "$1 $2"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 26; font.weight: Font.DemiBold; font.letterSpacing: 2 } }
                Text { anchors.right: parent.right; anchors.rightMargin: 60; anchors.verticalCenter: parent.verticalCenter; text: app.otp.resto || ""; color: (app.otp.resto || 30) <= 5 ? tel.rosso : tel.pal.testo2; font.family: Tema.font; font.pixelSize: 15 }
                TastoTondo { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; lato: 36; icona: "linea-copia"; color: "transparent"; onTocco: app.copia("codice", I18n.t("Codice")) }
            }
            // Avvisi di sicurezza
            Repeater {
                model: app.voce ? app.voce.problemi : []
                Rectangle { required property var modelData; width: sch.width; height: 48; radius: 14; color: Qt.rgba(0.9, 0.28, 0.3, 0.14)
                            Row { x: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                                  Icona { nome: "linea-attenzione"; lato: 18; colore: tel.rosso }
                                  Text { text: typeof parent.parent.modelData === "string" ? parent.parent.modelData : (parent.parent.modelData.testo || ""); color: tel.rosso; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.DemiBold } } }
            }
            Rectangle { visible: !!app.voce && !!app.voce.note; width: parent.width; height: noteT.implicitHeight + 28; radius: 20; color: tel.pal.superficie
                        Text { id: noteT; x: 16; y: 14; width: parent.width - 32; wrapMode: Text.Wrap; text: app.voce ? app.voce.note : ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 15 } }
            Pulsante { visible: !!app.voce && !app.voce.eliminata; width: parent.width; text: I18n.t("Elimina"); pericoloso: true
                       onClicked: { app.pc("elimina", [app.voce.id, false]); app.voce = null; app.aggiorna(); tel.avviso(I18n.t("Spostata in Eliminate")) } }
            Pulsante { visible: !!app.voce && !!app.voce.eliminata; width: parent.width; text: I18n.t("Ripristina"); principale: true
                       onClicked: { app.pc("ripristina", [app.voce.id]); app.voce = null; app.aggiorna() } }
            Pulsante { visible: !!app.voce && !!app.voce.eliminata; width: parent.width; text: I18n.t("Elimina per sempre"); pericoloso: true
                       onClicked: { app.pc("elimina", [app.voce.id, true]); app.voce = null; app.aggiorna() } }
        }
    }

    // ══ Nuova voce / modifica ═════════════════════════════════════════════
    Rectangle {
        id: modulo
        anchors.fill: parent; visible: false; color: tel.pal.sfondo
        property var v: null
        function apri(x) { v = x; titoloP.text = x ? x.titolo : ""; sitoP.text = x ? x.sito : ""; utenteP.text = x ? x.utente : ""; passP.text = x ? x.password : ""
                           codiceP.text = x ? (x.codice || "") : ""; noteP.text = x ? x.note : ""; visible = true }
        MouseArea { anchors.fill: parent }
        Text { x: 20; y: 64; text: I18n.t("Annulla"); color: tel.accento; font.family: Tema.font; font.pixelSize: 16
               MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: modulo.visible = false } }
        Text { anchors.right: parent.right; anchors.rightMargin: 20; y: 64; text: I18n.t("Salva"); color: tel.accento; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.Bold
               MouseArea { anchors.fill: parent; anchors.margins: -10
                           onClicked: { var r = app.pc("salva", [{ id: modulo.v ? modulo.v.id : "", titolo: titoloP.text, sito: sitoP.text, utente: utenteP.text, password: passP.text, codice: codiceP.text, note: noteP.text }])
                                        if (r && r.ok === false) { tel.avviso(r.messaggio || ""); return }
                                        modulo.visible = false; app.aggiorna(); if (r && r.id) app.apriVoce(r.id) } } }
        Column {
            x: 16; y: 110; width: parent.width - 32; spacing: 10
            CampoTesto { id: titoloP; width: parent.width; placeholderText: I18n.t("Nome (es. Banca)") }
            CampoTesto { id: sitoP; width: parent.width; placeholderText: I18n.t("Sito (es. banca.it)"); inputMethodHints: Qt.ImhUrlCharactersOnly }
            CampoTesto { id: utenteP; width: parent.width; placeholderText: I18n.t("Nome utente o email"); inputMethodHints: Qt.ImhNoAutoUppercase }
            Row { spacing: 8
                  CampoTesto { id: passP; width: modulo.width - 32 - 108; placeholderText: I18n.t("Password"); inputMethodHints: Qt.ImhNoAutoUppercase }
                  Pulsante { width: 100; text: I18n.t("Genera"); onClicked: passP.text = app.pc("genera", ["robusta", 20]) } }
            Text {
                visible: passP.text !== ""
                text: I18n.t("Sicurezza") + ": " + ((app.pc("forza", [passP.text]) || {}).testo || "")
                color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 13
            }
            CampoTesto { id: codiceP; width: parent.width; placeholderText: I18n.t("Chiave del codice di verifica (facoltativa)"); inputMethodHints: Qt.ImhNoAutoUppercase }
            CampoTesto { id: noteP; width: parent.width; placeholderText: I18n.t("Note") }
        }
    }
}
