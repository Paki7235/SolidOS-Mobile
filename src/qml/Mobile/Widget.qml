// Un widget della Home in tre misure: piccolo (mezza riga), medio (riga intera), grande
// (riga intera, alto il doppio). Tipi: oggi, batterie, meteo, musica, foto, note, orologio.
// «anteprima»: nella galleria i dati sono quelli veri ma il widget non si tocca.
import QtQuick
import SolidUI

Item {
    id: w
    property string tipo: "oggi"
    property string misura: "piccolo"
    property bool anteprima: false
    property real cella: 168          // larghezza di un widget piccolo
    property real alto: 160
    width: misura === "piccolo" ? cella : cella * 2 + 14
    height: misura === "grande" ? alto * 2 + 14 : alto
    readonly property bool largo: misura !== "piccolo"
    // Vesti Prisma: ogni widget ha il suo colore pieno; il testo è bianco o scuro di conseguenza
    readonly property var tinte: ({ oggi: "#FF6B4A", batterie: "#141414", musica: "#8B6CFF", note: "#FFD84A", orologio: "#141414" })
    readonly property color tinta: tel.solido && tinte[tipo] ? tinte[tipo] : "transparent"
    readonly property bool suScuro: tel.solido && tinte[tipo] ? tipo !== "note" : !tel.chiaro
    readonly property color t1: suScuro ? "#FFFFFF" : "#141414"
    readonly property color t2: suScuro ? "#BFFFFFFF" : "#99141414"
    readonly property string temaIcone: suScuro ? "scuro" : "chiaro"
    readonly property var nomi: ({ oggi: I18n.t("Calendario"), batterie: I18n.t("Batterie"), meteo: I18n.t("Meteo"), musica: I18n.t("Musica"),
                                   foto: I18n.t("Foto"), note: I18n.t("Note"), orologio: I18n.t("Orologio"), app: I18n.t("App") })
    // Dati (si aggiornano ogni pochi minuti)
    property var meteo: ({})
    property var nota: ({})
    property var ricordo: ({})
    property var orologi: []
    property var dispositivi: []
    property var esterna: ({})          // musica di un'app dello Store (MPRIS)
    readonly property var brano: tel.musica.titolo ? tel.musica : esterna
    Timer { interval: 3000; repeat: true; running: w.visible && w.tipo === "musica" && !w.anteprima && !tel.musica.titolo; triggeredOnStart: true
            onTriggered: ponte.avvia("mpris", [], "w-mpris-" + w) }
    function aggiorna() {
        if (tipo === "meteo") ponte.avvia("meteo", [], "w-meteo-" + w)
        else if (tipo === "note") nota = ponte.chiama0("notaRecente")
        else if (tipo === "foto" && !ricordo.uri) ricordo = ponte.chiama0("fotoRicordo")
        else if (tipo === "orologio") orologi = ponte.chiama0("orologi")
        else if (tipo === "batterie") ponte.avvia("dispositivi", [], "w-disp-" + w)
    }
    Component.onCompleted: aggiorna()
    onTipoChanged: aggiorna()
    Timer { interval: w.tipo === "orologio" ? 30000 : 600000; running: w.visible; repeat: true; onTriggered: w.aggiorna() }
    Connections {
        target: ponte
        function onCompletato(id, r) {
            if (id === "w-meteo-" + w) w.meteo = r
            else if (id === "w-disp-" + w) w.dispositivi = r
            else if (id === "w-mpris-" + w) w.esterna = r || {}
        }
    }
    readonly property int batteria: tel.stato && tel.stato.batteria ? tel.stato.batteria.livello : 100
    readonly property int notifiche: tel.elencoNotifiche ? tel.elencoNotifiche.length : 0
    function iconaMeteo(i, ora) {
        var notte = ora !== undefined ? (ora >= 19 || ora < 6) : (tel.adesso.getHours() >= 19 || tel.adesso.getHours() < 6)
        return "linea-" + (i === "sole" && notte ? "luna" : (i || "nuvola"))
    }

    // ── Oggi / Calendario ───────────────────────────────────────────────
    Vetro {
        visible: w.tipo === "oggi"
        anchors.fill: parent; radius: 24; tinta: w.tinta
        Column {
            x: 16; y: 14; width: (w.largo ? parent.width / 2 : parent.width) - 32
            Text { text: tel.adesso.toLocaleDateString(Qt.locale("it_IT"), "dddd").toUpperCase(); color: tel.solido ? "#FFE0D8" : "#FF6B6B"; font.family: Tema.font; font.pixelSize: tel.px(12); font.weight: Font.Bold; font.letterSpacing: 0.4 }
            Text { text: Qt.formatDate(tel.adesso, "d"); color: w.t1; font.family: Tema.font; font.pixelSize: 50; font.weight: Font.Light; font.letterSpacing: -2 }
        }
        Item {
            x: w.largo ? parent.width / 2 : 16; width: (w.largo ? parent.width / 2 : parent.width) - 32
            anchors.bottom: parent.bottom; anchors.bottomMargin: 14; height: colOggi.height
            Rectangle { width: 3; height: parent.height; radius: 2; color: tel.solido ? "#FFFFFF" : "#FF74A6" }
            Column {
                id: colOggi
                x: 10; width: parent.width - 10
                Text { width: parent.width; elide: Text.ElideRight; color: w.t1; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold
                       text: w.notifiche > 0 ? (tel.elencoNotifiche[0].titolo || "") : tel.adesso.toLocaleDateString(Qt.locale("it_IT"), "MMMM yyyy") }
                Text { width: parent.width; elide: Text.ElideRight; color: w.t2; font.family: Tema.font; font.pixelSize: tel.px(12)
                       text: w.notifiche > 1 ? "+" + (w.notifiche - 1) + " " + I18n.t("notifiche") : (w.notifiche === 1 ? (tel.elencoNotifiche[0].app || "") : I18n.t("Nessun impegno")) }
            }
        }
        MouseArea { anchors.fill: parent; enabled: !w.anteprima && !tel.modificaHome; onPressAndHold: tel.modificaHome = true; onClicked: tel.notifiche = true }
    }

    // ── Batterie ───────────────────────────────────────────────────────
    Vetro {
        visible: w.tipo === "batterie"
        anchors.fill: parent; radius: 24; tinta: w.tinta
        Text { x: 16; y: 14; text: I18n.t("Batterie"); color: w.t2; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 10
            spacing: w.largo ? 26 : 12
            Repeater {
                model: [{ i: "linea-smartphone", l: w.batteria, n: I18n.t("Telefono") }].concat(w.dispositivi.slice(0, w.largo ? 3 : 1).map(function (d) { return { i: "linea-portatile", l: d.batteria, n: d.nome || "" } }))
                Column {
                    required property var modelData
                    spacing: 4
                    Item {
                        width: 56; height: 56
                        Canvas {
                            anchors.fill: parent
                            property real l: parent.parent.modelData.l
                            property color c: l <= 20 ? tel.rosso : (l < 50 ? "#FFB443" : (tel.solido ? "#C6F432" : "#4BE38E"))
                            property color f: w.suScuro ? "#2EFFFFFF" : "#14000000"
                            onLChanged: requestPaint()
                            onFChanged: requestPaint()
                            onPaint: {
                                var g = getContext("2d"); g.reset(); g.lineWidth = 5; g.lineCap = "round"
                                g.strokeStyle = f; g.beginPath(); g.arc(28, 28, 24, 0, 2 * Math.PI); g.stroke()
                                g.strokeStyle = c; g.beginPath(); g.arc(28, 28, 24, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * l / 100); g.stroke()
                            }
                        }
                        Icona { anchors.centerIn: parent; nome: parent.parent.modelData.i; lato: 20; tema: w.temaIcone }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.modelData.l + "%"; color: w.t1; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                    Text { visible: w.misura === "grande"; anchors.horizontalCenter: parent.horizontalCenter; text: parent.modelData.n; color: w.t2; font.family: Tema.font; font.pixelSize: tel.px(11) }
                }
            }
        }
        MouseArea { anchors.fill: parent; enabled: !w.anteprima && !tel.modificaHome; onPressAndHold: tel.modificaHome = true; onClicked: { tel.apri({ "id": "interno:impostazioni" }); impostazioniApp.apri("batteria") } }
    }

    // ── Meteo ──────────────────────────────────────────────────────────
    Rectangle {
        visible: w.tipo === "meteo"
        anchors.fill: parent; radius: 24; clip: true
        gradient: Gradient {
            GradientStop { position: 0; color: tel.solido ? "#8B6CFF" : ((tel.adesso.getHours() >= 19 || tel.adesso.getHours() < 6) ? "#3B4A8C" : "#4A8BFF") }
            GradientStop { position: 1; color: tel.solido ? "#8B6CFF" : ((tel.adesso.getHours() >= 19 || tel.adesso.getHours() < 6) ? "#1E2552" : "#2753C9") }
        }
        Rectangle { visible: tel.solido; x: parent.width - width * 0.72; y: -height * 0.28; width: 120; height: 120; radius: 60; color: "#C6F432" }
        Column {
            x: 16; y: 14; width: parent.width - 32
            Text { width: parent.width; elide: Text.ElideRight; text: (w.meteo.citta || I18n.t("Meteo")) + " ➤"; color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.DemiBold }
            Text { text: w.meteo.ok ? w.meteo.gradi + "°" : "—"; color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: 46; font.weight: Font.Light; font.letterSpacing: -1.5 }
        }
        Column {
            visible: w.meteo.ok === true
            x: w.largo ? parent.width - width - 16 : 16; y: w.largo ? 18 : 0
            anchors.bottom: w.largo ? undefined : parent.bottom; anchors.bottomMargin: 12
            Icona { visible: w.largo || w.height >= 140; anchors.right: w.largo ? parent.right : undefined; nome: w.iconaMeteo(w.meteo.icona); lato: 20; colore: w.meteo.icona === "sole" ? "#FDE047" : "#FFFFFF" }
            Text { anchors.right: w.largo ? parent.right : undefined; text: w.meteo.descrizione || ""; color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(12); font.weight: Font.Medium }
            Text { anchors.right: w.largo ? parent.right : undefined; text: I18n.t("Max") + " " + w.meteo.max + "° " + I18n.t("Min") + " " + w.meteo.min + "°"; color: "#D9FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(12) }
        }
        Text {
            visible: w.meteo.ok === false
            x: 16; anchors.bottom: parent.bottom; anchors.bottomMargin: 14; width: parent.width - 32; wrapMode: Text.Wrap
            text: w.meteo.messaggio || ""; color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(12)
        }
        // Le prossime ore (medio e grande)
        Row {
            visible: w.largo && w.meteo.ok === true
            x: 16; anchors.bottom: parent.bottom; anchors.bottomMargin: 12; width: parent.width - 32
            Repeater {
                model: w.meteo.ore || []
                Column {
                    required property var modelData
                    width: (w.width - 32) / 5; spacing: 3
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.modelData.ora; color: "#D9FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(11); font.weight: Font.DemiBold }
                    Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: w.iconaMeteo(parent.modelData.icona, parseInt(parent.modelData.ora) || tel.adesso.getHours()); lato: 18; tema: "scuro" }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.modelData.gradi + "°"; color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                }
            }
        }
        MouseArea { anchors.fill: parent; enabled: !w.anteprima && !tel.modificaHome; onPressAndHold: tel.modificaHome = true; onClicked: sceltaCitta.open() }
    }

    // ── Musica ─────────────────────────────────────────────────────────
    Vetro {
        visible: w.tipo === "musica"
        anchors.fill: parent; radius: 24; tinta: w.tinta
        Rectangle {
            id: copertina
            x: 14; y: 14
            width: w.misura === "grande" ? parent.width - 28 : parent.height - 28; height: w.misura === "grande" ? parent.height - 120 : parent.height - 28
            radius: 14
            gradient: Gradient { GradientStop { position: 0; color: "#A78BFA" } GradientStop { position: 1; color: "#4C1D95" } }
            visible: w.largo || w.misura === "grande"
            Icona { anchors.centerIn: parent; nome: "linea-musica"; lato: parent.height * 0.3; tema: "scuro"; opacity: 0.8 }
        }
        Column {
            x: w.misura === "medio" ? copertina.width + 28 : 16
            y: w.misura === "grande" ? copertina.height + 24 : (w.largo ? 0 : 16)
            anchors.verticalCenter: w.misura === "medio" ? parent.verticalCenter : undefined
            width: parent.width - x - 16; spacing: 2
            Text { width: parent.width; elide: Text.ElideRight; text: w.brano.titolo || I18n.t("Musica"); color: w.t1; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.DemiBold }
            Text { width: parent.width; elide: Text.ElideRight; text: w.brano.titolo ? (w.brano.artista || w.brano.app || I18n.t("In riproduzione")) : I18n.t("Tocca per scegliere un brano"); color: w.t2; font.family: Tema.font; font.pixelSize: tel.px(12); wrapMode: Text.Wrap; maximumLineCount: 2 }
            Item { width: 1; height: 8 }
            Row {
                spacing: 22
                Repeater {
                    model: [{ i: "linea-indietro", c: "indietro" }, { i: w.brano.suona ? "linea-pausa" : "linea-play", c: "play" }, { i: "linea-avanti", c: "avanti" }]
                    Icona {
                        required property var modelData
                        nome: modelData.i; lato: 22; tema: w.temaIcone
                        MouseArea { anchors.fill: parent; anchors.margins: -10; enabled: !w.anteprima && !tel.modificaHome && !!w.brano.titolo
                                     onClicked: tel.musica.titolo ? tel.comandoMusica(parent.modelData.c) : ponte.chiama("mprisComando", [parent.modelData.c]) }
                    }
                }
            }
        }
        MouseArea { anchors.fill: parent; z: -1; enabled: !w.anteprima && !tel.modificaHome; onPressAndHold: tel.modificaHome = true; onClicked: tel.appInterna = "musica" }
    }

    // ── Foto: un ricordo ─────────────────────────────────────────────────
    Rectangle {
        visible: w.tipo === "foto"
        anchors.fill: parent; radius: 24; clip: true
        gradient: Gradient { GradientStop { position: 0; color: "#FDBA74" } GradientStop { position: 1; color: "#DB2777" } }
        Image { anchors.fill: parent; source: w.ricordo.uri || ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 600 }
        Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0.5; color: "transparent" } GradientStop { position: 1; color: "#80000000" } } }
        Column {
            x: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 12
            Text { text: w.ricordo.titolo || I18n.t("Le tue foto"); color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
            Text { text: w.ricordo.giorno || ""; color: "#D9FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(12) }
        }
        MouseArea { anchors.fill: parent; enabled: !w.anteprima && !tel.modificaHome; onPressAndHold: tel.modificaHome = true; onClicked: tel.appInterna = "foto" }
    }

    // ── Note: l'ultima nota ──────────────────────────────────────────────
    Vetro {
        visible: w.tipo === "note"
        anchors.fill: parent; radius: 24; tinta: w.tinta
        Row {
            x: 16; y: 14; spacing: 6
            Rectangle { width: 10; height: 10; radius: 5; color: "#F59E0B"; anchors.verticalCenter: parent.verticalCenter }
            Text { text: I18n.t("Note"); color: "#F59E0B"; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.Bold }
        }
        Column {
            x: 16; y: 40; width: parent.width - 32
            Text { width: parent.width; elide: Text.ElideRight; text: w.nota.titolo || I18n.t("Nessuna nota"); color: w.t1; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.DemiBold }
            Text { width: parent.width; wrapMode: Text.Wrap; maximumLineCount: w.misura === "grande" ? 12 : 4; elide: Text.ElideRight; text: w.nota.anteprima || ""; color: w.t2; font.family: Tema.font; font.pixelSize: tel.px(12.5) }
        }
        MouseArea { anchors.fill: parent; enabled: !w.anteprima && !tel.modificaHome; onPressAndHold: tel.modificaHome = true; onClicked: tel.appInterna = "note" }
    }

    // ── App: le app dello Store (e le altre) a portata di dito ────────────
    Vetro {
        visible: w.tipo === "app"
        anchors.fill: parent; radius: 24; tinta: w.tinta
        readonly property var scelte: { var t = ponte.chiama0("app"); var est = t.filter(function (a) { return a.id.indexOf("interno:") !== 0 }); return (est.length ? est : t).slice(0, w.misura === "piccolo" ? 4 : (w.misura === "medio" ? 8 : 16)) }
        Grid {
            anchors.centerIn: parent
            columns: w.misura === "piccolo" ? 2 : 4; spacing: w.misura === "piccolo" ? 10 : 14
            Repeater {
                model: parent.parent.scelte
                IconaApp { required property var modelData; app: modelData; conNome: false; lato: w.misura === "piccolo" ? 48 : 52; width: lato; enabled: !w.anteprima && !tel.modificaHome }
            }
        }
    }

    // ── Orologio ─────────────────────────────────────────────────────────
    Vetro {
        visible: w.tipo === "orologio"
        anchors.fill: parent; radius: 24; tinta: w.tinta
        Column {
            x: 16; y: 14
            Text { text: Qt.formatTime(tel.adesso, "HH:mm"); color: w.t1; font.family: tel.fontOra; font.pixelSize: w.largo ? 50 : 42; font.weight: Font.Light; font.letterSpacing: -1 }
            Text { text: tel.adesso.toLocaleDateString(Qt.locale("it_IT"), "ddd d MMMM"); color: w.t2; font.family: Tema.font; font.pixelSize: tel.px(12.5) }
        }
        Column {
            visible: w.largo || w.misura === "grande"
            x: w.misura === "medio" ? parent.width / 2 + 10 : 16
            y: w.misura === "medio" ? 18 : 110
            spacing: 6
            Repeater {
                model: w.orologi
                Row {
                    required property var modelData
                    spacing: 10
                    Text { width: 82; text: parent.modelData.citta; color: w.t2; font.family: Tema.font; font.pixelSize: tel.px(13) }
                    Text { text: parent.modelData.ora; color: w.t1; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.DemiBold }
                }
            }
        }
    }
}
