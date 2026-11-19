// SolidOS fa da «compositore» (come iOS e Android): le app installate dallo Store si aprono
// dentro lo schermo del telefono, sotto la barra in alto e sopra la barretta per tornare alla
// Home; si passa da un'app all'altra con la vista delle app aperte.
// Le app parlano Wayland con il socket «solidos-0» (WAYLAND_DISPLAY), che il nucleo passa a
// ogni app che avvia. Se questo modulo non si carica (Qt senza QtWayland Compositor),
// le app si aprono come prima, a schermo intero sopra l'interfaccia.
import QtQuick
import QtWayland.Compositor
import QtWayland.Compositor.XdgShell
import QtWayland.Compositor.WlShell

Item {
    id: comp
    readonly property string socket: "solidos-0"
    property int attiva: -1                    // app esterna in primo piano (-1 = nessuna)
    property bool vistaApp: false              // vista delle app aperte
    readonly property bool inPrimoPiano: attiva >= 0 && attiva < finestre.length
    readonly property int alto: 44             // barra di stato
    readonly property int basso: 26            // barretta della Home
    readonly property real scala: Math.max(1, Math.ceil(Number(ponte.chiama0("scalaSchermo")) || 1))
    property var finestre: []                  // [{superficie, toplevel, nome, appId}]
    function aggiungi(f) { finestre = finestre.concat([f]); mostra(finestre.length - 1) }
    function togli(superficie) {
        var i = finestre.findIndex(function (f) { return f.superficie === superficie })
        if (i < 0) return
        var l = finestre.slice(); l.splice(i, 1); finestre = l
        if (attiva === i) attiva = -1
        else if (attiva > i) attiva -= 1
    }
    function aggiornaNome(toplevel) {
        var l = finestre.slice()
        for (var k = 0; k < l.length; k++) if (l[k].toplevel === toplevel) l[k] = Object.assign({}, l[k], { nome: toplevel.title, appId: toplevel.appId })
        finestre = l
    }

    function mostra(i) {
        if (i < 0 || i >= finestre.length) return
        attiva = i; vistaApp = false
        tel.appInterna = ""; tel.chiudiTutto()
        var t = finestre[i].toplevel
        if (t) t.sendMaximized(Qt.size(comp.width, comp.height - alto - basso))
    }
    function attivaApp(appId) {
        for (var i = 0; i < finestre.length; i++) {
            var a = finestre[i].appId || ""
            if (a && (a === appId || appId.indexOf(a) >= 0 || a.indexOf(appId) >= 0)) { mostra(i); return true }
        }
        return false
    }
    function chiudi(i) {
        var f = finestre[i]
        if (f && f.toplevel) f.toplevel.sendClose()
        else if (f && f.superficie && f.superficie.surface) f.superficie.surface.destroy()
    }
    function nascondi() { attiva = -1; vistaApp = false }

    WaylandCompositor {
        id: server
        socketName: comp.socket
        WaylandOutput {
            id: uscita
            window: tel
            sizeFollowsWindow: true
            scaleFactor: comp.scala
        }
        XdgShell {
            onToplevelCreated: function (toplevel, xdgSurface) {
                toplevel.titleChanged.connect(function () { comp.aggiornaNome(toplevel) })
                toplevel.appIdChanged.connect(function () { comp.aggiornaNome(toplevel) })
                comp.aggiungi({ superficie: xdgSurface, toplevel: toplevel, nome: toplevel.title || "", appId: toplevel.appId || "" })
            }
        }
        WlShell {
            onWlShellSurfaceCreated: function (superficie) {
                comp.aggiungi({ superficie: superficie, toplevel: null, nome: superficie.title || "", appId: superficie.className || "" })
            }
        }
        XdgDecorationManagerV1 { preferredMode: XdgToplevel.ClientSideDecoration }
        Component.onCompleted: ponte.chiama("compositorePronto", [comp.socket])
    }

    // ── Le app aperte: quella in primo piano riempie lo schermo ─────────────
    Rectangle {
        anchors.fill: parent
        visible: comp.inPrimoPiano && !comp.vistaApp
        color: tel.pal.sfondo
    }
    Repeater {
        model: comp.finestre
        ShellSurfaceItem {
            id: superficie
            required property var modelData
            required property int index
            shellSurface: modelData.superficie
            autoCreatePopupItems: true
            // L'app prende la sua misura; se è più larga dello schermo (app pensate per il computer)
            // si rimpicciolisce finché entra
            readonly property real riduzione: Math.min(1, comp.width / Math.max(1, width), (comp.height - comp.alto - comp.basso) / Math.max(1, height))
            x: 0; y: comp.alto
            scale: riduzione
            transformOrigin: Item.TopLeft
            visible: comp.inPrimoPiano && comp.attiva === index && !comp.vistaApp
            onSurfaceDestroyed: comp.togli(modelData.superficie)
        }
    }

    // ── Vista delle app aperte (scorri su e fermati) ───────────────────────
    Rectangle {
        anchors.fill: parent
        visible: comp.vistaApp
        color: "#CC0B0E18"
        MouseArea { anchors.fill: parent; onClicked: comp.vistaApp = false }
        Text {
            visible: comp.finestre.length === 0
            anchors.centerIn: parent
            text: I18n.t("Nessuna app aperta"); color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(16)
        }
        ListView {
            id: schede
            anchors.fill: parent; anchors.topMargin: 110; anchors.bottomMargin: 90
            orientation: ListView.Horizontal
            spacing: 18
            leftMargin: (width - 220) / 2; rightMargin: leftMargin
            model: comp.finestre
            clip: false
            delegate: Item {
                id: scheda
                required property var modelData
                required property int index
                width: 220; height: schede.height
                property real spostamento: 0
                Text {
                    x: 6; y: -30 + scheda.spostamento
                    width: parent.width - 12; elide: Text.ElideRight
                    text: scheda.modelData.nome || scheda.modelData.appId || I18n.t("App")
                    color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.DemiBold
                }
                Rectangle {
                    id: cornice
                    y: scheda.spostamento
                    width: parent.width; height: parent.height - 20; radius: 26; clip: true
                    color: tel.pal.sfondo
                    opacity: 1 - Math.min(0.8, Math.abs(scheda.spostamento) / 400)
                    ShellSurfaceItem {
                        shellSurface: scheda.modelData.superficie
                        inputEventsEnabled: false
                        scale: Math.min(cornice.width / Math.max(1, width), cornice.height / Math.max(1, height))
                        transformOrigin: Item.TopLeft
                    }
                }
                // tocca: apri; spingi in alto: chiudi
                MouseArea {
                    anchors.fill: cornice
                    property real inizio: 0
                    onPressed: function (m) { inizio = m.y }
                    onPositionChanged: function (m) { scheda.spostamento = Math.min(0, m.y - inizio) }
                    onReleased: {
                        if (scheda.spostamento < -140) comp.chiudi(scheda.index)
                        else if (Math.abs(scheda.spostamento) < 8) comp.mostra(scheda.index)
                        scheda.spostamento = 0
                    }
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 50
            visible: comp.finestre.length > 0
            text: I18n.t("Tocca un'app per tornarci, spingila in alto per chiuderla")
            color: "#B3FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(13)
        }
    }
}
