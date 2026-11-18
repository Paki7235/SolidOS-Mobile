// Sfondo del telefono: lo stesso del PC (colline, chiaro o scuro), oppure una foto scelta in
// Foto. Si ritaglia al centro per riempire lo schermo.
import QtQuick

Item {
    id: sf
    property string sorgente: tel.sfondo
    readonly property bool foto: tel.imp.sfondo && tel.imp.sfondo.charAt(0) === "/"
    Rectangle { anchors.fill: parent; color: tel.chiaro ? "#C9D3EE" : "#0B0E18" }
    Image {
        anchors.fill: parent
        source: sf.sorgente
        fillMode: Image.PreserveAspectCrop
        sourceSize.height: Math.max(800, sf.height)
        asynchronous: true
        smooth: true
    }
    // Sulle foto un velo tiene leggibili ora e icone
    Rectangle { anchors.fill: parent; visible: sf.foto; color: tel.chiaro ? "#26FFFFFF" : "#40000000" }
}
