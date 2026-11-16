// Store: app consigliate per il telefono e ricerca su Flathub; installa e rimuove
// per l'utente (niente password). Le app installate compaiono nella Libreria.
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: app
    color: tel.pal.sfondo
    property var consigliate: []
    property bool disponibile: true
    property var risultati: []
    property string cerca: ""
    property bool cercando: false
    property var inCorso: ({})          // id → true durante installazione/rimozione
    readonly property color sezione: tel.pal.superficie
    readonly property color linea: tel.pal.bordo

    function aggiorna() { ponte.avvia("storeConsigliate", [], "store-consigliate") }
    function azione(a) {
        var c = Object.assign({}, inCorso); c[a.id] = true; inCorso = c
        ponte.avvia(a.installata ? "storeRimuovi" : "storeInstalla", [a.id], "store-fatto:" + a.id)
    }
    onVisibleChanged: if (visible) aggiorna()
    Component.onCompleted: aggiorna()
    Timer { id: ritardo; interval: 500; onTriggered: if (app.cerca) { app.cercando = true; ponte.avvia("storeCerca", [app.cerca], "store-cerca") } else app.risultati = [] }
    Connections {
        target: ponte
        function onCompletato(id, r) {
            if (id === "store-consigliate") { app.consigliate = r.app; app.disponibile = r.disponibile }
            else if (id === "store-cerca") { app.risultati = r; app.cercando = false }
            else if (id.indexOf("store-fatto:") === 0) {
                var c = Object.assign({}, app.inCorso); delete c[id.slice(12)]; app.inCorso = c
                tel.avviso(r.messaggio)
                app.aggiorna()
                if (app.cerca) ponte.avvia("storeCerca", [app.cerca], "store-cerca")
                tel.ricaricaApp()
            }
        }
    }

    Text { x: 20; y: 56; text: I18n.t("Store"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(30); font.weight: Font.Bold }
    Rectangle {
        x: 16; y: 104; width: parent.width - 32; height: 40; radius: 12
        color: tel.pal.superficie2
        Icona { x: 12; anchors.verticalCenter: parent.verticalCenter; nome: "system-search-symbolic"; lato: 16 }
        TextField {
            x: 36; width: parent.width - 46; anchors.verticalCenter: parent.verticalCenter
            placeholderText: I18n.t("Cerca app su Flathub"); placeholderTextColor: tel.pal.testo2; color: tel.pal.testo
            font.family: Tema.font; font.pixelSize: tel.px(15)
            onTextChanged: { app.cerca = text.trim(); ritardo.restart() }
            background: Item {}
        }
    }

    Flickable {
        x: 0; y: 156; width: parent.width; height: parent.height - y - 24
        contentHeight: contenuto.height + 20; clip: true
        Column {
            id: contenuto
            width: parent.width
            spacing: 8
            Text {
                visible: !app.disponibile
                x: 20; width: parent.width - 40; wrapMode: Text.Wrap
                text: I18n.t("Lo Store usa Flatpak, che su questo telefono non è installato.")
                color: "#ef4444"; font.family: Tema.font; font.pixelSize: tel.px(13)
            }
            Text {
                x: 20; topPadding: 4
                text: app.cerca ? (app.cercando ? I18n.t("Ricerca…") : I18n.t("Risultati")) : I18n.t("Consigliate per il telefono")
                color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(19); font.weight: Font.Bold
            }
            Text {
                visible: app.cerca !== "" && !app.cercando && app.risultati.length === 0
                x: 20; text: I18n.t("Nessuna app trovata"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(14)
            }
            Rectangle {
                x: 16; width: parent.width - 32; radius: 16; color: app.sezione
                height: righe.height
                visible: (app.cerca ? app.risultati : app.consigliate).length > 0
                Column {
                    id: righe
                    width: parent.width
                    Repeater {
                        model: app.cerca ? app.risultati : app.consigliate
                        Item {
                            required property var modelData
                            required property int index
                            width: righe.width; height: 72
                            Rectangle {
                                x: 14; anchors.verticalCenter: parent.verticalCenter
                                width: 48; height: 48; radius: 12; color: tel.pal.traccia; clip: true
                                Image { anchors.fill: parent; anchors.margins: 4; source: modelData.icona; asynchronous: true; fillMode: Image.PreserveAspectFit; sourceSize.width: 96 }
                            }
                            Column {
                                x: 74; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 74 - 110; spacing: 2
                                Text { width: parent.width; elide: Text.ElideRight; text: modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.DemiBold }
                                Text { width: parent.width; elide: Text.ElideRight; text: modelData.descrizione; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13) }
                            }
                            Rectangle {
                                anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                                width: 92; height: 32; radius: 16
                                color: modelData.installata ? tel.pal.traccia : tel.accento
                                opacity: app.disponibile ? 1 : 0.4
                                Text {
                                    anchors.centerIn: parent
                                    text: app.inCorso[modelData.id] ? "…" : (modelData.installata ? I18n.t("Rimuovi") : I18n.t("Installa"))
                                    color: modelData.installata ? tel.pal.testo : "#ffffff"
                                    font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold
                                }
                                MouseArea { anchors.fill: parent; enabled: app.disponibile && !app.inCorso[modelData.id]; onClicked: app.azione(modelData) }
                            }
                            Rectangle { visible: index < (app.cerca ? app.risultati : app.consigliate).length - 1; anchors.bottom: parent.bottom; x: 74; width: parent.width - 74; height: 1; color: app.linea }
                        }
                    }
                }
            }
            Text {
                x: 20; width: parent.width - 40; topPadding: 8; wrapMode: Text.Wrap
                text: I18n.t("Le app arrivano da Flathub e si installano solo per te. Alcune sono pensate per il computer e sul telefono possono essere scomode.")
                color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12)
            }
        }
    }
}
