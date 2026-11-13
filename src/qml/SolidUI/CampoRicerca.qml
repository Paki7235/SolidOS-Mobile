// Campo di ricerca con lente.
import QtQuick
import QtQuick.Controls

CampoTesto {
    leftPadding: 28
    placeholderText: I18n.t("Cerca")
    Canvas {
        x: 9
        anchors.verticalCenter: parent.verticalCenter
        width: 14; height: 14
        opacity: 0.8
        onPaint: {
            var c = getContext("2d"); c.reset()
            c.strokeStyle = Tema.testoSecondario; c.lineWidth = 1.6; c.lineCap = "round"
            c.beginPath(); c.arc(6, 6, 4.5, 0, Math.PI * 2); c.stroke()
            c.beginPath(); c.moveTo(9.5, 9.5); c.lineTo(13, 13); c.stroke()
        }
    }
    Keys.onEscapePressed: text = ""
}
