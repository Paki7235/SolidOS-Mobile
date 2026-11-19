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
    property string stileForzato: ""      // anteprime in Personalizza
    readonly property string stile: stileForzato || tel.imp.stile_icone || "vetro"
    readonly property bool altroStile: propria && stile !== "colori"
    // Colore del simbolo nello stile «Scure» (lo stesso della tessera a colori)
    // Colore del simbolo nello stile «Vetro liquido» (vivo, si vede sul vetro)
    readonly property var coloriVetro: ({ telefono: "#34C759", messaggi: "#0A84FF", contatti: "#FF9500", fotocamera: "#D1D1D6", foto: "#FF6B6B",
                                          musica: "#FF375F", note: "#FFCC00", file: "#0A84FF", dove: "#30C4A8", store: "#A08CFF",
                                          vicina: "#32D2E6", calcolatrice: "#FF9F0A", impostazioni: "#D1D1D6" })
    readonly property var colori: ({ telefono: "#4ADE80", messaggi: "#60A5FA", contatti: "#FCD34D", fotocamera: "#D4D4D8", foto: "#FDBA74",
                                     musica: "#FB7185", note: "#FDE68A", file: "#7DD3FC", dove: "#5EEAD4", store: "#C4B5FD",
                                     vicina: "#67E8F9", calcolatrice: "#FB923C", impostazioni: "#D4D4D8" })
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
        Icona { anchors.fill: parent; visible: !ic.altroStile; nome: ic.nomeIcona; lato: ic.lato }
        // Stili «Scure» e «Tinta» (Personalizza › Icone): tessera scura o del colore del tema,
        // con il simbolo a linea colorato o bianco
        // Stile «Vetro liquido» (predefinito): tessera di vetro con il bordo luminoso, il simbolo
        // colorato con un alone, luce in alto e un po' d'ombra in basso
        Item {
            visible: ic.altroStile && ic.stile === "vetro"
            anchors.fill: parent
            readonly property string chiave: ic.nomeIcona.slice(7)
            readonly property color tinta: { var c = ic.coloriVetro[chiave] || "#FFFFFF"; return tel.chiaro && c === "#D1D1D6" ? "#6E6E73" : c }
            Rectangle { anchors.fill: parent; anchors.topMargin: 3; anchors.bottomMargin: -2; radius: width * 0.26; color: tel.chiaro ? "#14000000" : "#40000000" }
            Rectangle {
                id: lastra
                anchors.fill: parent; radius: width * 0.26
                gradient: Gradient {
                    GradientStop { position: 0; color: tel.chiaro ? "#D9FFFFFF" : "#57FFFFFF" }
                    GradientStop { position: 0.55; color: tel.chiaro ? "#99FFFFFF" : "#21FFFFFF" }
                    GradientStop { position: 1; color: tel.chiaro ? "#80F2F2F7" : "#14FFFFFF" }
                }
                border.width: 1; border.color: tel.chiaro ? "#CCFFFFFF" : "#73FFFFFF"
            }
            // ombra interna in basso
            Rectangle {
                anchors.fill: parent; anchors.margins: 1; radius: lastra.radius - 1
                gradient: Gradient { GradientStop { position: 0.6; color: "transparent" } GradientStop { position: 1; color: tel.chiaro ? "#0F000000" : "#2E000000" } }
            }
            // riflesso sul bordo alto
            Rectangle { x: parent.width * 0.18; y: 1.5; width: parent.width * 0.64; height: 1.5; radius: 1; color: "#B3FFFFFF" }
            // alone e simbolo
            Icona { anchors.centerIn: parent; anchors.verticalCenterOffset: 1.5; lato: ic.lato * 0.56; nome: "linea-" + parent.chiave; colore: parent.tinta; opacity: 0.35 }
            Icona { anchors.centerIn: parent; lato: ic.lato * 0.5; nome: "linea-" + parent.chiave; colore: parent.tinta }
        }
        Rectangle {
            visible: ic.altroStile && ic.stile !== "vetro"
            anchors.fill: parent; anchors.margins: ic.lato * 0.03; radius: width * 0.24
            gradient: Gradient {
                GradientStop { position: 0; color: ic.stile === "scure" ? "#2A2B31" : Qt.rgba(tel.accento.r, tel.accento.g, tel.accento.b, 0.62) }
                GradientStop { position: 1; color: ic.stile === "scure" ? "#141418" : Qt.rgba(tel.accento.r * 0.55, tel.accento.g * 0.55, tel.accento.b * 0.55, 0.62) }
            }
            border.width: 1; border.color: "#24FFFFFF"
            Icona {
                anchors.centerIn: parent; lato: ic.lato * 0.5
                nome: "linea-" + ic.nomeIcona.slice(7)
                colore: ic.stile === "scure" ? (ic.colori[ic.nomeIcona.slice(7)] || "#FFFFFF") : "#FFFFFF"
            }
        }
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
