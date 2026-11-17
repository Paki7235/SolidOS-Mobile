// Home: due schede (data, batterie dei dispositivi), griglia di app ordinata, ricerca e Dock.
// Scorrendo a sinistra si arriva alla Libreria app. Le misure si adattano all'altezza
// dello schermo: su un telefono più basso ci sono meno righe, mai sovrapposizioni.
import QtQuick
import QtQuick.Controls
import SolidUI

Item {
    id: home
    property alias pagina: pagine.currentIndex
    property var app: ponte.chiama0("home")
    property var dock: ponte.chiama0("dock")
    property var dispositivi: []
    Component.onCompleted: ponte.avvia("dispositivi", [], "dispositivi")
    Connections {
        target: ponte
        function onCompletato(id, r) { if (id === "dispositivi") home.dispositivi = r }
    }
    readonly property int basso: tel.imp.navigazione === "tasti" ? 52 : 30   // spazio per la navigazione
    readonly property real cella: (width - 2 * tel.margine) / 4
    readonly property real altezzaCella: tel.latoIcona + 26 + 18

    SwipeView {
        id: pagine
        anchors.fill: parent
        anchors.topMargin: 44

        // ── Pagina 1: Home ────────────────────────────────────────────────
        Item {
            id: paginaHome
            // Schede
            Row {
                id: schede
                x: tel.margine; y: 8
                spacing: 12
                readonly property real lato: (home.width - 2 * tel.margine - 12) / 2
                readonly property real alto: Math.min(150, Math.max(120, home.height * 0.17))

                // Data
                Vetro {
                    width: schede.lato; height: schede.alto
                    Column {
                        x: 16; y: 14; width: parent.width - 32
                        spacing: 2
                        Text { text: tel.adesso.toLocaleDateString(Qt.locale("it_IT"), "dddd"); color: tel.accento; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold; font.capitalization: Font.Capitalize }
                        Text { text: Qt.formatDate(tel.adesso, "d"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 46; font.weight: Font.Light; height: 54 }
                    }
                    Text {
                        x: 16; anchors.bottom: parent.bottom; anchors.bottomMargin: 14
                        text: tel.adesso.toLocaleDateString(Qt.locale("it_IT"), "MMMM yyyy")
                        color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13); font.capitalization: Font.Capitalize
                    }
                }
                // Batterie: questo telefono e i dispositivi del Solid ID
                Vetro {
                    width: schede.lato; height: schede.alto
                    Column {
                        x: 16; y: 14; width: parent.width - 32
                        spacing: 10
                        Text { text: I18n.t("Batterie"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12); font.weight: Font.DemiBold }
                        Repeater {
                            model: [{ nome: I18n.t("Telefono"), livello: tel.stato.batteria ? tel.stato.batteria.livello : 100 }].concat(
                                       home.dispositivi.slice(0, 2).map(function (d) { return { nome: d.nome, livello: d.batteria } }))
                            Column {
                                required property var modelData
                                width: parent.width; spacing: 4
                                Item {
                                    width: parent.width; height: 16
                                    Text { width: parent.width - 40; elide: Text.ElideRight; text: parent.parent.modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13) }
                                    Text { anchors.right: parent.right; text: parent.parent.modelData.livello + "%"; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                                }
                                Rectangle {
                                    width: parent.width; height: 4; radius: 2; color: tel.pal.traccia
                                    Rectangle { width: parent.width * Math.max(0, Math.min(100, parent.parent.modelData.livello)) / 100; height: 4; radius: 2
                                                color: parent.parent.modelData.livello <= 20 ? tel.pal.pericolo : tel.pal.successo }
                                }
                            }
                        }
                    }
                    Text {
                        visible: home.dispositivi.length === 0
                        x: 16; width: parent.width - 32
                        anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                        wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                        text: I18n.t("Con il Solid ID qui vedi anche il PC")
                        color: tel.pal.testo3; font.family: Tema.font; font.pixelSize: tel.px(11)
                    }
                }
            }

            // Griglia: 4 colonne uguali, tante righe quante ne entrano
            Grid {
                id: griglia
                x: tel.margine
                anchors.top: schede.bottom; anchors.topMargin: 22
                columns: 4
                readonly property real spazio: dockHome.y - 58 - (schede.y + schede.height + 22)
                readonly property int righe: Math.max(1, Math.min(tel.imp.icone === 2 ? 2 : 3, Math.floor(spazio / home.altezzaCella)))
                Repeater {
                    model: home.app.slice(0, griglia.righe * 4)
                    Item {
                        required property var modelData
                        required property int index
                        width: home.cella; height: home.altezzaCella
                        IconaApp { anchors.horizontalCenter: parent.horizontalCenter; app: parent.modelData; ritardo: 60 + parent.index * 35 }
                    }
                }
            }

            // Ricerca (porta alla Libreria) e indicatore delle pagine
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: dockHome.top; anchors.bottomMargin: 14
                spacing: 10
                Vetro {
                    width: cerca.implicitWidth + 46; height: 32; radius: 16
                    Row {
                        anchors.centerIn: parent; spacing: 7
                        Icona { nome: "system-search-symbolic"; lato: 14; anchors.verticalCenter: parent.verticalCenter }
                        Text { id: cerca; text: I18n.t("Cerca"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.Medium }
                    }
                    MouseArea { anchors.fill: parent; onClicked: pagine.currentIndex = 1 }
                }
            }

            // Dock
            Vetro {
                id: dockHome
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: tel.margine - 6; anchors.rightMargin: tel.margine - 6
                anchors.bottom: parent.bottom; anchors.bottomMargin: home.basso
                height: tel.latoIcona + 24; radius: tel.r3 + 4
                Row {
                    anchors.left: parent.left; anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: home.dock
                        Item {
                            required property var modelData
                            required property int index
                            width: (dockHome.width - 12) / Math.max(4, home.dock.length); height: tel.latoIcona
                            IconaApp { anchors.horizontalCenter: parent.horizontalCenter; app: parent.modelData; conNome: false; ritardo: parent.index * 35 }
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
        anchors.bottomMargin: home.basso + tel.latoIcona + 24 + 14 + 32 + 10
        count: pagine.count
        currentIndex: pagine.currentIndex
        visible: pagine.currentIndex === 0
        spacing: 6
        delegate: Rectangle { required property int index; width: index === pagine.currentIndex ? 16 : 6; height: 6; radius: 3; color: tel.pal.testo; opacity: index === pagine.currentIndex ? 0.9 : 0.3 }
    }
}
