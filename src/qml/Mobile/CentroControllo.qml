// Centro di controllo (dall'angolo in alto a destra), in stile iPhone: moduli in vetro su
// una griglia di 4 colonne. Connessioni (2×2), Non disturbare e scorciatoie, cursori
// verticali alti per luminosità e volume, rete, e una fila di pulsanti rapidi.
// I comandi agiscono davvero sul sistema.
import QtQuick
import SolidUI

Item {
    id: cc
    property int luce: 70
    property int audio: 50
    onVisibleChanged: if (visible) { luce = ponte.chiama0("luminosita"); audio = ponte.chiama0("volume") }
    readonly property var st: tel.stato || ({})
    readonly property bool wifiAcceso: st.rete ? st.rete.wifi : false

    // Griglia: 4 colonne uguali; «passo» = una cella più lo spazio
    readonly property real spazio: 14
    readonly property real lato: Math.floor((width - 2 * 20 - 3 * spazio) / 4)
    readonly property real passo: lato + spazio
    readonly property real x0: 20
    readonly property real y0: 64
    function px(c) { return x0 + c * passo }
    function py(r) { return y0 + r * passo }
    function largo(n) { return n * lato + (n - 1) * spazio }

    MouseArea { anchors.fill: parent; onClicked: tel.controllo = false }

    // Un modulo del centro di controllo: vetro con angoli morbidi
    component Modulo: Vetro { radius: Math.round(cc.lato * 0.32) }
    // Un interruttore rotondo dentro un modulo
    component Tondo: Rectangle {
        id: tondo
        property string icona: ""
        property bool acceso: false
        property color coloreAcceso: tel.accento
        signal premuto()
        width: Math.round(cc.lato * 0.72); height: width; radius: width / 2
        color: acceso ? coloreAcceso : tel.pal.traccia
        scale: toccoTondo.pressed ? 0.93 : 1
        Behavior on scale { NumberAnimation { duration: tel.tVeloce } }
        Behavior on color { ColorAnimation { duration: tel.tVeloce } }
        Icona { anchors.centerIn: parent; nome: tondo.icona; lato: Math.round(tondo.width * 0.44); tema: tondo.acceso ? "scuro" : "" }
        MouseArea { id: toccoTondo; anchors.fill: parent; anchors.margins: -4; onClicked: tondo.premuto() }
    }

    // ── Connessioni (2×2) ────────────────────────────────────────────────
    Modulo {
        x: cc.px(0); y: cc.py(0)
        width: cc.largo(2); height: cc.largo(2)
        Grid {
            anchors.centerIn: parent
            columns: 2
            spacing: Math.round(cc.lato * 0.22)
            Tondo { icona: "airplane-mode-symbolic"; coloreAcceso: "#F59E0B"; onPremuto: tel.avviso(I18n.t("Modalità aereo: arriva con il telefono vero")) }
            Tondo { icona: "network-cellular-symbolic"; coloreAcceso: tel.pal.successo; acceso: tel.imp.dati_mobili === true
                    onPremuto: { ponte.avvia("datiMobili", [!tel.imp.dati_mobili], "dati"); tel.imposta("dati_mobili", !tel.imp.dati_mobili) } }
            Tondo { icona: "network-wireless-symbolic"; acceso: cc.wifiAcceso
                    onPremuto: { ponte.chiama("wifi", [!cc.wifiAcceso]); ponte.avvia("stato", [], "stato") } }
            Tondo { icona: "bluetooth-active-symbolic"; acceso: cc.st.bluetooth === true
                    onPremuto: { ponte.chiama("bluetooth", [!cc.st.bluetooth]); ponte.avvia("stato", [], "stato") } }
        }
    }

    // ── Non disturbare (largo) ───────────────────────────────────────────
    Modulo {
        x: cc.px(2); y: cc.py(0)
        width: cc.largo(2); height: cc.lato
        color: tel.imp.non_disturbare ? Qt.rgba(0.39, 0.40, 0.95, 0.92) : tel.pal.vetro
        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 12; spacing: 10
            Rectangle {
                width: Math.round(cc.lato * 0.5); height: width; radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: tel.imp.non_disturbare ? "#ffffff" : tel.pal.traccia
                Icona { anchors.centerIn: parent; nome: "weather-clear-night-symbolic"; lato: Math.round(parent.width * 0.5); tema: tel.imp.non_disturbare ? "chiaro" : "" }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text { text: I18n.t("Non disturbare"); color: tel.imp.non_disturbare ? "#ffffff" : tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                Text { text: tel.imp.non_disturbare ? I18n.t("Attivo") : I18n.t("Spento"); color: tel.imp.non_disturbare ? Qt.rgba(1, 1, 1, 0.8) : tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(11) }
            }
        }
        MouseArea { anchors.fill: parent; onClicked: tel.nonDisturbare(!tel.imp.non_disturbare) }
    }

    // ── Scorciatoie quadrate: Torcia e Aspetto ───────────────────────────
    Repeater {
        model: [
            { i: "torcia", f: function () { tel.avviso(I18n.t("Torcia: arriva con il telefono vero")) } },
            { i: "preferences-desktop-wallpaper-symbolic", f: function () { tel.controllo = false; tel.personalizza = true } }
        ]
        Modulo {
            required property var modelData
            required property int index
            x: cc.px(2 + index); y: cc.py(1)
            width: cc.lato; height: cc.lato
            Icona { anchors.centerIn: parent; visible: parent.modelData.i !== "torcia"; nome: parent.modelData.i; lato: Math.round(cc.lato * 0.34) }
            // Torcia disegnata (non tutti i temi di icone ce l'hanno)
            Item {
                visible: parent.modelData.i === "torcia"
                anchors.centerIn: parent; width: 14; height: 24
                Rectangle { width: 14; height: 7; radius: 2; color: tel.pal.testo }
                Rectangle { y: 6; x: 3; width: 8; height: 17; radius: 2; color: tel.pal.testo }
                Rectangle { y: 10; x: 6; width: 2; height: 4; radius: 1; color: tel.pal.suPieno }
            }
            scale: toccoScorc.pressed ? 0.95 : 1
            Behavior on scale { NumberAnimation { duration: tel.tVeloce } }
            MouseArea { id: toccoScorc; anchors.fill: parent; onClicked: parent.modelData.f() }
        }
    }

    // ── Luminosità e volume: cursori verticali alti ──────────────────────
    Repeater {
        model: [{ i: "display-brightness-symbolic", chiave: "luce" }, { i: "audio-volume-high-symbolic", chiave: "audio" }]
        Modulo {
            id: cursore
            required property var modelData
            required property int index
            readonly property int valore: cc[modelData.chiave]
            x: cc.px(index); y: cc.py(2)
            width: cc.lato; height: cc.largo(2)
            clip: true
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: Math.max(parent.radius * 2, parent.height * cursore.valore / 100)
                radius: parent.radius
                color: tel.pal.pieno
                Behavior on height { enabled: !trascina.pressed; NumberAnimation { duration: tel.tVeloce } }
            }
            Icona {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: 16
                nome: cursore.modelData.i; lato: Math.round(cc.lato * 0.32)
                tema: tel.chiaro ? "scuro" : "chiaro"     // sopra il riempimento pieno
            }
            MouseArea {
                id: trascina
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

    // ── Rete attuale (largo) e batteria ──────────────────────────────────
    Modulo {
        x: cc.px(2); y: cc.py(2)
        width: cc.largo(2); height: cc.lato
        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 14; spacing: 10
            Icona { anchors.verticalCenter: parent.verticalCenter; nome: cc.st.rete && cc.st.rete.tipo === "ethernet" ? "network-wired-symbolic" : "network-wireless-symbolic"; lato: Math.round(cc.lato * 0.3) }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text { width: cc.largo(2) - 60; elide: Text.ElideRight; text: cc.st.rete && cc.st.rete.connesso ? cc.st.rete.nome : I18n.t("Non connesso"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                Text { text: I18n.t("Rete"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(11) }
            }
        }
        MouseArea { anchors.fill: parent; onClicked: { tel.controllo = false; tel.apri({ "id": "interno:impostazioni" }); impostazioniApp.apri("wifi") } }
    }
    Modulo {
        x: cc.px(2); y: cc.py(3)
        width: cc.largo(2); height: cc.lato
        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 14; spacing: 10
            Text { anchors.verticalCenter: parent.verticalCenter; text: (cc.st.batteria ? cc.st.batteria.livello : 100) + "%"; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(22); font.weight: Font.DemiBold }
            Text { anchors.verticalCenter: parent.verticalCenter; text: cc.st.batteria && cc.st.batteria.carica ? I18n.t("In carica") : I18n.t("Batteria"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }
        }
    }

    // ── Fila di pulsanti rapidi ───────────────────────────────────────────
    Repeater {
        model: [
            { i: "system-lock-screen-symbolic", f: function () { tel.controllo = false; tel.schermata = "blocco" } },
            { i: "accessories-calculator-symbolic", f: function () { tel.controllo = false; tel.apri({ "id": "interno:calcolatrice" }) } },
            { i: "camera-photo-symbolic", f: function () { tel.controllo = false; tel.apri({ "id": "interno:fotocamera" }) } },
            { i: "preferences-system-symbolic", f: function () { tel.controllo = false; tel.apri({ "id": "interno:impostazioni" }) } }
        ]
        Modulo {
            required property var modelData
            required property int index
            x: cc.px(index); y: cc.py(4)
            width: cc.lato; height: cc.lato
            radius: cc.lato / 2
            Icona { anchors.centerIn: parent; nome: parent.modelData.i; lato: Math.round(cc.lato * 0.34) }
            scale: toccoRapido.pressed ? 0.93 : 1
            Behavior on scale { NumberAnimation { duration: tel.tVeloce } }
            MouseArea { id: toccoRapido; anchors.fill: parent; onClicked: parent.modelData.f() }
        }
    }
}
