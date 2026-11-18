// Home «Essenziale»: due widget (Batteria con i puntini, Oggi), la griglia delle app in tondi
// con il disegno a linea (senza ripetere quelle del Dock), la ricerca e il Dock con i tondi
// bianchi. Scorrendo a sinistra si arriva alla Libreria app. Le righe di app sono quante ne
// entrano: mai sovrapposizioni.
import QtQuick
import QtQuick.Controls
import SolidUI

Item {
    id: home
    property alias pagina: pagine.currentIndex
    property var app: ponte.chiama0("home")
    property var dock: ponte.chiama0("dock")
    // Le app del Dock non si ripetono nella griglia
    readonly property var appGriglia: app.filter(function (a) { return !dock.some(function (d) { return d.id === a.id }) })
    property var dispositivi: []
    Component.onCompleted: ponte.avvia("dispositivi", [], "dispositivi")
    Connections {
        target: ponte
        function onCompletato(id, r) { if (id === "dispositivi") home.dispositivi = r }
    }
    readonly property int basso: tel.imp.navigazione === "tasti" ? 52 : 30   // spazio per la navigazione
    readonly property real cella: (width - 2 * tel.margine) / 4
    readonly property real altezzaCella: tel.latoIcona + 28 + 16
    readonly property int batteria: tel.stato && tel.stato.batteria ? tel.stato.batteria.livello : 100
    readonly property int notifiche: tel.elencoNotifiche ? tel.elencoNotifiche.length : 0
    // Un'app ha novità se c'è una sua notifica (puntino rosso sull'icona)
    function haNovita(a) { return (tel.elencoNotifiche || []).some(function (n) { return n.icona === a.icona }) }

    SwipeView {
        id: pagine
        anchors.fill: parent
        anchors.topMargin: 44

        // ── Pagina 1: Home ────────────────────────────────────────────────
        Item {
            id: paginaHome

            // Widget
            Row {
                id: cima
                x: tel.margine; y: 14
                spacing: 12
                readonly property real lato: (home.width - 2 * tel.margine - 12) / 2
                readonly property real alto: Math.min(166, Math.max(140, home.height * 0.19))

                // Batteria: numero a puntini e barra di puntini
                Vetro {
                    width: cima.lato; height: cima.alto; radius: 24
                    Mono { x: 16; y: 16; text: I18n.t("Batteria") }
                    Punti { x: 16; y: 34; text: home.batteria; font.pixelSize: 58; color: home.batteria <= 20 ? tel.rosso : tel.pal.testo }
                    BarraPunti {
                        x: 16; width: parent.width - 32; height: 28
                        anchors.bottom: parent.bottom; anchors.bottomMargin: 14
                        valore: home.batteria
                        acceso: home.batteria <= 20 ? tel.rosso : tel.pal.testo
                    }
                    MouseArea { anchors.fill: parent; onClicked: { tel.apri({ "id": "interno:impostazioni" }); impostazioniApp.apri("batteria") } }
                }
                // Oggi: giorno, notifiche e il computer collegato
                Vetro {
                    width: cima.lato; height: cima.alto; radius: 24
                    Mono { x: 16; y: 16; text: I18n.t("Oggi") }
                    Rectangle { visible: home.notifiche > 0; anchors.right: parent.right; anchors.rightMargin: 18; y: 19; width: 8; height: 8; radius: 4; color: tel.rosso }
                    Column {
                        x: 16; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 4
                        width: parent.width - 32
                        spacing: 4
                        Text { width: parent.width; elide: Text.ElideRight; text: tel.adesso.toLocaleDateString(Qt.locale("it_IT"), "dddd d"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(19); font.weight: Font.DemiBold; font.capitalization: Font.Capitalize }
                        Mono {
                            text: home.notifiche > 0 ? home.notifiche + " " + (home.notifiche === 1 ? I18n.t("notifica") : I18n.t("notifiche"))
                                                     : I18n.t("Tutto letto")
                            color: home.notifiche > 0 ? tel.pal.testo : tel.pal.testo2; font.pixelSize: tel.px(12)
                        }
                    }
                    Mono {
                        x: 16; anchors.bottom: parent.bottom; anchors.bottomMargin: 16
                        width: parent.width - 32; elide: Text.ElideRight
                        text: home.dispositivi.length ? home.dispositivi[0].nome + " " + home.dispositivi[0].batteria + "%"
                                                      : (tel.stato.rete && tel.stato.rete.connesso ? tel.stato.rete.nome : I18n.t("Nessuna rete"))
                    }
                    MouseArea { anchors.fill: parent; onClicked: tel.notifiche = true }
                }
            }

            // Griglia: 4 colonne, tante righe quante ne entrano
            Grid {
                id: griglia
                x: tel.margine
                anchors.top: cima.bottom; anchors.topMargin: 26
                columns: 4
                readonly property real spazio: ricerca.y - 16 - (cima.y + cima.height + 26)
                readonly property int righe: Math.max(1, Math.min(4, Math.floor(spazio / home.altezzaCella)))
                Repeater {
                    model: home.appGriglia.slice(0, griglia.righe * 4)
                    Item {
                        required property var modelData
                        required property int index
                        width: home.cella; height: home.altezzaCella
                        IconaApp { anchors.horizontalCenter: parent.horizontalCenter; app: parent.modelData; nuovo: home.haNovita(parent.modelData); ritardo: 40 + parent.index * 30 }
                    }
                }
            }

            // Ricerca (porta alla Libreria)
            Rectangle {
                id: ricerca
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: dockHome.top; anchors.bottomMargin: 18
                width: cerca.implicitWidth + 50; height: 34; radius: 17
                color: "transparent"; border.width: 1; border.color: tel.pal.bordo
                Row {
                    anchors.centerIn: parent; spacing: 8
                    Icona { nome: "system-search-symbolic"; lato: 14; anchors.verticalCenter: parent.verticalCenter }
                    Mono { id: cerca; anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Cerca"); color: tel.pal.testo; font.pixelSize: tel.px(12) }
                }
                MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: pagine.currentIndex = 1 }
            }

            // Dock: tondi bianchi, senza nome
            Row {
                id: dockHome
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: tel.margine; anchors.rightMargin: tel.margine
                anchors.bottom: parent.bottom; anchors.bottomMargin: home.basso + 4
                height: tel.latoIcona + 6
                Repeater {
                    model: home.dock
                    Item {
                        required property var modelData
                        required property int index
                        width: dockHome.width / Math.max(4, home.dock.length); height: dockHome.height
                        IconaApp { anchors.horizontalCenter: parent.horizontalCenter; app: parent.modelData; conNome: false; pieno: true; lato: tel.latoIcona + 4; nuovo: home.haNovita(parent.modelData); ritardo: parent.index * 30 }
                    }
                }
            }
        }

        // ── Pagina 2: Libreria app ────────────────────────────────────────
        Libreria {}
    }

    PageIndicator {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: home.basso + 4 + tel.latoIcona + 6 + 18 + 34 + 12
        count: pagine.count
        currentIndex: pagine.currentIndex
        visible: pagine.currentIndex === 0
        spacing: 6
        delegate: Rectangle { required property int index; width: index === pagine.currentIndex ? 14 : 5; height: 5; radius: 2.5; color: tel.pal.testo; opacity: index === pagine.currentIndex ? 0.9 : 0.3 }
    }
}
