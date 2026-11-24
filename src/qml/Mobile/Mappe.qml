// Mappe sul telefono: la carta di SolidOS a tutto schermo (la stessa del PC, disegnata da noi dai
// dati di OpenStreetMap). In alto la ricerca e le categorie (ristoranti, benzina, farmacie…); in
// basso un foglio con i risultati, la scheda del luogo (orari, «aperto ora», telefono, sito),
// le indicazioni (auto, mezzi pubblici, bici, a piedi; tappe; evita pedaggi, autostrade, traghetti;
// percorsi alternativi) e «Avvia». Durante la guida: manovra e quella dopo, limite di velocità,
// via attuale, arrivo, voce e mappa che gira con la direzione di marcia (GPS del telefono).
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: app
    objectName: "mappeApp"
    color: tel.pal.sfondo

    property var qui: null
    property var risultati: []
    property string categoria: ""
    property bool cercando: false
    property var categorie: []
    property var luogo: null
    property var partenza: null
    property var tappe: []
    property string modoCerca: "luogo"     // luogo | partenza | tappa
    property var percorsi: []
    property int scelto: 0
    readonly property var percorso: percorsi.length ? percorsi[Math.min(scelto, percorsi.length - 1)] : null
    property string mezzo: "auto"
    property var opzioni: ({ pedaggi: true, autostrade: true, traghetti: true })
    property bool calcolo: false
    property bool aperto: false            // foglio in basso aperto del tutto
    property bool guidando: false
    property bool prova: false
    property var stato: null
    property int indiceProva: 0
    property bool voce: true
    property bool ruota: true
    property string ultimoAnnuncio: ""
    property bool seguendo: true
    property int nRicerca: 0
    property int nPercorso: 0

    function m(metodo, argomenti) { return ponte.chiama("mappe", [metodo, argomenti || []]) }
    function ma(metodo, argomenti, id) { ponte.avvia("mappe", [metodo, argomenti || []], id) }
    function cerca(t) {
        categoria = ""
        if (t.length < 2) { risultati = []; return }
        cercando = true; nRicerca++
        ma("cerca", [t, qui ? qui.lat : carta.lat, qui ? qui.lon : carta.lon], "mappe-cerca:" + nRicerca)
    }
    function cercaCategoria(c) {
        categoria = c.id; luogo = null; percorsi = []; cercando = true; campo.text = ""; campo.focus = false
        nRicerca++
        ma("vicini", [c.id, carta.lat, carta.lon], "mappe-vicini:" + nRicerca)
    }
    function scegli(l) {
        campo.focus = false
        if (modoCerca === "partenza") { partenza = l; modoCerca = "luogo"; risultati = []; campo.text = ""; indicazioni(); return }
        if (modoCerca === "tappa") { tappe = tappe.concat([l]); modoCerca = "luogo"; risultati = []; campo.text = ""; indicazioni(); return }
        nRicerca++; cercando = false
        luogo = l; percorsi = []; risultati = []; categoria = ""; aperto = false
        carta.centra(l.lat, l.lon, Math.max(carta.zoom, 16))
        m("ricorda", [l])
        if (l.osm) ma("dettagli", [l], "mappe-dettagli")
    }
    function indicazioni() {
        if (!luogo) return
        var da = partenza || qui
        if (!da) { tel.avviso(I18n.t("Sto cercando dove sei… riprova tra poco")); ma("posizione", [], "mappe-qui"); return }
        calcolo = true; scelto = 0; nPercorso++
        var tp = mezzo === "mezzi" ? [] : tappe.map(function (t) { return { lat: t.lat, lon: t.lon } })
        ma("percorso", [{ lat: da.lat, lon: da.lon }, { lat: luogo.lat, lon: luogo.lon }, mezzo, opzioni, tp], "mappe-percorso:" + nPercorso)
    }
    function scegliPercorso(i) { scelto = i; m("scegliPercorso", [percorsi[i]]); carta.inquadra(percorsi[i].forma) }
    function avvia(simulata) {
        if (!percorso || mezzo === "mezzi") return
        prova = simulata; guidando = true; seguendo = true; indiceProva = 0; ultimoAnnuncio = ""
        carta.zoom = 17
        aggiorna(simulata ? { lat: percorso.forma[0][0], lon: percorso.forma[0][1] } : qui)
    }
    function termina() { guidando = false; prova = false; stato = null; carta.fattoFino = 0; if (percorso) carta.inquadra(percorso.forma) }
    function aggiorna(pos) {
        if (!pos) return
        var g = m("guida", [pos.lat, pos.lon, stato ? stato.indice : 0])
        if (!g || !g.ok) return
        stato = g
        carta.fattoFino = g.indice
        if (seguendo) carta.centra(pos.lat, pos.lon)
        if (g.arrivato) { if (voce) m("parla", [I18n.t("Sei arrivato")]); tel.avviso(I18n.t("Sei arrivato a destinazione")); termina(); return }
        if (g.fuori && !prova) { qui = pos; partenza = null; indicazioni(); return }
        var chiave = g.manovra.inizio + (g.metriAllaManovra < 60 ? "-ora" : (g.metriAllaManovra < 320 ? "-presto" : ""))
        if (voce && chiave !== ultimoAnnuncio && g.metriAllaManovra < 320) {
            ultimoAnnuncio = chiave
            m("parla", [g.metriAllaManovra < 60 ? g.manovra.testo : I18n.t("Tra") + " " + g.allaManovra + ", " + g.manovra.annuncio])
        }
    }
    // disegno della manovra (tipi di Valhalla) e del mezzo pubblico
    function freccia(tipo) {
        if ([4, 5, 6].indexOf(tipo) >= 0) return "arrivo"
        if ([9, 18, 20, 23].indexOf(tipo) >= 0) return "leggera-destra"
        if (tipo === 10) return "svolta-destra"
        if (tipo === 11) return "brusca-destra"
        if ([12, 13].indexOf(tipo) >= 0) return "inversione"
        if (tipo === 14) return "brusca-sinistra"
        if (tipo === 15) return "svolta-sinistra"
        if ([16, 19, 21, 24].indexOf(tipo) >= 0) return "leggera-sinistra"
        if ([26, 27].indexOf(tipo) >= 0) return "rotonda"
        return "dritto"
    }
    function simboloMezzo(x) {
        return ({ WALK: "pedone", BUS: "autobus", COACH: "autobus", TRAM: "tram", SUBWAY: "metro", METRO: "metro", FERRY: "nave",
                  FUNICULAR: "funivia", CABLE_CAR: "funivia", AERIAL_LIFT: "funivia" })[x] || "treno"
    }

    Connections {
        target: ponte
        function onCompletato(id, r) {
            if (id.indexOf("mappe-") !== 0) return
            var parti = id.split(":")
            if (parti.length === 2) {
                if ((parti[0] === "mappe-cerca" || parti[0] === "mappe-vicini") && parseInt(parti[1]) !== app.nRicerca) return
                if (parti[0] === "mappe-percorso" && parseInt(parti[1]) !== app.nPercorso) return
                id = parti[0]
            }
            if (id === "mappe-qui" || id === "mappe-guida-qui") {
                if (!r || r.lat === undefined) return
                if (app.qui && r.direzione === undefined && (Math.abs(r.lat - app.qui.lat) + Math.abs(r.lon - app.qui.lon)) > 0.00005)
                    r.direzione = Math.atan2((r.lon - app.qui.lon) * Math.cos(r.lat * Math.PI / 180), r.lat - app.qui.lat) * 180 / Math.PI
                app.qui = r
                if (id === "mappe-guida-qui") app.aggiorna(r)
                else if (!app.luogo && !app.guidando) carta.centra(r.lat, r.lon, r.fonte === "ip" ? 12 : 15)
            } else if (id === "mappe-cerca" || id === "mappe-vicini") {
                app.cercando = false
                app.risultati = r || []
                if (id === "mappe-vicini" && !(r || []).length) tel.avviso(I18n.t("Niente di questo tipo qui vicino"))
            } else if (id === "mappe-dettagli") {
                if (app.luogo && r && Math.abs(r.lat - app.luogo.lat) < 0.01) app.luogo = r
            } else if (id === "mappe-percorso") {
                app.calcolo = false
                if (!r || !r.ok) { tel.avviso(r ? r.messaggio : I18n.t("Nessun percorso trovato")); app.percorsi = []; return }
                app.percorsi = [r].concat(r.alternative || [])
                app.aperto = true          // il foglio si alza: percorso e «Avvia» subito in vista
                if (!app.guidando) carta.inquadra(r.forma)
            } else if (id === "mappe-punto") app.scegli(r)
        }
    }
    Component.onCompleted: { categorie = m("categorie"); ma("posizione", [], "mappe-qui") }

    Timer {
        interval: app.prova ? 700 : 2000
        repeat: true
        running: app.guidando
        onTriggered: {
            if (app.prova) {
                var f = app.percorso.forma
                app.indiceProva = Math.min(f.length - 1, app.indiceProva + (app.mezzo === "piedi" ? 1 : (app.mezzo === "bici" ? 2 : 4)))
                var p = { lat: f[app.indiceProva][0], lon: f[app.indiceProva][1] }
                var s = f[Math.min(f.length - 1, app.indiceProva + 2)]
                if (s[0] !== p.lat || s[1] !== p.lon) p.direzione = Math.atan2((s[1] - p.lon) * Math.cos(p.lat * Math.PI / 180), s[0] - p.lat) * 180 / Math.PI
                else if (app.qui) p.direzione = app.qui.direzione
                app.qui = p
                app.aggiorna(p)
            } else app.ma("posizione", [], "mappe-guida-qui")
        }
    }

    // ── Carta (gira con la direzione di marcia durante la guida) ──
    Item {
        anchors.fill: parent
        clip: true
        readonly property bool gira: app.guidando && app.ruota && !!app.qui && app.qui.direzione !== undefined && app.seguendo
        MappeCarta {
            id: carta
            anchors.centerIn: parent
            width: parent.gira ? Math.hypot(parent.width, parent.height) : parent.width
            height: parent.gira ? Math.hypot(parent.width, parent.height) : parent.height
            rotation: parent.gira ? -app.qui.direzione : 0
            Behavior on rotation { enabled: tel.movimento; RotationAnimation { duration: 600; direction: RotationAnimation.Shortest } }
            zoom: 6; lat: 42.5; lon: 12.5
            forma: app.percorso ? app.percorso.forma : []
            altre: app.guidando ? [] : app.percorsi.filter(function (x, i) { return i !== app.scelto }).map(function (x) { return x.forma })
            posizione: app.qui
            segnaposti: {
                var s = []
                if (app.luogo) s.push({ id: "luogo", lat: app.luogo.lat, lon: app.luogo.lon, nome: app.luogo.nome, colore: "#EF4444" })
                if (app.partenza) s.push({ id: "partenza", lat: app.partenza.lat, lon: app.partenza.lon, nome: "", colore: "#22C55E" })
                for (var t = 0; t < app.tappe.length; t++) s.push({ id: "t" + t, lat: app.tappe[t].lat, lon: app.tappe[t].lon, nome: "", colore: "#A855F7" })
                for (var i = 0; i < app.risultati.length; i++) s.push({ id: "r" + i, lat: app.risultati[i].lat, lon: app.risultati[i].lon, nome: "", colore: "#F97316" })
                return s
            }
            onSegnapostoScelto: function (ident) { if (ident.charAt(0) === "r") app.scegli(app.risultati[parseInt(ident.slice(1))]) }
            onPuntoScelto: function (la, lo) { app.ma("indirizzo", [la, lo], "mappe-punto") }
            onSpostataAMano: app.seguendo = false
        }
    }

    // ── In alto: ricerca e categorie ──
    Column {
        visible: !app.guidando
        x: tel.margine; y: 50
        width: parent.width - 2 * tel.margine
        spacing: 8
        Text {
            visible: app.modoCerca !== "luogo"
            text: (app.modoCerca === "partenza" ? I18n.t("Da dove parti?") : I18n.t("Aggiungi una tappa")) + "   ·   " + I18n.t("Annulla")
            color: tel.accento; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.DemiBold
            MouseArea { anchors.fill: parent; onClicked: { app.modoCerca = "luogo"; app.risultati = []; campo.text = "" } }
        }
        Rectangle {
            width: parent.width; height: 50
            radius: 25
            color: tel.solido ? tel.pal.superficie : (tel.chiaro ? "#F2FFFFFF" : "#E6221E33")
            border.width: tel.solido ? 0 : 1
            border.color: tel.solido ? "transparent" : "#3DFFFFFF"
            Row {
                anchors.fill: parent; anchors.leftMargin: 16; spacing: 10
                Simbolo { anchors.verticalCenter: parent.verticalCenter; nome: "cerca"; lato: 19; colore: tel.pal.testo2 }
                TextInput {
                    id: campo
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 70
                    color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 16
                    clip: true
                    onTextChanged: attesa.restart()
                    Text { visible: !campo.text; text: app.modoCerca === "luogo" ? I18n.t("Cerca un luogo") : I18n.t("Cerca o tieni premuto sulla mappa"); color: tel.pal.testo3; font: campo.font }
                    Timer { id: attesa; interval: 500; onTriggered: app.cerca(campo.text) }
                }
                BusyIndicator { anchors.verticalCenter: parent.verticalCenter; visible: app.cercando; running: visible; width: 22; height: 22 }
            }
        }
        // categorie, scorrono di lato
        ListView {
            visible: !app.luogo && app.modoCerca === "luogo" && !campo.text
            width: parent.width; height: 36
            orientation: ListView.Horizontal
            spacing: 6
            clip: true
            model: app.categorie
            delegate: Rectangle {
                id: cat
                required property var modelData
                required property int index
                // ogni categoria ha il suo colore (in Prisma pieno quando è scelta)
                readonly property color tinta: ["#FF6B4A", "#8B6CFF", "#59C3FF", "#FFB443", "#3EE0B0", "#FF74A6"][index % 6]
                readonly property bool scelta: app.categoria === modelData.id
                width: tCat.implicitWidth + 26; height: 36; radius: 18
                color: scelta ? (tel.solido ? tinta : tel.accento) : (tel.solido ? tel.pal.superficie : (tel.chiaro ? "#F2FFFFFF" : "#E6221E33"))
                border.width: tel.solido ? 0 : 1
                border.color: tel.solido ? "transparent" : "#3DFFFFFF"
                Row {
                    id: tCat; anchors.centerIn: parent; spacing: 6
                    Simbolo { anchors.verticalCenter: parent.verticalCenter; nome: cat.modelData.simbolo; lato: 15; colore: cat.scelta ? "#FFFFFF" : (tel.solido ? cat.tinta : tel.accento) }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: cat.modelData.nome; color: cat.scelta ? "white" : tel.pal.testo; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                }
                MouseArea { anchors.fill: parent; onClicked: app.cercaCategoria(cat.modelData) }
            }
        }
        Rectangle {
            visible: app.modoCerca === "partenza"
            width: posTesto.implicitWidth + 30; height: 38; radius: 19
            color: tel.chiaro ? "#F2FFFFFF" : "#EB1E293B"
            Row {
                id: posTesto; anchors.centerIn: parent; spacing: 6
                Simbolo { anchors.verticalCenter: parent.verticalCenter; nome: "mirino"; lato: 16; colore: tel.accento }
                Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.t("La mia posizione"); color: tel.accento; font.family: Tema.font; font.pixelSize: 14 }
            }
            MouseArea { anchors.fill: parent; onClicked: { app.partenza = null; app.modoCerca = "luogo"; app.indicazioni() } }
        }
    }

    // ── Foglio in basso ──
    Rectangle {
        id: foglio
        visible: !app.guidando && (app.risultati.length > 0 || !!app.luogo)
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: Math.min(parent.height * (app.aperto ? 0.8 : 0.5), colFoglio.implicitHeight + 44)
        Behavior on height { enabled: tel.movimento; NumberAnimation { duration: tel.tNormale; easing.type: Easing.OutCubic } }
        radius: 26
        color: tel.chiaro ? "#F7FFFFFF" : "#F21E293B"
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter; y: 8; width: 40; height: 5; radius: 3; color: tel.pal.testo3; opacity: 0.6
            MouseArea { anchors.fill: parent; anchors.margins: -14; onClicked: app.aperto = !app.aperto }
        }
        Flickable {
            anchors.fill: parent; anchors.topMargin: 24; anchors.leftMargin: tel.margine; anchors.rightMargin: tel.margine; anchors.bottomMargin: 18
            contentHeight: colFoglio.implicitHeight
            clip: true
            Column {
                id: colFoglio
                width: parent.width
                spacing: 10

                // risultati
                Repeater {
                    model: app.risultati
                    Item {
                        width: colFoglio.width; height: 56
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            Row {
                                width: parent.width
                                Text { width: parent.width - 70; text: modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                Text { width: 70; horizontalAlignment: Text.AlignRight; text: modelData.distanza !== undefined ? app.m("testoDistanza", [modelData.distanza]) : ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 12 }
                            }
                            Row {
                                spacing: 6
                                Text {
                                    visible: modelData.aperto === true || modelData.aperto === false
                                    text: modelData.aperto ? I18n.t("Aperto") : I18n.t("Chiuso")
                                    color: modelData.aperto ? "#22C55E" : "#EF4444"; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.DemiBold
                                }
                                Text { width: colFoglio.width - 60; text: modelData.dettaglio || ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 13; elide: Text.ElideRight }
                            }
                        }
                        MouseArea { anchors.fill: parent; onClicked: app.scegli(modelData) }
                    }
                }

                // scheda del luogo
                Column {
                    visible: !!app.luogo && app.risultati.length === 0
                    width: parent.width
                    spacing: 8
                    Row {
                        width: parent.width
                        Text { width: parent.width - 30; text: app.luogo ? app.luogo.nome : ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 22; font.weight: Font.Bold; wrapMode: Text.WordWrap }
                        Simbolo {
                            nome: "chiudi"; lato: 20; colore: tel.pal.testo2
                            MouseArea { anchors.fill: parent; anchors.margins: -12; onClicked: { app.luogo = null; app.percorsi = []; app.tappe = []; app.partenza = null } }
                        }
                    }
                    Text {
                        visible: !!app.luogo && (app.luogo.aperto === true || app.luogo.aperto === false)
                        text: app.luogo && app.luogo.aperto ? I18n.t("Aperto ora") : I18n.t("Chiuso ora")
                        color: app.luogo && app.luogo.aperto ? "#22C55E" : "#EF4444"; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.DemiBold
                    }
                    Text { width: parent.width; text: app.luogo ? (app.luogo.indirizzo || app.luogo.dettaglio || "") : ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 14; wrapMode: Text.WordWrap }
                    // pulsanti tondi: indicazioni, chiama, sito, salva, condividi
                    Row {
                        spacing: 12
                        Repeater {
                            model: [
                                { t: I18n.t("Vai"), s: "naviga", pieno: true, ok: true, f: function () { app.indicazioni() } },
                                { t: I18n.t("Chiama"), s: "telefono", ok: !!(app.luogo && app.luogo.telefono), f: function () { app.m("apri", ["tel:" + app.luogo.telefono.replace(/\s/g, "")]) } },
                                { t: I18n.t("Sito"), s: "globo", ok: !!(app.luogo && app.luogo.sito), f: function () { app.m("apri", [app.luogo.sito]) } },
                                { t: I18n.t("Salva"), s: "stella", ok: true, f: function () { app.m("preferito", [app.luogo, ""]); tel.avviso(I18n.t("Salvato nei preferiti")) } },
                                { t: I18n.t("Condividi"), s: "condividi", ok: true, f: function () { tel.copia(app.m("collegamento", [app.luogo.lat, app.luogo.lon])); tel.avviso(I18n.t("Collegamento copiato")) } }
                            ]
                            Column {
                                spacing: 4
                                opacity: modelData.ok ? 1 : 0.35
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 52; height: 52; radius: 26
                                    color: modelData.pieno ? tel.accento : tel.pal.superficie2
                                    Simbolo { anchors.centerIn: parent; nome: modelData.s; lato: 22; colore: modelData.pieno ? "#FFFFFF" : tel.accento }
                                    MouseArea { anchors.fill: parent; enabled: modelData.ok; onClicked: modelData.f() }
                                }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.t; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 11 }
                            }
                        }
                    }
                    Rectangle {
                        visible: !!(app.luogo && app.luogo.orari) && app.percorsi.length === 0
                        width: parent.width; height: orariTesto.implicitHeight + 36; radius: 14
                        color: tel.pal.superficie
                        Column {
                            x: 14; y: 10; width: parent.width - 28
                            Text { text: I18n.t("Orari"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 12 }
                            Text { id: orariTesto; width: parent.width; text: app.luogo ? (app.luogo.orari || "") : ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 14; wrapMode: Text.WordWrap }
                        }
                    }
                }

                // indicazioni
                Column {
                    visible: (app.percorsi.length > 0 || app.calcolo) && !!app.luogo && app.risultati.length === 0
                    width: parent.width
                    spacing: 8
                    Rectangle { width: parent.width; height: 1; color: tel.pal.bordo }
                    Row {
                        width: parent.width
                        spacing: 8
                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 10; height: 10; radius: 5; color: "#22C55E" }
                        Text { width: parent.width - 112; text: I18n.t("Da") + ": " + (app.partenza ? app.partenza.nome : I18n.t("La mia posizione")); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 14; elide: Text.ElideRight }
                        Text { width: 86; horizontalAlignment: Text.AlignRight; text: I18n.t("Cambia"); color: tel.accento; font.family: Tema.font; font.pixelSize: 14
                            MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: { app.modoCerca = "partenza"; campo.forceActiveFocus() } } }
                    }
                    Repeater {
                        model: app.mezzo === "mezzi" ? [] : app.tappe
                        Row {
                            width: colFoglio.width
                            spacing: 8
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 10; height: 10; radius: 5; color: "#A855F7" }
                            Text { width: parent.width - 48; text: I18n.t("Tappa") + ": " + modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 14; elide: Text.ElideRight }
                            Simbolo { nome: "chiudi"; lato: 16; colore: tel.pal.testo2
                                MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: { var t = app.tappe.slice(); t.splice(index, 1); app.tappe = t; app.indicazioni() } } }
                        }
                    }
                    Row {
                        width: parent.width
                        spacing: 8
                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 10; height: 10; radius: 5; color: "#EF4444" }
                        Text { width: parent.width - 88; text: I18n.t("A") + ": " + (app.luogo ? app.luogo.nome : ""); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 14; elide: Text.ElideRight }
                        Text { visible: app.mezzo !== "mezzi"; width: 86; horizontalAlignment: Text.AlignRight; text: "+ " + I18n.t("Tappa"); color: tel.accento; font.family: Tema.font; font.pixelSize: 14
                            MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: { app.modoCerca = "tappa"; campo.forceActiveFocus() } } }
                    }
                    Row {
                        spacing: 8
                        Repeater {
                            model: [{ id: "auto", s: "auto" }, { id: "mezzi", s: "treno" }, { id: "bici", s: "bici" }, { id: "piedi", s: "pedone" }]
                            Rectangle {
                                width: 58; height: 40; radius: 20
                                color: app.mezzo === modelData.id ? tel.accento : tel.pal.superficie2
                                Simbolo { anchors.centerIn: parent; nome: modelData.s; lato: 20; colore: app.mezzo === modelData.id ? "#FFFFFF" : tel.pal.testo }
                                MouseArea { anchors.fill: parent; onClicked: { app.mezzo = modelData.id; app.indicazioni() } }
                            }
                        }
                    }
                    Repeater {
                        model: app.mezzo === "auto" ? [{ k: "pedaggi", t: I18n.t("Evita pedaggi") }, { k: "autostrade", t: I18n.t("Evita autostrade") }, { k: "traghetti", t: I18n.t("Evita traghetti") }] : []
                        Item {
                            width: colFoglio.width; height: 34
                            Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.t; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 15 }
                            Rectangle {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                width: 46; height: 28; radius: 14
                                readonly property bool acceso: app.opzioni[modelData.k] === false
                                color: acceso ? "#22C55E" : tel.pal.superficie2
                                Rectangle { width: 24; height: 24; radius: 12; y: 2; x: parent.acceso ? 20 : 2; color: "white"; Behavior on x { NumberAnimation { duration: 120 } } }
                                MouseArea { anchors.fill: parent; onClicked: { var o = Object.assign({}, app.opzioni); o[modelData.k] = parent.acceso; app.opzioni = o; app.indicazioni() } }
                            }
                        }
                    }
                    BusyIndicator { visible: app.calcolo; running: visible; width: 30; height: 30 }
                    Repeater {
                        model: app.calcolo ? [] : app.percorsi
                        Rectangle {
                            id: sch
                            required property var modelData
                            required property int index
                            width: colFoglio.width
                            height: colSch.implicitHeight + 20
                            radius: 16
                            color: index === app.scelto ? (tel.chiaro ? "#E8EFFE" : "#1E2A44") : tel.pal.superficie
                            border.color: index === app.scelto ? tel.accento : "transparent"
                            MouseArea { anchors.fill: parent; onClicked: app.scegliPercorso(sch.index) }
                            Column {
                                id: colSch
                                x: 14; y: 10; width: parent.width - 28
                                spacing: 4
                                Row {
                                    spacing: 10
                                    Text { text: sch.modelData.tempo; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 22; font.weight: Font.Bold }
                                    Text {
                                        anchors.baseline: parent.children[0].baseline
                                        text: sch.modelData.mezzo === "mezzi" ? sch.modelData.parte + " – " + sch.modelData.arrivo : sch.modelData.distanza + " · " + sch.modelData.arrivo
                                        color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 13
                                    }
                                }
                                Text {
                                    visible: sch.modelData.mezzo !== "mezzi"
                                    text: (sch.index === 0 ? I18n.t("Il più veloce") : I18n.t("Alternativa")) + (sch.modelData.pedaggi ? " · " + I18n.t("pedaggi") : "") + (sch.modelData.autostrade ? " · " + I18n.t("autostrade") : "")
                                    color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 12
                                }
                                Flow {
                                    visible: sch.modelData.mezzo === "mezzi"
                                    width: parent.width; spacing: 4
                                    Repeater {
                                        model: sch.modelData.tratti || []
                                        Rectangle {
                                            visible: modelData.mezzo !== "WALK" || modelData.minuti > 0
                                            height: 24; radius: 7; width: tTr.implicitWidth + 12
                                            color: modelData.mezzo === "WALK" ? "transparent" : modelData.colore
                                            Row {
                                                id: tTr; anchors.centerIn: parent; spacing: 4
                                                Simbolo { anchors.verticalCenter: parent.verticalCenter; nome: app.simboloMezzo(modelData.mezzo); lato: 15; colore: modelData.mezzo === "WALK" ? tel.pal.testo2 : "#FFFFFF" }
                                                Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.mezzo === "WALK" ? modelData.minuti + "′" : modelData.linea; color: modelData.mezzo === "WALK" ? tel.pal.testo2 : "white"; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                                            }
                                        }
                                    }
                                }
                                Repeater {
                                    model: sch.modelData.mezzo === "mezzi" && sch.index === app.scelto ? (sch.modelData.tratti || []) : []
                                    Row {
                                        width: colSch.width; spacing: 6
                                        Text { text: modelData.parte; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 13 }
                                        Simbolo { nome: app.simboloMezzo(modelData.mezzo); lato: 15; colore: modelData.mezzo === "WALK" ? tel.pal.testo2 : modelData.colore }
                                        Text {
                                            width: colSch.width - 70; wrapMode: Text.WordWrap
                                            text: modelData.mezzo === "WALK" ? I18n.t("A piedi") + " " + modelData.minuti + " min" : modelData.nome + " " + modelData.linea + (modelData.direzione ? " → " + modelData.direzione : "") + " · " + modelData.fermate + " " + I18n.t("fermate")
                                            color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 13
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Row {
                        visible: !!app.percorso && !app.calcolo && app.mezzo !== "mezzi"
                        spacing: 10
                        Rectangle {
                            width: (colFoglio.width - 10) * 0.6; height: 50; radius: 25; color: tel.coloreChiama
                            Text { anchors.centerIn: parent; text: I18n.t("Avvia"); color: tel.solido ? "#141414" : "white"; font.family: Tema.font; font.pixelSize: 17; font.weight: Font.Bold }
                            MouseArea { anchors.fill: parent; onClicked: app.avvia(false) }
                        }
                        Rectangle {
                            width: (colFoglio.width - 10) * 0.4; height: 50; radius: 25; color: tel.pal.superficie2
                            Text { anchors.centerIn: parent; text: I18n.t("Prova"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 15 }
                            MouseArea { anchors.fill: parent; onClicked: app.avvia(true) }
                        }
                    }
                }
            }
        }
    }

    // ── Guida ──
    Column {
        visible: app.guidando && !!app.stato
        x: tel.margine; y: 46
        width: parent.width - 2 * tel.margine
        spacing: 0
        Rectangle {
            width: parent.width; height: 104
            radius: 24
            color: "#1E3A8A"
            Row {
                anchors.fill: parent; anchors.margins: 16; spacing: 16
                Simbolo { anchors.verticalCenter: parent.verticalCenter; nome: app.stato ? app.freccia(app.stato.manovra.tipo) : ""; lato: 48; colore: "#FFFFFF" }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 80
                    Text { text: app.stato ? app.stato.allaManovra : ""; color: "white"; font.family: Tema.font; font.pixelSize: 28; font.weight: Font.Bold }
                    Text { width: parent.width; text: app.stato ? app.stato.manovra.testo : ""; color: "#E0E7FF"; font.family: Tema.font; font.pixelSize: 15; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
                }
            }
        }
        Rectangle {
            visible: !!(app.stato && app.stato.dopo)
            x: 16
            width: Math.min(parent.width - 32, tDopo.implicitWidth + 24); height: 32
            radius: 10; color: "#172E6E"
            Row {
                id: tDopo; anchors.centerIn: parent; spacing: 6
                Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Poi"); color: "#E0E7FF"; font.family: Tema.font; font.pixelSize: 13 }
                Simbolo { anchors.verticalCenter: parent.verticalCenter; nome: app.stato && app.stato.dopo ? app.freccia(app.stato.dopo.tipo) : ""; lato: 15; colore: "#E0E7FF" }
                Text { anchors.verticalCenter: parent.verticalCenter; width: Math.min(implicitWidth, app.width - 140); elide: Text.ElideRight
                    text: app.stato && app.stato.dopo ? (app.stato.dopo.via || app.stato.dopo.testo) : ""; color: "#E0E7FF"; font.family: Tema.font; font.pixelSize: 13 }
            }
        }
    }
    Rectangle {
        visible: app.guidando && !!app.stato && app.stato.limite > 0
        x: tel.margine; anchors.bottom: parent.bottom; anchors.bottomMargin: 150
        width: 62; height: 62; radius: 31
        color: "white"; border.color: "#DC2626"; border.width: 7
        Text { anchors.centerIn: parent; text: app.stato ? app.stato.limite : ""; color: "#111111"; font.family: Tema.font; font.pixelSize: 21; font.weight: Font.Bold }
    }
    Rectangle {
        visible: app.guidando
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 128; radius: 26
        color: tel.chiaro ? "#F7FFFFFF" : "#F21E293B"
        Text {
            x: tel.margine + 6; y: 12; width: parent.width - 2 * tel.margine - 12
            text: app.stato && app.stato.via ? app.stato.via : ""
            color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 14; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
        }
        Row {
            y: 42; x: tel.margine + 6; spacing: 18
            Column {
                Text { text: app.stato ? app.stato.arrivo : ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 24; font.weight: Font.Bold }
                Text { text: I18n.t("arrivo"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 12 }
            }
            Column {
                Text { text: app.stato ? app.stato.tempo : ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 20; font.weight: Font.DemiBold }
                Text { text: app.stato ? app.stato.resta : ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 12 }
            }
        }
        Row {
            y: 44; anchors.right: parent.right; anchors.rightMargin: tel.margine; spacing: 8
            Repeater {
                model: [
                    { s: app.voce ? "volume" : "silenzioso", f: function () { app.voce = !app.voce } },
                    { s: app.seguendo ? (app.ruota ? "bussola" : "nord") : "mirino", f: function () { if (!app.seguendo) { app.seguendo = true; if (app.qui) carta.centra(app.qui.lat, app.qui.lon, 17) } else app.ruota = !app.ruota } }
                ]
                Rectangle {
                    width: 46; height: 46; radius: 23; color: tel.pal.superficie2
                    Simbolo { anchors.centerIn: parent; nome: modelData.s; lato: 20; colore: tel.pal.testo }
                    MouseArea { anchors.fill: parent; onClicked: modelData.f() }
                }
            }
            Rectangle {
                width: 78; height: 46; radius: 23; color: "#EF4444"
                Text { anchors.centerIn: parent; text: I18n.t("Fine"); color: "white"; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.DemiBold }
                MouseArea { anchors.fill: parent; onClicked: app.termina() }
            }
        }
    }
    // Dove sono
    Rectangle {
        visible: !app.guidando
        anchors.right: parent.right; anchors.rightMargin: tel.margine
        y: app.luogo || app.categoria ? 104 : 150
        width: 44; height: 44; radius: 22
        color: tel.chiaro ? "#F2FFFFFF" : "#EB1E293B"
        Simbolo { anchors.centerIn: parent; nome: "mirino"; lato: 22; colore: tel.accento }
        MouseArea { anchors.fill: parent; onClicked: { if (app.qui) carta.centra(app.qui.lat, app.qui.lon, 16); app.ma("posizione", [], "mappe-qui") } }
    }
}
