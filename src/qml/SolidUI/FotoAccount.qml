// Foto dell'account in un cerchio, come sul Mac; senza foto, le iniziali su fondo grigio.
// account: { foto: "file:///…", iniziali: "MR" } (vedi nucleo/account.py)
import QtQuick

Item {
    id: radice
    property var account: ({})
    property int lato: 84
    implicitWidth: lato
    implicitHeight: lato
    width: lato
    height: lato

    readonly property string foto: account && account.foto ? account.foto : ""
    // Cambia indirizzo a ogni nuova foto (stesso file ~/.face): si ridisegna davvero
    property int versione: 0
    onFotoChanged: { versione++; cerchio.carica() }
    onAccountChanged: { versione++; cerchio.carica() }

    Canvas {
        id: cerchio
        anchors.fill: parent
        antialiasing: true
        property string caricata: ""
        function carica() {
            if (caricata) unloadImage(caricata)
            caricata = radice.foto ? radice.foto + "?v=" + radice.versione : ""
            if (caricata) loadImage(caricata)
            requestPaint()
        }
        onImageLoaded: requestPaint()
        onPaint: {
            var g = getContext("2d")
            g.reset()
            g.save()
            g.beginPath()
            g.arc(width / 2, height / 2, width / 2, 0, Math.PI * 2, false)
            g.closePath()
            g.clip()
            if (caricata && isImageLoaded(caricata)) {
                g.drawImage(caricata, 0, 0, width, height)
            } else {
                var sf = g.createLinearGradient(0, 0, 0, height)
                sf.addColorStop(0, "#A3A8B4")
                sf.addColorStop(1, "#7C818D")
                g.fillStyle = sf
                g.fillRect(0, 0, width, height)
            }
            g.restore()
        }
        Component.onCompleted: carica()
    }
    Text {
        anchors.centerIn: parent
        visible: !radice.foto
        text: radice.account && radice.account.iniziali ? radice.account.iniziali : "?"
        color: "#FFFFFF"
        font.family: Tema.font
        font.pixelSize: Math.round(radice.lato * 0.4)
        font.weight: Font.DemiBold
    }
}
