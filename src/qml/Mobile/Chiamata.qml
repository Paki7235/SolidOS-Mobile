// Schermata della chiamata «Essenziale» (in uscita, in arrivo, in corso): nome, numero e
// durata in Space Mono, muto, tastierino, vivavoce (acceso = bianco), rispondi e chiudi.
import QtQuick
import SolidUI

Rectangle {
    id: ch
    property var info: ({})
    property bool tastierino: false
    property string toni: ""
    color: tel.pal.sfondo

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
            color: t.attivo ? tel.pal.pieno : tel.pal.superficie2
            scale: toccoT.pressed ? 0.93 : 1
            Behavior on scale { NumberAnimation { duration: tel.tVeloce } }
            Behavior on color { ColorAnimation { duration: tel.tVeloce } }
            Icona { anchors.centerIn: parent; nome: t.icona; lato: 28; tema: t.attivo ? (tel.chiaro ? "scuro" : "chiaro") : "" }
            MouseArea { id: toccoT; anchors.fill: parent; onClicked: t.premuto() }
        }
        Mono { anchors.horizontalCenter: parent.horizontalCenter; text: t.testo; color: tel.pal.testo2 }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 110
        spacing: 10
        Avatar { anchors.horizontalCenter: parent.horizontalCenter; lato: 104; nome: ch.info.nome || "?" }
        Item { width: 1; height: 6 }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: ch.info.nome || ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(30); font.weight: Font.DemiBold }
        Mono { anchors.horizontalCenter: parent.horizontalCenter; visible: ch.info.nome !== ch.info.numero; text: ch.info.numero || ""; font.pixelSize: tel.px(13) }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Rectangle { visible: !ch.tastierino; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: ch.info.inArrivo ? tel.rosso : tel.pal.successo
                SequentialAnimation on opacity { running: ch.visible && tel.movimento; loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutSine } NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine } } }
            Mono { text: ch.tastierino ? ch.toni : (ch.info.testo || ""); color: tel.pal.testo; font.pixelSize: tel.px(14) }
        }
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
                color: tel.pal.superficie2
                Text { anchors.centerIn: parent; text: parent.modelData; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 30 }
                MouseArea { anchors.fill: parent; onClicked: { ch.toni += parent.modelData; ponte.chiama("tono", [parent.modelData]) } }
            }
        }
    }
    Text {
        visible: ch.tastierino
        anchors.right: parent.right; anchors.rightMargin: 40
        anchors.verticalCenter: chiudi.verticalCenter
        text: I18n.t("Nascondi"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16)
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
            Rectangle { width: 76; height: 76; radius: 38; color: tel.rosso; Icona { anchors.centerIn: parent; nome: "call-start-symbolic"; lato: 30; rotation: 135; tema: "scuro" }
                MouseArea { anchors.fill: parent; onClicked: ponte.chiama0("riaggancia") } }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Rifiuta"); color: tel.pal.testo2; font.family: tel.fontMono; font.pixelSize: tel.px(11); font.capitalization: Font.AllUppercase }
        }
        Column {
            spacing: 8
            Rectangle { width: 76; height: 76; radius: 38; color: tel.pal.successo; Icona { anchors.centerIn: parent; nome: "call-start-symbolic"; lato: 30; tema: "chiaro" }
                MouseArea { anchors.fill: parent; onClicked: ponte.chiama0("rispondi") } }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Rispondi"); color: tel.pal.testo2; font.family: tel.fontMono; font.pixelSize: tel.px(11); font.capitalization: Font.AllUppercase }
        }
    }
    Rectangle {
        id: chiudi
        visible: ch.info.inArrivo !== true
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 70
        width: 76; height: 76; radius: 38
        color: tel.rosso
        Icona { anchors.centerIn: parent; nome: "call-start-symbolic"; lato: 30; rotation: 135; tema: "scuro" }
        MouseArea { anchors.fill: parent; onClicked: { ponte.chiama0("riaggancia"); ch.tastierino = false; ch.toni = "" } }
    }
}
