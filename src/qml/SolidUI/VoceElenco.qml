// Voce di una barra laterale: icona, titolo e sottotitolo; selezionata = sfondo d'accento.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ItemDelegate {
    id: voce
    property string icona: ""
    property url immagine: ""
    property string titolo: ""
    property string sottotitolo: ""
    property bool selezionata: false
    width: parent ? parent.width : 220
    height: sottotitolo ? 42 : 30
    padding: 0
    leftPadding: 8
    rightPadding: 8
    hoverEnabled: true
    background: Rectangle {
        radius: 7
        color: voce.selezionata ? Tema.accento : (voce.hovered ? (Tema.chiaro ? "#0F000000" : "#14FFFFFF") : "transparent")
    }
    contentItem: RowLayout {
        spacing: 9
        Image {
            source: voce.immagine
            visible: voce.immagine != ""
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            sourceSize.width: 44
            sourceSize.height: 44
            smooth: true
        }
        Icona { nome: voce.icona; lato: 20; visible: voce.icona !== "" && voce.immagine == "" }
        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true
            Text { text: voce.titolo; color: voce.selezionata ? "#FFFFFF" : Tema.testo; font.family: Tema.font; font.pixelSize: 13; font.weight: voce.selezionata ? Font.Medium : Font.Normal; elide: Text.ElideRight; Layout.fillWidth: true }
            Text { text: voce.sottotitolo; visible: text !== ""; color: voce.selezionata ? "#DDFFFFFF" : Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
        }
    }
}
