// Schermata della chiamata (in uscita, in arrivo, in corso): nome, stato o durata,
// muto, tastierino, vivavoce, e i tasti per rispondere o chiudere.
import QtQuick
import SolidUI

Rectangle {
    id: ch
    property var info: ({})
    property bool tastierino: false
    property string toni: ""
    gradient: Gradient {
        GradientStop { position: 0.0; color: "#101a3a" }
        GradientStop { position: 1.0; color: "#05070f" }
    }

    component Tasto: Column {
        id: t
        property string icona: ""
        property string testo: ""
        property bool attivo: false
        signal premuto()
        spacing: 8
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 76; height: 76; radius: 38
            color: t.attivo ? "#ffffff" : Qt.rgba(1, 1, 1, 0.16)
            Icona { anchors.centerIn: parent; nome: t.icona; lato: 30 }
            MouseArea { anchors.fill: parent; onClicked: t.premuto() }
        }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: t.testo; color: "#ffffff"; font.family: Tema.font; font.pixelSize: tel.px(13) }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 110
        spacing: 10
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 96; height: 96; radius: 48
            color: tel.accento
            Text { anchors.centerIn: parent; text: (ch.info.nome || "?").charAt(0).toUpperCase(); color: "#ffffff"; font.family: Tema.font; font.pixelSize: 40; font.weight: Font.Bold }
        }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: ch.info.nome || ""; color: "#ffffff"; font.family: Tema.font; font.pixelSize: tel.px(30); font.weight: Font.DemiBold }
        Text { anchors.horizontalCenter: parent.horizontalCenter; visible: ch.info.nome !== ch.info.numero; text: ch.info.numero || ""; color: "#aab4c8"; font.family: Tema.font; font.pixelSize: tel.px(15) }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: ch.tastierino ? ch.toni : (ch.info.testo || ""); color: "#dbe3f5"; font.family: Tema.font; font.pixelSize: tel.px(17) }
    }

    // In corso: comandi
    Grid {
        visible: !ch.info.inArrivo && !ch.tastierino
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.5
        columns: 3; columnSpacing: 30; rowSpacing: 22
        Tasto { icona: "microphone-sensitivity-muted-symbolic"; testo: I18n.t("Muto"); attivo: ch.info.muto === true; onPremuto: ponte.chiama("muto", [!ch.info.muto]) }
        Tasto { icona: "input-dialpad-symbolic"; testo: I18n.t("Tastierino"); onPremuto: ch.tastierino = true }
        Tasto { icona: "audio-speakers-symbolic"; testo: I18n.t("Vivavoce"); attivo: ch.info.vivavoce === true; onPremuto: ponte.chiama("vivavoce", [!ch.info.vivavoce]) }
        Tasto { icona: "list-add-symbolic"; testo: I18n.t("Aggiungi"); onPremuto: tel.avviso(I18n.t("Le chiamate in conferenza arrivano più avanti")) }
        Tasto { icona: "computer-symbolic"; testo: I18n.t("Sul PC"); onPremuto: tel.avviso(I18n.t("Passa la chiamata al PC: arriva con l'ecosistema")) }
        Tasto { icona: "avatar-default-symbolic"; testo: I18n.t("Contatti"); onPremuto: { tel.chiamataRidotta = true } }
    }

    // In corso: tastierino per i toni (menu dei call center)
    Grid {
        visible: ch.tastierino
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.42
        columns: 3; rowSpacing: 14; columnSpacing: 26
        Repeater {
            model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]
            Rectangle {
                required property string modelData
                width: 70; height: 70; radius: 35
                color: Qt.rgba(1, 1, 1, 0.16)
                Text { anchors.centerIn: parent; text: parent.modelData; color: "#ffffff"; font.family: Tema.font; font.pixelSize: 30 }
                MouseArea { anchors.fill: parent; onClicked: { ch.toni += parent.modelData; ponte.chiama("tono", [parent.modelData]) } }
            }
        }
    }
    Text {
        visible: ch.tastierino
        anchors.right: parent.right; anchors.rightMargin: 40
        anchors.verticalCenter: chiudi.verticalCenter
        text: I18n.t("Nascondi"); color: "#ffffff"; font.family: Tema.font; font.pixelSize: tel.px(16)
        MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: ch.tastierino = false }
    }

    // In arrivo: rifiuta / rispondi — In corso: chiudi
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 70
        spacing: 120
        visible: ch.info.inArrivo === true
        Column {
            spacing: 8
            Rectangle { width: 76; height: 76; radius: 38; color: "#ef4444"; Icona { anchors.centerIn: parent; nome: "call-start-symbolic"; lato: 32; rotation: 135 }
                MouseArea { anchors.fill: parent; onClicked: ponte.chiama0("riaggancia") } }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Rifiuta"); color: "#ffffff"; font.family: Tema.font; font.pixelSize: tel.px(13) }
        }
        Column {
            spacing: 8
            Rectangle { width: 76; height: 76; radius: 38; color: "#22c55e"; Icona { anchors.centerIn: parent; nome: "call-start-symbolic"; lato: 32 }
                MouseArea { anchors.fill: parent; onClicked: ponte.chiama0("rispondi") } }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Rispondi"); color: "#ffffff"; font.family: Tema.font; font.pixelSize: tel.px(13) }
        }
    }
    Rectangle {
        id: chiudi
        visible: ch.info.inArrivo !== true
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 70
        width: 76; height: 76; radius: 38
        color: "#ef4444"
        Icona { anchors.centerIn: parent; nome: "call-start-symbolic"; lato: 32; rotation: 135 }
        MouseArea { anchors.fill: parent; onClicked: { ponte.chiama0("riaggancia"); ch.tastierino = false; ch.toni = "" } }
    }
}
