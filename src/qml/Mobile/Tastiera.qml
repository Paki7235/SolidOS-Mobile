// Tastiera sullo schermo, italiana. Compare quando si tocca un campo di testo e manda i tasti
// al campo come una tastiera vera (dal nucleo: «tasto»), quindi funziona con ogni campo.
// - Lettere QWERTY; tieni premuta una vocale per la lettera accentata (è, à, ò, ù, ì; «é» su e).
// - «123» per numeri e simboli, «#+=» per gli altri simboli.
// - Nei campi email ci sono «@» e «.» accanto allo spazio; negli indirizzi web «/» e «.it».
// - Nei campi dei numeri di telefono c'è il tastierino.
import QtQuick
import SolidUI

Rectangle {
    id: kb
    // Il campo di testo che ha il fuoco (TextField, TextInput, TextEdit)
    readonly property Item campo: {
        var f = tel.activeFocusItem
        return f && f.cursorPosition !== undefined && !f.readOnly && f.visible ? f : null
    }
    readonly property int hints: campo ? campo.inputMethodHints : 0
    // Solo per la foto della prova automatica (--schermata=tastiera o tastierino)
    readonly property string prova: { var a = ponte.chiama0("avvio").schermata || ""; return a === "tastiera" || a === "tastierino" ? a : "" }
    readonly property bool email: (hints & Qt.ImhEmailCharactersOnly) !== 0 || prova === "tastiera"
    readonly property bool web: (hints & Qt.ImhUrlCharactersOnly) !== 0
    readonly property bool numerico: prova === "tastierino" || (hints & (Qt.ImhDialableCharactersOnly | Qt.ImhDigitsOnly | Qt.ImhFormattedNumbersOnly)) !== 0
    readonly property bool aperta: (campo !== null || prova !== "") && tel.imp.tastiera !== false
    property string pagina: "lettere"        // lettere | numeri | simboli
    property int maiuscole: 0                // 0 no, 1 una lettera, 2 blocco
    readonly property real altezza: aperta ? height : 0

    onCampoChanged: {
        pagina = "lettere"
        // Maiuscola all'inizio di un campo vuoto (non per email e indirizzi)
        maiuscole = campo && campo.length === 0 && !email && !web && campo.echoMode !== TextInput.Password ? 1 : 0
    }

    function scrivi(t) {
        if (maiuscole > 0 && pagina === "lettere") t = t.toUpperCase()
        ponte.chiama("tasto", [t, ""])
        if (maiuscole === 1) maiuscole = 0
    }
    function speciale(n) { ponte.chiama("tasto", ["", n]) }

    readonly property color fondo: tel.chiaro ? "#D3D5DB" : "#202125"
    readonly property color tastoChiaro: tel.chiaro ? "#FFFFFF" : "#4A4B52"
    readonly property color tastoScuro: tel.chiaro ? "#ABAFB9" : "#34353B"

    anchors.left: parent.left; anchors.right: parent.right
    height: colonna.height + 34
    y: parent.height - (aperta ? height : 0)
    visible: y < parent.height
    Behavior on y { NumberAnimation { duration: tel.tNormale; easing.type: Easing.OutQuint } }
    color: fondo
    MouseArea { anchors.fill: parent }   // i tocchi tra i tasti non arrivano all'app sotto

    readonly property real passo: (width - 6) / 10        // larghezza di un tasto + spazio
    readonly property real lato: passo - 6

    component Tasto: Rectangle {
        id: t
        property string testo: ""
        property string etichetta: testo
        property string icona: ""
        property bool scuro: false
        property real larga: 1
        property string accento: ""          // con la pressione lunga
        property bool ripeti: false          // tenuto premuto si ripete (cancella)
        property color coloreTesto: tel.pal.testo
        signal premuto()
        Timer { running: t.ripeti && area.lunga && area.pressed; interval: 90; repeat: true; onTriggered: t.premuto() }
        width: kb.lato * larga + (larga - 1) * 6; height: 44; radius: 8
        color: area.pressed ? (scuro ? kb.tastoChiaro : kb.tastoScuro) : (scuro ? kb.tastoScuro : kb.tastoChiaro)
        Rectangle { anchors.fill: parent; anchors.topMargin: 1; anchors.bottomMargin: -1; radius: 8; z: -1; color: "#40000000" }
        Text {
            visible: t.icona === ""
            anchors.centerIn: parent
            text: kb.maiuscole > 0 && kb.pagina === "lettere" && t.testo.length === 1 ? t.etichetta.toUpperCase() : t.etichetta
            color: t.coloreTesto; font.family: Tema.font
            font.pixelSize: t.etichetta.length > 2 ? 15 : 22
            font.weight: t.etichetta.length > 2 ? Font.Medium : Font.Normal
        }
        Icona { visible: t.icona !== ""; anchors.centerIn: parent; nome: t.icona; lato: 20 }
        // Anteprima della lettera sopra il dito
        Rectangle {
            visible: area.pressed && t.testo.length === 1 && !t.scuro
            width: t.width + 16; height: 56; radius: 10
            anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.top; anchors.bottomMargin: 4
            color: kb.tastoChiaro
            Text { anchors.centerIn: parent; text: area.lunga && t.accento ? t.accento : (kb.maiuscole > 0 && kb.pagina === "lettere" ? t.testo.toUpperCase() : t.testo); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 30 }
        }
        MouseArea {
            id: area
            property bool lunga: false
            anchors.fill: parent; anchors.margins: -3
            pressAndHoldInterval: 420
            onPressed: lunga = false
            onPressAndHold: if (t.accento || t.ripeti) lunga = true
            onReleased: {
                if (!containsMouse && !lunga) return
                if (lunga && t.ripeti) return
                if (lunga && t.accento) kb.scrivi(t.accento)
                else if (t.testo) kb.scrivi(t.testo)
                t.premuto()
            }
        }
    }

    // Lettere, numeri, simboli
    readonly property var righe: pagina === "numeri" ? ["1234567890", "-/:;()€&@\"", ".,?!'"]
                               : pagina === "simboli" ? ["[]{}#%^*+=", "_\\|~<>$£¥•", ".,?!'"]
                               : ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
    readonly property var accenti: ({ e: "è", a: "à", o: "ò", u: "ù", i: "ì" })

    Column {
        id: colonna
        visible: !kb.numerico
        x: 3; y: 8; width: parent.width - 6; spacing: 11
        Repeater {
            model: 2
            Row {
                id: riga
                required property int index
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                Repeater {
                    model: kb.righe[riga.index].split("")
                    Tasto { required property string modelData; testo: modelData; accento: kb.pagina === "lettere" ? (kb.accenti[modelData] || "") : "" }
                }
            }
        }
        // Terza riga: maiuscole / altri simboli, lettere, cancella
        Item {
            width: parent.width; height: 44
            Tasto {
                x: 0; scuro: kb.maiuscole === 0 || kb.pagina !== "lettere"; larga: 1.35
                etichetta: kb.pagina === "lettere" ? "" : (kb.pagina === "numeri" ? "#+=" : "123")
                icona: kb.pagina === "lettere" ? "linea-tasto-maiuscole" : ""
                color: kb.pagina === "lettere" && kb.maiuscole > 0 ? (tel.chiaro ? "#FFFFFF" : "#F5F5F7") : (scuro ? kb.tastoScuro : kb.tastoChiaro)
                onPremuto: {
                    if (kb.pagina === "lettere") kb.maiuscole = kb.maiuscole === 0 ? 1 : (kb.maiuscole === 1 && raddoppio.running ? 2 : 0)
                    else kb.pagina = kb.pagina === "numeri" ? "simboli" : "numeri"
                    raddoppio.restart()
                }
                Timer { id: raddoppio; interval: 350 }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                Repeater {
                    model: kb.righe[2].split("")
                    Tasto { required property string modelData; testo: modelData; larga: kb.pagina === "lettere" ? 1 : 1.32 }
                }
            }
            Tasto {
                anchors.right: parent.right; scuro: true; larga: 1.35; icona: "linea-tasto-cancella"
                ripeti: true
                onPremuto: kb.speciale("cancella")
            }
        }
        // Ultima riga: 123/ABC, (@), spazio, (.), invio
        Row {
            width: parent.width; spacing: 6
            Tasto { scuro: true; larga: 1.35; etichetta: kb.pagina === "lettere" ? "123" : "ABC"; onPremuto: kb.pagina = kb.pagina === "lettere" ? "numeri" : "lettere" }
            Tasto { visible: kb.email; testo: "@" }
            Tasto { visible: kb.web; testo: "/" }
            Tasto {
                etichetta: "spazio"
                larga: 10 - 1.35 - 2.3 - (kb.email || kb.web ? 2 : 0)
                onPremuto: kb.scrivi(" ")
            }
            Tasto { visible: kb.email; testo: "." }
            Tasto { visible: kb.web; testo: ".it"; etichetta: ".it" }
            Tasto {
                larga: 2.3
                etichetta: kb.campo && kb.campo.echoMode === TextInput.Password ? I18n.t("Entra") : I18n.t("Invio")
                color: tel.accento; coloreTesto: "#FFFFFF"
                onPremuto: kb.speciale("invio")
            }
        }
    }

    // Tastierino per i numeri di telefono
    Grid {
        visible: kb.numerico
        x: 3; y: 8; columns: 3; spacing: 6
        Repeater {
            model: [["1", ""], ["2", "ABC"], ["3", "DEF"], ["4", "GHI"], ["5", "JKL"], ["6", "MNO"], ["7", "PQRS"], ["8", "TUV"], ["9", "WXYZ"], ["+", "* #"], ["0", ""], ["⌫", ""]]
            Rectangle {
                id: cifra
                required property var modelData
                width: (kb.width - 18) / 3; height: 48; radius: 8
                color: tocco.pressed ? kb.tastoScuro : (modelData[0] === "⌫" || modelData[0] === "+" ? "transparent" : kb.tastoChiaro)
                Column {
                    visible: cifra.modelData[0] !== "⌫"
                    anchors.centerIn: parent
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: cifra.modelData[0]; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 24 }
                    Text { visible: cifra.modelData[1] !== ""; anchors.horizontalCenter: parent.horizontalCenter; text: cifra.modelData[1]; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.5 }
                }
                Icona { visible: cifra.modelData[0] === "⌫"; anchors.centerIn: parent; nome: "linea-tasto-cancella"; lato: 22 }
                MouseArea {
                    id: tocco
                    anchors.fill: parent
                    onClicked: cifra.modelData[0] === "⌫" ? kb.speciale("cancella") : kb.scrivi(cifra.modelData[0])
                    onPressAndHold: if (cifra.modelData[0] === "0") kb.scrivi("+")
                }
            }
        }
    }

    // Chiudi la tastiera
    Item {
        anchors.right: parent.right; anchors.bottom: parent.bottom
        width: 56; height: 30
        Icona { anchors.centerIn: parent; nome: "go-up-symbolic"; lato: 18; rotation: 180; opacity: 0.7 }
        MouseArea { anchors.fill: parent; onClicked: if (kb.campo) kb.campo.focus = false }
    }
}
