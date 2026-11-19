// Store: come SolidOS App sul PC, pensato per il dito. In basso quattro schede (Scopri,
// Raccolte, Cerca, Le mie app). «Scopri» ha l'app della settimana, le raccolte da sfogliare
// e le consigliate; ogni app ha la sua scheda con foto, voto e recensioni di chi usa SolidOS,
// che si scrivono con il Solid ID in un foglio che sale dal basso. Le app arrivano da
// Flathub e si installano solo per te (niente password).
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: app
    color: tel.pal.sfondo
    property string scheda: "scopri"          // scopri | raccolte | cerca | mie
    property var consigliate: []
    property bool disponibile: true
    property var raccolte: []
    property var risultati: []
    property string cerca: ""
    property bool cercando: false
    property var inCorso: ({})                // id → true durante installazione/rimozione
    property var avanzamento: ({})            // id → percentuale dello scaricamento
    property bool soloTelefono: true          // Cerca: solo le app adatte al telefono
    property var account: ({ collegato: false, elenco: [], automatiche: true })   // «Le mie app» del Solid ID
    readonly property var altrove: account.elenco.filter(function (x) { return !x.installata && !app.installata({ id: x.app }) })
                                                  .map(function (x) { return { id: x.app, nome: x.nome, icona: x.icona || "", descrizione: x.dispositivo === "pc" ? I18n.t("Presa sul PC") : I18n.t("Presa su un altro telefono") } })
    property var raccolta: null               // raccolta aperta
    property var aperta: null                 // scheda dell'app aperta
    property var recensioni: ({ riepilogo: { media: 0, totale: 0, distribuzione: [0, 0, 0, 0, 0] }, elenco: [], account: { collegato: false } })
    readonly property var appDellaSettimana: consigliate.length ? consigliate[Math.floor(Date.now() / 604800000) % consigliate.length] : null
    readonly property var mie: {
        var visti = {}, r = []
        var tutte = consigliate.concat.apply(consigliate, raccolte.map(function (x) { return x.app }))
        for (var i = 0; i < tutte.length; i++) if (tutte[i].installata && !visti[tutte[i].id]) { visti[tutte[i].id] = true; r.push(tutte[i]) }
        return r
    }

    function aggiorna() {
        ponte.avvia("storeConsigliate", [], "store-consigliate")
        ponte.avvia("storeRaccolte", [], "store-raccolte")
        ponte.avvia("storeMieApp", [], "store-account")
    }
    function installata(a) { return !!a && (a.installata === true || app.mie.some(function (x) { return x.id === a.id })) }
    function azione(a) {
        var c = Object.assign({}, inCorso); c[a.id] = true; inCorso = c
        if (installata(a)) ponte.avvia("storeRimuovi", [a.id], "store-fatto:" + a.id)
        else { var v = Object.assign({}, avanzamento); v[a.id] = 0; avanzamento = v; ponte.avvia("storeInstalla", [a.id, a.nome || "", a.icona || ""], "store-fatto:" + a.id) }
    }
    function apriApp(a) {
        if (!a) return
        aperta = { id: a.id, nome: a.nome, descrizioneBreve: a.descrizione || "", icona: a.icona || "", installata: installata(a), caricata: false }
        recensioni = { riepilogo: { media: 0, totale: 0, distribuzione: [0, 0, 0, 0, 0] }, elenco: [], account: recensioni.account }
        ponte.avvia("storeScheda", [a.id], "store-scheda")
        ponte.avvia("storeRecensioni", [a.id], "store-recensioni")
        paginaApp.contentY = 0
    }
    onVisibleChanged: if (visible) aggiorna()
    Component.onCompleted: {
        aggiorna()
        // Foto di prova (--schermata=store-app / store-raccolta)
        var s = ponte.chiama0("avvio").schermata
        if (s === "store-app") apriApp({ id: "io.bassi.Amberol", nome: "Amberol", descrizione: "", icona: "" })
        else if (s === "store-raccolta") provaRaccolta.start()
        else if (s === "store-mie") scheda = "mie"
        else if (s === "store-scarica") { apriApp({ id: "io.bassi.Amberol", nome: "Amberol", descrizione: "", icona: "" }); provaScarica.start() }
    }
    Timer { id: provaScarica; interval: 10200; onTriggered: app.azione(app.aperta) }
    Timer { id: provaRaccolta; interval: 6000; onTriggered: if (app.raccolte.length) app.raccolta = app.raccolte[2] }
    Timer { id: ritardo; interval: 500; onTriggered: if (app.cerca) { app.cercando = true; ponte.avvia("storeCerca", [app.cerca, app.soloTelefono], "store-cerca") } else app.risultati = [] }
    Connections {
        target: ponte
        function onEvento(nome, d) {
            if (nome === "store-avanzamento") { var v = Object.assign({}, app.avanzamento); v[d.id] = d.percento; app.avanzamento = v }
            else if (nome === "store-scaricata") { tel.avviso(d.nome + ": " + I18n.t("scaricata dalle tue app")); app.aggiorna(); tel.ricaricaApp() }
        }
        function onCompletato(id, r) {
            if (id === "store-consigliate") { app.consigliate = r.app; app.disponibile = r.disponibile }
            else if (id === "store-raccolte") app.raccolte = r
            else if (id === "store-account") app.account = r
            else if (id === "store-cerca") { app.risultati = r; app.cercando = false }
            else if (id === "store-scheda") { if (r.ok && app.aperta && r.id === app.aperta.id) app.aperta = Object.assign({ caricata: true }, r) }
            else if (id === "store-recensioni") app.recensioni = r
            else if (id === "store-recensione") {
                tel.avviso(r.messaggio)
                if (r.ok) { foglio.chiudi(); if (app.aperta) ponte.avvia("storeRecensioni", [app.aperta.id], "store-recensioni") }
            }
            else if (id.indexOf("store-fatto:") === 0) {
                var c = Object.assign({}, app.inCorso); delete c[id.slice(12)]; app.inCorso = c
                var v = Object.assign({}, app.avanzamento); delete v[id.slice(12)]; app.avanzamento = v
                tel.avviso(r.messaggio)
                app.aggiorna()
                if (app.aperta) app.aperta = Object.assign({}, app.aperta, { installata: !app.aperta.installata })
                if (app.cerca) ponte.avvia("storeCerca", [app.cerca, app.soloTelefono], "store-cerca")
                tel.ricaricaApp()
            }
        }
    }

    // ── Pezzi comuni ─────────────────────────────────────────────────────
    component IconaStore: Item {
        id: is
        property var a: ({})
        property int lato: 48
        width: lato; height: lato
        Image {
            id: imm
            anchors.fill: parent
            source: (is.a && (is.a.icona || "").indexOf("http") === 0) ? is.a.icona : ""
            asynchronous: true; fillMode: Image.PreserveAspectFit; smooth: true
            sourceSize.width: is.lato * 2; sourceSize.height: is.lato * 2
        }
        Rectangle { anchors.fill: parent; radius: is.lato * 0.22; color: tel.pal.superficie2; visible: imm.status !== Image.Ready }
    }
    component Stelle: Row {
        id: st
        property real voto: 0
        property int lato: 11
        spacing: 1
        Repeater {
            model: 5
            Text { required property int index; text: "★"; font.pixelSize: st.lato
                   color: index < Math.round(st.voto) ? "#F5A524" : (tel.chiaro ? "#D4D4D8" : "#4A4B52") }
        }
    }
    component Tasto: Rectangle {
        id: ta
        property var a: ({})
        property bool grigio: false
        readonly property bool presente: app.installata(a)
        property string etichetta: ""
        // Durante lo scaricamento: barra che si riempie con la percentuale
        readonly property int percento: app.avanzamento[a.id] !== undefined ? app.avanzamento[a.id] : -1
        width: Math.max(84, et.implicitWidth + 28); height: 30; radius: 15
        color: percento >= 0 ? tel.pal.superficie2 : (grigio || presente ? tel.pal.superficie2 : tel.accento)
        opacity: app.disponibile ? 1 : 0.4
        clip: true
        Rectangle {
            visible: ta.percento >= 0
            width: Math.max(ta.height, ta.width * ta.percento / 100); height: ta.height; radius: ta.radius
            color: tel.accento
            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        }
        Text {
            id: et
            anchors.centerIn: parent
            text: ta.percento >= 0 ? (ta.percento >= 100 ? I18n.t("Installo…") : ta.percento + "%")
                  : app.inCorso[ta.a.id] ? "…" : (ta.presente ? I18n.t("Apri") : (ta.etichetta || I18n.t("Installa")))
            color: ta.percento >= 0 ? (ta.percento > 45 ? "#FFFFFF" : tel.pal.testo) : (ta.grigio || ta.presente ? tel.accento : "#FFFFFF")
            font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.Bold
        }
        MouseArea { anchors.fill: parent; anchors.margins: -6; enabled: app.disponibile && !app.inCorso[ta.a.id]
                    onClicked: ta.presente ? tel.apri({ id: ta.a.id, nome: ta.a.nome }) : app.azione(ta.a) }
    }
    // Riga di un'app in un elenco
    component RigaApp: Item {
        id: ra
        property var a: ({})
        property bool ultima: false
        width: parent ? parent.width : 300; height: 74
        IconaStore { x: 14; anchors.verticalCenter: parent.verticalCenter; a: ra.a; lato: 48 }
        Column {
            x: 74; anchors.verticalCenter: parent.verticalCenter; width: ra.width - 74 - 116; spacing: 1
            Text { width: parent.width; elide: Text.ElideRight; text: ra.a.nome || ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.DemiBold }
            Row {
                width: parent.width; spacing: 6
                Rectangle {
                    visible: ra.a.telefono === false
                    anchors.verticalCenter: parent.verticalCenter
                    width: etPc.implicitWidth + 12; height: 18; radius: 9; color: Qt.rgba(0.96, 0.62, 0.04, 0.18)
                    Text { id: etPc; anchors.centerIn: parent; text: I18n.t("Per computer"); color: "#F59E0B"; font.family: Tema.font; font.pixelSize: tel.px(10.5); font.weight: Font.Bold }
                }
                Text { width: parent.width - (ra.a.telefono === false ? 90 : 0); elide: Text.ElideRight; text: ra.a.descrizione || ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13) }
            }
        }
        Tasto { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; a: ra.a; grigio: true }
        Rectangle { visible: !ra.ultima; anchors.bottom: parent.bottom; x: 74; width: ra.width - 74; height: 1; color: tel.pal.bordo }
        MouseArea { anchors.fill: parent; anchors.rightMargin: 110; onClicked: app.apriApp(ra.a) }
    }
    // Copertina di una raccolta
    component Copertina: Rectangle {
        id: cop
        property var r: ({})
        radius: 18; clip: true
        color: tel.pal.superficie
        Rectangle {
            width: parent.width; height: parent.height - 52; radius: 18
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: (cop.r.colori || ["#4C7DFF"])[0] }
                GradientStop { position: 1; color: (cop.r.colori || ["#4C7DFF", "#8B5CF6"])[1] }
            }
            Row { anchors.centerIn: parent; spacing: -10; Repeater { model: (cop.r.app || []).slice(0, 4); IconaStore { required property var modelData; a: modelData; lato: 38 } } }
        }
        Column {
            x: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 9; width: cop.width - 24
            Text { width: parent.width; elide: Text.ElideRight; text: cop.r.nome || ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.Bold }
            Text { text: (cop.r.app || []).length + " " + I18n.t("app"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }
        }
        MouseArea { anchors.fill: parent; onClicked: app.raccolta = cop.r }
    }

    // ══ Schede principali ═════════════════════════════════════════════════
    Flickable {
        id: principale
        anchors.fill: parent; anchors.bottomMargin: 82
        contentHeight: corpo.height + 30
        clip: true
        Column {
            id: corpo
            x: 16; width: principale.width - 32
            spacing: 14
            Item { width: 1; height: 44 }
            Column {
                Text { visible: app.scheda === "scopri"; text: tel.adesso.toLocaleDateString(Qt.locale("it_IT"), "dddd d MMMM").toUpperCase(); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12); font.weight: Font.DemiBold }
                Punti { text: ({ scopri: I18n.t("Scopri"), raccolte: I18n.t("Raccolte"), cerca: I18n.t("Cerca"), mie: I18n.t("Le mie app") })[app.scheda] }
            }
            Text {
                visible: !app.disponibile
                width: parent.width; wrapMode: Text.Wrap
                text: I18n.t("Lo Store usa Flatpak, che su questo telefono non è installato.")
                color: tel.rosso; font.family: Tema.font; font.pixelSize: tel.px(13)
            }

            // ── Scopri: app della settimana ─────────────────────────────
            Rectangle {
                visible: app.scheda === "scopri" && app.appDellaSettimana !== null
                width: parent.width; height: 280; radius: 22; clip: true
                gradient: Gradient { GradientStop { position: 0; color: "#2F5FD0" } GradientStop { position: 1; color: "#8B5CF6" } }
                Rectangle { x: parent.width - 150; y: 90; width: 210; height: 210; radius: 105; color: "#14FFFFFF" }
                MouseArea { anchors.fill: parent; onClicked: app.apriApp(app.appDellaSettimana) }
                Column {
                    x: 20; y: 20; width: parent.width - 40; spacing: 6
                    Text { text: I18n.t("APP DELLA SETTIMANA"); color: "#D9FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(11); font.weight: Font.Bold; font.letterSpacing: 0.6 }
                    Text { width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight; text: app.appDellaSettimana ? app.appDellaSettimana.descrizione : ""; color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(26); font.weight: Font.Bold; lineHeight: 1.05 }
                }
                Rectangle {
                    x: 14; width: parent.width - 28; height: 68; radius: 16
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 14
                    color: "#2E000000"
                    IconaStore { x: 10; anchors.verticalCenter: parent.verticalCenter; a: app.appDellaSettimana || ({}); lato: 46 }
                    Text { x: 68; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 68 - 100; elide: Text.ElideRight; text: app.appDellaSettimana ? app.appDellaSettimana.nome : ""; color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.Bold }
                    Rectangle {
                        id: tastoSettimana
                        readonly property var a: app.appDellaSettimana || ({})
                        readonly property int percento: app.avanzamento[a.id] !== undefined ? app.avanzamento[a.id] : -1
                        readonly property bool presente: app.installata(app.appDellaSettimana)
                        anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                        width: 96; height: 30; radius: 15; clip: true
                        color: percento >= 0 ? "#59FFFFFF" : "#FFFFFF"
                        // durante lo scaricamento il pulsante si riempie
                        Rectangle {
                            visible: tastoSettimana.percento >= 0
                            width: Math.max(tastoSettimana.height, tastoSettimana.width * tastoSettimana.percento / 100); height: parent.height; radius: parent.radius
                            color: "#FFFFFF"
                            Behavior on width { NumberAnimation { duration: 250 } }
                        }
                        Text {
                            anchors.centerIn: parent; color: "#2F5FD0"; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.Bold
                            text: tastoSettimana.percento >= 0 ? (tastoSettimana.percento >= 100 ? I18n.t("Installo…") : tastoSettimana.percento + "%")
                                  : app.inCorso[tastoSettimana.a.id] ? "…" : (tastoSettimana.presente ? I18n.t("Apri") : I18n.t("Installa"))
                        }
                        MouseArea {
                            anchors.fill: parent; enabled: !app.inCorso[tastoSettimana.a.id]
                            onClicked: tastoSettimana.presente ? tel.apri(app.mie.find(function (x) { return x.id === tastoSettimana.a.id }) || tastoSettimana.a) : app.azione(app.appDellaSettimana)
                        }
                    }
                }
            }
            Item {
                visible: app.scheda === "scopri" && app.raccolte.length > 0
                width: parent.width; height: 26
                Text { anchors.bottom: parent.bottom; text: I18n.t("Raccolte"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(20); font.weight: Font.Bold }
                Text { anchors.right: parent.right; anchors.bottom: parent.bottom; text: I18n.t("Vedi tutte"); color: tel.accento; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.DemiBold
                       MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: app.scheda = "raccolte" } }
            }
            Grid {
                visible: (app.scheda === "scopri" || app.scheda === "raccolte") && app.raccolte.length > 0
                columns: 2; spacing: 12
                Repeater {
                    model: app.scheda === "scopri" ? app.raccolte.slice(0, 2) : app.raccolte
                    Copertina { required property var modelData; r: modelData; width: (corpo.width - 12) / 2; height: 140 }
                }
            }
            Text {
                visible: app.scheda === "scopri"
                text: I18n.t("Consigliate per il telefono"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(20); font.weight: Font.Bold
            }

            // ── Cerca e le mie app ───────────────────────────────────────
            CampoCerca {
                visible: app.scheda === "cerca"
                width: parent.width
                suggerimento: I18n.t("App, giochi e strumenti")
                onTextChanged: { app.cerca = text.trim(); ritardo.restart() }
            }
            // Solo le app fatte per il telefono (si adattano allo schermo piccolo e al tocco)
            Item {
                visible: app.scheda === "cerca"
                width: parent.width; height: 34
                Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Solo app per il telefono"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(14) }
                Rectangle {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: 46; height: 28; radius: 14; color: app.soloTelefono ? tel.accento : tel.pal.superficie2
                    Rectangle { width: 22; height: 22; radius: 11; y: 3; x: app.soloTelefono ? 21 : 3; color: "#FFFFFF" }
                    MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: { app.soloTelefono = !app.soloTelefono; ritardo.restart() } }
                }
            }
            Text {
                visible: app.scheda === "cerca" && app.cerca !== "" && !app.cercando && app.risultati.length === 0
                text: I18n.t("Nessuna app trovata"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(14)
            }
            // Le mie app: il Solid ID tiene l'elenco delle app prese su tutti i dispositivi
            Rectangle {
                visible: app.scheda === "mie"
                width: parent.width; height: colSid.height + 24; radius: 18; color: tel.pal.superficie
                Column {
                    id: colSid
                    x: 14; y: 12; width: parent.width - 28; spacing: 8
                    Row {
                        spacing: 10
                        Avatar { lato: 36; nome: app.account.collegato ? (ponte.chiama0("solidId").nome || "S") : "?" }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: app.account.collegato ? (ponte.chiama0("solidId").nome || I18n.t("Solid ID")) : I18n.t("Accedi al Solid ID"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.DemiBold }
                            Text { text: app.account.collegato ? I18n.t("Le tue app sono legate al Solid ID") : I18n.t("Per avere le stesse app su PC e telefono"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12.5) }
                        }
                    }
                    Text {
                        width: parent.width; wrapMode: Text.Wrap
                        text: app.account.collegato ? I18n.t("Ogni app che prendi dallo Store, qui o sul PC, resta nel tuo Solid ID: la ritrovi su tutti i tuoi dispositivi.")
                                                    : I18n.t("Come con l'ID Apple: accedi e le app che prendi sul PC compaiono anche qui (e al contrario).")
                        color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13)
                    }
                    Item {
                        visible: app.account.collegato
                        width: parent.width; height: 40
                        Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 60; wrapMode: Text.Wrap; text: I18n.t("Scarica da sola le app prese sul PC"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(14) }
                        Rectangle {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            width: 46; height: 28; radius: 14; color: app.account.automatiche ? tel.accento : tel.pal.superficie2
                            Rectangle { width: 22; height: 22; radius: 11; y: 3; x: app.account.automatiche ? 21 : 3; color: "#FFFFFF" }
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -6
                                onClicked: {
                                    var si = !app.account.automatiche
                                    tel.imposta("app_automatiche", si)
                                    app.account = Object.assign({}, app.account, { automatiche: si })
                                    if (si) ponte.avvia("storeScaricaMie", [], "store-scarica-mie")
                                }
                            }
                        }
                    }
                    Rectangle {
                        visible: !app.account.collegato
                        width: 120; height: 34; radius: 17; color: tel.accento
                        Text { anchors.centerIn: parent; text: I18n.t("Accedi"); color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.Bold }
                        MouseArea { anchors.fill: parent; onClicked: { tel.appInterna = "impostazioni"; impostazioniApp.apri("solidid") } }
                    }
                }
            }
            Text {
                visible: app.scheda === "mie" && app.altrove.length > 0
                text: I18n.t("Dagli altri dispositivi"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(20); font.weight: Font.Bold
            }
            Rectangle {
                id: bloccoAltrove
                visible: app.scheda === "mie" && app.altrove.length > 0
                width: parent.width; height: righeAltrove.height; radius: 18
                color: tel.pal.superficie
                Column {
                    id: righeAltrove
                    width: bloccoAltrove.width
                    Repeater {
                        model: app.scheda === "mie" ? app.altrove : []
                        RigaApp { required property var modelData; required property int index; a: modelData; ultima: index === app.altrove.length - 1 }
                    }
                }
            }
            Text {
                visible: app.scheda === "mie"
                text: I18n.t("Su questo telefono"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(20); font.weight: Font.Bold
            }
            Text {
                visible: app.scheda === "mie" && app.mie.length === 0
                width: parent.width; wrapMode: Text.Wrap
                text: I18n.t("Le app che installi dallo Store compaiono qui e nella Libreria app.")
                color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(14)
            }

            // Elenco (consigliate, risultati o le mie app)
            Rectangle {
                id: blocco
                readonly property var elenco: app.scheda === "scopri" ? app.consigliate : (app.scheda === "cerca" ? app.risultati : (app.scheda === "mie" ? app.mie : []))
                visible: elenco.length > 0
                width: parent.width; height: righe.height; radius: 18
                color: tel.pal.superficie
                Column {
                    id: righe
                    width: blocco.width
                    Repeater {
                        model: blocco.elenco
                        RigaApp { required property var modelData; required property int index; a: modelData; ultima: index === blocco.elenco.length - 1 }
                    }
                }
            }
            Text {
                visible: app.scheda === "scopri"
                width: parent.width; wrapMode: Text.Wrap
                text: I18n.t("Le app arrivano da Flathub e si installano solo per te. Alcune sono pensate per il computer e sul telefono possono essere scomode.")
                color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12)
            }
        }
    }

    // Schede in basso
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 82; color: tel.pal.superficie
        Rectangle { width: parent.width; height: 1; color: tel.pal.bordo }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter; y: 8
            Repeater {
                model: [{ s: "scopri", t: I18n.t("Scopri"), i: "starred-symbolic" }, { s: "raccolte", t: I18n.t("Raccolte"), i: "view-app-grid-symbolic" },
                        { s: "cerca", t: I18n.t("Cerca"), i: "system-search-symbolic" }, { s: "mie", t: I18n.t("Le mie app"), i: "user-home" }]
                Item {
                    id: voceTab
                    required property var modelData
                    width: (app.width - 20) / 4; height: 50
                    Column {
                        anchors.centerIn: parent; spacing: 3
                        opacity: app.scheda === voceTab.modelData.s ? 1 : 0.55
                        Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: voceTab.modelData.i; lato: 22 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: voceTab.modelData.t; color: app.scheda === voceTab.modelData.s ? tel.accento : tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(11); font.weight: Font.DemiBold }
                    }
                    MouseArea { anchors.fill: parent; onClicked: { app.scheda = voceTab.modelData.s; app.raccolta = null; principale.contentY = 0 } }
                }
            }
        }
    }

    // ══ Una raccolta ══════════════════════════════════════════════════════
    Rectangle {
        id: paginaRaccolta
        anchors.fill: parent
        visible: app.raccolta !== null
        color: tel.pal.sfondo
        readonly property var r: app.raccolta || ({})
        MouseArea { anchors.fill: parent }
        Flickable {
            anchors.fill: parent
            contentHeight: listaR.y + listaR.height + 40
            clip: true
            Rectangle {
                width: paginaRaccolta.width; height: 300
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: (paginaRaccolta.r.colori || ["#4C7DFF"])[0] }
                    GradientStop { position: 1; color: (paginaRaccolta.r.colori || ["#4C7DFF", "#8B5CF6"])[1] }
                }
                Rectangle {
                    x: 16; y: 54; width: 36; height: 36; radius: 18; color: "#33000000"
                    Icona { anchors.centerIn: parent; nome: "go-previous-symbolic"; lato: 18; tema: "scuro" }
                    MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: app.raccolta = null }
                }
                Column {
                    x: 20; y: 112; width: paginaRaccolta.width - 40; spacing: 6
                    Row { spacing: -12; Repeater { model: (paginaRaccolta.r.app || []).slice(0, 5); IconaStore { required property var modelData; a: modelData; lato: 50 } } }
                    Item { width: 1; height: 6 }
                    Text { width: parent.width; wrapMode: Text.Wrap; text: paginaRaccolta.r.nome || ""; color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(30); font.weight: Font.Bold }
                    Text { width: parent.width; wrapMode: Text.Wrap; text: (paginaRaccolta.r.sotto || "") + ". " + I18n.t("Scelte da") + " SolidOS."; color: "#E6FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(14) }
                }
            }
            Rectangle {
                id: listaR
                x: 16; y: 316; width: paginaRaccolta.width - 32; height: colR.height; radius: 18
                color: tel.pal.superficie
                Column {
                    id: colR
                    width: listaR.width
                    Repeater {
                        model: paginaRaccolta.r.app || []
                        RigaApp { required property var modelData; required property int index; a: modelData; ultima: index === (paginaRaccolta.r.app || []).length - 1 }
                    }
                }
            }
        }
    }

    // ══ Scheda di un'app ══════════════════════════════════════════════════
    Rectangle {
        id: paginaScheda
        anchors.fill: parent
        visible: app.aperta !== null
        color: tel.pal.sfondo
        readonly property var s: app.aperta || ({})
        readonly property var rr: app.recensioni.riepilogo || ({ media: 0, totale: 0, distribuzione: [0, 0, 0, 0, 0] })
        MouseArea { anchors.fill: parent }
        Flickable {
            id: paginaApp
            anchors.fill: parent
            contentHeight: colApp.height + 60
            clip: true
            Column {
                id: colApp
                x: 18; width: paginaApp.width - 36
                spacing: 16
                Item { width: 1; height: 48 }
                Item {
                    width: parent.width; height: 26
                    Row {
                        spacing: 4
                        Icona { anchors.verticalCenter: parent.verticalCenter; nome: "go-previous-symbolic"; lato: 20 }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: app.raccolta ? (app.raccolta.nome || "") : I18n.t("Store"); color: tel.accento; font.family: Tema.font; font.pixelSize: tel.px(16) }
                    }
                    MouseArea { width: 180; height: 40; y: -8; onClicked: app.aperta = null }
                }
                Row {
                    spacing: 14
                    IconaStore { a: paginaScheda.s; lato: 86 }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: colApp.width - 100; spacing: 4
                        Text { width: parent.width; wrapMode: Text.Wrap; text: paginaScheda.s.nome || ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(24); font.weight: Font.Bold }
                        Text { width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; text: paginaScheda.s.descrizioneBreve || ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13) }
                        Item { width: 1; height: 4 }
                        // Adatta al telefono? (lo dice Flathub)
                        Text {
                            visible: paginaScheda.s.telefono === true || paginaScheda.s.telefono === false
                            width: parent.width; wrapMode: Text.Wrap
                            text: paginaScheda.s.telefono ? "✓ " + I18n.t("Fatta per il telefono") : I18n.t("Pensata per il computer: sul telefono può essere scomoda")
                            color: paginaScheda.s.telefono ? tel.pal.successo : "#F59E0B"
                            font.family: Tema.font; font.pixelSize: tel.px(12); font.weight: Font.DemiBold
                        }
                        Row {
                            spacing: 14
                            Tasto { a: paginaScheda.s }
                            Text {
                                visible: app.installata(paginaScheda.s) && !app.inCorso[paginaScheda.s.id]
                                anchors.verticalCenter: parent.verticalCenter
                                text: I18n.t("Rimuovi"); color: tel.rosso; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.DemiBold
                                MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: app.azione(paginaScheda.s) }
                            }
                        }
                    }
                }
                // In breve
                Item {
                    width: parent.width; height: 70
                    Rectangle { width: parent.width; height: 1; color: tel.pal.bordo }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: tel.pal.bordo }
                    Row {
                        anchors.fill: parent
                        Repeater {
                            model: [{ t: paginaScheda.rr.totale + " " + I18n.t("voti"), v: paginaScheda.rr.totale ? String(paginaScheda.rr.media).replace(".", ",") : "—", s: true },
                                    { t: I18n.t("Dimensioni"), v: (paginaScheda.s.scarica || "—").split(" ")[0], u: (paginaScheda.s.scarica || "").split(" ")[1] || "" },
                                    { t: I18n.t("Versione"), v: paginaScheda.s.versione || "—", u: "" },
                                    { t: I18n.t("Prezzo"), v: I18n.t("Gratis"), u: paginaScheda.s.libera ? I18n.t("libera") : "" }]
                            Column {
                                id: dato
                                required property var modelData
                                width: colApp.width / 4; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: dato.modelData.t.toUpperCase(); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(10); font.weight: Font.DemiBold }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; width: dato.width - 6; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: dato.modelData.v; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(17); font.weight: Font.Bold }
                                Stelle { visible: dato.modelData.s === true; anchors.horizontalCenter: parent.horizontalCenter; voto: paginaScheda.rr.media; lato: 10 }
                                Text { visible: dato.modelData.s !== true && (dato.modelData.u || "") !== ""; anchors.horizontalCenter: parent.horizontalCenter; text: dato.modelData.u || ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(11) }
                            }
                        }
                    }
                }
                // Foto dello schermo
                ListView {
                    visible: (paginaScheda.s.foto || []).length > 0
                    width: parent.width; height: 260
                    orientation: ListView.Horizontal; spacing: 10; clip: true
                    model: paginaScheda.s.foto || []
                    delegate: Rectangle {
                        required property var modelData
                        height: 260; width: Math.max(140, foto.status === Image.Ready ? foto.implicitWidth * height / Math.max(1, foto.implicitHeight) : 260)
                        radius: 16; clip: true; color: tel.pal.superficie2
                        Image { id: foto; anchors.fill: parent; source: parent.modelData.url; fillMode: Image.PreserveAspectFit; asynchronous: true; sourceSize.height: 520 }
                    }
                }
                Text {
                    visible: !paginaScheda.s.caricata
                    text: I18n.t("Caricamento…"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(14)
                }
                Text {
                    visible: text !== ""
                    width: parent.width; wrapMode: Text.Wrap; textFormat: Text.RichText
                    text: paginaScheda.s.descrizione || ""
                    color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(14); lineHeight: 1.25
                }
                // Nelle raccolte
                Flow {
                    visible: (paginaScheda.s.raccolte || []).length > 0
                    width: parent.width; spacing: 8
                    Repeater {
                        model: paginaScheda.s.raccolte || []
                        Rectangle {
                            id: chip
                            required property var modelData
                            height: 40; width: nomeChip.implicitWidth + 56; radius: 12; color: tel.pal.superficie
                            Rectangle {
                                x: 6; anchors.verticalCenter: parent.verticalCenter; width: 28; height: 28; radius: 8
                                gradient: Gradient { GradientStop { position: 0; color: chip.modelData.colori[0] } GradientStop { position: 1; color: chip.modelData.colori[1] } }
                            }
                            Text { id: nomeChip; x: 44; anchors.verticalCenter: parent.verticalCenter; text: chip.modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { var id = chip.modelData.id; var t = app.raccolte.filter(function (x) { return x.id === id }); if (t.length) { app.raccolta = t[0]; app.aperta = null } }
                            }
                        }
                    }
                }
                // Recensioni
                Item {
                    width: parent.width; height: 30
                    Text { anchors.bottom: parent.bottom; text: I18n.t("Recensioni"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(20); font.weight: Font.Bold }
                    Text {
                        anchors.right: parent.right; anchors.bottom: parent.bottom
                        text: (app.recensioni.elenco || []).some(function (x) { return x.mia }) ? I18n.t("Modifica la tua") : I18n.t("Scrivi")
                        color: tel.accento; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.DemiBold
                        MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: foglio.apri() }
                    }
                }
                Row {
                    visible: paginaScheda.rr.totale > 0
                    spacing: 16
                    Text { anchors.verticalCenter: parent.verticalCenter; text: String(paginaScheda.rr.media).replace(".", ","); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 44; font.weight: Font.Bold }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        Repeater {
                            model: 5
                            Row {
                                id: barra
                                required property int index
                                spacing: 8
                                Text { width: 8; text: 5 - barra.index; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 10; font.weight: Font.DemiBold }
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: colApp.width - 130; height: 5; radius: 3; color: tel.pal.superficie2
                                    Rectangle { height: parent.height; radius: 3; color: tel.pal.testo2
                                                width: parent.width * (paginaScheda.rr.totale ? paginaScheda.rr.distribuzione[barra.index] / paginaScheda.rr.totale : 0) }
                                }
                            }
                        }
                    }
                }
                Text {
                    visible: paginaScheda.rr.totale === 0
                    width: parent.width; wrapMode: Text.Wrap
                    text: I18n.t("Nessuna recensione ancora: scrivi la prima.")
                    color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(14)
                }
                Repeater {
                    model: app.recensioni.elenco || []
                    Rectangle {
                        id: rec
                        required property var modelData
                        width: colApp.width; height: colRec.height + 24; radius: 16
                        color: tel.pal.superficie
                        Column {
                            id: colRec
                            x: 14; y: 12; width: rec.width - 28; spacing: 3
                            Item {
                                width: parent.width; height: 18
                                Text { width: parent.width - 70; elide: Text.ElideRight; text: rec.modelData.nome + (rec.modelData.mia ? " (" + I18n.t("tu") + ")" : ""); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.DemiBold }
                                Text { anchors.right: parent.right; text: rec.modelData.quando || ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }
                            }
                            Stelle { voto: rec.modelData.voto; lato: 11 }
                            Text { visible: text !== ""; width: parent.width; wrapMode: Text.Wrap; text: rec.modelData.titolo || ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.DemiBold }
                            Text { visible: text !== ""; width: parent.width; wrapMode: Text.Wrap; text: rec.modelData.testo || ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13); lineHeight: 1.2 }
                            Text {
                                visible: !rec.modelData.mia
                                text: I18n.t("Utile") + (rec.modelData.utili ? " (" + rec.modelData.utili + ")" : ""); color: tel.accento; font.family: Tema.font; font.pixelSize: tel.px(12); font.weight: Font.DemiBold
                                MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: ponte.avvia("storeUtile", [rec.modelData.id], "store-recensione") }
                            }
                        }
                    }
                }
            }
        }
    }

    // ══ Foglio «Scrivi una recensione» (sale dal basso) ════════════════════
    Rectangle {
        anchors.fill: parent
        color: "#73000000"
        opacity: foglio.aperto ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: tel.tNormale } }
        MouseArea { anchors.fill: parent; onClicked: foglio.chiudi() }
    }
    Rectangle {
        id: foglio
        property bool aperto: false
        property int voto: 0
        function apri() {
            var mia = (app.recensioni.elenco || []).filter(function (x) { return x.mia })
            voto = mia.length ? mia[0].voto : 0
            titoloRec.text = mia.length ? mia[0].titolo : ""
            testoRec.text = mia.length ? mia[0].testo : ""
            aperto = true
        }
        function chiudi() { aperto = false; Qt.inputMethod.hide() }
        x: 0; width: parent.width; height: parent.height - 100
        y: aperto ? 100 : parent.height
        visible: y < parent.height
        Behavior on y { Movimento { apre: foglio.aperto } }
        radius: 24
        color: tel.pal.superficie
        MouseArea { anchors.fill: parent }
        Column {
            x: 18; y: 12; width: foglio.width - 36
            spacing: 16
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 40; height: 5; radius: 3; color: tel.pal.bordo }
            Item {
                width: parent.width; height: 24
                Text { text: I18n.t("Annulla"); color: tel.accento; font.family: Tema.font; font.pixelSize: tel.px(15)
                       MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: foglio.chiudi() } }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Recensione"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.Bold }
                Text {
                    id: pubblica
                    anchors.right: parent.right
                    readonly property bool puo: foglio.voto > 0 && app.recensioni.account && app.recensioni.account.collegato === true
                    text: I18n.t("Pubblica"); color: tel.accento; opacity: puo ? 1 : 0.4; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.Bold
                    MouseArea { anchors.fill: parent; anchors.margins: -10; enabled: pubblica.puo
                                onClicked: ponte.avvia("storeScriviRecensione", [app.aperta.id, foglio.voto, titoloRec.text, testoRec.text], "store-recensione") }
                }
            }
            Row {
                spacing: 12
                IconaStore { a: app.aperta || ({}); lato: 48 }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: app.aperta ? app.aperta.nome : ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.Bold }
                    Text { text: I18n.t("Tocca le stelle per dare un voto"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13) }
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                Repeater {
                    model: 5
                    Text {
                        id: stella
                        required property int index
                        text: "★"; font.pixelSize: 42
                        color: index < foglio.voto ? "#F5A524" : (tel.chiaro ? "#D4D4D8" : "#4A4B52")
                        MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: foglio.voto = stella.index + 1 }
                    }
                }
            }
            Rectangle {
                width: parent.width; height: 46; radius: 12; color: tel.pal.superficie2
                TextField {
                    id: titoloRec
                    anchors.fill: parent; leftPadding: 14; rightPadding: 14
                    placeholderText: I18n.t("Titolo"); placeholderTextColor: tel.pal.testo2; maximumLength: 80
                    color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.DemiBold
                    background: Item {}
                }
            }
            Rectangle {
                width: parent.width; height: 150; radius: 12; color: tel.pal.superficie2
                TextArea {
                    id: testoRec
                    anchors.fill: parent; padding: 12
                    wrapMode: TextArea.Wrap
                    placeholderText: I18n.t("Cosa ti piace, cosa no, a cosa ti serve…"); placeholderTextColor: tel.pal.testo2
                    color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15)
                    background: Item {}
                }
            }
            Row {
                spacing: 10
                Rectangle { width: 28; height: 28; radius: 14; color: tel.accento; anchors.verticalCenter: parent.verticalCenter
                            Icona { anchors.centerIn: parent; nome: "avatar-default-symbolic"; lato: 15; tema: "scuro" } }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: foglio.width - 36 - 40; wrapMode: Text.Wrap
                    text: app.recensioni.account && app.recensioni.account.collegato
                          ? I18n.t("Pubblichi come") + " «" + app.recensioni.account.nome + "» " + I18n.t("con il tuo Solid ID. Puoi cambiarla o toglierla quando vuoi.")
                          : I18n.t("Per pubblicare accedi al Solid ID da Impostazioni.")
                    color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12)
                }
            }
            Text {
                visible: (app.recensioni.elenco || []).some(function (x) { return x.mia })
                text: I18n.t("Togli la mia recensione"); color: tel.rosso; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.DemiBold
                MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: ponte.avvia("storeCancellaRecensione", [app.aperta.id], "store-recensione") }
            }
        }
    }
}
