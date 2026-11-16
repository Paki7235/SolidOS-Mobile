// Mappa OpenStreetMap leggera: tessere 256×256 scaricate dal backend (ponte.tessere),
// trascinamento con il mouse, rotellina e pulsanti per lo zoom, segnaposto dei dispositivi
// con il cerchio della precisione.
import QtQuick
import SolidUI

Item {
    id: mappa
    clip: true
    property real lat: 41.9
    property real lon: 12.5
    property int zoom: 5
    property var segnaposti: []          // [{id, lat, lon, nome, tipo, icona, precisione, scelto}]
    signal segnapostoScelto(string ident)

    property var tessere: ({})           // "stile/z/x/y" → "file:///…"
    readonly property string stile: "osm"
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

    function centra(la, lo, z) { lat = la; lon = lo; if (z !== undefined) zoom = Math.max(2, Math.min(18, z)) }
    function zooma(d) { zoom = Math.max(2, Math.min(18, zoom + d)) }
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
            if (mancanti.length) ponte.avvia("tessere", [mancanti, mappa.stile], "tessere")
        }
    }
    Connections {
        target: ponte
        function onCompletato(id, r) {
            if (id !== "tessere") return
            mappa.tessere = Object.assign({}, mappa.tessere, r)
            mappa.richieste = ({})
        }
    }

    Rectangle { anchors.fill: parent; color: tel.chiaro ? "#E8E6E1" : "#2A2C31" }
    Repeater {
        model: mappa.visibili
        Image {
            required property var modelData
            x: modelData.sx; y: modelData.sy
            width: mappa.lato; height: mappa.lato
            source: mappa.tessere[modelData.chiave] || ""
            asynchronous: true
            smooth: true
            // Col tema scuro la mappa si attenua un po' per non abbagliare
            opacity: tel.chiaro ? 1 : 0.86
        }
    }

    // Trascinare per spostarsi
    DragHandler {
        id: trascina
        target: null
        property real inizioX: 0
        property real inizioY: 0
        onActiveChanged: if (active) { inizioX = mappa.cx; inizioY = mappa.cy }
        onTranslationChanged: if (active) {
            mappa.lon = mappa.lonDa(inizioX - translation.x)
            mappa.lat = mappa.latDa(Math.max(0, Math.min(mappa.mondo, inizioY - translation.y)))
        }
    }
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function (e) { mappa.zooma(e.angleDelta.y > 0 ? 1 : -1) }
    }
    TapHandler { onDoubleTapped: mappa.zooma(1) }
    PinchHandler { target: null; onActiveScaleChanged: if (activeScale > 1.6) { mappa.zooma(1) } else if (activeScale < 0.6) { mappa.zooma(-1) } }

    // Segnaposti
    Repeater {
        model: mappa.segnaposti
        Item {
            required property var modelData
            x: mappa.px(modelData.lon) - mappa.cx + mappa.width / 2
            y: mappa.py(modelData.lat) - mappa.cy + mappa.height / 2
            z: modelData.scelto ? 3 : 2
            Rectangle {   // precisione
                readonly property real r: Math.min(2000, (modelData.precisione || 0) / mappa.metriPerPixel())
                visible: r > 14
                width: r * 2; height: r * 2; radius: r
                x: -r; y: -r
                color: Qt.rgba(tel.accento.r, tel.accento.g, tel.accento.b, 0.14)
                border.color: Qt.rgba(tel.accento.r, tel.accento.g, tel.accento.b, 0.5)
            }
            Rectangle {
                width: modelData.scelto ? 46 : 38; height: width; radius: width / 2
                x: -width / 2; y: -height / 2
                color: "#FFFFFF"
                border.color: modelData.scelto ? tel.accento : "#33000000"
                border.width: modelData.scelto ? 3 : 1
                Behavior on width { NumberAnimation { duration: 120 } }
                IconaDispositivo { anchors.centerIn: parent; tipo: modelData.tipo || "computer"; icona: modelData.icona; lato: parent.width * 0.55 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: mappa.segnapostoScelto(modelData.id) }
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: (modelData.scelto ? 26 : 22)
                width: etichetta.implicitWidth + 14; height: etichetta.implicitHeight + 6; radius: height / 2
                color: tel.chiaro ? "#F2FFFFFF" : "#E6202227"
                Text { id: etichetta; anchors.centerIn: parent; text: modelData.nome; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 12; font.weight: Font.DemiBold }
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
                color: zoomArea.containsMouse ? tel.pal.traccia : (tel.pal.superficie)
                border.color: tel.pal.vetroBordo
                Text { anchors.centerIn: parent; text: parent.modelData.t; color: tel.pal.testo; font.pixelSize: 18; font.weight: Font.DemiBold }
                MouseArea { id: zoomArea; anchors.fill: parent; hoverEnabled: true; onClicked: mappa.zooma(parent.modelData.d) }
            }
        }
    }
    Text {
        anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 4
        text: "© OpenStreetMap"
        color: "#99000000"; font.pixelSize: 10
        Rectangle { anchors.fill: parent; anchors.margins: -2; z: -1; color: "#B3FFFFFF"; radius: 3 }
    }
}
