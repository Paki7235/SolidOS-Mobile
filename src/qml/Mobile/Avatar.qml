// Tondo di una persona: iniziali su un colore (sempre lo stesso per lo stesso nome), puntino
// se ci sono novità. Aurora: sfumature vive. Prisma: colori pieni (iniziali scure sul lime e sul giallo).
import QtQuick
import SolidUI

Rectangle {
    id: av
    property string nome: ""
    property bool nuovo: false
    property int lato: 48
    width: lato; height: lato; radius: lato / 2
    readonly property var coppie: tel.solido
        ? [["#FF6B4A", "#FF6B4A"], ["#8B6CFF", "#8B6CFF"], ["#59C3FF", "#59C3FF"], ["#C6F432", "#C6F432"],
           ["#FFB443", "#FFB443"], ["#3EE0B0", "#3EE0B0"], ["#FF74A6", "#FF74A6"], ["#FFD84A", "#FFD84A"]]
        : [["#66A6FF", "#3443F5"], ["#B994FF", "#6232F5"], ["#4BE38E", "#0E9B57"], ["#FFC46B", "#F27A1A"],
           ["#FF8172", "#E5304B"], ["#5EE6FF", "#0A8FC2"], ["#33E7BA", "#0C9A82"], ["#FF74A6", "#DE1B67"]]
    readonly property bool scuro: tel.solido && [3, 4, 5, 7].indexOf(indice) >= 0   // iniziali scure sui colori chiari
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
    Text { anchors.centerIn: parent; text: av.iniziali; color: av.scuro ? "#141414" : "#ffffff"; font.family: Tema.font; font.weight: tel.solido ? Font.ExtraBold : Font.DemiBold; font.pixelSize: Math.max(13, Math.round(av.lato * 0.36)) }
    Rectangle {
        visible: av.nuovo
        anchors.right: parent.right; anchors.top: parent.top; anchors.rightMargin: -1; anchors.topMargin: -1
        width: 13; height: 13; radius: 6.5; color: tel.accento
        border.width: 2; border.color: tel.pal.sfondo
    }
}
