// Centro di controllo (dall'angolo in alto a destra), stile «Vetro»: riquadri di vetro su una
// griglia di 4 colonne. Connessioni in tondi colorati, il brano in riproduzione, Non disturbare,
// Silenzioso e Risparmio, luminosità e volume verticali da trascinare, i «Momenti» (un tocco
// prepara il telefono per la notte, il lavoro o per durare di più) e le scorciatoie.
import QtQuick
import SolidUI

Item {
    id: cc
    property int luce: 70
    property int audio: 50
    onVisibleChanged: if (visible) { luce = ponte.chiama0("luminosita"); audio = ponte.chiama0("volume") }
    readonly property var st: tel.stato || ({})
    readonly property bool wifiAcceso: st.rete ? st.rete.wifi : false
    readonly property real spazio: 12
    readonly property real cima: 64
    readonly property real u: Math.floor((width - 36 - 3 * spazio) / 4)
    readonly property real alto: Math.min(u, Math.floor((height - cima - 40 - 5 * spazio) / 6))
    function px(c) { return 18 + c * (u + spazio) }
    function py(r) { return cima + r * (alto + spazio) }
    function largo(n) { return n * u + (n - 1) * spazio }
    function altoN(n) { return n * alto + (n - 1) * spazio }

    MouseArea { anchors.fill: parent; onClicked: tel.controllo = false }

    // Riquadro di vetro che si preme
    component Riquadro: Vetro {
        id: rq
        signal tocco()
        radius: 26
        scale: toccoRq.pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: tel.tVeloce; easing.type: Easing.OutQuad } }
        MouseArea { id: toccoRq; anchors.fill: parent; z: -1; onClicked: rq.tocco() }
    }
    // Tondo colorato quando è acceso
    component Tondo: Rectangle {
        id: td
        property string icona: ""
        property bool acceso: false
        property color colore: tel.accento
        property int lato: 54
        signal tocco()
        width: lato; height: lato; radius: lato / 2
        color: acceso ? colore : tel.pal.traccia
        scale: toccoTd.pressed ? 0.9 : 1
        Behavior on scale { NumberAnimation { duration: tel.tVeloce } }
        Behavior on color { ColorAnimation { duration: tel.tVeloce } }
        Icona { anchors.centerIn: parent; nome: td.icona; lato: Math.round(td.lato * 0.42); tema: td.acceso ? "scuro" : "" }
        MouseArea { id: toccoTd; anchors.fill: parent; anchors.margins: -4; onClicked: td.tocco() }
    }
    // Cursore verticale: si riempie dal basso
    component Cursore: Vetro {
        id: cur
        property string icona: ""
        property int valore: 50
        signal cambia(int v)
        radius: 26
        Rectangle {
            id: pieno
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            height: Math.max(cur.radius * 2, parent.height * cur.valore / 100); radius: cur.radius
            color: tel.chiaro ? tel.accento : "#F5F5F7"
        }
        Rectangle {   // bordo superiore dritto del riempimento
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.bottomMargin: cur.radius
            height: Math.max(0, pieno.height - cur.radius * 2); color: pieno.color
        }
        Icona { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 18
                nome: cur.icona; lato: 22; tema: tel.chiaro ? "scuro" : "chiaro" }
        MouseArea {
            anchors.fill: parent
            function muovi(y) { cur.cambia(Math.max(5, Math.min(100, Math.round((1 - y / height) * 100)))) }
            onPressed: function (e) { muovi(e.y) }
            onPositionChanged: function (e) { muovi(e.y) }
        }
    }

    // ── Righe 0–1: connessioni e musica ──────────────────────────────────
    Riquadro {
        x: cc.px(0); y: cc.py(0); width: cc.largo(2); height: cc.altoN(2); radius: 30
        Grid {
            anchors.centerIn: parent
            columns: 2
            columnSpacing: (parent.width - 2 * 54) / 3; rowSpacing: (parent.height - 2 * 54) / 3
            Tondo { icona: "airplane-mode-symbolic"; colore: "#F59E0B"; onTocco: tel.avviso(I18n.t("Modalità aereo: arriva con il telefono vero")) }
            Tondo { icona: "network-cellular-symbolic"; colore: tel.pal.successo; acceso: tel.imp.dati_mobili === true
                    onTocco: { ponte.avvia("datiMobili", [!tel.imp.dati_mobili], "dati"); tel.imposta("dati_mobili", !tel.imp.dati_mobili) } }
            Tondo { icona: "network-wireless-symbolic"; acceso: cc.wifiAcceso
                    onTocco: { ponte.chiama("wifi", [!cc.wifiAcceso]); ponte.avvia("stato", [], "stato") } }
            Tondo { icona: "bluetooth-active-symbolic"; acceso: cc.st.bluetooth === true
                    onTocco: { ponte.chiama("bluetooth", [!cc.st.bluetooth]); ponte.avvia("stato", [], "stato") } }
        }
    }
    Riquadro {
        x: cc.px(2); y: cc.py(0); width: cc.largo(2); height: cc.altoN(2); radius: 30
        onTocco: { tel.controllo = false; tel.apri({ "id": "interno:musica" }) }
        Rectangle {
            x: 16; y: 16; width: 50; height: 50; radius: 12
            gradient: Gradient { GradientStop { position: 0; color: "#4C7DFF" } GradientStop { position: 1; color: "#8B5CF6" } }
            Icona { anchors.centerIn: parent; nome: "linea-musica"; lato: 22; tema: "scuro" }
        }
        Column {
            x: 16; y: 76; width: parent.width - 32
            Text { width: parent.width; elide: Text.ElideRight; text: I18n.t("Nessun brano"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.DemiBold }
            Text { text: I18n.t("Musica"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }
        }
        Row {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 14; anchors.horizontalCenter: parent.horizontalCenter
            spacing: 26
            Icona { nome: "media-skip-backward-symbolic"; lato: 20 }
            Icona { nome: "media-playback-start-symbolic"; lato: 22 }
            Icona { nome: "media-skip-forward-symbolic"; lato: 20 }
        }
    }

    // ── Riga 2: Non disturbare, Silenzioso, Risparmio ────────────────────
    Riquadro {
        x: cc.px(0); y: cc.py(2); width: cc.largo(2); height: cc.alto; radius: height / 2
        onTocco: tel.nonDisturbare(!tel.imp.non_disturbare)
        Row {
            x: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 10
            Tondo { anchors.verticalCenter: parent.verticalCenter; lato: Math.min(52, cc.alto - 20); icona: "weather-clear-night-symbolic"; colore: "#6366F1"
                    acceso: tel.imp.non_disturbare === true; onTocco: tel.nonDisturbare(!tel.imp.non_disturbare) }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: cc.largo(2) - cc.alto - 10
                Text { width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 2; text: I18n.t("Non disturbare"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.DemiBold }
                Text { text: tel.imp.non_disturbare ? I18n.t("Attivo") : I18n.t("Spento"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }
            }
        }
    }
    Repeater {
        model: [{ i: "audio-volume-muted-symbolic", k: "silenzioso", c: "#E5484D" }, { i: "battery-good-symbolic", k: "risparmio", c: "#F59E0B" }]
        Riquadro {
            required property var modelData
            required property int index
            readonly property bool acceso: tel.imp[modelData.k] === true
            x: cc.px(2 + index); y: cc.py(2); width: cc.u; height: cc.alto; radius: height / 2
            onTocco: tel.imposta(modelData.k, !acceso)
            Rectangle { anchors.fill: parent; radius: parent.radius; color: parent.modelData.c; opacity: parent.acceso ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: tel.tVeloce } } }
            Icona { anchors.centerIn: parent; nome: parent.modelData.i; lato: 22; tema: parent.acceso ? "scuro" : "" }
        }
    }

    // ── Righe 3–4: cursori e Momenti ─────────────────────────────────────
    Cursore { x: cc.px(0); y: cc.py(3); width: cc.u; height: cc.altoN(2); icona: "display-brightness-symbolic"; valore: cc.luce
              onCambia: function (v) { cc.luce = v; ponte.chiama("impostaLuminosita", [v]) } }
    Cursore { x: cc.px(1); y: cc.py(3); width: cc.u; height: cc.altoN(2); icona: "audio-volume-high-symbolic"; valore: cc.audio
              onCambia: function (v) { cc.audio = v; ponte.chiama("impostaVolume", [v]) } }
    Vetro {
        x: cc.px(2); y: cc.py(3); width: cc.largo(2); height: cc.altoN(2); radius: 26
        Text { x: 16; y: 14; text: I18n.t("Momenti"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
        Column {
            x: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 12
            width: parent.width - 24
            spacing: 6
            Repeater {
                model: [
                    { i: "weather-clear-night-symbolic", t: I18n.t("Notte"),
                      on: tel.imp.non_disturbare === true && tel.imp.silenzioso !== true,
                      f: function (si) { tel.nonDisturbare(si); if (si) { cc.luce = 25; ponte.chiama("impostaLuminosita", [25]) } } },
                    { i: "user-busy-symbolic", t: I18n.t("Lavoro"),
                      on: tel.imp.non_disturbare === true && tel.imp.silenzioso === true,
                      f: function (si) { tel.nonDisturbare(si); tel.imposta("silenzioso", si) } },
                    { i: "battery-good-symbolic", t: I18n.t("Durata"),
                      on: tel.imp.risparmio === true,
                      f: function (si) { tel.imposta("risparmio", si); if (si) { cc.luce = 40; ponte.chiama("impostaLuminosita", [40]) } } }
                ]
                Rectangle {
                    id: mo
                    required property var modelData
                    width: parent.width; height: Math.max(30, (cc.altoN(2) - 60) / 3); radius: 12
                    color: modelData.on ? tel.accento : tel.pal.traccia
                    Behavior on color { ColorAnimation { duration: tel.tVeloce } }
                    Row {
                        x: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                        Icona { anchors.verticalCenter: parent.verticalCenter; nome: mo.modelData.i; lato: 15; tema: mo.modelData.on ? "scuro" : "" }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: mo.modelData.t; color: mo.modelData.on ? "#FFFFFF" : tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                    }
                    MouseArea { anchors.fill: parent; onClicked: mo.modelData.f(!mo.modelData.on) }
                }
            }
        }
    }

    // ── Riga 5: scorciatoie ──────────────────────────────────────────────
    Repeater {
        model: [{ i: "accessories-calculator-symbolic", f: function () { tel.controllo = false; tel.apri({ "id": "interno:calcolatrice" }) } },
                { i: "camera-photo-symbolic", f: function () { tel.controllo = false; tel.apri({ "id": "interno:fotocamera" }) } },
                { i: "system-lock-screen-symbolic", f: function () { tel.controllo = false; tel.schermata = "blocco" } },
                { i: "preferences-system-symbolic", f: function () { tel.controllo = false; tel.apri({ "id": "interno:impostazioni" }) } }]
        Riquadro {
            required property var modelData
            required property int index
            x: cc.px(index); y: cc.py(5); width: cc.u; height: cc.alto; radius: height / 2
            onTocco: modelData.f()
            Icona { anchors.centerIn: parent; nome: parent.modelData.i; lato: 22 }
        }
    }
}
