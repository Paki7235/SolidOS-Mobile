// Libreria app: ricerca e app raggruppate per tipo (dalle categorie del menu di sistema).
// Scrivendo nella ricerca compare l'elenco alfabetico filtrato.
import QtQuick
import QtQuick.Controls
import SolidUI

Item {
    id: lib
    property var cartelle: ponte.chiama0("libreria")
    property var tutte: ponte.chiama0("app")
    readonly property var trovate: campo.text ? tutte.filter(function (a) { return a.nome.toLowerCase().indexOf(campo.text.toLowerCase()) >= 0 }) : []

    Vetro {
        id: barraCerca
        x: 18; width: parent.width - 36; height: 44; radius: 14
        Row {
            anchors.fill: parent; anchors.leftMargin: 14; spacing: 8
            Icona { nome: "system-search-symbolic"; lato: 18; anchors.verticalCenter: parent.verticalCenter }
            TextField {
                id: campo
                anchors.verticalCenter: parent.verticalCenter
                width: barraCerca.width - 50
                placeholderText: I18n.t("Libreria app")
                placeholderTextColor: tel.pal.testo2
                color: tel.pal.testo
                font.family: Tema.font; font.pixelSize: tel.px(16)
                background: Item {}
            }
        }
    }

    // Cartelle 2×N
    Flickable {
        visible: !campo.text
        anchors.top: barraCerca.bottom; anchors.topMargin: 16
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.bottomMargin: 30
        contentHeight: griglia.height + 20
        clip: true
        Grid {
            id: griglia
            x: 18
            columns: 2
            columnSpacing: 16; rowSpacing: 14
            Repeater {
                model: lib.cartelle
                Column {
                    id: casella
                    required property var modelData
                    spacing: 6
                    Vetro {
                        width: (lib.width - 52) / 2; height: width; radius: 26
                        Grid {
                            anchors.centerIn: parent
                            columns: 2; spacing: 10
                            Repeater {
                                model: casella.modelData.app.slice(0, 3)
                                Item {
                                    required property var modelData
                                    width: (lib.width - 52) / 2 / 2 - 18; height: width
                                    Icona { anchors.fill: parent; nome: parent.modelData.icona; lato: parent.width }
                                    MouseArea { anchors.fill: parent; onClicked: tel.apri(parent.modelData) }
                                }
                            }
                            // Le altre app della cartella, in piccolo
                            Grid {
                                visible: casella.modelData.app.length > 3
                                columns: 2; spacing: 3
                                width: (lib.width - 52) / 2 / 2 - 18
                                Repeater {
                                    model: casella.modelData.app.slice(3, 7)
                                    Icona { required property var modelData; nome: modelData.icona; lato: ((lib.width - 52) / 2 / 2 - 21) / 2 }
                                }
                            }
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
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
        anchors.leftMargin: 18; anchors.rightMargin: 18; anchors.bottomMargin: 30
        clip: true
        model: lib.trovate
        delegate: Item {
            id: riga
            required property var modelData
            width: ListView.view.width; height: 56
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                Icona { nome: riga.modelData.icona; lato: 40 }
                Text { anchors.verticalCenter: parent.verticalCenter; text: riga.modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16) }
            }
            MouseArea { anchors.fill: parent; onClicked: tel.apri(riga.modelData) }
        }
    }
}
