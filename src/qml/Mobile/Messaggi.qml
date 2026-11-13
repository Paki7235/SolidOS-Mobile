// App Messaggi: elenco delle conversazioni (con ricerca) e la chat con le nuvolette.
// Gli SMS passano da ModemManager; quelli ricevuti si copiano nell'archivio del telefono.
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: app
    color: tel.chiaro ? "#f2f3f8" : "#0e1118"
    property var conversazioni: []
    property var aperta: null            // {numero, nome, messaggi} oppure null
    property string cerca: ""
    property bool nuova: false
    readonly property color linea: tel.chiaro ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.08)
    readonly property color sezione: tel.chiaro ? "#ffffff" : "#1b1f2b"

    function aggiorna() { conversazioni = ponte.chiama0("conversazioni") }
    function apri(numero) { aperta = ponte.chiama("conversazione", [numero]); nuova = false }
    onVisibleChanged: if (visible) aggiorna()
    Component.onCompleted: aggiorna()
    Timer { interval: 8000; running: app.visible; repeat: true; onTriggered: { app.aggiorna(); if (app.aperta) app.apri(app.aperta.numero) } }

    // ══ Elenco delle conversazioni ═══════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: app.aperta === null && !app.nuova
        Text { x: 20; y: 56; text: I18n.t("Messaggi"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(30); font.weight: Font.Bold }
        Rectangle {
            anchors.right: parent.right; anchors.rightMargin: 18; y: 58
            width: 40; height: 40; radius: 20
            color: tel.accento
            Icona { anchors.centerIn: parent; nome: "document-edit-symbolic"; lato: 20 }
            MouseArea { anchors.fill: parent; onClicked: { app.nuova = true; destinatario.text = ""; testoNuovo.text = "" } }
        }
        Rectangle {
            x: 16; y: 108; width: parent.width - 32; height: 40; radius: 12
            color: tel.chiaro ? "#e6e8f0" : "#1f2430"
            Row {
                anchors.fill: parent; anchors.leftMargin: 12; spacing: 8
                Icona { nome: "system-search-symbolic"; lato: 16; anchors.verticalCenter: parent.verticalCenter }
                TextField {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 40
                    placeholderText: I18n.t("Cerca"); placeholderTextColor: tel.pal.testo2
                    color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15)
                    background: Item {}
                    onTextChanged: app.cerca = text.toLowerCase()
                }
            }
        }
        ListView {
            id: lista
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top; anchors.topMargin: 160; anchors.bottom: parent.bottom; anchors.bottomMargin: 30
            clip: true
            model: app.conversazioni.filter(function (c) { return !app.cerca || c.nome.toLowerCase().indexOf(app.cerca) >= 0 || c.ultimo.toLowerCase().indexOf(app.cerca) >= 0 })
            delegate: Item {
                id: conv
                required property var modelData
                width: lista.width; height: 76
                Rectangle {
                    x: 16; anchors.verticalCenter: parent.verticalCenter
                    width: 48; height: 48; radius: 24
                    color: tel.accento
                    Text { anchors.centerIn: parent; text: conv.modelData.conNome ? conv.modelData.nome.charAt(0).toUpperCase() : "#"; color: "#ffffff"; font.family: Tema.font; font.pixelSize: 19; font.weight: Font.Bold }
                }
                Column {
                    x: 76; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 92; spacing: 3
                    Item {
                        width: parent.width; height: nomeConv.implicitHeight
                        Text { id: nomeConv; width: parent.width - 60; elide: Text.ElideRight; text: conv.modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.DemiBold }
                        Text { anchors.right: parent.right; text: conv.modelData.testoQuando; color: conv.modelData.nuovi ? tel.accento : tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }
                    }
                    Item {
                        width: parent.width; height: ultimo.implicitHeight
                        Text { id: ultimo; width: parent.width - 30; elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap; text: conv.modelData.ultimo; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(14) }
                        Rectangle { visible: conv.modelData.nuovi > 0; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 10; height: 10; radius: 5; color: tel.accento }
                    }
                }
                Rectangle { anchors.bottom: parent.bottom; x: 76; width: parent.width - 76; height: 1; color: app.linea }
                MouseArea { anchors.fill: parent; onClicked: app.apri(conv.modelData.numero) }
            }
            Text {
                anchors.centerIn: parent
                visible: lista.count === 0
                width: parent.width - 60; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                text: app.cerca ? I18n.t("Nessun risultato") : I18n.t("Nessun messaggio. Premi la matita per scriverne uno.")
                color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(15)
            }
        }
    }

    // ══ Nuovo messaggio ══════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: app.nuova
        Text {
            x: 18; y: 60; text: "‹ " + I18n.t("Messaggi"); color: tel.accento; font.family: Tema.font; font.pixelSize: tel.px(16)
            MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: app.nuova = false }
        }
        Text { x: 20; y: 92; text: I18n.t("Nuovo messaggio"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(24); font.weight: Font.Bold }
        CampoTesto { id: destinatario; x: 16; y: 140; width: parent.width - 32; placeholderText: I18n.t("A: nome o numero"); inputMethodHints: Qt.ImhDialableCharactersOnly }
        Column {
            x: 16; y: 190; width: parent.width - 32
            Repeater {
                model: destinatario.text.length >= 1 ? ponte.chiama0("contatti").filter(function (c) { return c.nome.toLowerCase().indexOf(destinatario.text.toLowerCase()) >= 0 }).slice(0, 4) : []
                Item {
                    required property var modelData
                    width: parent.width; height: 48
                    Text { anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.nome + "  ·  " + parent.modelData.numero; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15) }
                    MouseArea { anchors.fill: parent; onClicked: destinatario.text = parent.modelData.numero }
                }
            }
        }
        BarraScrivi {
            id: testoNuovo
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            onInvia: function (testo) {
                var r = ponte.chiama("inviaSms", [destinatario.text, testo])
                if (!r.ok) { tel.avviso(r.messaggio); return }
                app.aggiorna(); app.apri(destinatario.text)
            }
        }
    }

    // ══ Conversazione ════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: app.aperta !== null
        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right
            height: 110
            color: app.sezione
            z: 2
            Text {
                x: 16; y: 62; text: "‹"; color: tel.accento; font.pixelSize: 34
                MouseArea { anchors.fill: parent; anchors.margins: -12; onClicked: { app.aperta = null; app.aggiorna() } }
            }
            Column {
                anchors.horizontalCenter: parent.horizontalCenter; y: 54
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 34; height: 34; radius: 17; color: tel.accento
                    Text { anchors.centerIn: parent; text: app.aperta ? app.aperta.nome.charAt(0).toUpperCase() : ""; color: "#ffffff"; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.Bold }
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: app.aperta ? app.aperta.nome : ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
            }
            Rectangle {
                anchors.right: parent.right; anchors.rightMargin: 16; y: 62
                width: 36; height: 36; radius: 18; color: tel.chiaro ? "#e7f6ec" : "#16301f"
                Icona { anchors.centerIn: parent; nome: "call-start-symbolic"; lato: 18 }
                MouseArea { anchors.fill: parent; onClicked: tel.chiama(app.aperta.numero) }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: app.linea }
        }
        ListView {
            id: chat
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top; anchors.topMargin: 116
            anchors.bottom: scrivi.top; anchors.bottomMargin: 6
            clip: true
            spacing: 6
            model: app.aperta ? app.aperta.messaggi : []
            onCountChanged: positionViewAtEnd()
            delegate: Item {
                id: msg
                required property var modelData
                width: chat.width
                height: nuvola.height + 2
                Rectangle {
                    id: nuvola
                    x: msg.modelData.mio ? parent.width - width - 14 : 14
                    width: Math.min(testoMsg.implicitWidth + 28, chat.width * 0.76)
                    height: testoMsg.implicitHeight + ora.implicitHeight + 18
                    radius: 18
                    color: msg.modelData.mio ? tel.accento : (tel.chiaro ? "#e6e8f0" : "#262b37")
                    Text {
                        id: testoMsg
                        x: 14; y: 8
                        width: Math.min(implicitWidth, chat.width * 0.76 - 28)
                        wrapMode: Text.Wrap
                        text: msg.modelData.testo
                        color: msg.modelData.mio ? "#ffffff" : tel.pal.testo
                        font.family: Tema.font; font.pixelSize: tel.px(16)
                    }
                    Text {
                        id: ora
                        anchors.right: parent.right; anchors.rightMargin: 12
                        anchors.top: testoMsg.bottom; anchors.topMargin: 2
                        text: msg.modelData.testoQuando
                        color: msg.modelData.mio ? Qt.rgba(1, 1, 1, 0.75) : tel.pal.testo2
                        font.family: Tema.font; font.pixelSize: tel.px(11)
                    }
                }
            }
        }
        BarraScrivi {
            id: scrivi
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            onInvia: function (testo) {
                var r = ponte.chiama("inviaSms", [app.aperta.numero, testo])
                if (!r.ok) { tel.avviso(r.messaggio); return }
                app.apri(app.aperta.numero)
            }
        }
    }
}
