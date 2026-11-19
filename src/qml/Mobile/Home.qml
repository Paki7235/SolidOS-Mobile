// Home: i widget scelti (Calendario, Batterie, Meteo, Musica, Foto, Note, Orologio in tre
// misure), la griglia delle app (senza ripetere quelle del Dock), la ricerca e il Dock di vetro.
// Tieni premuto per modificarla: le icone tremano, si spostano trascinandole, «−» le toglie,
// «+» aggiunge un widget. Scorrendo a sinistra si arriva
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
    readonly property real altezzaCella: tel.latoIcona + 28 + 16
    readonly property int batteria: tel.stato && tel.stato.batteria ? tel.stato.batteria.livello : 100
    readonly property int notifiche: tel.elencoNotifiche ? tel.elencoNotifiche.length : 0
    // Un'app ha novità se c'è una sua notifica (puntino rosso sull'icona)
    // Sposta un'app della Home (ordine salvato) o la toglie (resta nella Libreria)
    function sposta(da, a) {
        var ids = appGriglia.map(function (x) { return x.id })
        var x = ids.splice(da, 1)[0]
        ids.splice(a, 0, x)
        tel.imposta("ordine_home", ids)
        app = ponte.chiama0("home")
    }
    function togli(i) {
        var a = appGriglia[i]
        if (!a) return
        tel.imposta("nascoste_home", (tel.imp.nascoste_home || []).concat([a.id]))
        app = ponte.chiama0("home")
        tel.avviso(a.nome + ": " + I18n.t("tolta dalla Home, la trovi nella Libreria"))
    }
    Connections { target: tel; function onAppInternaChanged() { if (tel.appInterna) tel.modificaHome = false } }
    function haNovita(a) { return (tel.elencoNotifiche || []).some(function (n) { return n.icona === a.icona }) }

    SwipeView {
        id: pagine
        anchors.fill: parent
        anchors.topMargin: 44

        // ── Pagina 1: Home ────────────────────────────────────────────────
        Item {
            id: paginaHome

            // Widget (Personalizzabili: tieni premuto per modificare la Home, «+» per aggiungerne)
            Flow {
                id: cima
                x: tel.margine; y: tel.modificaHome ? 60 : 16
                Behavior on y { NumberAnimation { duration: tel.tNormale; easing.type: Easing.OutQuint } }
                width: home.width - 2 * tel.margine
                spacing: 14
                readonly property real lato: (home.width - 2 * tel.margine - 14) / 2
                readonly property real alto: Math.min(160, Math.max(140, home.height * 0.185))
                Repeater {
                    model: tel.imp.widget || []
                    Item {
                        id: posto
                        required property var modelData
                        required property int index
                        width: wid.width; height: wid.height
                        Widget { id: wid; tipo: posto.modelData.tipo; misura: posto.modelData.misura; cella: cima.lato; alto: cima.alto }
                        // In modifica: tocca per cambiare misura, «−» per toglierlo
                        MouseArea {
                            anchors.fill: parent; enabled: tel.modificaHome
                            onClicked: {
                                var l = tel.imp.widget.slice(), m = ["piccolo", "medio", "grande"]
                                l[posto.index] = { tipo: posto.modelData.tipo, misura: m[(m.indexOf(posto.modelData.misura) + 1) % 3] }
                                tel.imposta("widget", l)
                            }
                        }
                        Rectangle {
                            visible: tel.modificaHome
                            x: -6; y: -6; width: 24; height: 24; radius: 12; color: "#E6505058"; border.width: 1; border.color: "#33FFFFFF"
                            Text { anchors.centerIn: parent; anchors.verticalCenterOffset: -1; text: "−"; color: "#FFFFFF"; font.pixelSize: 18; font.bold: true }
                            MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: { var l = tel.imp.widget.slice(); l.splice(posto.index, 1); tel.imposta("widget", l) } }
                        }
                    }
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
                readonly property int visibili: Math.min(home.appGriglia.length, righe * 4)
                Repeater {
                    model: home.appGriglia.slice(0, griglia.righe * 4)
                    Item {
                        required property var modelData
                        required property int index
                        width: home.cella; height: home.altezzaCella
                        opacity: trascina.da === index ? 0.25 : 1
                        IconaApp { anchors.horizontalCenter: parent.horizontalCenter; app: parent.modelData; nuovo: home.haNovita(parent.modelData); ritardo: 40 + parent.index * 30; inHome: true }
                    }
                }
            }
            // Home in modifica: trascina un'icona per spostarla, «−» per toglierla dalla Home
            MouseArea {
                id: trascina
                anchors.fill: griglia; z: 5
                enabled: tel.modificaHome
                property int da: -1
                property point dito
                function indice(x, y) {
                    var c = Math.max(0, Math.min(3, Math.floor(x / home.cella))), r = Math.max(0, Math.floor(y / home.altezzaCella))
                    return Math.max(0, Math.min(griglia.visibili - 1, r * 4 + c))
                }
                onPressed: function (m) {
                    var i = indice(m.x, m.y)
                    var cx = (i % 4) * home.cella + (home.cella - tel.latoIcona) / 2, cy = Math.floor(i / 4) * home.altezzaCella
                    if (m.x - cx < 24 && m.x - cx > -12 && m.y - cy < 24) { home.togli(i); da = -1; return }   // «−»
                    da = i; dito = Qt.point(m.x, m.y)
                }
                onPositionChanged: function (m) { dito = Qt.point(m.x, m.y) }
                onReleased: function (m) { if (da >= 0) { var a = indice(m.x, m.y); if (a !== da) home.sposta(da, a) } da = -1 }
                onCanceled: da = -1
                IconaApp {
                    visible: trascina.da >= 0 && trascina.pressed
                    x: trascina.dito.x - width / 2; y: trascina.dito.y - tel.latoIcona / 2
                    scale: 1.12; opacity: 0.95; enabled: false
                    app: trascina.da >= 0 ? home.appGriglia[trascina.da] : ({})
                }
            }

            // In modifica: «+» (aggiungi un widget) e «Fine»
            Item {
                visible: tel.modificaHome
                x: tel.margine; y: 10; width: home.width - 2 * tel.margine; height: 34
                Vetro {
                    width: 34; height: 34; radius: 17
                    Icona { anchors.centerIn: parent; nome: "linea-piu"; lato: 20 }
                    MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: galleriaWidget.apri() }
                }
                Vetro {
                    anchors.right: parent.right
                    width: fine.implicitWidth + 32; height: 34; radius: 17
                    Text { id: fine; anchors.centerIn: parent; text: I18n.t("Fine"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: tel.modificaHome = false }
                }
            }
            // Tieni premuto lo sfondo per modificare la Home
            MouseArea { anchors.fill: parent; z: -1; onPressAndHold: tel.modificaHome = true; onClicked: tel.modificaHome = false }

            // Ricerca (porta alla Libreria)
            Vetro {
                id: ricerca
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: dockHome.top; anchors.bottomMargin: 16
                width: cerca.implicitWidth + 48; height: 32; radius: 16
                Row {
                    anchors.centerIn: parent; spacing: 7
                    Icona { visible: !tel.modificaHome; nome: "system-search-symbolic"; lato: 14; anchors.verticalCenter: parent.verticalCenter }
                    Text { id: cerca; anchors.verticalCenter: parent.verticalCenter; text: tel.modificaHome ? I18n.t("Tieni premuto e trascina per spostare") : I18n.t("Cerca"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                }
                MouseArea { anchors.fill: parent; anchors.margins: -6; enabled: !tel.modificaHome; onClicked: pagine.currentIndex = 1 }
            }

            // Dock di vetro
            Vetro {
                id: dockHome
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 12; anchors.rightMargin: 12
                anchors.bottom: parent.bottom; anchors.bottomMargin: home.basso
                height: tel.latoIcona + 30; radius: 32
                Row {
                    anchors.left: parent.left; anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: home.dock
                        Item {
                            required property var modelData
                            required property int index
                            width: (dockHome.width - 12) / Math.max(4, home.dock.length); height: tel.latoIcona
                            IconaApp { anchors.horizontalCenter: parent.horizontalCenter; app: parent.modelData; conNome: false; nuovo: home.haNovita(parent.modelData); ritardo: parent.index * 30 }
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
        anchors.bottomMargin: home.basso + tel.latoIcona + 30 + 16 + 32 + 10
        count: pagine.count
        currentIndex: pagine.currentIndex
        visible: pagine.currentIndex === 0
        spacing: 6
        delegate: Rectangle { required property int index; width: 6; height: 6; radius: 3; color: tel.chiaro ? "#1D1D1F" : "#FFFFFF"; opacity: index === pagine.currentIndex ? 0.9 : 0.35 }
    }
}
