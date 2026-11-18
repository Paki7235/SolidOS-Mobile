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
        // Barra in alto come l'iPhone: «Elenchi» (rubrica vCard) e «+»
        Text {
            x: 16; y: 56; text: I18n.t("Elenchi"); color: tel.accento; font.family: Tema.font; font.pixelSize: tel.px(16)
            MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: vcard.open() }
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 16; y: 48
            text: "+"; color: tel.accento; font.family: Tema.font; font.pixelSize: 30; font.weight: Font.Light
            MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: app.nuovo() }
        }
        Punti { x: 18; y: 92; text: I18n.t("Contatti") }
        CampoCerca {
            x: 16; y: 146; width: parent.width - 46; height: 38; radius: 11
            suggerimento: I18n.t("Cerca tra") + " " + app.contatti.length + " " + I18n.t("contatti")
            onTextChanged: app.cerca = text.toLowerCase()
        }
        // La mia scheda (nome del Solid ID)
        Item {
            id: miaScheda
            x: 16; y: 198; width: parent.width - 46; height: app.cerca ? 0 : 84
            visible: !app.cerca
            readonly property string nome: (ponte.chiama0("solidId").nome || "") || I18n.t("Io")
            Avatar { y: 4; lato: 60; nome: miaScheda.nome }
            Column {
                x: 74; y: 14
                Text { text: miaScheda.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(19); font.weight: Font.Bold }
                Text { text: I18n.t("La mia scheda"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13) }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: app.linea }
        }
        // Indice delle lettere: tocca per saltare
        Column {
            anchors.right: parent.right; anchors.rightMargin: 4
            y: 206
            visible: !app.cerca && app.contatti.length > 0
            Repeater {
                model: "ABCDEFGHILMNOPQRSTUVZ#".split("")
                Text {
                    required property string modelData
                    width: 20; height: 13; horizontalAlignment: Text.AlignHCenter
                    text: modelData; color: tel.accento; font.family: Tema.font; font.pixelSize: 10; font.weight: Font.DemiBold
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -2
                        onClicked: {
                            var l = parent.modelData
                            for (var i = 0; i < app.filtrati.length; i++) {
                                var c = (app.filtrati[i].nome || "").charAt(0).toUpperCase()
                                if (l === "#" ? !/[A-Z]/.test(c) : c >= l) { elenco.positionViewAtIndex(i, ListView.Beginning); return }
                            }
                        }
                    }
                }
            }
        }
        ListView {
            id: elenco
            anchors.left: parent.left; anchors.leftMargin: 16; anchors.right: parent.right; anchors.rightMargin: 30
            anchors.top: miaScheda.bottom; anchors.topMargin: 6; anchors.bottom: parent.bottom; anchors.bottomMargin: 30
            clip: true
            model: app.filtrati
            section.property: "nome"
            section.criteria: ViewSection.FirstCharacter
            section.delegate: Text {
                required property string section
                height: 30; verticalAlignment: Text.AlignBottom; bottomPadding: 4
                text: section.toUpperCase()
                color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.Bold
            }
            delegate: Item {
                id: voce
                required property var modelData
                width: elenco.width; height: 44
                // Solo il nome, come la rubrica dell'iPhone
                Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width; elide: Text.ElideRight; text: voce.modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.Medium }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: app.linea }
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
        id: schedaContatto
        anchors.fill: parent
        visible: app.scelto !== null
        readonly property bool vista: !app.modifica
        // Testata a tutto schermo: la sfumatura del contatto, che sfuma nello sfondo
        Rectangle {
            visible: schedaContatto.vista
            width: parent.width; height: 440
            gradient: Gradient {
                GradientStop { position: 0; color: "#8B5CF6" }
                GradientStop { position: 0.6; color: "#4C7DFF" }
                GradientStop { position: 1; color: tel.pal.sfondo }
            }
            Avatar { id: copiaColori; visible: false; nome: app.scelto && app.scelto.nome ? app.scelto.nome : "" }
        }
        Text {
            x: 18; y: 60; text: "‹ " + I18n.t("Contatti"); color: schedaContatto.vista ? "#FFFFFF" : tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16)
            MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: { app.scelto = null; app.modifica = false } }
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 20; y: 60
            text: app.modifica ? I18n.t("Salva") : I18n.t("Modifica")
            color: schedaContatto.vista ? "#FFFFFF" : tel.accento; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.DemiBold
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
            Avatar { visible: app.modifica; anchors.horizontalCenter: parent.horizontalCenter; lato: 104; nome: app.scelto && app.scelto.nome ? app.scelto.nome : "+" }
            Rectangle {
                visible: !app.modifica
                anchors.horizontalCenter: parent.horizontalCenter
                width: 118; height: 118; radius: 59; color: "#38FFFFFF"
                Text { anchors.centerIn: parent; text: copiaColori.iniziali; color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: 44; font.weight: Font.DemiBold }
            }
            Item { width: 1; height: 4 }
            Text { visible: !app.modifica; anchors.horizontalCenter: parent.horizontalCenter; width: app.width - 40; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                   text: app.scelto ? app.scelto.nome : ""; color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(30); font.weight: Font.Bold }
            Text { visible: !app.modifica && text !== ""; anchors.horizontalCenter: parent.horizontalCenter; width: app.width - 40; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                   text: app.scelto ? (app.scelto.note || (app.scelto.preferito ? "★ " + I18n.t("Preferito") : "")) : ""; color: "#D9FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.Medium }
        }
        // Azioni rapide
        Row {
            visible: !app.modifica
            anchors.horizontalCenter: parent.horizontalCenter
            y: 338
            spacing: 8
            Repeater {
                model: [{ t: I18n.t("messaggio"), i: "mail-message-new-symbolic" }, { t: I18n.t("chiama"), i: "call-start-symbolic" },
                        { t: I18n.t("video"), i: "camera-photo-symbolic" }, { t: I18n.t("mail"), i: "document-send-symbolic" }]
                Rectangle {
                    id: azione
                    required property var modelData
                    required property int index
                    readonly property bool attiva: index < 2 || !!(index === 3 && app.scelto && app.scelto.email)
                    width: (app.width - 32 - 24) / 4; height: 62; radius: 14
                    color: "#2EFFFFFF"
                    opacity: attiva ? 1 : 0.45
                    Column {
                        anchors.centerIn: parent; spacing: 4
                        Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: azione.modelData.i; lato: 21; tema: "scuro" }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: azione.modelData.t; color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(11.5); font.weight: Font.Medium }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (azione.index === 0) { tel.appInterna = "messaggi"; messaggiApp.apri(app.scelto.numero) }
                            else if (azione.index === 1) tel.chiama(app.scelto.numero)
                            else if (azione.index === 2) tel.avviso(I18n.t("Le videochiamate arrivano più avanti"))
                            else if (app.scelto.email) Qt.openUrlExternally("mailto:" + app.scelto.email)
                        }
                    }
                }
            }
        }
        // Dettagli (lettura) o campi (modifica)
        Rectangle {
            visible: app.modifica
            x: 16; y: 210
            width: parent.width - 32; height: dettagli.implicitHeight + 8
            radius: 16; color: app.sezione
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
                        Text { x: 16; y: 30; visible: !app.modifica; text: app.scelto ? (app.scelto[parent.modelData.c] || "") : ""; color: parent.modelData.c === "note" ? tel.pal.testo : tel.accento; font.family: Tema.font; font.pixelSize: tel.px(16) }
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
        // Gruppi come la scheda dell'iPhone: numeri, email, compleanno, azioni
        Flickable {
            visible: !app.modifica
            x: 16; y: 420; width: parent.width - 32; height: parent.height - y - 24
            contentHeight: gruppi.height; clip: true
            component Gruppo: Rectangle {
                default property alias righe: colG.data
                width: gruppi.width; height: colG.height; radius: 14; color: app.sezione
                visible: colG.children.length > 0
                Column { id: colG; width: parent.width }
            }
            component Voce: Item {
                id: vo
                property string etichetta: ""
                property string valore: ""
                property bool cliccabile: true
                property bool prima: true
                signal tocco()
                width: gruppi.width; height: 64
                Rectangle { visible: !vo.prima; x: 16; width: parent.width - 16; height: 1; color: app.linea }
                Column {
                    x: 16; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                    Text { text: vo.etichetta; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.Medium }
                    Text { text: vo.valore; color: vo.cliccabile ? tel.accento : tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16) }
                }
                MouseArea { anchors.fill: parent; enabled: vo.cliccabile; onClicked: vo.tocco() }
            }
            component Azione: Item {
                id: az
                property string testo: ""
                property color colore: tel.accento
                property bool prima: true
                signal tocco()
                width: gruppi.width; height: 48
                Rectangle { visible: !az.prima; x: 16; width: parent.width - 16; height: 1; color: app.linea }
                Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: az.testo; color: az.colore; font.family: Tema.font; font.pixelSize: tel.px(16) }
                MouseArea { anchors.fill: parent; onClicked: az.tocco() }
            }
            Column {
                id: gruppi
                width: parent.width; spacing: 12
                Gruppo {
                    Voce { etichetta: I18n.t("cellulare"); valore: app.scelto ? app.scelto.numero || "" : ""; onTocco: tel.chiama(app.scelto.numero) }
                    Voce { visible: !!(app.scelto && app.scelto.numero2); prima: false; etichetta: I18n.t("casa"); valore: app.scelto ? app.scelto.numero2 || "" : ""; onTocco: tel.chiama(app.scelto.numero2) }
                }
                Gruppo {
                    visible: !!(app.scelto && app.scelto.email)
                    Voce { etichetta: I18n.t("email"); valore: app.scelto ? app.scelto.email || "" : ""; onTocco: Qt.openUrlExternally("mailto:" + app.scelto.email) }
                }
                Gruppo {
                    visible: !!(app.scelto && app.scelto.compleanno)
                    Voce { etichetta: I18n.t("compleanno"); valore: app.scelto ? app.scelto.compleanno || "" : ""; cliccabile: false }
                }
                Gruppo {
                    Azione { testo: I18n.t("Condividi contatto"); onTocco: { var r = ponte.chiama0("esportaVcard"); tel.avviso(r.messaggio) } }
                    Azione { prima: false; testo: app.scelto && app.scelto.preferito ? I18n.t("Togli dai preferiti") : I18n.t("Aggiungi ai preferiti")
                             onTocco: { ponte.chiama("preferito", [app.scelto.id, !app.scelto.preferito]); app.aggiorna() } }
                    Azione { prima: false; testo: I18n.t("Blocca questo contatto"); colore: tel.rosso; onTocco: tel.avviso(I18n.t("Il blocco dei numeri arriva con il telefono vero")) }
                }
            }
        }
        Rectangle {
            visible: app.modifica && app.scelto && app.scelto.id !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 50
            width: parent.width - 32; height: 48; radius: 14
            color: app.sezione
            Text { anchors.centerIn: parent; text: I18n.t("Elimina contatto"); color: tel.rosso; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.DemiBold }
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
