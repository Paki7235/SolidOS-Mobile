// Sfondo del telefono disegnato dal sistema: un fondo calmo con due aloni di colore
// leggeri. Niente file da scaricare, nitido su ogni schermo, chiaro e scuro.
// Se «nome» è un percorso (una foto scelta in Foto) si mostra quella foto.
import QtQuick

Item {
    id: sf
    property string nome: "notte"
    property bool chiaro: false
    readonly property bool foto: nome.charAt(0) === "/"

    // base, alone 1 (in alto a destra), alone 2 (in basso a sinistra), intensità
    readonly property var tavolozze: ({
        "notte":   { scuro: ["#0A0C12", "#2F5BDB", "#6C4FD8", 0.30], chiaro: ["#F3F5FA", "#9DB6FF", "#C7B7FF", 0.45] },
        "alba":    { scuro: ["#120C0E", "#E2683F", "#C9408A", 0.26], chiaro: ["#FBF5F1", "#FFC09E", "#F5B3D2", 0.45] },
        "oceano":  { scuro: ["#071116", "#1597B0", "#2559D6", 0.28], chiaro: ["#F1F7F9", "#9FDCE8", "#A9C1FF", 0.45] },
        "aurora":  { scuro: ["#08100E", "#1FA37A", "#2F6FD6", 0.26], chiaro: ["#F2F8F5", "#A5E3CB", "#AFC8FF", 0.45] },
        "grafite": { scuro: ["#0C0D0F", "#5A6170", "#3A3F4A", 0.22], chiaro: ["#F2F3F4", "#D7DAE0", "#E3E5EA", 0.55] }
    })
    readonly property var t: (tavolozze[nome] || tavolozze["notte"])[chiaro ? "chiaro" : "scuro"]

    Canvas {
        id: tela
        anchors.fill: parent
        visible: !sf.foto
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections { target: sf; function onTChanged() { tela.requestPaint() } }
        function alone(g, x, y, r, colore, intensita) {
            var c = Qt.color(colore)
            var gr = g.createRadialGradient(x, y, 0, x, y, r)
            gr.addColorStop(0, Qt.rgba(c.r, c.g, c.b, intensita))
            gr.addColorStop(0.55, Qt.rgba(c.r, c.g, c.b, intensita * 0.35))
            gr.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0))
            g.fillStyle = gr
            g.fillRect(0, 0, width, height)
        }
        onPaint: {
            var g = getContext("2d")
            g.reset()
            g.fillStyle = sf.t[0]
            g.fillRect(0, 0, width, height)
            var r = Math.max(width, height)
            alone(g, width * 0.95, height * 0.08, r * 0.75, sf.t[1], sf.t[3])
            alone(g, width * 0.05, height * 0.92, r * 0.70, sf.t[2], sf.t[3] * 0.8)
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
    // Sulle foto un velo leggero tiene leggibili ora e icone
    Rectangle { anchors.fill: parent; visible: sf.foto; color: sf.chiaro ? "#26FFFFFF" : "#40000000" }
}
