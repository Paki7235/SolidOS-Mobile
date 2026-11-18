// Titolo grande delle app, sempre nello stesso posto; a destra i tasti dell'app (figli)
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
        text: ti.testo
    }
    Row { id: fila; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 8 }
}
