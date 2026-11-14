// Vicina: manda e ricevi file con PC e telefoni vicini (LocalSend, Quick Share e
// codice QR per qualsiasi telefono con un browser). Usa lo stesso servizio del PC.
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: app
    color: tel.chiaro ? "#f2f3f8" : "#0e1118"
    property var stato: ({ attivo: false, visibilita: "nessuno", cartella: "", dispositivi: [] })
    property var qr: null
    readonly property var file: tel.daCondividere
    readonly property color sezione: tel.chiaro ? "#ffffff" : "#1b1f2b"
    readonly property color linea: tel.chiaro ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.08)

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

    Text { x: 20; y: 56; text: I18n.t("Vicina"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(30); font.weight: Font.Bold }

    Flickable {
        x: 0; y: 104; width: parent.width; height: parent.height - y - 24
        contentHeight: contenuto.height + 20; clip: true
        Column {
            id: contenuto
            width: parent.width; spacing: 8

            // ── File da mandare ──────────────────────────────────────────
            Rectangle {
                visible: app.file.length > 0
                x: 16; width: parent.width - 32; radius: 16; color: app.sezione
                height: colFile.implicitHeight + 24
                Column {
                    id: colFile
                    x: 16; y: 12; width: parent.width - 32; spacing: 4
                    Text { text: app.file.length === 1 ? I18n.t("Da mandare") : I18n.t("Da mandare") + " (" + app.file.length + ")"; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                    Repeater {
                        model: app.file.slice(0, 3)
                        Text { required property string modelData; width: colFile.width; elide: Text.ElideMiddle; text: app.nomeFile(modelData); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15) }
                    }
                    Text { text: I18n.t("Tocca un dispositivo qui sotto per mandarli"); color: tel.accento; font.family: Tema.font; font.pixelSize: tel.px(13) }
                }
                Text {
                    anchors.right: parent.right; anchors.rightMargin: 14; y: 10
                    text: "×"; color: tel.pal.testo2; font.pixelSize: 22
                    MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: tel.daCondividere = [] }
                }
            }

            // ── Chi mi vede ──────────────────────────────────────────────
            Text { x: 32; topPadding: 8; text: I18n.t("Chi può mandarti file"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
            Rectangle {
                x: 16; width: parent.width - 32; height: 44; radius: 12; color: app.sezione
                Row {
                    anchors.fill: parent; anchors.margins: 4
                    Repeater {
                        model: [{ k: "nessuno", t: I18n.t("Nessuno") }, { k: "associati", t: I18n.t("I miei") }, { k: "tutti10", t: I18n.t("Tutti 10 min") }]
                        Rectangle {
                            required property var modelData
                            width: (parent.width) / 3; height: 36; radius: 9
                            color: app.stato.visibilita === modelData.k ? tel.accento : "transparent"
                            Text { anchors.centerIn: parent; text: parent.modelData.t; color: app.stato.visibilita === parent.modelData.k ? "#ffffff" : tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.DemiBold }
                            MouseArea { anchors.fill: parent; onClicked: { ponte.chiama("vicinaVisibilita", [parent.modelData.k]); app.stato = Object.assign({}, app.stato, { visibilita: parent.modelData.k }) } }
                        }
                    }
                }
            }
            Text { x: 32; width: parent.width - 64; wrapMode: Text.Wrap; text: I18n.t("I file ricevuti vanno in") + " " + (app.stato.cartella || "Scaricati"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }

            // ── Dispositivi vicini ───────────────────────────────────────
            Text { x: 32; topPadding: 12; text: I18n.t("Dispositivi vicini"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
            Rectangle {
                x: 16; width: parent.width - 32; radius: 16; color: app.sezione
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
                                width: 40; height: 40; radius: 20; color: tel.pal.traccia
                                IconaDispositivo { anchors.centerIn: parent; tipo: modelData.tipo === "telefono" ? "telefono" : "computer"; icona: "computer"; lato: 22; colore: tel.pal.testo }
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
                x: 16; width: parent.width - 32; radius: 16; color: app.sezione
                height: app.qr ? colQr.implicitHeight + 28 : 54
                Text {
                    visible: !app.qr
                    x: 16; anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("Ricevi con un codice QR"); color: tel.accento; font.family: Tema.font; font.pixelSize: tel.px(16)
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
                        text: I18n.t("Chiudi"); color: tel.accento; font.family: Tema.font; font.pixelSize: tel.px(15)
                        MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: { ponte.chiama0("vicinaFermaQr"); app.qr = null } }
                    }
                }
            }
        }
    }
}
