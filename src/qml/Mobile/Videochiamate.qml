// App Videochiamate del telefono: in alto l'email del Solid ID da chiamare (video o solo
// audio), poi i preferiti a tondi, i recenti (in uscita, in arrivo, perse in rosso) e i contatti
// con un'email. La chiamata vera si apre a tutto schermo (VideoSovrapposta).
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: app
    objectName: "videochiamateApp"
    color: tel.pal.sfondo

    property var conf: ({})
    property var recenti: []
    property var preferiti: []
    property var contatti: []
    property bool cercando: false
    property bool videoScelto: true

    function vc(m, a) { return ponte.chiama("videochiamate", [m, a || []]) }
    function aggiorna() {
        conf = vc("configurazione")
        recenti = vc("recenti")
        preferiti = vc("preferiti")
        contatti = vc("contatti")
    }
    function chiamaEmail(email, video) {
        if (!conf.ok) { avviso.text = conf.motivo; return }
        cercando = true; videoScelto = video
        ponte.avvia("videochiamate", ["persona", [email]], "vc-persona")
    }
    Component.onCompleted: { aggiorna(); tel.videochiamateApp = app }
    Connections {
        target: ponte
        function onCompletato(id, r) {
            if (id !== "vc-persona") return
            app.cercando = false
            if (r.ok) tel.videochiama(r, app.videoScelto)
            else avviso.text = r.messaggio
        }
    }

    component TastoVerde: Rectangle {
        property string simbolo
        property bool pieno: false
        signal premuto()
        width: 40; height: 40; radius: 20
        color: pieno ? tel.pal.successo : Qt.rgba(0.19, 0.64, 0.42, tel.chiaro ? 0.14 : 0.22)
        scale: tocco.pressed ? 0.92 : 1
        Simbolo { anchors.centerIn: parent; nome: parent.simbolo; lato: 19; colore: parent.pieno ? "#FFFFFF" : tel.pal.successo }
        MouseArea { id: tocco; anchors.fill: parent; anchors.margins: -4; onClicked: parent.premuto() }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: colonna.height + 120
        clip: true
        Column {
            id: colonna
            x: tel.margine
            width: parent.width - 2 * tel.margine
            spacing: 16
            Item { width: 1; height: 92 }
            Punti { text: I18n.t("Videochiamate") }

            // senza Solid ID
            Rectangle {
                visible: !app.conf.ok
                width: parent.width; height: testoAccesso.implicitHeight + 28; radius: 16
                color: tel.pal.superficie
                Text { id: testoAccesso; x: 16; y: 14; width: parent.width - 32; wrapMode: Text.WordWrap; text: app.conf.motivo || ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(14) }
            }

            // chiama un Solid ID
            Rectangle {
                width: parent.width; height: 56; radius: 18
                color: tel.pal.superficie
                Row {
                    anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 8
                    spacing: 8
                    TextField {
                        id: campoEmail
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 108
                        placeholderText: I18n.t("Email del Solid ID")
                        placeholderTextColor: tel.pal.testo2
                        color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16)
                        inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoAutoUppercase
                        background: Item {}
                        leftPadding: 0
                        onAccepted: if (text.includes("@")) app.chiamaEmail(text, true)
                    }
                    TastoVerde { anchors.verticalCenter: parent.verticalCenter; simbolo: "telefono"; opacity: campoEmail.text.includes("@") ? 1 : 0.4; onPremuto: if (campoEmail.text.includes("@")) app.chiamaEmail(campoEmail.text, false) }
                    TastoVerde { anchors.verticalCenter: parent.verticalCenter; simbolo: "video"; pieno: true; opacity: campoEmail.text.includes("@") ? 1 : 0.4; onPremuto: if (campoEmail.text.includes("@")) app.chiamaEmail(campoEmail.text, true) }
                }
            }
            Text {
                id: avviso
                visible: text !== "" || app.cercando
                width: parent.width; wrapMode: Text.WordWrap
                text: app.cercando ? I18n.t("Ricerca…") : ""
                color: tel.pal.pericolo; font.family: Tema.font; font.pixelSize: tel.px(13)
            }

            // preferiti
            Text { visible: app.preferiti.length > 0; text: I18n.t("Preferiti"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(19); font.weight: Font.Bold }
            Flow {
                visible: app.preferiti.length > 0
                width: parent.width; spacing: 14
                Repeater {
                    model: app.preferiti
                    Column {
                        width: 74; spacing: 6
                        Avatar { anchors.horizontalCenter: parent.horizontalCenter; lato: 64; nome: modelData.nome
                                 MouseArea { anchors.fill: parent; onClicked: tel.videochiama(modelData, true) } }
                        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(12) }
                    }
                }
            }

            // recenti
            Text { text: I18n.t("Recenti"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(19); font.weight: Font.Bold }
            Rectangle {
                width: parent.width; height: app.recenti.length ? listaRecenti.height : 60; radius: 16
                color: tel.pal.superficie
                Text { anchors.centerIn: parent; visible: app.recenti.length === 0; text: I18n.t("Nessuna chiamata"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(14) }
                Column {
                    id: listaRecenti
                    width: parent.width
                    Repeater {
                        model: app.recenti.slice(0, 25)
                        Item {
                            width: listaRecenti.width; height: 64
                            readonly property bool preferito: app.preferiti.some(function (p) { return p.id === modelData.id })
                            Avatar { x: 12; anchors.verticalCenter: parent.verticalCenter; lato: 42; nome: modelData.nome }
                            Column {
                                x: 64; anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 64 - 104
                                Text { width: parent.width; elide: Text.ElideRight; text: modelData.nome; color: modelData.verso === "persa" ? tel.pal.pericolo : tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.DemiBold }
                                Row {
                                    spacing: 5
                                    Simbolo { anchors.verticalCenter: parent.verticalCenter; nome: modelData.video ? "video" : "telefono"; lato: 13; colore: tel.pal.testo2 }
                                    Text {
                                        text: (modelData.verso === "uscita" ? I18n.t("In uscita") : modelData.verso === "entrata" ? I18n.t("In arrivo") : I18n.t("Persa"))
                                              + (modelData.durataTesto ? " · " + modelData.durataTesto : "") + " · " + modelData.quando
                                        color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12)
                                    }
                                }
                            }
                            Row {
                                anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                                spacing: 10
                                Simbolo {
                                    anchors.verticalCenter: parent.verticalCenter
                                    nome: parent.parent.preferito ? "stella-piena" : "stella"; lato: 18
                                    colore: parent.parent.preferito ? "#F59E0B" : tel.pal.testo3
                                    MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: app.preferiti = app.vc("preferito", [modelData, !parent.parent.parent.preferito]) }
                                }
                                TastoVerde { simbolo: modelData.video ? "video" : "telefono"; onPremuto: tel.videochiama(modelData, modelData.video) }
                            }
                            Rectangle { x: 64; anchors.bottom: parent.bottom; width: parent.width - 64; height: 1; color: tel.pal.bordo; visible: index < app.recenti.length - 1 }
                        }
                    }
                }
            }

            // contatti con l'email
            Text { visible: app.contatti.length > 0; text: I18n.t("Contatti"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(19); font.weight: Font.Bold }
            Rectangle {
                visible: app.contatti.length > 0
                width: parent.width; height: listaContatti.height; radius: 16
                color: tel.pal.superficie
                Column {
                    id: listaContatti
                    width: parent.width
                    Repeater {
                        model: app.contatti
                        Item {
                            width: listaContatti.width; height: 60
                            Avatar { x: 12; anchors.verticalCenter: parent.verticalCenter; lato: 38; nome: modelData.nome }
                            Column {
                                x: 60; anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 60 - 110
                                Text { width: parent.width; elide: Text.ElideRight; text: modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15) }
                                Text { width: parent.width; elide: Text.ElideRight; text: modelData.email; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }
                            }
                            Row {
                                anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                                spacing: 10
                                TastoVerde { simbolo: "telefono"; onPremuto: app.chiamaEmail(modelData.email, false) }
                                TastoVerde { simbolo: "video"; onPremuto: app.chiamaEmail(modelData.email, true) }
                            }
                            Rectangle { x: 60; anchors.bottom: parent.bottom; width: parent.width - 60; height: 1; color: tel.pal.bordo; visible: index < app.contatti.length - 1 }
                        }
                    }
                }
            }
            Text {
                width: parent.width; wrapMode: Text.WordWrap
                text: I18n.t("Audio e video vanno direttamente da un dispositivo all'altro, cifrati. Puoi chiamare chi ha un Solid ID, sul telefono o sul computer.")
                color: tel.pal.testo3; font.family: Tema.font; font.pixelSize: tel.px(12)
            }
        }
    }
}
