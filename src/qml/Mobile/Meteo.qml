// Meteo del telefono: stessa logica del PC (nucleo/apps/meteo.py, dati Open-Meteo).
// In alto la città con i gradi grandi su uno sfondo che cambia col tempo e col giorno/notte,
// poi le prossime 24 ore, i prossimi 10 giorni con la barra delle temperature e i riquadri
// (percepita, umidità, vento, UV, alba e tramonto, qualità dell'aria). Le città salvate
// scorrono di lato (la prima è «La mia posizione»); + per cercarne e aggiungerne una.
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: app
    property var luoghi: []
    property int scelto: 0
    property var dati: ({})
    property bool cerca: false
    property var trovate: []
    readonly property var luogo: luoghi.length ? luoghi[Math.min(scelto, luoghi.length - 1)] : null
    function pc(m, a) { return ponte.chiama("appPc", ["meteo", m, a || []]) }
    function carica() {
        var qui = pc("qui")
        luoghi = (qui && qui.lat !== undefined ? [Object.assign({ qui: true }, qui)] : []).concat(pc("luoghi") || [])
        if (!luoghi.length) luoghi = [{ nome: "Roma", lat: 41.9, lon: 12.5 }]
        apri(Math.min(scelto, luoghi.length - 1))
    }
    function apri(i) {
        scelto = i
        var l = luoghi[i]
        if (l) ponte.avvia("appPc", ["meteo", "previsioni", [l.lat, l.lon, l.nome]], "meteo-prev")
    }
    onVisibleChanged: if (visible && !luoghi.length) carica()
    Component.onCompleted: carica()
    Connections {
        target: ponte
        function onCompletato(id, r) {
            if (id === "meteo-prev") app.dati = r || {}
            else if (id === "meteo-cerca") app.trovate = r || []
        }
    }
    // Colori dello sfondo secondo il tempo (come sul PC)
    readonly property bool notte: !!dati.ok && !dati.giorno
    readonly property var sfondo: !dati.ok ? ["#4A8BFF", "#2753C9"]
        : notte ? ["#1E2552", "#0B1030"]
        : (["pioggia", "temporale", "neve"].indexOf(dati.simbolo) >= 0 ? ["#5B6B82", "#2F3A4D"]
        : (dati.simbolo === "nuvola" || dati.simbolo === "nebbia" ? ["#6F8FB8", "#3F5F8F"] : ["#4FA3FF", "#2563EB"]))
    gradient: Gradient { GradientStop { position: 0; color: app.sfondo[0] } GradientStop { position: 1; color: app.sfondo[1] } }
    readonly property color vetro: Qt.rgba(1, 1, 1, 0.14)
    component Riquadro: Rectangle {
        property string titolo: ""
        property string valore: ""
        property string nota: ""
        property string simbolo: ""
        width: (app.width - 32 - 10) / 2; height: 112; radius: 22; color: app.vetro
        Row { x: 14; y: 12; spacing: 6
              Icona { nome: "linea-" + parent.parent.simbolo; lato: 14; colore: "#B3FFFFFF"; anchors.verticalCenter: parent.verticalCenter }
              Text { text: parent.parent.titolo.toUpperCase(); color: "#B3FFFFFF"; font.family: Tema.font; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 0.5 } }
        Text { x: 14; y: 34; text: parent.valore; color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: 30; font.weight: Font.Medium }
        Text { x: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 12; width: parent.width - 28; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
               text: parent.nota; color: "#E6FFFFFF"; font.family: Tema.font; font.pixelSize: 12 }
    }

    Flickable {
        anchors.fill: parent; anchors.topMargin: 44
        contentHeight: col.height + 60; clip: true
        Column {
            id: col
            width: parent.width; spacing: 12
            // Città, gradi, descrizione
            Item {
                width: parent.width; height: 230
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter; y: 26; spacing: 0
                    Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 6
                          Icona { visible: !!app.luogo && app.luogo.qui === true; nome: "linea-naviga"; lato: 14; colore: "#FFFFFF"; anchors.verticalCenter: parent.verticalCenter }
                          Text { text: app.luogo ? app.luogo.nome : ""; color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: 30; font.weight: Font.Medium } }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: app.dati.ok ? app.dati.gradi + "°" : "—"; color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: 96; font.weight: Font.ExtraLight }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: app.dati.descrizione || (app.dati.ok === false ? (app.dati.messaggio || I18n.t("Meteo non disponibile")) : I18n.t("Carico…")); color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: 18; font.weight: Font.Medium }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; visible: !!app.dati.ok; text: I18n.t("Max") + " " + app.dati.max + "°  " + I18n.t("Min") + " " + app.dati.min + "°"; color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: 16 }
                }
                TastoTondo { anchors.right: parent.right; anchors.rightMargin: 16; y: 8; icona: "linea-piu"; color: app.vetro; temaIcona: "scuro"; onTocco: { app.cerca = true; campoCerca.text = ""; app.trovate = [] } }
            }
            // Puntini delle città (scorri di lato sulla parte alta per cambiare)
            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 7; visible: app.luoghi.length > 1
                Repeater { model: app.luoghi.length
                           Rectangle { required property int index; width: 8; height: 8; radius: 4; color: "#FFFFFF"; opacity: index === app.scelto ? 1 : 0.4
                                       MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: app.apri(parent.index) } } }
            }
            // Prossime ore
            Rectangle {
                visible: !!app.dati.ok
                x: 16; width: parent.width - 32; height: 130; radius: 22; color: app.vetro
                Text { x: 14; y: 12; text: I18n.t("PROSSIME ORE"); color: "#B3FFFFFF"; font.family: Tema.font; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 0.5 }
                ListView {
                    x: 6; y: 36; width: parent.width - 12; height: 86
                    orientation: ListView.Horizontal; clip: true
                    model: app.dati.ore || []
                    delegate: Column {
                        required property var modelData
                        width: 56; spacing: 6
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.ora; color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                        Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: "linea-" + modelData.simbolo; lato: 22; colore: modelData.simbolo === "sole" ? "#FDE047" : "#FFFFFF" }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.gradi + "°"; color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.DemiBold }
                    }
                }
            }
            // Prossimi giorni con la barra delle temperature
            Rectangle {
                visible: !!app.dati.ok
                x: 16; width: parent.width - 32; height: giorni.height + 48; radius: 22; color: app.vetro
                Text { x: 14; y: 12; text: I18n.t("PROSSIMI 10 GIORNI"); color: "#B3FFFFFF"; font.family: Tema.font; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 0.5 }
                Column {
                    id: giorni
                    x: 14; y: 38; width: parent.width - 28
                    Repeater {
                        model: app.dati.giorni || []
                        Item {
                            required property var modelData
                            width: giorni.width; height: 44
                            readonly property real scala: Math.max(1, app.dati.scalaMax - app.dati.scalaMin)
                            Text { width: 54; anchors.verticalCenter: parent.verticalCenter; text: modelData.giorno; color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.DemiBold }
                            Icona { x: 58; anchors.verticalCenter: parent.verticalCenter; nome: "linea-" + modelData.simbolo; lato: 22; colore: modelData.simbolo === "sole" ? "#FDE047" : "#FFFFFF" }
                            Text { x: 86; width: 34; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter; text: modelData.min + "°"; color: "#B3FFFFFF"; font.family: Tema.font; font.pixelSize: 16 }
                            Rectangle {
                                id: traccia
                                x: 128; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 128 - 44; height: 5; radius: 3; color: "#33FFFFFF"
                                Rectangle {
                                    x: traccia.width * (modelData.min - app.dati.scalaMin) / parent.parent.scala
                                    width: Math.max(6, traccia.width * (modelData.max - modelData.min) / parent.parent.scala); height: 5; radius: 3
                                    gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: "#7DD3FC" } GradientStop { position: 1; color: "#FDBA74" } }
                                }
                            }
                            Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: modelData.max + "°"; color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.DemiBold }
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#1FFFFFFF" }
                        }
                    }
                }
            }
            // Riquadri dei dettagli
            Flow {
                visible: !!app.dati.ok
                x: 16; width: parent.width - 32; spacing: 10
                Riquadro { titolo: I18n.t("Percepita"); simbolo: "termometro"; valore: app.dati.percepita + "°"; nota: app.dati.percepita < app.dati.gradi ? I18n.t("Il vento la fa sembrare più fredda") : I18n.t("Simile alla temperatura vera") }
                Riquadro { titolo: I18n.t("Umidità"); simbolo: "goccia"; valore: app.dati.umidita + "%"; nota: I18n.t("Pioggia") + ": " + app.dati.precipitazioni + " mm" }
                Riquadro { titolo: I18n.t("Vento"); simbolo: "vento"; valore: app.dati.vento + " km/h"; nota: I18n.t("Da") + " " + (app.dati.direzioneVento || "") }
                Riquadro { titolo: "UV"; simbolo: "sole"; valore: String(app.dati.uv); nota: app.dati.giudizioUv || "" }
                Riquadro { titolo: I18n.t("Alba"); simbolo: "alba"; valore: app.dati.alba || ""; nota: I18n.t("Tramonto") + ": " + (app.dati.tramonto || "") }
                Riquadro { titolo: I18n.t("Aria"); simbolo: "foglia"; valore: app.dati.aria ? String(app.dati.aria.indice) : "—"; nota: app.dati.aria ? app.dati.aria.giudizio : "" }
            }
            Text { visible: !!app.dati.ok; anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Aggiornato alle") + " " + (app.dati.aggiornato || "") + " · Open-Meteo"; color: "#B3FFFFFF"; font.family: Tema.font; font.pixelSize: 12 }
            // Togli la città (non la posizione attuale)
            Text {
                visible: !!app.luogo && !app.luogo.qui && app.luoghi.length > 1
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.t("Togli") + " " + (app.luogo ? app.luogo.nome : ""); color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.DemiBold
                MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: { app.pc("togli", [app.luogo.lat, app.luogo.lon]); app.scelto = 0; app.carica() } }
            }
        }
        // Scorri di lato per cambiare città
        DragHandler {
            target: null; yAxis.enabled: false
            onActiveChanged: if (!active) {
                if (translation.x < -60 && app.scelto < app.luoghi.length - 1) app.apri(app.scelto + 1)
                else if (translation.x > 60 && app.scelto > 0) app.apri(app.scelto - 1)
            }
        }
    }

    // ── Cerca una città ──────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent; visible: app.cerca; color: tel.pal.sfondo
        MouseArea { anchors.fill: parent }
        Punti { x: 20; y: 60; text: I18n.t("Aggiungi una città") }
        Text { anchors.right: parent.right; anchors.rightMargin: 20; y: 72; text: I18n.t("Fine"); color: tel.accento; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.DemiBold
               MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: app.cerca = false } }
        CampoCerca { id: campoCerca; x: 16; y: 118; width: parent.width - 32
                     onTextChanged: if (text.length >= 2) ponte.avvia("appPc", ["meteo", "cerca", [text]], "meteo-cerca") }
        Column {
            x: 16; y: 176; width: parent.width - 32
            Repeater {
                model: app.trovate
                Item {
                    required property var modelData
                    width: parent.width; height: 58
                    Column { anchors.verticalCenter: parent.verticalCenter
                             Text { text: modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 17; font.weight: Font.DemiBold }
                             Text { text: modelData.regione || ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 13 } }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: tel.pal.bordo }
                    MouseArea { anchors.fill: parent; onClicked: { app.pc("salva", [modelData]); app.cerca = false; app.carica(); app.apri(app.luoghi.length - 1) } }
                }
            }
        }
    }
}
