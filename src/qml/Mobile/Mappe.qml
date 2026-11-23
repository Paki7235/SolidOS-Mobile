// Mappe sul telefono: la carta di SolidOS a tutto schermo (la stessa del PC: disegnata da noi
// dai dati di OpenStreetMap), la ricerca in alto e un foglio in basso con il luogo, il percorso
// (auto, bici, a piedi) e «Avvia». Durante la guida: la manovra grande in alto, arrivo e tempo
// in basso, indicazioni a voce. La posizione arriva dal GPS (o dalle reti Wi-Fi).
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: app
    color: tel.pal.sfondo

    property var qui: null
    property var risultati: []
    property var luogo: null
    property var percorso: null
    property string mezzo: "auto"
    property bool calcolo: false
    property bool guidando: false
    property bool prova: false
    property var stato: null
    property int indiceProva: 0
    property bool voce: true
    property string ultimoAnnuncio: ""
    property bool seguendo: true

    function m(metodo, argomenti) { return ponte.chiama("mappe", [metodo, argomenti || []]) }
    function ma(metodo, argomenti, id) { ponte.avvia("mappe", [metodo, argomenti || []], id) }
    function cerca(t) { if (t.length < 2) { risultati = []; return } ma("cerca", [t, qui ? qui.lat : "", qui ? qui.lon : ""], "mappe-cerca") }
    function scegli(l) {
        luogo = l; percorso = null; risultati = []; campo.focus = false
        carta.centra(l.lat, l.lon, Math.max(carta.zoom, 15))
        m("ricorda", [l])
    }
    function indicazioni() {
        if (!luogo) return
        if (!qui) { tel.avviso(I18n.t("Sto cercando dove sei… riprova tra poco")); ma("posizione", [], "mappe-qui"); return }
        calcolo = true
        ma("percorso", [{ lat: qui.lat, lon: qui.lon }, { lat: luogo.lat, lon: luogo.lon }, mezzo], "mappe-percorso")
    }
    function avvia(simulata) {
        prova = simulata; guidando = true; seguendo = true; indiceProva = 0; ultimoAnnuncio = ""
        carta.zoom = 16
        aggiorna(simulata ? { lat: percorso.forma[0][0], lon: percorso.forma[0][1] } : qui)
    }
    function termina() { guidando = false; prova = false; stato = null; carta.fattoFino = 0; if (percorso) carta.inquadra(percorso.forma) }
    function aggiorna(pos) {
        if (!pos) return
        var g = m("guida", [pos.lat, pos.lon, stato ? stato.indice : 0])
        if (!g || !g.ok) return
        stato = g
        carta.fattoFino = g.indice
        if (seguendo) carta.centra(pos.lat, pos.lon)
        if (g.arrivato) { if (voce) m("parla", [I18n.t("Sei arrivato")]); tel.avviso(I18n.t("Sei arrivato a destinazione")); termina(); return }
        if (g.fuori && !prova) { qui = pos; indicazioni(); return }
        var chiave = g.manovra.inizio + (g.metriAllaManovra < 60 ? "-ora" : (g.metriAllaManovra < 320 ? "-presto" : ""))
        if (voce && chiave !== ultimoAnnuncio && g.metriAllaManovra < 320) {
            ultimoAnnuncio = chiave
            m("parla", [g.metriAllaManovra < 60 ? g.manovra.testo : I18n.t("Tra") + " " + g.allaManovra + ", " + g.manovra.annuncio])
        }
    }
    function freccia(tipo) {
        if ([4, 5, 6].indexOf(tipo) >= 0) return "⚑"
        if ([9, 18, 20, 23].indexOf(tipo) >= 0) return "↗"
        if (tipo === 10) return "→"
        if (tipo === 11) return "↘"
        if ([12, 13].indexOf(tipo) >= 0) return "↶"
        if (tipo === 14) return "↙"
        if (tipo === 15) return "←"
        if ([16, 19, 21, 24].indexOf(tipo) >= 0) return "↖"
        if ([26, 27].indexOf(tipo) >= 0) return "⟳"
        return "↑"
    }

    Connections {
        target: ponte
        function onCompletato(id, r) {
            if (id === "mappe-qui" || id === "mappe-guida-qui") {
                if (r && r.lat !== undefined) {
                    app.qui = r
                    if (id === "mappe-guida-qui") app.aggiorna(r)
                    else if (!app.luogo && !app.guidando) carta.centra(r.lat, r.lon, 15)
                }
            } else if (id === "mappe-cerca") app.risultati = r || []
            else if (id === "mappe-percorso") {
                app.calcolo = false
                if (!r || !r.ok) { tel.avviso(r ? r.messaggio : I18n.t("Nessun percorso trovato")); return }
                app.percorso = r
                if (!app.guidando) carta.inquadra(r.forma)
            } else if (id === "mappe-punto") app.scegli(r)
        }
    }
    Component.onCompleted: ma("posizione", [], "mappe-qui")

    Timer {
        interval: app.prova ? 700 : 2000
        repeat: true
        running: app.guidando
        onTriggered: {
            if (app.prova) {
                var f = app.percorso.forma
                app.indiceProva = Math.min(f.length - 1, app.indiceProva + (app.mezzo === "piedi" ? 1 : (app.mezzo === "bici" ? 2 : 4)))
                var p = { lat: f[app.indiceProva][0], lon: f[app.indiceProva][1] }
                var s = f[Math.min(f.length - 1, app.indiceProva + 1)]
                p.direzione = Math.atan2((s[1] - p.lon) * Math.cos(p.lat * Math.PI / 180), s[0] - p.lat) * 180 / Math.PI
                app.qui = p
                app.aggiorna(p)
            } else app.ma("posizione", [], "mappe-guida-qui")
        }
    }

    MappeCarta {
        id: carta
        anchors.fill: parent
        zoom: 6; lat: 42.5; lon: 12.5
        forma: app.percorso ? app.percorso.forma : []
        posizione: app.qui
        segnaposti: {
            var s = []
            if (app.luogo) s.push({ id: "luogo", lat: app.luogo.lat, lon: app.luogo.lon, nome: app.luogo.nome, colore: "#EF4444" })
            for (var i = 0; i < app.risultati.length; i++) s.push({ id: "r" + i, lat: app.risultati[i].lat, lon: app.risultati[i].lon, nome: "", colore: "#F97316" })
            return s
        }
        onSegnapostoScelto: function (ident) { if (ident.charAt(0) === "r") app.scegli(app.risultati[parseInt(ident.slice(1))]) }
        onPuntoScelto: function (la, lo) { app.ma("indirizzo", [la, lo], "mappe-punto") }
        onSpostataAMano: app.seguendo = false
    }

    // ── Ricerca in alto ──
    Rectangle {
        visible: !app.guidando
        x: tel.margine; y: 52
        width: parent.width - 2 * tel.margine; height: 48
        radius: 24
        color: tel.chiaro ? "#F2FFFFFF" : "#EB1E293B"
        border.color: tel.pal.bordo
        Row {
            anchors.fill: parent; anchors.leftMargin: 16; spacing: 10
            Text { anchors.verticalCenter: parent.verticalCenter; text: "⌕"; color: tel.pal.testo2; font.pixelSize: 20 }
            TextInput {
                id: campo
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 60
                color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 16
                clip: true
                onTextChanged: attesa.restart()
                Text { visible: !campo.text; text: I18n.t("Cerca un luogo"); color: tel.pal.testo3; font: campo.font }
                Timer { id: attesa; interval: 500; onTriggered: app.cerca(campo.text) }
            }
        }
    }

    // ── Foglio in basso: risultati, luogo, percorso ──
    Rectangle {
        id: foglio
        visible: !app.guidando && (app.risultati.length > 0 || !!app.luogo)
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: Math.min(parent.height * 0.62, colFoglio.implicitHeight + 40)
        radius: 26
        color: tel.chiaro ? "#F7FFFFFF" : "#F21E293B"
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 8; width: 40; height: 5; radius: 3; color: tel.pal.testo3; opacity: 0.6 }
        Flickable {
            anchors.fill: parent; anchors.topMargin: 22; anchors.leftMargin: tel.margine; anchors.rightMargin: tel.margine; anchors.bottomMargin: 18
            contentHeight: colFoglio.implicitHeight
            clip: true
            Column {
                id: colFoglio
                width: parent.width
                spacing: 10
                Repeater {
                    model: app.risultati
                    Item {
                        width: colFoglio.width; height: 52
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            Text { width: parent.width; text: modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.DemiBold; elide: Text.ElideRight }
                            Text { width: parent.width; text: modelData.dettaglio; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 13; elide: Text.ElideRight }
                        }
                        MouseArea { anchors.fill: parent; onClicked: app.scegli(modelData) }
                    }
                }
                Column {
                    visible: !!app.luogo && app.risultati.length === 0
                    width: parent.width
                    spacing: 10
                    Text { width: parent.width; text: app.luogo ? app.luogo.nome : ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 22; font.weight: Font.Bold; wrapMode: Text.WordWrap }
                    Text { width: parent.width; text: app.luogo ? app.luogo.dettaglio : ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 14; wrapMode: Text.WordWrap }
                    Row {
                        spacing: 8
                        Repeater {
                            model: [{ id: "auto", t: "🚗" }, { id: "bici", t: "🚲" }, { id: "piedi", t: "🚶" }]
                            Rectangle {
                                width: 56; height: 40; radius: 20
                                color: app.mezzo === modelData.id ? tel.accento : tel.pal.superficie2
                                Text { anchors.centerIn: parent; text: modelData.t; font.pixelSize: 18 }
                                MouseArea { anchors.fill: parent; onClicked: { app.mezzo = modelData.id; if (app.percorso) app.indicazioni() } }
                            }
                        }
                    }
                    Rectangle {
                        visible: !app.percorso
                        width: parent.width; height: 48; radius: 24
                        color: tel.accento
                        Text { anchors.centerIn: parent; text: app.calcolo ? I18n.t("Calcolo il percorso…") : I18n.t("Indicazioni"); color: "white"; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.DemiBold }
                        MouseArea { anchors.fill: parent; onClicked: app.indicazioni() }
                    }
                    Row {
                        visible: !!app.percorso
                        spacing: 10
                        Text { text: app.percorso ? app.percorso.tempo : ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 26; font.weight: Font.Bold }
                        Text { anchors.baseline: parent.children[0].baseline; text: app.percorso ? app.percorso.distanza + " · " + app.percorso.arrivo : ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 14 }
                    }
                    Row {
                        visible: !!app.percorso
                        spacing: 10
                        Rectangle {
                            width: (colFoglio.width - 10) * 0.6; height: 48; radius: 24; color: "#22C55E"
                            Text { anchors.centerIn: parent; text: I18n.t("Avvia"); color: "white"; font.family: Tema.font; font.pixelSize: 17; font.weight: Font.Bold }
                            MouseArea { anchors.fill: parent; onClicked: app.avvia(false) }
                        }
                        Rectangle {
                            width: (colFoglio.width - 10) * 0.4; height: 48; radius: 24; color: tel.pal.superficie2
                            Text { anchors.centerIn: parent; text: I18n.t("Prova"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 15 }
                            MouseArea { anchors.fill: parent; onClicked: app.avvia(true) }
                        }
                    }
                    Repeater {
                        model: app.percorso ? app.percorso.manovre : []
                        Row {
                            width: colFoglio.width; spacing: 12
                            Text { width: 22; text: app.freccia(modelData.tipo); color: tel.accento; font.pixelSize: 18; horizontalAlignment: Text.AlignHCenter }
                            Text { width: parent.width - 34; text: modelData.testo; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 14; wrapMode: Text.WordWrap }
                        }
                    }
                }
            }
        }
    }

    // ── Guida ──
    Rectangle {
        visible: app.guidando && !!app.stato
        x: tel.margine; y: 48
        width: parent.width - 2 * tel.margine; height: 104
        radius: 24
        color: "#1E3A8A"
        Row {
            anchors.fill: parent; anchors.margins: 16; spacing: 16
            Text { anchors.verticalCenter: parent.verticalCenter; text: app.stato ? app.freccia(app.stato.manovra.tipo) : ""; color: "white"; font.pixelSize: 44; font.weight: Font.Bold }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 80
                Text { text: app.stato ? app.stato.allaManovra : ""; color: "white"; font.family: Tema.font; font.pixelSize: 28; font.weight: Font.Bold }
                Text { width: parent.width; text: app.stato ? app.stato.manovra.testo : ""; color: "#E0E7FF"; font.family: Tema.font; font.pixelSize: 15; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
            }
        }
    }
    Rectangle {
        visible: app.guidando
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 96; radius: 26
        color: tel.chiaro ? "#F7FFFFFF" : "#F21E293B"
        Row {
            anchors.verticalCenter: parent.verticalCenter; x: tel.margine + 6; spacing: 18
            Column {
                Text { text: app.stato ? app.stato.arrivo : ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 24; font.weight: Font.Bold }
                Text { text: I18n.t("arrivo"); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 12 }
            }
            Column {
                Text { text: app.stato ? app.stato.tempo : ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 20; font.weight: Font.DemiBold }
                Text { text: app.stato ? app.stato.resta : ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: 12 }
            }
        }
        Row {
            anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; anchors.rightMargin: tel.margine; spacing: 10
            Rectangle {
                width: 48; height: 48; radius: 24; color: tel.pal.superficie2
                Text { anchors.centerIn: parent; text: app.voce ? "🔊" : "🔇"; font.pixelSize: 18 }
                MouseArea { anchors.fill: parent; onClicked: app.voce = !app.voce }
            }
            Rectangle {
                width: 84; height: 48; radius: 24; color: "#EF4444"
                Text { anchors.centerIn: parent; text: I18n.t("Fine"); color: "white"; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.DemiBold }
                MouseArea { anchors.fill: parent; onClicked: app.termina() }
            }
        }
    }
    // Dove sono
    Rectangle {
        visible: !app.guidando
        anchors.right: parent.right; anchors.rightMargin: tel.margine
        y: 112
        width: 44; height: 44; radius: 22
        color: tel.chiaro ? "#F2FFFFFF" : "#EB1E293B"
        Text { anchors.centerIn: parent; text: "➤"; rotation: -45; color: tel.accento; font.pixelSize: 18 }
        MouseArea { anchors.fill: parent; onClicked: { if (app.qui) carta.centra(app.qui.lat, app.qui.lon, 16); app.ma("posizione", [], "mappe-qui") } }
    }
}
