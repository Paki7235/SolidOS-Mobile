// Personalizza: tema, grandezza del testo, colore, sfondo, orologio del blocco,
// grandezza delle icone e navigazione. Ogni scelta si salva e cambia subito il telefono.
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: pers
    color: tel.chiaro ? "#f2f3f8" : "#0e1118"
    readonly property color sezione: tel.chiaro ? "#ffffff" : "#1b1f2b"
    readonly property color spento: tel.chiaro ? "#e6e8f0" : "#2a2f3d"

    component Scelta: Rectangle {
        id: sc
        property string testo: ""
        property bool attiva: false
        property string carattere: Tema.font
        property int misura: tel.px(14)
        signal scelta()
        height: 38; radius: 12
        width: et.implicitWidth + 26
        color: attiva ? tel.accento : pers.spento
        Text { id: et; anchors.centerIn: parent; text: sc.testo; color: sc.attiva ? "#ffffff" : tel.pal.testo; font.family: sc.carattere; font.pixelSize: sc.misura; font.weight: Font.DemiBold }
        MouseArea { anchors.fill: parent; onClicked: sc.scelta() }
    }
    component Sezione: Rectangle {
        property string titolo: ""
        default property alias contenuto: riga.data
        width: parent.width; height: colonna.implicitHeight + 24; radius: 18
        color: pers.sezione
        Column {
            id: colonna
            x: 14; y: 12; width: parent.width - 28
            spacing: 10
            Text { text: parent.parent.titolo; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
            Flow { id: riga; width: parent.width; spacing: 8 }
        }
    }

    Text {
        x: 18; y: 56
        text: "‹ " + I18n.t("Chiudi")
        color: tel.accento
        font.family: Tema.font; font.pixelSize: tel.px(16)
        MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: tel.personalizza = false }
    }
    Text { x: 18; y: 82; text: I18n.t("Personalizza"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(28); font.weight: Font.Bold }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: 130; anchors.bottomMargin: 20
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
                    model: ["#3F7CF5", "#8B5CF6", "#12B886", "#FF7A3D", "#E8467C", "#6B7385"]
                    Rectangle {
                        required property string modelData
                        width: 38; height: 38; radius: 19
                        color: modelData
                        border.width: 3
                        border.color: tel.imp.accento.toUpperCase() === modelData ? tel.pal.testo : "transparent"
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
                        width: 54; height: 74; radius: 12
                        color: "transparent"
                        border.width: 3
                        border.color: tel.imp.sfondo === modelData ? tel.accento : "transparent"
                        clip: true
                        Image {
                            anchors.fill: parent; anchors.margins: 3
                            source: "file://" + tel.sfondi + "/" + parent.modelData + (tel.chiaro ? "-chiaro" : "") + ".png"
                            sourceSize.height: 160
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        MouseArea { anchors.fill: parent; onClicked: tel.imposta("sfondo", parent.modelData) }
                    }
                }
            }
            Sezione {
                titolo: I18n.t("Orologio del blocco")
                Repeater {
                    model: [{ t: I18n.t("Moderno"), f: "League Spartan" }, { t: I18n.t("Pulito"), f: "Inter" }, { t: I18n.t("Elegante"), f: "Noto Serif" }]
                    Scelta { required property var modelData; testo: modelData.t; carattere: modelData.f; misura: tel.px(16); attiva: tel.imp.orologio === modelData.f; onScelta: tel.imposta("orologio", modelData.f) }
                }
            }
            Sezione {
                titolo: I18n.t("Icone")
                Repeater {
                    model: [I18n.t("Piccole"), I18n.t("Normali"), I18n.t("Grandi")]
                    Scelta { required property string modelData; required property int index; testo: modelData; attiva: (tel.imp.icone === undefined ? 1 : tel.imp.icone) === index; onScelta: tel.imposta("icone", index) }
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
