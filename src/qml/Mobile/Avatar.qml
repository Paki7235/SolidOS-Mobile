// Tondo di una persona: iniziali in Space Mono su grigio, puntino rosso se ci sono novità
import QtQuick
import SolidUI

Rectangle {
    id: av
    property string nome: ""
    property bool nuovo: false
    property int lato: 50
    width: lato; height: lato; radius: lato / 2
    color: tel.pal.superficie2
    readonly property string iniziali: {
        var p = nome.trim().split(" ").filter(function (x) { return x.length && /[A-Za-zÀ-ÿ0-9]/.test(x.charAt(0)) })
        if (!p.length) return "#"
        return (p[0].charAt(0) + (p.length > 1 ? p[1].charAt(0) : "")).toUpperCase()
    }
    Text { anchors.centerIn: parent; text: av.iniziali; color: tel.pal.testo; font.family: tel.fontMono; font.bold: true; font.pixelSize: Math.max(13, Math.round(av.lato * 0.36)) }
    Rectangle {
        visible: av.nuovo
        anchors.right: parent.right; anchors.top: parent.top; anchors.rightMargin: -1; anchors.topMargin: -1
        width: 13; height: 13; radius: 6.5; color: tel.rosso
        border.width: 2; border.color: tel.pal.sfondo
    }
}
