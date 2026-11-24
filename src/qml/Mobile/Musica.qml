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
    Component.onCompleted: {
        aggiorna(); if (tel.branoDaSuonare) { suonaFile(tel.branoDaSuonare); tel.branoDaSuonare = "" }
        if (ponte.chiama0("avvio").schermata === "musica-ascolto" && brani.length) { attuale = 0; grande = true }   // anteprima
    }
    // Per il widget Musica della Home: cosa suona e i comandi dal widget
    Binding { target: tel; property: "musica"; value: ({ titolo: app.brano ? app.brano.titolo : "", artista: app.brano ? (app.brano.artista || "") : "", suona: app.suona }) }
    Connections {
        target: tel
        function onComandoMusica(c) {
            if (c === "play") app.playPausa()
            else if (c === "avanti") app.suonaIndice(app.attuale + 1)
            else if (c === "indietro") app.suonaIndice(Math.max(0, app.attuale - 1))
        }
    }
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
    Punti { x: 20; y: 60; text: I18n.t("Musica"); font.pixelSize: 32 }
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
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.hsla((0.62 + index * 0.11) % 1, 0.65, 0.58, 1) }
                    GradientStop { position: 1; color: Qt.hsla((0.72 + index * 0.11) % 1, 0.6, 0.45, 1) }
                }
                Icona { anchors.centerIn: parent; nome: "linea-musica"; lato: 20; tema: "scuro" }
            }
            Column {
                x: 58; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 64; spacing: 2
                Text { width: parent.width; elide: Text.ElideRight; text: modelData.titolo; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: index === app.attuale ? Font.DemiBold : Font.Normal }
                Text { width: parent.width; elide: Text.ElideRight; text: modelData.artista; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13) }
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
        id: mini
        x: 12; width: parent.width - 24; height: 70; radius: 26
        anchors.bottom: parent.bottom; anchors.bottomMargin: 32
        color: tel.solido ? Qt.hsla(app.tono, 0.7, 0.6, 1) : app.sezione
        border.width: tel.solido ? 0 : 1; border.color: tel.pal.bordo
        readonly property color t1: tel.solido ? "#FFFFFF" : tel.pal.testo
        Column {
            x: 16; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 120; spacing: 2
            Text { width: parent.width; elide: Text.ElideRight; text: app.brano ? app.brano.titolo : ""; color: mini.t1; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.DemiBold }
            Text { width: parent.width; elide: Text.ElideRight; text: app.brano ? app.brano.artista : ""; color: mini.t1; opacity: 0.7; font.family: Tema.font; font.pixelSize: tel.px(12) }
        }
        MouseArea { anchors.fill: parent; onClicked: app.grande = true }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
            spacing: 18
            TastoTondo { lato: 42; pieno: !tel.solido; color: tel.solido ? "#FFFFFF" : tel.accento; temaIcona: tel.solido ? "chiaro" : "scuro"; icona: app.suona ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"; onTocco: app.playPausa() }
            TastoTondo { lato: 42; icona: "media-skip-forward-symbolic"; color: "transparent"; temaIcona: tel.solido ? "scuro" : ""; onTocco: app.suonaIndice(app.attuale + 1) }
        }
    }

    // Colore della copertina del brano: le vesti lo usano come fondo di «In ascolto»
    readonly property real tono: ((0.62 + Math.max(0, attuale) * 0.11) % 1)
    // ══ In ascolto ═══════════════════════════════════════════════════════
    // Aurora: dalla copertina si scende verso la notte. Prisma: il colore della copertina, pieno.
    Rectangle {
        id: ascolto
        anchors.fill: parent
        visible: app.grande && app.brano !== null
        color: Qt.hsla(app.tono, 0.7, 0.6, 1)
        gradient: tel.solido ? null : notteMusica
        Gradient {
            id: notteMusica
            GradientStop { position: 0; color: Qt.hsla(app.tono, 0.75, 0.55, 1) }
            GradientStop { position: 0.55; color: Qt.hsla((app.tono + 0.08) % 1, 0.6, 0.28, 1) }
            GradientStop { position: 1; color: "#120A2E" }
        }
        MouseArea { anchors.fill: parent }
        TastoTondo { x: 18; y: 58; lato: 40; icona: "go-up-symbolic"; rotation: 180; color: "#33FFFFFF"; temaIcona: "scuro"; onTocco: app.grande = false }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter; y: 120
            width: parent.width - 80; height: width; radius: 32
            border.width: 1; border.color: "#33FFFFFF"
            // Copertina: sfumatura colorata con un'onda di barrette che si muove mentre suona
            // In Prisma la copertina prende il colore opposto al fondo, così si stacca
            id: copertinaGrande
            readonly property real tonoCopertina: tel.solido ? (app.tono + 0.5) % 1 : app.tono
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.hsla(copertinaGrande.tonoCopertina, tel.solido ? 0.85 : 0.65, tel.solido ? 0.62 : 0.58, 1) }
                GradientStop { position: 1; color: Qt.hsla((copertinaGrande.tonoCopertina + 0.1) % 1, tel.solido ? 0.85 : 0.6, tel.solido ? 0.55 : 0.4, 1) }
            }
            Icona { x: 22; y: 22; nome: "linea-musica"; lato: 34; tema: "scuro" }
            Row {
                anchors.bottom: parent.bottom; anchors.bottomMargin: 28; anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5
                Repeater {
                    model: 24
                    Rectangle {
                        required property int index
                        anchors.bottom: parent.bottom
                        width: 5; radius: 2.5; color: "#FFFFFF"; opacity: 0.85
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
            Text { width: parent.width; elide: Text.ElideRight; text: app.brano ? app.brano.titolo : ""; color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(26); font.weight: tel.solido ? Font.Black : Font.Bold; font.letterSpacing: -0.6 }
            Text { width: parent.width; elide: Text.ElideRight; text: app.brano ? app.brano.artista : ""; color: "#CCFFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(17) }
            Item { width: 1; height: 10 }
            // Avanzamento (si può toccare per spostarsi)
            Rectangle {
                width: parent.width; height: 6; radius: 3; color: "#40FFFFFF"
                Rectangle { width: app.durata > 0 ? parent.width * app.posizione / app.durata : 0; height: 6; radius: 3; color: "#FFFFFF" }
                MouseArea { anchors.fill: parent; anchors.margins: -12; onClicked: function (m) { if (app.durata > 0) app.lettore.position = app.durata * Math.max(0, Math.min(1, (m.x - 12) / parent.width)) } }
            }
            Item {
                width: parent.width; height: 18
                Text { text: app.tempo(app.posizione); color: "#B3FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(11) }
                Text { anchors.right: parent.right; text: app.tempo(app.durata); color: "#B3FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(11) }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 36
                TastoTondo { anchors.verticalCenter: parent.verticalCenter; lato: 56; icona: "media-skip-backward-symbolic"; color: "transparent"; temaIcona: "scuro"; onTocco: app.posizione > 3000 ? app.lettore.position = 0 : app.suonaIndice(app.attuale - 1) }
                TastoTondo { anchors.verticalCenter: parent.verticalCenter; lato: 76; color: "#FFFFFF"; temaIcona: "chiaro"; icona: app.suona ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"; onTocco: app.playPausa() }
                TastoTondo { anchors.verticalCenter: parent.verticalCenter; lato: 56; icona: "media-skip-forward-symbolic"; color: "transparent"; temaIcona: "scuro"; onTocco: app.suonaIndice(app.attuale + 1) }
            }
        }
    }
}
