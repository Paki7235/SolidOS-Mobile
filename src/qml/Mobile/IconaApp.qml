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
    property bool inHome: false       // sulla Home: tenuta premuta = modifica la Home
    readonly property bool trema: inHome && tel.modificaHome
    readonly property string nomeIcona: app.icona || "application-x-executable"
    readonly property bool propria: nomeIcona.indexOf("nucleo-") === 0
    property string stileForzato: ""      // anteprime in Aspetto
    // Finitura delle icone di SolidOS: gemme (sfumate), piene (colore pieno), vetro (lastra)
    readonly property string stile: stileForzato || tel.stileIcone
    readonly property string file: !propria || stile === "gemme" ? nomeIcona : stile + "-" + nomeIcona
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
        scale: area.pressed && !ic.trema ? 0.94 : 1
        // Home in modifica: le icone tremano un poco
        SequentialAnimation on rotation {
            running: ic.trema && tel.movimento; loops: Animation.Infinite
            NumberAnimation { to: 2; duration: 120 + (ic.ritardo % 40) }
            NumberAnimation { to: -2; duration: 240 }
            NumberAnimation { to: 0; duration: 120 }
            onRunningChanged: if (!running) tessera.rotation = 0
        }
        opacity: area.pressed ? 0.85 : 1
        Behavior on scale { NumberAnimation { duration: tel.tVeloce; easing.type: Easing.OutQuad } }
        Behavior on opacity { NumberAnimation { duration: tel.tVeloce } }
        // Vetro: una lastra chiara sopra lo sfondo, con il simbolo bianco
        Rectangle {
            visible: ic.propria && ic.stile === "vetro"
            anchors.fill: parent; anchors.margins: ic.lato * 0.03; radius: width * 0.3
            gradient: Gradient {
                GradientStop { position: 0; color: tel.chiaro ? "#33141414" : "#40FFFFFF" }
                GradientStop { position: 1; color: tel.chiaro ? "#1F141414" : "#1AFFFFFF" }
            }
            border.width: 1; border.color: tel.chiaro ? "#1F141414" : "#4DFFFFFF"
            Rectangle { x: parent.width * 0.2; y: 1.5; width: parent.width * 0.6; height: 1.5; radius: 1; color: "#80FFFFFF"; visible: !tel.chiaro }
        }
        Icona { anchors.fill: parent; nome: ic.file; lato: ic.lato; tema: "nessuno" }
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
    // «−»: toglie l'app dalla Home (resta nella Libreria)
    Rectangle {
        visible: ic.trema && ic.conNome
        x: tessera.x - 6; y: -6; z: 3
        width: 22; height: 22; radius: 11; color: "#E6505058"; border.width: 1; border.color: "#33FFFFFF"
        Text { anchors.centerIn: parent; anchors.verticalCenterOffset: -1; text: "−"; color: "#FFFFFF"; font.pixelSize: 17; font.bold: true }
    }
    MouseArea {
        id: area; anchors.fill: parent
        onClicked: if (!ic.trema) tel.apri(ic.app)
        onPressAndHold: {
            if (ic.inHome) { tel.modificaHome = true; return }
            // Dalla Libreria: un'app tolta dalla Home ci torna
            var n = (tel.imp.nascoste_home || [])
            if (n.indexOf(ic.app.id) >= 0) { tel.imposta("nascoste_home", n.filter(function (x) { return x !== ic.app.id })); tel.avviso(I18n.t("Aggiunta alla Home")); home.app = ponte.chiama0("home") }
        }
    }
}
