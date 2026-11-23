// Carta delle Mappe di SolidOS: tessere disegnate da noi (nucleo.mappe.disegno) dai dati
// aperti di OpenStreetMap, chiare o scure col tema. Sopra: il percorso, la posizione (punto
// blu con il cerchio della precisione) e i segnaposti dei luoghi. Trascinare, rotellina,
// pizzico; tenere premuto sceglie un punto.
import QtQuick
import SolidUI

Item {
    id: mappa
    clip: true
    property real lat: 41.9
    property real lon: 12.5
    property int zoom: 5
    property var segnaposti: []          // [{id, lat, lon, nome, colore}]
    property var forma: []               // percorso: [[lat, lon], …]
    property var altre: []               // percorsi alternativi (grigi, si possono scegliere)
    signal alternativaScelta(int indice)
    property int fattoFino: 0            // punti del percorso già fatti (grigi durante la guida)
    property var posizione: null         // {lat, lon, precisione, direzione}
    signal segnapostoScelto(string ident)
    signal puntoScelto(real lat, real lon)
    signal spostataAMano()

    property var tessere: ({})           // "stile/z/x/y" → "file:///…"
    readonly property string stile: tel.chiaro ? "chiaro" : "scuro"
    property var richieste: ({})
    readonly property real lato: 256
    readonly property real mondo: Math.pow(2, zoom) * lato

    function px(lo) { return (lo + 180) / 360 * mondo }
    function py(la) {
        var r = Math.max(-85.05, Math.min(85.05, la)) * Math.PI / 180
        return (1 - Math.log(Math.tan(r) + 1 / Math.cos(r)) / Math.PI) / 2 * mondo
    }
    function lonDa(x) { return x / mondo * 360 - 180 }
    function latDa(y) { return Math.atan(Math.sinh(Math.PI * (1 - 2 * y / mondo))) * 180 / Math.PI }
    readonly property real cx: px(lon)
    readonly property real cy: py(lat)

    function centra(la, lo, z) { lat = la; lon = lo; if (z !== undefined) zoom = Math.max(2, Math.min(19, z)) }
    function zooma(d) { zoom = Math.max(2, Math.min(19, zoom + d)) }
    // inquadra tutto il percorso
    function inquadra(punti) {
        if (!punti || punti.length < 2) return
        var la0 = 90, la1 = -90, lo0 = 180, lo1 = -180
        for (var i = 0; i < punti.length; i++) { la0 = Math.min(la0, punti[i][0]); la1 = Math.max(la1, punti[i][0]); lo0 = Math.min(lo0, punti[i][1]); lo1 = Math.max(lo1, punti[i][1]) }
        lat = (la0 + la1) / 2; lon = (lo0 + lo1) / 2
        for (var z = 18; z >= 3; z--) {
            var m = Math.pow(2, z) * lato
            var w = (lo1 - lo0) / 360 * m
            var r0 = la0 * Math.PI / 180, r1 = la1 * Math.PI / 180
            var h = Math.abs(Math.log(Math.tan(r1) + 1 / Math.cos(r1)) - Math.log(Math.tan(r0) + 1 / Math.cos(r0))) / (2 * Math.PI) * m
            if (w < width * 0.8 && h < height * 0.75) { zoom = z; return }
        }
        zoom = 3
    }
    // Metri per pixel alla latitudine attuale (per il cerchio della precisione)
    function metriPerPixel() { return 156543.03 * Math.cos(lat * Math.PI / 180) / Math.pow(2, zoom) }

    // Tessere visibili
    readonly property var visibili: {
        var n = Math.pow(2, zoom), elenco = []
        var x0 = Math.floor((cx - width / 2) / lato), x1 = Math.floor((cx + width / 2) / lato)
        var y0 = Math.max(0, Math.floor((cy - height / 2) / lato)), y1 = Math.min(n - 1, Math.floor((cy + height / 2) / lato))
        for (var ty = y0; ty <= y1; ty++)
            for (var tx = x0; tx <= x1; tx++) {
                var xr = ((tx % n) + n) % n
                elenco.push({ chiave: stile + "/" + zoom + "/" + xr + "/" + ty, z: zoom, x: xr, y: ty,
                              sx: tx * lato - cx + width / 2, sy: ty * lato - cy + height / 2 })
            }
        return elenco
    }
    onVisibiliChanged: chiediTessere.restart()
    Timer {
        id: chiediTessere
        interval: 120
        onTriggered: {
            var mancanti = []
            for (var i = 0; i < mappa.visibili.length; i++) {
                var t = mappa.visibili[i]
                if (!mappa.tessere[t.chiave] && !mappa.richieste[t.chiave]) { mancanti.push([t.z, t.x, t.y]); mappa.richieste[t.chiave] = true }
            }
            if (mancanti.length) ponte.avvia("mappe", ["tessere", [mancanti, mappa.stile]], "mappeTessere")
        }
    }
    Connections {
        target: ponte
        function onCompletato(id, r) {
            if (id !== "mappeTessere") return
            var nuove = Object.assign({}, mappa.tessere), attese = Object.assign({}, mappa.richieste)
            for (var k in r) { if (r[k]) nuove[k] = r[k]; delete attese[k] }
            mappa.tessere = nuove
            mappa.richieste = attese
        }
    }

    Rectangle { anchors.fill: parent; color: Tema.chiaro ? "#E8E6E1" : "#2A2C31" }
    Repeater {
        model: mappa.visibili
        Image {
            required property var modelData
            x: modelData.sx; y: modelData.sy
            width: mappa.lato; height: mappa.lato
            source: mappa.tessere[modelData.chiave] || ""
            // subito dalla memoria: durante la guida la carta si sposta di continuo
            asynchronous: false
            cache: true
            smooth: true
            opacity: 1
        }
    }

    // Trascinare per spostarsi
    DragHandler {
        id: trascina
        target: null
        property real inizioX: 0
        property real inizioY: 0
        onActiveChanged: if (active) { inizioX = mappa.cx; inizioY = mappa.cy; mappa.spostataAMano() }
        onTranslationChanged: if (active) {
            mappa.lon = mappa.lonDa(inizioX - translation.x)
            mappa.lat = mappa.latDa(Math.max(0, Math.min(mappa.mondo, inizioY - translation.y)))
        }
    }
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function (e) { mappa.zooma(e.angleDelta.y > 0 ? 1 : -1) }
    }
    TapHandler {
        onDoubleTapped: mappa.zooma(1)
        onLongPressed: mappa.puntoScelto(mappa.latDa(mappa.cy - mappa.height / 2 + point.position.y), mappa.lonDa(mappa.cx - mappa.width / 2 + point.position.x))
    }

    // Percorso: bordo scuro e linea del colore del sistema; il tratto già fatto in grigio
    Canvas {
        id: tracciato
        anchors.fill: parent
        visible: mappa.forma.length > 1
        property var chiave: [mappa.cx, mappa.cy, mappa.zoom, mappa.forma, mappa.altre, mappa.fattoFino, mappa.width, mappa.height]
        onChiaveChanged: requestPaint()
        onPaint: {
            var g = getContext("2d"); g.reset()
            var f = mappa.forma
            if (f.length < 2) return
            function disegna(da, a, colore, largo) {
                g.beginPath(); g.lineJoin = "round"; g.lineCap = "round"; g.lineWidth = largo; g.strokeStyle = colore
                for (var i = da; i <= a; i++) {
                    var x = mappa.px(f[i][1]) - mappa.cx + width / 2, y = mappa.py(f[i][0]) - mappa.cy + height / 2
                    if (i === da) g.moveTo(x, y); else g.lineTo(x, y)
                }
                g.stroke()
            }
            for (var k = 0; k < mappa.altre.length; k++) {
                var salva = f; f = mappa.altre[k]
                if (f && f.length > 1) { disegna(0, f.length - 1, "#6B7280", 8); disegna(0, f.length - 1, "#AEB6C2", 5) }
                f = salva
            }
            var fatto = Math.min(mappa.fattoFino, f.length - 1)
            if (fatto > 0) disegna(0, fatto, "#9AA3AE", 6)
            disegna(fatto, f.length - 1, "#1E3FA8", 9)
            disegna(fatto, f.length - 1, "#3B82F6", 6)
        }
    }

    // Posizione: punto blu con alone, freccia se si conosce la direzione
    Item {
        visible: !!mappa.posizione
        z: 4
        x: mappa.posizione ? mappa.px(mappa.posizione.lon) - mappa.cx + mappa.width / 2 : 0
        y: mappa.posizione ? mappa.py(mappa.posizione.lat) - mappa.cy + mappa.height / 2 : 0
        Rectangle {
            readonly property real r: mappa.posizione ? Math.min(1500, (mappa.posizione.precisione || 0) / mappa.metriPerPixel()) : 0
            visible: r > 16
            width: r * 2; height: r * 2; radius: r; x: -r; y: -r
            color: "#223B82F6"; border.color: "#663B82F6"
        }
        Rectangle { width: 22; height: 22; radius: 11; x: -11; y: -11; color: "white"; border.color: "#33000000" }
        Rectangle { width: 16; height: 16; radius: 8; x: -8; y: -8; color: "#3B82F6" }
        Canvas {
            visible: mappa.posizione && mappa.posizione.direzione !== undefined && mappa.posizione.direzione !== null
            width: 40; height: 40; x: -20; y: -20
            rotation: mappa.posizione && mappa.posizione.direzione ? mappa.posizione.direzione : 0
            onPaint: { var g = getContext("2d"); g.reset(); g.fillStyle = "#3B82F6"; g.beginPath(); g.moveTo(20, 0); g.lineTo(27, 10); g.lineTo(13, 10); g.closePath(); g.fill() }
        }
    }
    PinchHandler { target: null; onActiveScaleChanged: if (activeScale > 1.6) { mappa.zooma(1) } else if (activeScale < 0.6) { mappa.zooma(-1) } }

    // Segnaposti dei luoghi: spillo col nome
    Repeater {
        model: mappa.segnaposti
        Item {
            required property var modelData
            x: mappa.px(modelData.lon) - mappa.cx + mappa.width / 2
            y: mappa.py(modelData.lat) - mappa.cy + mappa.height / 2
            z: modelData.scelto ? 3 : 2
            Canvas {
                width: 30; height: 40; x: -15; y: -40
                property color c: modelData.colore || "#EF4444"
                onPaint: {
                    var g = getContext("2d"); g.reset()
                    g.fillStyle = c; g.strokeStyle = "white"; g.lineWidth = 2
                    g.beginPath(); g.moveTo(15, 39); g.bezierCurveTo(4, 25, 2, 19, 2, 14); g.arc(15, 14, 13, Math.PI, 0); g.bezierCurveTo(28, 19, 26, 25, 15, 39); g.closePath(); g.fill(); g.stroke()
                    g.fillStyle = "white"; g.beginPath(); g.arc(15, 14, 4.5, 0, Math.PI * 2); g.fill()
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: mappa.segnapostoScelto(modelData.id) }
            }
            Rectangle {
                visible: !!modelData.nome
                anchors.horizontalCenter: parent.horizontalCenter
                y: 4
                width: etichetta.implicitWidth + 14; height: etichetta.implicitHeight + 6; radius: height / 2
                color: Tema.chiaro ? "#F2FFFFFF" : "#E6202227"
                Text { id: etichetta; anchors.centerIn: parent; text: modelData.nome || ""; color: Tema.testo; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold }
            }
        }
    }

    // Zoom
    Column {
        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 14
        spacing: 1
        Repeater {
            model: [{ t: "+", d: 1 }, { t: "−", d: -1 }]
            Rectangle {
                required property var modelData
                width: 34; height: 34; radius: 8
                color: zoomArea.containsMouse ? Tema.superficieAlta : Tema.superficie
                border.color: Tema.bordo
                Text { anchors.centerIn: parent; text: parent.modelData.t; color: Tema.testo; font.pixelSize: 18; font.weight: Font.DemiBold }
                MouseArea { id: zoomArea; anchors.fill: parent; hoverEnabled: true; onClicked: mappa.zooma(parent.modelData.d) }
            }
        }
    }
    Text {
        anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 4
        text: "© OpenStreetMap · OpenFreeMap"
        color: "#99000000"; font.pixelSize: 10
        Rectangle { anchors.fill: parent; anchors.margins: -2; z: -1; color: "#B3FFFFFF"; radius: 3 }
    }

    // Scala: una barretta con una distanza tonda (100 m, 1 km…)
    Item {
        id: scala
        anchors.left: parent.left; anchors.leftMargin: 10
        anchors.bottom: parent.bottom; anchors.bottomMargin: 26
        readonly property var misura: {
            var mpp = mappa.metriPerPixel(), tonde = [5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000, 100000, 200000, 500000, 1000000]
            var scelta = tonde[0]
            for (var i = 0; i < tonde.length; i++) if (tonde[i] / mpp <= 110) scelta = tonde[i]
            return { metri: scelta, px: scelta / mpp }
        }
        width: misura.px; height: 16
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 3; radius: 1.5; color: Tema.chiaro ? "#3B3F46" : "#E3E7EE" }
        Text {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 5
            text: scala.misura.metri >= 1000 ? (scala.misura.metri / 1000) + " km" : scala.misura.metri + " m"
            color: Tema.chiaro ? "#3B3F46" : "#E3E7EE"; font.pixelSize: 11; font.weight: Font.DemiBold
            style: Text.Outline; styleColor: Tema.chiaro ? "#F7F5F1" : "#1C2028"
        }
    }
}
