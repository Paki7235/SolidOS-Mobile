// Home: una scheda «Oggi» (data, ora grande, anello della batteria e notifiche), la griglia
// delle app (senza ripetere quelle del Dock), ricerca e Dock. Scorrendo a sinistra si arriva
// alla Libreria app. Le righe di app sono quante ne entrano: mai sovrapposizioni.
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
    readonly property real altezzaCella: tel.latoIcona + 26 + 18
    readonly property int batteria: tel.stato && tel.stato.batteria ? tel.stato.batteria.livello : 100
    readonly property int notifiche: tel.elencoNotifiche ? tel.elencoNotifiche.length : 0

    // Anello della batteria
    component Anello: Item {
        id: an
        property int livello: 100
        property real spessore: 5
        property bool conTesto: true
        property int testo: 14
        width: 52; height: 52
        Canvas {
            anchors.fill: parent
            property int l: an.livello
            property color c: an.livello <= 20 ? tel.pal.pericolo : tel.pal.successo
            property color f: tel.pal.traccia
            onLChanged: requestPaint()
            onCChanged: requestPaint()
            onWidthChanged: requestPaint()
            onPaint: {
                var g = getContext("2d"), r = width / 2 - an.spessore / 2 - 1
                g.reset(); g.lineWidth = an.spessore; g.lineCap = "round"
                g.strokeStyle = f; g.beginPath(); g.arc(width / 2, height / 2, r, 0, 2 * Math.PI); g.stroke()
                g.strokeStyle = c; g.beginPath(); g.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * l / 100); g.stroke()
            }
        }
        Text { visible: an.conTesto; anchors.centerIn: parent; text: an.livello; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: an.testo; font.weight: Font.Bold }
    }

    SwipeView {
        id: pagine
        anchors.fill: parent
        anchors.topMargin: 44

        // ── Pagina 1: Home ────────────────────────────────────────────────
        Item {
            id: paginaHome
            // Scheda «Oggi»: ora e data grandi, batteria e notifiche
            Vetro {
                id: cima
                x: tel.margine; y: 8
                width: home.width - 2 * tel.margine; height: Math.min(168, Math.max(136, home.height * 0.19))
                radius: 28
                Column {
                    x: 20; anchors.verticalCenter: parent.verticalCenter
                    Text { text: tel.adesso.toLocaleDateString(Qt.locale("it_IT"), "dddd d MMMM"); color: tel.accento; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.DemiBold; font.capitalization: Font.Capitalize }
                    Text { text: tel.ora(); color: tel.pal.testo; font.family: tel.fontOra; font.pixelSize: 64; font.weight: Font.Bold; font.letterSpacing: -2 }
                }
                Column {
                    anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Anello { anchors.horizontalCenter: parent.horizontalCenter; livello: home.batteria; width: 60; height: 60; testo: 16 }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tel.imp.non_disturbare ? I18n.t("Non disturbare") : (home.notifiche > 0 ? home.notifiche + " " + I18n.t("notifiche") : I18n.t("Tutto letto"))
                        color: tel.imp.non_disturbare ? "#818CF8" : tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12); font.weight: Font.Medium
                    }
                }
                MouseArea { anchors.fill: parent; onClicked: tel.notifiche = true }
            }

            // Griglia: 4 colonne, tante righe quante ne entrano
            Grid {
                id: griglia
                x: tel.margine
                anchors.top: cima.bottom; anchors.topMargin: 24
                columns: 4
                readonly property real spazio: ricerca.y - 16 - (cima.y + cima.height + 24)
                readonly property int righe: Math.max(1, Math.min(4, Math.floor(spazio / home.altezzaCella)))
                Repeater {
                    model: home.appGriglia.slice(0, griglia.righe * 4)
                    Item {
                        required property var modelData
                        required property int index
                        width: home.cella; height: home.altezzaCella
                        IconaApp { anchors.horizontalCenter: parent.horizontalCenter; app: parent.modelData; ritardo: 60 + parent.index * 35 }
                    }
                }
            }

            // Ricerca (porta alla Libreria)
            Vetro {
                id: ricerca
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: dockHome.top; anchors.bottomMargin: 14
                width: cerca.implicitWidth + 46; height: 32; radius: 16
                Row {
                    anchors.centerIn: parent; spacing: 7
                    Icona { nome: "system-search-symbolic"; lato: 14; anchors.verticalCenter: parent.verticalCenter }
                    Text { id: cerca; text: I18n.t("Cerca"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.Medium }
                }
                MouseArea { anchors.fill: parent; onClicked: pagine.currentIndex = 1 }
            }

            // Dock
            Vetro {
                id: dockHome
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: tel.margine - 6; anchors.rightMargin: tel.margine - 6
                anchors.bottom: parent.bottom; anchors.bottomMargin: home.basso
                height: tel.latoIcona + 24; radius: tel.r3 + 4
                Row {
                    anchors.left: parent.left; anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: home.dock
                        Item {
                            required property var modelData
                            required property int index
                            width: (dockHome.width - 12) / Math.max(4, home.dock.length); height: tel.latoIcona
                            IconaApp { anchors.horizontalCenter: parent.horizontalCenter; app: parent.modelData; conNome: false; ritardo: parent.index * 35 }
                        }
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
        anchors.bottomMargin: home.basso + tel.latoIcona + 24 + 14 + 32 + 10
        count: pagine.count
        currentIndex: pagine.currentIndex
        visible: pagine.currentIndex === 0
        spacing: 6
        delegate: Rectangle { required property int index; width: index === pagine.currentIndex ? 16 : 6; height: 6; radius: 3; color: tel.pal.testo; opacity: index === pagine.currentIndex ? 0.9 : 0.3 }
    }
}
