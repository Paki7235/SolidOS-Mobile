// Home: widget, griglia di app, ricerca e Dock. Scorrendo a sinistra si arriva alla Libreria app.
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

    SwipeView {
        id: pagine
        anchors.fill: parent
        anchors.topMargin: 56

        // ── Pagina 1: Home ────────────────────────────────────────────────
        Item {
            Row {
                id: widget
                x: 22; spacing: 16
                Vetro {
                    width: (home.width - 60) / 2; height: 154; radius: 24
                    Column {
                        anchors.fill: parent; anchors.margins: 14
                        spacing: 4
                        Text { text: tel.adesso.toLocaleDateString(Qt.locale("it_IT"), "dddd"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.DemiBold; font.capitalization: Font.Capitalize }
                        Text { text: Qt.formatDate(tel.adesso, "d"); color: tel.pal.testo; font.family: tel.fontOra; font.pixelSize: 56; font.weight: Font.Bold; height: 66 }
                        Text { text: tel.adesso.toLocaleDateString(Qt.locale("it_IT"), "MMMM yyyy"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13); font.capitalization: Font.Capitalize }
                    }
                }
                Vetro {
                    width: (home.width - 60) / 2; height: 154; radius: 24
                    Column {
                        anchors.fill: parent; anchors.margins: 14
                        spacing: 9
                        Text { text: I18n.t("Dispositivi"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12); font.weight: Font.DemiBold }
                        Row {
                            spacing: 8
                            Rectangle { width: 12; height: 18; radius: 3; color: "transparent"; border.color: tel.pal.testo; border.width: 2 }
                            Text { width: 70; text: I18n.t("Telefono"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13); elide: Text.ElideRight }
                            Text { text: (tel.stato.batteria ? tel.stato.batteria.livello : 100) + "%"; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                        }
                        Repeater {
                            model: home.dispositivi
                            Row {
                                required property var modelData
                                spacing: 8
                                Icona { nome: parent.modelData.tipo === "portatile" ? "computer-laptop" : "computer"; lato: 18 }
                                Text { width: 70; text: parent.modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13); elide: Text.ElideRight }
                                Text { text: parent.modelData.batteria + "%"; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                            }
                        }
                        Text { visible: home.dispositivi.length === 0; width: parent.width; wrapMode: Text.Wrap; text: I18n.t("Accedi al Solid ID per vedere qui anche il PC"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(11) }
                    }
                }
            }

            Grid {
                anchors.top: widget.bottom; anchors.topMargin: 24
                anchors.horizontalCenter: parent.horizontalCenter
                columns: 4
                rowSpacing: 18
                columnSpacing: Math.max(4, (home.width - 36 - 4 * (tel.latoIcona + 22)) / 3)
                Repeater {
                    model: home.app.slice(0, tel.imp.icone === 2 ? 8 : 12)
                    IconaApp { required property var modelData; app: modelData }
                }
            }

            Vetro {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: dockHome.top; anchors.bottomMargin: 14
                width: cerca.implicitWidth + 44; height: 30; radius: 15
                Row {
                    anchors.centerIn: parent; spacing: 6
                    Icona { nome: "system-search-symbolic"; lato: 14; anchors.verticalCenter: parent.verticalCenter }
                    Text { id: cerca; text: I18n.t("Cerca"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(12); font.weight: Font.Medium }
                }
                MouseArea { anchors.fill: parent; onClicked: pagine.currentIndex = 1 }
            }

            Vetro {
                id: dockHome
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 14; anchors.rightMargin: 14
                anchors.bottom: parent.bottom; anchors.bottomMargin: tel.imp.navigazione === "tasti" ? 48 : 28
                height: tel.latoIcona + 28; radius: 32
                Row {
                    anchors.centerIn: parent
                    spacing: Math.max(6, (parent.width - 4 * (tel.latoIcona + 22)) / 5)
                    Repeater {
                        model: home.dock
                        IconaApp { required property var modelData; app: modelData; conNome: false }
                    }
                }
            }
        }

        // ── Pagina 2: Libreria app ────────────────────────────────────────
        Libreria {}
    }

    PageIndicator {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: tel.latoIcona + (tel.imp.navigazione === "tasti" ? 82 : 62)
        count: pagine.count
        currentIndex: pagine.currentIndex
        visible: pagine.currentIndex === 0
        delegate: Rectangle { required property int index; width: 7; height: 7; radius: 4; color: tel.pal.testo; opacity: index === pagine.currentIndex ? 0.95 : 0.35 }
    }
}
