// Barra fatta di puntini (batteria, luminosità, volume): i puntini accesi sono pieni, gli
// altri appena visibili. «valore» da 0 a 100; «righe» quante file di puntini.
import QtQuick
import SolidUI

Canvas {
    id: bp
    property real valore: 50
    property int righe: 4
    property real passo: 7
    property color acceso: tel.pal.testo
    property color spento: tel.chiaro ? "#D4D4D4" : "#333333"
    onValoreChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onAccesoChanged: requestPaint()
    onSpentoChanged: requestPaint()
    onPaint: {
        var g = getContext("2d")
        g.reset()
        var colonne = Math.max(1, Math.floor(width / passo))
        var fino = Math.round(colonne * Math.max(0, Math.min(100, valore)) / 100)
        var oy = (height - righe * passo) / 2 + passo / 2
        for (var c = 0; c < colonne; c++) {
            g.fillStyle = c < fino ? acceso : spento
            for (var r = 0; r < righe; r++) {
                g.beginPath(); g.arc(c * passo + passo / 2, oy + r * passo, passo * 0.2, 0, 2 * Math.PI); g.fill()
            }
        }
    }
}
