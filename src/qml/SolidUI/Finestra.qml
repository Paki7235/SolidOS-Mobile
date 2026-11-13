// Finestra principale delle app: sfondo, colori e font del tema.
import QtQuick
import QtQuick.Controls
import QtQuick.Window

ApplicationWindow {
    id: finestra
    width: 960
    height: 640
    minimumWidth: 480
    minimumHeight: 360
    visible: true
    color: Tema.sfondo
    font.family: Tema.font
    font.pointSize: Tema.fontDimensione
    palette.window: Tema.sfondo
    palette.windowText: Tema.testo
    palette.base: Tema.superficie
    palette.text: Tema.testo
    palette.button: Tema.superficieAlta
    palette.buttonText: Tema.testo
    palette.highlight: Tema.accento
    palette.highlightedText: "#FFFFFF"
    palette.placeholderText: Tema.testoSecondario

    // La finestra non deve mai superare lo spazio utile (barra in alto 28 px, dock 74 px):
    // altrimenti la barra del titolo con i pulsanti finirebbe fuori dallo schermo.
    Component.onCompleted: {
        var maxL = Screen.width - 48, maxA = Screen.height - 28 - 74 - 40
        if (maxL > 300 && width > maxL) width = maxL
        if (maxA > 240 && height > maxA) height = maxA
        if (minimumWidth > width) minimumWidth = width
        if (minimumHeight > height) minimumHeight = height
    }

    // Messaggio temporaneo in basso: finestra.avviso("Fatto")
    function avviso(testo) { toast.mostra(testo) }

    Messaggio { id: toast; z: 1000 }
}
