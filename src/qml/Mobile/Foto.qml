// Foto: Libreria per giorni (la più recente in alto), Album e Account collegati. Le foto
// arrivano dal telefono (Fotocamera, Immagini, Scaricati, DCIM) e dagli account collegati
// (Nextcloud…): un simbolino sulla miniatura dice da dove arriva. Tocca per vederla a tutto
// schermo; scorri di lato per la successiva. Azioni: Condividi (Vicina), Sfondo, Elimina.
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: app
    color: tel.pal.sfondo
    property var elenco: []                   // tutte le foto
    property string scheda: "libreria"        // libreria | album | account
    property string filtro: ""                // "" = tutte, oppure una fonte o un album
    property var servizi: []
    property int aperta: -1
    property bool comandi: true
    readonly property color sezione: tel.pal.superficie
    readonly property var nomiFonte: ({ telefono: I18n.t("Telefono"), nextcloud: "Nextcloud", onedrive: "OneDrive", dropbox: "Dropbox", google: "Google Foto" })
    readonly property var coloriFonte: ({ nextcloud: "#0082C9", onedrive: "#0078D4", dropbox: "#0061FE", google: "#4285F4" })
    // Le foto mostrate (con il filtro) e raggruppate per giorno
    readonly property var vista: elenco.filter(function (f) { return !filtro || f.fonte === filtro || f.album === filtro })
    readonly property var giorni: {
        var g = [], ultimo = null
        for (var i = 0; i < vista.length; i++) {
            if (!ultimo || ultimo.giorno !== vista[i].giorno) { ultimo = { giorno: vista[i].giorno, foto: [] }; g.push(ultimo) }
            ultimo.foto.push({ f: vista[i], i: i })
        }
        return g
    }
    readonly property var fonti: { var f = []; for (var i = 0; i < elenco.length; i++) if (f.indexOf(elenco[i].fonte) < 0) f.push(elenco[i].fonte); return f }

    function aggiorna() { elenco = ponte.chiama0("foto"); servizi = ponte.chiama0("fotoServizi") }
    function apri(i) { aperta = i; comandi = true; vista_.positionViewAtIndex(i, ListView.Beginning); vista_.currentIndex = i }
    onVisibleChanged: if (visible) { aggiorna(); ponte.avvia("fotoSincronizza", [], "foto-sinc") }
    Component.onCompleted: { aggiorna(); if (ponte.chiama0("avvio").schermata === "foto-account") scheda = "account" }
    Connections { target: ponte; function onCompletato(id, r) { if (id === "foto-sinc") app.aggiorna() } }

    // Simbolino del servizio sulla miniatura
    component Fonte: Rectangle {
        property string fonte: ""
        property int lato: 20
        visible: fonte !== "" && fonte !== "telefono"
        width: lato; height: lato; radius: lato / 2
        color: app.coloriFonte[fonte] || "#71717A"
        border.width: 1.5; border.color: "#FFFFFF"
        Text { anchors.centerIn: parent; text: (app.nomiFonte[parent.fonte] || "?").charAt(0); color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: parent.lato * 0.5; font.weight: Font.Bold }
    }
    component Interruttore2: Rectangle {
        property bool acceso: false
        signal cambia(bool si)
        width: 46; height: 28; radius: 14
        color: acceso ? tel.accento : tel.pal.superficie2
        Rectangle { width: 22; height: 22; radius: 11; y: 3; x: parent.acceso ? 21 : 3; color: "#FFFFFF"; Behavior on x { NumberAnimation { duration: tel.tNormale; easing.type: Easing.OutQuint } } }
        MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: parent.cambia(!parent.acceso) }
    }

    // ══ Libreria ═════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent; anchors.bottomMargin: 82
        visible: app.scheda === "libreria"
        Punti { x: 18; y: 56; text: I18n.t("Libreria") }
        // Filtri: tutte, telefono e ogni account che ha foto
        Row {
            x: 16; y: 106; spacing: 6
            Repeater {
                model: [""].concat(app.fonti)
                Rectangle {
                    required property string modelData
                    height: 30; width: etF.implicitWidth + 24; radius: 15
                    color: app.filtro === modelData ? tel.accento : tel.pal.superficie2
                    Text { id: etF; anchors.centerIn: parent; text: parent.modelData ? app.nomiFonte[parent.modelData] : I18n.t("Tutte"); color: app.filtro === parent.modelData ? "#FFFFFF" : tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(12.5); font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; onClicked: app.filtro = parent.modelData }
                }
            }
        }
        Flickable {
            id: libreria
            x: 0; y: 146; width: parent.width; height: parent.height - y
            contentHeight: colGiorni.height + 20
            clip: true
            Column {
                id: colGiorni
                width: libreria.width
                Repeater {
                    model: app.giorni
                    Column {
                        id: blocco
                        required property var modelData
                        width: colGiorni.width
                        Text { x: 18; topPadding: 12; bottomPadding: 8; text: blocco.modelData.giorno; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(17); font.weight: Font.Bold }
                        Grid {
                            columns: 4; spacing: 2
                            readonly property real lato: Math.floor((colGiorni.width - 6) / 4)
                            Repeater {
                                model: blocco.modelData.foto
                                Item {
                                    required property var modelData
                                    width: parent.lato; height: parent.lato
                                    Image {
                                        anchors.fill: parent
                                        source: parent.modelData.f.uri
                                        sourceSize.width: 240; sourceSize.height: 240
                                        fillMode: Image.PreserveAspectCrop; asynchronous: true
                                        Rectangle { anchors.fill: parent; color: tel.pal.traccia; visible: parent.status !== Image.Ready }
                                    }
                                    Fonte { anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 5; fonte: parent.modelData.f.fonte }
                                    MouseArea { anchors.fill: parent; onClicked: app.apri(parent.modelData.i) }
                                }
                            }
                        }
                    }
                }
            }
        }
        Column {
            visible: app.vista.length === 0
            anchors.centerIn: parent; spacing: 10
            Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: "camera-photo-symbolic"; lato: 48 }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Nessuna foto"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(18); font.weight: Font.DemiBold }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Le foto scattate e scaricate compaiono qui"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(14) }
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
            Grid {
                columns: 2; spacing: 14
                Repeater {
                    model: [{ k: "", t: I18n.t("Recenti") }, { k: "fotocamera", t: I18n.t("Fotocamera") }, { k: "schermate", t: I18n.t("Schermate") }, { k: "scaricati", t: I18n.t("Scaricati") }]
                        .concat(app.fonti.filter(function (f) { return f !== "telefono" }).map(function (f) { return { k: f, t: app.nomiFonte[f] } }))
                    Column {
                        id: alb
                        required property var modelData
                        readonly property var dentro: app.elenco.filter(function (f) { return !alb.modelData.k || f.album === alb.modelData.k || f.fonte === alb.modelData.k })
                        visible: dentro.length > 0 || !modelData.k
                        width: (colAlbum.width - 14) / 2; spacing: 4
                        Rectangle {
                            width: parent.width; height: width; radius: 14; clip: true; color: tel.pal.superficie2
                            Image { anchors.fill: parent; source: alb.dentro.length ? alb.dentro[0].uri : ""; fillMode: Image.PreserveAspectCrop; sourceSize.width: 360; asynchronous: true }
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

    // ══ Account collegati ════════════════════════════════════════════════
    Flickable {
        anchors.fill: parent; anchors.bottomMargin: 82
        visible: app.scheda === "account"
        contentHeight: colAcc.height + 40
        clip: true
        Column {
            id: colAcc
            x: 16; width: parent.width - 32; spacing: 14
            Item { width: 1; height: 44 }
            Punti { text: I18n.t("Account collegati"); font.pixelSize: 30 }
            Text { width: parent.width; wrapMode: Text.Wrap; text: I18n.t("Le foto dei tuoi account compaiono nella Libreria con il simbolino del servizio. Scegli tu cosa portare sul telefono."); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13.5) }
            Repeater {
                model: app.servizi
                Rectangle {
                    id: srv
                    required property var modelData
                    readonly property bool collegato: modelData.stato === "collegato"
                    width: colAcc.width; height: colSrv.height; radius: 14; color: tel.pal.superficie
                    opacity: modelData.stato === "impossibile" || modelData.stato === "da_attivare" ? 0.6 : 1
                    Column {
                        id: colSrv
                        width: parent.width
                        Item {
                            width: parent.width; height: 64
                            Rectangle {
                                x: 14; anchors.verticalCenter: parent.verticalCenter; width: 36; height: 36; radius: 18; color: srv.modelData.colore
                                Text { anchors.centerIn: parent; text: srv.modelData.lettera; color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.Bold }
                            }
                            Column {
                                x: 62; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 62 - 104
                                Text { text: srv.modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15.5); font.weight: Font.DemiBold }
                                Text { width: parent.width; elide: Text.ElideRight; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12.5)
                                       text: srv.collegato ? (srv.modelData.account.utente || "") + (srv.modelData.account.cartella ? " · " + srv.modelData.account.cartella : "")
                                             : (srv.modelData.stato === "da_attivare" ? I18n.t("In arrivo: SolidOS va registrato su") + " " + srv.modelData.nome : srv.modelData.descrizione) }
                            }
                            Rectangle {
                                visible: srv.modelData.stato === "collegabile" || srv.collegato
                                anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                                height: 30; width: etS.implicitWidth + 26; radius: 15
                                color: srv.collegato ? "transparent" : tel.pal.superficie2
                                Text { id: etS; anchors.centerIn: parent; text: srv.collegato ? I18n.t("Collegato") : I18n.t("Collega"); color: srv.collegato ? tel.pal.successo : tel.accento; font.family: Tema.font; font.pixelSize: tel.px(12.5); font.weight: Font.Bold }
                                MouseArea { anchors.fill: parent; enabled: !srv.collegato; onClicked: if (srv.modelData.id === "nextcloud") collegaNc.open() }
                            }
                        }
                        // Impostazioni di un account collegato
                        Repeater {
                            model: srv.collegato && srv.modelData.id !== "google" ? [{ k: "auto", t: I18n.t("Sincronizza in automatico") }, { k: "wifi", t: I18n.t("Solo con il Wi-Fi") }, { k: "scarica", t: I18n.t("Scarica le foto sul telefono") }] : []
                            Item {
                                required property var modelData
                                width: colSrv.width; height: 48
                                Rectangle { width: parent.width - 62; x: 62; height: 1; color: tel.pal.bordo }
                                Text { x: 62; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.t; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(14.5) }
                                Interruttore2 {
                                    anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                                    acceso: srv.modelData.account[parent.modelData.k] !== false
                                    onCambia: function (si) { ponte.chiama("fotoImposta", [srv.modelData.id, parent.modelData.k, si]); app.aggiorna() }
                                }
                            }
                        }
                        Item {
                            visible: srv.collegato
                            width: colSrv.width; height: 48
                            Rectangle { width: parent.width - 62; x: 62; height: 1; color: tel.pal.bordo }
                            Text { x: 62; anchors.verticalCenter: parent.verticalCenter; text: srv.modelData.id === "google" ? I18n.t("Scegli altre foto o album…") : I18n.t("Scollega"); color: srv.modelData.id === "google" ? tel.accento : tel.rosso; font.family: Tema.font; font.pixelSize: tel.px(14.5); font.weight: Font.Medium }
                            MouseArea { anchors.fill: parent; onClicked: { if (srv.modelData.id === "google") tel.avviso(I18n.t("Arriva quando SolidOS sarà registrato su Google")); else { var r = ponte.chiama("fotoScollega", [srv.modelData.id]); tel.avviso(r.messaggio); app.aggiorna() } } }
                        }
                    }
                }
            }
            Text {
                width: parent.width; wrapMode: Text.Wrap
                text: I18n.t("Google Foto lascia scegliere foto e album con il suo selettore (non tutta la libreria). Amazon Foto non permette l'accesso alle app esterne.")
                color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12)
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

    // Schede in basso
    Rectangle {
        visible: app.aperta < 0
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 82; color: tel.pal.superficie
        Rectangle { width: parent.width; height: 1; color: tel.pal.bordo }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter; y: 8
            Repeater {
                model: [{ s: "libreria", t: I18n.t("Libreria"), i: "linea-foto" }, { s: "album", t: I18n.t("Album"), i: "view-app-grid-symbolic" }, { s: "account", t: I18n.t("Account"), i: "avatar-default-symbolic" }]
                Item {
                    id: tabF
                    required property var modelData
                    width: (app.width - 20) / 3; height: 50
                    Column {
                        anchors.centerIn: parent; spacing: 3
                        opacity: app.scheda === tabF.modelData.s ? 1 : 0.55
                        Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: tabF.modelData.i; lato: 22 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: tabF.modelData.t; color: app.scheda === tabF.modelData.s ? tel.accento : tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(11); font.weight: Font.DemiBold }
                    }
                    MouseArea { anchors.fill: parent; onClicked: app.scheda = tabF.modelData.s }
                }
            }
        }
    }

    // ══ A tutto schermo ══════════════════════════════════════════════════
    Rectangle {
        anchors.fill: parent
        visible: app.aperta >= 0
        color: "#000000"
        ListView {
            id: vista_
            anchors.fill: parent
            orientation: ListView.Horizontal
            snapMode: ListView.SnapOneItem; highlightRangeMode: ListView.StrictlyEnforceRange
            boundsBehavior: Flickable.StopAtBounds
            model: app.aperta >= 0 ? app.vista : []
            onCurrentIndexChanged: if (app.aperta >= 0) app.aperta = currentIndex
            delegate: Item {
                required property var modelData
                width: vista_.width; height: vista_.height
                Image {
                    anchors.fill: parent
                    source: modelData.uri; fillMode: Image.PreserveAspectFit; asynchronous: true
                    sourceSize.width: 1400
                }
                TapHandler { onTapped: app.comandi = !app.comandi }
            }
        }
        // Barra in alto
        Rectangle {
            visible: app.comandi
            width: parent.width; height: 100; color: Qt.rgba(0, 0, 0, 0.55)
            Text {
                x: 18; y: 58
                text: "‹ " + I18n.t("Foto"); color: "#ffffff"; font.family: Tema.font; font.pixelSize: tel.px(16)
                MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: app.aperta = -1 }
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 18; y: 60
                text: app.aperta >= 0 && app.vista[app.aperta] ? app.vista[app.aperta].data : ""
                color: Qt.rgba(1, 1, 1, 0.8); font.family: Tema.font; font.pixelSize: tel.px(13)
            }
        }
        // Da dove arriva la foto (account collegato)
        Rectangle {
            readonly property var f: app.aperta >= 0 ? app.vista[app.aperta] : null
            visible: app.comandi && f && f.fonte !== "telefono"
            x: 16; width: parent.width - 32; height: 56; radius: 14
            anchors.bottom: parent.bottom; anchors.bottomMargin: 110
            color: Qt.rgba(1, 1, 1, 0.12)
            Fonte { x: 12; anchors.verticalCenter: parent.verticalCenter; lato: 28; fonte: parent.f ? parent.f.fonte : "" }
            Column {
                x: 52; anchors.verticalCenter: parent.verticalCenter
                Text { text: I18n.t("Da") + " " + (parent.parent.f ? app.nomiFonte[parent.parent.f.fonte] : "") + (parent.parent.f && parent.parent.f.dove ? " · " + parent.parent.f.dove : ""); color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                Text { text: I18n.t("Copiata dal tuo account"); color: "#B3FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(11.5) }
            }
        }
        // Azioni in basso
        Rectangle {
            visible: app.comandi
            anchors.bottom: parent.bottom
            width: parent.width; height: 96; color: Qt.rgba(0, 0, 0, 0.55)
            Row {
                anchors.centerIn: parent; anchors.verticalCenterOffset: -8
                spacing: 40
                Repeater {
                    model: [{ k: "condividi", t: I18n.t("Condividi"), i: "emblem-shared-symbolic" },
                            { k: "sfondo", t: I18n.t("Sfondo"), i: "preferences-desktop-wallpaper-symbolic" },
                            { k: "elimina", t: I18n.t("Elimina"), i: "user-trash-symbolic" }]
                    Column {
                        required property var modelData
                        spacing: 4
                        Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: parent.modelData.i; lato: 24; tema: "scuro" }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.modelData.t; color: "#ffffff"; font.family: Tema.font; font.pixelSize: tel.px(12) }
                        MouseArea {
                            width: 60; height: 50; x: (parent.width - 60) / 2; y: -6
                            onClicked: {
                                var f = app.vista[app.aperta]
                                if (!f) return
                                if (parent.modelData.k === "condividi") tel.condividi([f.percorso])
                                else if (parent.modelData.k === "sfondo") { var r = ponte.chiama("sfondoFoto", [f.percorso]); tel.imp = ponte.chiama0("impostazioni"); tel.avviso(r.messaggio) }
                                else elimina.open()
                            }
                        }
                    }
                }
            }
        }
    }
    Popup {
        id: elimina
        anchors.centerIn: parent
        width: parent.width - 60; modal: true; padding: 20
        background: Rectangle { radius: 20; color: app.sezione }
        Column {
            width: parent.width; spacing: 14
            Text { width: parent.width; wrapMode: Text.Wrap; text: I18n.t("Spostare la foto nel Cestino?"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.DemiBold }
            Row {
                spacing: 10; anchors.right: parent.right
                Pulsante { text: I18n.t("Annulla"); onClicked: elimina.close() }
                Pulsante {
                    text: I18n.t("Elimina"); pericoloso: true
                    onClicked: {
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
}
