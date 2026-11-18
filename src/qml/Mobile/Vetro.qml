// Pannello di vetro sopra lo sfondo: prende la sfumatura dello sfondo nella zona che copre
// (come se fosse sfocato), con sopra una velatura grafite o bianca e un bordo sottile.
// Funziona anche senza scheda video (telefoni vecchi, telefono virtuale).
// «sfocato: false» = pannello pieno, per quando sotto non c'è lo sfondo (dentro le app).
import QtQuick

Rectangle {
    id: v
    property bool sfocato: true
    radius: tel.r3
    // Posizione sullo schermo (frazioni dell'altezza), aggiornata quando il pannello compare
    property real alto: 0
    property real basso: 1
    function misura() {
        if (typeof tel === "undefined" || !tel.contentItem || !visible) return
        var p = mapToItem(tel.contentItem, 0, 0)
        alto = p.y / Math.max(1, tel.height)
        basso = (p.y + height) / Math.max(1, tel.height)
    }
    Component.onCompleted: misura()
    onVisibleChanged: { misura(); ritardo.restart() }
    onHeightChanged: misura()
    onYChanged: misura()
    Timer { id: ritardo; interval: 450; onTriggered: v.misura() }
    gradient: v.sfocato ? sfumatura : null
    color: v.sfocato ? "transparent" : tel.pal.superficie
    Gradient {
        id: sfumatura
        GradientStop { position: 0.0; color: tel.coloreSfondo(v.alto) }
        GradientStop { position: 0.5; color: tel.coloreSfondo((v.alto + v.basso) / 2) }
        GradientStop { position: 1.0; color: tel.coloreSfondo(v.basso) }
    }
    // Velatura e bordo
    Rectangle {
        anchors.fill: parent
        radius: v.radius
        color: v.sfocato ? tel.pal.vetro : "transparent"
        border.width: 1
        border.color: v.sfocato ? tel.pal.vetroBordo : tel.pal.bordo
    }
}
