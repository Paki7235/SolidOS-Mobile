// Registratore del telefono: stessa logica e stessa cartella del PC (nucleo/apps/registratore.py).
// In basso il grande tasto rosso; mentre registra si vedono l'onda dal vivo, il tempo, Pausa
// e Fine. Sopra l'elenco delle registrazioni: toccandone una si apre il lettore con l'onda,
// la posizione, ±15 secondi, Rinomina, Condividi (Vicina) ed Elimina.
import QtQuick
import QtQuick.Controls
import QtMultimedia
import SolidUI

Rectangle {
    id: app
    color: tel.pal.sfondo
    property var stato: ({ registra: false })
    property var voci: []
    property string aperta: ""
    function pc(m, a) { return ponte.chiama("appPc", ["registratore", m, a || []]) }
    function aggiorna() { voci = pc("elenco") || []; stato = pc("stato") || { registra: false } }
    function tempo(s) { s = Math.floor(s); return Math.floor(s / 60) + ":" + ("0" + s % 60).slice(-2) }
    onVisibleChanged: if (visible) aggiorna()
    Component.onCompleted: aggiorna()
    Timer { interval: 120; running: app.stato.registra === true; repeat: true; onTriggered: app.stato = app.pc("stato") || { registra: false } }

    MediaPlayer { id: lettore; audioOutput: AudioOutput {} }
    readonly property var voce: voci.find(function (v) { return v.id === aperta }) || null

    Punti { x: 20; y: 60; text: I18n.t("Registrazioni") }
    ListView {
        id: elenco
        x: 8; y: 112; width: parent.width - 16; height: parent.height - y - (app.stato.registra ? 330 : 190); clip: true
        model: app.voci
        delegate: Rectangle {
            id: reg
            required property var modelData
            readonly property bool aperta: app.aperta === modelData.id
            width: elenco.width; height: aperta ? 190 : 66; radius: 20
            color: aperta ? tel.pal.superficie : "transparent"
            Behavior on height { NumberAnimation { duration: tel.tNormale; easing.type: Easing.OutQuint } }
            clip: true
            Column { x: 14; y: 12; width: parent.width - 100
                     Text { width: parent.width; elide: Text.ElideRight; text: modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.DemiBold }
                     Text { text: modelData.data; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 13 } }
            Text { anchors.right: parent.right; anchors.rightMargin: 14; y: 22; text: app.tempo(modelData.durata); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 14 }
            Rectangle { visible: !parent.aperta; x: 14; anchors.bottom: parent.bottom; width: parent.width - 28; height: 1; color: tel.pal.bordo }
            MouseArea { width: parent.width; height: 66; onClicked: { lettore.stop(); app.aperta = parent.aperta ? "" : modelData.id; if (app.aperta) lettore.source = modelData.percorso } }
            // Lettore della registrazione aperta
            Item {
                visible: parent.aperta
                x: 14; y: 66; width: parent.width - 28; height: 120
                Row {   // l'onda, colorata fin dove è arrivato l'ascolto
                    id: onda
                    width: parent.width; height: 36; spacing: 2
                    readonly property int quante: Math.min(80, reg.modelData.onde.length || 60)
                    Repeater {
                        model: onda.quante
                        Rectangle {
                            required property int index
                            readonly property real v: reg.modelData.onde.length ? (reg.modelData.onde[Math.floor(index * reg.modelData.onde.length / onda.quante)] || 0.05) : 0.3
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(2, (onda.width - 2 * (onda.quante - 1)) / onda.quante); height: Math.max(3, 36 * Math.min(1, v * 1.6)); radius: 1
                            color: lettore.duration > 0 && index / onda.quante <= lettore.position / lettore.duration ? (tel.solido ? "#FF6B4A" : tel.accento) : tel.pal.testo3
                        }
                    }
                }
                Text { y: 42; text: app.tempo(lettore.position / 1000); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 12 }
                Text { y: 42; anchors.right: parent.right; text: "-" + app.tempo(Math.max(0, (lettore.duration - lettore.position) / 1000)); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 12 }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter; y: 60; spacing: 24
                    TastoTondo { lato: 44; icona: "media-seek-backward-symbolic"; color: "transparent"; onTocco: lettore.position = Math.max(0, lettore.position - 15000) }
                    TastoTondo { lato: 52; pieno: true; icona: lettore.playbackState === MediaPlayer.PlayingState ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                                 onTocco: lettore.playbackState === MediaPlayer.PlayingState ? lettore.pause() : lettore.play() }
                    TastoTondo { lato: 44; icona: "media-seek-forward-symbolic"; color: "transparent"; onTocco: lettore.position = Math.min(lettore.duration, lettore.position + 15000) }
                }
                Row {
                    anchors.right: parent.right; y: 66; spacing: 4
                    TastoTondo { lato: 36; icona: "linea-condividi"; color: "transparent"; onTocco: { tel.daCondividere = [decodeURIComponent(reg.modelData.percorso.replace("file://", ""))]; tel.appInterna = "vicina" } }
                }
                Row {
                    y: 66; spacing: 4
                    TastoTondo { lato: 36; icona: "linea-matita"; color: "transparent"; onTocco: { rinomina.ident = reg.modelData.id; campoNome.text = reg.modelData.nome; rinomina.open() } }
                    TastoTondo { lato: 36; icona: "linea-cestino"; color: "transparent"; temaIcona: ""; onTocco: { lettore.stop(); app.pc("elimina", [reg.modelData.id]); app.aperta = ""; app.aggiorna(); tel.avviso(I18n.t("Registrazione eliminata")) } }
                }
            }
        }
        Text { anchors.centerIn: parent; visible: elenco.count === 0 && !app.stato.registra; width: parent.width - 60; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
               text: I18n.t("Nessuna registrazione. Premi il tasto rosso per registrare."); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 15 }
    }

    // ── In basso: registrazione ──────────────────────────────────────────
    Rectangle {
        anchors.bottom: parent.bottom; width: parent.width
        height: app.stato.registra ? 320 : 180
        color: tel.pal.superficie; radius: 30
        Behavior on height { NumberAnimation { duration: tel.tNormale; easing.type: Easing.OutQuint } }
        Column {
            visible: app.stato.registra === true
            anchors.horizontalCenter: parent.horizontalCenter; y: 22; spacing: 8
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: app.stato.nome || I18n.t("Nuova registrazione"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 17; font.weight: Font.DemiBold }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: app.tempo(app.stato.secondi || 0) + (app.stato.pausa ? "  ·  " + I18n.t("in pausa") : ""); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 28; font.weight: Font.Light }
            // onda dal vivo
            Row {
                anchors.horizontalCenter: parent.horizontalCenter; height: 70; spacing: 2
                Repeater {
                    model: (app.stato.livelli || []).slice(-80)
                    Rectangle { required property real modelData; anchors.verticalCenter: parent.verticalCenter; width: 2.5; radius: 1; height: Math.max(3, 70 * modelData); color: "#E5484D" }
                }
            }
            Text { visible: !!app.stato.errore; width: app.width - 40; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: app.stato.errore || ""; color: tel.rosso; font.family: Tema.font; font.pixelSize: 13 }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 46; spacing: 36
            TastoTondo { visible: app.stato.registra === true; anchors.verticalCenter: parent.verticalCenter; lato: 56
                         icona: app.stato.pausa ? "media-record-symbolic" : "media-playback-pause-symbolic"; onTocco: app.stato = app.pc("pausa", [!app.stato.pausa]) || app.stato }
            // Il grande tasto: tondo rosso, quadrato mentre registra (Fine)
            Rectangle {
                width: 80; height: 80; radius: 40; color: "transparent"; border.width: 4; border.color: tel.pal.testo3
                Rectangle { anchors.centerIn: parent; width: app.stato.registra ? 30 : 64; height: width; radius: app.stato.registra ? 8 : width / 2; color: "#E5484D"
                            Behavior on width { NumberAnimation { duration: 160 } } Behavior on radius { NumberAnimation { duration: 160 } } }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (app.stato.registra) { var r = app.pc("ferma", [true]); app.aggiorna(); if (r && r.id) { app.aperta = r.id; tel.avviso(I18n.t("Registrazione salvata")) } }
                        else { lettore.stop(); app.stato = app.pc("avvia") || { registra: false }; if (app.stato.errore) tel.avviso(app.stato.errore) }
                    }
                }
            }
            TastoTondo { visible: app.stato.registra === true; anchors.verticalCenter: parent.verticalCenter; lato: 56; icona: "linea-cestino"
                         onTocco: { app.pc("ferma", [false]); app.aggiorna(); tel.avviso(I18n.t("Registrazione scartata")) } }
        }
    }

    Popup {
        id: rinomina
        property string ident: ""
        anchors.centerIn: parent; width: parent.width - 40; modal: true; padding: 18
        background: Rectangle { radius: 20; color: tel.pal.superficie }
        Column {
            width: parent.width; spacing: 12
            Text { text: I18n.t("Rinomina"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 17; font.weight: Font.Bold }
            CampoTesto { id: campoNome; width: parent.width }
            Row { anchors.right: parent.right; spacing: 10
                  Pulsante { text: I18n.t("Annulla"); onClicked: rinomina.close() }
                  Pulsante { text: I18n.t("Salva"); principale: true
                             onClicked: { var r = app.pc("rinomina", [rinomina.ident, campoNome.text]); if (r && r.ok === false) tel.avviso(r.messaggio || ""); else { app.aperta = r && r.id ? r.id : ""; app.aggiorna() } rinomina.close() } } }
        }
    }
}
