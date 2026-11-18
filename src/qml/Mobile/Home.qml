// Home: due widget di vetro (Oggi e Batterie con gli anelli), la griglia delle app (senza
// ripetere quelle del Dock), la ricerca e il Dock di vetro. Scorrendo a sinistra si arriva
// alla Libreria app. Le righe di app sono quante ne entrano: mai sovrapposizioni.
import QtQuick
import QtQuick.Controls
import SolidUI

Item {
    id: home
    property alias pagina: pagine.currentIndex
    property var app: ponte.chiama0("home")
    property var dock: ponte.chiama0("dock")
    // Le app del Dock non si ripetono nella griglia
    readonly property var appGriglia: app.filter(function (a) { return !dock.some(function (d) { return d.id === a.id }) })
    property var dispositivi: []
    Component.onCompleted: ponte.avvia("dispositivi", [], "dispositivi")
    Connections {
        target: ponte
        function onCompletato(id, r) { if (id === "dispositivi") home.dispositivi = r }
    }
    readonly property int basso: tel.imp.navigazione === "tasti" ? 52 : 30   // spazio per la navigazione
    readonly property real cella: (width - 2 * tel.margine) / 4
    readonly property real altezzaCella: tel.latoIcona + 28 + 16
    readonly property int batteria: tel.stato && tel.stato.batteria ? tel.stato.batteria.livello : 100
    readonly property int notifiche: tel.elencoNotifiche ? tel.elencoNotifiche.length : 0
    // Un'app ha novità se c'è una sua notifica (puntino rosso sull'icona)
    function haNovita(a) { return (tel.elencoNotifiche || []).some(function (n) { return n.icona === a.icona }) }

    SwipeView {
        id: pagine
        anchors.fill: parent
        anchors.topMargin: 44

        // ── Pagina 1: Home ────────────────────────────────────────────────
        Item {
            id: paginaHome

            // Widget
            Row {
                id: cima
                x: tel.margine; y: 16
                spacing: 14
                readonly property real lato: (home.width - 2 * tel.margine - 14) / 2
                readonly property real alto: Math.min(160, Math.max(140, home.height * 0.185))

                // Oggi: giorno della settimana, numero del giorno e notifiche
                Vetro {
                    width: cima.lato; height: cima.alto; radius: 24
                    Column {
                        x: 16; y: 14; width: parent.width - 32
                        spacing: 0
                        Text { text: tel.adesso.toLocaleDateString(Qt.locale("it_IT"), "dddd").toUpperCase(); color: tel.accento; font.family: Tema.font; font.pixelSize: tel.px(12); font.weight: Font.Bold; font.letterSpacing: 0.4 }
                        Text { text: Qt.formatDate(tel.adesso, "d"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 54; font.weight: Font.DemiBold; font.letterSpacing: -2 }
                    }
                    Column {
                        x: 16; anchors.bottom: parent.bottom; anchors.bottomMargin: 14; width: parent.width - 32
                        Text { width: parent.width; elide: Text.ElideRight; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold
                               text: home.notifiche > 0 ? (tel.elencoNotifiche[0].titolo || "") : tel.adesso.toLocaleDateString(Qt.locale("it_IT"), "MMMM yyyy") }
                        Text { width: parent.width; elide: Text.ElideRight; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12); font.weight: Font.Medium
                               text: home.notifiche > 1 ? "+" + (home.notifiche - 1) + " " + I18n.t("notifiche") : (home.notifiche === 1 ? (tel.elencoNotifiche[0].app || "") : I18n.t("Nessuna notifica")) }
                    }
                    MouseArea { anchors.fill: parent; onClicked: tel.notifiche = true }
                }
                // Batterie: questo telefono e il PC collegato con il Solid ID, ad anello
                Vetro {
                    width: cima.lato; height: cima.alto; radius: 24
                    Text { x: 16; y: 14; text: I18n.t("Batterie"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom; anchors.bottomMargin: 14
                        spacing: 14
                        Repeater {
                            model: [{ i: "phone", l: home.batteria }].concat(home.dispositivi.slice(0, 1).map(function (d) { return { i: "computer-laptop", l: d.batteria } }))
                            Column {
                                required property var modelData
                                spacing: 4
                                Item {
                                    width: 56; height: 56
                                    Canvas {
                                        anchors.fill: parent
                                        property real l: parent.parent.modelData.l
                                        property color c: l <= 20 ? tel.rosso : tel.pal.successo
                                        property color f: tel.pal.traccia
                                        onLChanged: requestPaint()
                                        onFChanged: requestPaint()
                                        onPaint: {
                                            var g = getContext("2d"); g.reset(); g.lineWidth = 5; g.lineCap = "round"
                                            g.strokeStyle = f; g.beginPath(); g.arc(28, 28, 24, 0, 2 * Math.PI); g.stroke()
                                            g.strokeStyle = c; g.beginPath(); g.arc(28, 28, 24, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * l / 100); g.stroke()
                                        }
                                    }
                                    Icona { anchors.centerIn: parent; nome: parent.parent.modelData.i; lato: 20 }
                                }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.modelData.l + "%"; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                            }
                        }
                    }
                    MouseArea { anchors.fill: parent; onClicked: { tel.apri({ "id": "interno:impostazioni" }); impostazioniApp.apri("batteria") } }
                }
            }

            // Griglia: 4 colonne, tante righe quante ne entrano
            Grid {
                id: griglia
                x: tel.margine
                anchors.top: cima.bottom; anchors.topMargin: 26
                columns: 4
                readonly property real spazio: ricerca.y - 16 - (cima.y + cima.height + 26)
                readonly property int righe: Math.max(1, Math.min(4, Math.floor(spazio / home.altezzaCella)))
                Repeater {
                    model: home.appGriglia.slice(0, griglia.righe * 4)
                    Item {
                        required property var modelData
                        required property int index
                        width: home.cella; height: home.altezzaCella
                        IconaApp { anchors.horizontalCenter: parent.horizontalCenter; app: parent.modelData; nuovo: home.haNovita(parent.modelData); ritardo: 40 + parent.index * 30 }
                    }
                }
            }

            // Ricerca (porta alla Libreria)
            Vetro {
                id: ricerca
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: dockHome.top; anchors.bottomMargin: 16
                width: cerca.implicitWidth + 48; height: 32; radius: 16
                Row {
                    anchors.centerIn: parent; spacing: 7
                    Icona { nome: "system-search-symbolic"; lato: 14; anchors.verticalCenter: parent.verticalCenter }
                    Text { id: cerca; anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Cerca"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                }
                MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: pagine.currentIndex = 1 }
            }

            // Dock di vetro
            Vetro {
                id: dockHome
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 12; anchors.rightMargin: 12
                anchors.bottom: parent.bottom; anchors.bottomMargin: home.basso
                height: tel.latoIcona + 30; radius: 32
                Row {
                    anchors.left: parent.left; anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: home.dock
                        Item {
                            required property var modelData
                            required property int index
                            width: (dockHome.width - 12) / Math.max(4, home.dock.length); height: tel.latoIcona
                            IconaApp { anchors.horizontalCenter: parent.horizontalCenter; app: parent.modelData; conNome: false; nuovo: home.haNovita(parent.modelData); ritardo: parent.index * 30 }
                        }
                    }
                }
            }
        }

        // ── Pagina 2: Libreria app ────────────────────────────────────────
        Libreria {}
    }

    PageIndicator {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: home.basso + tel.latoIcona + 30 + 16 + 32 + 10
        count: pagine.count
        currentIndex: pagine.currentIndex
        visible: pagine.currentIndex === 0
        spacing: 6
        delegate: Rectangle { required property int index; width: 6; height: 6; radius: 3; color: tel.chiaro ? "#1D1D1F" : "#FFFFFF"; opacity: index === pagine.currentIndex ? 0.9 : 0.35 }
    }
}
