// Contenitore arrotondato per raggruppare contenuti (gruppo di impostazioni, riquadro).
import QtQuick

Rectangle {
    default property alias contenuto: interno.data
    property int margine: 16
    color: Tema.chiaro ? "#FFFFFF" : Tema.superficie
    radius: 10
    border.color: Tema.chiaro ? "#14000000" : "#14FFFFFF"
    border.width: 1
    implicitHeight: interno.childrenRect.height + margine * 2
    Item {
        id: interno
        anchors.fill: parent
        anchors.margins: parent.margine
    }
}
