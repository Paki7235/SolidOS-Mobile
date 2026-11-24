// Pagina web dell'app Web (file a parte: se il motore web non c'è, Web lo dice).
import QtQuick
import QtWebEngine

WebEngineView {
    id: v
    profile: WebEngineProfile { storageName: "solidos-web"; offTheRecord: false }
    settings.fullScreenSupportEnabled: true
    onFullScreenRequested: function (r) { r.accept() }
}
