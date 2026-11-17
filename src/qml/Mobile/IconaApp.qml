// Icona di un'app: la stessa di SolidOS per PC (tema di icone di sistema), con il nome sotto.
import QtQuick
import SolidUI

Item {
    id: ic
    property var app: ({})
    property bool conNome: true
    property int lato: tel.latoIcona
    property int ritardo: 0      // entrata scaglionata: ogni icona parte un po' dopo la precedente
    transform: Translate { id: spinta }
    // Quando si entra nella Home le icone salgono e appaiono una dopo l'altra (con un piccolo rimbalzo)
    Connections { target: tel; function onEntrataChanged() { if (tel.movimento) entrata.restart() } }
    SequentialAnimation {
        id: entrata
        PropertyAction { target: ic; property: "opacity"; value: 0 }
        PropertyAction { target: spinta; property: "y"; value: 16 }
        PropertyAction { target: ic; property: "scale"; value: 0.92 }
        PauseAnimation { duration: ic.ritardo }
        ParallelAnimation {
            NumberAnimation { target: ic; property: "opacity"; to: 1; duration: 280; easing.type: Easing.OutCubic }
            NumberAnimation { target: spinta; property: "y"; to: 0; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
            NumberAnimation { target: ic; property: "scale"; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
        }
    }
    width: lato + 24
    height: lato + (conNome ? 26 : 0)

    // Le stesse icone di SolidOS per PC, a grandezza piena (come nel Dock del PC)
    Icona {
        id: tessera
        anchors.horizontalCenter: parent.horizontalCenter
        nome: ic.app.icona || "application-x-executable"
        lato: ic.lato
        // Pressione: 97%, risposta immediata (≤ 150 ms)
        scale: area.pressed ? 0.97 : 1
        opacity: area.pressed ? 0.85 : 1
        Behavior on scale { NumberAnimation { duration: tel.tVeloce; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: tel.tVeloce } }
    }
    Text {
        visible: ic.conNome
        anchors.top: tessera.bottom; anchors.topMargin: 7
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width + 6
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: ic.app.nome || ""
        color: tel.pal.testo
        font.family: Tema.font; font.pixelSize: tel.px(12); font.weight: Font.Medium
    }
    MouseArea { id: area; anchors.fill: parent; onClicked: tel.apri(ic.app) }
}
