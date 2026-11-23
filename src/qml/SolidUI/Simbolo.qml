// Simbolo a linea di SolidOS (gli stessi sul PC e sul telefono), del colore che serve:
// Simbolo { nome: "posate"; colore: "#FFFFFF"; lato: 18 }  (disegni in src/dati/icone/linea)
import QtQuick
import QtQuick.Layouts

Image {
    property string nome: ""
    property color colore: "#808080"
    property int lato: 18
    width: lato
    height: lato
    // nelle righe e colonne (RowLayout…) la grandezza è quella chiesta, non quella dell'immagine
    Layout.preferredWidth: lato
    Layout.preferredHeight: lato
    Layout.maximumWidth: lato
    Layout.maximumHeight: lato
    sourceSize.width: lato * 2
    sourceSize.height: lato * 2
    readonly property string esadecimale: {
        var c = colore
        function due(v) { var h = Math.round(v * 255).toString(16); return h.length < 2 ? "0" + h : h }
        return due(c.r) + due(c.g) + due(c.b)
    }
    source: nome ? "image://icona/linea-" + nome + "?tema=colore-" + esadecimale : ""
    fillMode: Image.PreserveAspectFit
    smooth: true
}
