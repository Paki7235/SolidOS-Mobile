// App Telefono: Preferiti, Recenti, Contatti e Tastierino (schede in basso).
// Le chiamate passano da ModemManager; la schermata di chiamata è in Chiamata.qml.
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: app
    color: tel.pal.sfondo
    property string scheda: "tastierino"      // preferiti | recenti | contatti | tastierino
    property string numero: ""
    property var contatti: []
    property var registro: []
    property var modem: ({})
    readonly property color sezione: tel.pal.superficie
    readonly property color linea: tel.pal.bordo

    function aggiorna() {
        contatti = ponte.chiama0("contatti")
        registro = ponte.chiama0("registro")
        modem = ponte.chiama0("modem")
    }
    onVisibleChanged: if (visible) aggiorna()
    Component.onCompleted: aggiorna()
    function chiama(n) { tel.chiama(n) }

    // ── Intestazione ──────────────────────────────────────────────────────
    Punti {
        x: 20; y: 60
        text: ({ preferiti: I18n.t("Preferiti"), recenti: I18n.t("Recenti"), contatti: I18n.t("Contatti"), tastierino: "" })[app.scheda].toUpperCase()
        font.pixelSize: 36
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: 20; y: 64
        visible: app.scheda === "recenti" && app.registro.length > 0
        text: I18n.t("Cancella"); color: tel.accento
        font.family: Tema.font; font.pixelSize: tel.px(16)
        MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: { ponte.chiama0("cancellaRegistro"); app.aggiorna() } }
    }
    TastoTondo {
        anchors.right: parent.right; anchors.rightMargin: 18; y: 62
        visible: app.scheda === "contatti"
        icona: "list-add-symbolic"; pieno: true
        onTocco: nuovoContatto.open()
    }

    // ── Avviso SIM ────────────────────────────────────────────────────────
    Rectangle {
        visible: app.modem.messaggio !== undefined && app.modem.messaggio !== ""
        x: 16; y: 104; width: parent.width - 32; height: 40; radius: 12
        color: tel.chiaro ? "#fff4e5" : "#3a2a12"
        Row {
            anchors.centerIn: parent; spacing: 8
            Icona { nome: "dialog-warning-symbolic"; lato: 18; anchors.verticalCenter: parent.verticalCenter }
            Text { text: app.modem.messaggio || ""; color: tel.chiaro ? "#8a4b00" : "#ffcf8a"; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
        }
    }

    // ── Elenchi (Preferiti, Recenti, Contatti) ────────────────────────────
    ListView {
        id: elenco
        visible: app.scheda !== "tastierino"
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: parent.top; anchors.topMargin: app.modem.messaggio ? 152 : 108
        anchors.bottom: schede.top
        clip: true
        model: app.scheda === "recenti" ? app.registro : (app.scheda === "preferiti" ? app.contatti.filter(function (c) { return c.preferito }) : app.contatti)
        delegate: Item {
            id: voce
            required property var modelData
            width: elenco.width; height: 64
            Avatar { x: 20; anchors.verticalCenter: parent.verticalCenter; lato: 44; nome: voce.modelData.nome || "?"; nuovo: app.scheda === "recenti" && voce.modelData.tipo === "persa" }
            Column {
                x: 74; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 150
                Text { width: parent.width; elide: Text.ElideRight; text: voce.modelData.nome; color: app.scheda === "recenti" && voce.modelData.tipo === "persa" ? tel.rosso : tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.DemiBold }
                Text {
                    width: parent.width; elide: Text.ElideRight
                    text: app.scheda === "recenti"
                          ? ({ persa: I18n.t("Persa"), entrata: I18n.t("In arrivo"), uscita: I18n.t("In uscita") })[voce.modelData.tipo] + (voce.modelData.conNome ? " · " + voce.modelData.numero : "")
                          : voce.modelData.numero
                    color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13)
                }
            }
            Text {
                visible: app.scheda === "recenti"
                anchors.right: parent.right; anchors.rightMargin: 64; anchors.verticalCenter: parent.verticalCenter
                text: voce.modelData.testoQuando || ""
                color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13)
            }
            TastoTondo {
                anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                lato: 40; icona: "call-start-symbolic"
                onTocco: app.chiama(voce.modelData.numero)
            }
            Rectangle { anchors.bottom: parent.bottom; x: 74; width: parent.width - 74; height: 1; color: app.linea }
            MouseArea {
                anchors.fill: parent; anchors.rightMargin: 64
                onClicked: app.chiama(voce.modelData.numero)
                onPressAndHold: if (app.scheda !== "recenti") { ponte.chiama("preferito", [voce.modelData.id, !voce.modelData.preferito]); app.aggiorna(); tel.avviso(voce.modelData.preferito ? I18n.t("Tolto dai preferiti") : I18n.t("Aggiunto ai preferiti")) }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: elenco.count === 0
            width: parent.width - 60
            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
            text: app.scheda === "recenti" ? I18n.t("Nessuna chiamata recente") : (app.scheda === "preferiti" ? I18n.t("Tieni premuto un contatto per aggiungerlo ai preferiti") : I18n.t("Nessun contatto: premi + per aggiungerne uno"))
            color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(15)
        }
    }

    // ── Tastierino ────────────────────────────────────────────────────────
    Item {
        visible: app.scheda === "tastierino"
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: parent.top; anchors.bottom: schede.top
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.14
            spacing: 6
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: app.width - 40; horizontalAlignment: Text.AlignHCenter
                text: app.numero || " "
                elide: Text.ElideLeft
                color: tel.pal.testo; font.family: tel.fontPunti; font.pixelSize: app.numero.length > 13 ? 30 : 40; font.weight: Font.Black; font.letterSpacing: -1
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    if (!app.numero) return " "
                    for (var i = 0; i < app.contatti.length; i++) {
                        var a = app.contatti[i].numero.replace(/\D/g, ""), b = app.numero.replace(/\D/g, "")
                        if (b.length >= 6 && a.slice(-9) === b.slice(-9)) return app.contatti[i].nome
                    }
                    return " "
                }
                color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15)
            }
        }
        Grid {
            id: tasti
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: chiamaTasto.top; anchors.bottomMargin: 22
            columns: 3; rowSpacing: 16; columnSpacing: 28
            Repeater {
                model: [["1", ""], ["2", "ABC"], ["3", "DEF"], ["4", "GHI"], ["5", "JKL"], ["6", "MNO"], ["7", "PQRS"], ["8", "TUV"], ["9", "WXYZ"], ["*", ""], ["0", "+"], ["#", ""]]
                Rectangle {
                    required property var modelData
                    width: 76; height: 76; radius: 38
                    color: tasto.pressed ? tel.pal.pieno : tel.pal.superficie2
                    Behavior on color { ColorAnimation { duration: tel.tVeloce } }
                    Column {
                        anchors.centerIn: parent
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.modelData[0]; color: tasto.pressed ? tel.pal.suPieno : tel.pal.testo; font.family: Tema.font; font.pixelSize: 32; font.weight: Font.Medium }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.modelData[1]; color: tasto.pressed ? tel.pal.suPieno : tel.pal.testo2; font.family: tel.fontMono; font.pixelSize: 9; font.letterSpacing: 1.2 }
                    }
                    MouseArea {
                        id: tasto
                        anchors.fill: parent
                        onClicked: app.numero += parent.modelData[0]
                        onPressAndHold: if (parent.modelData[0] === "0") app.numero += "+"
                    }
                }
            }
        }
        Rectangle {
            id: chiamaTasto
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 18
            width: 76; height: 76; radius: 38
            color: tel.pal.successo
            scale: toccoChiama.pressed ? 0.93 : 1
            Behavior on scale { NumberAnimation { duration: tel.tVeloce } }
            Icona { anchors.centerIn: parent; nome: "call-start-symbolic"; lato: 30; tema: "chiaro" }
            MouseArea { id: toccoChiama; anchors.fill: parent; onClicked: if (app.numero) app.chiama(app.numero) }
        }
        Text {
            visible: app.numero !== ""
            anchors.left: chiamaTasto.right; anchors.leftMargin: 40
            anchors.verticalCenter: chiamaTasto.verticalCenter
            text: "⌫"; color: tel.pal.testo2; font.pixelSize: 30
            MouseArea { anchors.fill: parent; anchors.margins: -12; onClicked: app.numero = app.numero.slice(0, -1); onPressAndHold: app.numero = "" }
        }
    }

    // ── Schede in basso ───────────────────────────────────────────────────
    Rectangle {
        id: schede
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 84
        color: tel.pal.sfondo
        Rectangle { width: parent.width; height: 1; color: app.linea }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8
            Repeater {
                model: [{ s: "preferiti", t: I18n.t("Preferiti"), i: "starred-symbolic" }, { s: "recenti", t: I18n.t("Recenti"), i: "document-open-recent-symbolic" },
                        { s: "contatti", t: I18n.t("Contatti"), i: "avatar-default-symbolic" }, { s: "tastierino", t: I18n.t("Tastierino"), i: "input-dialpad-symbolic" }]
                Item {
                    required property var modelData
                    width: (app.width - 20) / 4; height: 52
                    opacity: app.scheda === modelData.s ? 1 : 0.45
                    Column {
                        anchors.centerIn: parent; spacing: 3
                        Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: parent.parent.modelData.i; lato: 24 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.modelData.t; color: tel.pal.testo; font.family: tel.fontMono; font.pixelSize: tel.px(10); font.capitalization: Font.AllUppercase; font.letterSpacing: 0.5 }
                    }
                    MouseArea { anchors.fill: parent; onClicked: app.scheda = parent.modelData.s }
                }
            }
        }
    }

    // ── Nuovo contatto ────────────────────────────────────────────────────
    Popup {
        id: nuovoContatto
        anchors.centerIn: parent
        width: parent.width - 40
        modal: true
        padding: 18
        background: Rectangle { radius: 20; color: app.sezione }
        onOpened: { campoNome.text = ""; campoNumero.text = app.numero }
        Column {
            width: parent.width; spacing: 12
            Text { text: I18n.t("Nuovo contatto"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(20); font.weight: Font.Bold }
            CampoTesto { id: campoNome; width: parent.width; placeholderText: I18n.t("Nome") }
            CampoTesto { id: campoNumero; width: parent.width; placeholderText: I18n.t("Numero"); inputMethodHints: Qt.ImhDialableCharactersOnly }
            Row {
                spacing: 10; anchors.right: parent.right
                Pulsante { text: I18n.t("Annulla"); onClicked: nuovoContatto.close() }
                Pulsante {
                    text: I18n.t("Salva"); principale: true
                    onClicked: { var r = ponte.chiama("salvaContatto", [campoNome.text, campoNumero.text, ""]); tel.avviso(r.messaggio); if (r.ok) { nuovoContatto.close(); app.aggiorna() } }
                }
            }
        }
    }
}
