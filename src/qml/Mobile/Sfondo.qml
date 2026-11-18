// Sfondo del telefono nello stile «Essenziale»: nero pieno (grigio chiarissimo nel tema
// chiaro), oppure una griglia di puntini appena visibile, oppure grafite. Niente file da
// scaricare. Se «nome» è un percorso (una foto scelta in Foto) si mostra quella foto.
import QtQuick

Item {
    id: sf
    property string nome: "nero"
    property bool chiaro: false
    readonly property bool foto: nome.charAt(0) === "/"
    // I vecchi sfondi colorati (notte, alba, oceano…) diventano il nero
    readonly property string tipo: ["nero", "puntini", "grafite"].indexOf(nome) >= 0 ? nome : "nero"

    Rectangle {
        anchors.fill: parent
        visible: !sf.foto
        color: sf.tipo === "grafite" ? (sf.chiaro ? "#E4E4E4" : "#141414") : (sf.chiaro ? "#F2F2F2" : "#000000")
    }
    // Griglia di puntini, disegnata una volta per grandezza dello schermo
    Canvas {
        id: griglia
        anchors.fill: parent
        visible: !sf.foto && sf.tipo === "puntini"
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        Connections { target: sf; function onChiaroChanged() { griglia.requestPaint() } }
        onPaint: {
            var g = getContext("2d")
            g.reset()
            if (!visible) return
            g.fillStyle = sf.chiaro ? "#CFCFCF" : "#2A2A2A"
            for (var y = 7; y < height; y += 14)
                for (var x = 7; x < width; x += 14) { g.beginPath(); g.arc(x, y, 1.2, 0, 2 * Math.PI); g.fill() }
        }
    }
    Image {
        anchors.fill: parent
        visible: sf.foto
        source: sf.foto ? "file://" + sf.nome : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.height: 1600
    }
    // Sulle foto un velo tiene leggibili ora e icone
    Rectangle { anchors.fill: parent; visible: sf.foto; color: sf.chiaro ? "#33FFFFFF" : "#59000000" }
}
