// App Contatti: elenco alfabetico con ricerca, scheda del contatto (chiama, messaggio,
// preferito, modifica, elimina), nuovo contatto e importa/esporta in vCard (.vcf).
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: app
    color: tel.pal.sfondo
    property var contatti: []
    property var scelto: null          // contatto aperto nella scheda
    property bool modifica: false
    property string cerca: ""
    readonly property color sezione: tel.pal.superficie
    readonly property color linea: tel.pal.bordo
    readonly property var filtrati: contatti.filter(function (c) { return !cerca || c.nome.toLowerCase().indexOf(cerca) >= 0 || c.numero.replace(/\s/g, "").indexOf(cerca.replace(/\s/g, "")) >= 0 })

    function aggiorna() {
        contatti = ponte.chiama0("contatti")
        if (scelto) scelto = contatti.find(function (c) { return c.id === scelto.id }) || null
    }
    function apri(c) { scelto = c; modifica = false }
    function nuovo() { scelto = { id: "", nome: "", numero: "", email: "", note: "", preferito: false }; modifica = true }
    onVisibleChanged: if (visible) aggiorna()
    Component.onCompleted: aggiorna()

    // ══ Elenco ═══════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: app.scelto === null
        Punti { x: 20; y: 60; text: I18n.t("Contatti"); font.pixelSize: 32 }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 18; y: 62
            spacing: 10
            TastoTondo { icona: "document-send-symbolic"; onTocco: vcard.open() }
            TastoTondo { icona: "list-add-symbolic"; pieno: true; onTocco: app.nuovo() }
        }
        CampoCerca {
            x: 16; y: 122; width: parent.width - 32
            suggerimento: I18n.t("Cerca tra") + " " + app.contatti.length + " " + I18n.t("contatti")
            onTextChanged: app.cerca = text.toLowerCase()
        }
        ListView {
            id: elenco
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top; anchors.topMargin: 178; anchors.bottom: parent.bottom; anchors.bottomMargin: 30
            clip: true
            model: app.filtrati
            section.property: "nome"
            section.criteria: ViewSection.FirstCharacter
            section.delegate: Text {
                required property string section
                x: 20; height: 28; verticalAlignment: Text.AlignBottom
                text: section.toUpperCase()
                color: tel.accento; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.Bold
            }
            delegate: Item {
                id: voce
                required property var modelData
                width: elenco.width; height: 58
                Avatar { x: 20; anchors.verticalCenter: parent.verticalCenter; lato: 42; nome: voce.modelData.nome }
                Column {
                    x: 72; anchors.verticalCenter: parent.verticalCenter
                    Text { text: voce.modelData.nome + (voce.modelData.preferito ? "  ★" : ""); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.DemiBold }
                    Text { text: voce.modelData.numero; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }
                }
                Rectangle { anchors.bottom: parent.bottom; x: 72; width: parent.width - 72; height: 1; color: app.linea }
                MouseArea { anchors.fill: parent; onClicked: app.apri(voce.modelData) }
            }
            Text {
                anchors.centerIn: parent
                visible: elenco.count === 0
                width: parent.width - 60; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                text: app.cerca ? I18n.t("Nessun risultato") : I18n.t("Nessun contatto. Premi + per aggiungerne uno, oppure importa la rubrica del vecchio telefono (file .vcf).")
                color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(15)
            }
        }
    }

    // ══ Scheda del contatto (e modifica) ═════════════════════════════════
    Item {
        anchors.fill: parent
        visible: app.scelto !== null
        Text {
            x: 18; y: 60; text: "‹ " + I18n.t("Contatti"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16)
            MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: { app.scelto = null; app.modifica = false } }
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 20; y: 60
            text: app.modifica ? I18n.t("Salva") : I18n.t("Modifica")
            color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.DemiBold
            MouseArea {
                anchors.fill: parent; anchors.margins: -10
                onClicked: {
                    if (!app.modifica) { app.modifica = true; return }
                    var r = ponte.chiama("salvaContatto", [campoNome.text, campoNumero.text, app.scelto.id, campoEmail.text, campoNote.text])
                    tel.avviso(r.messaggio)
                    if (r.ok) { app.scelto = { id: r.id }; app.aggiorna(); app.modifica = false }
                }
            }
        }
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 100
            spacing: 8
            Avatar { anchors.horizontalCenter: parent.horizontalCenter; lato: 104; nome: app.scelto && app.scelto.nome ? app.scelto.nome : "+" }
            Text { visible: !app.modifica; anchors.horizontalCenter: parent.horizontalCenter; text: app.scelto ? app.scelto.nome : ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(28); font.weight: Font.DemiBold }
        }
        // Azioni rapide
        Row {
            visible: !app.modifica
            anchors.horizontalCenter: parent.horizontalCenter
            y: 260
            spacing: 12
            Repeater {
                model: [{ t: I18n.t("Chiama"), i: "call-start-symbolic" }, { t: I18n.t("Messaggio"), i: "mail-message-new-symbolic" }, { t: I18n.t("Preferito"), i: "starred-symbolic" }]
                Rectangle {
                    required property var modelData
                    required property int index
                    width: (app.width - 64) / 3; height: 70; radius: 22
                    color: index === 2 && app.scelto && app.scelto.preferito ? tel.pal.pieno : app.sezione
                    border.width: 1; border.color: index === 2 && app.scelto && app.scelto.preferito ? tel.pal.pieno : tel.pal.bordo
                    Column {
                        anchors.centerIn: parent; spacing: 4
                        Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: parent.parent.modelData.i; lato: 22; tema: parent.parent.index === 2 && app.scelto && app.scelto.preferito ? (tel.chiaro ? "scuro" : "chiaro") : "" }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.modelData.t; color: parent.parent.index === 2 && app.scelto && app.scelto.preferito ? tel.pal.suPieno : tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(12); font.weight: Font.DemiBold }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (parent.index === 0) tel.chiama(app.scelto.numero)
                            else if (parent.index === 1) { tel.appInterna = "messaggi"; messaggiApp.apri(app.scelto.numero) }
                            else { ponte.chiama("preferito", [app.scelto.id, !app.scelto.preferito]); app.aggiorna() }
                        }
                    }
                }
            }
        }
        // Dettagli (lettura) o campi (modifica)
        Rectangle {
            x: 16; y: app.modifica ? 210 : 344
            width: parent.width - 32; height: dettagli.implicitHeight + 8
            radius: 22; color: app.sezione
            Column {
                id: dettagli
                width: parent.width
                Repeater {
                    model: [{ e: I18n.t("Nome"), c: "nome", solo: true }, { e: I18n.t("Cellulare"), c: "numero" }, { e: I18n.t("Email"), c: "email" }, { e: I18n.t("Note"), c: "note" }]
                    Item {
                        required property var modelData
                        visible: app.modifica ? true : !!(!modelData.solo && app.scelto && app.scelto[modelData.c])
                        width: parent.width; height: visible ? 62 : 0
                        Text { x: 16; y: 10; text: parent.modelData.e; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }
                        Text { x: 16; y: 30; visible: !app.modifica; text: app.scelto ? (app.scelto[parent.modelData.c] || "") : ""; color: tel.pal.testo; font.family: parent.modelData.c === "numero" ? tel.fontMono : Tema.font; font.pixelSize: tel.px(16) }
                        Rectangle { anchors.bottom: parent.bottom; x: 16; width: parent.width - 16; height: 1; color: app.linea }
                    }
                }
            }
            // Campi di modifica sovrapposti alle righe (uno per riga)
            Column {
                visible: app.modifica
                x: 16; y: 26; width: parent.width - 32
                spacing: 24
                TextField { id: campoNome; width: parent.width; height: 38; text: app.scelto ? app.scelto.nome || "" : ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); placeholderText: I18n.t("Nome e cognome"); placeholderTextColor: tel.pal.testo2; background: Item {} }
                TextField { id: campoNumero; width: parent.width; height: 38; text: app.scelto ? app.scelto.numero || "" : ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); inputMethodHints: Qt.ImhDialableCharactersOnly; placeholderText: "+39 …"; placeholderTextColor: tel.pal.testo2; background: Item {} }
                TextField { id: campoEmail; width: parent.width; height: 38; text: app.scelto ? app.scelto.email || "" : ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); inputMethodHints: Qt.ImhEmailCharactersOnly; placeholderText: "nome@esempio.it"; placeholderTextColor: tel.pal.testo2; background: Item {} }
                TextField { id: campoNote; width: parent.width; height: 38; text: app.scelto ? app.scelto.note || "" : ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); background: Item {} }
            }
        }
        Rectangle {
            visible: app.modifica && app.scelto && app.scelto.id !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 50
            width: parent.width - 32; height: 48; radius: 14
            color: app.sezione
            Text { anchors.centerIn: parent; text: I18n.t("Elimina contatto"); color: "#ef4444"; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.DemiBold }
            MouseArea { anchors.fill: parent; onClicked: conferma.open() }
        }
    }

    // ══ Conferma eliminazione ════════════════════════════════════════════
    Popup {
        id: conferma
        anchors.centerIn: parent
        width: parent.width - 60; modal: true; padding: 20
        background: Rectangle { radius: 20; color: app.sezione }
        Column {
            width: parent.width; spacing: 14
            Text { width: parent.width; wrapMode: Text.Wrap; text: I18n.t("Eliminare") + " " + (app.scelto ? app.scelto.nome : "") + "?"; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(18); font.weight: Font.Bold }
            Row {
                spacing: 10; anchors.right: parent.right
                Pulsante { text: I18n.t("Annulla"); onClicked: conferma.close() }
                Pulsante { text: I18n.t("Elimina"); pericoloso: true; onClicked: { ponte.chiama("eliminaContatto", [app.scelto.id]); conferma.close(); app.scelto = null; app.modifica = false; app.aggiorna(); tel.avviso(I18n.t("Contatto eliminato")) } }
            }
        }
    }

    // ══ Importa / esporta vCard ══════════════════════════════════════════
    Popup {
        id: vcard
        anchors.centerIn: parent
        width: parent.width - 40; modal: true; padding: 18
        background: Rectangle { radius: 20; color: app.sezione }
        property var file: []
        onOpened: file = ponte.chiama0("cercaVcard")
        Column {
            width: parent.width; spacing: 12
            Text { text: I18n.t("Rubrica in formato vCard"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(18); font.weight: Font.Bold }
            Text { width: parent.width; wrapMode: Text.Wrap; text: I18n.t("Dal vecchio telefono esporta i contatti in un file .vcf (Android: Contatti › Esporta; iPhone: da iCloud) e mettilo in Scaricati."); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13) }
            Repeater {
                model: vcard.file
                Rectangle {
                    required property var modelData
                    width: parent.width; height: 48; radius: 12; color: tel.pal.traccia
                    Text { x: 14; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 28; elide: Text.ElideMiddle; text: I18n.t("Importa") + " " + parent.modelData.nome + " (" + parent.modelData.cartella + ")"; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; onClicked: { var r = ponte.chiama("importaVcard", [parent.modelData.percorso]); tel.avviso(r.messaggio); vcard.close(); app.aggiorna() } }
                }
            }
            Text { visible: vcard.file.length === 0; text: I18n.t("Nessun file .vcf trovato"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13) }
            Row {
                spacing: 10; anchors.right: parent.right
                Pulsante { text: I18n.t("Chiudi"); onClicked: vcard.close() }
                Pulsante { text: I18n.t("Esporta tutti"); principale: true; onClicked: { var r = ponte.chiama0("esportaVcard"); tel.avviso(r.messaggio); vcard.close() } }
            }
        }
    }
}
