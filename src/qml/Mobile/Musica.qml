// Musica: brani della cartella Musica (titolo e artista dal nome del file o dalla
// cartella), riproduzione con QtMultimedia, mini lettore in basso e schermata «In ascolto».
import QtQuick
import QtMultimedia
import SolidUI

Rectangle {
    id: app
    color: tel.pal.sfondo
    property var brani: []
    property int attuale: -1
    property bool grande: false
    readonly property var brano: attuale >= 0 ? brani[attuale] : null
    readonly property color sezione: tel.pal.superficie
    readonly property color linea: tel.pal.bordo
    readonly property bool suona: lettore !== null && lettore.playbackState === MediaPlayer.PlayingState

    function aggiorna() { brani = ponte.chiama0("musica") }
    function suonaIndice(i) {
        if (i < 0 || i >= brani.length) return
        attuale = i
        if (!brani[i].uri) { tel.avviso(I18n.t("Brano di esempio: aggiungi la tua musica nella cartella Musica")); return }
        var l = lettoreAttivo()
        l.source = brani[i].uri
        l.play()
    }
    function suonaFile(percorso) {
        aggiorna()
        for (var i = 0; i < brani.length; i++) if (brani[i].percorso === percorso) { suonaIndice(i); grande = true; return }
    }
    function tempo(ms) { var s = Math.floor(ms / 1000); return Math.floor(s / 60) + ":" + ("0" + s % 60).slice(-2) }
    onVisibleChanged: if (visible) aggiorna()
    Component.onCompleted: { aggiorna(); if (tel.branoDaSuonare) { suonaFile(tel.branoDaSuonare); tel.branoDaSuonare = "" } }
    Connections { target: tel; function onBranoDaSuonareChanged() { if (tel.branoDaSuonare) { app.suonaFile(tel.branoDaSuonare); tel.branoDaSuonare = "" } } }

    // Il lettore nasce solo al primo Play: senza scheda audio non blocca l'interfaccia
    Loader {
        id: motore
        active: false
        sourceComponent: MediaPlayer {
            audioOutput: AudioOutput {}
            onMediaStatusChanged: if (mediaStatus === MediaPlayer.EndOfMedia) app.suonaIndice(app.attuale + 1)
            onErrorOccurred: function (errore, testo) { tel.avviso(I18n.t("Impossibile riprodurre il brano")) }
        }
    }
    readonly property var lettore: motore.item
    readonly property real posizione: lettore ? lettore.position : 0
    readonly property real durata: lettore ? lettore.duration : 0
    function lettoreAttivo() { motore.active = true; return motore.item }
    function playPausa() {
        if (suona) lettore.pause()
        else if (lettore && lettore.source != "") lettore.play()
        else suonaIndice(attuale)
    }

    // ══ Elenco ═══════════════════════════════════════════════════════════
    Punti { x: 20; y: 60; text: I18n.t("Musica").toUpperCase(); font.pixelSize: 36 }
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
                width: 46; height: 46; radius: 14
                color: index === app.attuale ? tel.pal.pieno : tel.pal.superficie2
                Icona { anchors.centerIn: parent; nome: "linea-musica"; lato: 20; tema: index === app.attuale ? (tel.chiaro ? "scuro" : "chiaro") : "" }
            }
            Column {
                x: 58; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 64; spacing: 2
                Text { width: parent.width; elide: Text.ElideRight; text: modelData.titolo; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: index === app.attuale ? Font.DemiBold : Font.Normal }
                Text { width: parent.width; elide: Text.ElideRight; text: modelData.artista.toUpperCase(); color: tel.pal.testo2; font.family: tel.fontMono; font.pixelSize: tel.px(11) }
            }
            Rectangle { anchors.bottom: parent.bottom; x: 58; width: parent.width - 58; height: 1; color: app.linea }
            MouseArea { anchors.fill: parent; onClicked: app.suonaIndice(index) }
        }
    }
    Column {
        visible: app.brani.length === 0
        anchors.centerIn: parent; spacing: 10
        Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: "linea-musica"; lato: 44; opacity: 0.6 }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Nessun brano"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(18); font.weight: Font.DemiBold }
        Text { width: app.width - 80; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: I18n.t("Copia la tua musica nella cartella Musica (con Vicina o la microSD)"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(14) }
    }

    // ══ Mini lettore ═════════════════════════════════════════════════════
    Rectangle {
        visible: app.brano !== null && !app.grande
        x: 12; width: parent.width - 24; height: 70; radius: 24
        anchors.bottom: parent.bottom; anchors.bottomMargin: 32
        color: app.sezione
        border.width: 1; border.color: tel.pal.bordo
        Column {
            x: 16; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 120; spacing: 2
            Text { width: parent.width; elide: Text.ElideRight; text: app.brano ? app.brano.titolo : ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.DemiBold }
            Text { width: parent.width; elide: Text.ElideRight; text: app.brano ? app.brano.artista : ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }
        }
        MouseArea { anchors.fill: parent; onClicked: app.grande = true }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
            spacing: 18
            TastoTondo { lato: 42; pieno: true; icona: app.suona ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"; onTocco: app.playPausa() }
            TastoTondo { lato: 42; icona: "media-skip-forward-symbolic"; color: "transparent"; onTocco: app.suonaIndice(app.attuale + 1) }
        }
    }

    // ══ In ascolto ═══════════════════════════════════════════════════════
    Rectangle {
        anchors.fill: parent
        visible: app.grande && app.brano !== null
        color: app.color
        MouseArea { anchors.fill: parent }
        TastoTondo { x: 18; y: 58; lato: 40; icona: "go-up-symbolic"; rotation: 180; onTocco: app.grande = false }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter; y: 120
            width: parent.width - 80; height: width; radius: 32
            color: tel.pal.superficie
            border.width: 1; border.color: tel.pal.bordo
            // Copertina «Essenziale»: numero del brano a puntini e un'onda di barrette che si muove
            Mono { x: 20; y: 20; text: I18n.t("Brano") }
            Punti { x: 20; y: 38; text: ("0" + (app.attuale + 1)).slice(-2); font.pixelSize: 64 }
            Row {
                anchors.bottom: parent.bottom; anchors.bottomMargin: 28; anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5
                Repeater {
                    model: 24
                    Rectangle {
                        required property int index
                        anchors.bottom: parent.bottom
                        width: 5; radius: 2.5; color: tel.pal.testo
                        property real base: 12 + Math.abs(Math.sin(index * 1.7)) * 70
                        height: base
                        SequentialAnimation on height {
                            running: app.suona && tel.movimento && app.grande; loops: Animation.Infinite
                            NumberAnimation { to: 10 + Math.abs(Math.sin(index * 2.3)) * 80; duration: 380 + (index % 5) * 60; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 12 + Math.abs(Math.sin(index * 1.7)) * 70; duration: 380 + (index % 4) * 70; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
        }
        Column {
            x: 40; width: parent.width - 80; y: 140 + parent.width - 80
            spacing: 6
            Text { width: parent.width; elide: Text.ElideRight; text: app.brano ? app.brano.titolo : ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(24); font.weight: Font.DemiBold }
            Text { width: parent.width; elide: Text.ElideRight; text: app.brano ? app.brano.artista : ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(16) }
            Item { width: 1; height: 10 }
            // Avanzamento (si può toccare per spostarsi)
            Rectangle {
                width: parent.width; height: 6; radius: 3; color: tel.pal.traccia
                Rectangle { width: app.durata > 0 ? parent.width * app.posizione / app.durata : 0; height: 6; radius: 3; color: tel.rosso }
                MouseArea { anchors.fill: parent; anchors.margins: -12; onClicked: function (m) { if (app.durata > 0) app.lettore.position = app.durata * Math.max(0, Math.min(1, (m.x - 12) / parent.width)) } }
            }
            Item {
                width: parent.width; height: 18
                Text { text: app.tempo(app.posizione); color: tel.pal.testo2; font.family: tel.fontMono; font.pixelSize: tel.px(11) }
                Text { anchors.right: parent.right; text: app.tempo(app.durata); color: tel.pal.testo2; font.family: tel.fontMono; font.pixelSize: tel.px(11) }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 36
                TastoTondo { anchors.verticalCenter: parent.verticalCenter; lato: 56; icona: "media-skip-backward-symbolic"; color: "transparent"; onTocco: app.posizione > 3000 ? app.lettore.position = 0 : app.suonaIndice(app.attuale - 1) }
                TastoTondo { anchors.verticalCenter: parent.verticalCenter; lato: 76; pieno: true; icona: app.suona ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"; onTocco: app.playPausa() }
                TastoTondo { anchors.verticalCenter: parent.verticalCenter; lato: 56; icona: "media-skip-forward-symbolic"; color: "transparent"; onTocco: app.suonaIndice(app.attuale + 1) }
            }
        }
    }
}
