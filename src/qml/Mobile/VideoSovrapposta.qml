// Videochiamata in corso o in arrivo: sopra a tutto (anche al blocco), a tutto schermo.
// La chiamata vera è la pagina del motore web (VideoChiamata.qml); qui ci sono l'avvio, i suoni,
// i recenti e cosa fare se il motore web non è ancora installato.
import QtQuick
import SolidUI

Item {
    id: sov
    anchors.fill: parent
    z: 91
    visible: attiva

    property bool attiva: false
    property var attuale: null
    property var daAvviare: null
    property var conf: ({})
    property string errore: ""

    function vc(m, a) { return ponte.chiama("videochiamate", [m, a || []]) }
    function chiama(p, video) {
        if (attiva) return
        conf = vc("configurazione")
        if (!conf.ok) { errore = conf.motivo; attuale = null; attiva = true; return }
        attuale = { id: p.id, nome: p.nome, email: p.email, verso: "uscita", video: video }
        daAvviare = { modo: "chiama", a: p.id, nome: p.nome, email: p.email, video: video }
        inizia()
    }
    function arrivo(off) {
        if (attiva) return
        conf = vc("configurazione")
        if (!conf.ok) return
        attuale = { id: off.da, nome: off.dati.nome || off.dati.email || I18n.t("Chiamata"), email: off.dati.email || "", verso: "entrata", video: !!off.dati.video, chiamata: off.chiamata }
        daAvviare = { modo: "arrivo", nome: attuale.nome, offerta: off }
        inizia()
    }
    function inizia() {
        errore = ""
        vc("inChiamata", [true])
        attiva = true
    }
    function finita(d) {
        vc("squillo", [false])
        vc("inChiamata", [false])
        if (attuale) {
            var verso = attuale.verso === "entrata" && !d.connessa && d.motivo !== "rifiutata-da-me" && d.motivo !== "altrove" ? "persa" : attuale.verso
            if (d.motivo !== "altrove")
                vc("registra", [{ chiamata: d.chiamata || attuale.chiamata, id: attuale.id, nome: attuale.nome, email: attuale.email, verso: verso,
                                  video: d.video !== undefined ? d.video : attuale.video, durata: d.durata || 0 }])
            if (verso === "persa") vc("avvisoPersa", [attuale.nome])
        }
        attuale = null
        attiva = false
        if (tel.appInterna === "videochiamate" && videochiamateApp) videochiamateApp.aggiorna()
    }
    property var videochiamateApp: null

    Rectangle { anchors.fill: parent; color: "#0B0C10" }
    Loader {
        id: vista
        anchors.fill: parent
        active: sov.attiva && sov.errore === ""
        source: "VideoChiamata.qml"
        onStatusChanged: if (status === Loader.Error && sov.attiva) { sov.vc("inChiamata", [false]); sov.errore = I18n.t("Il motore web per le videochiamate non è ancora installato: arriva con il prossimo aggiornamento del telefono.") }
    }
    Connections {
        target: vista.item
        ignoreUnknownSignals: true
        function onPronta() { if (sov.daAvviare) { vista.item.avvia(sov.conf, sov.daAvviare, sov.vc("traduzioni")); sov.daAvviare = null } }
        function onEvento(nome, d) {
            if (nome === "squillo") sov.vc("squillo", [d.attivo, !!d.uscita])
            else if (nome === "iniziata" && sov.attuale) { var a = sov.attuale; a.chiamata = d.chiamata; sov.attuale = a }
            else if (nome === "fine") sov.finita(d)
        }
    }
    Timer { interval: 20 * 60 * 1000; repeat: true; running: sov.attiva && !!vista.item; onTriggered: vista.item.token(sov.vc("token")) }

    // senza motore web o senza Solid ID
    Column {
        anchors.centerIn: parent
        width: parent.width - 2 * tel.margine
        visible: sov.errore !== ""
        spacing: 18
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 84; height: 84; radius: 42; color: Qt.rgba(1, 1, 1, 0.1)
            Simbolo { anchors.centerIn: parent; nome: "video"; lato: 40; colore: "#FFFFFF" }
        }
        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; text: sov.errore; color: "#F5F5F7"; font.family: Tema.font; font.pixelSize: tel.px(16) }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 160; height: 48; radius: 24; color: Qt.rgba(1, 1, 1, 0.16)
            Text { anchors.centerIn: parent; text: I18n.t("Chiudi"); color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.DemiBold }
            MouseArea { anchors.fill: parent; onClicked: { sov.attiva = false; sov.errore = "" } }
        }
    }
}
