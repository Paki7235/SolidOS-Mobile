// Una notifica in vetro: icona dell'app, app e ora, titolo, testo e azioni.
// Toccandola si apre l'app collegata; la × (o scorrendo di lato) la chiude.
import QtQuick
import SolidUI

Vetro {
    id: scheda
    property var n: ({})
    property bool compatta: false
    property bool pieno: false          // banner: fondo quasi pieno per leggerlo su qualsiasi schermata
    color: pieno ? (tel.chiaro ? Qt.rgba(0.98, 0.98, 1, 0.97) : Qt.rgba(0.12, 0.14, 0.2, 0.97)) : tel.pal.vetro
    width: parent ? parent.width : 300
    height: contenuto.implicitHeight + 24
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

    Row {
        id: contenuto
        x: 14; y: 12
        width: parent.width - 28
        spacing: 12
        Icona { nome: scheda.n.icona || "dialog-information"; lato: 36 }
        Column {
            width: parent.width - 48 - (chiudi.visible ? 24 : 0)
            spacing: 2
            Item {
                width: parent.width; height: app.implicitHeight
                Text { id: app; text: scheda.n.app || ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12); font.weight: Font.DemiBold; width: parent.width - 50; elide: Text.ElideRight }
                Text { anchors.right: parent.right; text: scheda.n.ora || ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }
            }
            Text { width: parent.width; text: scheda.n.titolo || ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.DemiBold; elide: Text.ElideRight }
            Text { width: parent.width; visible: text !== ""; text: scheda.n.testo || ""; textFormat: Text.PlainText; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(14); wrapMode: Text.Wrap; maximumLineCount: scheda.compatta ? 2 : 4; elide: Text.ElideRight }
            Row {
                visible: !scheda.compatta && (scheda.n.azioni || []).filter(function (a) { return a.chiave.indexOf("apri:") !== 0 }).length > 0
                spacing: 8; topPadding: 6
                Repeater {
                    model: (scheda.n.azioni || []).filter(function (a) { return a.chiave.indexOf("apri:") !== 0 })
                    Rectangle {
                        required property var modelData
                        height: 30; width: testoAz.implicitWidth + 22; radius: 10
                        color: tel.pal.traccia
                        Text { id: testoAz; anchors.centerIn: parent; text: parent.modelData.testo; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                        MouseArea { anchors.fill: parent; onClicked: { ponte.chiama("azioneNotifica", [scheda.n.id, parent.modelData.chiave]); tel.chiudiNotifica(scheda.n.id) } }
                    }
                }
            }
        }
    }
    MouseArea { anchors.fill: parent; onClicked: scheda.apri() }
    DragHandler {
        id: trascina
        target: null
        yAxis.enabled: false
        onActiveChanged: if (!active && Math.abs(translation.x) > scheda.width * 0.35) tel.chiudiNotifica(scheda.n.id)
    }
    Text {
        id: chiudi
        visible: !scheda.compatta
        anchors.right: parent.right; anchors.rightMargin: 12; anchors.top: parent.top; anchors.topMargin: 8
        text: "×"; color: tel.pal.testo2; font.pixelSize: 20
        MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: tel.chiudiNotifica(scheda.n.id) }
    }
}
