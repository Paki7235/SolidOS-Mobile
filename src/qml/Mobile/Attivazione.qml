// Blocco di attivazione (come su iPhone): questo telefono è collegato al Solid ID di qualcun
// altro. Anche dopo averlo cancellato o reinstallato, per usarlo serve la password di quel
// Solid ID. Così un telefono rubato e cancellato non serve a chi l'ha preso.
import QtQuick
import SolidUI

Rectangle {
    id: att
    color: "#0B0E18"
    MouseArea { anchors.fill: parent }        // niente passa sotto
    property string errore: ""
    property bool attesa: false

    Column {
        x: 28; y: Math.max(90, parent.height * 0.14); width: parent.width - 56
        spacing: 14
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 76; height: 76; radius: 22
            gradient: Gradient { GradientStop { position: 0; color: "#4C7DFF" } GradientStop { position: 1; color: "#8B5CF6" } }
            Icona { anchors.centerIn: parent; nome: "system-lock-screen-symbolic"; lato: 36; tema: "scuro" }
        }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Blocco di attivazione"); color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(26); font.weight: Font.Bold }
        Text {
            width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
            text: I18n.t("Questo telefono è collegato a un Solid ID. Anche dopo averlo cancellato o reinstallato, per usarlo serve la password di") + " " + tel.attivazione + "."
            color: "#A1A1AA"; font.family: Tema.font; font.pixelSize: tel.px(15); lineHeight: 1.15
        }
        Item { width: 1; height: 6 }
        CampoTesto { id: email; width: parent.width; placeholderText: tel.attivazione; inputMethodHints: Qt.ImhEmailCharactersOnly }
        CampoTesto { id: password; width: parent.width; placeholderText: I18n.t("Password"); echoMode: TextInput.Password; onAccepted: sblocca.clicked() }
        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; visible: text !== ""; text: att.errore; color: tel.rosso; font.family: Tema.font; font.pixelSize: tel.px(13) }
        Pulsante {
            id: sblocca
            width: parent.width; principale: true
            text: att.attesa ? I18n.t("Controllo…") : I18n.t("Sblocca")
            enabled: !att.attesa
            onClicked: { att.attesa = true; att.errore = ""; ponte.avvia("sbloccaAttivazione", [email.text, password.text], "sblocca-attivazione") }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.t("Password dimenticata?"); color: tel.accento; font.family: Tema.font; font.pixelSize: tel.px(14)
            MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: { var r = ponte.chiama("sidPassword", [email.text]); tel.avviso(r.messaggio) } }
        }
        Item { width: 1; height: 10 }
        Text {
            width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
            text: I18n.t("Se il telefono è tuo ma l'hai preso da un'altra persona, chiedile di toglierlo dal suo Solid ID in Dov'è.")
            color: "#71717A"; font.family: Tema.font; font.pixelSize: tel.px(12)
        }
    }
    Connections {
        target: ponte
        function onCompletato(id, r) {
            if (id !== "sblocca-attivazione") return
            att.attesa = false; password.text = ""
            if (r.ok) { tel.attivazione = ""; tel.avviso(r.messaggio) }
            else att.errore = r.messaggio
        }
    }
}
