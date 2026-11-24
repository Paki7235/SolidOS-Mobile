// Mail del telefono: gli stessi account e la stessa posta del PC (nucleo/apps/mail.py, IMAP e
// SMTP). Entrata di tutti gli account insieme (o di uno solo), ricerca, aggiorna scorrendo; il
// messaggio aperto con Rispondi, Rispondi a tutti, Inoltra ed Elimina; la matita per scrivere.
// Senza account: si aggiunge con email e password (i server si trovano da soli).
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: app
    color: tel.pal.sfondo
    property var conti: []
    property string conto: ""                 // "" = tutte le Entrate
    property var messaggi: []
    property var aperto: null
    property bool caricando: false
    property bool scrivi: false
    property bool nuovoConto: false
    function pc(m, a) { return ponte.chiama("appPc", ["mail", m, a || []]) }
    function elenco() { messaggi = pc("messaggi", [conto, conto ? "INBOX" : "", cerca.text, false]) || [] }
    function sincronizza() { caricando = true; ponte.avvia("appPc", ["mail", "aggiorna", [conto, "INBOX"]], "mail-aggiorna") }
    function carica() { conti = pc("conti") || []; if (conti.length) { elenco(); sincronizza() } }
    onVisibleChanged: if (visible && !conti.length) carica()
    Component.onCompleted: carica()
    Connections {
        target: ponte
        function onCompletato(id, r) {
            if (id === "mail-aggiorna") { app.caricando = false; app.elenco(); if (r && r.ok === false && r.messaggio) tel.avviso(r.messaggio) }
            else if (id === "mail-apri") { app.aperto = r && r.ok ? r : null; if (r && r.ok === false) tel.avviso(r.messaggio); app.elenco() }
        }
    }
    function apri(m) { ponte.avvia("appPc", ["mail", "apri", [m.conto, m.cartella, m.uid, false, !tel.chiaro]], "mail-apri") }
    function bozza(tipo) {
        var b = pc("bozza", [aperto.conto, aperto.cartella, aperto.uid, tipo]) || {}
        composizione.apri(b)
    }

    // ══ Nessun account ════════════════════════════════════════════════════
    Column {
        visible: app.conti.length === 0 && !app.nuovoConto
        anchors.centerIn: parent; width: parent.width - 60; spacing: 14
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 84; height: 84; radius: 26; color: tel.solido ? "#59C3FF" : "#3B82F6"
                    Icona { anchors.centerIn: parent; nome: "linea-busta"; lato: 42; colore: tel.solido ? "#141414" : "#FFFFFF" } }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Mail"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 26; font.weight: Font.Bold }
        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 14
               text: I18n.t("Aggiungi il tuo account di posta: Gmail, Outlook, Libero, Aruba, iCloud e gli altri. Gli account aggiunti sul PC ci sono già.") }
        Pulsante { width: parent.width; text: I18n.t("Aggiungi un account"); principale: true; onClicked: app.nuovoConto = true }
    }

    // ══ Entrata ═══════════════════════════════════════════════════════════
    Item {
        visible: app.conti.length > 0 && app.aperto === null
        anchors.fill: parent
        Punti { x: 20; y: 60; text: I18n.t("Entrata") }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 16; y: 62; spacing: 8
            TastoTondo { icona: "linea-piu"; onTocco: app.nuovoConto = true }
            TastoTondo { icona: "linea-matita"; pieno: true; onTocco: composizione.apri({}) }
        }
        CampoCerca { id: cerca; x: 16; y: 116; width: parent.width - 32; onTextChanged: app.elenco() }
        // Account: Tutte o uno solo
        ListView {
            x: 16; y: 166; width: parent.width - 32; height: 34; orientation: ListView.Horizontal; spacing: 6; clip: true
            visible: app.conti.length > 1
            model: [{ id: "", email: I18n.t("Tutte"), nonlette: 0 }].concat(app.conti)
            delegate: Rectangle {
                required property var modelData
                readonly property bool scelto: app.conto === modelData.id
                width: etC.implicitWidth + 24; height: 34; radius: 17; color: scelto ? (tel.solido ? "#C6F432" : tel.accento) : tel.pal.superficie
                Text { id: etC; anchors.centerIn: parent; text: parent.modelData.email + (parent.modelData.nonlette ? " · " + parent.modelData.nonlette : ""); color: parent.scelto ? (tel.solido ? "#141414" : "#FFFFFF") : tel.pal.testo; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                MouseArea { anchors.fill: parent; onClicked: { app.conto = parent.modelData.id; app.elenco() } }
            }
        }
        ListView {
            id: lista
            x: 0; y: app.conti.length > 1 ? 208 : 168; width: parent.width; height: parent.height - y - 20; clip: true
            model: app.messaggi
            header: Item { width: lista.width; height: app.caricando ? 40 : 0; visible: app.caricando
                           BusyIndicator { anchors.centerIn: parent; width: 26; height: 26; running: app.caricando } }
            onContentYChanged: if (contentY < -90 && !app.caricando) app.sincronizza()
            delegate: Item {
                required property var modelData
                width: lista.width; height: 92
                Rectangle { visible: !modelData.letto; x: 8; y: 20; width: 10; height: 10; radius: 5; color: tel.accento }
                Column {
                    x: 26; y: 12; width: parent.width - 42; spacing: 2
                    Item { width: parent.width; height: 22
                           Text { width: parent.width - 70; elide: Text.ElideRight; text: modelData.da; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 16; font.weight: modelData.letto ? Font.DemiBold : Font.Bold }
                           Text { anchors.right: parent.right; text: modelData.quando; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 12 } }
                    Text { width: parent.width; elide: Text.ElideRight; text: modelData.oggetto; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 14 }
                    Text { width: parent.width; elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap; text: modelData.anteprima; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 13 }
                }
                Rectangle { x: 26; anchors.bottom: parent.bottom; width: parent.width - 26; height: 1; color: tel.pal.bordo }
                MouseArea { anchors.fill: parent; onClicked: app.apri(modelData) }
            }
            Text { anchors.centerIn: parent; visible: lista.count === 0 && !app.caricando; text: I18n.t("Nessun messaggio"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 15 }
        }
    }

    // ══ Messaggio aperto ══════════════════════════════════════════════════
    Item {
        visible: app.aperto !== null
        anchors.fill: parent
        Text { x: 18; y: 60; text: "‹ " + I18n.t("Entrata"); color: tel.accento; font.family: Tema.font; font.pixelSize: 16
               MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: app.aperto = null } }
        Column {
            x: 16; y: 92; width: parent.width - 32; spacing: 4
            Text { width: parent.width; wrapMode: Text.Wrap; text: app.aperto ? app.aperto.oggetto : ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 21; font.weight: Font.Bold }
            Row { spacing: 10; topPadding: 6
                  Avatar { lato: 40; nome: app.aperto ? app.aperto.daNome : "" }
                  Column { anchors.verticalCenter: parent.verticalCenter
                           Text { text: app.aperto ? app.aperto.daNome : ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.DemiBold }
                           Text { text: app.aperto ? I18n.t("A") + ": " + app.aperto.a + " · " + app.aperto.quando : ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 12; width: app.width - 100; elide: Text.ElideRight } } }
        }
        Loader {
            id: vista
            x: 0; y: 190; width: parent.width; height: parent.height - y - 90
            source: "MailVista.qml"
            onLoaded: item.link.connect(function (u) { app.pc("apriLink", [u]) })
            Binding { target: vista.item; property: "html"; value: app.aperto ? (app.aperto.html || "") : ""; when: vista.status === Loader.Ready }
        }
        // Senza motore web: il testo del messaggio
        Flickable {
            visible: vista.status === Loader.Error
            x: 16; y: 190; width: parent.width - 32; height: parent.height - y - 90; contentHeight: semplice.implicitHeight; clip: true
            Text { id: semplice; width: parent.width; wrapMode: Text.Wrap; textFormat: Text.RichText; text: app.aperto ? (app.aperto.html || "") : ""
                   color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 15; onLinkActivated: function (u) { app.pc("apriLink", [u]) } }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 30; spacing: 22
            TastoTondo { lato: 48; icona: "linea-cestino"; onTocco: { app.pc("elimina", [app.aperto.conto, app.aperto.cartella, app.aperto.uid]); app.aperto = null; app.elenco(); tel.avviso(I18n.t("Messaggio eliminato")) } }
            TastoTondo { lato: 48; icona: "linea-rispondi"; onTocco: app.bozza("rispondi") }
            TastoTondo { lato: 48; icona: "linea-rispondi-tutti"; onTocco: app.bozza("tutti") }
            TastoTondo { lato: 48; icona: "linea-inoltra"; onTocco: app.bozza("inoltra") }
        }
    }

    // ══ Scrivi ════════════════════════════════════════════════════════════
    Rectangle {
        id: composizione
        anchors.fill: parent; visible: false; color: tel.pal.sfondo
        property var b: ({})
        function apri(x) {
            b = x || {}
            aC.text = b.a || ""; ccC.text = b.cc || ""; oggettoC.text = b.oggetto || ""
            testoC.text = (b.testo || "") + (b.testo ? "" : ((app.pc("firma", [b.conto || (app.conti[0] ? app.conti[0].id : "")]) || {}).testo || ""))
            visible = true
        }
        MouseArea { anchors.fill: parent }
        Text { x: 20; y: 64; text: I18n.t("Annulla"); color: tel.accento; font.family: Tema.font; font.pixelSize: 16
               MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: composizione.visible = false } }
        Text { anchors.horizontalCenter: parent.horizontalCenter; y: 64; text: I18n.t("Nuovo messaggio"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.Bold }
        TastoTondo {
            anchors.right: parent.right; anchors.rightMargin: 16; y: 56; lato: 40; icona: "linea-invia"; pieno: true
            onTocco: {
                var d = Object.assign({}, composizione.b, { conto: composizione.b.conto || (app.conto || (app.conti[0] ? app.conti[0].id : "")), a: aC.text, cc: ccC.text, oggetto: oggettoC.text, testo: testoC.text })
                var r = app.pc("invia", [d]); tel.avviso(r ? r.messaggio : "")
                if (r && r.ok) composizione.visible = false
            }
        }
        Column {
            x: 16; y: 110; width: parent.width - 32; spacing: 8
            CampoTesto { id: aC; width: parent.width; placeholderText: I18n.t("A:"); inputMethodHints: Qt.ImhEmailCharactersOnly }
            CampoTesto { id: ccC; width: parent.width; placeholderText: I18n.t("Cc:"); inputMethodHints: Qt.ImhEmailCharactersOnly }
            CampoTesto { id: oggettoC; width: parent.width; placeholderText: I18n.t("Oggetto") }
            Rectangle {
                width: parent.width; height: composizione.height - 330; radius: 16; color: tel.pal.superficie
                Flickable { anchors.fill: parent; anchors.margins: 12; contentHeight: testoC.implicitHeight; clip: true
                            TextArea.flickable: TextArea { id: testoC; wrapMode: TextArea.Wrap; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 16; background: Item {}
                                                           placeholderText: I18n.t("Scrivi qui"); placeholderTextColor: tel.pal.testo3 } }
            }
        }
    }

    // ══ Aggiungi un account ═══════════════════════════════════════════════
    Rectangle {
        anchors.fill: parent; visible: app.nuovoConto; color: tel.pal.sfondo
        MouseArea { anchors.fill: parent }
        Text { x: 20; y: 64; text: I18n.t("Annulla"); color: tel.accento; font.family: Tema.font; font.pixelSize: 16
               MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: app.nuovoConto = false } }
        Column {
            x: 20; y: 110; width: parent.width - 40; spacing: 10
            Text { text: I18n.t("Nuovo account"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 26; font.weight: Font.Bold }
            CampoTesto { id: nomeA; width: parent.width; placeholderText: I18n.t("Il tuo nome") }
            CampoTesto { id: emailA; width: parent.width; placeholderText: I18n.t("Email"); inputMethodHints: Qt.ImhEmailCharactersOnly
                         onEditingFinished: { var c = app.pc("configura", [text]) || ({}); notaA.text = c.nota || (c.trovata ? I18n.t("Server trovati") : "") } }
            CampoTesto { id: passA; width: parent.width; placeholderText: I18n.t("Password (o password per le app)"); echoMode: TextInput.Password }
            Text { id: notaA; width: parent.width; wrapMode: Text.Wrap; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 13 }
            Pulsante {
                width: parent.width; text: I18n.t("Aggiungi"); principale: true
                onClicked: {
                    var c = app.pc("configura", [emailA.text]) || {}
                    var r = app.pc("aggiungiConto", [Object.assign({}, c, { email: emailA.text, nome: nomeA.text, password: passA.text })])
                    tel.avviso(r ? (r.messaggio || "") : "")
                    if (r && r.ok) { app.nuovoConto = false; passA.text = ""; app.carica() }
                }
            }
        }
    }
}
