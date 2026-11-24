// Web del telefono: lo stesso navigatore del PC (preferiti, cronologia e più visitati da
// nucleo/apps/web.py) con la barra dell'indirizzo in basso, a portata di pollice. Indietro,
// avanti, preferito, condividi e ricarica; la pagina iniziale con i preferiti e i più visitati.
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: app
    color: tel.pal.sfondo
    property string url: ""
    property var preferiti: []
    property var visitati: []
    property bool preferito: false
    function pc(m, a) { return ponte.chiama("appPc", ["web", m, a || []]) }
    function vai(testo) {
        var u = pc("indirizzo", [testo]); if (!u) return
        url = u; campo.focus = false
        if (pagina.item) pagina.item.url = u
    }
    function iniziale() { url = ""; preferiti = pc("preferiti") || []; visitati = pc("piuVisitati") || [] }
    Component.onCompleted: iniziale()
    onVisibleChanged: if (visible && !url) iniziale()

    // ── Pagina ───────────────────────────────────────────────────────────
    Loader {
        id: pagina
        anchors.fill: parent; anchors.topMargin: 44; anchors.bottomMargin: 110
        source: "WebVista.qml"
        visible: app.url !== "" && status === Loader.Ready
        Connections {
            target: pagina.item
            function onUrlChanged() { if (pagina.item.url.toString() && pagina.item.url.toString() !== "about:blank") { app.url = pagina.item.url.toString(); campo.text = app.url; app.preferito = app.pc("ePreferito", [app.url]) === true } }
            function onLoadingChanged(r) { if (r.status === 2) app.pc("visita", [pagina.item.url.toString(), pagina.item.title]) }
        }
    }
    Column {
        visible: app.url !== "" && pagina.status === Loader.Error
        anchors.centerIn: parent; width: parent.width - 60; spacing: 10
        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: I18n.t("Il motore web non è installato su questo telefono."); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 16 }
    }
    // Barra di caricamento
    Rectangle { visible: pagina.item && pagina.item.loading; y: 44; height: 3; color: tel.accento
                width: pagina.item ? parent.width * pagina.item.loadProgress / 100 : 0 }

    // ── Pagina iniziale ──────────────────────────────────────────────────
    Flickable {
        visible: app.url === ""
        anchors.fill: parent; anchors.topMargin: 54; anchors.bottomMargin: 110; contentHeight: inizio.height + 20; clip: true
        Column {
            id: inizio
            x: 16; width: parent.width - 32; spacing: 14
            Punti { text: I18n.t("Web") }
            Text { visible: app.preferiti.length > 0; text: I18n.t("Preferiti"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 20; font.weight: Font.Bold }
            Grid {
                columns: 4; spacing: 12
                Repeater {
                    model: app.preferiti.slice(0, 12)
                    Column {
                        required property var modelData
                        width: (inizio.width - 36) / 4; spacing: 6
                        Avatar { anchors.horizontalCenter: parent.horizontalCenter; lato: 56; nome: (modelData.titolo || modelData.url || "").replace(/^https?:\/\/(www\.)?/, "") }
                        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: modelData.titolo || modelData.url; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 12 }
                        MouseArea { width: parent.width; height: parent.height; onClicked: app.vai(parent.modelData.url) }
                    }
                }
            }
            Text { visible: app.visitati.length > 0; text: I18n.t("Più visitati"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 20; font.weight: Font.Bold }
            Rectangle {
                visible: app.visitati.length > 0
                width: parent.width; height: colV.height; radius: 20; color: tel.pal.superficie
                Column {
                    id: colV
                    width: parent.width
                    Repeater {
                        model: app.visitati.slice(0, 8)
                        Item {
                            required property var modelData
                            width: colV.width; height: 56
                            Column { x: 16; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 32
                                     Text { width: parent.width; elide: Text.ElideRight; text: modelData.titolo || modelData.url; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 15 }
                                     Text { width: parent.width; elide: Text.ElideRight; text: modelData.url; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 12 } }
                            MouseArea { anchors.fill: parent; onClicked: app.vai(modelData.url) }
                        }
                    }
                }
            }
            Text { visible: !app.preferiti.length && !app.visitati.length; width: parent.width; wrapMode: Text.Wrap; text: I18n.t("Scrivi un indirizzo o cosa cerchi nella barra qui sotto."); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 15 }
        }
    }

    // ── Barra in basso: indirizzo e comandi ──────────────────────────────
    Rectangle {
        anchors.bottom: parent.bottom; width: parent.width; height: 110; color: tel.pal.sfondo
        Rectangle { width: parent.width; height: 1; color: tel.pal.bordo; visible: !tel.solido }
        Rectangle {
            x: 12; y: 10; width: parent.width - 24; height: 44; radius: 22; color: tel.pal.superficie
            border.width: tel.solido ? 0 : 1; border.color: tel.pal.bordo
            Icona { x: 14; anchors.verticalCenter: parent.verticalCenter; nome: app.url.indexOf("https:") === 0 ? "linea-lucchetto" : "linea-cerca"; lato: 16; colore: tel.pal.testo2 }
            TextInput {
                id: campo
                x: 38; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 80
                color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 15; clip: true
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase
                onAccepted: app.vai(text)
                onActiveFocusChanged: if (activeFocus) selectAll()
                Text { visible: !campo.text; text: I18n.t("Cerca o scrivi un indirizzo"); color: tel.pal.testo3; font: campo.font }
            }
            Icona { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; visible: app.url !== ""
                    nome: pagina.item && pagina.item.loading ? "linea-chiudi" : "linea-freccia-giro"; lato: 18; colore: tel.pal.testo2
                    MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: pagina.item.loading ? pagina.item.stop() : pagina.item.reload() } }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter; y: 60
            Repeater {
                model: [{ k: "indietro", i: "go-previous-symbolic" }, { k: "avanti", i: "go-next-symbolic" }, { k: "preferito", i: "linea-stella" },
                        { k: "condividi", i: "linea-condividi" }, { k: "casa", i: "linea-casa" }]
                Item {
                    required property var modelData
                    width: (app.width - 24) / 5; height: 40
                    readonly property bool attivo: modelData.k === "casa" || (app.url !== "" && pagina.item &&
                        (modelData.k === "indietro" ? pagina.item.canGoBack : (modelData.k === "avanti" ? pagina.item.canGoForward : true)))
                    opacity: attivo ? 1 : 0.35
                    Icona { anchors.centerIn: parent; nome: parent.modelData.i; lato: 22
                            colore: parent.modelData.k === "preferito" && app.preferito ? "#F59E0B" : (tel.chiaro ? "#141414" : "#FFFFFF") }
                    MouseArea {
                        anchors.fill: parent; enabled: parent.attivo
                        onClicked: {
                            var k = parent.modelData.k
                            if (k === "indietro") pagina.item.goBack()
                            else if (k === "avanti") pagina.item.goForward()
                            else if (k === "preferito") { app.preferito = !app.preferito; app.pc("preferito", [app.url, pagina.item.title, app.preferito]); tel.avviso(app.preferito ? I18n.t("Aggiunto ai preferiti") : I18n.t("Tolto dai preferiti")) }
                            else if (k === "condividi") { ponte.chiama("copiaTesto", [app.url]); tel.avviso(I18n.t("Indirizzo copiato")) }
                            else { app.iniziale(); campo.text = "" }
                        }
                    }
                }
            }
        }
    }
}
