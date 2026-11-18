// Icona di un'app: la tessera a colori (le app di SolidOS) o l'icona dell'app dello Store,
// con il nome sotto e un puntino quando c'è qualcosa di nuovo.
import QtQuick
import SolidUI

Item {
    id: ic
    property var app: ({})
    property bool conNome: true
    property int lato: tel.latoIcona
    property int ritardo: 0      // entrata scaglionata: ogni icona parte un po' dopo la precedente
    property bool pieno: false        // (non più usato: resta per compatibilità)
    property bool suSfondo: true      // nome sopra lo sfondo (Home) o dentro un pannello
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

    Item {
        id: tessera
        anchors.horizontalCenter: parent.horizontalCenter
        width: ic.lato; height: ic.lato
        // Pressione: 94%, risposta immediata
        scale: area.pressed ? 0.94 : 1
        opacity: area.pressed ? 0.85 : 1
        Behavior on scale { NumberAnimation { duration: tel.tVeloce; easing.type: Easing.OutQuad } }
        Behavior on opacity { NumberAnimation { duration: tel.tVeloce } }
        Icona { anchors.fill: parent; nome: ic.nomeIcona; lato: ic.lato }
        Rectangle {
            visible: ic.nuovo
            anchors.right: parent.right; anchors.top: parent.top; anchors.rightMargin: -4; anchors.topMargin: -4
            width: 16; height: 16; radius: 8; color: tel.rosso
            border.width: 2; border.color: tel.chiaro ? "#FFFFFF" : "#1E1F24"
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
        color: ic.suSfondo ? (tel.chiaro ? "#1D1D1F" : "#FFFFFF") : tel.pal.testo
        style: ic.suSfondo && !tel.chiaro ? Text.Raised : Text.Normal; styleColor: "#55000000"
        font.family: Tema.font; font.pixelSize: tel.px(12); font.weight: Font.Medium
    }
    MouseArea { id: area; anchors.fill: parent; onClicked: tel.apri(ic.app) }
}
