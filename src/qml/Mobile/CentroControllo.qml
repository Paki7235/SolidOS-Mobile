// Centro di controllo (dall'angolo in alto a destra): interruttori rapidi, luminosità,
// volume e rete. Tutto in schede ordinate su una griglia regolare. I comandi agiscono
// davvero sul sistema.
import QtQuick
import SolidUI

Item {
    id: cc
    property int luce: 70
    property int audio: 50
    onVisibleChanged: if (visible) { luce = ponte.chiama0("luminosita"); audio = ponte.chiama0("volume") }
    readonly property var st: tel.stato || ({})
    readonly property bool wifiAcceso: st.rete ? st.rete.wifi : false
    readonly property real larghezza: width - 2 * tel.margine

    MouseArea { anchors.fill: parent; onClicked: tel.controllo = false }

    Column {
        x: tel.margine; y: 52
        width: cc.larghezza
        spacing: 14

        // ── Intestazione: ora e data, Impostazioni ───────────────────────
        Item {
            width: parent.width; height: 56
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text { text: tel.ora(); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 34; font.weight: Font.Light }
                Text { text: tel.giorno(); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13); font.capitalization: Font.Capitalize }
            }
            Rectangle {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                width: 40; height: 40; radius: 20; color: tel.pal.superficie2
                Icona { anchors.centerIn: parent; nome: "preferences-system-symbolic"; lato: 18 }
                MouseArea { anchors.fill: parent; onClicked: { tel.controllo = false; tel.apri({ "id": "interno:impostazioni" }) } }
            }
        }

        // ── Interruttori rapidi: 4 per riga, tutti uguali ────────────────
        Rectangle {
            width: parent.width; height: interruttori.height + 32
            radius: tel.r3; color: tel.pal.superficie; border.color: tel.pal.bordo
            Grid {
                id: interruttori
                x: 8; y: 16
                columns: 4; rowSpacing: 16
                Repeater {
                    model: [
                        { i: "network-wireless-symbolic", t: "Wi-Fi", acceso: cc.wifiAcceso,
                          f: function () { ponte.chiama("wifi", [!cc.wifiAcceso]); ponte.avvia("stato", [], "stato") } },
                        { i: "bluetooth-active-symbolic", t: "Bluetooth", acceso: cc.st.bluetooth === true,
                          f: function () { ponte.chiama("bluetooth", [!cc.st.bluetooth]); ponte.avvia("stato", [], "stato") } },
                        { i: "network-cellular-symbolic", t: I18n.t("Dati"), acceso: tel.imp.dati_mobili === true,
                          f: function () { ponte.avvia("datiMobili", [!tel.imp.dati_mobili], "dati"); tel.imposta("dati_mobili", !tel.imp.dati_mobili) } },
                        { i: "airplane-mode-symbolic", t: I18n.t("Aereo"), acceso: false,
                          f: function () { tel.avviso(I18n.t("Modalità aereo: arriva con il telefono vero")) } },
                        { i: "weather-clear-night-symbolic", t: I18n.t("Non disturbare"), acceso: tel.imp.non_disturbare === true,
                          f: function () { tel.nonDisturbare(!tel.imp.non_disturbare) } },
                        { i: "audio-volume-muted-symbolic", t: I18n.t("Silenzioso"), acceso: tel.imp.silenzioso === true,
                          f: function () { tel.imposta("silenzioso", !tel.imp.silenzioso) } },
                        { i: "system-lock-screen-symbolic", t: I18n.t("Blocca"), acceso: false,
                          f: function () { tel.controllo = false; tel.schermata = "blocco" } },
                        { i: "preferences-desktop-wallpaper-symbolic", t: I18n.t("Aspetto"), acceso: false,
                          f: function () { tel.controllo = false; tel.personalizza = true } }
                    ]
                    Item {
                        required property var modelData
                        width: (cc.larghezza - 16) / 4; height: 78
                        Rectangle {
                            id: tasto
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 52; height: 52; radius: 26
                            color: parent.modelData.acceso ? tel.accento : tel.pal.superficie2
                            scale: tocco.pressed ? 0.93 : 1
                            Behavior on scale { NumberAnimation { duration: 80 } }
                            Icona { anchors.centerIn: parent; nome: parent.parent.modelData.i; lato: 22 }
                        }
                        Text {
                            anchors.top: tasto.bottom; anchors.topMargin: 6
                            width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                            text: parent.modelData.t; color: tel.pal.testo2
                            font.family: Tema.font; font.pixelSize: tel.px(11); font.weight: Font.Medium
                        }
                        MouseArea { id: tocco; anchors.fill: parent; onClicked: parent.modelData.f() }
                    }
                }
            }
        }

        // ── Luminosità e volume: cursori orizzontali ─────────────────────
        Rectangle {
            width: parent.width; height: 132
            radius: tel.r3; color: tel.pal.superficie; border.color: tel.pal.bordo
            Column {
                x: 16; y: 16; width: parent.width - 32
                spacing: 12
                Repeater {
                    model: [{ i: "display-brightness-symbolic", chiave: "luce" }, { i: "audio-volume-high-symbolic", chiave: "audio" }]
                    Rectangle {
                        id: cursore
                        required property var modelData
                        readonly property int valore: cc[modelData.chiave]
                        width: parent.width; height: 44; radius: 22
                        color: tel.pal.superficie2
                        clip: true
                        Rectangle {
                            width: Math.max(44, parent.width * cursore.valore / 100); height: parent.height; radius: 22
                            color: tel.pal.pieno
                        }
                        Icona { x: 13; anchors.verticalCenter: parent.verticalCenter; nome: cursore.modelData.i; lato: 18 }
                        MouseArea {
                            anchors.fill: parent
                            function aggiorna(x) {
                                var v = Math.max(5, Math.min(100, Math.round(x / width * 100)))
                                cc[cursore.modelData.chiave] = v
                                if (cursore.modelData.chiave === "luce") ponte.chiama("impostaLuminosita", [v])
                                else ponte.chiama("impostaVolume", [v])
                            }
                            onPressed: function (e) { aggiorna(e.x) }
                            onPositionChanged: function (e) { aggiorna(e.x) }
                        }
                    }
                }
            }
        }

        // ── Rete e batteria ───────────────────────────────────────────────
        Row {
            width: parent.width; spacing: 12
            Repeater {
                model: [
                    { i: cc.st.rete && cc.st.rete.tipo === "ethernet" ? "network-wired-symbolic" : "network-wireless-symbolic",
                      t: cc.st.rete && cc.st.rete.connesso ? cc.st.rete.nome : I18n.t("Non connesso"), s: I18n.t("Rete") },
                    { i: "battery-good-symbolic",
                      t: (cc.st.batteria ? cc.st.batteria.livello : 100) + "%", s: cc.st.batteria && cc.st.batteria.carica ? I18n.t("In carica") : I18n.t("Batteria") }
                ]
                Rectangle {
                    required property var modelData
                    width: (cc.larghezza - 12) / 2; height: 64
                    radius: tel.r2; color: tel.pal.superficie; border.color: tel.pal.bordo
                    Row {
                        x: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 12
                        Icona { anchors.verticalCenter: parent.verticalCenter; nome: parent.parent.modelData.i; lato: 20 }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text { width: (cc.larghezza - 12) / 2 - 64; elide: Text.ElideRight; text: parent.parent.parent.modelData.t; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.DemiBold }
                            Text { text: parent.parent.parent.modelData.s; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }
                        }
                    }
                }
            }
        }
    }
}
