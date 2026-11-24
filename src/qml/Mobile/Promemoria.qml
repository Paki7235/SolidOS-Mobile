// Promemoria del telefono: stessa logica e stessi dati del PC (nucleo/apps/promemoria.py).
// In alto le quattro tessere (Oggi, Programmati, Tutti, Con bandiera) e le liste; dentro una
// lista i promemoria con il tondo da spuntare, la scadenza e la bandiera. In fondo «Nuovo
// promemoria»; toccandone uno si modifica (titolo, note, scadenza, bandiera, lista).
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: app
    color: tel.pal.sfondo
    property string filtro: ""            // "" = schermata iniziale, poi oggi | programmati | tutti | bandiera | completati | <lista>
    property var liste: []
    property var conteggi: ({})
    property var voci: []
    function pc(m, a) { return ponte.chiama("appPc", ["promemoria", m, a || []]) }
    function aggiorna() {
        liste = pc("liste") || []; conteggi = pc("conteggi") || {}
        if (filtro) voci = pc("promemoria", [filtro]) || []
    }
    function apri(f) { filtro = f; voci = pc("promemoria", [f]) || [] }
    readonly property var lista: liste.find(function (l) { return l.id === filtro }) || null
    readonly property var tessere: [{ k: "oggi", t: I18n.t("Oggi"), c: "#3B82F6", i: "linea-calendario" }, { k: "programmati", t: I18n.t("Programmati"), c: "#EF4444", i: "linea-orologio" },
                                    { k: "tutti", t: I18n.t("Tutti"), c: "#475569", i: "linea-elenco" }, { k: "bandiera", t: I18n.t("Con bandiera"), c: "#F59E0B", i: "linea-bandiera" }]
    onVisibleChanged: if (visible) aggiorna()
    Component.onCompleted: aggiorna()

    // ══ Schermata iniziale: tessere e liste ═══════════════════════════════
    Flickable {
        visible: app.filtro === ""
        anchors.fill: parent; anchors.topMargin: 54; contentHeight: col.height + 40; clip: true
        Column {
            id: col
            x: 16; width: parent.width - 32; spacing: 12
            Punti { x: 4; text: I18n.t("Promemoria") }
            Grid {
                columns: 2; spacing: 10
                Repeater {
                    model: app.tessere
                    Rectangle {
                        required property var modelData
                        width: (col.width - 10) / 2; height: 86; radius: 22
                        color: tel.solido ? modelData.c : tel.pal.superficie
                        Rectangle { x: 14; y: 12; width: 34; height: 34; radius: 17; color: tel.solido ? "#33FFFFFF" : parent.modelData.c
                                    Icona { anchors.centerIn: parent; nome: parent.parent.modelData.i; lato: 18; colore: "#FFFFFF" } }
                        Text { anchors.right: parent.right; anchors.rightMargin: 16; y: 10; text: app.conteggi[parent.modelData.k] || 0; color: tel.solido ? "#FFFFFF" : tel.pal.testo; font.family: Tema.font; font.pixelSize: 28; font.weight: Font.Bold }
                        Text { x: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 12; text: parent.modelData.t; color: tel.solido ? "#FFFFFF" : tel.pal.testo2; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.DemiBold }
                        MouseArea { anchors.fill: parent; onClicked: app.apri(parent.modelData.k) }
                    }
                }
            }
            Text { text: I18n.t("Le mie liste"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 20; font.weight: Font.Bold; topPadding: 10 }
            Rectangle {
                width: parent.width; height: colListe.height; radius: 20; color: tel.pal.superficie
                Column {
                    id: colListe
                    width: parent.width
                    Repeater {
                        model: app.liste
                        Item {
                            required property var modelData
                            required property int index
                            width: colListe.width; height: 56
                            Rectangle { x: 14; anchors.verticalCenter: parent.verticalCenter; width: 32; height: 32; radius: 16; color: modelData.colore
                                        Icona { anchors.centerIn: parent; nome: "linea-elenco"; lato: 16; colore: "#FFFFFF" } }
                            Text { x: 58; anchors.verticalCenter: parent.verticalCenter; text: modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 16 }
                            Text { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; text: modelData.quanti; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 15 }
                            Rectangle { visible: index < app.liste.length - 1; x: 58; anchors.bottom: parent.bottom; width: parent.width - 58; height: 1; color: tel.pal.bordo }
                            MouseArea { anchors.fill: parent; onClicked: app.apri(modelData.id)
                                        onPressAndHold: if (app.liste.length > 1) { app.pc("eliminaLista", [modelData.id]); app.aggiorna(); tel.avviso(modelData.nome + ": " + I18n.t("lista eliminata")) } }
                        }
                    }
                }
            }
            Row {
                spacing: 8
                CampoTesto { id: nuovaLista; width: col.width - 58; placeholderText: I18n.t("Nuova lista") }
                TastoTondo { anchors.verticalCenter: parent.verticalCenter; lato: 46; icona: "linea-piu"; pieno: true
                             onTocco: if (nuovaLista.text.trim()) { var cs = app.pc("colori") || ["#3B82F6"]; app.pc("salvaLista", [{ nome: nuovaLista.text.trim(), colore: cs[app.liste.length % cs.length] }]); nuovaLista.text = ""; app.aggiorna() } }
            }
            Text { text: I18n.t("Completati") + " (" + (app.conteggi.completati || 0) + ")"; color: tel.accento; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.DemiBold
                   MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: app.apri("completati") } }
        }
    }

    // ══ Dentro una lista ══════════════════════════════════════════════════
    Item {
        visible: app.filtro !== ""
        anchors.fill: parent
        Text { x: 18; y: 60; text: "‹ " + I18n.t("Liste"); color: tel.accento; font.family: Tema.font; font.pixelSize: 16
               MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: { app.filtro = ""; app.aggiorna() } } }
        Punti {
            x: 20; y: 88
            text: app.lista ? app.lista.nome : ({ oggi: I18n.t("Oggi"), programmati: I18n.t("Programmati"), tutti: I18n.t("Tutti"), bandiera: I18n.t("Con bandiera"), completati: I18n.t("Completati") })[app.filtro] || ""
            color: app.lista ? app.lista.colore : tel.pal.testo
        }
        ListView {
            id: elenco
            x: 8; y: 140; width: parent.width - 16; height: parent.height - y - 90; clip: true
            model: app.voci
            delegate: Item {
                required property var modelData
                width: elenco.width; height: Math.max(58, testi.height + 20)
                Rectangle {
                    x: 12; y: 16; width: 26; height: 26; radius: 13
                    color: modelData.fatto ? modelData.colore : "transparent"; border.width: 2; border.color: modelData.fatto ? modelData.colore : tel.pal.testo3
                    Icona { visible: modelData.fatto; anchors.centerIn: parent; nome: "linea-spunta"; lato: 16; colore: "#FFFFFF" }
                    MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: { app.pc("fatto", [modelData.id, !modelData.fatto]); app.aggiorna() } }
                }
                Column {
                    id: testi
                    x: 52; y: 12; width: parent.width - 52 - 36
                    Text { width: parent.width; wrapMode: Text.Wrap; text: modelData.titolo; color: modelData.fatto ? tel.pal.testo2 : tel.pal.testo; font.family: Tema.font; font.pixelSize: 16; font.strikeout: modelData.fatto }
                    Text { visible: text !== ""; width: parent.width; elide: Text.ElideRight; text: modelData.note; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 13 }
                    Text { visible: modelData.quando !== ""; text: modelData.quando; color: modelData.scaduto ? tel.rosso : tel.pal.testo2; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                }
                Icona { visible: modelData.bandiera; anchors.right: parent.right; anchors.rightMargin: 10; y: 18; nome: "linea-bandiera"; lato: 18; colore: "#F59E0B" }
                Rectangle { x: 52; anchors.bottom: parent.bottom; width: parent.width - 52; height: 1; color: tel.pal.bordo }
                MouseArea { anchors.fill: parent; anchors.leftMargin: 46; onClicked: modifica.apri(modelData) }
            }
            Text { anchors.centerIn: parent; visible: elenco.count === 0; text: I18n.t("Nessun promemoria"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 15 }
        }
        // Nuovo promemoria veloce
        Row {
            visible: app.filtro !== "completati"
            x: 16; anchors.bottom: parent.bottom; anchors.bottomMargin: 32; spacing: 8
            CampoTesto { id: nuovo; width: app.width - 32 - 54; placeholderText: I18n.t("Nuovo promemoria"); onAccepted: aggiungi.tocco() }
            TastoTondo {
                id: aggiungi
                anchors.verticalCenter: parent.verticalCenter; lato: 46; icona: "linea-piu"; pieno: true
                onTocco: if (nuovo.text.trim()) {
                    var oggi = new Date(), d = { titolo: nuovo.text.trim(), lista: app.lista ? app.lista.id : "promemoria", bandiera: app.filtro === "bandiera" }
                    if (app.filtro === "oggi") d.scadenza = oggi.getFullYear() + "-" + ("0" + (oggi.getMonth() + 1)).slice(-2) + "-" + ("0" + oggi.getDate()).slice(-2)
                    app.pc("salva", [d]); nuovo.text = ""; app.aggiorna()
                }
            }
        }
    }

    // ══ Modifica di un promemoria ═════════════════════════════════════════
    Rectangle {
        id: modifica
        anchors.fill: parent; visible: false; color: tel.pal.sfondo
        property var p: null
        property bool bandiera: false
        property string lista: "promemoria"
        function apri(v) { p = v; titoloM.text = v.titolo; noteM.text = v.note; scadenzaM.text = v.scadenza || ""; bandiera = v.bandiera; lista = v.lista; visible = true }
        MouseArea { anchors.fill: parent }
        Text { x: 20; y: 64; text: I18n.t("Annulla"); color: tel.accento; font.family: Tema.font; font.pixelSize: 16
               MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: modifica.visible = false } }
        Text { anchors.right: parent.right; anchors.rightMargin: 20; y: 64; text: I18n.t("Salva"); color: tel.accento; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.Bold
               MouseArea { anchors.fill: parent; anchors.margins: -10
                           onClicked: { app.pc("salva", [Object.assign({}, modifica.p, { titolo: titoloM.text, note: noteM.text, scadenza: scadenzaM.text.trim(), bandiera: modifica.bandiera, lista: modifica.lista })])
                                        modifica.visible = false; app.aggiorna() } } }
        Column {
            x: 16; y: 110; width: parent.width - 32; spacing: 10
            CampoTesto { id: titoloM; width: parent.width; placeholderText: I18n.t("Titolo") }
            CampoTesto { id: noteM; width: parent.width; placeholderText: I18n.t("Note") }
            CampoTesto { id: scadenzaM; width: parent.width; placeholderText: I18n.t("Scadenza: AAAA-MM-GG o AAAA-MM-GGTHH:MM") }
            Rectangle { width: parent.width; height: 52; radius: 16; color: tel.pal.superficie
                        Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Bandiera"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 16 }
                        Interruttore { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; checked: modifica.bandiera; onToggled: modifica.bandiera = checked } }
            Text { text: I18n.t("Lista"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.DemiBold }
            Flow { width: parent.width; spacing: 8
                   Repeater { model: app.liste
                              Rectangle { required property var modelData; readonly property bool scelta: modifica.lista === modelData.id
                                          width: etL.implicitWidth + 28; height: 36; radius: 18; color: scelta ? modelData.colore : tel.pal.superficie
                                          Text { id: etL; anchors.centerIn: parent; text: parent.modelData.nome; color: parent.scelta ? "#FFFFFF" : tel.pal.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                                          MouseArea { anchors.fill: parent; onClicked: modifica.lista = parent.modelData.id } } } }
            Pulsante { width: parent.width; text: I18n.t("Elimina promemoria"); pericoloso: true
                       onClicked: { app.pc("elimina", [modifica.p.id]); modifica.visible = false; app.aggiorna() } }
        }
    }
}
