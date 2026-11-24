// Fotocamera: anteprima a tutto schermo con tre modalità (Video, Foto, Quadrato), scelte con i
// tasti o scorrendo di lato. In alto: flash (automatico, acceso, spento; in video la luce
// continua), autoscatto (3 o 10 secondi), griglia e luminosità. Tocca per mettere a fuoco e
// trascina il sole per schiarire o scurire; pizzica o usa 0,5× · 1× · 2× · 5× per lo zoom.
// Video con il tempo che scorre, pausa e stop. Foto in Immagini/Fotocamera (il Quadrato si
// ritaglia al centro), video nella stessa cartella. Doppio tocco o il tasto in basso a destra
// per passare tra davanti e dietro (anteprima a specchio davanti).
// Se il telefono non ha una fotocamera supportata lo dice chiaramente.
import QtQuick
import QtMultimedia
import SolidUI

Rectangle {
    id: app
    color: "#000000"

    // ── Stato ────────────────────────────────────────────────────────────
    property int scelta: 0
    property string ultima: ""            // ultima foto (miniatura)
    property bool lampo: false
    property string modo: "foto"          // video | foto | quadrato
    property string flash: "auto"         // auto | acceso | spento (in video: acceso | spento)
    property int autoscatto: 0            // 0, 3, 10 secondi
    property int contoAllaRovescia: 0
    property bool griglia: false
    property real luce: 0                 // compensazione dell'esposizione, da -2 a +2
    property point fuoco: Qt.point(-1, -1)
    // Prove sul PC (--schermata=fotocamera-prova / fotocamera-video): una scena finta
    readonly property string avvio: ponte.chiama0("avvio").schermata || ""
    readonly property bool prova: avvio === "fotocamera-prova" || avvio === "fotocamera-video"
    readonly property var fotocamere: dispositivi.videoInputs
    readonly property bool pronta: fotocamere.length > 0 || prova
    readonly property bool davanti: fotocamere.length > 0 && camera.cameraDevice.position === CameraDevice.FrontFace
    readonly property bool registra: registratore.recorderState !== MediaRecorder.StoppedState || (prova && avvio === "fotocamera-video")
    readonly property bool inPausa: registratore.recorderState === MediaRecorder.PausedState
    readonly property real zoomMin: Math.max(0.5, camera.minimumZoomFactor || 1)
    readonly property real zoomMax: Math.max(1, Math.min(10, camera.maximumZoomFactor || 1))
    readonly property color colore: tel.solido ? "#C6F432" : "#FFFFFF"     // colore della veste
    Component.onCompleted: if (avvio === "fotocamera-video") modo = "video"

    function scatta() {
        if (!pronta) return
        if (modo === "video") { if (registra) fermaVideo(); else avviaVideo(); return }
        if (contatore.running) { contatore.stop(); contoAllaRovescia = 0; return }   // ritocco: annulla l'autoscatto
        if (autoscatto > 0) { contoAllaRovescia = autoscatto; contatore.start(); return }
        foto()
    }
    function foto() {
        lampo = true; fineLampo.restart()
        if (prova) return
        scatto.captureToFile(ponte.chiama0("nuovaFoto"))
    }
    function avviaVideo() {
        if (prova) return
        registratore.outputLocation = "file://" + ponte.chiama0("nuovoVideo")
        if (flash === "acceso") camera.torchMode = Camera.TorchOn
        registratore.record()
    }
    function fermaVideo() { registratore.stop(); camera.torchMode = Camera.TorchOff }
    function cambiaModo(m) {
        if (registra || m === modo) return
        contatore.stop(); contoAllaRovescia = 0
        if (m === "video" && flash === "auto") flash = "spento"
        modo = m
    }
    function cambiaFotocamera() {
        if (registra || fotocamere.length < 2) return
        scelta++; luce = 0; fuoco = Qt.point(-1, -1)
    }
    function zoom(z) { if (fotocamere.length > 0) camera.zoomFactor = Math.max(zoomMin, Math.min(zoomMax, z)) }
    function testoTempo(ms) { var s = Math.floor(ms / 1000); return ("0" + Math.floor(s / 60)).slice(-2) + ":" + ("0" + s % 60).slice(-2) }

    MediaDevices { id: dispositivi }
    CaptureSession {
        id: sessione
        camera: Camera {
            id: camera
            cameraDevice: app.fotocamere.length > 0 ? app.fotocamere[app.scelta % app.fotocamere.length] : dispositivi.defaultVideoInput
            active: app.visible && app.fotocamere.length > 0
            flashMode: app.modo === "video" ? Camera.FlashOff : (app.flash === "acceso" ? Camera.FlashOn : (app.flash === "spento" ? Camera.FlashOff : Camera.FlashAuto))
            exposureCompensation: app.luce
            focusMode: Camera.FocusModeAuto
            onCameraDeviceChanged: zoomFactor = 1
        }
        imageCapture: ImageCapture {
            id: scatto
            onImageSaved: function (ident, percorso) {
                if (app.modo === "quadrato") ponte.chiama("ritagliaQuadrato", [percorso])
                app.ultima = "file://" + percorso + "?" + Date.now()     // si ricarica anche dopo il ritaglio
            }
            onErrorOccurred: function (ident, errore, testo) { tel.avviso(I18n.t("Foto non salvata")) }
        }
        recorder: MediaRecorder {
            id: registratore
            onRecorderStateChanged: if (recorderState === MediaRecorder.StoppedState && String(actualLocation) !== "") tel.avviso(I18n.t("Video salvato in Foto"))
            onErrorOccurred: function (errore, testo) { camera.torchMode = Camera.TorchOff; tel.avviso(I18n.t("Video non registrato") + (testo ? ": " + testo : "")) }
        }
        audioInput: AudioInput {}
        videoOutput: anteprima
    }
    // Uscendo dall'app il video in corso si salva e l'autoscatto si ferma
    onVisibleChanged: if (!visible) { contatore.stop(); contoAllaRovescia = 0; if (registratore.recorderState !== MediaRecorder.StoppedState) fermaVideo() }

    // ── Anteprima ────────────────────────────────────────────────────────
    Item {
        id: inquadratura
        anchors.fill: parent
        VideoOutput {
            id: anteprima
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectCrop
            transform: Scale { origin.x: anteprima.width / 2; xScale: app.davanti ? -1 : 1 }   // a specchio davanti
        }
        // Scena finta per le prove sul PC
        Rectangle {
            anchors.fill: parent; visible: app.prova
            gradient: Gradient { GradientStop { position: 0; color: "#6FA8DC" } GradientStop { position: 0.55; color: "#F4C38A" } GradientStop { position: 0.56; color: "#3E7B4F" } GradientStop { position: 1; color: "#1F3D2A" } }
            Rectangle { x: parent.width * 0.62; y: parent.height * 0.18; width: 90; height: 90; radius: 45; color: "#FFF4C9" }
        }
        // Formato quadrato: il resto si scurisce
        Rectangle { visible: app.modo === "quadrato"; width: parent.width; height: (parent.height - parent.width) / 2; color: "#B3000000" }
        Rectangle { visible: app.modo === "quadrato"; width: parent.width; y: (parent.height + parent.width) / 2; height: (parent.height - parent.width) / 2; color: "#B3000000" }
        // Griglia dei terzi
        Item {
            visible: app.griglia
            readonly property real alto: app.modo === "quadrato" ? parent.width : parent.height
            y: (parent.height - alto) / 2; width: parent.width; height: alto
            Repeater { model: 2; Rectangle { required property int index; x: parent.width * (index + 1) / 3; width: 1; height: parent.height; color: "#80FFFFFF" } }
            Repeater { model: 2; Rectangle { required property int index; y: parent.height * (index + 1) / 3; height: 1; width: parent.width; color: "#80FFFFFF" } }
        }
        // Tocca: messa a fuoco lì; doppio tocco: davanti/dietro
        TapHandler {
            onTapped: function (ev) {
                if (!app.pronta) return
                app.fuoco = Qt.point(ev.position.x, ev.position.y)
                if (app.fotocamere.length > 0 && (camera.supportedFeatures & Camera.CustomFocusPoint)) {
                    var px = ev.position.x / inquadratura.width
                    camera.customFocusPoint = Qt.point(app.davanti ? 1 - px : px, ev.position.y / inquadratura.height)
                }
                nascondiFuoco.restart()
            }
            onDoubleTapped: app.cambiaFotocamera()
        }
        // Pizzica: zoom
        PinchHandler {
            target: null
            property real partenza: 1
            onActiveChanged: if (active) partenza = camera.zoomFactor
            onActiveScaleChanged: if (active) app.zoom(partenza * activeScale)
        }
        // Scorri di lato: cambia modalità
        DragHandler {
            target: null; yAxis.enabled: false
            onActiveChanged: if (!active) {
                var m = ["video", "foto", "quadrato"], i = m.indexOf(app.modo)
                if (translation.x < -60 && i < 2) app.cambiaModo(m[i + 1])
                else if (translation.x > 60 && i > 0) app.cambiaModo(m[i - 1])
            }
        }
    }

    // Quadrato della messa a fuoco, con il sole della luminosità da trascinare su e giù
    Item {
        id: quadroFuoco
        visible: app.fuoco.x >= 0
        x: Math.min(app.width - 130, Math.max(10, app.fuoco.x - 40)); y: Math.min(app.height - 320, Math.max(120, app.fuoco.y - 40))
        width: 80; height: 80
        Rectangle { anchors.fill: parent; color: "transparent"; border.width: 1.5; border.color: app.colore; radius: 6 }
        Item {
            x: parent.width + 8; y: -20; width: 34; height: 120
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 1.5; height: parent.height; color: "#80FFFFFF" }
            Icona { anchors.horizontalCenter: parent.horizontalCenter; y: (1 - (app.luce + 2) / 4) * (parent.height - 22); nome: "linea-sole"; lato: 22; colore: app.colore }
            DragHandler {
                target: null; xAxis.enabled: false
                property real inizio: 0
                onActiveChanged: { if (active) { inizio = app.luce; nascondiFuoco.stop() } else nascondiFuoco.restart() }
                onTranslationChanged: if (active) app.luce = Math.round(Math.max(-2, Math.min(2, inizio - translation.y / 40)) * 10) / 10
            }
        }
    }
    Timer { id: nascondiFuoco; interval: 3500; onTriggered: app.fuoco = Qt.point(-1, -1) }

    // Lampo dello scatto
    Rectangle { anchors.fill: parent; color: "#ffffff"; opacity: app.lampo ? 0.8 : 0; Behavior on opacity { NumberAnimation { duration: 140 } } }
    Timer { id: fineLampo; interval: 120; onTriggered: app.lampo = false }

    // Autoscatto: il numero grande al centro
    Timer {
        id: contatore; interval: 1000; repeat: true
        onTriggered: { app.contoAllaRovescia--; if (app.contoAllaRovescia <= 0) { stop(); app.foto() } }
    }
    Text {
        visible: app.contoAllaRovescia > 0
        anchors.centerIn: parent
        text: app.contoAllaRovescia; color: "#FFFFFF"; style: Text.Raised; styleColor: "#66000000"
        font.family: Tema.font; font.pixelSize: 140; font.weight: Font.Black
    }

    // Nessuna fotocamera
    Column {
        visible: !app.pronta
        anchors.centerIn: parent; spacing: 12
        width: parent.width - 80
        Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: "camera-disabled-symbolic"; lato: 52; tema: "scuro" }
        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: I18n.t("Nessuna fotocamera disponibile"); color: "#ffffff"; font.family: Tema.font; font.pixelSize: tel.px(18); font.weight: Font.DemiBold }
        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: I18n.t("Su questo telefono la fotocamera non è ancora supportata dal sistema."); color: Qt.rgba(1, 1, 1, 0.7); font.family: Tema.font; font.pixelSize: tel.px(14) }
    }

    // ── In alto: flash, autoscatto, griglia, luminosità (o il tempo del video) ──
    Rectangle {
        width: parent.width; height: 110
        gradient: Gradient { GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.6) } GradientStop { position: 1; color: "transparent" } }
        Row {
            visible: !app.registra && app.pronta
            anchors.horizontalCenter: parent.horizontalCenter; y: 52; spacing: 12
            Repeater {
                model: [
                    { k: "flash", i: app.flash === "spento" ? "linea-fulmine-spento" : "linea-fulmine", on: app.flash !== "spento",
                      t: app.modo === "video" ? "" : (app.flash === "auto" ? "Auto" : "") },
                    { k: "timer", i: "linea-cronometro", t: app.autoscatto ? app.autoscatto + "s" : "", on: app.autoscatto > 0 && app.modo !== "video" },
                    { k: "griglia", i: "linea-griglia", t: "", on: app.griglia },
                    { k: "luce", i: "linea-sole", t: app.luce !== 0 ? (app.luce > 0 ? "+" : "") + app.luce.toFixed(1).replace(".", ",") : "", on: app.luce !== 0 }]
                Rectangle {
                    id: tc
                    required property var modelData
                    visible: !(modelData.k === "timer" && app.modo === "video")
                    width: Math.max(42, rigaTc.implicitWidth + 24); height: 42; radius: 21
                    color: modelData.on ? app.colore : Qt.rgba(1, 1, 1, 0.16)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Row {
                        id: rigaTc; anchors.centerIn: parent; spacing: 4
                        Icona { anchors.verticalCenter: parent.verticalCenter; nome: tc.modelData.i; lato: 19; colore: tc.modelData.on ? "#141414" : "#FFFFFF" }
                        Text { visible: tc.modelData.t !== ""; anchors.verticalCenter: parent.verticalCenter; text: tc.modelData.t; color: tc.modelData.on ? "#141414" : "#FFFFFF"; font.family: Tema.font; font.pixelSize: 13; font.weight: Font.Bold }
                    }
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -4
                        onClicked: {
                            var k = tc.modelData.k
                            if (k === "flash") app.flash = app.modo === "video" ? (app.flash === "acceso" ? "spento" : "acceso") : ({ auto: "acceso", acceso: "spento", spento: "auto" })[app.flash]
                            else if (k === "timer") app.autoscatto = ({ 0: 3, 3: 10, 10: 0 })[app.autoscatto]
                            else if (k === "griglia") app.griglia = !app.griglia
                            else { app.luce = 0; tel.avviso(I18n.t("Tocca l'immagine e trascina il sole per la luminosità")) }
                        }
                    }
                }
            }
        }
        // Video in corso: il tempo con il pallino; la luce si accende e spegne anche registrando
        Row {
            visible: app.registra
            anchors.horizontalCenter: parent.horizontalCenter; y: 54; spacing: 10
            Rectangle {
                width: rigaRec.implicitWidth + 28; height: 38; radius: 19; color: "#E5484D"
                Row {
                    id: rigaRec; anchors.centerIn: parent; spacing: 8
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 10; height: 10; radius: 5; color: "#FFFFFF"
                                SequentialAnimation on opacity { running: app.registra && !app.inPausa && app.visible; loops: Animation.Infinite
                                                                 NumberAnimation { to: 0.2; duration: 500 } NumberAnimation { to: 1; duration: 500 } } }
                    Text { text: app.testoTempo(app.prova ? 42000 : registratore.duration) + (app.inPausa ? "  " + I18n.t("in pausa") : ""); color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: 16; font.weight: Font.Bold }
                }
            }
            Rectangle {
                width: 38; height: 38; radius: 19
                color: app.flash === "acceso" ? app.colore : Qt.rgba(1, 1, 1, 0.16)
                Icona { anchors.centerIn: parent; nome: app.flash === "acceso" ? "linea-fulmine" : "linea-fulmine-spento"; lato: 18; colore: app.flash === "acceso" ? "#141414" : "#FFFFFF" }
                MouseArea { anchors.fill: parent; anchors.margins: -4
                            onClicked: { app.flash = app.flash === "acceso" ? "spento" : "acceso"; if (!app.prova) camera.torchMode = app.flash === "acceso" ? Camera.TorchOn : Camera.TorchOff } }
            }
        }
    }

    // ── In basso: zoom, modalità, scatto ─────────────────────────────────
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width; height: 250
        gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 0.3; color: Qt.rgba(0, 0, 0, 0.55) } GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.8) } }

        // Zoom: 0,5× · 1× · 2× · 5× (solo quelli che la fotocamera può fare)
        Row {
            anchors.horizontalCenter: parent.horizontalCenter; y: 6; spacing: 8
            visible: app.pronta
            Repeater {
                model: [0.5, 1, 2, 5].filter(function (z) { return app.prova ? z <= 2 : (z >= app.zoomMin - 0.01 && z <= app.zoomMax + 0.01) })
                Rectangle {
                    id: zt
                    required property real modelData
                    readonly property real attuale: app.prova ? 1 : camera.zoomFactor
                    readonly property bool attivo: Math.abs(attuale - modelData) < modelData * 0.25
                    width: attivo ? 44 : 36; height: width; radius: width / 2
                    color: "#66000000"; border.width: 1; border.color: "#40FFFFFF"
                    Behavior on width { NumberAnimation { duration: 120 } }
                    Text { anchors.centerIn: parent; text: (zt.attivo ? zt.attuale.toFixed(1).replace(".0", "") : String(zt.modelData)).replace(".", ",") + "×"
                           color: zt.attivo ? app.colore : "#FFFFFF"; font.family: Tema.font; font.pixelSize: zt.attivo ? 13 : 12; font.weight: Font.Bold }
                    MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: app.zoom(zt.modelData) }
                }
            }
        }
        // Video · Foto · Quadrato
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 64; spacing: 4
            visible: !app.registra
            Repeater {
                model: [{ k: "video", t: I18n.t("VIDEO") }, { k: "foto", t: I18n.t("FOTO") }, { k: "quadrato", t: I18n.t("QUADRATO") }]
                Rectangle {
                    id: mt
                    required property var modelData
                    readonly property bool attivo: app.modo === modelData.k
                    width: etMod.implicitWidth + 26; height: 32; radius: 16
                    color: attivo ? (tel.solido ? "#C6F432" : Qt.rgba(1, 1, 1, 0.22)) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text { id: etMod; anchors.centerIn: parent; text: mt.modelData.t; color: mt.attivo && tel.solido ? "#141414" : (mt.attivo ? "#FFD84A" : "#B3FFFFFF")
                           font.family: Tema.font; font.pixelSize: tel.px(12); font.weight: Font.Bold; font.letterSpacing: 1 }
                    MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: app.cambiaModo(mt.modelData.k) }
                }
            }
        }
        // Ultima foto (apre Foto) oppure, registrando, la pausa
        Rectangle {
            x: 34; y: 130
            width: 54; height: 54; radius: app.registra ? 27 : 16; clip: true
            color: app.registra ? Qt.rgba(1, 1, 1, 0.2) : "#222"
            border.color: app.registra ? "#40FFFFFF" : "#ffffff"; border.width: app.registra ? 1 : 2
            Image { visible: !app.registra; anchors.fill: parent; anchors.margins: 2; source: app.ultima; fillMode: Image.PreserveAspectCrop; sourceSize.width: 120; cache: false }
            Icona { visible: app.registra; anchors.centerIn: parent; nome: app.inPausa ? "media-playback-start-symbolic" : "media-playback-pause-symbolic"; lato: 22; tema: "scuro" }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (!app.registra) { tel.appInterna = "foto"; return }
                    if (app.prova) return
                    if (app.inPausa) registratore.record(); else registratore.pause()
                }
            }
        }
        // Scatta / registra
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 117
            width: 82; height: 82; radius: 41; color: "transparent"
            border.color: "#ffffff"; border.width: 4
            opacity: app.pronta ? 1 : 0.4
            Rectangle {
                anchors.centerIn: parent
                // foto: tondo nel colore della veste; video: tondo rosso, quadrato rosso mentre registra
                width: app.registra ? 30 : 66; height: width; radius: app.registra ? 8 : width / 2
                color: app.modo === "video" ? "#E5484D" : app.colore
                scale: tocco.pressed ? 0.88 : 1
                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
                Behavior on radius { NumberAnimation { duration: 160 } }
                Behavior on scale { NumberAnimation { duration: 90 } }
            }
            MouseArea { id: tocco; anchors.fill: parent; enabled: app.pronta; onClicked: app.scatta() }
        }
        // Davanti / dietro
        Rectangle {
            anchors.right: parent.right; anchors.rightMargin: 34
            y: 130
            width: 54; height: 54; radius: 27; color: Qt.rgba(1, 1, 1, 0.2)
            border.width: 1; border.color: "#40FFFFFF"
            opacity: app.fotocamere.length > 1 && !app.registra ? 1 : 0.4
            Icona { anchors.centerIn: parent; nome: "linea-freccia-giro"; lato: 24; tema: "scuro" }
            MouseArea { anchors.fill: parent; onClicked: app.cambiaFotocamera() }
        }
    }
}
