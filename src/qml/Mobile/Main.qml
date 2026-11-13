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
    width: 390
    height: 844
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
    readonly property QtObject pal: QtObject {
        readonly property color testo: tel.chiaro ? "#0f1630" : "#ffffff"
        readonly property color testo2: tel.chiaro ? Qt.rgba(0.06, 0.09, 0.19, 0.66) : Qt.rgba(1, 1, 1, 0.78)
        readonly property color vetro: tel.chiaro ? Qt.rgba(1, 1, 1, 0.62) : Qt.rgba(1, 1, 1, 0.14)
        readonly property color vetroBordo: tel.chiaro ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(1, 1, 1, 0.16)
        readonly property color traccia: tel.chiaro ? Qt.rgba(0.06, 0.09, 0.19, 0.12) : Qt.rgba(1, 1, 1, 0.22)
        readonly property color velo: tel.chiaro ? Qt.rgba(0.93, 0.94, 0.98, 0.72) : Qt.rgba(0.02, 0.03, 0.08, 0.62)
        readonly property color pieno: tel.chiaro ? "#0f1630" : "#ffffff"
        readonly property color suPieno: tel.chiaro ? "#ffffff" : "#1b2140"
    }
    function px(n) { return Math.round(n * k) }
    readonly property string fontOra: imp.orologio || Tema.font
    readonly property int latoIcona: [52, 60, 68][imp.icone === undefined ? 1 : imp.icone]

    // ── Stato del telefono ────────────────────────────────────────────────
    property string schermata: "blocco"          // blocco | home
    property bool notifiche: false
    property bool controllo: false
    property bool personalizza: false
    property var stato: ponte.chiama0("stato")
    property date adesso: new Date()
    Timer { interval: 15000; running: true; repeat: true; onTriggered: { tel.adesso = new Date(); ponte.avvia("stato", [], "stato") } }
    Connections {
        target: ponte
        function onCompletato(id, r) { if (id === "stato") tel.stato = r }
    }
    function ora() { return Qt.formatTime(adesso, "H:mm") }
    function giorno() {
        var g = adesso.toLocaleDateString(Qt.locale("it_IT"), "dddd d MMMM")
        return g
    }
    function apri(app) {
        var r = ponte.chiama("avvia", [app.id])
        if (!r.ok) avviso(r.messaggio)
    }
    function avviso(testo) { messaggio.testo = testo; messaggio.opacity = 1; nascondi.restart() }
    function chiudiTutto() { notifiche = false; controllo = false; personalizza = false }
    Component.onCompleted: {
        var a = ponte.chiama0("avvio")
        if (a.tema) imp = Object.assign({}, imp, { tema: a.tema })
        if (!a.schermata || a.schermata === "blocco") return
        schermata = "home"
        if (a.schermata === "libreria") home.pagina = 1
        else if (a.schermata === "controllo") controllo = true
        else if (a.schermata === "notifiche") notifiche = true
        else if (a.schermata === "personalizza") personalizza = true
    }
    // --foto=PERCORSO: salva una foto della schermata ed esce (prova automatica)
    Timer {
        interval: 2500
        running: ponte.chiama0("avvio").foto !== undefined
        onTriggered: tel.contentItem.grabToImage(function (r) { r.saveToFile(ponte.chiama0("avvio").foto); Qt.quit() })
    }

    // ── Sfondo: gli stessi sfondi di SolidOS per PC (variante chiara col tema chiaro) ──
    // Riserva se l'immagine manca: gli stessi colori dello sfondo «Notte»
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: tel.chiaro ? "#eef1ff" : "#0b1230" }
            GradientStop { position: 0.6; color: tel.chiaro ? "#c9d4ff" : "#2a3d9e" }
            GradientStop { position: 1.0; color: tel.chiaro ? "#e5d6ff" : "#5b34b0" }
        }
    }
    readonly property string sfondi: ponte.chiama0("cartellaSfondi")
    Image {
        anchors.fill: parent
        source: "file://" + tel.sfondi + "/" + tel.imp.sfondo + (tel.chiaro ? "-chiaro" : "") + ".png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.height: 1080
    }

    // ── Schermate ─────────────────────────────────────────────────────────
    Home {
        id: home
        anchors.fill: parent
        visible: tel.schermata === "home"
    }
    Blocco {
        anchors.fill: parent
        visible: tel.schermata === "blocco"
        onSblocca: tel.schermata = "home"
    }

    // Velo scuro sotto le tendine
    Rectangle {
        anchors.fill: parent
        color: tel.pal.velo
        opacity: (tel.notifiche || tel.controllo || tel.personalizza) ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        MouseArea { anchors.fill: parent; onClicked: tel.chiudiTutto() }
    }
    Notifiche {
        anchors.fill: parent
        y: tel.notifiche ? 0 : -tel.height
        visible: tel.notifiche || y > -tel.height
        Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    }
    CentroControllo {
        anchors.left: parent.left; anchors.right: parent.right
        height: parent.height
        y: tel.controllo ? 0 : -tel.height
        visible: tel.controllo || y > -tel.height
        Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    }
    Personalizza {
        anchors.left: parent.left; anchors.right: parent.right
        height: parent.height
        y: tel.personalizza ? 0 : tel.height
        visible: tel.personalizza || y < tel.height
        Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
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
            onActiveChanged: if (!active && translation.y > 50) {
                if (centroid.pressPosition.x > parent.width * 0.6) tel.controllo = true
                else tel.notifiche = true
            }
        }
        TapHandler { onTapped: function (punto) { if (punto.position.x > parent.width * 0.6) tel.controllo = true; else tel.notifiche = true } }
    }

    BarraStato { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; z: 60 }

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
            onActiveChanged: if (!active && translation.y < -30) { tel.chiudiTutto(); home.pagina = 0 }
        }
        Row {
            visible: tel.imp.navigazione === "tasti"
            anchors.centerIn: parent
            spacing: 80
            Repeater {
                model: [{ i: "go-previous-symbolic", f: function () { if (tel.notifiche || tel.controllo || tel.personalizza) tel.chiudiTutto(); else home.pagina = 0 } },
                        { i: "go-home-symbolic", f: function () { tel.chiudiTutto(); home.pagina = 0 } },
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
        color: tel.chiaro ? "#0f1630" : "#f2f4f8"
        opacity: 0
        visible: opacity > 0
        z: 100
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Text { id: etichetta; anchors.centerIn: parent; width: Math.min(implicitWidth, tel.width - 72); wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; color: tel.chiaro ? "#ffffff" : "#0f1630"; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.Medium }
        Timer { id: nascondi; interval: 2600; onTriggered: messaggio.opacity = 0 }
    }
}
