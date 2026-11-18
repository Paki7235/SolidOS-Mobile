// File: luoghi (Telefono, Documenti, Immagini, Musica, Video, Scaricati, microSD, Cestino),
// elenco delle cartelle, anteprima di immagini e testi, nuova cartella, rinomina,
// Cestino e Condividi con Vicina. Pressione lunga su un elemento per le azioni.
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: app
    color: tel.pal.sfondo
    property var luoghi: []
    property var cartella: ({ percorso: "", titolo: "", su: "", voci: [] })
    property bool inLuoghi: true
    property var anteprima: null         // voce aperta (immagine o testo)
    property string testoAnteprima: ""
    readonly property color sezione: tel.pal.superficie
    readonly property color linea: tel.pal.bordo

    function vai(percorso) { cartella = ponte.chiama("elencoFile", [percorso, false]); inLuoghi = false }
    function ricarica() { if (!inLuoghi) cartella = ponte.chiama("elencoFile", [cartella.percorso, false]) }
    function indietro() {
        if (anteprima) { anteprima = null; return }
        if (inLuoghi) return
        if (cartella.su) vai(cartella.su); else inLuoghi = true
    }
    function apri(v) {
        if (v.tipo === "cartella") vai(v.percorso)
        else if (v.tipo === "immagine") anteprima = v
        else if (v.tipo === "testo") { testoAnteprima = ponte.chiama("leggiTesto", [v.percorso]); anteprima = v }
        else if (v.tipo === "audio") { tel.appInterna = "musica"; tel.branoDaSuonare = v.percorso }
        else tel.avviso(I18n.t("Nessuna app per aprire questo file"))
    }
    onVisibleChanged: if (visible) { luoghi = ponte.chiama0("luoghiFile"); ricarica() }
    Component.onCompleted: luoghi = ponte.chiama0("luoghiFile")

    // ── Intestazione ─────────────────────────────────────────────────────
    Text {
        visible: !app.inLuoghi
        x: 18; y: 58
        text: "‹ " + (app.cartella.su ? I18n.t("Indietro") : I18n.t("Luoghi")); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16)
        MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: app.indietro() }
    }
    Text {
        visible: !app.inLuoghi
        anchors.right: parent.right; anchors.rightMargin: 20; y: 58
        text: I18n.t("Nuova cartella"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16)
        MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: { campo.modo = "cartella"; campo.voce = null; campo.open() } }
    }
    Text {
        x: 20; y: app.inLuoghi ? 60 : 86
        width: parent.width - 40; elide: Text.ElideRight
        text: app.inLuoghi ? I18n.t("File") : app.cartella.titolo
        color: tel.pal.testo; font.family: Tema.font; font.pixelSize: app.inLuoghi ? 32 : 28; font.weight: Font.Bold; font.letterSpacing: -0.6
    }

    // ── Luoghi ───────────────────────────────────────────────────────────
    Rectangle {
        visible: app.inLuoghi
        x: 16; y: 120; width: parent.width - 32; radius: 22
        height: colLuoghi.height; color: app.sezione; border.width: 1; border.color: tel.pal.bordo
        Column {
            id: colLuoghi
            width: parent.width
            Repeater {
                model: app.luoghi
                Item {
                    required property var modelData
                    required property int index
                    width: colLuoghi.width; height: 54
                    Icona { x: 18; anchors.verticalCenter: parent.verticalCenter; nome: modelData.icona; lato: 22 }
                    Text { x: 56; anchors.verticalCenter: parent.verticalCenter; text: modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16) }
                    Text { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: "›"; color: tel.pal.testo2; font.pixelSize: 24 }
                    Rectangle { visible: index < app.luoghi.length - 1; anchors.bottom: parent.bottom; x: 56; width: parent.width - 56; height: 1; color: app.linea }
                    MouseArea { anchors.fill: parent; onClicked: app.vai(modelData.percorso) }
                }
            }
        }
    }

    // ── Contenuto della cartella ─────────────────────────────────────────
    ListView {
        visible: !app.inLuoghi
        x: 16; y: 134; width: parent.width - 32; height: parent.height - y - 30
        clip: true
        model: app.cartella.voci
        delegate: Item {
            required property var modelData
            width: ListView.view.width; height: 62
            Item {
                x: 4; width: 40; height: 40; anchors.verticalCenter: parent.verticalCenter
                Icona { anchors.centerIn: parent; visible: modelData.uri === ""; nome: modelData.icona; lato: 36 }
                Image {
                    anchors.fill: parent; visible: modelData.uri !== ""
                    source: modelData.uri; sourceSize.width: 80; sourceSize.height: 80
                    fillMode: Image.PreserveAspectCrop; asynchronous: true
                }
            }
            Column {
                x: 56; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 60; spacing: 2
                Text { width: parent.width; elide: Text.ElideMiddle; text: modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15) }
                Text { text: modelData.info; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }
            }
            Rectangle { anchors.bottom: parent.bottom; x: 56; width: parent.width - 56; height: 1; color: app.linea }
            MouseArea {
                anchors.fill: parent
                onClicked: app.apri(modelData)
                onPressAndHold: { azioni.voce = modelData; azioni.open() }
            }
        }
        Text {
            visible: app.cartella.voci.length === 0
            anchors.horizontalCenter: parent.horizontalCenter; y: 40
            text: I18n.t("Cartella vuota"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(14)
        }
    }

    // ── Anteprima ────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        visible: app.anteprima !== null
        color: app.anteprima && app.anteprima.tipo === "immagine" ? "#000000" : app.color
        MouseArea { anchors.fill: parent }
        Image {
            anchors.fill: parent; anchors.topMargin: 100; anchors.bottomMargin: 60
            visible: app.anteprima !== null && app.anteprima.tipo === "immagine"
            source: visible ? "file://" + app.anteprima.percorso : ""
            fillMode: Image.PreserveAspectFit; asynchronous: true
            sourceSize.width: 1200
        }
        Flickable {
            visible: app.anteprima !== null && app.anteprima.tipo === "testo"
            x: 16; y: 100; width: parent.width - 32; height: parent.height - y - 30
            contentHeight: testoA.implicitHeight; clip: true
            Text { id: testoA; width: parent.width; wrapMode: Text.Wrap; text: app.testoAnteprima; textFormat: Text.PlainText; color: tel.pal.testo; font.family: "monospace"; font.pixelSize: tel.px(13) }
        }
        Text {
            x: 18; y: 58
            text: "‹ " + I18n.t("Indietro"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16)
            MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: app.anteprima = null }
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 20; y: 58
            text: I18n.t("Condividi"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16)
            MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: tel.condividi([app.anteprima.percorso]) }
        }
    }

    // ── Azioni (pressione lunga) ─────────────────────────────────────────
    Popup {
        id: azioni
        property var voce: null
        anchors.centerIn: parent
        width: parent.width - 80; modal: true; padding: 6
        background: Rectangle { radius: 18; color: app.sezione }
        Column {
            width: parent.width
            Text { x: 16; width: parent.width - 32; topPadding: 10; bottomPadding: 6; elide: Text.ElideMiddle; text: azioni.voce ? azioni.voce.nome : ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13) }
            Repeater {
                model: [{ k: "condividi", t: I18n.t("Condividi con Vicina") }, { k: "rinomina", t: I18n.t("Rinomina") }, { k: "cestino", t: I18n.t("Sposta nel Cestino") }]
                Item {
                    required property var modelData
                    visible: modelData.k !== "condividi" || (azioni.voce && azioni.voce.tipo !== "cartella")
                    width: parent.width; height: visible ? 50 : 0
                    Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.t; color: parent.modelData.k === "cestino" ? "#ef4444" : tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16) }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            var v = azioni.voce, k = parent.modelData.k
                            azioni.close()
                            if (k === "condividi") tel.condividi([v.percorso])
                            else if (k === "rinomina") { campo.modo = "rinomina"; campo.voce = v; campo.open() }
                            else { var r = ponte.chiama("cestinaFile", [v.percorso]); tel.avviso(r.messaggio); app.ricarica() }
                        }
                    }
                }
            }
        }
    }
    // ── Nome (nuova cartella o rinomina) ─────────────────────────────────
    Popup {
        id: campo
        property string modo: "cartella"
        property var voce: null
        anchors.centerIn: parent
        width: parent.width - 40; modal: true; padding: 18
        background: Rectangle { radius: 20; color: app.sezione }
        onOpened: { campoNome.text = voce ? voce.nome : ""; campoNome.forceActiveFocus() }
        Column {
            width: parent.width; spacing: 12
            Text { text: campo.modo === "cartella" ? I18n.t("Nuova cartella") : I18n.t("Rinomina"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(17); font.weight: Font.Bold }
            CampoTesto { id: campoNome; width: parent.width; placeholderText: I18n.t("Nome"); onAccepted: ok.clicked() }
            Row {
                spacing: 10; anchors.right: parent.right
                Pulsante { text: I18n.t("Annulla"); onClicked: campo.close() }
                Pulsante {
                    id: ok
                    text: I18n.t("Fatto"); principale: true
                    onClicked: {
                        var r = campo.modo === "cartella" ? ponte.chiama("nuovaCartella", [app.cartella.percorso, campoNome.text])
                                                         : ponte.chiama("rinominaFile", [campo.voce.percorso, campoNome.text])
                        if (!r.ok) { tel.avviso(r.messaggio); return }
                        campo.close(); app.ricarica()
                    }
                }
            }
        }
    }
}
