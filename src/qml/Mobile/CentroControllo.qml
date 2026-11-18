// Centro di controllo (dall'angolo in alto a destra), stile «Essenziale»: data e ora a
// puntini, otto tasti quadrati (accesi = bianchi), luminosità e volume fatti di puntini che
// si trascinano, i «Momenti» (un tocco prepara il telefono per la notte, il lavoro o per
// durare di più), il brano in riproduzione e le scorciatoie.
import QtQuick
import SolidUI

Item {
    id: cc
    property int luce: 70
    property int audio: 50
    onVisibleChanged: if (visible) { luce = ponte.chiama0("luminosita"); audio = ponte.chiama0("volume") }
    readonly property var st: tel.stato || ({})
    readonly property bool wifiAcceso: st.rete ? st.rete.wifi : false
    readonly property real largh: width - 2 * tel.margine
    readonly property real latoTasto: Math.floor((largh - 3 * 12) / 4)
    readonly property bool conLettore: height >= 800

    MouseArea { anchors.fill: parent; onClicked: tel.controllo = false }

    // Tasto quadrato: grigio scuro, bianco quando è acceso
    component Tasto: Rectangle {
        id: ta
        property string icona: ""
        property bool acceso: false
        signal tocco()
        width: cc.latoTasto; height: cc.latoTasto; radius: 24
        color: acceso ? tel.pal.pieno : tel.pal.superficie
        border.width: 1; border.color: acceso ? tel.pal.pieno : tel.pal.bordo
        scale: toccoTa.pressed ? 0.93 : 1
        Behavior on scale { NumberAnimation { duration: tel.tVeloce; easing.type: Easing.OutQuad } }
        Behavior on color { ColorAnimation { duration: tel.tVeloce } }
        Icona { anchors.centerIn: parent; nome: ta.icona; lato: 24; tema: ta.acceso ? (tel.chiaro ? "scuro" : "chiaro") : "" }
        MouseArea { id: toccoTa; anchors.fill: parent; onClicked: ta.tocco() }
    }
    // Cursore di puntini a tutta larghezza, con l'icona a sinistra e il numero a destra
    component Cursore: Vetro {
        id: cur
        property string icona: ""
        property int valore: 50
        signal cambia(int v)
        width: cc.largh; height: 62; radius: 22
        Icona { x: 18; anchors.verticalCenter: parent.verticalCenter; nome: cur.icona; lato: 22 }
        BarraPunti {
            id: punti
            x: 54; width: parent.width - 54 - 58; height: parent.height - 20
            anchors.verticalCenter: parent.verticalCenter
            valore: cur.valore; righe: 6
        }
        Mono { anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter; text: cur.valore; color: tel.pal.testo; font.pixelSize: tel.px(14); font.bold: true }
        MouseArea {
            anchors.fill: parent
            function muovi(x) { cur.cambia(Math.max(5, Math.min(100, Math.round((x - punti.x) / punti.width * 100)))) }
            onPressed: function (e) { muovi(e.x) }
            onPositionChanged: function (e) { muovi(e.x) }
        }
    }

    Column {
        x: tel.margine; y: 56
        width: cc.largh
        spacing: 12

        // ── Data, ora e connessioni ──────────────────────────────────────
        Item {
            width: parent.width; height: 92
            Column {
                anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                spacing: 4
                Mono { text: tel.adesso.toLocaleDateString(Qt.locale("it_IT"), "dddd · d MMM"); font.pixelSize: tel.px(12) }
                Punti { text: tel.ora(); font.family: tel.fontOra; font.pixelSize: 54; font.letterSpacing: -2 }
            }
            Column {
                anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.bottomMargin: 16
                spacing: 4
                Mono { anchors.right: parent.right; text: cc.st.rete && cc.st.rete.connesso ? cc.st.rete.nome : I18n.t("Nessuna rete") }
                Mono { anchors.right: parent.right; text: (cc.st.batteria ? cc.st.batteria.livello : 100) + "% " + I18n.t("batteria") }
            }
        }

        // ── Otto tasti ───────────────────────────────────────────────────
        Grid {
            columns: 4; spacing: 12
            Tasto { icona: "network-wireless-symbolic"; acceso: cc.wifiAcceso; onTocco: { ponte.chiama("wifi", [!cc.wifiAcceso]); ponte.avvia("stato", [], "stato") } }
            Tasto { icona: "bluetooth-active-symbolic"; acceso: cc.st.bluetooth === true; onTocco: { ponte.chiama("bluetooth", [!cc.st.bluetooth]); ponte.avvia("stato", [], "stato") } }
            Tasto { icona: "network-cellular-symbolic"; acceso: tel.imp.dati_mobili === true; onTocco: { ponte.avvia("datiMobili", [!tel.imp.dati_mobili], "dati"); tel.imposta("dati_mobili", !tel.imp.dati_mobili) } }
            Tasto { icona: "airplane-mode-symbolic"; onTocco: tel.avviso(I18n.t("Modalità aereo: arriva con il telefono vero")) }
            Tasto { icona: "weather-clear-night-symbolic"; acceso: tel.imp.non_disturbare === true; onTocco: tel.nonDisturbare(!tel.imp.non_disturbare) }
            Tasto { icona: "audio-volume-muted-symbolic"; acceso: tel.imp.silenzioso === true; onTocco: tel.imposta("silenzioso", !tel.imp.silenzioso) }
            Tasto { icona: "battery-good-symbolic"; acceso: tel.imp.risparmio === true; onTocco: tel.imposta("risparmio", !tel.imp.risparmio) }
            Tasto { icona: "display-brightness-symbolic"; acceso: tel.chiaro; onTocco: tel.imposta("tema", tel.chiaro ? "scuro" : "chiaro") }
        }

        // ── Luminosità e volume ──────────────────────────────────────────
        Cursore { icona: "display-brightness-symbolic"; valore: cc.luce; onCambia: function (v) { cc.luce = v; ponte.chiama("impostaLuminosita", [v]) } }
        Cursore { icona: "audio-volume-high-symbolic"; valore: cc.audio; onCambia: function (v) { cc.audio = v; ponte.chiama("impostaVolume", [v]) } }

        // ── Momenti: un tocco prepara il telefono ────────────────────────
        Row {
            id: momenti
            spacing: 8
            readonly property real largo: (cc.largh - 2 * spacing) / 3
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
                    width: momenti.largo; height: 44; radius: 22
                    color: modelData.on ? tel.pal.pieno : "transparent"
                    border.width: 1; border.color: modelData.on ? tel.pal.pieno : tel.pal.bordo
                    scale: toccoMo.pressed ? 0.95 : 1
                    Behavior on scale { NumberAnimation { duration: tel.tVeloce } }
                    Behavior on color { ColorAnimation { duration: tel.tVeloce } }
                    Row {
                        anchors.centerIn: parent; spacing: 8
                        Icona { anchors.verticalCenter: parent.verticalCenter; nome: mo.modelData.i; lato: 16; tema: mo.modelData.on ? (tel.chiaro ? "scuro" : "chiaro") : "" }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: mo.modelData.t; color: mo.modelData.on ? tel.pal.suPieno : tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                    }
                    MouseArea { id: toccoMo; anchors.fill: parent; onClicked: mo.modelData.f(!mo.modelData.on) }
                }
            }
        }

        // ── In riproduzione ──────────────────────────────────────────────
        Vetro {
            visible: cc.conLettore
            width: cc.largh; height: 122; radius: 24
            Column {
                x: 18; y: 16
                spacing: 2
                Mono { text: I18n.t("Musica") }
                Text { text: I18n.t("Nessun brano"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(17); font.weight: Font.DemiBold }
            }
            // Onda a barrette (ferma finché non suona niente)
            Row {
                anchors.right: parent.right; anchors.rightMargin: 18; y: 18
                spacing: 4
                Repeater {
                    model: [10, 22, 16, 28, 12, 24, 18, 8, 20, 14]
                    Rectangle { required property int modelData; anchors.bottom: parent.bottom; width: 3; height: modelData; radius: 1.5; color: tel.pal.testo3 }
                }
            }
            Row {
                x: 18; anchors.bottom: parent.bottom; anchors.bottomMargin: 14
                spacing: 18
                Icona { anchors.verticalCenter: parent.verticalCenter; nome: "media-skip-backward-symbolic"; lato: 20 }
                TastoTondo { anchors.verticalCenter: parent.verticalCenter; icona: "media-playback-start-symbolic"; pieno: true; lato: 42 }
                Icona { anchors.verticalCenter: parent.verticalCenter; nome: "media-skip-forward-symbolic"; lato: 20 }
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: cc.largh - 18 * 2 - 20 * 2 - 42 - 18 * 3 - 4; height: 2; color: tel.pal.traccia }
            }
            MouseArea { anchors.fill: parent; z: -1; onClicked: { tel.controllo = false; tel.apri({ "id": "interno:musica" }) } }
        }

        // ── Scorciatoie ──────────────────────────────────────────────────
        Grid {
            columns: 4; spacing: 12
            Repeater {
                model: [{ i: "accessories-calculator-symbolic", f: function () { tel.controllo = false; tel.apri({ "id": "interno:calcolatrice" }) } },
                        { i: "camera-photo-symbolic", f: function () { tel.controllo = false; tel.apri({ "id": "interno:fotocamera" }) } },
                        { i: "system-lock-screen-symbolic", f: function () { tel.controllo = false; tel.schermata = "blocco" } },
                        { i: "preferences-system-symbolic", f: function () { tel.controllo = false; tel.apri({ "id": "interno:impostazioni" }) } }]
                Tasto { required property var modelData; icona: modelData.i; height: 64; radius: 22; onTocco: modelData.f() }
            }
        }
    }
}
