// Note: elenco con ricerca (le fissate in alto) e scrittura a tutto schermo.
// Si salva da sola mentre scrivi; la prima riga è il titolo.
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: app
    color: tel.chiaro ? "#f2f3f8" : "#0e1118"
    property var elenco: []
    property string aperta: ""          // id della nota aperta ("" = elenco)
    property bool scrivendo: false
    property string cerca: ""
    readonly property color sezione: tel.chiaro ? "#ffffff" : "#1b1f2b"
    readonly property color linea: tel.chiaro ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.08)

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
        Text { x: 20; y: 56; text: I18n.t("Note"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(30); font.weight: Font.Bold }
        Rectangle {
            x: 16; y: 104; width: parent.width - 32; height: 40; radius: 12
            color: tel.chiaro ? "#e3e5ee" : "#1b1f2b"
            Icona { x: 12; anchors.verticalCenter: parent.verticalCenter; nome: "system-search-symbolic"; lato: 16 }
            TextField {
                x: 36; width: parent.width - 46; anchors.verticalCenter: parent.verticalCenter
                placeholderText: I18n.t("Cerca"); placeholderTextColor: tel.pal.testo2; color: tel.pal.testo
                font.family: Tema.font; font.pixelSize: tel.px(15)
                onTextChanged: { app.cerca = text; app.aggiorna() }
                background: Item {}
            }
        }
        ListView {
            x: 16; y: 158; width: parent.width - 32; height: parent.height - y - 30
            clip: true; spacing: 10
            model: app.elenco
            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width; height: colonna.implicitHeight + 24; radius: 16
                color: app.sezione
                Column {
                    id: colonna
                    x: 16; y: 12; width: parent.width - 32; spacing: 3
                    Row {
                        width: parent.width; spacing: 6
                        Text { visible: modelData.fissata; text: "📌"; font.pixelSize: 13 }
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
            width: 60; height: 60; radius: 30; color: tel.accento
            Text { anchors.centerIn: parent; text: "+"; color: "#ffffff"; font.pixelSize: 34; font.weight: Font.Light }
            MouseArea { anchors.fill: parent; onClicked: app.apri("") }
        }
    }

    // ══ Scrittura ════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: app.scrivendo
        Text {
            x: 18; y: 58
            text: "‹ " + I18n.t("Note"); color: tel.accento; font.family: Tema.font; font.pixelSize: tel.px(16)
            MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: app.chiudi() }
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 18; y: 58
            spacing: 22
            Text {
                text: I18n.t("Condividi"); color: tel.accento; font.family: Tema.font; font.pixelSize: tel.px(16)
                visible: testo.text !== ""
                MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: { app.salva(); tel.copia(testo.text); tel.avviso(I18n.t("Testo copiato")) } }
            }
            Text {
                text: I18n.t("Fine"); color: tel.accento; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.DemiBold
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
