// La videochiamata: pagina chiamata-video.html nel motore web, con microfono, videocamera e schermo
// concessi solo a questa pagina locale dell'app. Gli eventi arrivano dalla pagina con QWebChannel.
import QtQuick
import QtWebEngine
import QtWebChannel

WebEngineView {
    id: vista
    signal evento(string nome, var dati)
    signal pronta()
    url: ponte.chiama("videochiamate", ["pagina", []])
    backgroundColor: "#0B0C10"
    settings.javascriptEnabled: true
    settings.localContentCanAccessRemoteUrls: true
    settings.playbackRequiresUserGesture: false
    settings.screenCaptureEnabled: true
    settings.pluginsEnabled: false
    webChannel: WebChannel { registeredObjects: [oggetto] }
    QtObject {
        id: oggetto
        WebChannel.id: "solidos"
        function evento(nome, json) { vista.evento(nome, JSON.parse(json)) }
        function pronta() { vista.pronta() }
    }
    // la pagina è dell'app: microfono, videocamera e schermo si concedono (nessun sito esterno si apre qui)
    Connections {
        target: vista
        ignoreUnknownSignals: true
        function onPermissionRequested(permesso) { permesso.grant() }
        function onFeaturePermissionRequested(origine, cosa) { vista.grantFeaturePermission(origine, cosa, true) }
        function onDesktopMediaRequested(richiesta) { richiesta.selectScreen(richiesta.screensModel.index(0, 0)) }
        function onNavigationRequested(r) {
            if (!r.url.toString().startsWith("file:")) { if (r.reject) r.reject(); else r.action = WebEngineNavigationRequest.IgnoreRequest }
        }
    }
    function avvia(conf, opzioni, traduzioni) { runJavaScript("avvia(" + JSON.stringify(conf) + "," + JSON.stringify(opzioni) + "," + JSON.stringify(traduzioni) + ")") }
    function token(t) { runJavaScript("aggiornaToken(" + JSON.stringify(t) + ")") }
    function chiudi() { runJavaScript("chiudiDaFuori()") }
}
