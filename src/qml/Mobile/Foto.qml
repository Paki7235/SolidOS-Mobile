// Foto, come nell'immagine approvata: in basso Libreria, Per te, Album e Cerca.
// La Libreria è divisa per giorni, con i filtri per provenienza e «Seleziona»; le foto degli
// account collegati (Nextcloud…) hanno il simbolino del servizio. Dagli Album si aprono gli
// «Account collegati». A tutto schermo: data e ora in alto, da dove arriva la foto, e in basso
// Condividi, Preferita, Informazioni ed Elimina.
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: app
    color: tel.pal.sfondo
    property var elenco: []                   // tutte le foto
    property string scheda: "libreria"        // libreria | perte | album | cerca | account
    property string filtro: ""                // "" = tutte, oppure una fonte, un album o «preferite»
    property string ricerca: ""
    property var servizi: []
    property int aperta: -1
    property bool comandi: true
    property bool selezionando: false
    property var scelte: ({})                 // percorso → true (in «Seleziona»)
    readonly property int quanteScelte: Object.keys(scelte).length
    readonly property color sezione: tel.pal.superficie
    readonly property var nomiFonte: ({ telefono: I18n.t("Telefono"), nextcloud: "Nextcloud", onedrive: "OneDrive", dropbox: "Dropbox", google: "Google Foto" })
    readonly property var coloriFonte: ({ nextcloud: "#0082C9", onedrive: "#0078D4", dropbox: "#0061FE", google: "#4285F4" })
    // Le foto mostrate (filtro o ricerca) e raggruppate per giorno
    readonly property var vista: elenco.filter(function (f) {
        if (scheda === "cerca") {
            var t = ricerca.toLowerCase()
            return t.length > 1 && (f.nome.toLowerCase().indexOf(t) >= 0 || f.giorno.toLowerCase().indexOf(t) >= 0 || (nomiFonte[f.fonte] || "").toLowerCase().indexOf(t) >= 0)
        }
        return !filtro || f.fonte === filtro || f.album === filtro || (filtro === "preferite" && f.preferita)
    })
    readonly property var giorni: {
        var g = [], ultimo = null
        for (var i = 0; i < vista.length; i++) {
            if (!ultimo || ultimo.chiave !== vista[i].giorno) { ultimo = { chiave: vista[i].giorno, giorno: vista[i].giorno + (vista[i].luogo ? " · " + vista[i].luogo : ""), foto: [] }; g.push(ultimo) }
            ultimo.foto.push({ f: vista[i], i: i })
        }
        return g
    }
    readonly property var fonti: { var f = []; for (var i = 0; i < elenco.length; i++) if (f.indexOf(elenco[i].fonte) < 0) f.push(elenco[i].fonte); var o = ["telefono", "google", "onedrive", "nextcloud", "dropbox"]; return f.sort(function (a, b) { return o.indexOf(a) - o.indexOf(b) }) }
    readonly property var fotoAperta: aperta >= 0 ? vista[aperta] : null

    function aggiorna() { elenco = ponte.chiama0("foto"); servizi = ponte.chiama0("fotoServizi") }
    function apri(i) { aperta = i; comandi = true; vistaGrande.currentIndex = i; Qt.callLater(function () { vistaGrande.positionViewAtIndex(app.aperta, ListView.Beginning) }) }
    function scegli(f) { var s = Object.assign({}, scelte); if (s[f.percorso]) delete s[f.percorso]; else s[f.percorso] = true; scelte = s }
    onVisibleChanged: if (visible) { aggiorna(); ponte.avvia("fotoSincronizza", [], "foto-sinc") }
    Component.onCompleted: {
        aggiorna()
        var s = ponte.chiama0("avvio").schermata
        if (s === "foto-account") scheda = "account"
        else if (s === "foto-google") { scheda = "account"; sceltaGoogle.apri() }
        else if (s === "foto-una") aperturaProva.start()
    }
    Timer { id: aperturaProva; interval: 300; onTriggered: { var i = app.elenco.findIndex(function (f) { return f.fonte === "onedrive" }); app.apri(Math.max(0, i)) } }
    Connections { target: ponte; function onCompletato(id, r) { if (id === "foto-sinc") app.aggiorna() } }

    // ── Pezzi comuni ─────────────────────────────────────────────────────
    // Simbolino del servizio sulla miniatura
    component Fonte: Rectangle {
        id: fo
        property string fonte: ""
        property int lato: 20
        visible: fonte !== "" && fonte !== "telefono"
        width: lato; height: lato; radius: lato / 2
        color: fonte === "google" ? "#FFFFFF" : (app.coloriFonte[fonte] || "#71717A")
        border.width: 1.5; border.color: "#FFFFFF"
        // Google: la «G» a quattro colori
        Canvas {
            visible: fo.fonte === "google"
            anchors.fill: parent; anchors.margins: fo.lato * 0.2
            onPaint: {
                var c = getContext("2d"), w = width, r = w * 0.36, cx = w / 2, cy = w / 2
                c.reset(); c.lineWidth = w * 0.2
                var archi = [["#EA4335", -2.4, -0.75], ["#FBBC05", 2.3, 3.9], ["#34A853", 0.6, 2.35], ["#4285F4", 0, 0.62]]
                for (var i = 0; i < archi.length; i++) { c.strokeStyle = archi[i][0]; c.beginPath(); c.arc(cx, cy, r, archi[i][1], archi[i][2]); c.stroke() }
                c.fillStyle = "#4285F4"; c.fillRect(cx, cy - w * 0.1, r + w * 0.1, w * 0.2)
            }
        }
        Text { visible: fo.fonte !== "google"; anchors.centerIn: parent; text: (app.nomiFonte[fo.fonte] || "?").charAt(0); color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: fo.lato * 0.5; font.weight: Font.Bold }
    }
    component Interruttore2: Rectangle {
        property bool acceso: false
        signal cambia(bool si)
        width: 46; height: 28; radius: 14
        color: acceso ? tel.accento : tel.pal.superficie2
        Rectangle { width: 22; height: 22; radius: 11; y: 3; x: parent.acceso ? 21 : 3; color: "#FFFFFF"; Behavior on x { NumberAnimation { duration: tel.tNormale; easing.type: Easing.OutQuint } } }
        MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: parent.cambia(!parent.acceso) }
    }
    component Pillola: Rectangle {
        id: pl
        property string testo: ""
        property bool attiva: false
        signal tocco()
        height: 30; width: etPl.implicitWidth + 24; radius: 15
        property bool blu: false
        color: attiva ? tel.accento : tel.pal.superficie2
        Text { id: etPl; anchors.centerIn: parent; text: pl.testo; color: pl.attiva ? "#FFFFFF" : (pl.blu ? tel.accento : tel.pal.testo); font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
        MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: pl.tocco() }
    }
    // Griglia per giorni (Libreria e Cerca)
    component Giorni: Flickable {
        id: gg
        contentHeight: colGiorni.height + 20
        clip: true
        Column {
            id: colGiorni
            width: gg.width
            Repeater {
                model: app.giorni
                Column {
                    id: blocco
                    required property var modelData
                    width: colGiorni.width
                    Text { x: 16; topPadding: 12; bottomPadding: 8; text: blocco.modelData.giorno; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(17); font.weight: Font.Bold }
                    Grid {
                        id: grigliaG
                        columns: 4; spacing: 2
                        readonly property real lato: Math.floor((colGiorni.width - 6) / 4)
                        Repeater {
                            model: blocco.modelData.foto
                            Item {
                                id: mini
                                required property var modelData
                                width: grigliaG.lato; height: grigliaG.lato
                                Image {
                                    anchors.fill: parent
                                    source: mini.modelData.f.uri
                                    sourceSize.width: 240; sourceSize.height: 240
                                    fillMode: Image.PreserveAspectCrop; asynchronous: true
                                    Rectangle { anchors.fill: parent; color: tel.pal.traccia; visible: parent.status !== Image.Ready }
                                }
                                Fonte { anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 5; fonte: mini.modelData.f.fonte }
                                // Scelta (in «Seleziona»)
                                Rectangle {
                                    visible: app.selezionando
                                    anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 6
                                    width: 24; height: 24; radius: 12
                                    color: app.scelte[mini.modelData.f.percorso] ? tel.accento : "#33000000"
                                    border.width: 2; border.color: "#FFFFFF"
                                    Text { anchors.centerIn: parent; visible: !!app.scelte[mini.modelData.f.percorso]; text: "✓"; color: "#FFFFFF"; font.pixelSize: 13; font.bold: true }
                                }
                                MouseArea { anchors.fill: parent; onClicked: app.selezionando ? app.scegli(mini.modelData.f) : app.apri(mini.modelData.i) }
                            }
                        }
                    }
                }
            }
        }
    }

    // ══ Libreria ═════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent; anchors.bottomMargin: 82
        visible: app.scheda === "libreria"
        Punti { x: 18; y: 54; text: app.filtro === "preferite" ? I18n.t("Preferite") : I18n.t("Libreria") }
        Pillola {
            anchors.right: parent.right; anchors.rightMargin: 16; y: 62
            testo: app.selezionando ? I18n.t("Annulla") : I18n.t("Seleziona")
            onTocco: { app.selezionando = !app.selezionando; app.scelte = {} }
        }
        Flickable {
            x: 0; y: 106; width: parent.width; height: 30
            contentWidth: filtri.width + 32; clip: true
            flickableDirection: Flickable.HorizontalFlick; boundsBehavior: Flickable.StopAtBounds
        Row {
            id: filtri
            x: 16; spacing: 6
            Repeater {
                model: [""].concat(app.fonti)
                Pillola {
                    required property string modelData
                    testo: modelData ? app.nomiFonte[modelData] : I18n.t("Tutte")
                    attiva: app.filtro === modelData
                    onTocco: app.filtro = modelData
                }
            }
        }
        }
        Giorni { x: 0; y: 140; width: parent.width; height: parent.height - y }
        Column {
            visible: app.vista.length === 0
            anchors.centerIn: parent; spacing: 10
            Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: "camera-photo-symbolic"; lato: 48 }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Nessuna foto"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(18); font.weight: Font.DemiBold }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Le foto scattate e scaricate compaiono qui"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(14) }
        }
    }

    // ══ Per te: i ricordi (i giorni con più foto) ═════════════════════════
    Flickable {
        anchors.fill: parent; anchors.bottomMargin: 82
        visible: app.scheda === "perte"
        contentHeight: colPerTe.height + 40
        clip: true
        Column {
            id: colPerTe
            x: 16; width: parent.width - 32; spacing: 14
            Item { width: 1; height: 44 }
            Punti { text: I18n.t("Per te") }
            Text { text: I18n.t("Ricordi"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(20); font.weight: Font.Bold }
            Repeater {
                model: app.giorni.slice().sort(function (a, b) { return b.foto.length - a.foto.length }).slice(0, 6)
                Rectangle {
                    id: ricordo
                    required property var modelData
                    width: colPerTe.width; height: 220; radius: 20; clip: true; color: tel.pal.superficie2
                    Image { anchors.fill: parent; source: ricordo.modelData.foto[0].f.uri; fillMode: Image.PreserveAspectCrop; sourceSize.width: 720; asynchronous: true }
                    Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0.45; color: "transparent" } GradientStop { position: 1; color: "#A6000000" } } }
                    Column {
                        x: 18; anchors.bottom: parent.bottom; anchors.bottomMargin: 16
                        Text { text: ricordo.modelData.giorno; color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(24); font.weight: Font.Bold }
                        Text { text: ricordo.modelData.foto.length + " " + I18n.t("foto"); color: "#D9FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(13) }
                    }
                    MouseArea { anchors.fill: parent; onClicked: { app.filtro = ""; app.scheda = "libreria"; app.apri(ricordo.modelData.foto[0].i) } }
                }
            }
        }
    }

    // ══ Album ════════════════════════════════════════════════════════════
    Flickable {
        anchors.fill: parent; anchors.bottomMargin: 82
        visible: app.scheda === "album"
        contentHeight: colAlbum.height + 40
        clip: true
        Column {
            id: colAlbum
            x: 16; width: parent.width - 32; spacing: 14
            Item { width: 1; height: 44 }
            Punti { text: I18n.t("Album") }
            // Account collegati
            Rectangle {
                width: parent.width; height: 64; radius: 14; color: tel.pal.superficie
                Row {
                    x: 14; anchors.verticalCenter: parent.verticalCenter; spacing: -8
                    Repeater { model: ["google", "onedrive", "nextcloud"]; Fonte { required property string modelData; fonte: modelData; lato: 30 } }
                }
                Column {
                    x: 92; anchors.verticalCenter: parent.verticalCenter
                    Text { text: I18n.t("Account collegati"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.DemiBold }
                    Text { text: app.servizi.filter(function (s) { return s.stato === "collegato" }).length + " " + I18n.t("collegati"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12.5) }
                }
                Text { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; text: "›"; color: tel.pal.testo2; font.pixelSize: 24 }
                MouseArea { anchors.fill: parent; onClicked: app.scheda = "account" }
            }
            Text { text: I18n.t("I miei album"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(20); font.weight: Font.Bold }
            Grid {
                columns: 2; spacing: 14
                Repeater {
                    model: [{ k: "", t: I18n.t("Recenti") }, { k: "preferite", t: I18n.t("Preferite") }, { k: "fotocamera", t: I18n.t("Fotocamera") }, { k: "schermate", t: I18n.t("Schermate") }, { k: "scaricati", t: I18n.t("Scaricati") }]
                        .concat(app.fonti.filter(function (f) { return f !== "telefono" }).map(function (f) { return { k: f, t: app.nomiFonte[f] } }))
                    Column {
                        id: alb
                        required property var modelData
                        readonly property var dentro: app.elenco.filter(function (f) { return !alb.modelData.k || f.album === alb.modelData.k || f.fonte === alb.modelData.k || (alb.modelData.k === "preferite" && f.preferita) })
                        visible: dentro.length > 0 || !modelData.k || modelData.k === "preferite"
                        width: (colAlbum.width - 14) / 2; spacing: 4
                        Rectangle {
                            width: parent.width; height: width; radius: 14; clip: true; color: tel.pal.superficie2
                            Image { anchors.fill: parent; source: alb.dentro.length ? alb.dentro[0].uri : ""; fillMode: Image.PreserveAspectCrop; sourceSize.width: 360; asynchronous: true }
                            Icona { anchors.centerIn: parent; visible: alb.dentro.length === 0; nome: "starred-symbolic"; lato: 36; opacity: 0.5 }
                            Fonte { anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8; lato: 24; fonte: app.coloriFonte[alb.modelData.k] ? alb.modelData.k : "" }
                            MouseArea { anchors.fill: parent; onClicked: { app.filtro = alb.modelData.k; app.scheda = "libreria" } }
                        }
                        Text { text: alb.modelData.t; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.DemiBold }
                        Text { text: alb.dentro.length + " " + I18n.t("foto"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }
                    }
                }
            }
        }
    }

    // ══ Cerca ════════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent; anchors.bottomMargin: 82
        visible: app.scheda === "cerca"
        Punti { x: 18; y: 54; text: I18n.t("Cerca") }
        CampoCerca {
            x: 16; y: 106; width: parent.width - 32
            suggerimento: I18n.t("Giorni, nomi, Google Foto…")
            onTextChanged: app.ricerca = text.trim()
        }
        Giorni { x: 0; y: 156; width: parent.width; height: parent.height - y; visible: app.ricerca.length > 1 }
        Text {
            visible: app.ricerca.length > 1 && app.vista.length === 0
            x: 20; y: 170; text: I18n.t("Nessuna foto trovata"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(15)
        }
    }

    // ══ Account collegati ════════════════════════════════════════════════
    Flickable {
        anchors.fill: parent
        visible: app.scheda === "account"
        contentHeight: colAcc.height + 60
        clip: true
        Column {
            id: colAcc
            x: 16; width: parent.width - 32; spacing: 14
            Item {
                width: parent.width; height: 92
                Row {
                    y: 56; spacing: 2
                    Icona { anchors.verticalCenter: parent.verticalCenter; nome: "go-previous-symbolic"; lato: 20 }
                    Text { text: I18n.t("Album"); color: tel.accento; font.family: Tema.font; font.pixelSize: tel.px(16) }
                }
                MouseArea { y: 46; width: 110; height: 40; onClicked: app.scheda = "album" }
            }
            Punti { text: I18n.t("Account collegati"); font.pixelSize: 30 }
            Text { width: parent.width; wrapMode: Text.Wrap; text: I18n.t("Le foto dei tuoi account compaiono nella Libreria con il simbolino del servizio. Scegli tu cosa portare sul telefono."); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13.5); lineHeight: 1.15 }
            // Account collegati: ognuno nel suo riquadro, con le sue impostazioni
            Repeater {
                model: app.servizi.filter(function (s) { return s.stato === "collegato" }).sort(function (a, b) { return (a.id === "google" ? 0 : 1) - (b.id === "google" ? 0 : 1) })
                Rectangle {
                    id: srv
                    required property var modelData
                    width: colAcc.width; height: colSrv.height; radius: 14; color: tel.pal.superficie
                    Column {
                        id: colSrv
                        width: parent.width
                        Item {
                            width: parent.width; height: 62
                            Fonte { x: 14; anchors.verticalCenter: parent.verticalCenter; fonte: srv.modelData.id; lato: 34 }
                            Column {
                                x: 62; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 62 - 96
                                Text { text: srv.modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15.5); font.weight: Font.DemiBold }
                                Text { width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12.5)
                                       text: srv.modelData.id === "google" ? (srv.modelData.account.utente || "") + " · " + (srv.modelData.account.album || 0) + " " + I18n.t("album") + ", " + (srv.modelData.account.foto || 0) + " " + I18n.t("foto scelte")
                                             : (srv.modelData.account.cartella ? I18n.t("Cartella") + " " + srv.modelData.account.cartella : (srv.modelData.account.utente || "")) + (srv.modelData.account.auto !== false ? " · " + I18n.t("sincronizzata") : "") }
                            }
                            Text { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Collegato"); color: tel.pal.successo; font.family: Tema.font; font.pixelSize: tel.px(12); font.weight: Font.DemiBold }
                        }
                        Repeater {
                            model: srv.modelData.id !== "google" ? [{ k: "auto", t: I18n.t("Sincronizza in automatico") }, { k: "wifi", t: I18n.t("Solo con il Wi-Fi") }, { k: "scarica", t: I18n.t("Scarica le foto sul telefono") }] : []
                            Item {
                                id: imp
                                required property var modelData
                                width: colSrv.width; height: 48
                                Rectangle { width: parent.width - 62; x: 62; height: 1; color: tel.pal.bordo }
                                Text { x: 62; anchors.verticalCenter: parent.verticalCenter; text: imp.modelData.t; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(14.5) }
                                Interruttore2 {
                                    anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                                    acceso: srv.modelData.account[imp.modelData.k] !== false
                                    onCambia: function (si) { ponte.chiama("fotoImposta", [srv.modelData.id, imp.modelData.k, si]); app.aggiorna() }
                                }
                            }
                        }
                        Item {
                            width: colSrv.width; height: 48
                            Rectangle { width: parent.width - 62; x: 62; height: 1; color: tel.pal.bordo }
                            Text { x: 62; anchors.verticalCenter: parent.verticalCenter; text: srv.modelData.id === "google" ? I18n.t("Scegli altre foto o album…") : I18n.t("Scollega"); color: srv.modelData.id === "google" ? tel.accento : tel.rosso; font.family: Tema.font; font.pixelSize: tel.px(14.5); font.weight: Font.Medium }
                            MouseArea { anchors.fill: parent; onClicked: { if (srv.modelData.id === "google") sceltaGoogle.apri(); else { var r = ponte.chiama("fotoScollega", [srv.modelData.id]); tel.avviso(r.messaggio); app.aggiorna() } } }
                        }
                    }
                }
            }
            // Gli altri servizi, insieme in un riquadro
            Rectangle {
                readonly property var altri: app.servizi.filter(function (s) { return s.stato !== "collegato" })
                visible: altri.length > 0
                width: colAcc.width; height: colAltri.height; radius: 14; color: tel.pal.superficie
                Column {
                    id: colAltri
                    width: parent.width
                    Repeater {
                        model: parent.parent.altri
                        Item {
                            id: alt
                            required property var modelData
                            required property int index
                            width: colAltri.width; height: 62
                            opacity: modelData.stato === "impossibile" ? 0.55 : 1
                            Rectangle { visible: alt.index > 0; width: parent.width - 62; x: 62; height: 1; color: tel.pal.bordo }
                            Rectangle {
                                x: 14; anchors.verticalCenter: parent.verticalCenter; width: 34; height: 34; radius: 17
                                readonly property bool spento: alt.modelData.stato === "impossibile"
                                color: spento ? "transparent" : alt.modelData.colore
                                border.width: spento ? 1.5 : 0; border.color: tel.pal.testo2
                                Text { anchors.centerIn: parent; text: alt.modelData.lettera; color: parent.spento ? tel.pal.testo2 : "#FFFFFF"; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.Bold }
                            }
                            Column {
                                x: 62; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 62 - (alt.modelData.stato === "impossibile" ? 12 : 96)
                                Text { text: alt.modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15.5); font.weight: Font.DemiBold }
                                Text { width: parent.width; elide: Text.ElideRight; text: alt.modelData.descrizione; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12.5) }
                            }
                            Pillola {
                                visible: alt.modelData.stato !== "impossibile"
                                anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                                testo: I18n.t("Collega"); blu: true
                                onTocco: {
                                    if (alt.modelData.id === "nextcloud") collegaNc.open()
                                    else tel.avviso(alt.modelData.nome + ": " + I18n.t("arriva quando SolidOS sarà registrato sul servizio"))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Collega Nextcloud
    Popup {
        id: collegaNc
        anchors.centerIn: parent
        width: parent.width - 32; modal: true; padding: 18
        background: Rectangle { radius: 20; color: tel.pal.superficie }
        Column {
            width: parent.width; spacing: 12
            Text { text: I18n.t("Collega Nextcloud"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(19); font.weight: Font.Bold }
            Text { width: parent.width; wrapMode: Text.Wrap; text: I18n.t("Su Nextcloud crea una «password per le app» in Impostazioni › Sicurezza e scrivila qui (non la password normale)."); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13) }
            CampoTesto { id: ncUrl; width: parent.width; placeholderText: I18n.t("Indirizzo, es. cloud.esempio.it"); inputMethodHints: Qt.ImhUrlCharactersOnly }
            CampoTesto { id: ncUtente; width: parent.width; placeholderText: I18n.t("Nome utente") }
            CampoTesto { id: ncPw; width: parent.width; placeholderText: I18n.t("Password per le app"); echoMode: TextInput.Password }
            CampoTesto { id: ncCartella; width: parent.width; text: "Photos"; placeholderText: I18n.t("Cartella delle foto") }
            Row {
                spacing: 10; anchors.right: parent.right
                Pulsante { text: I18n.t("Annulla"); onClicked: collegaNc.close() }
                Pulsante {
                    text: I18n.t("Collega"); principale: true
                    onClicked: { var r = ponte.chiama("fotoCollegaNextcloud", [ncUrl.text, ncUtente.text, ncPw.text, ncCartella.text]); tel.avviso(r.messaggio); if (r.ok) { ncPw.text = ""; collegaNc.close(); app.aggiorna() } }
                }
            }
        }
    }

    // ══ Barra in basso: schede, oppure le azioni di «Seleziona» ══════════
    Rectangle {
        visible: app.aperta < 0 && app.scheda !== "account"
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 82; color: tel.pal.superficie
        Rectangle { width: parent.width; height: 1; color: tel.pal.bordo }
        Row {
            visible: !app.selezionando
            anchors.horizontalCenter: parent.horizontalCenter; y: 8
            Repeater {
                model: [{ s: "libreria", t: I18n.t("Libreria"), i: "linea-foto" }, { s: "perte", t: I18n.t("Per te"), i: "starred-symbolic" },
                        { s: "album", t: I18n.t("Album"), i: "linea-file" }, { s: "cerca", t: I18n.t("Cerca"), i: "system-search-symbolic" }]
                Item {
                    id: tabF
                    required property var modelData
                    width: (app.width - 20) / 4; height: 50
                    Column {
                        anchors.centerIn: parent; spacing: 3
                        opacity: app.scheda === tabF.modelData.s ? 1 : 0.55
                        Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: tabF.modelData.i; lato: 22 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: tabF.modelData.t; color: app.scheda === tabF.modelData.s ? tel.accento : tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(11); font.weight: Font.DemiBold }
                    }
                    MouseArea { anchors.fill: parent; onClicked: { app.scheda = tabF.modelData.s; if (tabF.modelData.s !== "libreria") app.filtro = "" } }
                }
            }
        }
        Item {
            visible: app.selezionando
            anchors.fill: parent
            Icona { x: 24; y: 16; nome: "linea-esporta"; lato: 24; opacity: app.quanteScelte ? 1 : 0.4
                    MouseArea { anchors.fill: parent; anchors.margins: -10; enabled: app.quanteScelte > 0; onClicked: { tel.condividi(Object.keys(app.scelte)); app.selezionando = false; app.scelte = {} } } }
            Text { anchors.horizontalCenter: parent.horizontalCenter; y: 18; text: app.quanteScelte ? app.quanteScelte + " " + I18n.t("selezionate") : I18n.t("Seleziona le foto"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.DemiBold }
            Icona { anchors.right: parent.right; anchors.rightMargin: 24; y: 16; nome: "user-trash-symbolic"; lato: 24; opacity: app.quanteScelte ? 1 : 0.4
                    MouseArea { anchors.fill: parent; anchors.margins: -10; enabled: app.quanteScelte > 0; onClicked: elimina.open() } }
        }
    }

    // ══ A tutto schermo ══════════════════════════════════════════════════
    Rectangle {
        anchors.fill: parent
        visible: app.aperta >= 0
        color: "#000000"
        ListView {
            id: vistaGrande
            anchors.fill: parent
            anchors.topMargin: 112; anchors.bottomMargin: 170
            orientation: ListView.Horizontal
            snapMode: ListView.SnapOneItem; highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: 0; preferredHighlightEnd: width
            boundsBehavior: Flickable.StopAtBounds
            model: app.vista
            onCurrentIndexChanged: if (app.aperta >= 0) app.aperta = currentIndex
            delegate: Item {
                required property var modelData
                width: vistaGrande.width; height: vistaGrande.height
                Image { anchors.fill: parent; source: parent.modelData.uri; fillMode: Image.PreserveAspectFit; asynchronous: true; sourceSize.width: 1400 }
                TapHandler { onTapped: app.comandi = !app.comandi }
            }
        }
        // In alto: indietro, giorno e ora, Modifica
        Item {
            visible: app.comandi
            width: parent.width; height: 100
            Icona {
                x: 16; y: 62; nome: "go-previous-symbolic"; lato: 22; tema: "scuro"
                MouseArea { anchors.fill: parent; anchors.margins: -12; onClicked: app.aperta = -1 }
            }
            Column {
                anchors.horizontalCenter: parent.horizontalCenter; y: 54
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: app.fotoAperta ? app.fotoAperta.giorno : ""; color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.DemiBold }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: app.fotoAperta ? app.fotoAperta.data.split(" ")[1] + (app.fotoAperta.luogo ? " · " + app.fotoAperta.luogo : "") : ""; color: "#B3FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(12) }
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 16; y: 60
                text: I18n.t("Modifica"); color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(16)
                MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: tel.avviso(I18n.t("La modifica delle foto arriva più avanti")) }
            }
        }
        // Da dove arriva la foto (account collegato)
        Rectangle {
            visible: app.comandi && app.fotoAperta && app.fotoAperta.fonte !== "telefono"
            x: 16; width: parent.width - 32; height: 52; radius: 14
            anchors.bottom: parent.bottom; anchors.bottomMargin: 110
            color: Qt.rgba(1, 1, 1, 0.12)
            Fonte { x: 12; anchors.verticalCenter: parent.verticalCenter; lato: 26; fonte: app.fotoAperta ? app.fotoAperta.fonte : "" }
            Column {
                x: 50; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 90
                Text { width: parent.width; elide: Text.ElideRight; text: app.fotoAperta ? I18n.t("Da") + " " + app.nomiFonte[app.fotoAperta.fonte] + (app.fotoAperta.dove ? " · " + app.fotoAperta.dove : "") : ""; color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                Text { text: app.fotoAperta && app.fotoAperta.fonte === "nextcloud" ? I18n.t("Copiata sul telefono dal tuo account") : I18n.t("Si apre dal cloud, non occupa spazio"); color: "#B3FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(11.5) }
            }
            Icona { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; nome: "linea-nuvola"; lato: 18; tema: "scuro" }
        }
        // In basso: Condividi, Preferita, Informazioni, Elimina
        Row {
            visible: app.comandi
            anchors.bottom: parent.bottom; anchors.bottomMargin: 30
            x: 0; width: parent.width
            Repeater {
                model: [{ k: "condividi", i: "linea-esporta" }, { k: "preferita", i: "starred-symbolic" }, { k: "info", i: "help-about-symbolic" }, { k: "elimina", i: "user-trash-symbolic" }]
                Item {
                    id: azF
                    required property var modelData
                    width: parent.width / 4; height: 40
                    Icona { anchors.centerIn: parent; nome: azF.modelData.i; lato: 24; tema: "scuro"
                            opacity: azF.modelData.k === "preferita" && !(app.fotoAperta && app.fotoAperta.preferita) ? 0.75 : 1 }
                    Text { visible: azF.modelData.k === "preferita" && !!(app.fotoAperta && app.fotoAperta.preferita); anchors.centerIn: parent; text: "★"; color: "#FFFFFF"; font.pixelSize: 26 }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            var f = app.fotoAperta
                            if (!f) return
                            if (azF.modelData.k === "condividi") tel.condividi([f.percorso])
                            else if (azF.modelData.k === "preferita") { var i = app.aperta; ponte.chiama("fotoPreferita", [f.percorso, !f.preferita]); app.aggiorna(); app.apri(Math.min(i, app.vista.length - 1)) }
                            else if (azF.modelData.k === "info") informazioni.open()
                            else elimina.open()
                        }
                    }
                }
            }
        }
    }

    // Informazioni sulla foto
    Popup {
        id: informazioni
        anchors.centerIn: parent
        width: parent.width - 40; modal: true; padding: 20
        background: Rectangle { radius: 20; color: tel.pal.superficie }
        Column {
            width: parent.width; spacing: 10
            Text { width: parent.width; elide: Text.ElideMiddle; text: app.fotoAperta ? app.fotoAperta.nome : ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(17); font.weight: Font.Bold }
            Text { text: app.fotoAperta ? app.fotoAperta.data : ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(14) }
            Text { text: app.fotoAperta ? I18n.t("Da") + " " + app.nomiFonte[app.fotoAperta.fonte] : ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(14) }
            Row {
                spacing: 10; anchors.right: parent.right
                Pulsante { text: I18n.t("Usa come sfondo"); onClicked: { var r = ponte.chiama("sfondoFoto", [app.fotoAperta.percorso]); tel.imp = ponte.chiama0("impostazioni"); tel.avviso(r.messaggio); informazioni.close() } }
                Pulsante { text: I18n.t("Chiudi"); principale: true; onClicked: informazioni.close() }
            }
        }
    }

    // Elimina (una foto, o quelle selezionate)
    Popup {
        id: elimina
        anchors.centerIn: parent
        width: parent.width - 60; modal: true; padding: 20
        background: Rectangle { radius: 20; color: app.sezione }
        Column {
            width: parent.width; spacing: 14
            Text { width: parent.width; wrapMode: Text.Wrap; text: app.selezionando ? I18n.t("Spostare le foto selezionate nel Cestino?") : I18n.t("Spostare la foto nel Cestino?"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.DemiBold }
            Row {
                spacing: 10; anchors.right: parent.right
                Pulsante { text: I18n.t("Annulla"); onClicked: elimina.close() }
                Pulsante {
                    text: I18n.t("Elimina"); pericoloso: true
                    onClicked: {
                        if (app.selezionando) {
                            var p = Object.keys(app.scelte)
                            for (var k = 0; k < p.length; k++) ponte.chiama("cestinaFile", [p[k]])
                            app.selezionando = false; app.scelte = {}
                            elimina.close(); app.aggiorna(); return
                        }
                        var i = app.aperta
                        ponte.chiama("cestinaFile", [app.vista[i].percorso])
                        elimina.close(); app.aggiorna()
                        if (app.vista.length === 0) app.aperta = -1
                        else app.apri(Math.min(i, app.vista.length - 1))
                    }
                }
            }
        }
    }

    // ══ Foglio «Scegli da Google Foto» ════════════════════════════════════
    Rectangle {
        anchors.fill: parent; color: "#66000000"
        opacity: sceltaGoogle.aperto ? 1 : 0; visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: tel.tNormale } }
        MouseArea { anchors.fill: parent; onClicked: sceltaGoogle.aperto = false }
    }
    Rectangle {
        id: sceltaGoogle
        property bool aperto: false
        property var album: []
        property var scelti: ({})
        function apri() {
            // Senza la registrazione su Google si vede cosa si potrà fare (foto di prova)
            var g = app.giorni.slice(0, 4)
            album = g.map(function (x, i) { return { nome: [I18n.t("Vacanze 2026"), I18n.t("Famiglia"), I18n.t("Laurea di Sara"), I18n.t("Cani e gatti")][i] || x.giorno, n: [124, 308, 36, 57][i] || x.foto.length, uri: x.foto[0].f.uri } })
            scelti = ({ 2: true })
            aperto = true
        }
        x: 0; width: parent.width; height: parent.height - 96
        y: aperto ? 96 : parent.height
        visible: y < parent.height
        Behavior on y { Movimento { apre: sceltaGoogle.aperto } }
        radius: 24; color: tel.pal.superficie
        MouseArea { anchors.fill: parent }
        Column {
            x: 16; y: 12; width: sceltaGoogle.width - 32; spacing: 14
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 40; height: 5; radius: 3; color: tel.pal.bordo }
            Item {
                width: parent.width; height: 26
                Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Annulla"); color: tel.accento; font.family: Tema.font; font.pixelSize: tel.px(15)
                       MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: sceltaGoogle.aperto = false } }
                Row {
                    anchors.centerIn: parent; spacing: 8
                    Fonte { anchors.verticalCenter: parent.verticalCenter; fonte: "google"; lato: 22 }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Google Foto"; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.Bold }
                }
                Text {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    readonly property int n: { var t = 0; for (var k in sceltaGoogle.scelti) if (sceltaGoogle.scelti[k]) t += sceltaGoogle.album[k] ? sceltaGoogle.album[k].n : 0; return t }
                    text: I18n.t("Aggiungi") + " (" + n + ")"; color: tel.accento; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.Bold
                    MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: { sceltaGoogle.aperto = false; tel.avviso(I18n.t("Google Foto si attiva quando SolidOS sarà registrato su Google")) } }
                }
            }
            Text { width: parent.width; wrapMode: Text.Wrap; text: I18n.t("Google permette di scegliere le foto o gli album da portare su SolidOS: quelle che scegli si aggiornano quando apri Foto."); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13); lineHeight: 1.15 }
            Row {
                spacing: 6
                Repeater { model: [I18n.t("Album"), I18n.t("Foto"), I18n.t("Persone")]; Pillola { required property string modelData; required property int index; testo: modelData; attiva: index === 0 } }
            }
            Grid {
                columns: 2; spacing: 12
                Repeater {
                    model: sceltaGoogle.album
                    Column {
                        id: albG
                        required property var modelData
                        required property int index
                        width: (sceltaGoogle.width - 32 - 12) / 2; spacing: 4
                        Rectangle {
                            width: parent.width; height: width; radius: 14; clip: true; color: tel.pal.superficie2
                            Image { anchors.fill: parent; source: albG.modelData.uri; fillMode: Image.PreserveAspectCrop; sourceSize.width: 360; asynchronous: true }
                            Rectangle {
                                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8
                                width: 26; height: 26; radius: 13
                                color: sceltaGoogle.scelti[albG.index] ? tel.accento : "#33000000"
                                border.width: 2; border.color: "#FFFFFF"
                                Text { anchors.centerIn: parent; visible: !!sceltaGoogle.scelti[albG.index]; text: "✓"; color: "#FFFFFF"; font.pixelSize: 14; font.bold: true }
                            }
                            MouseArea { anchors.fill: parent; onClicked: { var s = Object.assign({}, sceltaGoogle.scelti); s[albG.index] = !s[albG.index]; sceltaGoogle.scelti = s } }
                        }
                        Text { text: albG.modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.DemiBold }
                        Text { text: albG.modelData.n + " " + I18n.t("foto"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }
                    }
                }
            }
        }
    }
}
