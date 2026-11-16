// Libreria app: ricerca e app raggruppate per tipo (dalle categorie del menu di sistema).
// Ogni cartella mostra le prime tre app (si toccano direttamente) e, nel quarto
// riquadro, le altre in piccolo. Scrivendo nella ricerca compare l'elenco alfabetico.
import QtQuick
import QtQuick.Controls
import SolidUI

Item {
    id: lib
    property var cartelle: ponte.chiama0("libreria")
    property var tutte: ponte.chiama0("app")
    readonly property var trovate: campo.text ? tutte.filter(function (a) { return a.nome.toLowerCase().indexOf(campo.text.toLowerCase()) >= 0 }) : []
    readonly property real latoCartella: (width - 2 * tel.margine - 14) / 2
    readonly property real pad: 14
    readonly property real latoMini: (latoCartella - 2 * pad - 12) / 2

    Vetro {
        id: barraCerca
        x: tel.margine; y: 8
        width: parent.width - 2 * tel.margine; height: 44; radius: tel.r1 + 2
        Row {
            anchors.fill: parent; anchors.leftMargin: 14; spacing: 10
            Icona { nome: "system-search-symbolic"; lato: 18; anchors.verticalCenter: parent.verticalCenter }
            TextField {
                id: campo
                anchors.verticalCenter: parent.verticalCenter
                width: barraCerca.width - 56
                placeholderText: I18n.t("Cerca tra le app")
                placeholderTextColor: tel.pal.testo2
                color: tel.pal.testo
                font.family: Tema.font; font.pixelSize: tel.px(16)
                background: Item {}
            }
        }
    }

    // Cartelle 2 per riga
    Flickable {
        visible: !campo.text
        anchors.top: barraCerca.bottom; anchors.topMargin: 18
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.bottomMargin: 30
        contentHeight: griglia.height + 20
        clip: true
        Grid {
            id: griglia
            x: tel.margine
            columns: 2
            columnSpacing: 14; rowSpacing: 18
            Repeater {
                model: lib.cartelle
                Column {
                    id: casella
                    required property var modelData
                    spacing: 8
                    Vetro {
                        width: lib.latoCartella; height: width; radius: tel.r3
                        Grid {
                            x: lib.pad; y: lib.pad
                            columns: 2; spacing: 12
                            Repeater {
                                model: casella.modelData.app.slice(0, casella.modelData.app.length > 4 ? 3 : 4)
                                Rectangle {
                                    required property var modelData
                                    width: lib.latoMini; height: width; radius: Math.round(width * 0.27)
                                    color: tel.pal.tessera; border.color: tel.pal.vetroBordo
                                    Icona { anchors.centerIn: parent; nome: parent.modelData.icona; lato: Math.round(parent.width * 0.68) }
                                    MouseArea { anchors.fill: parent; onClicked: tel.apri(parent.modelData) }
                                }
                            }
                            // Le altre app della cartella, in piccolo, nel quarto riquadro
                            Rectangle {
                                visible: casella.modelData.app.length > 4
                                width: lib.latoMini; height: width; radius: Math.round(width * 0.27)
                                color: tel.pal.traccia
                                Grid {
                                    anchors.centerIn: parent
                                    columns: 2; spacing: 4
                                    Repeater {
                                        model: casella.modelData.app.slice(3, 7)
                                        Icona { required property var modelData; nome: modelData.icona; lato: Math.floor((lib.latoMini - 16) / 2) }
                                    }
                                }
                            }
                        }
                    }
                    Text {
                        width: lib.latoCartella
                        horizontalAlignment: Text.AlignHCenter
                        text: casella.modelData.nome
                        color: tel.pal.testo
                        font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.Medium
                    }
                }
            }
        }
    }

    // Risultati della ricerca
    ListView {
        visible: campo.text !== ""
        anchors.top: barraCerca.bottom; anchors.topMargin: 12
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.leftMargin: tel.margine; anchors.rightMargin: tel.margine; anchors.bottomMargin: 30
        clip: true
        model: lib.trovate
        delegate: Item {
            id: riga
            required property var modelData
            width: ListView.view.width; height: 60
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14
                IconaApp { app: riga.modelData; conNome: false; lato: 44 }
                Text { anchors.verticalCenter: parent.verticalCenter; text: riga.modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16) }
            }
            MouseArea { anchors.fill: parent; onClicked: tel.apri(riga.modelData) }
        }
    }
}
