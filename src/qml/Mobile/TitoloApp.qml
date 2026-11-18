// Titolo delle app, a puntini e maiuscolo, sempre nello stesso posto (come «MESSAGGI»).
// A destra si possono mettere i tasti dell'app (figli di questo elemento).
import QtQuick
import SolidUI

Item {
    id: ti
    property string testo: ""
    default property alias tasti: fila.data
    x: tel.margine; y: 54
    width: parent.width - 2 * tel.margine; height: 52
    Punti {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - fila.width - 12
        elide: Text.ElideRight
        text: ti.testo.toUpperCase()
        font.pixelSize: 36
    }
    Row { id: fila; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 8 }
}
