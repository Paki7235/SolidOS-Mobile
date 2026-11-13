// Interruttore acceso/spento (verde quando acceso).
import QtQuick
import QtQuick.Controls

Switch {
    id: interruttore
    hoverEnabled: true
    padding: 0
    indicator: Rectangle {
        implicitWidth: 38
        implicitHeight: 22
        x: interruttore.leftPadding
        y: parent.height / 2 - height / 2
        radius: 11
        color: interruttore.checked ? "#34C759" : (Tema.chiaro ? "#E5E5EA" : "#48484F")
        opacity: interruttore.enabled ? 1 : 0.45
        Behavior on color { enabled: Tema.animazioni; ColorAnimation { duration: 140 } }
        Rectangle {
            x: interruttore.checked ? parent.width - width - 2 : 2
            y: 2
            width: 18
            height: 18
            radius: 9
            color: "#FFFFFF"
            border.color: "#1F000000"
            border.width: 0.5
            Behavior on x { enabled: Tema.animazioni; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
    }
    contentItem: Text {
        text: interruttore.text
        font.family: Tema.font
        font.pixelSize: 13
        color: Tema.testo
        verticalAlignment: Text.AlignVCenter
        leftPadding: interruttore.text ? interruttore.indicator.width + 10 : interruttore.indicator.width
    }
}
