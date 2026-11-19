// File (come nell'immagine approvata, sul modello dell'app File dell'iPhone):
// - Recenti: i file usati di recente, con i filtri Tutti / Documenti / Immagini / Scaricati.
// - Condivisi: i file ricevuti con Vicina (dal PC o da altri telefoni).
// - Sfoglia: Posizioni (telefono, microSD, server di casa, Nextcloud, PC), Preferiti e Tag.
// Le cartelle si vedono a griglia con le anteprime o in elenco; le azioni su un file stanno
// in un foglio (Condividi, Al PC, Rinomina, Elimina, Sposta, Duplica, Comprimi, Tag, Informazioni).
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: app
    color: tel.pal.sfondo
    property string scheda: "sfoglia"                 // recenti | condivisi | sfoglia
    property string vista: "radice"                   // radice | cartella | remoto | tag | cerca
    property var sfoglia: ({ posizioni: [], preferiti: [], tag: [] })
    property var cartella: ({ percorso: "", titolo: "", su: "", voci: [] })
    property var remoto: ({ servizio: "", cartella: "", titolo: "", voci: [] })
    property var elenco: []                           // recenti, condivisi, tag o ricerca
    property string filtro: ""
    property string ordine: "data"                    // nome | data | dimensione
    property bool griglia: true
    property bool selezione: false
    property var scelti: ({})
    property var tagAperto: null
    property string cerca: ""
    property var anteprima: null
    property string testoAnteprima: ""
    property string cartellaRadice: ""
    readonly property int quantiScelti: Object.keys(scelti).length
    readonly property var coloriEst: ({ pdf: "#E5484D", doc: "#2B6CE6", docx: "#2B6CE6", odt: "#2B6CE6", xls: "#1E8E4E", xlsx: "#1E8E4E", ods: "#1E8E4E", csv: "#1E8E4E",
                                        ppt: "#E2702E", pptx: "#E2702E", odp: "#E2702E", txt: "#71717A", md: "#71717A", zip: "#8B5CF6", mp3: "#E11D48", mp4: "#0891B2" })

    function carica() {
        if (scheda === "sfoglia" && vista === "radice") sfoglia = ponte.chiama0("fileSfoglia")
        else if (scheda === "recenti" && vista === "radice") elenco = ponte.chiama("fileRecenti", [filtro])
        else if (scheda === "condivisi" && vista === "radice") elenco = ponte.chiama0("fileCondivisi")
        else if (vista === "cartella") cartella = ponte.chiama("elencoFile", [cartella.percorso, false, ordine])
        else if (vista === "tag" && tagAperto) elenco = ponte.chiama("fileConTag", [tagAperto.id])
    }
    function apriCartella(percorso) { cartella = ponte.chiama("elencoFile", [percorso, false, ordine]); vista = "cartella"; selezione = false; scelti = {} }
    function apriRemoto(servizio, sotto) {
        var r = ponte.chiama("fileRemoto", [servizio, sotto || ""])
        if (r.ok === false) { tel.avviso(r.messaggio); return }
        remoto = { servizio: servizio, cartella: r.cartella, titolo: r.titolo, voci: r.voci }; vista = "remoto"
    }
    function indietro() {
        if (anteprima) { anteprima = null; return }
        if (vista === "cartella" && cartella.su && cartella.percorso !== cartellaRadice) apriCartella(cartella.su)
        else if (vista === "remoto" && remoto.cartella) apriRemoto(remoto.servizio, remoto.cartella.split("/").slice(0, -1).join("/"))
        else { vista = "radice"; carica() }
    }
    function apriPosizione(p) {
        if (p.remoto) apriRemoto(p.remoto, "")
        else if (p.vicina) tel.appInterna = "vicina"
        else { cartellaRadice = p.percorso; apriCartella(p.percorso) }
    }
    function apri(v) {
        if (selezione) { var s = Object.assign({}, scelti); if (s[v.percorso]) delete s[v.percorso]; else s[v.percorso] = true; scelti = s; return }
        if (v.tipo === "cartella") { if (vista !== "cartella") cartellaRadice = v.percorso; apriCartella(v.percorso) }
        else if (v.tipo === "immagine") anteprima = v
        else if (v.tipo === "testo") { testoAnteprima = ponte.chiama("leggiTesto", [v.percorso]); anteprima = v }
        else if (v.tipo === "audio") { tel.appInterna = "musica"; tel.branoDaSuonare = v.percorso }
        else azioni.apri(v)
    }
    onVisibleChanged: if (visible) carica()
    onSchedaChanged: { vista = "radice"; filtro = ""; carica() }
    Component.onCompleted: {
        carica()
        // Foto della prova automatica
        var s = ponte.chiama0("avvio").schermata
        if (s === "file-cartella") { var d = sfoglia.preferiti.length ? sfoglia.preferiti[0].percorso : ""; cartellaRadice = d; apriCartella(d) }
        else if (s === "file-recenti") scheda = "recenti"
        else if (s === "file-azioni") { scheda = "recenti"; provaAzioni.start() }
    }
    Timer { id: provaAzioni; interval: 300; onTriggered: { var v = app.elenco.find(function (x) { return x.est === "pdf" }) || app.elenco[0]; if (v) azioni.apri(v) } }

    // ── Pezzi comuni ─────────────────────────────────────────────────────
    // Anteprima di un file: la foto vera, una cartella o un foglio con il tipo colorato
    component Anteprima: Item {
        id: an
        property var v: ({})
        property real lato: 84
        width: lato; height: lato
        Icona { visible: an.v.tipo === "cartella"; anchors.centerIn: parent; nome: "linea-file"; lato: an.lato * 0.92; colore: "#6BA4FF" }
        Rectangle {
            visible: an.v.tipo === "immagine"
            anchors.centerIn: parent; width: an.lato * 0.8; height: an.lato; radius: 8; clip: true; color: tel.pal.superficie2
            Image { anchors.fill: parent; source: an.v.uri || ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 240 }
        }
        Rectangle {
            visible: an.v.tipo !== "cartella" && an.v.tipo !== "immagine"
            anchors.centerIn: parent; width: an.lato * 0.78; height: an.lato; radius: 7; color: "#F4F4F5"
            Repeater {
                model: 5
                Rectangle { required property int index; x: parent.width * 0.18; y: parent.height * (0.2 + index * 0.11); width: parent.width * (index % 2 ? 0.52 : 0.64); height: Math.max(1.5, an.lato * 0.025); color: "#D4D4D8" }
            }
            Rectangle {
                visible: (an.v.est || "") !== ""
                anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: parent.height * 0.08
                width: etEst.implicitWidth + 8; height: etEst.implicitHeight + 2; radius: 3
                color: app.coloriEst[an.v.est] || "#71717A"
                Text { id: etEst; anchors.centerIn: parent; text: (an.v.est || "").toUpperCase().slice(0, 4); color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: Math.max(7, an.lato * 0.13); font.weight: Font.Bold }
            }
        }
    }
    component Pillola: Rectangle {
        id: pl
        property string testo: ""
        property bool attiva: false
        property color punto: "transparent"
        signal tocco()
        height: 30; width: rigaPl.width + 26; radius: 15
        color: attiva ? tel.accento : tel.pal.superficie2
        Row {
            id: rigaPl
            anchors.centerIn: parent; spacing: 6
            Rectangle { visible: pl.punto.a > 0; anchors.verticalCenter: parent.verticalCenter; width: 10; height: 10; radius: 5; color: pl.punto }
            Text { text: pl.testo; color: pl.attiva ? "#FFFFFF" : tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
        }
        MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: pl.tocco() }
    }
    // Riga di un file (Recenti, Condivisi, Tag, Cerca, cartella in elenco)
    component RigaFile: Item {
        id: rf
        property var v: ({})
        property bool prima: false
        height: 62
        Rectangle { visible: !rf.prima; x: 68; width: parent.width - 68; height: 1; color: tel.pal.bordo }
        Anteprima { x: 14; anchors.verticalCenter: parent.verticalCenter; v: rf.v; lato: 44 }
        Column {
            x: 68; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 68 - 70
            Text { width: parent.width; elide: Text.ElideMiddle; text: rf.v.nome || ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.Medium }
            Text { width: parent.width; elide: Text.ElideRight; text: (rf.v.quando || "") + (rf.v.info ? " · " + rf.v.info : ""); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12.5) }
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 42; anchors.verticalCenter: parent.verticalCenter; spacing: 3
            Repeater { model: rf.v.tag || []; Rectangle { required property string modelData; width: 10; height: 10; radius: 5; color: (app.sfoglia.tag.find(function (t) { return t.id === modelData }) || { colore: "#888" }).colore } }
        }
        Text { visible: !app.selezione; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: "⋯"; color: tel.pal.testo2; font.pixelSize: 20 }
        Rectangle {
            visible: app.selezione
            anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
            width: 24; height: 24; radius: 12; color: app.scelti[rf.v.percorso] ? tel.accento : tel.pal.superficie; border.width: 2; border.color: app.scelti[rf.v.percorso] ? tel.accento : tel.pal.bordo
            Text { anchors.centerIn: parent; visible: !!app.scelti[rf.v.percorso]; text: "✓"; color: "#FFFFFF"; font.pixelSize: 13; font.bold: true }
        }
        MouseArea { anchors.fill: parent; anchors.rightMargin: 50; onClicked: app.apri(rf.v); onPressAndHold: azioni.apri(rf.v) }
        MouseArea { anchors.right: parent.right; width: 50; height: parent.height; onClicked: app.selezione ? app.apri(rf.v) : azioni.apri(rf.v) }
    }
    component Gruppo: Rectangle {
        default property alias righe: colGr.data
        height: colGr.height; radius: 14; color: tel.pal.superficie
        Column { id: colGr; width: parent.width }
    }
    component Intestazione: Text {
        topPadding: 10; bottomPadding: 2
        color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(19); font.weight: Font.Bold
    }

    // ══ Barra in alto (dentro una cartella) ════════════════════════════════
    Item {
        visible: app.vista !== "radice"
        x: 14; y: 54; width: parent.width - 32; height: 30
        Text {
            text: "‹ " + (app.scheda === "sfoglia" ? I18n.t("Sfoglia") : app.scheda === "recenti" ? I18n.t("Recenti") : I18n.t("Condivisi"))
            color: tel.accento; font.family: Tema.font; font.pixelSize: tel.px(16)
            MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: app.indietro() }
        }
        Row {
            visible: app.vista === "cartella"
            anchors.right: parent.right; spacing: 18
            Icona {
                anchors.verticalCenter: parent.verticalCenter; nome: "linea-piu"; lato: 22; colore: tel.accento
                MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: { campo.modo = "cartella"; campo.voce = null; campo.open() } }
            }
            Icona {
                anchors.verticalCenter: parent.verticalCenter; nome: app.griglia ? "linea-elenco" : "linea-griglia"; lato: 22; colore: tel.accento
                MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: app.griglia = !app.griglia }
            }
            Text {
                text: app.selezione ? I18n.t("Fine") : I18n.t("Seleziona"); color: tel.accento; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: app.selezione ? Font.DemiBold : Font.Normal
                MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: { app.selezione = !app.selezione; app.scelti = {} } }
            }
        }
    }
    Punti {
        x: 18; y: app.vista === "radice" ? 84 : 88
        width: parent.width - 36; elide: Text.ElideRight
        text: app.vista === "cartella" ? app.cartella.titolo : app.vista === "remoto" ? app.remoto.titolo
              : app.vista === "tag" ? (app.tagAperto ? app.tagAperto.nome : "") : app.vista === "cerca" ? I18n.t("Risultati")
              : ({ sfoglia: I18n.t("Sfoglia"), recenti: I18n.t("Recenti"), condivisi: I18n.t("Condivisi") })[app.scheda]
    }

    // ══ Sfoglia ══════════════════════════════════════════════════════════
    Flickable {
        visible: app.scheda === "sfoglia" && app.vista === "radice"
        anchors.fill: parent; anchors.topMargin: 136; anchors.bottomMargin: 82
        contentHeight: colSf.height + 30; clip: true
        Column {
            id: colSf
            x: 16; width: app.width - 32; spacing: 8
            CampoCerca {
                width: parent.width; height: 38; radius: 12
                suggerimento: I18n.t("Cerca in tutti i file")
                onTextChanged: { app.cerca = text.trim(); if (app.cerca.length > 1) { app.elenco = ponte.chiama("fileCerca", [app.cerca]); app.vista = "cerca" } }
            }
            Intestazione { text: I18n.t("Posizioni") }
            Gruppo {
                width: colSf.width
                Repeater {
                    model: app.sfoglia.posizioni
                    Item {
                        id: pos
                        required property var modelData
                        required property int index
                        width: colSf.width; height: 56
                        Rectangle { visible: pos.index > 0; x: 56; width: parent.width - 56; height: 1; color: tel.pal.bordo }
                        Rectangle {
                            x: 14; anchors.verticalCenter: parent.verticalCenter; width: 30; height: 30; radius: 8; color: pos.modelData.colore
                            Icona { anchors.centerIn: parent; nome: pos.modelData.icona; lato: 17; tema: "scuro" }
                        }
                        Column {
                            x: 56; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 90
                            Text { text: pos.modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16) }
                            Text { visible: text !== ""; width: parent.width; elide: Text.ElideRight; text: pos.modelData.info || ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12.5) }
                        }
                        Text { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: "›"; color: tel.pal.testo2; font.pixelSize: 22 }
                        MouseArea { anchors.fill: parent; onClicked: app.apriPosizione(pos.modelData) }
                    }
                }
            }
            Intestazione { text: I18n.t("Preferiti") }
            Gruppo {
                width: colSf.width
                Repeater {
                    model: app.sfoglia.preferiti
                    Item {
                        id: pref
                        required property var modelData
                        required property int index
                        width: colSf.width; height: 48
                        Rectangle { visible: pref.index > 0; x: 56; width: parent.width - 56; height: 1; color: tel.pal.bordo }
                        Icona { x: 18; anchors.verticalCenter: parent.verticalCenter; nome: pref.modelData.icona; lato: 22; colore: tel.accento }
                        Text { x: 56; anchors.verticalCenter: parent.verticalCenter; text: pref.modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16) }
                        MouseArea { anchors.fill: parent; onClicked: { app.cartellaRadice = pref.modelData.percorso; app.apriCartella(pref.modelData.percorso) } }
                    }
                }
            }
            Intestazione { text: I18n.t("Tag") }
            Flow {
                width: parent.width; spacing: 8
                Repeater {
                    model: app.sfoglia.tag
                    Pillola {
                        required property var modelData
                        testo: modelData.nome + (modelData.n ? "  " + modelData.n : ""); punto: modelData.colore
                        onTocco: { app.tagAperto = modelData; app.vista = "tag"; app.carica() }
                    }
                }
            }
        }
    }

    // ══ Recenti, Condivisi, Tag, Cerca (elenco) ════════════════════════════
    Flickable {
        visible: (app.vista === "radice" && app.scheda !== "sfoglia") || app.vista === "tag" || app.vista === "cerca"
        anchors.fill: parent; anchors.topMargin: 136; anchors.bottomMargin: 82
        contentHeight: colEl.height + 30; clip: true
        Column {
            id: colEl
            x: 16; width: app.width - 32; spacing: 12
            Row {
                visible: app.scheda === "recenti" && app.vista === "radice"
                spacing: 8
                Repeater {
                    model: [{ k: "", t: I18n.t("Tutti") }, { k: "documenti", t: I18n.t("Documenti") }, { k: "immagini", t: I18n.t("Immagini") }, { k: "scaricati", t: I18n.t("Scaricati") }]
                    Pillola { required property var modelData; testo: modelData.t; attiva: app.filtro === modelData.k; onTocco: { app.filtro = modelData.k; app.carica() } }
                }
            }
            Text {
                visible: app.scheda === "condivisi" && app.vista === "radice"
                width: parent.width; wrapMode: Text.Wrap
                text: I18n.t("I file ricevuti con Vicina, dal PC o da altri telefoni.")
                color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13.5)
            }
            Gruppo {
                visible: app.elenco.length > 0
                width: colEl.width
                Repeater {
                    model: app.elenco
                    RigaFile { required property var modelData; required property int index; v: modelData; prima: index === 0; width: colEl.width }
                }
            }
            Text {
                visible: app.elenco.length === 0
                width: parent.width; wrapMode: Text.Wrap; topPadding: 20; horizontalAlignment: Text.AlignHCenter
                text: app.vista === "cerca" ? I18n.t("Nessun file trovato") : app.vista === "tag" ? I18n.t("Nessun file con questo tag: aggiungilo dal foglio delle azioni di un file.") : I18n.t("Ancora niente qui")
                color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(14)
            }
        }
    }

    // ══ Una cartella: griglia con le anteprime o elenco ════════════════════
    Text {
        visible: app.vista === "cartella"
        x: 18; y: 136
        text: app.cartella.voci.length + " " + I18n.t("elementi") + " · " + ({ nome: I18n.t("ordinati per nome"), data: I18n.t("ordinati per data"), dimensione: I18n.t("ordinati per dimensione") })[app.ordine] + " ▾"
        color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.Medium
        MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: { app.ordine = app.ordine === "data" ? "nome" : app.ordine === "nome" ? "dimensione" : "data"; app.carica() } }
    }
    Flickable {
        visible: app.vista === "cartella"
        anchors.fill: parent; anchors.topMargin: 166; anchors.bottomMargin: 82
        contentHeight: (app.griglia ? grigliaF.height : colLista.height) + 30; clip: true
        Grid {
            id: grigliaF
            visible: app.griglia
            x: 16; columns: 3; rowSpacing: 18
            readonly property real cella: (app.width - 32) / 3
            Repeater {
                model: app.griglia ? app.cartella.voci : []
                Item {
                    id: cel
                    required property var modelData
                    width: grigliaF.cella; height: 152
                    Anteprima { anchors.horizontalCenter: parent.horizontalCenter; y: 4; v: cel.modelData; lato: 84 }
                    Rectangle {
                        visible: app.selezione
                        anchors.right: parent.right; anchors.rightMargin: 14; y: 0
                        width: 24; height: 24; radius: 12; color: app.scelti[cel.modelData.percorso] ? tel.accento : "#66000000"; border.width: 2; border.color: "#FFFFFF"
                        Text { anchors.centerIn: parent; visible: !!app.scelti[cel.modelData.percorso]; text: "✓"; color: "#FFFFFF"; font.pixelSize: 13; font.bold: true }
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter; y: 92; spacing: 3
                        Repeater { model: cel.modelData.tag || []; Rectangle { required property string modelData; width: 8; height: 8; radius: 4; color: (app.sfoglia.tag.find(function (t) { return t.id === modelData }) || { colore: "#888" }).colore } }
                    }
                    Column {
                        y: 100; width: parent.width
                        Text { width: parent.width - 8; x: 4; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideMiddle; text: cel.modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(12.5); font.weight: Font.Medium }
                        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: cel.modelData.tipo === "cartella" ? cel.modelData.info : cel.modelData.quando + " · " + cel.modelData.info; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(11) }
                    }
                    MouseArea { anchors.fill: parent; onClicked: app.apri(cel.modelData); onPressAndHold: azioni.apri(cel.modelData) }
                }
            }
        }
        Gruppo {
            id: colLista
            visible: !app.griglia && app.cartella.voci.length > 0
            x: 16; width: app.width - 32
            Repeater {
                model: app.griglia ? [] : app.cartella.voci
                RigaFile { required property var modelData; required property int index; v: modelData; prima: index === 0; width: app.width - 32 }
            }
        }
        Text {
            visible: app.cartella.voci.length === 0
            x: 18; y: 30; text: I18n.t("Cartella vuota"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(14)
        }
    }

    // ══ Server di casa o Nextcloud ═════════════════════════════════════════
    Flickable {
        visible: app.vista === "remoto"
        anchors.fill: parent; anchors.topMargin: 140; anchors.bottomMargin: 82
        contentHeight: grRem.height + 30; clip: true
        Gruppo {
            id: grRem
            x: 16; width: app.width - 32
            Repeater {
                model: app.remoto.voci
                Item {
                    id: rem
                    required property var modelData
                    required property int index
                    width: app.width - 32; height: 58
                    Rectangle { visible: rem.index > 0; x: 68; width: parent.width - 68; height: 1; color: tel.pal.bordo }
                    Anteprima { x: 14; anchors.verticalCenter: parent.verticalCenter; v: ({ tipo: rem.modelData.tipo, est: rem.modelData.tipo === "cartella" ? "" : rem.modelData.nome.split(".").pop().toLowerCase() }); lato: 40 }
                    Column {
                        x: 68; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 100
                        Text { width: parent.width; elide: Text.ElideMiddle; text: rem.modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15) }
                        Text { visible: text !== ""; text: rem.modelData.info; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12.5) }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (rem.modelData.tipo === "cartella") { app.apriRemoto(app.remoto.servizio, rem.modelData.relativo); return }
                            var r = ponte.chiama("fileScaricaRemoto", [app.remoto.servizio, rem.modelData.relativo])
                            tel.avviso(r.messaggio)
                        }
                    }
                }
            }
        }
    }

    // ══ Barra in basso: schede, o le azioni della selezione ════════════════
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 82; color: tel.pal.superficie
        Rectangle { width: parent.width; height: 1; color: tel.pal.bordo }
        Row {
            visible: !app.selezione
            anchors.horizontalCenter: parent.horizontalCenter; y: 8
            Repeater {
                model: [{ s: "recenti", t: I18n.t("Recenti"), i: "linea-orologio" }, { s: "condivisi", t: I18n.t("Condivisi"), i: "linea-vicina" }, { s: "sfoglia", t: I18n.t("Sfoglia"), i: "linea-file" }]
                Item {
                    id: tabF
                    required property var modelData
                    width: app.width / 3; height: 50
                    Column {
                        anchors.centerIn: parent; spacing: 3
                        Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: tabF.modelData.i; lato: 24; colore: app.scheda === tabF.modelData.s ? tel.accento : tel.pal.testo2 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: tabF.modelData.t; color: app.scheda === tabF.modelData.s ? tel.accento : tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(11); font.weight: Font.DemiBold }
                    }
                    MouseArea { anchors.fill: parent; onClicked: { if (app.scheda === tabF.modelData.s) { app.vista = "radice"; app.carica() } else app.scheda = tabF.modelData.s } }
                }
            }
        }
        Item {
            visible: app.selezione
            anchors.fill: parent
            Icona { x: 26; y: 16; nome: "linea-esporta"; lato: 24; colore: tel.accento; opacity: app.quantiScelti ? 1 : 0.4
                    MouseArea { anchors.fill: parent; anchors.margins: -10; enabled: app.quantiScelti > 0; onClicked: { tel.condividi(Object.keys(app.scelti)); app.selezione = false; app.scelti = {} } } }
            Text { anchors.horizontalCenter: parent.horizontalCenter; y: 18; text: app.quantiScelti ? app.quantiScelti + " " + I18n.t("selezionati") : I18n.t("Tocca i file da scegliere"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.DemiBold }
            Icona { anchors.right: parent.right; anchors.rightMargin: 26; y: 16; nome: "linea-cestino"; lato: 24; colore: tel.rosso; opacity: app.quantiScelti ? 1 : 0.4
                    MouseArea { anchors.fill: parent; anchors.margins: -10; enabled: app.quantiScelti > 0
                                onClicked: { var p = Object.keys(app.scelti); for (var i = 0; i < p.length; i++) ponte.chiama("cestinaFile", [p[i]]); tel.avviso(I18n.t("Spostati nel Cestino")); app.selezione = false; app.scelti = ({}); app.carica() } } }
        }
    }

    // ══ Anteprima (immagini e testi) ═══════════════════════════════════════
    Rectangle {
        anchors.fill: parent
        visible: app.anteprima !== null
        color: app.anteprima && app.anteprima.tipo === "immagine" ? "#000000" : app.color
        MouseArea { anchors.fill: parent }
        Image {
            anchors.fill: parent; anchors.topMargin: 100; anchors.bottomMargin: 60
            visible: app.anteprima !== null && app.anteprima.tipo === "immagine"
            source: visible ? app.anteprima.uri : ""
            fillMode: Image.PreserveAspectFit; asynchronous: true
            sourceSize.width: 1200
        }
        Flickable {
            visible: app.anteprima !== null && app.anteprima.tipo === "testo"
            x: 16; y: 100; width: parent.width - 32; height: parent.height - y - 30
            contentHeight: testoA.implicitHeight; clip: true
            Text { id: testoA; width: parent.width; wrapMode: Text.Wrap; text: app.testoAnteprima; textFormat: Text.PlainText; color: tel.pal.testo; font.family: "monospace"; font.pixelSize: tel.px(13) }
        }
        Text {
            x: 18; y: 58
            text: "‹ " + I18n.t("Indietro"); color: app.anteprima && app.anteprima.tipo === "immagine" ? "#FFFFFF" : tel.accento; font.family: Tema.font; font.pixelSize: tel.px(16)
            MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: app.anteprima = null }
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 20; y: 54
            text: "⋯"; color: app.anteprima && app.anteprima.tipo === "immagine" ? "#FFFFFF" : tel.accento; font.pixelSize: 26
            MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: azioni.apri(app.anteprima) }
        }
    }

    // ══ Foglio delle azioni su un file ═════════════════════════════════════
    Rectangle {
        anchors.fill: parent; color: "#80000000"
        opacity: azioni.aperto ? 1 : 0; visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: tel.tNormale } }
        MouseArea { anchors.fill: parent; onClicked: azioni.aperto = false }
    }
    Rectangle {
        id: azioni
        property bool aperto: false
        property var voce: ({})
        function apri(v) { voce = v; aperto = true }
        width: parent.width; height: colAz.height + 50
        y: aperto ? parent.height - height : parent.height
        visible: y < parent.height
        Behavior on y { Movimento { apre: azioni.aperto } }
        radius: 26; color: tel.pal.superficie
        MouseArea { anchors.fill: parent }
        Column {
            id: colAz
            x: 16; y: 12; width: parent.width - 32; spacing: 14
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 40; height: 5; radius: 3; color: tel.pal.bordo }
            Row {
                spacing: 14
                Anteprima { v: azioni.voce; lato: 56 }
                Column {
                    anchors.verticalCenter: parent.verticalCenter; width: colAz.width - 80
                    Text { width: parent.width; elide: Text.ElideMiddle; text: azioni.voce.nome || ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(17); font.weight: Font.DemiBold }
                    Text { width: parent.width; elide: Text.ElideRight; text: ((azioni.voce.est || "").toUpperCase() || (azioni.voce.tipo === "cartella" ? I18n.t("Cartella") : "")) + (azioni.voce.info ? " · " + azioni.voce.info : "") + (azioni.voce.quando ? " · " + I18n.t("modificato") + " " + azioni.voce.quando : ""); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13) }
                }
            }
            Row {
                spacing: 8
                Repeater {
                    model: [{ k: "condividi", t: I18n.t("Condividi"), i: "linea-esporta" }, { k: "pc", t: I18n.t("Al PC"), i: "linea-vicina" },
                            { k: "rinomina", t: I18n.t("Rinomina"), i: "linea-matita" }, { k: "elimina", t: I18n.t("Elimina"), i: "linea-cestino" }]
                    Rectangle {
                        id: az
                        required property var modelData
                        width: (colAz.width - 24) / 4; height: 66; radius: 14; color: tel.pal.superficie2
                        readonly property color tinta: az.modelData.k === "elimina" ? tel.rosso : tel.accento
                        Column {
                            anchors.centerIn: parent; spacing: 5
                            Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: az.modelData.i; lato: 22; colore: az.tinta }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: az.modelData.t; color: az.tinta; font.family: Tema.font; font.pixelSize: tel.px(12); font.weight: Font.Medium }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                var v = azioni.voce, k = az.modelData.k
                                azioni.aperto = false
                                if (k === "condividi" || k === "pc") tel.condividi([v.percorso])
                                else if (k === "rinomina") { campo.modo = "rinomina"; campo.voce = v; campo.open() }
                                else { var r = ponte.chiama("cestinaFile", [v.percorso]); tel.avviso(r.messaggio); app.anteprima = null; app.carica() }
                            }
                        }
                    }
                }
            }
            Gruppo {
                width: colAz.width
                color: tel.pal.superficie2
                Repeater {
                    model: [{ k: "sposta", t: I18n.t("Sposta…") }, { k: "duplica", t: I18n.t("Duplica") }, { k: "comprimi", t: I18n.t("Comprimi (.zip)") },
                            { k: "tag", t: I18n.t("Aggiungi un tag") }, { k: "info", t: I18n.t("Informazioni") }]
                    Item {
                        id: voceAz
                        required property var modelData
                        required property int index
                        width: colAz.width; height: 46
                        Rectangle { visible: voceAz.index > 0; x: 16; width: parent.width - 16; height: 1; color: tel.pal.bordo }
                        Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: voceAz.modelData.t; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16) }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                var v = azioni.voce, k = voceAz.modelData.k, r
                                azioni.aperto = false
                                if (k === "sposta") sposta.open()
                                else if (k === "duplica") { r = ponte.chiama("fileDuplica", [v.percorso]); tel.avviso(r.messaggio); app.carica() }
                                else if (k === "comprimi") { r = ponte.chiama("fileComprimi", [v.percorso]); tel.avviso(r.messaggio); app.carica() }
                                else if (k === "tag") sceltaTag.open()
                                else informazioni.open()
                            }
                        }
                    }
                }
            }
        }
    }

    // Sposta in una delle cartelle preferite
    Popup {
        id: sposta
        anchors.centerIn: parent
        width: parent.width - 40; modal: true; padding: 14
        background: Rectangle { radius: 20; color: tel.pal.superficie }
        Column {
            width: parent.width; spacing: 6
            Text { text: I18n.t("Sposta in…"); bottomPadding: 6; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(17); font.weight: Font.Bold }
            Repeater {
                model: app.sfoglia.preferiti
                Rectangle {
                    required property var modelData
                    width: parent.width; height: 46; radius: 12; color: tel.pal.superficie2
                    Icona { x: 12; anchors.verticalCenter: parent.verticalCenter; nome: parent.modelData.icona; lato: 20; colore: tel.accento }
                    Text { x: 44; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15) }
                    MouseArea { anchors.fill: parent; onClicked: { var r = ponte.chiama("fileSposta", [azioni.voce.percorso, parent.modelData.percorso]); tel.avviso(r.messaggio); sposta.close(); app.carica() } }
                }
            }
        }
    }
    // Tag del file
    Popup {
        id: sceltaTag
        anchors.centerIn: parent
        width: parent.width - 40; modal: true; padding: 14
        background: Rectangle { radius: 20; color: tel.pal.superficie }
        Column {
            width: parent.width; spacing: 6
            Text { text: I18n.t("Tag"); bottomPadding: 6; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(17); font.weight: Font.Bold }
            Repeater {
                model: app.sfoglia.tag
                Rectangle {
                    id: tg
                    required property var modelData
                    readonly property bool messo: (azioni.voce.tag || []).indexOf(modelData.id) >= 0
                    width: parent.width; height: 46; radius: 12; color: tel.pal.superficie2
                    Rectangle { x: 14; anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; radius: 7; color: tg.modelData.colore }
                    Text { x: 40; anchors.verticalCenter: parent.verticalCenter; text: tg.modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15) }
                    Text { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; visible: tg.messo; text: "✓"; color: tel.accento; font.pixelSize: 16 }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            ponte.chiama("fileTag", [azioni.voce.percorso, tg.modelData.id, !tg.messo])
                            var t = (azioni.voce.tag || []).filter(function (x) { return x !== tg.modelData.id })
                            if (!tg.messo) t.push(tg.modelData.id)
                            azioni.voce = Object.assign({}, azioni.voce, { tag: t })
                            app.sfoglia = ponte.chiama0("fileSfoglia"); app.carica()
                        }
                    }
                }
            }
        }
    }
    // Informazioni
    Popup {
        id: informazioni
        anchors.centerIn: parent
        width: parent.width - 40; modal: true; padding: 18
        background: Rectangle { radius: 20; color: tel.pal.superficie }
        Column {
            width: parent.width; spacing: 8
            Text { width: parent.width; wrapMode: Text.Wrap; text: azioni.voce.nome || ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(17); font.weight: Font.Bold }
            Repeater {
                model: [[I18n.t("Tipo"), (azioni.voce.est || "").toUpperCase() || azioni.voce.tipo || ""], [I18n.t("Dimensione"), azioni.voce.info || ""],
                        [I18n.t("Modificato"), azioni.voce.quando || ""], [I18n.t("Dove"), (azioni.voce.percorso || "").split("/").slice(0, -1).join("/")]]
                Column {
                    required property var modelData
                    width: parent.width
                    Text { text: parent.modelData[0]; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }
                    Text { width: parent.width; wrapMode: Text.WrapAnywhere; text: parent.modelData[1]; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(14) }
                }
            }
            Pulsante { anchors.right: parent.right; text: I18n.t("Chiudi"); principale: true; onClicked: informazioni.close() }
        }
    }
    // Nome (nuova cartella o rinomina)
    Popup {
        id: campo
        property string modo: "cartella"
        property var voce: null
        anchors.centerIn: parent
        width: parent.width - 40; modal: true; padding: 18
        background: Rectangle { radius: 20; color: tel.pal.superficie }
        onOpened: { campoNome.text = voce ? voce.nome : ""; campoNome.forceActiveFocus() }
        Column {
            width: parent.width; spacing: 12
            Text { text: campo.modo === "cartella" ? I18n.t("Nuova cartella") : I18n.t("Rinomina"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(17); font.weight: Font.Bold }
            CampoTesto { id: campoNome; width: parent.width; placeholderText: I18n.t("Nome"); onAccepted: ok.clicked() }
            Row {
                spacing: 10; anchors.right: parent.right
                Pulsante { text: I18n.t("Annulla"); onClicked: campo.close() }
                Pulsante {
                    id: ok
                    text: I18n.t("Fatto"); principale: true
                    onClicked: {
                        var r = campo.modo === "cartella" ? ponte.chiama("nuovaCartella", [app.cartella.percorso, campoNome.text])
                                                         : ponte.chiama("rinominaFile", [campo.voce.percorso, campoNome.text])
                        if (!r.ok) { tel.avviso(r.messaggio); return }
                        campo.close(); app.anteprima = null; app.carica()
                    }
                }
            }
        }
    }
}
