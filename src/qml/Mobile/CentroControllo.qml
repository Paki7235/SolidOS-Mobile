// Centro di controllo (dall'angolo in alto a destra): connessioni, luminosità, volume,
// scorciatoie e Personalizza. I comandi agiscono davvero sul sistema.
import QtQuick
import SolidUI

Item {
    id: cc
    property int luce: 70
    property int audio: 50
    onVisibleChanged: if (visible) { luce = ponte.chiama0("luminosita"); audio = ponte.chiama0("volume") }
    readonly property var st: tel.stato || ({})
    readonly property bool wifiAcceso: st.rete ? st.rete.wifi : false
    readonly property real lato: (width - 40 - 3 * 14) / 4

    MouseArea { anchors.fill: parent; onClicked: tel.controllo = false }

    Grid {
        x: 20; y: 58
        columns: 4
        spacing: 14
        // Connessioni (2×2)
        Vetro {
            width: cc.lato * 2 + 14; height: width; radius: 26
            Grid {
                anchors.centerIn: parent
                columns: 2; spacing: 14
                Repeater {
                    model: [
                        { i: "network-wireless-symbolic", acceso: cc.wifiAcceso, f: function () { ponte.chiama("wifi", [!cc.wifiAcceso]); ponte.avvia("stato", [], "stato") } },
                        { i: "bluetooth-active-symbolic", acceso: cc.st.bluetooth === true, f: function () { ponte.chiama("bluetooth", [!cc.st.bluetooth]); ponte.avvia("stato", [], "stato") } },
                        { i: "airplane-mode-symbolic", acceso: false, f: function () { tel.avviso(I18n.t("Modalità aereo: arriva con il telefono vero")) } },
                        { i: "network-cellular-symbolic", acceso: false, f: function () { tel.avviso(I18n.t("Dati mobili: arrivano con la SIM")) } }
                    ]
                    Rectangle {
                        required property var modelData
                        width: 56; height: 56; radius: 28
                        color: modelData.acceso ? tel.accento : tel.pal.traccia
                        Icona { anchors.centerIn: parent; nome: parent.modelData.i; lato: 24 }
                        MouseArea { anchors.fill: parent; onClicked: parent.modelData.f() }
                    }
                }
            }
        }
        // Spazi / Personalizza
        Vetro {
            width: cc.lato * 2 + 14; height: width; radius: 26
            Column {
                anchors.fill: parent; anchors.margins: 16
                spacing: 10
                Text { text: I18n.t("Questo telefono"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12); font.weight: Font.DemiBold }
                Text { text: (cc.st.batteria ? cc.st.batteria.livello : 100) + "%"; color: tel.pal.testo; font.family: tel.fontOra; font.pixelSize: 34; font.weight: Font.Bold }
                Rectangle {
                    width: parent.width; height: 34; radius: 12
                    color: tel.accento
                    Text { anchors.centerIn: parent; text: I18n.t("Personalizza"); color: "#ffffff"; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; onClicked: { tel.controllo = false; tel.personalizza = true } }
                }
            }
        }
        // Luminosità e volume (cursori verticali)
        Repeater {
            model: [{ i: "display-brightness-symbolic", chiave: "luce" }, { i: "audio-volume-high-symbolic", chiave: "audio" }]
            Vetro {
                id: cursore
                required property var modelData
                readonly property int valore: cc[modelData.chiave]
                width: cc.lato; height: cc.lato * 2 + 14; radius: 26
                clip: true
                Rectangle {
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    height: parent.height * cursore.valore / 100
                    radius: 26
                    color: tel.pal.pieno
                }
                Icona { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 14; nome: cursore.modelData.i; lato: 24 }
                MouseArea {
                    anchors.fill: parent
                    function aggiorna(y) {
                        var v = Math.max(5, Math.min(100, Math.round((1 - y / height) * 100)))
                        cc[cursore.modelData.chiave] = v
                        if (cursore.modelData.chiave === "luce") ponte.chiama("impostaLuminosita", [v])
                        else ponte.chiama("impostaVolume", [v])
                    }
                    onPressed: function (e) { aggiorna(e.y) }
                    onPositionChanged: function (e) { aggiorna(e.y) }
                }
            }
        }
        // Rete attuale
        Vetro {
            width: cc.lato * 2 + 14; height: cc.lato; radius: 26
            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: 14; spacing: 10
                Icona { nome: cc.st.rete && cc.st.rete.tipo === "ethernet" ? "network-wired-symbolic" : "network-wireless-symbolic"; lato: 22; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    Text { text: cc.st.rete && cc.st.rete.connesso ? cc.st.rete.nome : I18n.t("Non connesso"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold; width: cc.lato * 2 - 40; elide: Text.ElideRight }
                    Text { text: I18n.t("Rete"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }
                }
            }
        }
        // Scorciatoie
        Repeater {
            model: [
                { i: "system-lock-screen-symbolic", f: function () { tel.controllo = false; tel.schermata = "blocco" } },
                { i: "preferences-system-symbolic", f: function () { tel.controllo = false; tel.apri({ "id": Tema.idSistema + "-impostazioni" }) } },
                { i: "camera-photo-symbolic", f: function () { tel.avviso(I18n.t("Fotocamera: arriva con il telefono vero")) } },
                { i: "accessories-calculator-symbolic", f: function () { tel.apri({ "id": Tema.idSistema + "-calcolatrice" }) } }
            ]
            Vetro {
                required property var modelData
                width: cc.lato; height: cc.lato; radius: 26
                Icona { anchors.centerIn: parent; nome: parent.modelData.i; lato: 24 }
                MouseArea { anchors.fill: parent; onClicked: parent.modelData.f() }
            }
        }
    }
}
