// Aspetto: la veste (Aurora, Prisma, Prisma Notte o automatica), le icone (Gemme, Piene,
// Vetro), il colore, lo sfondo, il testo, l'orologio del blocco e la navigazione.
// Ogni scelta si salva e cambia subito il telefono.
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
        testo: I18n.t("Aspetto")
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
            // Veste: un'anteprima piccola di ogni Home
            Sezione {
                titolo: I18n.t("Veste")
                Repeater {
                    model: [{ k: "aurora", t: "Aurora" }, { k: "prisma", t: "Prisma" }, { k: "notte", t: "Prisma Notte" }]
                    Item {
                        id: vs
                        required property var modelData
                        readonly property bool attiva: tel.vesteScelta === modelData.k
                        width: (elenco.width - 32 - 16) / 3; height: 196
                        Rectangle {
                            id: mini
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 88; height: 164; radius: 18; clip: true
                            border.width: vs.attiva ? 3 : 1; border.color: vs.attiva ? tel.accento : tel.pal.bordo
                            Image {
                                anchors.fill: parent; anchors.margins: vs.attiva ? 3 : 1
                                source: ponte.chiama("sfondo", [({ aurora: "viva", prisma: "carta", notte: "inchiostro" })[vs.modelData.k], false])
                                fillMode: Image.PreserveAspectCrop; sourceSize.height: 330
                            }
                            // due widget e le icone, come nella Home
                            Grid {
                                x: 9; y: 16; columns: 2; spacing: 5
                                Rectangle { width: 32; height: 30; radius: 8; color: vs.modelData.k === "aurora" ? "#3DFFFFFF" : "#8B6CFF" }
                                Rectangle { width: 32; height: 30; radius: 8; color: vs.modelData.k === "aurora" ? "#3DFFFFFF" : "#FF6B4A" }
                            }
                            Rectangle { x: 9; y: 51; width: 69; height: 16; radius: 6; color: vs.modelData.k === "aurora" ? "#3DFFFFFF" : (vs.modelData.k === "prisma" ? "#141414" : "#1C1C21") }
                            Grid {
                                x: 10; y: 78; columns: 4; spacing: 3
                                Repeater {
                                    model: ["foto", "mappe", "note", "file", "dove", "store", "musica", "impostazioni"]
                                    Icona { required property string modelData; lato: 15; tema: "nessuno"
                                            nome: (vs.modelData.k === "aurora" ? "" : "piene-") + "nucleo-" + modelData }
                                }
                            }
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; text: vs.modelData.t; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: vs.attiva ? Font.Bold : Font.Medium }
                        MouseArea { anchors.fill: parent; onClicked: tel.scegliVeste(vs.modelData.k) }
                    }
                }
                Scelta { testo: I18n.t("Automatica: Prisma di giorno, Aurora la sera"); attiva: tel.vesteScelta === "auto"; onScelta: tel.scegliVeste("auto") }
            }
            // Finitura delle icone: Gemme, Piene, Vetro
            Sezione {
                titolo: I18n.t("Icone")
                Repeater {
                    model: [{ k: "gemme", t: I18n.t("Gemme") }, { k: "piene", t: I18n.t("Piene") }, { k: "vetro", t: I18n.t("Vetro") }]
                    Rectangle {
                        id: prova
                        required property var modelData
                        readonly property bool attiva: tel.stileIcone === modelData.k
                        width: (elenco.width - 32 - 16) / 3; height: 132; radius: 16; clip: true
                        color: "transparent"
                        border.width: attiva ? 3 : 0; border.color: tel.accento
                        Image {
                            anchors.fill: parent; anchors.margins: prova.attiva ? 3 : 0
                            source: tel.sfondo; fillMode: Image.PreserveAspectCrop
                            sourceSize.height: 260
                        }
                        Grid {
                            anchors.centerIn: parent; anchors.verticalCenterOffset: -8
                            columns: 2; spacing: 8
                            Repeater {
                                model: ["telefono", "messaggi", "foto", "note"]
                                IconaApp { required property string modelData; app: ({ icona: "nucleo-" + modelData, nome: "" }); conNome: false; lato: 36; stileForzato: prova.modelData.k; width: 40; enabled: false }
                            }
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 8; text: prova.modelData.t; color: tel.chiaro ? "#141414" : "#FFFFFF"; style: tel.chiaro ? Text.Normal : Text.Raised; styleColor: "#66000000"; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                        MouseArea { anchors.fill: parent; onClicked: tel.imposta("stile_icone", prova.modelData.k) }
                    }
                }
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
                    model: ["#8B6CFF", "#FF3D8B", "#FF6B4A", "#FFB443", "#7CC00F", "#12B886", "#3B8BFF", "#6B7385"]
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
                    model: tel.sfondi
                    Rectangle {
                        required property string modelData
                        width: 56; height: 96; radius: 12
                        color: "transparent"
                        border.width: 3
                        border.color: tel.nomeSfondo === modelData && !(tel.imp.sfondo || "").startsWith("/") ? tel.accento : tel.pal.bordo
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
                titolo: I18n.t("Grandezza delle icone")
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
