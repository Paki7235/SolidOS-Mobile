// Personalizza: tema, grandezza del testo, colore, sfondo, orologio del blocco,
// grandezza delle icone e navigazione. Ogni scelta si salva e cambia subito il telefono.
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: pers
    color: tel.pal.sfondo
    readonly property color sezione: tel.pal.superficie
    readonly property color spento: tel.pal.superficie2

    component Scelta: Rectangle {
        id: sc
        property string testo: ""
        property bool attiva: false
        property string carattere: Tema.font
        property int misura: tel.px(14)
        signal scelta()
        height: 40; radius: 20
        width: et.implicitWidth + 30
        color: attiva ? tel.accento : pers.spento
        Behavior on color { ColorAnimation { duration: tel.tVeloce } }
        Text { id: et; anchors.centerIn: parent; text: sc.testo; color: sc.attiva ? "#FFFFFF" : tel.pal.testo; font.family: sc.carattere; font.pixelSize: sc.misura; font.weight: Font.DemiBold }
        MouseArea { anchors.fill: parent; onClicked: sc.scelta() }
    }
    component Sezione: Rectangle {
        property string titolo: ""
        default property alias contenuto: riga.data
        width: parent.width; height: colonna.implicitHeight + 28; radius: 16
        color: pers.sezione
        Column {
            id: colonna
            x: 16; y: 14; width: parent.width - 32
            spacing: 12
            Mono { text: parent.parent.titolo }
            Flow { id: riga; width: parent.width; spacing: 8 }
        }
    }

    TitoloApp {
        testo: I18n.t("Personalizza")
        TastoTondo { icona: "go-up-symbolic"; rotation: 180; onTocco: tel.personalizza = false }
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: 122; anchors.bottomMargin: 20
        contentHeight: elenco.height + 20
        clip: true
        Column {
            id: elenco
            x: 14; width: pers.width - 28
            spacing: 10
            Sezione {
                titolo: I18n.t("Tema")
                Scelta { testo: I18n.t("Scuro"); attiva: !tel.chiaro; onScelta: tel.imposta("tema", "scuro") }
                Scelta { testo: I18n.t("Chiaro"); attiva: tel.chiaro; onScelta: tel.imposta("tema", "chiaro") }
            }
            Sezione {
                titolo: I18n.t("Grandezza del testo")
                Repeater {
                    model: [{ t: I18n.t("Piccolo"), m: 12 }, { t: I18n.t("Normale"), m: 15 }, { t: I18n.t("Grande"), m: 18 }]
                    Scelta { required property var modelData; required property int index; testo: modelData.t; misura: modelData.m; attiva: tel.imp.testo === index; onScelta: tel.imposta("testo", index) }
                }
            }
            Sezione {
                titolo: I18n.t("Colore")
                Repeater {
                    model: ["#4C7DFF", "#8B5CF6", "#12B886", "#FF7A3D", "#E8467C", "#6B7385"]
                    Rectangle {
                        required property string modelData
                        width: 38; height: 38; radius: 19
                        color: modelData
                        border.width: tel.accento.toString().toUpperCase() === modelData ? 3 : 1
                        border.color: tel.accento.toString().toUpperCase() === modelData ? tel.pal.testo3 : tel.pal.bordo
                        MouseArea { anchors.fill: parent; onClicked: tel.imposta("accento", parent.modelData) }
                    }
                }
            }
            Sezione {
                titolo: I18n.t("Sfondo")
                Repeater {
                    model: ["notte", "alba", "oceano", "aurora", "grafite"]
                    Rectangle {
                        required property string modelData
                        width: 56; height: 96; radius: 12
                        color: "transparent"
                        border.width: 3
                        border.color: tel.nomeSfondo === modelData && !(tel.imp.sfondo || "").startsWith("/") ? tel.accento : "transparent"
                        clip: true
                        // Anteprima: lo stesso sfondo disegnato del telefono, in piccolo
                        // Anteprima: lo stesso sfondo del PC, in piccolo
                        Image {
                            anchors.fill: parent; anchors.margins: 3
                            source: ponte.chiama("sfondo", [parent.modelData, tel.chiaro])
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.height: 200
                        }
                        MouseArea { anchors.fill: parent; onClicked: tel.imposta("sfondo", parent.modelData) }
                    }
                }
            }
            Sezione {
                titolo: I18n.t("Orologio del blocco")
                Repeater {
                    model: [{ t: I18n.t("Moderno"), f: "Inter" }, { t: I18n.t("Morbido"), f: "Plus Jakarta Sans" }, { t: I18n.t("Elegante"), f: "Noto Serif" }]
                    Scelta { required property var modelData; testo: modelData.t; carattere: modelData.f; misura: tel.px(16); attiva: tel.fontOra === modelData.f; onScelta: tel.imposta("orologio", modelData.f) }
                }
            }
            Sezione {
                titolo: I18n.t("Icone")
                Repeater {
                    model: [I18n.t("Piccole"), I18n.t("Normali"), I18n.t("Grandi")]
                    Scelta { required property string modelData; required property int index; testo: modelData; attiva: (tel.imp.icone === undefined ? 1 : tel.imp.icone) === index; onScelta: tel.imposta("icone", index) }
                }
            }
            // Stile delle icone: Colori, Scure, Tinta (colore del tema)
            Sezione {
                titolo: I18n.t("Stile delle icone")
                Repeater {
                    model: [{ k: "colori", t: I18n.t("Colori") }, { k: "scure", t: I18n.t("Scure") }, { k: "tinta", t: I18n.t("Tinta") }]
                    Rectangle {
                        id: prova
                        required property var modelData
                        readonly property bool attiva: (tel.imp.stile_icone || "colori") === modelData.k
                        width: (elenco.width - 32 - 16) / 3; height: 132; radius: 16; clip: true
                        color: "transparent"
                        border.width: attiva ? 3 : 0; border.color: tel.accento
                        Image {
                            anchors.fill: parent; anchors.margins: prova.attiva ? 3 : 0
                            source: ponte.chiama("sfondo", [tel.nomeSfondo, tel.chiaro]); fillMode: Image.PreserveAspectCrop
                            sourceSize.height: 260
                        }
                        Grid {
                            anchors.centerIn: parent; anchors.verticalCenterOffset: -8
                            columns: 2; spacing: 8
                            Repeater {
                                model: ["telefono", "messaggi", "foto", "note"]
                                IconaApp { required property string modelData; app: ({ icona: "nucleo-" + modelData, nome: "" }); conNome: false; lato: 34; stileForzato: prova.modelData.k; width: 34; enabled: false }
                            }
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 8; text: prova.modelData.t; color: "#FFFFFF"; style: Text.Raised; styleColor: "#66000000"; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                        MouseArea { anchors.fill: parent; onClicked: tel.imposta("stile_icone", prova.modelData.k) }
                    }
                }
            }
            Sezione {
                titolo: I18n.t("Navigazione")
                Scelta { testo: I18n.t("Gesti"); attiva: tel.imp.navigazione !== "tasti"; onScelta: tel.imposta("navigazione", "gesti") }
                Scelta { testo: I18n.t("Tre tasti"); attiva: tel.imp.navigazione === "tasti"; onScelta: tel.imposta("navigazione", "tasti") }
            }
        }
    }
}
