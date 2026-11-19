// SolidOS Mobile: l'interfaccia del telefono.
// Schermate: Blocco → (scorri in su) → Home ⇄ (scorri a sinistra) Libreria app.
// Dall'alto: a sinistra le Notifiche, a destra il Centro di controllo (come nel design).
// Sul PC è una finestra grande come un telefono; sul telefono va a tutto schermo.
import QtQuick
import QtQuick.Controls
import SolidUI

Window {
    id: tel
    visible: true
    width: ponte.chiama0("avvio").larghezza || 390
    height: ponte.chiama0("avvio").altezza || 844
    minimumWidth: 320
    minimumHeight: 600
    title: "SolidOS Mobile"
    color: "#000000"
    visibility: ponte.chiama0("schermoIntero") ? Window.FullScreen : Window.Windowed

    // ── Personalizza (salvato in mobile.json) ────────────────────────────
    property var imp: ponte.chiama0("impostazioni")
    function imposta(chiave, valore) { imp = ponte.chiama("imposta", [chiave, valore]) }

    // ── Tema «Vetro»: i colori, lo sfondo e il carattere del PC, con pannelli di vetro sfocato ──
    readonly property bool chiaro: imp.tema === "chiaro"
    readonly property real k: [0.9, 1.0, 1.15][imp.testo] || 1.0
    // Accento blu di SolidOS (lo stesso del PC); chi ne ha scelto un altro in Personalizza lo tiene
    readonly property color accento: (!imp.accento || imp.accento === "#3F7CF5" || imp.accento === "#FF3B30")
                                     ? (chiaro ? "#2F5FD0" : "#4C7DFF") : imp.accento
    readonly property color rosso: "#E5484D"
    // Colori del design (vedi docs/DESIGN.md), uguali a quelli del PC
    readonly property QtObject pal: QtObject {
        readonly property color sfondo: tel.chiaro ? "#F2F2F7" : "#1E1F24"        // fondo delle app
        readonly property color superficie: tel.chiaro ? "#FFFFFF" : "#26272D"    // schede, righe
        readonly property color superficie2: tel.chiaro ? "#E9E9EE" : "#2F3037"   // campi, pulsanti, tondi
        readonly property color bordo: tel.chiaro ? "#E5E5EA" : "#3A3B42"
        readonly property color testo: tel.chiaro ? "#1D1D1F" : "#F5F5F7"
        readonly property color testo2: tel.chiaro ? "#6E6E73" : "#A1A1AA"
        readonly property color testo3: tel.chiaro ? "#A1A1AA" : "#71717A"
        // Vetro: velatura sopra lo sfondo sfocato (blocco, Home, tendine)
        readonly property color vetro: tel.chiaro ? Qt.rgba(0.98, 0.98, 0.99, 0.62) : Qt.rgba(0.11, 0.114, 0.133, 0.58)
        readonly property color vetroBordo: tel.chiaro ? Qt.rgba(0, 0, 0, 0.07) : Qt.rgba(1, 1, 1, 0.10)
        readonly property color traccia: tel.chiaro ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(1, 1, 1, 0.10)
        readonly property color velo: tel.chiaro ? Qt.rgba(0.95, 0.95, 0.97, 0.30) : Qt.rgba(0.04, 0.05, 0.08, 0.38)
        readonly property color tessera: tel.chiaro ? "#FFFFFF" : "#26272D"
        readonly property color pieno: tel.accento
        readonly property color suPieno: "#FFFFFF"
        readonly property color successo: "#30A46C"
        readonly property color pericolo: "#E5484D"
    }
    // Movimento: aperture con curva «quint» (partono veloci e si posano morbide), chiusure più
    // brevi. Con «Riduci animazioni» tutto diventa istantaneo.
    readonly property bool movimento: imp.riduci_movimento !== true
    function durata(ms) { return movimento ? ms : 0 }
    readonly property int tVeloce: durata(150)
    readonly property int tNormale: durata(230)
    readonly property int tEntrata: durata(360)
    // Misure del design: raggi e margini uguali ovunque
    readonly property int r1: 12      // controlli piccoli
    readonly property int r2: 18      // schede
    readonly property int r3: 24      // pannelli grandi
    readonly property int margine: 18 // bordo dello schermo
    function px(n) { return Math.round(n * k) }
    // Caratteri: Inter ovunque, come sul PC (titoli grandi in grassetto, ora in semibold)
    readonly property string fontPunti: Tema.font
    readonly property string fontMono: Tema.font
    readonly property string fontOra: (!imp.orologio || ["League Spartan", "Doto", "Space Grotesk", "Space Mono"].indexOf(imp.orologio) >= 0) ? Tema.font : imp.orologio
    // Sfondo del PC (colline): file SVG e la sua versione chiara
    readonly property string nomeSfondo: ["notte", "alba", "oceano", "aurora", "grafite"].indexOf(imp.sfondo) >= 0 ? imp.sfondo : "notte"
    readonly property string sfondo: (imp.sfondo || "").charAt(0) === "/" ? "file://" + imp.sfondo
                                     : ponte.chiama("sfondo", [nomeSfondo, chiaro])
    // Colori dello sfondo dall'alto in basso: i pannelli di vetro ne prendono la sfumatura
    readonly property var coloriSfondo: sfondo ? ponte.chiama("coloriSfondo", [sfondo, Math.max(0.2, width / Math.max(1, height))]) : []
    function coloreSfondo(frazione) {
        var c = coloriSfondo
        if (!c || !c.length) return chiaro ? "#C9D3EE" : "#18203A"
        return c[Math.max(0, Math.min(c.length - 1, Math.round(frazione * (c.length - 1))))]
    }
    readonly property int latoIcona: [52, 58, 64][imp.icone === undefined ? 1 : imp.icone]

    // ── Stato del telefono ────────────────────────────────────────────────
    property string schermata: "blocco"          // blocco | home
    // Ogni volta che si entra nella Home le icone fanno la loro entrata scaglionata
    property int entrata: 0
    onSchermataChanged: if (schermata === "home") entrata++
    property bool notifiche: false
    property bool controllo: false
    property bool personalizza: false
    property string appInterna: ""               // telefono | messaggi (app dentro l'interfaccia)
    property var chiamataInfo: ({ attiva: false })
    property bool chiamataRidotta: false
    // Blocco a distanza da «Dov'è»: messaggio del proprietario sulla schermata di blocco
    property string messaggioRemoto: ""
    property bool perso: false                   // Dov'è › Modalità smarrito: si sblocca solo con il Solid ID
    property bool inizializzando: false          // Dov'è › Inizializza a distanza
    property string attivazione: ""              // blocco di attivazione: email nascosta del proprietario
    Timer { interval: 2000; running: true; repeat: true; onTriggered: ponte.avvia("richiestaBlocco", [], "blocco-remoto") }
    // Chiamate: controllo ogni secondo durante la chiamata, ogni 3 secondi per quelle in arrivo
    Timer {
        interval: tel.chiamataInfo.attiva ? 1000 : 3000
        running: true; repeat: true
        onTriggered: ponte.avvia("chiamata", [], "chiamata")
    }
    // ── Notifiche ─────────────────────────────────────────────────────────
    property var elencoNotifiche: ponte.chiama0("notifiche")
    property var banner: null
    function aggiornaNotifiche() { elencoNotifiche = ponte.chiama0("notifiche") }
    function chiudiNotifica(id) { ponte.chiama("chiudiNotifica", [id]); aggiornaNotifiche(); if (banner && banner.id === id) banner = null }
    function nonDisturbare(si) { ponte.chiama("nonDisturbare", [si]); imp = ponte.chiama0("impostazioni") }
    Timer { interval: 20000; running: true; repeat: true; onTriggered: ponte.avvia("controllaSms", [], "sms") }
    Timer { id: fineBanner; onTriggered: tel.banner = null }

    function chiama(numero) {
        var r = ponte.chiama("chiama", [numero])
        if (!r.ok) { avviso(r.messaggio); return }
        chiamataRidotta = false
        chiamataInfo = ponte.chiama0("chiamata")
    }
    property var stato: ponte.chiama0("stato")
    property date adesso: new Date()
    Timer { interval: 15000; running: true; repeat: true; onTriggered: { tel.adesso = new Date(); ponte.avvia("stato", [], "stato") } }
    Connections {
        target: ponte
        function onEvento(nome, d) {
            if (nome === "notifica") {
                tel.aggiornaNotifiche()
                if (d.mostra) { tel.banner = d.notifica; fineBanner.interval = d.notifica.scadenza > 0 ? d.notifica.scadenza : 6000; fineBanner.restart() }
            } else if (nome === "chiusa") tel.aggiornaNotifiche()
        }
        function onCompletato(id, r) {
            if (id === "stato") tel.stato = r
            else if (id === "attivazione") tel.attivazione = r || ""
            else if (id === "blocco-remoto") {
                if (r.cancella && !tel.inizializzando) { tel.inizializzando = true; fineInizializza.start() }
                if (r.blocca || (r.perso && !tel.perso)) { tel.messaggioRemoto = r.messaggio; tel.chiudiTutto(); tel.appInterna = ""; tel.schermata = "blocco" }
                tel.perso = r.perso === true
            }
            else if (id === "chiamata") {
                if (r.inArrivo && !tel.chiamataInfo.inArrivo) tel.chiamataRidotta = false
                tel.chiamataInfo = r
            }
        }
    }
    function ora() { return Qt.formatTime(adesso, "H:mm") }
    function giorno() {
        var g = adesso.toLocaleDateString(Qt.locale("it_IT"), "dddd d MMMM")
        return g
    }
    function apri(app) {
        // App dello Store già aperta: torna in primo piano
        if (compositore.item && app.id.indexOf("interno:") !== 0 && compositore.item.attivaApp(app.id)) return
        var r = ponte.chiama("avvia", [app.id])
        if (r.interna) { chiudiTutto(); appInterna = r.interna }
        else if (!r.ok) avviso(r.messaggio)
    }
    // Passaggi tra app: file da mandare con Vicina, brano da suonare, testo negli appunti
    property var daCondividere: []
    property string branoDaSuonare: ""
    // Widget Musica: cosa suona (lo aggiorna Musica) e i comandi dal widget
    property var musica: ({ titolo: "", artista: "", suona: false })
    signal comandoMusica(string c)
    property bool modificaHome: false           // Home in modifica: icone che tremano, «−», «+» e «Fine»
    function condividi(percorsi) { daCondividere = percorsi; chiudiTutto(); appInterna = "vicina" }
    function copia(testo) { appunti.text = testo; appunti.selectAll(); appunti.copy() }
    function ricaricaApp() { home.app = ponte.chiama0("home"); home.dock = ponte.chiama0("dock") }
    TextEdit { id: appunti; visible: false }
    function avviso(testo) { messaggio.testo = testo; messaggio.opacity = 1; nascondi.restart() }
    function chiudiTutto() { notifiche = false; controllo = false; personalizza = false }
    Component.onCompleted: {
        ponte.avvia("voipAvvia", [], "voip-avvio")   // chiamate via Internet: si collega all'account SIP
        ponte.avvia("bloccoAttivazione", [], "attivazione")   // telefono di un altro Solid ID?
        var a = ponte.chiama0("avvio")
        if (a.tema) imp = Object.assign({}, imp, { tema: a.tema })
        if (!a.schermata || a.schermata === "blocco") return
        if (a.schermata === "bloccato") { messaggioRemoto = I18n.t("Se lo trovi chiama il 333 123 4567. Grazie!"); return }
        if (a.schermata === "perso") { messaggioRemoto = I18n.t("Se lo trovi chiama il 333 123 4567. Grazie!"); perso = true; return }
        if (a.schermata === "perso-sblocca") { messaggioRemoto = I18n.t("Se lo trovi chiama il 333 123 4567. Grazie!"); perso = true; bloccoSchermata.entra(); return }
        if (a.schermata === "codice") { bloccoSchermata.chiedeCodice = true; return }
        schermata = "home"
        if (a.schermata === "libreria") home.pagina = 1
        else if (a.schermata === "controllo") controllo = true
        else if (a.schermata === "notifiche") notifiche = true
        else if (a.schermata === "personalizza") personalizza = true
        else if (a.schermata === "telefono") appInterna = "telefono"
        else if (a.schermata === "recenti") { appInterna = "telefono"; telefonoApp.scheda = "recenti" }
        else if (a.schermata === "messaggi") appInterna = "messaggi"
        else if (a.schermata === "conversazione") { appInterna = "messaggi"; var c = ponte.chiama0("conversazioni"); if (c.length) messaggiApp.apri(c[0].numero) }
        else if (a.schermata === "contatti") appInterna = "contatti"
        else if (a.schermata === "dove") appInterna = "dove"
        else if (["calcolatrice", "note", "file", "foto", "musica", "fotocamera", "store", "vicina"].indexOf(a.schermata) >= 0) appInterna = a.schermata
        else if (a.schermata === "store-app" || a.schermata === "store-raccolta" || a.schermata === "store-mie" || a.schermata === "store-scarica") appInterna = "store"
        else if (a.schermata === "foto-account" || a.schermata === "foto-google" || a.schermata === "foto-casa" || a.schermata === "foto-una") appInterna = "foto"
        else if (a.schermata === "segreteria") { appInterna = "telefono"; telefonoApp.scheda = "segreteria" }
        else if (a.schermata === "condividi") condividi(ponte.chiama0("foto").slice(0, 2).map(function (f) { return f.percorso }))
        else if (a.schermata === "impostazioni") appInterna = "impostazioni"
        else if (["wifi", "bluetooth", "rete", "suoni", "schermo", "batteria", "info", "solidid", "sicurezza"].indexOf(a.schermata) >= 0) { appInterna = "impostazioni"; impostazioniApp.apri(a.schermata) }
        else if (a.schermata === "home-widget") { imp = Object.assign({}, imp, { widget: [{ tipo: "meteo", misura: "piccolo" }, { tipo: "oggi", misura: "piccolo" }, { tipo: "musica", misura: "medio" }] }) }
        else if (a.schermata === "home-modifica") { imp = Object.assign({}, imp, { widget: [{ tipo: "meteo", misura: "piccolo" }, { tipo: "oggi", misura: "piccolo" }] }); modificaHome = true }
        else if (a.schermata === "home-galleria") { modificaHome = true; galleriaWidget.apri() }
        else if (a.schermata === "home-misura") { modificaHome = true; galleriaWidget.apri(); galleriaWidget.scelto = "batterie" }
        else if (a.schermata === "home-scure" || a.schermata === "home-tinta") { imp = Object.assign({}, imp, { stile_icone: a.schermata.slice(5) }) }
        else if (a.schermata.indexOf("file-") === 0) appInterna = "file"
        else if (a.schermata.indexOf("calc-") === 0) appInterna = "calcolatrice"
        else if (a.schermata === "tastiera" || a.schermata === "tastierino") { appInterna = "contatti"; contattiApp.nuovo() }
        else if (a.schermata === "voip") { appInterna = "impostazioni"; impostazioniApp.apri("chiamate") }
        else if (a.schermata === "mia-scheda") { appInterna = "contatti"; contattiApp.aggiorna(); contattiApp.apri(contattiApp.mia) }
        else if (a.schermata === "modifica-contatto") { appInterna = "contatti"; var cm = ponte.chiama0("contatti"); if (cm.length) { contattiApp.apri(cm[1] || cm[0]); contattiApp.modifica = true } }
        else if (a.schermata === "scheda") { appInterna = "contatti"; var cs = ponte.chiama0("contatti"); if (cs.length) contattiApp.apri(cs[1] || cs[0]) }
        else if (a.schermata === "banner") { schermata = "home"; var nn = ponte.chiama0("notifiche"); if (nn.length) banner = nn[0] }
        else if (a.schermata === "chiamata") { var cc = ponte.chiama0("contatti"); if (cc.length) chiama(cc[0].numero) }
    }
    // --foto=PERCORSO: salva una foto della schermata ed esce (prova automatica)
    Timer {
        interval: (ponte.chiama0("avvio").schermata || "").indexOf("store") === 0 ? 12000 : 2500   // lo Store aspetta il catalogo
        running: ponte.chiama0("avvio").foto !== undefined
        onTriggered: tel.contentItem.grabToImage(function (r) { r.saveToFile(ponte.chiama0("avvio").foto); Qt.quit() })
    }

    // ── Sfondo: disegnato dal sistema (niente file), oppure una foto scelta in Foto ──
    Sfondo {
        anchors.fill: parent
    }

    // ── Schermate ─────────────────────────────────────────────────────────
    Home {
        id: home
        anchors.fill: parent
        visible: tel.schermata === "home"
        // Profondità: quando sopra si apre un'app la Home arretra un poco e si spegne
        readonly property bool coperta: tel.appInterna !== ""
        scale: coperta ? 0.94 : 1
        opacity: coperta ? 0 : 1
        Behavior on scale { NumberAnimation { duration: tel.tEntrata; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: tel.tNormale; easing.type: Easing.OutQuad } }
    }
    Blocco {
        id: bloccoSchermata
        anchors.fill: parent
        visible: tel.schermata === "blocco"
        onSblocca: tel.schermata = "home"
    }

    // ── App interne (Telefono, Messaggi): pagine a tutto schermo che salgono dal basso ──
    Telefono {
        id: telefonoApp
        anchors.left: parent.left; anchors.right: parent.right
        height: parent.height - tastiera.altezza
        // Si apre ingrandendosi dal centro (94% → 100%) e comparendo; si chiude più in fretta
        property real apertura: tel.appInterna === "telefono" ? 1 : 0
        Behavior on apertura { Movimento { apre: tel.appInterna === "telefono" } }
        y: (1 - apertura) * 40
        opacity: apertura
        scale: 0.94 + 0.06 * apertura
        visible: apertura > 0.001
    }
    Dove {
        id: doveApp
        anchors.left: parent.left; anchors.right: parent.right
        height: parent.height - tastiera.altezza
        // Si apre ingrandendosi dal centro (94% → 100%) e comparendo; si chiude più in fretta
        property real apertura: tel.appInterna === "dove" ? 1 : 0
        Behavior on apertura { Movimento { apre: tel.appInterna === "dove" } }
        y: (1 - apertura) * 40
        opacity: apertura
        scale: 0.94 + 0.06 * apertura
        visible: apertura > 0.001
    }
    Impostazioni {
        id: impostazioniApp
        anchors.left: parent.left; anchors.right: parent.right
        height: parent.height - tastiera.altezza
        // Si apre ingrandendosi dal centro (94% → 100%) e comparendo; si chiude più in fretta
        property real apertura: tel.appInterna === "impostazioni" ? 1 : 0
        Behavior on apertura { Movimento { apre: tel.appInterna === "impostazioni" } }
        y: (1 - apertura) * 40
        opacity: apertura
        scale: 0.94 + 0.06 * apertura
        visible: apertura > 0.001
    }
    Contatti {
        id: contattiApp
        anchors.left: parent.left; anchors.right: parent.right
        height: parent.height - tastiera.altezza
        // Si apre ingrandendosi dal centro (94% → 100%) e comparendo; si chiude più in fretta
        property real apertura: tel.appInterna === "contatti" ? 1 : 0
        Behavior on apertura { Movimento { apre: tel.appInterna === "contatti" } }
        y: (1 - apertura) * 40
        opacity: apertura
        scale: 0.94 + 0.06 * apertura
        visible: apertura > 0.001
    }
    Messaggi {
        id: messaggiApp
        anchors.left: parent.left; anchors.right: parent.right
        height: parent.height - tastiera.altezza
        // Si apre ingrandendosi dal centro (94% → 100%) e comparendo; si chiude più in fretta
        property real apertura: tel.appInterna === "messaggi" ? 1 : 0
        Behavior on apertura { Movimento { apre: tel.appInterna === "messaggi" } }
        y: (1 - apertura) * 40
        opacity: apertura
        scale: 0.94 + 0.06 * apertura
        visible: apertura > 0.001
    }

    // ── App di base: caricate solo quando servono (meno memoria) ─────────
    component PaginaApp: Loader {
        property string nome: ""
        property bool resta: false          // Musica: continua a suonare quando la chiudi
        property bool usata: false
        anchors.left: parent.left; anchors.right: parent.right
        height: parent.height - tastiera.altezza
        property real apertura: tel.appInterna === nome ? 1 : 0
        Behavior on apertura { Movimento { apre: tel.appInterna === nome } }
        y: (1 - apertura) * 40
        opacity: apertura
        scale: 0.94 + 0.06 * apertura
        visible: apertura > 0.001
        active: tel.appInterna === nome || visible || (resta && usata)
        onActiveChanged: if (active) usata = true
        asynchronous: false
    }
    // ── App dello Store: si aprono dentro SolidOS (compositore Wayland) ──
    Loader {
        id: compositore
        anchors.fill: parent; z: 30
        source: "Compositore.qml"
        onStatusChanged: if (status === Loader.Error) ponte.chiama("compositorePronto", [""])   // senza: come prima
    }
    PaginaApp { nome: "calcolatrice"; source: "Calcolatrice.qml" }
    PaginaApp { nome: "note"; source: "Note.qml" }
    PaginaApp { nome: "file"; source: "FileApp.qml" }
    PaginaApp { nome: "foto"; source: "Foto.qml" }
    PaginaApp { nome: "musica"; source: "Musica.qml"; resta: true }
    PaginaApp { nome: "fotocamera"; source: "Fotocamera.qml" }
    PaginaApp { nome: "store"; source: "Store.qml" }
    PaginaApp { nome: "vicina"; source: "Vicina.qml" }

    // Sotto le tendine: lo sfondo «sfocato» (le sue sfumature) con una velatura, che copre la Home
    Rectangle {
        anchors.fill: parent
        opacity: (tel.notifiche || tel.controllo || tel.personalizza) ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: tel.tNormale; easing.type: Easing.OutCubic } }
        gradient: Gradient {
            GradientStop { position: 0.0; color: tel.coloreSfondo(0.0) }
            GradientStop { position: 0.25; color: tel.coloreSfondo(0.25) }
            GradientStop { position: 0.5; color: tel.coloreSfondo(0.5) }
            GradientStop { position: 0.75; color: tel.coloreSfondo(0.75) }
            GradientStop { position: 1.0; color: tel.coloreSfondo(1.0) }
        }
        Rectangle { anchors.fill: parent; color: tel.pal.velo }
        MouseArea { anchors.fill: parent; onClicked: tel.chiudiTutto() }
    }
    Notifiche {
        anchors.left: parent.left; anchors.right: parent.right
        height: parent.height
        property real apertura: tel.notifiche ? 1 : 0
        Behavior on apertura { Movimento { apre: tel.notifiche } }
        y: (apertura - 1) * 60
        opacity: apertura
        visible: apertura > 0.001
    }
    CentroControllo {
        anchors.left: parent.left; anchors.right: parent.right
        height: parent.height
        property real apertura: tel.controllo ? 1 : 0
        Behavior on apertura { Movimento { apre: tel.controllo } }
        y: (apertura - 1) * 60
        opacity: apertura
        visible: apertura > 0.001
    }
    Personalizza {
        anchors.left: parent.left; anchors.right: parent.right
        height: parent.height
        y: tel.personalizza ? 0 : tel.height
        visible: tel.personalizza || y < tel.height - 1
        Behavior on y { Movimento { apre: tel.personalizza } }
    }

    // ── Gesti dal bordo alto: sinistra = notifiche, destra = controllo ────
    Item {
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: 34
        z: 50
        visible: tel.schermata === "home" && !tel.notifiche && !tel.controllo && !tel.personalizza
        DragHandler {
            id: tendina
            target: null
            yAxis.enabled: true; xAxis.enabled: false
            property real ultimaY: 0
            property real inizioX: 0
            onTranslationChanged: if (active) ultimaY = translation.y
            onActiveChanged: {
                if (active) { ultimaY = 0; inizioX = centroid.pressPosition.x; return }
                if (ultimaY > 50) {
                    if (tel.perso) return          // telefono smarrito: niente Centro di controllo né notifiche
                    if (inizioX > parent.width * 0.6) tel.controllo = true
                    else tel.notifiche = true
                }
            }
        }
        TapHandler { onTapped: function (punto) { if (tel.perso) return; if (punto.position.x > parent.width * 0.6) tel.controllo = true; else tel.notifiche = true } }
    }

    BarraStato { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; z: 60 }

    // ── Banner: la notifica appena arrivata scende dall'alto (non sul blocco: lì c'è l'elenco) ──
    SchedaNotifica {
        id: schedaBanner
        z: 80
        x: 10
        width: tel.width - 20
        compatta: true
        pieno: true
        n: tel.banner || ({})
        y: tel.banner && tel.schermata !== "blocco" && !tel.notifiche ? 54 : -height - 20
        visible: y > -height - 20
        Behavior on y { Movimento { apre: tel.banner && tel.schermata !== "blocco" && !tel.notifiche } }
    }

    // ── Chiamata: sopra a tutto (anche al blocco), riducibile a pillola verde ──
    Chiamata {
        anchors.fill: parent
        z: 90
        info: tel.chiamataInfo
        visible: tel.chiamataInfo.attiva === true && (!tel.chiamataRidotta || tel.chiamataInfo.inArrivo === true)
    }

    // ── Navigazione: barretta dei gesti o tre tasti ───────────────────────
    Item {
        id: navigazione
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: tel.imp.navigazione === "tasti" ? 44 : 26
        z: 70
        visible: tel.schermata === "home"
        Rectangle {
            visible: tel.imp.navigazione !== "tasti"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 8
            width: 134; height: 5; radius: 3
            color: tel.pal.testo
        }
        DragHandler {
            target: null
            enabled: tel.imp.navigazione !== "tasti"
            xAxis.enabled: false
            property real ultimaY: 0
            onTranslationChanged: if (active) ultimaY = translation.y
            // su: Home; su lungo: le app aperte
            onActiveChanged: {
                if (active) { ultimaY = 0; return }
                if (ultimaY < -220 && compositore.item) { tel.chiudiTutto(); tel.appInterna = ""; compositore.item.vistaApp = true; return }
                if (ultimaY < -30) { tel.chiudiTutto(); tel.appInterna = ""; home.pagina = 0; if (compositore.item) compositore.item.nascondi() }
            }
        }
        Row {
            visible: tel.imp.navigazione === "tasti"
            anchors.centerIn: parent
            spacing: 80
            Repeater {
                model: [{ i: "go-previous-symbolic", f: function () { if (tel.notifiche || tel.controllo || tel.personalizza) tel.chiudiTutto(); else if (tel.appInterna) tel.appInterna = ""; else if (compositore.item && compositore.item.inPrimoPiano) compositore.item.nascondi(); else home.pagina = 0 } },
                        { i: "go-home-symbolic", f: function () { tel.chiudiTutto(); tel.appInterna = ""; home.pagina = 0; if (compositore.item) compositore.item.nascondi() } },
                        { i: "view-app-grid-symbolic", f: function () { tel.chiudiTutto(); if (compositore.item) compositore.item.vistaApp = !compositore.item.vistaApp; else home.pagina = 1 } }]
                Item {
                    required property var modelData
                    width: 40; height: 40
                    Icona { anchors.centerIn: parent; nome: parent.modelData.i; lato: 22 }
                    MouseArea { anchors.fill: parent; onClicked: parent.modelData.f() }
                }
            }
        }
    }

    // Le app prese con lo stesso Solid ID sul PC: si scaricano da sole un minuto dopo l'avvio
    Timer { interval: 60000; running: true; onTriggered: if (tel.imp.app_automatiche !== false) ponte.avvia("storeScaricaMie", [], "store-scarica-mie") }

    // ── Widget: galleria e scelta della città del meteo ─────────────────
    GalleriaWidget { id: galleriaWidget; z: 85 }
    Popup {
        id: sceltaCitta
        anchors.centerIn: parent
        width: parent.width - 40; modal: true; padding: 18
        background: Rectangle { radius: 20; color: tel.pal.superficie }
        onOpened: campoCitta.text = tel.imp.citta_meteo || ""
        Column {
            width: parent.width; spacing: 12
            Text { text: I18n.t("Città del meteo"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(17); font.weight: Font.Bold }
            Text { width: parent.width; wrapMode: Text.Wrap; text: I18n.t("Lascia vuoto per usare la posizione del telefono."); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13) }
            CampoTesto { id: campoCitta; width: parent.width; placeholderText: I18n.t("es. Napoli") }
            Row {
                spacing: 10; anchors.right: parent.right
                Pulsante { text: I18n.t("Annulla"); onClicked: sceltaCitta.close() }
                Pulsante { text: I18n.t("Fatto"); principale: true; onClicked: { tel.imposta("citta_meteo", campoCitta.text.trim()); sceltaCitta.close(); tel.imp = ponte.chiama0("impostazioni") } }
            }
        }
    }

    // ── Dov'è › Inizializza a distanza: avviso, poi si cancella tutto ─────
    Timer { id: fineInizializza; interval: 4000; onTriggered: ponte.chiama0("inizializza") }
    Rectangle {
        anchors.fill: parent; z: 200
        visible: tel.inizializzando
        color: "#000000"
        MouseArea { anchors.fill: parent }
        Column {
            anchors.centerIn: parent; spacing: 14; width: parent.width - 60
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Inizializzazione"); color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(22); font.weight: Font.Bold }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: I18n.t("Il proprietario ha chiesto di cancellare questo telefono da Dov'è. Tutti i dati vengono cancellati."); color: "#B3FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(14) }
        }
    }
    // ── Blocco di attivazione (telefono di un altro Solid ID, anche dopo un reset) ──
    Attivazione { anchors.fill: parent; z: 190; visible: tel.attivazione !== "" }

    // ── Tastiera sullo schermo ─────────────────────────────────────────
    Tastiera { id: tastiera; z: 95 }

    // ── Messaggio temporaneo ──────────────────────────────────────────────
    Rectangle {
        id: messaggio
        property alias testo: etichetta.text
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 120
        width: Math.min(parent.width - 40, etichetta.implicitWidth + 32)
        height: etichetta.implicitHeight + 20
        radius: 16
        color: tel.pal.pieno
        opacity: 0
        visible: opacity > 0
        z: 100
        Behavior on opacity { NumberAnimation { duration: tel.tNormale; easing.type: Easing.OutCubic } }
        Text { id: etichetta; anchors.centerIn: parent; width: Math.min(implicitWidth, tel.width - 72); wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; color: tel.pal.suPieno; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.Medium }
        Timer { id: nascondi; interval: 2600; onTriggered: messaggio.opacity = 0 }
    }
}
