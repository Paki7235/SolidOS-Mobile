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

    // Comandi
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width; height: 170
        color: Qt.rgba(0, 0, 0, 0.45)
        // Ultima foto
        Rectangle {
            x: 34; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -10
            width: 52; height: 52; radius: 10; color: "#222"; clip: true
            border.color: "#ffffff"; border.width: 2
            Image { anchors.fill: parent; anchors.margins: 2; source: app.ultima; fillMode: Image.PreserveAspectCrop; sourceSize.width: 120 }
            MouseArea { anchors.fill: parent; onClicked: tel.appInterna = "foto" }
        }
        // Scatta
        Rectangle {
            anchors.centerIn: parent; anchors.verticalCenterOffset: -10
            width: 78; height: 78; radius: 39; color: "transparent"
            border.color: "#ffffff"; border.width: 4
            opacity: app.fotocamere.length > 0 ? 1 : 0.4
            Rectangle { anchors.centerIn: parent; width: 64; height: 64; radius: 32; color: "#ffffff"; scale: tocco.pressed ? 0.9 : 1 }
            MouseArea {
                id: tocco
                anchors.fill: parent; enabled: app.fotocamere.length > 0
                onClicked: { app.lampo = true; fineLampo.restart(); scatto.captureToFile(ponte.chiama0("nuovaFoto")) }
            }
        }
        // Cambia fotocamera
        Rectangle {
            anchors.right: parent.right; anchors.rightMargin: 34
            anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -10
            width: 52; height: 52; radius: 26; color: Qt.rgba(1, 1, 1, 0.2)
            visible: app.fotocamere.length > 1
            Text { anchors.centerIn: parent; text: "⟲"; color: "#ffffff"; font.pixelSize: 26 }
            MouseArea { anchors.fill: parent; onClicked: app.scelta++ }
        }
    }
}
