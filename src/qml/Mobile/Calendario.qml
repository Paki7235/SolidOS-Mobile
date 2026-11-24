// Calendario del telefono: stessa logica e stessi dati del PC (nucleo/apps/calendario.py,
// agenda). In alto il mese con un puntino colorato nei giorni con impegni (scorri di lato per
// cambiare mese), sotto gli eventi del giorno scelto. + per un evento nuovo: titolo,
// calendario, tutto il giorno, inizio e fine, luogo, ripetizione, avviso e note.
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: app
    color: tel.pal.sfondo
    property date mese: new Date(new Date().getFullYear(), new Date().getMonth(), 1)
    property date giorno: new Date()
    property var eventi: []
    property var calendari: []
    property var opzioni: ({ ripeti: [], avvisi: [] })
    readonly property var nomiMesi: ["Gennaio", "Febbraio", "Marzo", "Aprile", "Maggio", "Giugno", "Luglio", "Agosto", "Settembre", "Ottobre", "Novembre", "Dicembre"]
    function pc(m, a) { return ponte.chiama("appPc", ["calendario", m, a || []]) }
    function iso(d) { return d.getFullYear() + "-" + ("0" + (d.getMonth() + 1)).slice(-2) + "-" + ("0" + d.getDate()).slice(-2) }
    function carica() {
        var da = new Date(mese.getFullYear(), mese.getMonth(), 1), a = new Date(mese.getFullYear(), mese.getMonth() + 1, 7)
        eventi = pc("eventi", [iso(new Date(da.getTime() - 7 * 86400000)), iso(a)]) || []
    }
    function delGiorno(d) { var k = iso(d); return eventi.filter(function (e) { return e.giorno === k }) }
    function cambiaMese(n) { mese = new Date(mese.getFullYear(), mese.getMonth() + n, 1); carica() }
    onVisibleChanged: if (visible) { calendari = pc("calendari") || []; carica() }
    Component.onCompleted: { calendari = pc("calendari") || []; opzioni = pc("opzioni") || opzioni; carica() }

    // ── Testata: mese e anno, frecce, Oggi, + ────────────────────────────
    Punti { x: 20; y: 60; width: parent.width - 20 - 164; elide: Text.ElideRight; fontSizeMode: Text.HorizontalFit; minimumPixelSize: 22
            text: I18n.t(app.nomiMesi[app.mese.getMonth()]) + " " + app.mese.getFullYear() }
    Row {
        anchors.right: parent.right; anchors.rightMargin: 16; y: 62; spacing: 8
        TastoTondo { icona: "go-previous-symbolic"; onTocco: app.cambiaMese(-1) }
        TastoTondo { icona: "go-next-symbolic"; onTocco: app.cambiaMese(1) }
        TastoTondo { icona: "linea-piu"; pieno: true; onTocco: scheda.apri(null) }
    }
    Text {
        x: 20; y: 104; text: I18n.t("Oggi"); color: tel.accento; font.family: Tema.font; font.pixelSize: 15; font.weight: Font.DemiBold
        MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: { var o = new Date(); app.giorno = o; app.mese = new Date(o.getFullYear(), o.getMonth(), 1); app.carica() } }
    }

    // ── Il mese ──────────────────────────────────────────────────────────
    Item {
        id: griglia
        x: 12; y: 136; width: parent.width - 24; height: 6 * 50 + 26
        readonly property real cella: width / 7
        readonly property int primo: (app.mese.getDay() + 6) % 7          // lunedì = 0
        Row { Repeater { model: ["L", "M", "M", "G", "V", "S", "D"]
                         Text { required property string modelData; width: griglia.cella; horizontalAlignment: Text.AlignHCenter; text: modelData; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.Bold } } }
        Grid {
            y: 24; columns: 7
            Repeater {
                model: 42
                Item {
                    required property int index
                    readonly property date giornoCella: new Date(app.mese.getFullYear(), app.mese.getMonth(), index - griglia.primo + 1)
                    readonly property bool fuori: giornoCella.getMonth() !== app.mese.getMonth()
                    readonly property bool oggi: app.iso(giornoCella) === app.iso(new Date())
                    readonly property bool scelto: app.iso(giornoCella) === app.iso(app.giorno)
                    readonly property var suoi: app.delGiorno(giornoCella)
                    width: griglia.cella; height: 50
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter; y: 2
                        width: 38; height: 38; radius: 19
                        color: parent.scelto ? (parent.oggi ? tel.rosso : (tel.solido ? "#141414" : tel.pal.testo)) : "transparent"
                        Text { anchors.centerIn: parent; text: parent.parent.giornoCella.getDate()
                               color: parent.parent.scelto ? (tel.solido || parent.parent.oggi || !tel.chiaro ? (tel.chiaro || parent.parent.oggi ? "#FFFFFF" : "#141414") : "#FFFFFF") : (parent.parent.oggi ? tel.rosso : tel.pal.testo)
                               opacity: parent.parent.fuori ? 0.35 : 1
                               font.family: Tema.font; font.pixelSize: 18; font.weight: parent.parent.oggi || parent.parent.scelto ? Font.Bold : Font.Normal }
                    }
                    Row { anchors.horizontalCenter: parent.horizontalCenter; y: 42; spacing: 3
                          Repeater { model: parent.parent.suoi.slice(0, 3)
                                     Rectangle { required property var modelData; width: 5; height: 5; radius: 2.5; color: modelData.colore } } }
                    MouseArea { anchors.fill: parent; onClicked: { app.giorno = parent.giornoCella; if (parent.fuori) { app.mese = new Date(parent.giornoCella.getFullYear(), parent.giornoCella.getMonth(), 1); app.carica() } }
                                onDoubleClicked: scheda.apri(null) }
                }
            }
        }
        DragHandler { target: null; yAxis.enabled: false
                      onActiveChanged: if (!active) { if (translation.x < -60) app.cambiaMese(1); else if (translation.x > 60) app.cambiaMese(-1) } }
    }

    // ── Eventi del giorno ────────────────────────────────────────────────
    Rectangle { x: 0; y: griglia.y + griglia.height + 4; width: parent.width; height: 1; color: tel.pal.bordo }
    Text { x: 20; y: griglia.y + griglia.height + 16; text: app.giorno.toLocaleDateString(Qt.locale("it_IT"), "dddd d MMMM"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 17; font.weight: Font.Bold }
    ListView {
        id: lista
        x: 16; y: griglia.y + griglia.height + 48; width: parent.width - 32; height: parent.height - y - 30
        clip: true; spacing: 8
        model: app.delGiorno(app.giorno)
        delegate: Rectangle {
            required property var modelData
            width: lista.width; height: 64; radius: 18; color: tel.pal.superficie
            Rectangle { x: 10; y: 10; width: 5; height: parent.height - 20; radius: 3; color: modelData.colore }
            Column { x: 26; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 110
                     Text { width: parent.width; elide: Text.ElideRight; text: modelData.titolo; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.DemiBold }
                     Text { width: parent.width; elide: Text.ElideRight; text: (modelData.luogo ? modelData.luogo + " · " : "") + modelData.nomeCalendario; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 13 } }
            Column { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                     Text { anchors.right: parent.right; text: modelData.tuttoGiorno ? I18n.t("tutto il giorno") : modelData.ora; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                     Text { anchors.right: parent.right; visible: !modelData.tuttoGiorno; text: modelData.oraFine; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 13 } }
            MouseArea { anchors.fill: parent; onClicked: scheda.apri(modelData) }
        }
        Text { anchors.centerIn: parent; visible: lista.count === 0; text: I18n.t("Nessun evento"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 15 }
    }

    // ── Evento nuovo o da modificare ─────────────────────────────────────
    Rectangle {
        id: scheda
        anchors.fill: parent; visible: false; color: tel.pal.sfondo
        property var ev: null
        property string calendario: "personale"
        property string ripeti: ""
        property int avviso: 15
        property bool tutto: false
        function apri(e) {
            ev = e
            var g = app.iso(app.giorno)
            titolo.text = e ? e.titolo : ""; luogo.text = e ? e.luogo : ""; note.text = e ? e.note : ""
            calendario = e ? e.calendario : (app.calendari.length ? app.calendari[0].id : "personale")
            tutto = e ? e.tuttoGiorno : false; ripeti = e ? e.ripeti : ""; avviso = e ? e.avviso : 15
            dataInizio.text = e ? e.inizio.slice(0, 10) : g; oraInizio.text = e && !e.tuttoGiorno ? e.ora : "09:00"
            dataFine.text = e ? e.fine.slice(0, 10) : g; oraFine.text = e && !e.tuttoGiorno ? e.oraFine : "10:00"
            visible = true
        }
        function salva() {
            if (!titolo.text.trim()) { tel.avviso(I18n.t("Scrivi un titolo")); return }
            var d = { titolo: titolo.text.trim(), calendario: calendario, tuttoGiorno: tutto, luogo: luogo.text, note: note.text, ripeti: ripeti, avviso: avviso,
                      inizio: dataInizio.text + (tutto ? "" : "T" + oraInizio.text), fine: dataFine.text + (tutto ? "" : "T" + oraFine.text) }
            if (ev) d.id = ev.id
            var r = app.pc("salvaEvento", [d])
            if (r && r.ok === false) { tel.avviso(r.messaggio); return }
            visible = false; app.carica()
        }
        MouseArea { anchors.fill: parent }
        Text { x: 20; y: 64; text: I18n.t("Annulla"); color: tel.accento; font.family: Tema.font; font.pixelSize: 16
               MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: scheda.visible = false } }
        Text { anchors.horizontalCenter: parent.horizontalCenter; y: 64; text: scheda.ev ? I18n.t("Modifica evento") : I18n.t("Nuovo evento"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.Bold }
        Text { anchors.right: parent.right; anchors.rightMargin: 20; y: 64; text: I18n.t("Salva"); color: tel.accento; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.Bold
               MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: scheda.salva() } }
        Flickable {
            anchors.fill: parent; anchors.topMargin: 104; contentHeight: modulo.height + 40; clip: true
            Column {
                id: modulo
                x: 16; width: parent.width - 32; spacing: 10
                CampoTesto { id: titolo; width: parent.width; placeholderText: I18n.t("Titolo") }
                CampoTesto { id: luogo; width: parent.width; placeholderText: I18n.t("Luogo") }
                Text { text: I18n.t("Calendario"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.DemiBold; topPadding: 6 }
                Flow {
                    width: parent.width; spacing: 8
                    Repeater {
                        model: app.calendari
                        Rectangle {
                            required property var modelData
                            readonly property bool scelto: scheda.calendario === modelData.id
                            width: etCal.implicitWidth + 40; height: 38; radius: 19
                            color: scelto ? modelData.colore : tel.pal.superficie
                            Row { id: etCal; anchors.centerIn: parent; spacing: 6
                                  Rectangle { width: 10; height: 10; radius: 5; color: parent.parent.scelto ? "#FFFFFF" : parent.parent.modelData.colore; anchors.verticalCenter: parent.verticalCenter }
                                  Text { text: parent.parent.modelData.nome; color: parent.parent.scelto ? "#FFFFFF" : tel.pal.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.DemiBold } }
                            MouseArea { anchors.fill: parent; onClicked: scheda.calendario = parent.modelData.id }
                        }
                    }
                }
                Rectangle {
                    width: parent.width; height: 52; radius: 16; color: tel.pal.superficie
                    Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Tutto il giorno"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 16 }
                    Interruttore { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; checked: scheda.tutto; onToggled: scheda.tutto = checked }
                }
                Row { spacing: 8; width: parent.width
                      CampoTesto { id: dataInizio; width: (parent.width - 8) * 0.6; placeholderText: "AAAA-MM-GG"; inputMethodHints: Qt.ImhDate }
                      CampoTesto { id: oraInizio; visible: !scheda.tutto; width: (parent.width - 8) * 0.4; placeholderText: "HH:MM"; inputMethodHints: Qt.ImhTime } }
                Row { spacing: 8; width: parent.width
                      CampoTesto { id: dataFine; width: (parent.width - 8) * 0.6; placeholderText: "AAAA-MM-GG"; inputMethodHints: Qt.ImhDate }
                      CampoTesto { id: oraFine; visible: !scheda.tutto; width: (parent.width - 8) * 0.4; placeholderText: "HH:MM"; inputMethodHints: Qt.ImhTime } }
                Text { text: I18n.t("Ripeti"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.DemiBold; topPadding: 6 }
                Flow { width: parent.width; spacing: 8
                       Repeater { model: app.opzioni.ripeti
                                  Rectangle { required property var modelData; readonly property bool scelto: scheda.ripeti === modelData.id
                                              width: etR.implicitWidth + 28; height: 36; radius: 18; color: scelto ? (tel.solido ? "#C6F432" : tel.accento) : tel.pal.superficie
                                              Text { id: etR; anchors.centerIn: parent; text: parent.modelData.nome; color: parent.scelto ? (tel.solido ? "#141414" : "#FFFFFF") : tel.pal.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                                              MouseArea { anchors.fill: parent; onClicked: scheda.ripeti = parent.modelData.id } } } }
                Text { text: I18n.t("Avviso"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.DemiBold; topPadding: 6 }
                Flow { width: parent.width; spacing: 8
                       Repeater { model: app.opzioni.avvisi
                                  Rectangle { required property var modelData; readonly property bool scelto: scheda.avviso === modelData.id
                                              width: etA.implicitWidth + 28; height: 36; radius: 18; color: scelto ? (tel.solido ? "#C6F432" : tel.accento) : tel.pal.superficie
                                              Text { id: etA; anchors.centerIn: parent; text: parent.modelData.nome; color: parent.scelto ? (tel.solido ? "#141414" : "#FFFFFF") : tel.pal.testo; font.family: Tema.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                                              MouseArea { anchors.fill: parent; onClicked: scheda.avviso = parent.modelData.id } } } }
                CampoTesto { id: note; width: parent.width; placeholderText: I18n.t("Note") }
                Pulsante { visible: scheda.ev !== null; width: parent.width; text: I18n.t("Elimina evento"); pericoloso: true
                           onClicked: { app.pc("eliminaEvento", [scheda.ev.id]); scheda.visible = false; app.carica() } }
            }
        }
    }
}
