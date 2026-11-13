import QtQuick
import QtQuick.Controls

ProgressBar {
    id: barra
    background: Rectangle { implicitHeight: 8; implicitWidth: 200; radius: 4; color: Tema.bordo }
    contentItem: Item {
        Rectangle {
            width: barra.indeterminate ? parent.width * 0.3 : barra.visualPosition * parent.width
            height: parent.height
            radius: 4
            color: Tema.accento
            SequentialAnimation on x {
                running: barra.indeterminate && Tema.animazioni
                loops: Animation.Infinite
                NumberAnimation { from: 0; to: barra.width * 0.7; duration: 900 }
                NumberAnimation { from: barra.width * 0.7; to: 0; duration: 900 }
            }
        }
    }
}
