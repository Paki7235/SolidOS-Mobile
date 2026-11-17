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

    // ── Tema: scuro/chiaro, grandezza del testo, colore d'accento ────────
    readonly property bool chiaro: imp.tema === "chiaro"
    readonly property real k: [0.9, 1.0, 1.15][imp.testo] || 1.0
    readonly property color accento: imp.accento
    // Colori del design (sistema «Modern Dark»: ardesia profonda, mai nero puro sugli OLED).
    // Contrasti verificati: testo ≥ 7:1, testo secondario ≥ 4,5:1 in entrambi i temi.
    readonly property QtObject pal: QtObject {
        readonly property color sfondo: tel.chiaro ? "#F8FAFC" : "#0F172A"        // fondo delle app
        readonly property color superficie: tel.chiaro ? "#FFFFFF" : "#1E293B"    // schede, righe
        readonly property color superficie2: tel.chiaro ? "#E9EDF1" : "#272F42"   // campi, pulsanti
        readonly property color bordo: tel.chiaro ? "#E2E8F0" : Qt.rgba(0.58, 0.64, 0.72, 0.16)
        readonly property color testo: tel.chiaro ? "#0F172A" : "#F8FAFC"
        readonly property color testo2: tel.chiaro ? "#64748B" : "#94A3B8"
        readonly property color testo3: tel.chiaro ? "#94A3B8" : "#64748B"
        // Pannelli sopra lo sfondo (blocco, Home, tendine)
        readonly property color vetro: tel.chiaro ? Qt.rgba(1, 1, 1, 0.80) : Qt.rgba(0.118, 0.161, 0.231, 0.78)
        readonly property color vetroBordo: tel.chiaro ? Qt.rgba(0.06, 0.09, 0.16, 0.07) : Qt.rgba(0.58, 0.64, 0.72, 0.16)
        readonly property color traccia: tel.chiaro ? Qt.rgba(0.06, 0.09, 0.16, 0.08) : Qt.rgba(0.58, 0.64, 0.72, 0.18)
        readonly property color velo: tel.chiaro ? Qt.rgba(0.95, 0.96, 0.98, 0.93) : Qt.rgba(0.04, 0.06, 0.12, 0.90)
        readonly property color tessera: tel.chiaro ? "#FFFFFF" : "#1E293B"
        readonly property color pieno: tel.chiaro ? "#0F172A" : "#F8FAFC"
        readonly property color suPieno: tel.chiaro ? "#FFFFFF" : "#0F172A"
        readonly property color successo: "#22C55E"
        readonly property color pericolo: "#EF4444"
    }
    // Movimento (regole: entrata «expo» ~380 ms, uscita più rapida ~240 ms, pressione al 97%,
    // 150–300 ms per i piccoli effetti). Con «Riduci animazioni» tutto diventa istantaneo.
    readonly property bool movimento: imp.riduci_movimento !== true
    function durata(ms) { return movimento ? ms : 0 }
    readonly property int tVeloce: durata(150)
    readonly property int tNormale: durata(240)
    readonly property int tEntrata: durata(380)
    // Misure del design: raggi e margini uguali ovunque
    readonly property int r1: 12      // controlli piccoli
    readonly property int r2: 18      // schede
    readonly property int r3: 24      // pannelli grandi
    readonly property int margine: 18 // bordo dello schermo
    function px(n) { return Math.round(n * k) }
    readonly property string fontOra: imp.orologio || Tema.font
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
            else if (id === "blocco-remoto") {
                if (r.blocca) { tel.messaggioRemoto = r.messaggio; tel.chiudiTutto(); tel.appInterna = ""; tel.schermata = "blocco" }
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
        var r = ponte.chiama("avvia", [app.id])
        if (r.interna) { chiudiTutto(); appInterna = r.interna }
        else if (!r.ok) avviso(r.messaggio)
    }
    // Passaggi tra app: file da mandare con Vicina, brano da suonare, testo negli appunti
    property var daCondividere: []
    property string branoDaSuonare: ""
    function condividi(percorsi) { daCondividere = percorsi; chiudiTutto(); appInterna = "vicina" }
    function copia(testo) { appunti.text = testo; appunti.selectAll(); appunti.copy() }
    function ricaricaApp() { home.app = ponte.chiama0("home"); home.dock = ponte.chiama0("dock") }
    TextEdit { id: appunti; visible: false }
    function avviso(testo) { messaggio.testo = testo; messaggio.opacity = 1; nascondi.restart() }
    function chiudiTutto() { notifiche = false; controllo = false; personalizza = false }
    Component.onCompleted: {
        var a = ponte.chiama0("avvio")
        if (a.tema) imp = Object.assign({}, imp, { tema: a.tema })
        if (!a.schermata || a.schermata === "blocco") return
        if (a.schermata === "bloccato") { messaggioRemoto = I18n.t("Se lo trovi chiama il 333 123 4567. Grazie!"); return }
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
        else if (a.schermata === "condividi") condividi(ponte.chiama0("foto").slice(0, 2).map(function (f) { return f.percorso }))
        else if (a.schermata === "impostazioni") appInterna = "impostazioni"
        else if (["wifi", "bluetooth", "rete", "suoni", "schermo", "batteria", "info", "solidid", "sicurezza"].indexOf(a.schermata) >= 0) { appInterna = "impostazioni"; impostazioniApp.apri(a.schermata) }
        else if (a.schermata === "scheda") { appInterna = "contatti"; var cs = ponte.chiama0("contatti"); if (cs.length) contattiApp.apri(cs[1] || cs[0]) }
        else if (a.schermata === "banner") { schermata = "home"; var nn = ponte.chiama0("notifiche"); if (nn.length) banner = nn[0] }
        else if (a.schermata === "chiamata") { var cc = ponte.chiama0("contatti"); if (cc.length) chiama(cc[0].numero) }
    }
    // --foto=PERCORSO: salva una foto della schermata ed esce (prova automatica)
    Timer {
        interval: 2500
        running: ponte.chiama0("avvio").foto !== undefined
        onTriggered: tel.contentItem.grabToImage(function (r) { r.saveToFile(ponte.chiama0("avvio").foto); Qt.quit() })
    }

    // ── Sfondo: disegnato dal sistema (niente file), oppure una foto scelta in Foto ──
    Sfondo {
        anchors.fill: parent
        nome: tel.imp.sfondo
        chiaro: tel.chiaro
    }

    // ── Schermate ─────────────────────────────────────────────────────────
    Home {
        id: home
        anchors.fill: parent
        visible: tel.schermata === "home"
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
        height: parent.height
        y: tel.appInterna === "telefono" ? 0 : tel.height
        visible: tel.appInterna === "telefono" || y < tel.height - 1
        Behavior on y { Movimento { apre: tel.appInterna === "telefono" } }
    }
    Dove {
        id: doveApp
        anchors.left: parent.left; anchors.right: parent.right
        height: parent.height
        y: tel.appInterna === "dove" ? 0 : tel.height
        visible: tel.appInterna === "dove" || y < tel.height - 1
        Behavior on y { Movimento { apre: tel.appInterna === "dove" } }
    }
    Impostazioni {
        id: impostazioniApp
        anchors.left: parent.left; anchors.right: parent.right
        height: parent.height
        y: tel.appInterna === "impostazioni" ? 0 : tel.height
        visible: tel.appInterna === "impostazioni" || y < tel.height - 1
        Behavior on y { Movimento { apre: tel.appInterna === "impostazioni" } }
    }
    Contatti {
        id: contattiApp
        anchors.left: parent.left; anchors.right: parent.right
        height: parent.height
        y: tel.appInterna === "contatti" ? 0 : tel.height
        visible: tel.appInterna === "contatti" || y < tel.height - 1
        Behavior on y { Movimento { apre: tel.appInterna === "contatti" } }
    }
    Messaggi {
        id: messaggiApp
        anchors.left: parent.left; anchors.right: parent.right
        height: parent.height
        y: tel.appInterna === "messaggi" ? 0 : tel.height
        visible: tel.appInterna === "messaggi" || y < tel.height - 1
        Behavior on y { Movimento { apre: tel.appInterna === "messaggi" } }
    }

    // ── App di base: caricate solo quando servono (meno memoria) ─────────
    component PaginaApp: Loader {
        property string nome: ""
        property bool resta: false          // Musica: continua a suonare quando la chiudi
        property bool usata: false
        anchors.left: parent.left; anchors.right: parent.right
        height: parent.height
        y: tel.appInterna === nome ? 0 : tel.height
        visible: tel.appInterna === nome || y < tel.height - 1
        active: tel.appInterna === nome || visible || (resta && usata)
        onActiveChanged: if (active) usata = true
        asynchronous: false
        Behavior on y { Movimento { apre: tel.appInterna === nome } }
    }
    PaginaApp { nome: "calcolatrice"; source: "Calcolatrice.qml" }
    PaginaApp { nome: "note"; source: "Note.qml" }
    PaginaApp { nome: "file"; source: "FileApp.qml" }
    PaginaApp { nome: "foto"; source: "Foto.qml" }
    PaginaApp { nome: "musica"; source: "Musica.qml"; resta: true }
    PaginaApp { nome: "fotocamera"; source: "Fotocamera.qml" }
    PaginaApp { nome: "store"; source: "Store.qml" }
    PaginaApp { nome: "vicina"; source: "Vicina.qml" }

    // Velo scuro sotto le tendine
    Rectangle {
        anchors.fill: parent
        color: tel.pal.velo
        opacity: (tel.notifiche || tel.controllo || tel.personalizza) ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: tel.tNormale; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: tel.chiudiTutto() }
    }
    Notifiche {
        anchors.left: parent.left; anchors.right: parent.right
        height: parent.height
        y: tel.notifiche ? 0 : -tel.height
        visible: tel.notifiche || y > -tel.height + 1
        Behavior on y { Movimento { apre: tel.notifiche } }
    }
    CentroControllo {
        anchors.left: parent.left; anchors.right: parent.right
        height: parent.height
        y: tel.controllo ? 0 : -tel.height
        visible: tel.controllo || y > -tel.height + 1
        Behavior on y { Movimento { apre: tel.controllo } }
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
                    if (inizioX > parent.width * 0.6) tel.controllo = true
                    else tel.notifiche = true
                }
            }
        }
        TapHandler { onTapped: function (punto) { if (punto.position.x > parent.width * 0.6) tel.controllo = true; else tel.notifiche = true } }
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
            onActiveChanged: if (active) ultimaY = 0; else if (ultimaY < -30) { tel.chiudiTutto(); tel.appInterna = ""; home.pagina = 0 }
        }
        Row {
            visible: tel.imp.navigazione === "tasti"
            anchors.centerIn: parent
            spacing: 80
            Repeater {
                model: [{ i: "go-previous-symbolic", f: function () { if (tel.notifiche || tel.controllo || tel.personalizza) tel.chiudiTutto(); else if (tel.appInterna) tel.appInterna = ""; else home.pagina = 0 } },
                        { i: "go-home-symbolic", f: function () { tel.chiudiTutto(); tel.appInterna = ""; home.pagina = 0 } },
                        { i: "view-app-grid-symbolic", f: function () { tel.chiudiTutto(); home.pagina = 1 } }]
                Item {
                    required property var modelData
                    width: 40; height: 40
                    Icona { anchors.centerIn: parent; nome: parent.modelData.i; lato: 22 }
                    MouseArea { anchors.fill: parent; onClicked: parent.modelData.f() }
                }
            }
        }
    }

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
