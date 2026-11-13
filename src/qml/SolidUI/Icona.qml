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
    source: nome ? "image://icona/" + nome : ""
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    smooth: true
}
