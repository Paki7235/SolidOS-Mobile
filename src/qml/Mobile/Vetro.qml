// Pannello sopra lo sfondo (blocco, Home, tendine): scuro o chiaro e quasi pieno,
// bordo sottile, angoli del design. Niente sfocatura (costa memoria e batteria).
import QtQuick

Rectangle {
    color: tel.pal.vetro
    border.color: tel.pal.vetroBordo
    border.width: 1
    radius: tel.r3
}
