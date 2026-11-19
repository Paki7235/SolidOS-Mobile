// Aggiungi un widget (dalla Home in modifica, tasto «+»): cerca, i widget consigliati,
// l'elenco di tutti i widget. Toccandone uno si sceglie la misura (piccolo, medio, grande)
// scorrendo, poi «Aggiungi widget». Si può anche mettere nella schermata di blocco.
import QtQuick
import QtQuick.Controls
import SolidUI

Item {
    id: gal
    anchors.fill: parent
    property bool aperta: false
    property string scelto: ""           // tipo del widget di cui si sceglie la misura
    property string cerca: ""
    visible: aperta || foglio.y < height
    readonly property var tutti: [
        { tipo: "meteo", nome: I18n.t("Meteo"), info: I18n.t("Piccolo · Medio · Grande"), icona: "linea-sole", colore: "#3B82F6" },
        { tipo: "oggi", nome: I18n.t("Calendario"), info: I18n.t("Oggi e prossimi impegni"), icona: "linea-calendario", colore: "#E5484D" },
        { tipo: "batterie", nome: I18n.t("Batterie"), info: I18n.t("Telefono, PC e cuffie collegati"), icona: "linea-batteria", colore: "#30A46C" },
        { tipo: "foto", nome: I18n.t("Foto"), info: I18n.t("Ricordi e preferite"), icona: "linea-foto", colore: "#DB2777" },
        { tipo: "musica", nome: I18n.t("Musica"), info: I18n.t("Il brano che stai ascoltando"), icona: "linea-musica", colore: "#E11D48" },
        { tipo: "orologio", nome: I18n.t("Orologio"), info: I18n.t("Città del mondo"), icona: "linea-orologio", colore: "#3F3F46" },
        { tipo: "note", nome: I18n.t("Note"), info: I18n.t("L'ultima nota"), icona: "linea-note", colore: "#F59E0B" }]
    readonly property var filtrati: tutti.filter(function (x) { return !cerca || x.nome.toLowerCase().indexOf(cerca.toLowerCase()) >= 0 })
    readonly property var infoScelto: tutti.find(function (x) { return x.tipo === scelto }) || ({ nome: "", info: "" })

    function apri() { scelto = ""; aperta = true }
    function aggiungi(tipo, misura) {
        var l = (tel.imp.widget || []).slice()
        l.push({ tipo: tipo, misura: misura })
        tel.imposta("widget", l)
        aperta = false; scelto = ""
        tel.avviso(I18n.t("Widget aggiunto"))
    }

    Rectangle {
        anchors.fill: parent; color: "#73000000"
        opacity: gal.aperta ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: tel.tNormale } }
        MouseArea { anchors.fill: parent; onClicked: gal.aperta = false }
    }
    Rectangle {
        id: foglio
        width: parent.width; height: parent.height - 96
        y: gal.aperta ? 96 : parent.height
        Behavior on y { Movimento { apre: gal.aperta } }
        radius: 26; color: tel.chiaro ? "#F2F2F7" : "#1C1D22"
        MouseArea { anchors.fill: parent }
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 10; width: 40; height: 5; radius: 3; color: tel.pal.bordo }

        // ── Elenco dei widget ─────────────────────────────────────────
        Flickable {
            visible: gal.scelto === ""
            anchors.fill: parent; anchors.topMargin: 26
            contentHeight: colG.height + 40; clip: true
            Column {
                id: colG
                x: 16; width: foglio.width - 32; spacing: 14
                CampoCerca { width: parent.width; height: 36; suggerimento: I18n.t("Cerca un widget"); onTextChanged: gal.cerca = text.trim() }
                Text { visible: !gal.cerca; text: I18n.t("Aggiungi un widget"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(19); font.weight: Font.Bold }
                // Consigliati: anteprime vere, in piccolo
                Grid {
                    visible: !gal.cerca
                    columns: 2; spacing: 12
                    Repeater {
                        model: [{ t: "batterie", m: "piccolo" }, { t: "musica", m: "piccolo" }, { t: "foto", m: "piccolo" }, { t: "meteo", m: "piccolo" }]
                        Item {
                            required property var modelData
                            width: (colG.width - 12) / 2; height: 120
                            Widget {
                                anchors.centerIn: parent
                                tipo: parent.modelData.t; misura: parent.modelData.m; anteprima: true
                                cella: parent.width; alto: parent.height
                            }
                            MouseArea { anchors.fill: parent; onClicked: gal.scelto = parent.modelData.t }
                        }
                    }
                }
                Text { text: I18n.t("Tutti i widget"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.Bold }
                Rectangle {
                    width: parent.width; height: colT.height; radius: 14; color: tel.pal.superficie
                    Column {
                        id: colT
                        width: parent.width
                        Repeater {
                            model: gal.filtrati
                            Item {
                                id: rw
                                required property var modelData
                                required property int index
                                width: colT.width; height: 58
                                Rectangle { visible: rw.index > 0; x: 58; width: parent.width - 58; height: 1; color: tel.pal.bordo }
                                Rectangle {
                                    x: 14; anchors.verticalCenter: parent.verticalCenter; width: 32; height: 32; radius: 8; color: rw.modelData.colore
                                    Icona { anchors.centerIn: parent; nome: rw.modelData.icona; lato: 18; tema: "scuro" }
                                }
                                Column {
                                    x: 58; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 58 - 100
                                    Text { text: rw.modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.Medium }
                                    Text { width: parent.width; elide: Text.ElideRight; text: rw.modelData.info; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }
                                }
                                Text { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Aggiungi"); color: tel.accento; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.DemiBold }
                                MouseArea { anchors.fill: parent; onClicked: gal.scelto = rw.modelData.tipo }
                            }
                        }
                    }
                }
            }
        }

        // ── Scegli la misura ──────────────────────────────────────────
        Item {
            visible: gal.scelto !== ""
            anchors.fill: parent; anchors.topMargin: 26
            Text { x: 16; y: 2; text: "‹ " + I18n.t("Widget"); color: tel.accento; font.family: Tema.font; font.pixelSize: tel.px(15)
                   MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: gal.scelto = "" } }
            Column {
                y: 34; width: parent.width; spacing: 4
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: gal.infoScelto.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(20); font.weight: Font.Bold }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: gal.infoScelto.info + ". " + I18n.t("Scorri per la misura."); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13) }
            }
            SwipeView {
                id: misure
                y: 100; width: parent.width; height: 360
                clip: true
                Repeater {
                    model: [{ m: "piccolo", t: I18n.t("Piccolo") }, { m: "medio", t: I18n.t("Medio") }, { m: "grande", t: I18n.t("Grande") }]
                    Item {
                        required property var modelData
                        Widget {
                            anchors.centerIn: parent; anchors.verticalCenterOffset: -12
                            tipo: gal.scelto || "oggi"; misura: parent.modelData.m; anteprima: true
                            cella: (gal.width - 2 * tel.margine - 14) / 2; alto: parent.modelData.m === "grande" ? 150 : 160
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; text: parent.modelData.t; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                    }
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter; y: misure.y + misure.height + 14; spacing: 7
                Repeater { model: 3; Rectangle { required property int index; width: 8; height: 8; radius: 4; color: index === misure.currentIndex ? tel.pal.testo : tel.pal.testo3 } }
            }
            Rectangle {
                x: 16; y: misure.y + misure.height + 44; width: parent.width - 32; height: 48; radius: 24; color: tel.accento
                Text { anchors.centerIn: parent; text: "+ " + I18n.t("Aggiungi widget"); color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.DemiBold }
                MouseArea { anchors.fill: parent; onClicked: gal.aggiungi(gal.scelto, ["piccolo", "medio", "grande"][misure.currentIndex]) }
            }
            Text {
                visible: ["meteo", "batterie", "oggi", "musica"].indexOf(gal.scelto) >= 0
                anchors.horizontalCenter: parent.horizontalCenter; y: misure.y + misure.height + 106
                text: I18n.t("Aggiungi alla schermata di blocco"); color: tel.accento; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.Medium
                MouseArea {
                    anchors.fill: parent; anchors.margins: -10
                    onClicked: {
                        var l = (tel.imp.widget_blocco || []).filter(function (x) { return x !== gal.scelto })
                        l.push(gal.scelto); tel.imposta("widget_blocco", l.slice(-3))
                        gal.aperta = false; gal.scelto = ""; tel.avviso(I18n.t("Lo vedi sotto l'orologio della schermata di blocco"))
                    }
                }
            }
        }
    }
}
