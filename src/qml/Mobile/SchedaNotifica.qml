// Una notifica «Essenziale»: in alto l'app (icona a linea e nome in piccolo) e quando,
// poi il titolo e il testo. Toccandola si apre l'app collegata; la × (o scorrendo di lato)
// la chiude, con la scheda che segue il dito.
import QtQuick
import SolidUI

Vetro {
    id: scheda
    property var n: ({})
    property bool compatta: false
    property bool pieno: false          // banner: sopra qualsiasi schermata, con un'ombra
    readonly property string icona: (n.icona || "dialog-information")
    width: parent ? parent.width : 300
    height: contenuto.implicitHeight + 28
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

    Column {
        id: contenuto
        x: 16; y: 14
        width: parent.width - 32
        spacing: 3
        Item {
            width: parent.width; height: 18
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Icona {
                    anchors.verticalCenter: parent.verticalCenter
                    nome: scheda.icona.indexOf("nucleo-") === 0 ? "linea-" + scheda.icona.substring(7) : scheda.icona
                    lato: 13
                }
                Mono { anchors.verticalCenter: parent.verticalCenter; text: scheda.n.app || ""; width: Math.min(implicitWidth, contenuto.width - 110); elide: Text.ElideRight }
            }
            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Mono { anchors.verticalCenter: parent.verticalCenter; text: scheda.n.ora || "" }
                Text {
                    id: chiudi
                    visible: !scheda.compatta
                    anchors.verticalCenter: parent.verticalCenter
                    text: "×"; color: tel.pal.testo2; font.pixelSize: 20
                    MouseArea { anchors.fill: parent; anchors.margins: -12; onClicked: tel.chiudiNotifica(scheda.n.id) }
                }
            }
        }
        Item { width: 1; height: 3 }
        Text { width: parent.width; text: scheda.n.titolo || ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.DemiBold; elide: Text.ElideRight }
        Text { width: parent.width; visible: text !== ""; text: scheda.n.testo || ""; textFormat: Text.PlainText; color: tel.pal.testo; opacity: 0.72; font.family: Tema.font; font.pixelSize: tel.px(14); wrapMode: Text.Wrap; maximumLineCount: scheda.compatta ? 2 : 4; elide: Text.ElideRight; lineHeight: 1.08 }
        Row {
            visible: !scheda.compatta && (scheda.n.azioni || []).filter(function (a) { return a.chiave.indexOf("apri:") !== 0 }).length > 0
            spacing: 8; topPadding: 8
            Repeater {
                model: (scheda.n.azioni || []).filter(function (a) { return a.chiave.indexOf("apri:") !== 0 })
                Rectangle {
                    required property var modelData
                    height: 34; width: testoAz.implicitWidth + 28; radius: 17
                    color: "transparent"; border.width: 1; border.color: tel.pal.bordo
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
