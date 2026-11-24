// Corpo di un messaggio di Mail (pagina HTML preparata dal backend, link aperti fuori).
// File a parte: se il motore web non c'è, Mail mostra il testo semplice.
import QtQuick
import QtWebEngine

WebEngineView {
    property string html: ""
    signal link(string url)
    onHtmlChanged: loadHtml(html)
    onNavigationRequested: function (r) {
        if (r.navigationType === WebEngineNavigationRequest.LinkClickedNavigation) { r.reject(); link(r.url.toString()) }
    }
}
