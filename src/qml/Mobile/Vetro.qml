// Pannello di vetro sopra lo sfondo: prende la sfumatura dello sfondo nella zona che copre
// (come se fosse sfocato), con sopra una velatura grafite o bianca e un bordo sottile.
// Funziona anche senza scheda video (telefoni vecchi, telefono virtuale).
// «sfocato: false» = pannello pieno, per quando sotto non c'è lo sfondo (dentro le app).
// Nelle vesti Prisma e Prisma Notte il pannello è pieno: bianco, grafite o del colore «tinta».
import QtQuick

Rectangle {
    id: v
    property bool sfocato: true
    property color tinta: "transparent"      // colore pieno nelle vesti Prisma (widget colorati)
    readonly property bool pieno: tel.solido
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
    gradient: v.sfocato && !v.pieno ? sfumatura : null
    color: v.pieno ? (v.tinta.a > 0 ? v.tinta : tel.pal.superficie) : (v.sfocato ? "transparent" : tel.pal.superficie)
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
        visible: !v.pieno || (!tel.chiaro && v.tinta.a === 0)
        color: v.sfocato && !v.pieno ? tel.pal.vetro : "transparent"
        border.width: 1
        border.color: v.sfocato ? tel.pal.vetroBordo : tel.pal.bordo
    }
}
