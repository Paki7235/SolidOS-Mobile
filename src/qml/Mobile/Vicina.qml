// Vicina: manda e ricevi file con PC e telefoni vicini (LocalSend, Quick Share e
// codice QR per qualsiasi telefono con un browser). Usa lo stesso servizio del PC.
// In alto il radar: questo telefono al centro, i dispositivi vicini intorno (si toccano per
// mandare). Aurora: luce viola e azzurra; Prisma: viola pieno con i dispositivi colorati.
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: app
    color: tel.pal.sfondo
    property var stato: ({ attivo: false, visibilita: "nessuno", cartella: "", dispositivi: [] })
    property var qr: null
    readonly property var file: tel.daCondividere
    readonly property color sezione: tel.pal.superficie
    readonly property color linea: tel.pal.bordo

    function aggiorna() { ponte.avvia("vicinaStato", [], "vicina-stato") }
    function nomeFile(p) { return p.split("/").pop() }
    onVisibleChanged: if (visible) { aggiorna(); ponte.avvia("vicinaScopri", [], "vicina-scopri") } else if (qr) { ponte.chiama0("vicinaFermaQr"); qr = null }
    Component.onCompleted: aggiorna()
    Timer { interval: 3000; running: app.visible; repeat: true; onTriggered: app.aggiorna() }
    Connections {
        target: ponte
        function onCompletato(id, r) {
            if (id === "vicina-stato") app.stato = r
            else if (id === "vicina-qr") app.qr = r.ok ? r : null
        }
    }

    Punti { x: 20; y: 60; text: I18n.t("Vicina"); font.pixelSize: 32 }

    Flickable {
        x: 0; y: 104; width: parent.width; height: parent.height - y - 24
        contentHeight: contenuto.height + 20; clip: true
        Column {
            id: contenuto
            width: parent.width; spacing: 8

            // ── Radar ────────────────────────────────────────────────────
            Rectangle {
                id: radar
                x: 16; width: parent.width - 32; height: 262; radius: 30; clip: true
                color: "#8B6CFF"
                gradient: tel.solido ? null : luceRadar
                Gradient { id: luceRadar; GradientStop { position: 0; color: "#7B3CFF" } GradientStop { position: 1; color: "#0A8FC2" } }
                readonly property real cx: width / 2
                readonly property real cy: height / 2 + 10
                // onde che partono dal centro
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        property real fase: 0
                        width: 60 + fase * 300; height: width; radius: width / 2
                        x: radar.cx - width / 2; y: radar.cy - height / 2
                        color: "transparent"; border.width: 2
                        border.color: tel.solido ? "#C6F432" : "#FFFFFF"
                        opacity: 0.55 * (1 - fase)
                        SequentialAnimation on fase {
                            running: app.visible && tel.movimento; loops: Animation.Infinite
                            PauseAnimation { duration: index * 900 }
                            NumberAnimation { from: 0; to: 1; duration: 2700; easing.type: Easing.OutQuad }
                        }
                    }
                }
                // questo telefono
                Rectangle {
                    width: 64; height: 64; radius: 32
                    x: radar.cx - 32; y: radar.cy - 32
                    color: tel.solido ? "#C6F432" : "#FFFFFF"
                    IconaDispositivo { anchors.centerIn: parent; tipo: "telefono"; lato: 30; colore: "#141414" }
                }
                // i dispositivi vicini, in cerchio
                Repeater {
                    model: app.stato.dispositivi.slice(0, 5)
                    Column {
                        id: vicino
                        required property var modelData
                        required property int index
                        readonly property real angolo: -Math.PI / 2 + (index + 0.5) * 2 * Math.PI / Math.max(3, Math.min(5, app.stato.dispositivi.length))
                        x: radar.cx + Math.cos(angolo) * radar.width * 0.34 - width / 2
                        y: radar.cy + Math.sin(angolo) * 72 - 24
                        spacing: 4
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 48; height: 48; radius: 24
                            color: tel.solido ? (vicino.modelData.tipo === "telefono" ? "#FF6B4A" : "#59C3FF") : Qt.rgba(1, 1, 1, 0.22)
                            border.width: tel.solido ? 0 : 1; border.color: "#66FFFFFF"
                            IconaDispositivo { anchors.centerIn: parent; tipo: vicino.modelData.tipo === "telefono" ? "telefono" : "computer"; icona: "computer"; lato: 24
                                               colore: tel.solido && vicino.modelData.tipo !== "telefono" ? "#141414" : "#FFFFFF" }
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -6
                                onClicked: {
                                    if (app.file.length === 0) { tel.avviso(I18n.t("Scegli prima cosa mandare da Foto o File")); return }
                                    var r = ponte.chiama("vicinaInvia", [app.file, vicino.modelData.id])
                                    tel.avviso(r.messaggio)
                                    if (r.ok) tel.daCondividere = []
                                }
                            }
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; width: Math.min(implicitWidth, 96); elide: Text.ElideRight
                               text: vicino.modelData.nome; color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(11); font.weight: Font.DemiBold }
                    }
                }
                Text {
                    x: 18; y: 14
                    text: app.stato.dispositivi.length ? (app.file.length ? I18n.t("Tocca un dispositivo per mandare") : app.stato.dispositivi.length + " " + I18n.t("dispositivi vicini"))
                                                       : I18n.t("Ricerca dei dispositivi vicini…")
                    color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.Bold
                }
            }

            // ── File da mandare ──────────────────────────────────────────
            Rectangle {
                visible: app.file.length > 0
                x: 16; width: parent.width - 32; radius: 22; color: app.sezione
                height: colFile.implicitHeight + 24
                Column {
                    id: colFile
                    x: 16; y: 12; width: parent.width - 32; spacing: 4
                    Text { text: app.file.length === 1 ? I18n.t("Da mandare") : I18n.t("Da mandare") + " (" + app.file.length + ")"; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                    Repeater {
                        model: app.file.slice(0, 3)
                        Text { required property string modelData; width: colFile.width; elide: Text.ElideMiddle; text: app.nomeFile(modelData); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15) }
                    }
                    Text { text: I18n.t("Tocca un dispositivo qui sotto per mandarli"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13) }
                }
                Text {
                    anchors.right: parent.right; anchors.rightMargin: 14; y: 10
                    text: "×"; color: tel.pal.testo2; font.pixelSize: 22
                    MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: tel.daCondividere = [] }
                }
            }

            // ── Chi mi vede ──────────────────────────────────────────────
            Mono { x: 32; topPadding: 8; text: I18n.t("Chi può mandarti file") }
            Rectangle {
                x: 16; width: parent.width - 32; height: 48; radius: 24
                color: tel.solido ? tel.pal.superficie : "transparent"; border.width: tel.solido ? 0 : 1; border.color: tel.pal.bordo
                Row {
                    anchors.fill: parent; anchors.margins: 4
                    Repeater {
                        model: [{ k: "nessuno", t: I18n.t("Nessuno") }, { k: "associati", t: I18n.t("I miei") }, { k: "tutti10", t: I18n.t("Tutti 10 min") }]
                        Rectangle {
                            required property var modelData
                            width: (parent.width) / 3; height: 40; radius: 20
                            color: app.stato.visibilita === modelData.k ? (tel.solido ? "#C6F432" : tel.pal.pieno) : "transparent"
                            Behavior on color { ColorAnimation { duration: tel.tVeloce } }
                            Text { anchors.centerIn: parent; text: parent.modelData.t; color: app.stato.visibilita === parent.modelData.k ? (tel.solido ? "#141414" : "#FFFFFF") : tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.DemiBold }
                            MouseArea { anchors.fill: parent; onClicked: { ponte.chiama("vicinaVisibilita", [parent.modelData.k]); app.stato = Object.assign({}, app.stato, { visibilita: parent.modelData.k }) } }
                        }
                    }
                }
            }
            Text { x: 32; width: parent.width - 64; wrapMode: Text.Wrap; text: I18n.t("I file ricevuti vanno in") + " " + (app.stato.cartella || "Scaricati"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }

            // ── Dispositivi vicini ───────────────────────────────────────
            Text { x: 32; topPadding: 12; text: I18n.t("Dispositivi vicini"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
            Rectangle {
                x: 16; width: parent.width - 32; radius: 22; color: app.sezione
                height: Math.max(54, colDisp.height)
                Column {
                    id: colDisp
                    width: parent.width
                    Repeater {
                        model: app.stato.dispositivi
                        Item {
                            required property var modelData
                            required property int index
                            width: colDisp.width; height: 62
                            Rectangle {
                                x: 14; anchors.verticalCenter: parent.verticalCenter
                                width: 40; height: 40; radius: tel.solido ? 13 : 20; color: tel.coloreDispositivo(modelData.tipo)
                                IconaDispositivo { anchors.centerIn: parent; tipo: modelData.tipo === "telefono" ? "telefono" : "computer"; icona: "computer"; lato: 22; colore: tel.inchiostroDispositivo(modelData.tipo) }
                            }
                            Column {
                                x: 66; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 80; spacing: 2
                                Text { width: parent.width; elide: Text.ElideRight; text: modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16) }
                                Text { text: ({ localsend: "LocalSend", quickshare: "Quick Share", qr: "QR" })[modelData.backend] || modelData.backend; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }
                            }
                            Rectangle { visible: index < app.stato.dispositivi.length - 1; anchors.bottom: parent.bottom; x: 66; width: parent.width - 66; height: 1; color: app.linea }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (app.file.length === 0) { tel.avviso(I18n.t("Scegli prima cosa mandare da Foto o File")); return }
                                    var r = ponte.chiama("vicinaInvia", [app.file, modelData.id])
                                    tel.avviso(r.messaggio)
                                    if (r.ok) tel.daCondividere = []
                                }
                            }
                        }
                    }
                }
                Text {
                    visible: app.stato.dispositivi.length === 0
                    anchors.centerIn: parent
                    text: app.stato.attivo ? I18n.t("Ricerca dei dispositivi vicini…") : I18n.t("Avvio del servizio…")
                    color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(14)
                }
            }

            // ── Ricevi con QR ────────────────────────────────────────────
            Text { x: 32; topPadding: 12; text: I18n.t("Da un telefono qualsiasi"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
            Rectangle {
                x: 16; width: parent.width - 32; radius: 22; color: app.sezione
                height: app.qr ? colQr.implicitHeight + 28 : 54
                Text {
                    visible: !app.qr
                    x: 16; anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("Ricevi con un codice QR"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16)
                }
                MouseArea { anchors.fill: parent; enabled: !app.qr; onClicked: ponte.avvia("vicinaQr", [], "vicina-qr") }
                Column {
                    id: colQr
                    visible: app.qr !== null
                    x: 16; y: 14; width: parent.width - 32; spacing: 10
                    Text { width: parent.width; wrapMode: Text.Wrap; text: I18n.t("Inquadra il codice con la fotocamera dell'altro telefono (stessa rete Wi-Fi) e scegli i file da mandare."); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(14) }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 200; height: 200; color: "#ffffff"; radius: 8
                        Image { anchors.fill: parent; anchors.margins: 10; source: app.qr && app.qr.qr ? "file://" + app.qr.qr : ""; sourceSize.width: 400; fillMode: Image.PreserveAspectFit }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: app.qr ? app.qr.url || "" : ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: I18n.t("Chiudi"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15)
                        MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: { ponte.chiama0("vicinaFermaQr"); app.qr = null } }
                    }
                }
            }
        }
    }
}
