// Icona del tema di sistema: Icona { nome: "network-wireless"; lato: 24 }
import QtQuick
import QtQuick.Layouts

Image {
    property string nome: ""
    property int lato: 24
    width: lato
    height: lato
    // Nei layout (RowLayout…) senza queste righe l'icona prenderebbe la grandezza
    // dell'immagine caricata (il doppio) e sborderebbe. implicitWidth di Image è di sola lettura.
    Layout.preferredWidth: lato
    Layout.preferredHeight: lato
    sourceSize.width: lato * 2
    sourceSize.height: lato * 2
    // Sul telefono le icone seguono il tema chiaro o scuro dell'interfaccia
    // «tema» forza le icone: "scuro" = icone chiare (su colori pieni), "chiaro" = icone scure
    property string tema: ""
    // «colore»: l'icona a linea in un colore preciso (es. tel.accento)
    property color colore: "transparent"
    readonly property string temaIcone: colore.a > 0 ? "colore-" + colore.toString().slice(-6) : tema !== "" ? tema
        : (typeof tel !== "undefined" && tel.chiaro !== undefined ? (tel.chiaro ? "chiaro" : "scuro") : "")
    source: nome ? "image://icona/" + nome + (temaIcone ? "?tema=" + temaIcone : "") : ""
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    smooth: true
}
