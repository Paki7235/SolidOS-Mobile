// Musica: brani della cartella Musica (titolo e artista dal nome del file o dalla
// cartella), riproduzione con QtMultimedia, mini lettore in basso e schermata «In ascolto».
import QtQuick
import QtMultimedia
import SolidUI

Rectangle {
    id: app
    color: tel.chiaro ? "#f2f3f8" : "#0e1118"
    property var brani: []
    property int attuale: -1
    property bool grande: false
    readonly property var brano: attuale >= 0 ? brani[attuale] : null
    readonly property color sezione: tel.chiaro ? "#ffffff" : "#1b1f2b"
    readonly property color linea: tel.chiaro ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.08)
    readonly property bool suona: lettore.playbackState === MediaPlayer.PlayingState

    function aggiorna() { brani = ponte.chiama0("musica") }
    function suonaIndice(i) {
        if (i < 0 || i >= brani.length) return
        attuale = i
        if (!brani[i].uri) { tel.avviso(I18n.t("Brano di esempio: aggiungi la tua musica nella cartella Musica")); return }
        lettore.source = brani[i].uri
        lettore.play()
    }
    function suonaFile(percorso) {
        aggiorna()
        for (var i = 0; i < brani.length; i++) if (brani[i].percorso === percorso) { suonaIndice(i); grande = true; return }
    }
    function tempo(ms) { var s = Math.floor(ms / 1000); return Math.floor(s / 60) + ":" + ("0" + s % 60).slice(-2) }
    onVisibleChanged: if (visible) aggiorna()
    Component.onCompleted: { aggiorna(); if (tel.branoDaSuonare) { suonaFile(tel.branoDaSuonare); tel.branoDaSuonare = "" } }
    Connections { target: tel; function onBranoDaSuonareChanged() { if (tel.branoDaSuonare) { app.suonaFile(tel.branoDaSuonare); tel.branoDaSuonare = "" } } }

    MediaPlayer {
        id: lettore
        audioOutput: AudioOutput {}
        onMediaStatusChanged: if (mediaStatus === MediaPlayer.EndOfMedia) app.suonaIndice(app.attuale + 1)
        onErrorOccurred: function (errore, testo) { tel.avviso(I18n.t("Impossibile riprodurre il brano")) }
    }

    // ══ Elenco ═══════════════════════════════════════════════════════════
    Text { x: 20; y: 56; text: I18n.t("Musica"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(30); font.weight: Font.Bold }
    ListView {
        x: 16; y: 110; width: parent.width - 32; height: parent.height - y - (app.brano ? 110 : 30)
        clip: true
        model: app.brani
        delegate: Item {
            required property var modelData
            required property int index
            width: ListView.view.width; height: 60
            Rectangle {
                x: 2; anchors.verticalCenter: parent.verticalCenter
                width: 44; height: 44; radius: 10
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.hsla((index * 0.13) % 1, 0.6, 0.55, 1) }
                    GradientStop { position: 1; color: Qt.hsla((index * 0.13 + 0.15) % 1, 0.6, 0.4, 1) }
                }
                Text { anchors.centerIn: parent; text: "♪"; color: "#ffffff"; font.pixelSize: 20 }
            }
            Column {
                x: 58; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 64; spacing: 2
                Text { width: parent.width; elide: Text.ElideRight; text: modelData.titolo; color: index === app.attuale ? tel.accento : tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: index === app.attuale ? Font.DemiBold : Font.Normal }
                Text { width: parent.width; elide: Text.ElideRight; text: modelData.artista; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13) }
            }
            Rectangle { anchors.bottom: parent.bottom; x: 58; width: parent.width - 58; height: 1; color: app.linea }
            MouseArea { anchors.fill: parent; onClicked: app.suonaIndice(index) }
        }
    }
    Column {
        visible: app.brani.length === 0
        anchors.centerIn: parent; spacing: 10
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "♪"; color: tel.pal.testo2; font.pixelSize: 48 }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Nessun brano"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(18); font.weight: Font.DemiBold }
        Text { width: app.width - 80; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: I18n.t("Copia la tua musica nella cartella Musica (con Vicina o la microSD)"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(14) }
    }

    // ══ Mini lettore ═════════════════════════════════════════════════════
    Rectangle {
        visible: app.brano !== null && !app.grande
        x: 12; width: parent.width - 24; height: 68; radius: 18
        anchors.bottom: parent.bottom; anchors.bottomMargin: 32
        color: app.sezione
        Column {
            x: 16; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 120; spacing: 2
            Text { width: parent.width; elide: Text.ElideRight; text: app.brano ? app.brano.titolo : ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.DemiBold }
            Text { width: parent.width; elide: Text.ElideRight; text: app.brano ? app.brano.artista : ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }
        }
        MouseArea { anchors.fill: parent; onClicked: app.grande = true }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
            spacing: 18
            Text { text: app.suona ? "❚❚" : "▶"; color: tel.pal.testo; font.pixelSize: 22; MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: app.suona ? lettore.pause() : (lettore.source != "" ? lettore.play() : app.suonaIndice(app.attuale)) } }
            Text { text: "⏭"; color: tel.pal.testo; font.pixelSize: 22; MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: app.suonaIndice(app.attuale + 1) } }
        }
    }

    // ══ In ascolto ═══════════════════════════════════════════════════════
    Rectangle {
        anchors.fill: parent
        visible: app.grande && app.brano !== null
        color: app.color
        MouseArea { anchors.fill: parent }
        Text {
            x: 18; y: 58
            text: "⌄"; color: tel.pal.testo; font.pixelSize: 30
            MouseArea { anchors.fill: parent; anchors.margins: -12; onClicked: app.grande = false }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter; y: 120
            width: parent.width - 80; height: width; radius: 28
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.hsla((app.attuale * 0.13) % 1, 0.6, 0.55, 1) }
                GradientStop { position: 1; color: Qt.hsla((app.attuale * 0.13 + 0.15) % 1, 0.6, 0.35, 1) }
            }
            Text { anchors.centerIn: parent; text: "♪"; color: "#ffffff"; font.pixelSize: 96 }
        }
        Column {
            x: 40; width: parent.width - 80; y: 140 + parent.width - 80
            spacing: 6
            Text { width: parent.width; elide: Text.ElideRight; text: app.brano ? app.brano.titolo : ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(22); font.weight: Font.Bold }
            Text { width: parent.width; elide: Text.ElideRight; text: app.brano ? app.brano.artista : ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(16) }
            Item { width: 1; height: 10 }
            // Avanzamento (si può toccare per spostarsi)
            Rectangle {
                width: parent.width; height: 6; radius: 3; color: tel.pal.traccia
                Rectangle { width: lettore.duration > 0 ? parent.width * lettore.position / lettore.duration : 0; height: 6; radius: 3; color: tel.pal.testo }
                MouseArea { anchors.fill: parent; anchors.margins: -12; onClicked: function (m) { if (lettore.duration > 0) lettore.position = lettore.duration * Math.max(0, Math.min(1, (m.x - 12) / parent.width)) } }
            }
            Item {
                width: parent.width; height: 18
                Text { text: app.tempo(lettore.position); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }
                Text { anchors.right: parent.right; text: app.tempo(lettore.duration); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 48
                Text { text: "⏮"; color: tel.pal.testo; font.pixelSize: 34; MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: lettore.position > 3000 ? lettore.position = 0 : app.suonaIndice(app.attuale - 1) } }
                Text { text: app.suona ? "❚❚" : "▶"; color: tel.pal.testo; font.pixelSize: 44; MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: app.suona ? lettore.pause() : (lettore.source != "" ? lettore.play() : app.suonaIndice(app.attuale)) } }
                Text { text: "⏭"; color: tel.pal.testo; font.pixelSize: 34; MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: app.suonaIndice(app.attuale + 1) } }
            }
        }
    }
}
