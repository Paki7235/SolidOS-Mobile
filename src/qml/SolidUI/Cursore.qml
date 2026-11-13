// Cursore con binario sottile e manopola bianca.
import QtQuick
import QtQuick.Controls

Slider {
    id: cursore
    background: Rectangle {
        x: cursore.leftPadding
        y: cursore.topPadding + cursore.availableHeight / 2 - height / 2
        implicitWidth: 200
        implicitHeight: 4
        width: cursore.availableWidth
        height: implicitHeight
        radius: 2
        color: Tema.chiaro ? "#E5E5EA" : "#48484F"
        Rectangle {
            width: cursore.visualPosition * parent.width
            height: parent.height
            color: Tema.accento
            radius: 2
        }
    }
    handle: Rectangle {
        x: cursore.leftPadding + cursore.visualPosition * (cursore.availableWidth - width)
        y: cursore.topPadding + cursore.availableHeight / 2 - height / 2
        implicitWidth: 20
        implicitHeight: 20
        radius: 10
        color: cursore.pressed ? "#F2F2F7" : "#FFFFFF"
        border.color: "#26000000"
        border.width: 0.5
    }
}
