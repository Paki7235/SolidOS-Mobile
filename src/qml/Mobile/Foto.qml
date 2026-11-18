// Foto: griglia di tutte le immagini (Fotocamera, Immagini, Scaricati, DCIM), la più
// recente in alto. Tocca per vederla a tutto schermo; scorri di lato per la successiva.
// Azioni: Condividi (Vicina), Usa come sfondo, Elimina.
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: app
    color: tel.pal.sfondo
    property var elenco: []
    property int aperta: -1
    property bool comandi: true
    readonly property color sezione: tel.pal.superficie

    function aggiorna() { elenco = ponte.chiama0("foto") }
    function apri(i) { aperta = i; comandi = true; vista.positionViewAtIndex(i, ListView.Beginning); vista.currentIndex = i }
    onVisibleChanged: if (visible) aggiorna()
    Component.onCompleted: aggiorna()

    // ══ Griglia ══════════════════════════════════════════════════════════
    Punti { x: 20; y: 60; text: I18n.t("Foto").toUpperCase(); font.pixelSize: 36 }
    Text { x: 22; y: 96; text: app.elenco.length + " " + I18n.t("elementi"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13) }
    GridView {
        id: griglia
        x: 2; y: 124; width: parent.width - 4; height: parent.height - y
        clip: true
        readonly property real lato: Math.floor(width / 3)
        cellWidth: lato; cellHeight: lato
        model: app.elenco
        delegate: Item {
            required property var modelData
            required property int index
            width: griglia.lato; height: griglia.lato
            Image {
                anchors.fill: parent; anchors.margins: 1
                source: modelData.uri
                sourceSize.width: 240; sourceSize.height: 240
                fillMode: Image.PreserveAspectCrop; asynchronous: true
                Rectangle { anchors.fill: parent; color: tel.pal.traccia; visible: parent.status !== Image.Ready }
            }
            MouseArea { anchors.fill: parent; onClicked: app.apri(index) }
        }
    }
    Column {
        visible: app.elenco.length === 0
        anchors.centerIn: parent; spacing: 10
        Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: "camera-photo-symbolic"; lato: 48 }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Nessuna foto"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(18); font.weight: Font.DemiBold }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Le foto scattate e scaricate compaiono qui"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(14) }
    }

    // ══ A tutto schermo ══════════════════════════════════════════════════
    Rectangle {
        anchors.fill: parent
        visible: app.aperta >= 0
        color: "#000000"
        ListView {
            id: vista
            anchors.fill: parent
            orientation: ListView.Horizontal
            snapMode: ListView.SnapOneItem; highlightRangeMode: ListView.StrictlyEnforceRange
            boundsBehavior: Flickable.StopAtBounds
            model: app.aperta >= 0 ? app.elenco : []
            onCurrentIndexChanged: if (app.aperta >= 0) app.aperta = currentIndex
            delegate: Item {
                required property var modelData
                width: vista.width; height: vista.height
                Image {
                    anchors.fill: parent
                    source: modelData.uri; fillMode: Image.PreserveAspectFit; asynchronous: true
                    sourceSize.width: 1400
                }
                TapHandler { onTapped: app.comandi = !app.comandi }
            }
        }
        // Barra in alto
        Rectangle {
            visible: app.comandi
            width: parent.width; height: 100; color: Qt.rgba(0, 0, 0, 0.55)
            Text {
                x: 18; y: 58
                text: "‹ " + I18n.t("Foto"); color: "#ffffff"; font.family: Tema.font; font.pixelSize: tel.px(16)
                MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: app.aperta = -1 }
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 18; y: 60
                text: app.aperta >= 0 && app.elenco[app.aperta] ? app.elenco[app.aperta].data : ""
                color: Qt.rgba(1, 1, 1, 0.8); font.family: Tema.font; font.pixelSize: tel.px(13)
            }
        }
        // Azioni in basso
        Rectangle {
            visible: app.comandi
            anchors.bottom: parent.bottom
            width: parent.width; height: 96; color: Qt.rgba(0, 0, 0, 0.55)
            Row {
                anchors.centerIn: parent; anchors.verticalCenterOffset: -8
                spacing: 40
                Repeater {
                    model: [{ k: "condividi", t: I18n.t("Condividi"), i: "emblem-shared-symbolic" },
                            { k: "sfondo", t: I18n.t("Sfondo"), i: "preferences-desktop-wallpaper-symbolic" },
                            { k: "elimina", t: I18n.t("Elimina"), i: "user-trash-symbolic" }]
                    Column {
                        required property var modelData
                        spacing: 4
                        Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: parent.modelData.i; lato: 24; tema: "scuro" }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.modelData.t.toUpperCase(); color: "#ffffff"; font.family: tel.fontMono; font.pixelSize: tel.px(10) }
                        MouseArea {
                            width: 60; height: 50; x: (parent.width - 60) / 2; y: -6
                            onClicked: {
                                var f = app.elenco[app.aperta]
                                if (!f) return
                                if (parent.modelData.k === "condividi") tel.condividi([f.percorso])
                                else if (parent.modelData.k === "sfondo") { var r = ponte.chiama("sfondoFoto", [f.percorso]); tel.imp = ponte.chiama0("impostazioni"); tel.avviso(r.messaggio) }
                                else elimina.open()
                            }
                        }
                    }
                }
            }
        }
    }
    Popup {
        id: elimina
        anchors.centerIn: parent
        width: parent.width - 60; modal: true; padding: 20
        background: Rectangle { radius: 20; color: app.sezione }
        Column {
            width: parent.width; spacing: 14
            Text { width: parent.width; wrapMode: Text.Wrap; text: I18n.t("Spostare la foto nel Cestino?"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.DemiBold }
            Row {
                spacing: 10; anchors.right: parent.right
                Pulsante { text: I18n.t("Annulla"); onClicked: elimina.close() }
                Pulsante {
                    text: I18n.t("Elimina"); pericoloso: true
                    onClicked: {
                        var i = app.aperta
                        ponte.chiama("cestinaFile", [app.elenco[i].percorso])
                        elimina.close(); app.aggiorna()
                        if (app.elenco.length === 0) app.aperta = -1
                        else app.apri(Math.min(i, app.elenco.length - 1))
                    }
                }
            }
        }
    }
}
