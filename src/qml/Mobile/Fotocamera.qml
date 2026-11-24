// Fotocamera: anteprima a tutto schermo, scatto, cambio fotocamera (davanti/dietro)
// e miniatura dell'ultima foto (apre Foto). Le foto vanno in Immagini/Fotocamera.
// Se il telefono non ha una fotocamera supportata lo dice chiaramente.
import QtQuick
import QtMultimedia
import SolidUI

Rectangle {
    id: app
    color: "#000000"
    property int scelta: 0
    property string ultima: ""
    property bool lampo: false
    readonly property var fotocamere: dispositivi.videoInputs

    MediaDevices { id: dispositivi }
    CaptureSession {
        id: sessione
        camera: Camera {
            id: camera
            cameraDevice: app.fotocamere.length > 0 ? app.fotocamere[app.scelta % app.fotocamere.length] : dispositivi.defaultVideoInput
            active: app.visible && app.fotocamere.length > 0
        }
        imageCapture: ImageCapture {
            id: scatto
            onImageSaved: function (ident, percorso) { app.ultima = "file://" + percorso }
            onErrorOccurred: function (ident, errore, testo) { tel.avviso(I18n.t("Foto non salvata")) }
        }
        videoOutput: anteprima
    }
    VideoOutput {
        id: anteprima
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }
    Rectangle { anchors.fill: parent; color: "#ffffff"; opacity: app.lampo ? 0.8 : 0; Behavior on opacity { NumberAnimation { duration: 140 } } }
    Timer { id: fineLampo; interval: 120; onTriggered: app.lampo = false }

    // Nessuna fotocamera
    Column {
        visible: app.fotocamere.length === 0
        anchors.centerIn: parent; spacing: 12
        width: parent.width - 80
        Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: "camera-disabled-symbolic"; lato: 52 }
        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: I18n.t("Nessuna fotocamera disponibile"); color: "#ffffff"; font.family: Tema.font; font.pixelSize: tel.px(18); font.weight: Font.DemiBold }
        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: I18n.t("Su questo telefono la fotocamera non è ancora supportata dal sistema."); color: Qt.rgba(1, 1, 1, 0.7); font.family: Tema.font; font.pixelSize: tel.px(14) }
    }

    // Comandi: in basso, su una sfumatura scura. Il tasto di scatto prende il colore della veste
    // (bianco in Aurora, lime in Prisma); sopra la scelta Foto/Video.
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width; height: 220
        gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 0.35; color: Qt.rgba(0, 0, 0, 0.55) } GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.75) } }
        // Foto · Video
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 34; spacing: 6
            Repeater {
                model: [{ k: "foto", t: I18n.t("FOTO") }, { k: "video", t: I18n.t("VIDEO") }]
                Rectangle {
                    required property var modelData
                    readonly property bool attivo: modelData.k === "foto"
                    width: etMod.implicitWidth + 26; height: 30; radius: 15
                    color: attivo ? (tel.solido ? "#C6F432" : Qt.rgba(1, 1, 1, 0.22)) : "transparent"
                    Text { id: etMod; anchors.centerIn: parent; text: parent.modelData.t; color: parent.attivo && tel.solido ? "#141414" : (parent.attivo ? "#FFFFFF" : "#B3FFFFFF")
                           font.family: Tema.font; font.pixelSize: tel.px(12); font.weight: Font.Bold; font.letterSpacing: 1 }
                    MouseArea { anchors.fill: parent; onClicked: if (!parent.attivo) tel.avviso(I18n.t("Video: arriva con il telefono vero")) }
                }
            }
        }
        // Ultima foto
        Rectangle {
            x: 34; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 30
            width: 54; height: 54; radius: 16; color: "#222"; clip: true
            border.color: "#ffffff"; border.width: 2
            Image { anchors.fill: parent; anchors.margins: 2; source: app.ultima; fillMode: Image.PreserveAspectCrop; sourceSize.width: 120 }
            MouseArea { anchors.fill: parent; onClicked: tel.appInterna = "foto" }
        }
        // Scatta
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 30
            width: 82; height: 82; radius: 41; color: "transparent"
            border.color: "#ffffff"; border.width: 4
            opacity: app.fotocamere.length > 0 ? 1 : 0.4
            Rectangle { anchors.centerIn: parent; width: 66; height: 66; radius: 33; color: tel.solido ? "#C6F432" : "#ffffff"; scale: tocco.pressed ? 0.88 : 1
                        Behavior on scale { NumberAnimation { duration: 90 } } }
            MouseArea {
                id: tocco
                anchors.fill: parent; enabled: app.fotocamere.length > 0
                onClicked: { app.lampo = true; fineLampo.restart(); scatto.captureToFile(ponte.chiama0("nuovaFoto")) }
            }
        }
        // Cambia fotocamera
        Rectangle {
            anchors.right: parent.right; anchors.rightMargin: 34
            anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 30
            width: 54; height: 54; radius: 27; color: Qt.rgba(1, 1, 1, 0.2)
            border.width: 1; border.color: "#40FFFFFF"
            opacity: app.fotocamere.length > 1 ? 1 : 0.4
            Icona { anchors.centerIn: parent; nome: "linea-freccia-giro"; lato: 24; tema: "scuro" }
            MouseArea { anchors.fill: parent; enabled: app.fotocamere.length > 1; onClicked: app.scelta++ }
        }
    }
}
