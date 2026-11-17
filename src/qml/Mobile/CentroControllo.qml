// Centro di controllo (dall'angolo in alto a destra): l'ordine del centro di controllo dell'iPhone, con un carattere
// tutto suo. In cima ora, data e un anello con la batteria. Ogni tasto acceso si colora
// della sua tinta (non diventa bianco), i cursori si riempiono del colore di accento con la
// percentuale scritta dentro, il lettore prende i colori della copertina. In più i
// «Momenti»: un tocco e il telefono si prepara per la notte, il lavoro o per durare di più.
import QtQuick
import SolidUI

Item {
    id: cc
    property int luce: 70
    property int audio: 50
    onVisibleChanged: if (visible) { luce = ponte.chiama0("luminosita"); audio = ponte.chiama0("volume") }
    readonly property var st: tel.stato || ({})
    readonly property bool wifiAcceso: st.rete ? st.rete.wifi : false
    readonly property int batteria: st.batteria ? st.batteria.livello : 100
    readonly property real spazio: 14
    readonly property real cima: 136
    readonly property real altoMomenti: 48
    readonly property real u: Math.floor((width - 40 - 3 * spazio) / 4)
    readonly property real alto: Math.min(u, Math.floor((height - cima - 40 - altoMomenti - 5 * spazio) / 5))
    function px(c) { return 20 + c * (u + spazio) }
    function py(r) { return cima + r * (alto + spazio) }
    function largo(n) { return n * u + (n - 1) * spazio }
    function altoN(n) { return n * alto + (n - 1) * spazio }
    function tinta(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    // Tinta piena (non trasparente): così sotto non si vede la Home
    function acceso(c) {
        c = Qt.lighter(c, 1.0)   // accetta anche i colori scritti come testo
        var b = tel.pal.superficie, a = tel.chiaro ? 0.14 : 0.26
        return Qt.rgba(b.r + (c.r - b.r) * a, b.g + (c.g - b.g) * a, b.b + (c.b - b.b) * a, 1)
    }

    MouseArea { anchors.fill: parent; onClicked: tel.controllo = false }

    // Tasto tondo 1×1: acceso prende la sua tinta, con l'alone
    component Tondo: Item {
        id: td
        property string icona: ""
        property bool acceso: false
        property color colore: tel.accento
        signal tocco()
        width: cc.u; height: cc.alto
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height); height: width; radius: width / 2
            color: td.acceso ? cc.acceso(td.colore) : tel.pal.vetro
            border.width: td.acceso ? 1.5 : 1
            border.color: td.acceso ? td.colore : tel.pal.vetroBordo
            scale: toccoTd.pressed ? 0.92 : 1
            Behavior on scale { NumberAnimation { duration: tel.tVeloce } }
            Behavior on color { ColorAnimation { duration: tel.tVeloce } }
            Rectangle {   // pallino di stato
                visible: td.acceso
                anchors.horizontalCenter: parent.horizontalCenter; y: parent.height - 14
                width: 5; height: 5; radius: 2.5; color: td.colore
            }
            Icona { anchors.centerIn: parent; nome: td.icona; lato: 24 }
        }
        MouseArea { id: toccoTd; anchors.fill: parent; onClicked: td.tocco() }
    }
    // Tondo colorato del blocco connessioni, con l'alone quando è acceso
    component Connessione: Item {
        id: cn
        property string icona: ""
        property string nome: ""
        property bool acceso: false
        property color colore: tel.accento
        signal tocco()
        width: 64; height: 64
        Rectangle {
            visible: cn.acceso
            anchors.centerIn: tondo; width: 70; height: 70; radius: 35
            color: cc.tinta(cn.colore, 0.22)
        }
        Rectangle {
            id: tondo
            anchors.centerIn: parent
            width: 56; height: 56; radius: 28
            color: cn.acceso ? cn.colore : tel.pal.traccia
            scale: toccoCn.pressed ? 0.9 : 1
            Behavior on scale { NumberAnimation { duration: tel.tVeloce } }
            Icona { anchors.centerIn: parent; nome: cn.icona; lato: 24; tema: cn.acceso ? "scuro" : "" }
        }
        MouseArea { id: toccoCn; anchors.fill: parent; onClicked: cn.tocco() }
    }
    // Cursore verticale 1×2 nel colore di accento, con la percentuale dentro
    component Cursore: Vetro {
        id: cur
        property string icona: ""
        property int valore: 50
        signal cambia(int v)
        width: cc.u; height: cc.altoN(2); radius: 30; clip: true
        Rectangle {
            id: pieno
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            height: parent.height * cur.valore / 100; radius: cur.radius; color: tel.accento
        }
        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.bottomMargin: cur.radius
            height: Math.max(0, pieno.height - cur.radius); color: tel.accento
        }
        Text {
            visible: pieno.height > 80
            anchors.horizontalCenter: parent.horizontalCenter
            y: cur.height - pieno.height + 12
            text: cur.valore + "%"; color: "#ffffff"
            font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.Bold
        }
        Icona { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 18
                nome: cur.icona; lato: 24; tema: cur.valore > 15 ? "scuro" : "" }
        MouseArea {
            anchors.fill: parent
            function muovi(y) { cur.cambia(Math.max(5, Math.min(100, Math.round((1 - y / height) * 100)))) }
            onPressed: function (e) { muovi(e.y) }
            onPositionChanged: function (e) { muovi(e.y) }
        }
    }

    // ── In cima: ora, data, anello della batteria, Impostazioni ───────────
    Column {
        x: 22; y: 50
        Text { text: tel.ora(); color: tel.pal.testo; font.family: tel.fontOra; font.pixelSize: 44; font.weight: Font.Bold; font.letterSpacing: -1 }
        Text { text: tel.giorno(); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13); font.capitalization: Font.Capitalize }
    }
    Row {
        anchors.right: parent.right; anchors.rightMargin: 20; y: 60
        spacing: 10
        Item {
            width: 52; height: 52
            Canvas {
                id: anello
                anchors.fill: parent
                property int livello: cc.batteria
                property color colore: cc.batteria <= 20 ? tel.pal.pericolo : tel.pal.successo
                property color fondo: tel.pal.traccia
                onLivelloChanged: requestPaint()
                onColoreChanged: requestPaint()
                onPaint: {
                    var c = getContext("2d"); c.reset(); c.lineWidth = 5; c.lineCap = "round"
                    c.strokeStyle = fondo; c.beginPath(); c.arc(26, 26, 22, 0, 2 * Math.PI); c.stroke()
                    c.strokeStyle = colore; c.beginPath()
                    c.arc(26, 26, 22, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * livello / 100); c.stroke()
                }
            }
            Text { anchors.centerIn: parent; text: cc.batteria; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.Bold }
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 44; height: 44; radius: 22; color: tel.pal.vetro; border.color: tel.pal.vetroBordo
            Icona { anchors.centerIn: parent; nome: "preferences-system-symbolic"; lato: 20 }
            MouseArea { anchors.fill: parent; onClicked: { tel.controllo = false; tel.apri({ "id": "interno:impostazioni" }) } }
        }
    }

    // ── Righe 0–1: connessioni e lettore ─────────────────────────────────
    Vetro {
        x: cc.px(0); y: cc.py(0); width: cc.largo(2); height: cc.altoN(2); radius: 34
        Grid {
            anchors.centerIn: parent
            columns: 2
            columnSpacing: (parent.width - 2 * 64) / 3; rowSpacing: (parent.height - 2 * 64) / 3
            Connessione { icona: "airplane-mode-symbolic"; colore: "#F59E0B"
                          onTocco: tel.avviso(I18n.t("Modalità aereo: arriva con il telefono vero")) }
            Connessione { icona: "network-cellular-symbolic"; colore: tel.pal.successo; acceso: tel.imp.dati_mobili === true
                          onTocco: { ponte.avvia("datiMobili", [!tel.imp.dati_mobili], "dati"); tel.imposta("dati_mobili", !tel.imp.dati_mobili) } }
            Connessione { icona: "network-wireless-symbolic"; colore: tel.accento; acceso: cc.wifiAcceso
                          onTocco: { ponte.chiama("wifi", [!cc.wifiAcceso]); ponte.avvia("stato", [], "stato") } }
            Connessione { icona: "bluetooth-active-symbolic"; colore: tel.accento; acceso: cc.st.bluetooth === true
                          onTocco: { ponte.chiama("bluetooth", [!cc.st.bluetooth]); ponte.avvia("stato", [], "stato") } }
        }
    }
    Vetro {
        id: lettore
        x: cc.px(2); y: cc.py(0); width: cc.largo(2); height: cc.altoN(2); radius: 34
        clip: true
        // I colori della copertina sfumano nel riquadro
        Rectangle {
            anchors.fill: parent; radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 0.4, 0.5, tel.chiaro ? 0.18 : 0.28) }
                GradientStop { position: 1; color: Qt.rgba(0.49, 0.23, 0.93, tel.chiaro ? 0.10 : 0.16) }
            }
        }
        Rectangle {
            x: 16; y: 16; width: 52; height: 52; radius: 14
            gradient: Gradient { GradientStop { position: 0; color: "#FF6680" } GradientStop { position: 1; color: "#7C3AED" } }
            Text { anchors.centerIn: parent; text: "♪"; color: "#ffffff"; font.pixelSize: 24 }
        }
        Column {
            x: 16; y: 78; width: parent.width - 32
            Text { width: parent.width; elide: Text.ElideRight; text: I18n.t("Nessun brano"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.DemiBold }
            Text { text: I18n.t("Musica"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }
        }
        Row {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 16; anchors.horizontalCenter: parent.horizontalCenter
            spacing: 24
            Repeater { model: ["⏮", "▶", "⏭"]; Text { required property string modelData; text: modelData; color: tel.pal.testo; font.pixelSize: 22 } }
        }
        MouseArea { anchors.fill: parent; z: -1; onClicked: { tel.controllo = false; tel.apri({ "id": "interno:musica" }) } }
    }

    // ── Righe 2–3: tasti, «Non disturbare» e cursori ─────────────────────
    Tondo { x: cc.px(0); y: cc.py(2); icona: "audio-volume-muted-symbolic"; colore: "#EF4444"; acceso: tel.imp.silenzioso === true
            onTocco: tel.imposta("silenzioso", !tel.imp.silenzioso) }
    Tondo { x: cc.px(1); y: cc.py(2); icona: "battery-good-symbolic"; colore: "#F59E0B"; acceso: tel.imp.risparmio === true
            onTocco: tel.imposta("risparmio", !tel.imp.risparmio) }
    Rectangle {
        id: nd
        readonly property bool acceso: tel.imp.non_disturbare === true
        readonly property color colore: "#6366F1"
        x: cc.px(0); y: cc.py(3); width: cc.largo(2); height: cc.alto; radius: height / 2
        color: acceso ? cc.acceso(colore) : tel.pal.vetro
        border.width: acceso ? 1.5 : 1
        border.color: acceso ? colore : tel.pal.vetroBordo
        scale: toccoNd.pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: tel.tVeloce } }
        Behavior on color { ColorAnimation { duration: tel.tVeloce } }
        Rectangle {
            id: luna
            x: 12; anchors.verticalCenter: parent.verticalCenter
            width: nd.height - 30; height: width; radius: width / 2
            color: nd.acceso ? nd.colore : tel.pal.traccia
            Icona { anchors.centerIn: parent; nome: "weather-clear-night-symbolic"; lato: 22; tema: nd.acceso ? "scuro" : "" }
        }
        Column {
            x: luna.x + luna.width + 10; anchors.verticalCenter: parent.verticalCenter
            width: nd.width - x - 14
            Text { width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 2; text: I18n.t("Non disturbare"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.DemiBold }
        }
        MouseArea { id: toccoNd; anchors.fill: parent; onClicked: tel.nonDisturbare(!tel.imp.non_disturbare) }
    }
    Cursore { x: cc.px(2); y: cc.py(2); icona: "display-brightness-symbolic"; valore: cc.luce
              onCambia: function (v) { cc.luce = v; ponte.chiama("impostaLuminosita", [v]) } }
    Cursore { x: cc.px(3); y: cc.py(2); icona: "audio-volume-high-symbolic"; valore: cc.audio
              onCambia: function (v) { cc.audio = v; ponte.chiama("impostaVolume", [v]) } }

    // ── Momenti: un tocco prepara il telefono ────────────────────────────
    Row {
        id: momenti
        x: 20; y: cc.py(4)
        spacing: 10
        readonly property real largo: (cc.width - 40 - 2 * spacing) / 3
        Repeater {
            model: [
                { i: "weather-clear-night-symbolic", t: I18n.t("Notte"), c: "#6366F1",
                  on: tel.imp.non_disturbare === true && tel.imp.silenzioso !== true,
                  f: function (si) { tel.nonDisturbare(si); if (si) { cc.luce = 25; ponte.chiama("impostaLuminosita", [25]) } } },
                { i: "user-busy-symbolic", t: I18n.t("Lavoro"), c: "#EF4444",
                  on: tel.imp.non_disturbare === true && tel.imp.silenzioso === true,
                  f: function (si) { tel.nonDisturbare(si); tel.imposta("silenzioso", si) } },
                { i: "battery-good-symbolic", t: I18n.t("Durata"), c: "#F59E0B",
                  on: tel.imp.risparmio === true,
                  f: function (si) { tel.imposta("risparmio", si); if (si) { cc.luce = 40; ponte.chiama("impostaLuminosita", [40]) } } }
            ]
            Rectangle {
                id: mo
                required property var modelData
                width: momenti.largo; height: cc.altoMomenti; radius: height / 2
                color: modelData.on ? cc.acceso(modelData.c) : tel.pal.vetro
                border.width: modelData.on ? 1.5 : 1
                border.color: modelData.on ? modelData.c : tel.pal.vetroBordo
                scale: toccoMo.pressed ? 0.95 : 1
                Behavior on scale { NumberAnimation { duration: tel.tVeloce } }
                Row {
                    anchors.centerIn: parent; spacing: 8
                    Icona { anchors.verticalCenter: parent.verticalCenter; nome: mo.modelData.i; lato: 18 }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: mo.modelData.t; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                }
                MouseArea { id: toccoMo; anchors.fill: parent; onClicked: mo.modelData.f(!mo.modelData.on) }
            }
        }
    }

    // ── Scorciatoie ──────────────────────────────────────────────────────
    Repeater {
        model: [{ i: "preferences-desktop-wallpaper-symbolic", f: function () { tel.controllo = false; tel.personalizza = true } },
                { i: "accessories-calculator-symbolic", f: function () { tel.controllo = false; tel.apri({ "id": "interno:calcolatrice" }) } },
                { i: "camera-photo-symbolic", f: function () { tel.controllo = false; tel.apri({ "id": "interno:fotocamera" }) } },
                { i: "system-lock-screen-symbolic", f: function () { tel.controllo = false; tel.schermata = "blocco" } }]
        Tondo { required property var modelData; required property int index
                x: cc.px(index); y: cc.py(4) + cc.altoMomenti + cc.spazio; icona: modelData.i; onTocco: modelData.f() }
    }
}
