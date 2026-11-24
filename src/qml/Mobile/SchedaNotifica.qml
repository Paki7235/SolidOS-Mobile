// Una notifica in un pannello di vetro: icona dell'app, titolo e quando, testo e azioni.
// Toccandola si apre l'app collegata; la × (o scorrendo di lato) la chiude, con la scheda
// che segue il dito. «pieno»: il banner che compare sopra le app, su fondo pieno.
import QtQuick
import SolidUI

Vetro {
    id: scheda
    property var n: ({})
    property bool compatta: false
    property bool pieno: false
    sfocato: !pieno
    width: parent ? parent.width : 300
    height: Math.max(66, contenuto.implicitHeight + 26)
    radius: 22
    x: trascina.active ? trascina.translation.x : 0
    opacity: 1 - Math.min(0.8, Math.abs(x) / width)

    function apri() {
        var azioni = scheda.n.azioni || []
        for (var i = 0; i < azioni.length; i++) {
            if (azioni[i].chiave.indexOf("apri:") === 0) { tel.apri({ "id": "interno:" + azioni[i].chiave.slice(5) }); break }
        }
        tel.chiudiNotifica(scheda.n.id)
    }

    // Le icone di SolidOS nella finitura scelta (Piene nelle vesti Prisma); il Vetro qui resta Gemma
    Icona { x: 14; y: 14; lato: 38; tema: "nessuno"
            nome: { var i = scheda.n.icona || "dialog-information"; return i.indexOf("nucleo-") === 0 && tel.stileIcone === "piene" ? "piene-" + i : i } }
    Column {
        id: contenuto
        x: 64; y: 13
        width: parent.width - 64 - 14
        spacing: 1
        Item {
            width: parent.width; height: titolo.implicitHeight
            Text { id: titolo; width: parent.width - quando.implicitWidth - (chiudi.visible ? 30 : 8); elide: Text.ElideRight
                   text: scheda.n.titolo || ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.DemiBold }
            Row {
                anchors.right: parent.right; anchors.verticalCenter: titolo.verticalCenter
                spacing: 10
                Text { id: quando; anchors.verticalCenter: parent.verticalCenter; text: scheda.n.ora || ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }
                Text {
                    id: chiudi
                    visible: !scheda.compatta
                    anchors.verticalCenter: parent.verticalCenter
                    text: "×"; color: tel.pal.testo2; font.pixelSize: 19
                    MouseArea { anchors.fill: parent; anchors.margins: -12; onClicked: tel.chiudiNotifica(scheda.n.id) }
                }
            }
        }
        Text { width: parent.width; visible: text !== ""; text: scheda.n.testo || ""; textFormat: Text.PlainText; color: tel.pal.testo; opacity: 0.82; font.family: Tema.font; font.pixelSize: tel.px(14); wrapMode: Text.Wrap; maximumLineCount: scheda.compatta ? 2 : 4; elide: Text.ElideRight }
        Row {
            visible: !scheda.compatta && (scheda.n.azioni || []).filter(function (a) { return a.chiave.indexOf("apri:") !== 0 }).length > 0
            spacing: 8; topPadding: 8
            Repeater {
                model: (scheda.n.azioni || []).filter(function (a) { return a.chiave.indexOf("apri:") !== 0 })
                Rectangle {
                    required property var modelData
                    height: 32; width: testoAz.implicitWidth + 26; radius: 10
                    color: tel.pal.traccia
                    Text { id: testoAz; anchors.centerIn: parent; text: parent.modelData.testo; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; onClicked: { ponte.chiama("azioneNotifica", [scheda.n.id, parent.modelData.chiave]); tel.chiudiNotifica(scheda.n.id) } }
                }
            }
        }
    }
    MouseArea { anchors.fill: parent; z: -1; onClicked: scheda.apri() }
    DragHandler {
        id: trascina
        target: null
        yAxis.enabled: false
        property real ultimaX: 0
        onTranslationChanged: if (active) ultimaX = translation.x
        onActiveChanged: if (active) ultimaX = 0; else if (Math.abs(ultimaX) > scheda.width * 0.35) tel.chiudiNotifica(scheda.n.id)
    }
}
