// Tondo di una persona: iniziali bianche su una sfumatura colorata (sempre la stessa per
// lo stesso nome), puntino blu se ci sono novità
import QtQuick
import SolidUI

Rectangle {
    id: av
    property string nome: ""
    property bool nuovo: false
    property int lato: 48
    width: lato; height: lato; radius: lato / 2
    readonly property var coppie: [["#4C7DFF", "#2F5FD0"], ["#8B5CF6", "#6D28D9"], ["#30A46C", "#14866D"], ["#F59E0B", "#EA580C"],
                                   ["#E5484D", "#BE123C"], ["#0EA5E9", "#2563EB"], ["#14B8A6", "#0F766E"], ["#EC4899", "#9333EA"]]
    readonly property int indice: { var h = 0; for (var i = 0; i < nome.length; i++) h = (h * 31 + nome.charCodeAt(i)) % 997; return h % coppie.length }
    gradient: Gradient {
        GradientStop { position: 0; color: av.coppie[av.indice][0] }
        GradientStop { position: 1; color: av.coppie[av.indice][1] }
    }
    readonly property string iniziali: {
        var p = nome.trim().split(" ").filter(function (x) { return x.length && /[A-Za-zÀ-ÿ0-9]/.test(x.charAt(0)) })
        if (!p.length) return "#"
        return (p[0].charAt(0) + (p.length > 1 ? p[1].charAt(0) : "")).toUpperCase()
    }
    Text { anchors.centerIn: parent; text: av.iniziali; color: "#ffffff"; font.family: Tema.font; font.weight: Font.DemiBold; font.pixelSize: Math.max(13, Math.round(av.lato * 0.36)) }
    Rectangle {
        visible: av.nuovo
        anchors.right: parent.right; anchors.top: parent.top; anchors.rightMargin: -1; anchors.topMargin: -1
        width: 13; height: 13; radius: 6.5; color: tel.accento
        border.width: 2; border.color: tel.pal.sfondo
    }
}
