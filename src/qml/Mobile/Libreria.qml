// Libreria app: ricerca e app raggruppate per tipo (dalle categorie del menu di sistema).
// Ogni cartella mostra le prime tre app (si toccano direttamente) e, nel quarto
// riquadro, le altre in piccolo. Scrivendo nella ricerca compare l'elenco alfabetico.
// Misure compatte, come la Libreria app dell'iPhone (vedi docs/DESIGN.md).
import QtQuick
import QtQuick.Controls
import SolidUI

Item {
    id: lib
    property var cartelle: ponte.chiama0("libreria")
    property var tutte: ponte.chiama0("app")
    readonly property var trovate: campo.text ? tutte.filter(function (a) { return a.nome.toLowerCase().indexOf(campo.text.toLowerCase()) >= 0 }) : []
    // Misure compatte (come la Libreria dell'iPhone): margini 24, cartelle quadrate con
    // 3 icone grandi + un riquadro con 4 icone piccole, nome sotto in piccolo
    readonly property real margine: 24
    readonly property real spazio: 18
    readonly property real pad: 12
    readonly property real gap: 8
    // Le icone non superano quelle della Home: su uno schermo largo le cartelle restano
    // della loro misura e si mettono al centro (prima crescevano con lo schermo)
    readonly property real latoMini: Math.min(tel.latoIcona, Math.floor((Math.floor((width - 2 * margine - spazio) / 2) - 2 * pad - gap) / 2))
    readonly property real latoCartella: 2 * latoMini + 2 * pad + gap

    Rectangle {
        id: barraCerca
        x: Math.round((lib.width - width) / 2); y: 8
        width: 2 * lib.latoCartella + lib.spazio; height: 44; radius: 22
        color: "transparent"
        border.color: campo.activeFocus ? tel.pal.testo2 : tel.pal.bordo; border.width: 1
        Row {
            anchors.fill: parent; anchors.leftMargin: 16; spacing: 10
            Icona { nome: "system-search-symbolic"; lato: 17; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
            TextField {
                id: campo
                anchors.verticalCenter: parent.verticalCenter
                width: barraCerca.width - 48; height: parent.height
                leftPadding: 0; rightPadding: 0; topPadding: 0; bottomPadding: 0
                verticalAlignment: TextInput.AlignVCenter
                placeholderText: I18n.t("Libreria app")
                placeholderTextColor: tel.pal.testo2
                color: tel.pal.testo
                font.family: Tema.font; font.pixelSize: tel.px(15)
                background: Item {}
            }
        }
    }

    // Cartelle 2 per riga
    Flickable {
        visible: !campo.text
        anchors.top: barraCerca.bottom; anchors.topMargin: 20
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.bottomMargin: 30
        contentHeight: griglia.height + 20
        clip: true
        Grid {
            id: griglia
            x: Math.round((lib.width - 2 * lib.latoCartella - lib.spazio) / 2)
            columns: 2
            columnSpacing: lib.spazio; rowSpacing: lib.spazio
            Repeater {
                model: lib.cartelle
                Column {
                    id: casella
                    required property var modelData
                    spacing: 6
                    Vetro {
                        width: lib.latoCartella; height: width; radius: tel.r3
                        Grid {
                            x: lib.pad; y: lib.pad
                            columns: 2; spacing: lib.gap
                            // Le prime tre app (quattro, se la cartella ne ha al massimo quattro)
                            Repeater {
                                model: casella.modelData.app.slice(0, casella.modelData.app.length > 4 ? 3 : 4)
                                IconaApp {
                                    required property var modelData
                                    app: modelData; conNome: false; lato: lib.latoMini
                                    width: lib.latoMini
                                }
                            }
                            // Le altre app della cartella, in piccolo, nel quarto riquadro
                            Item {
                                visible: casella.modelData.app.length > 4
                                width: lib.latoMini; height: width
                                Grid {
                                    anchors.centerIn: parent
                                    columns: 2; spacing: 4
                                    Repeater {
                                        model: casella.modelData.app.slice(3, 7)
                                        Icona { required property var modelData; nome: modelData.icona; lato: Math.floor((lib.latoMini - 4) / 2) }
                                    }
                                }
                                MouseArea { anchors.fill: parent; onClicked: campo.forceActiveFocus() }
                            }
                        }
                    }
                    Text {
                        width: lib.latoCartella
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: casella.modelData.nome
                        color: tel.pal.testo2
                        font.family: Tema.font; font.pixelSize: tel.px(11); font.letterSpacing: 0.6
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
        anchors.leftMargin: lib.margine; anchors.rightMargin: lib.margine; anchors.bottomMargin: 30
        clip: true
        model: lib.trovate
        delegate: Item {
            id: riga
            required property var modelData
            width: ListView.view.width; height: 56
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14
                IconaApp { app: riga.modelData; conNome: false; lato: 40; width: 40 }
                Text { anchors.verticalCenter: parent.verticalCenter; text: riga.modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15) }
            }
            MouseArea { anchors.fill: parent; onClicked: tel.apri(riga.modelData) }
        }
    }
}
