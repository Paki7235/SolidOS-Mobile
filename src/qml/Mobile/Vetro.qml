// Scheda dello stile «Essenziale»: superficie piena (sotto non si vede niente), bordo
// sottile di un pixel, angoli del design. È la base di schede, pannelli e tasti.
import QtQuick

Rectangle {
    color: tel.pal.vetro
    border.color: tel.pal.vetroBordo
    border.width: 1
    radius: tel.r3
}
