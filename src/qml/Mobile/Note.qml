// Note: elenco con ricerca (le fissate in alto) e scrittura a tutto schermo.
// Si salva da sola mentre scrivi; la prima riga è il titolo.
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: app
    color: tel.pal.sfondo
    property var elenco: []
    property string aperta: ""          // id della nota aperta ("" = elenco)
    property bool scrivendo: false
    property string cerca: ""
    readonly property color sezione: tel.pal.superficie
    readonly property color linea: tel.pal.bordo

    function aggiorna() { elenco = ponte.chiama("note", [cerca]) }
    function apri(ident) {
        var n = ident ? ponte.chiama("leggiNota", [ident]) : { id: "", testo: "" }
        aperta = ident || "nuova"
        testo.text = n.testo || ""
        scrivendo = true
        if (!ident) testo.forceActiveFocus()
    }
    function salva() {
        if (!scrivendo) return
        var id = ponte.chiama("salvaNota", [aperta === "nuova" ? "" : aperta, testo.text])
        if (id) aperta = id
    }
    function chiudi() { salva(); scrivendo = false; aperta = ""; aggiorna() }
    onVisibleChanged: if (visible) aggiorna(); else if (scrivendo) salva()
    Component.onCompleted: aggiorna()
    Timer { id: salvataggio; interval: 800; onTriggered: app.salva() }

    // ══ Elenco ═══════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: !app.scrivendo
        Punti { x: 20; y: 60; text: I18n.t("Note"); font.pixelSize: 32 }
        CampoCerca {
            x: 16; y: 122; width: parent.width - 32
            onTextChanged: { app.cerca = text; app.aggiorna() }
        }
        ListView {
            x: 16; y: 180; width: parent.width - 32; height: parent.height - y - 30
            clip: true; spacing: 10
            model: app.elenco
            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width; height: colonna.implicitHeight + 24; radius: 22
                color: app.sezione
                Column {
                    id: colonna
                    x: 16; y: 12; width: parent.width - 32; spacing: 3
                    Row {
                        width: parent.width; spacing: 6
                        Simbolo { visible: modelData.fissata; nome: "puntina"; lato: 14; colore: tel.pal.testo2 }
                        Text { width: parent.width - 30; elide: Text.ElideRight; text: modelData.titolo; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.DemiBold }
                    }
                    Text { width: parent.width; elide: Text.ElideRight; text: modelData.quando + (modelData.anteprima ? "  " + modelData.anteprima : ""); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13) }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: app.apri(modelData.id)
                    onPressAndHold: { menuNota.ident = modelData.id; menuNota.fissata = modelData.fissata; menuNota.open() }
                }
            }
            Text {
                visible: app.elenco.length === 0
                anchors.horizontalCenter: parent.horizontalCenter; y: 60
                text: app.cerca ? I18n.t("Nessuna nota trovata") : I18n.t("Nessuna nota: tocca + per scriverne una")
                color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(14)
            }
        }
        // Nuova nota
        Rectangle {
            anchors.right: parent.right; anchors.rightMargin: 22
            anchors.bottom: parent.bottom; anchors.bottomMargin: 44
            width: 60; height: 60; radius: 30; color: tel.pal.pieno
            Icona { anchors.centerIn: parent; nome: "list-add-symbolic"; lato: 26; tema: tel.chiaro ? "scuro" : "chiaro" }
            MouseArea { anchors.fill: parent; onClicked: app.apri("") }
        }
    }

    // ══ Scrittura ════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: app.scrivendo
        Text {
            x: 18; y: 58
            text: "‹ " + I18n.t("Note"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16)
            MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: app.chiudi() }
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 18; y: 58
            spacing: 22
            Text {
                text: I18n.t("Condividi"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16)
                visible: testo.text !== ""
                MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: { app.salva(); tel.copia(testo.text); tel.avviso(I18n.t("Testo copiato")) } }
            }
            Text {
                text: I18n.t("Fine"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.DemiBold
                MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: app.chiudi() }
            }
        }
        Flickable {
            id: scorri
            x: 16; y: 100; width: parent.width - 32; height: parent.height - y - 30
            contentHeight: testo.implicitHeight + 40; clip: true
            TextArea.flickable: TextArea {
                id: testo
                wrapMode: TextArea.Wrap
                placeholderText: I18n.t("Scrivi qui…\nLa prima riga diventa il titolo.")
                placeholderTextColor: tel.pal.testo2
                color: tel.pal.testo; selectionColor: tel.accento
                font.family: Tema.font; font.pixelSize: tel.px(17)
                onTextChanged: if (app.scrivendo) salvataggio.restart()
                background: Item {}
            }
        }
    }

    // ── Menu con pressione lunga ─────────────────────────────────────────
    Popup {
        id: menuNota
        property string ident: ""
        property bool fissata: false
        anchors.centerIn: parent
        width: parent.width - 80; modal: true; padding: 6
        background: Rectangle { radius: 18; color: app.sezione }
        Column {
            width: parent.width
            Repeater {
                model: [{ k: "fissa", t: menuNota.fissata ? I18n.t("Togli dalle fissate") : I18n.t("Fissa in alto") },
                        { k: "elimina", t: I18n.t("Elimina") }]
                Item {
                    required property var modelData
                    width: parent.width; height: 50
                    Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.t; color: parent.modelData.k === "elimina" ? "#ef4444" : tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16) }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (parent.modelData.k === "fissa") ponte.chiama("fissaNota", [menuNota.ident, !menuNota.fissata])
                            else ponte.chiama("eliminaNota", [menuNota.ident])
                            menuNota.close(); app.aggiorna()
                        }
                    }
                }
            }
        }
    }
}
