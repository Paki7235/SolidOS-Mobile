// Icona di un'app nello stile «Essenziale»: un tondo con il disegno a linea (le app di SolidOS)
// o con l'icona dell'app (quelle dello Store), il nome sotto. «pieno»: tondo bianco (Dock).
import QtQuick
import SolidUI

Item {
    id: ic
    property var app: ({})
    property bool conNome: true
    property int lato: tel.latoIcona
    property int ritardo: 0      // entrata scaglionata: ogni icona parte un po' dopo la precedente
    property bool pieno: false
    property bool nuovo: false        // puntino rosso: c'è qualcosa di nuovo
    readonly property string nomeIcona: app.icona || "application-x-executable"
    readonly property bool propria: nomeIcona.indexOf("nucleo-") === 0
    transform: Translate { id: spinta }
    // Quando si entra nella Home le icone salgono di poco e appaiono una dopo l'altra, senza rimbalzi
    Connections { target: tel; function onEntrataChanged() { if (tel.movimento) entrata.restart() } }
    SequentialAnimation {
        id: entrata
        PropertyAction { target: ic; property: "opacity"; value: 0 }
        PropertyAction { target: spinta; property: "y"; value: 12 }
        PauseAnimation { duration: ic.ritardo }
        ParallelAnimation {
            NumberAnimation { target: ic; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutQuad }
            NumberAnimation { target: spinta; property: "y"; to: 0; duration: 380; easing.type: Easing.OutQuint }
        }
    }
    width: lato + 24
    height: lato + (conNome ? 26 : 0)

    Rectangle {
        id: tessera
        anchors.horizontalCenter: parent.horizontalCenter
        width: ic.lato; height: ic.lato; radius: ic.lato / 2
        color: ic.pieno ? tel.pal.pieno : tel.pal.superficie2
        // Pressione: 94%, risposta immediata
        scale: area.pressed ? 0.94 : 1
        Behavior on scale { NumberAnimation { duration: tel.tVeloce; easing.type: Easing.OutQuad } }
        Icona {
            anchors.centerIn: parent
            nome: ic.propria ? "linea-" + ic.nomeIcona.substring(7) : ic.nomeIcona
            lato: Math.round(ic.lato * (ic.propria ? 0.42 : 0.6))
            tema: ic.pieno ? (tel.chiaro ? "scuro" : "chiaro") : ""
        }
        Rectangle {
            visible: ic.nuovo
            anchors.right: parent.right; anchors.top: parent.top
            width: 14; height: 14; radius: 7; color: tel.rosso
            border.width: 2; border.color: tel.pal.sfondo
        }
    }
    Text {
        visible: ic.conNome
        anchors.top: tessera.bottom; anchors.topMargin: 7
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width + 6
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: ic.app.nome || ""
        color: tel.pal.testo; opacity: 0.82
        font.family: Tema.font; font.pixelSize: tel.px(12); font.weight: Font.Medium
    }
    MouseArea { id: area; anchors.fill: parent; onClicked: tel.apri(ic.app) }
}
