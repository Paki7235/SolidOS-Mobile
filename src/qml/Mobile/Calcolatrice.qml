// Calcolatrice: tasti grandi, risultato mentre scrivi; il calcolo lo fa il backend
// in modo sicuro (niente eval). Tocca il risultato per riusarlo.
import QtQuick
import SolidUI

Rectangle {
    id: app
    color: tel.pal.sfondo
    property string espressione: ""
    property string risultato: ""
    property bool errore: false

    function aggiorna() {
        if (!espressione) { risultato = ""; errore = false; return }
        var r = ponte.chiama("calcola", [espressione])
        errore = !r.ok
        risultato = r.ok ? r.valore : (/[+−×÷^(]$/.test(espressione) ? "" : r.valore)
    }
    function tasto(t) {
        if (t === "C") { espressione = ""; aggiorna(); return }
        if (t === "⌫") { espressione = espressione.slice(0, -1); aggiorna(); return }
        if (t === "=") { if (risultato && !errore) { espressione = risultato.replace(/\./g, ""); risultato = "" } return }
        if (t === "()") {
            var aperte = (espressione.match(/\(/g) || []).length - (espressione.match(/\)/g) || []).length
            t = (aperte > 0 && /[0-9)%π]$/.test(espressione)) ? ")" : "("
        }
        if (t === "√") t = "√("
        espressione += t
        aggiorna()
    }

    Text {
        anchors.right: parent.right; anchors.rightMargin: 24
        anchors.bottom: tastiera.top; anchors.bottomMargin: 92
        width: parent.width - 48; horizontalAlignment: Text.AlignRight
        text: app.espressione || "0"
        color: tel.pal.testo; elide: Text.ElideLeft
        font.family: Tema.font; font.pixelSize: app.espressione.length > 12 ? 44 : 72; font.weight: Font.Light; font.letterSpacing: -1
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: 24
        anchors.bottom: tastiera.top; anchors.bottomMargin: 46
        text: app.risultato ? (app.errore ? app.risultato : "= " + app.risultato) : ""
        color: app.errore ? tel.rosso : tel.pal.testo2
        font.family: Tema.font; font.pixelSize: 24
        MouseArea { anchors.fill: parent; onClicked: app.tasto("=") }
    }

    Grid {
        id: tastiera
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 40
        columns: 4; rowSpacing: 12; columnSpacing: 12
        readonly property real lato: Math.min(80, (app.width - 32 - 36) / 4)
        Repeater {
            model: ["C", "()", "%", "÷", "7", "8", "9", "×", "4", "5", "6", "−", "1", "2", "3", "+", "√", "0", ",", "="]
            Rectangle {
                required property string modelData
                readonly property bool operatore: ["÷", "×", "−", "+", "="].indexOf(modelData) >= 0
                readonly property bool funzione: ["C", "()", "%", "√"].indexOf(modelData) >= 0
                width: tastiera.lato; height: tastiera.lato; radius: width / 2
                // «=» rosso pieno, operatori bianchi pieni, funzioni a contorno, cifre grigie
                color: modelData === "=" ? tel.accento
                       : operatore ? tel.pal.pieno
                       : funzione ? tel.pal.superficie
                       : tel.pal.superficie2

                Text {
                    anchors.centerIn: parent; text: parent.modelData === "()" ? "( )" : parent.modelData
                    color: parent.modelData === "=" ? "#ffffff" : (parent.operatore ? tel.pal.suPieno : tel.pal.testo)
                    font.family: Tema.font; font.pixelSize: parent.funzione ? 24 : 30; font.weight: parent.operatore ? Font.DemiBold : Font.Normal
                }
                MouseArea {
                    id: premuto
                    anchors.fill: parent
                    onClicked: app.tasto(parent.modelData)
                    onPressAndHold: if (parent.modelData === "C") app.tasto("C")
                }
                scale: premuto.pressed ? 0.94 : 1
                Behavior on scale { NumberAnimation { duration: 80 } }
            }
        }
    }
    // Cancella l'ultima cifra
    Text {
        anchors.left: parent.left; anchors.leftMargin: 28
        anchors.bottom: tastiera.top; anchors.bottomMargin: 10
        visible: app.espressione !== ""
        text: "⌫"; color: tel.pal.testo2; font.pixelSize: 26
        MouseArea { anchors.fill: parent; anchors.margins: -12; onClicked: app.tasto("⌫"); onPressAndHold: app.tasto("C") }
    }
}
