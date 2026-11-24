// App Telefono: Preferiti, Recenti, Contatti e Tastierino (schede in basso).
// Le chiamate passano da ModemManager; la schermata di chiamata è in Chiamata.qml.
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: app
    color: tel.pal.sfondo
    property string scheda: "tastierino"      // preferiti | recenti | contatti | tastierino | segreteria
    property bool soloPerse: false
    // Chiamate perse nelle ultime 24 ore (numero rosso sulla scheda Recenti)
    readonly property int perse: registro.filter(function (v) { return v.tipo === "persa" && Date.now() / 1000 - v.quando < 86400 }).length
    function contattoDi(numero) {
        var b = (numero || "").replace(/\D/g, "")
        for (var i = 0; i < contatti.length; i++) { var a = contatti[i].numero.replace(/\D/g, ""); if (b.length >= 6 && a.slice(-9) === b.slice(-9)) return contatti[i] }
        return null
    }
    function dettagli(v) {
        var c = contattoDi(v.numero)
        if (c) { tel.appInterna = "contatti"; contattiApp.apri(c) }
        else { app.numero = v.numero; nuovoContatto.open() }
    }
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
    function chiamaSegreteria() {
        if (tel.imp.segreteria) app.chiama(tel.imp.segreteria)
        else { app.scheda = "segreteria"; tel.avviso(I18n.t("Scrivi prima il numero della segreteria del tuo operatore")) }
    }

    // ── Intestazione: barra in alto (come l'iPhone) e titolo grande ───────
    property bool modifica: false
    Punti {
        x: 18; y: 92
        visible: app.scheda !== "tastierino"
        text: ({ preferiti: I18n.t("Preferiti"), recenti: I18n.t("Recenti"), contatti: I18n.t("Contatti"), tastierino: "", segreteria: I18n.t("Segreteria") })[app.scheda]
    }
    // Recenti: tutte o solo le perse
    Rectangle {
        visible: app.scheda === "recenti"
        x: 16; y: 52
        width: segm.width + 4; height: 32; radius: 9; color: tel.pal.superficie2
        Row {
            id: segm
            x: 2; y: 2
            Repeater {
                model: [I18n.t("Tutte"), I18n.t("Perse")]
                Rectangle {
                    required property string modelData
                    required property int index
                    width: etSeg.implicitWidth + 32; height: 28; radius: 7
                    color: (index === 1) === app.soloPerse ? tel.pal.superficie : "transparent"
                    Text { id: etSeg; anchors.centerIn: parent; text: parent.modelData; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; onClicked: app.soloPerse = parent.index === 1 }
                }
            }
        }
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: 16; y: 57
        visible: app.scheda === "recenti" && app.registro.length > 0
        text: app.modifica ? I18n.t("Fine") : I18n.t("Modifica"); color: tel.accento
        font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: app.modifica ? Font.DemiBold : Font.Normal
        MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: app.modifica = !app.modifica }
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: 16; y: 98
        visible: app.scheda === "recenti" && app.modifica
        text: I18n.t("Cancella tutto"); color: tel.rosso
        font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.DemiBold
        MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: { ponte.chiama0("cancellaRegistro"); app.modifica = false; app.aggiorna() } }
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: 16; y: 50
        visible: app.scheda === "contatti" || app.scheda === "preferiti"
        text: "+"; color: tel.accento; font.family: Tema.font; font.pixelSize: 30; font.weight: Font.Light
        MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: nuovoContatto.open() }
    }

    // Senza SIM non c'è più un banner fisso: lo dice la barra di stato e, se si prova a chiamare
    // senza SIM né chiamate via Internet, un avviso al momento della chiamata.

    // ── Elenchi (Preferiti, Recenti, Contatti) ────────────────────────────
    ListView {
        id: elenco
        visible: app.scheda !== "tastierino" && app.scheda !== "segreteria"
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: parent.top; anchors.topMargin: 146
        anchors.bottom: schede.top
        clip: true
        model: app.scheda === "recenti" ? app.registro.filter(function (v) { return !app.soloPerse || v.tipo === "persa" })
               : (app.scheda === "preferiti" ? app.contatti.filter(function (c) { return c.preferito }) : (app.scheda === "contatti" ? app.contatti : []))
        delegate: Item {
            id: voce
            required property var modelData
            width: elenco.width; height: 56
            Avatar { x: 16; anchors.verticalCenter: parent.verticalCenter; lato: 40; nome: voce.modelData.nome || "?" }
            Column {
                x: 66; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 150
                Text { width: parent.width; elide: Text.ElideRight; text: voce.modelData.nome; color: app.scheda === "recenti" && voce.modelData.tipo === "persa" ? tel.rosso : tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.DemiBold }
                Row {
                    spacing: 4
                    Text {
                        visible: app.scheda === "recenti" && voce.modelData.tipo !== "persa"
                        anchors.verticalCenter: parent.verticalCenter
                        text: voce.modelData.tipo === "uscita" ? "↗" : "↙"; color: tel.pal.testo2; font.pixelSize: tel.px(13)
                    }
                    Text {
                        width: elenco.width - 150 - 16; elide: Text.ElideRight
                        text: app.scheda === "recenti" ? (voce.modelData.conNome ? I18n.t("cellulare") : I18n.t("sconosciuto")) : voce.modelData.numero
                        color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13)
                    }
                }
            }
            Text {
                visible: app.scheda === "recenti"
                anchors.right: parent.right; anchors.rightMargin: 54; anchors.verticalCenter: parent.verticalCenter
                text: voce.modelData.testoQuando || ""
                color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(14)
            }
            // «i»: i dettagli del contatto (o aggiungilo)
            Rectangle {
                visible: app.scheda === "recenti"
                anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter
                width: 24; height: 24; radius: 12; color: "transparent"; border.width: 1.5; border.color: tel.accento
                Text { anchors.centerIn: parent; text: "i"; color: tel.accento; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.Bold }
                MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: app.dettagli(voce.modelData) }
            }
            TastoTondo {
                visible: app.scheda !== "recenti"
                anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                lato: 40; icona: "call-start-symbolic"
                onTocco: app.chiama(voce.modelData.numero)
            }
            Rectangle { anchors.bottom: parent.bottom; x: 66; width: parent.width - 66; height: 1; color: app.linea }
            MouseArea {
                anchors.fill: parent; anchors.rightMargin: 56
                onClicked: app.chiama(voce.modelData.numero)
                onPressAndHold: if (app.scheda !== "recenti") { ponte.chiama("preferito", [voce.modelData.id, !voce.modelData.preferito]); app.aggiorna(); tel.avviso(voce.modelData.preferito ? I18n.t("Tolto dai preferiti") : I18n.t("Aggiunto ai preferiti")) }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: elenco.count === 0
            width: parent.width - 60
            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
            text: app.scheda === "recenti" ? (app.soloPerse ? I18n.t("Nessuna chiamata persa") : I18n.t("Nessuna chiamata recente")) : (app.scheda === "preferiti" ? I18n.t("Tieni premuto un contatto per aggiungerlo ai preferiti") : I18n.t("Nessun contatto: premi + per aggiungerne uno"))
            color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(15)
        }
    }

    // ── Tastierino (come l'iPhone: numero in alto, tasti tondi, chiamata verde al centro) ──
    Item {
        visible: app.scheda === "tastierino"
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: parent.top; anchors.bottom: schede.top
        readonly property var conosciuto: app.contattoDi(app.numero)
        Text {
            x: 20; y: 150; width: parent.width - 40
            horizontalAlignment: Text.AlignHCenter; elide: Text.ElideLeft
            text: app.numero
            color: tel.pal.testo; font.family: Tema.font; font.pixelSize: app.numero.length > 13 ? 30 : 38; font.letterSpacing: 1
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter; y: 202
            visible: app.numero.length >= 3
            text: parent.conosciuto ? parent.conosciuto.nome : I18n.t("Aggiungi numero")
            color: parent.conosciuto ? tel.pal.testo : tel.accento; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.Medium
            MouseArea { anchors.fill: parent; anchors.margins: -10; enabled: !parent.parent.conosciuto; onClicked: nuovoContatto.open() }
        }
        Grid {
            id: tasti
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.min(270, parent.height - 5 * 78 - 4 * 16 - 20)
            columns: 3; rowSpacing: 16; columnSpacing: 26
            Repeater {
                model: [["1", ""], ["2", "ABC"], ["3", "DEF"], ["4", "GHI"], ["5", "JKL"], ["6", "MNO"], ["7", "PQRS"], ["8", "TUV"], ["9", "WXYZ"], ["*", ""], ["0", "+"], ["#", ""]]
                Rectangle {
                    id: tastoT
                    required property var modelData
                    width: 78; height: 78; radius: 39
                    readonly property color base: tel.solido ? tel.pal.superficie : tel.pal.superficie2
                    color: tasto.pressed ? (tel.solido ? "#C6F432" : Qt.lighter(base, 1.6)) : base
                    Behavior on color { ColorAnimation { duration: tel.tVeloce } }
                    Column {
                        anchors.centerIn: parent
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: tastoT.modelData[0]; color: tel.solido && tasto.pressed ? "#141414" : tel.pal.testo; font.family: Tema.font; font.pixelSize: 34; font.weight: tel.solido ? Font.Bold : Font.Light }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: tastoT.modelData[1] || " "; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.6 }
                    }
                    MouseArea {
                        id: tasto
                        anchors.fill: parent
                        onClicked: app.numero += tastoT.modelData[0]
                        onPressAndHold: {
                            if (tastoT.modelData[0] === "0") app.numero += "+"
                            else if (tastoT.modelData[0] === "1") app.chiamaSegreteria()   // come su tutti i telefoni
                        }
                    }
                }
            }
            // Ultima riga: vuoto, chiama, cancella
            Item { width: 78; height: 78 }
            Rectangle {
                width: 78; height: 78; radius: 39
                color: tel.coloreChiama
                scale: toccoChiama.pressed ? 0.93 : 1
                Behavior on scale { NumberAnimation { duration: tel.tVeloce } }
                Icona { anchors.centerIn: parent; nome: "call-start-symbolic"; lato: 32; tema: tel.temaChiama }
                MouseArea { id: toccoChiama; anchors.fill: parent; onClicked: if (app.numero) app.chiama(app.numero) }
            }
            Item {
                width: 78; height: 78
                Icona { anchors.centerIn: parent; visible: app.numero !== ""; nome: "go-previous-symbolic"; lato: 30 }
                MouseArea { anchors.fill: parent; enabled: app.numero !== ""; onClicked: app.numero = app.numero.slice(0, -1); onPressAndHold: app.numero = "" }
            }
        }
    }

    // ── Segreteria ────────────────────────────────────────────────────────
    Column {
        visible: app.scheda === "segreteria"
        x: 20; y: 130; width: parent.width - 40
        spacing: 14
        Rectangle {
            width: parent.width; height: 150; radius: 18; color: tel.pal.superficie
            Column {
                anchors.centerIn: parent; spacing: 8
                Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: "phone-voicemail-symbolic"; lato: 34 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("Nessun messaggio"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(17); font.weight: Font.DemiBold }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("I messaggi lasciati in segreteria li ascolti chiamandola"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13) }
            }
        }
        Text { text: I18n.t("Numero della segreteria"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
        CampoTesto {
            id: campoSegreteria
            width: parent.width
            text: tel.imp.segreteria || ""
            placeholderText: I18n.t("Lo trovi sul sito del tuo operatore")
            inputMethodHints: Qt.ImhDialableCharactersOnly
            onEditingFinished: tel.imposta("segreteria", text.trim())
        }
        Rectangle {
            width: parent.width; height: 50; radius: 25; color: tel.coloreChiama
            opacity: campoSegreteria.text.trim() ? 1 : 0.4
            Row {
                anchors.centerIn: parent; spacing: 8
                Icona { anchors.verticalCenter: parent.verticalCenter; nome: "call-start-symbolic"; lato: 18; tema: tel.temaChiama }
                Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Chiama la segreteria"); color: tel.solido ? "#141414" : "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.DemiBold }
            }
            MouseArea { anchors.fill: parent; enabled: campoSegreteria.text.trim() !== ""; onClicked: { tel.imposta("segreteria", campoSegreteria.text.trim()); app.chiama(campoSegreteria.text.trim()) } }
        }
        Text {
            width: parent.width; wrapMode: Text.Wrap
            text: I18n.t("Puoi anche tenere premuto 1 sul tastierino, come su ogni telefono.")
            color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13)
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
                        { s: "contatti", t: I18n.t("Contatti"), i: "avatar-default-symbolic" }, { s: "tastierino", t: I18n.t("Tastierino"), i: "input-dialpad-symbolic" },
                        { s: "segreteria", t: I18n.t("Segreteria"), i: "phone-voicemail-symbolic" }]
                Item {
                    id: voceTab
                    required property var modelData
                    width: (app.width - 20) / 5; height: 52
                    readonly property bool attiva: app.scheda === voceTab.modelData.s
                    // Scheda attiva: una pillola colorata dietro l'icona
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter; y: 1
                        width: 54; height: 30; radius: 15; visible: voceTab.attiva
                        color: tel.solido ? "#C6F432" : Qt.rgba(tel.accento.r, tel.accento.g, tel.accento.b, 0.28)
                    }
                    Column {
                        anchors.centerIn: parent; spacing: 3
                        opacity: voceTab.attiva ? 1 : 0.55
                        Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: voceTab.modelData.i; lato: 24; tema: voceTab.attiva && tel.solido ? "chiaro" : "" }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: voceTab.modelData.t; color: voceTab.attiva && !tel.solido ? tel.accento : tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(10.5); font.weight: voceTab.attiva ? Font.Bold : Font.DemiBold }
                    }
                    Rectangle {
                        visible: voceTab.modelData.s === "recenti" && app.perse > 0
                        x: parent.width / 2 + 4; y: 0; height: 18; width: Math.max(18, conto.implicitWidth + 10); radius: 9; color: tel.rosso
                        Text { id: conto; anchors.centerIn: parent; text: app.perse; color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: 11; font.weight: Font.Bold }
                    }
                    MouseArea { anchors.fill: parent; onClicked: app.scheda = voceTab.modelData.s }
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
