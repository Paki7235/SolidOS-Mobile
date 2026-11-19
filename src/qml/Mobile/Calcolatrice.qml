// Calcolatrice in stile Vetro (proposta B approvata): sullo sfondo del telefono, risultato in una
// scheda di vetro, tasti di vetro, operatori azzurri e «=» pieno. ⌫ toglie una cifra. In alto: Cronologia, e i modi Base, Scientifica e Converti
// (valute con i cambi della BCE, lunghezza, peso, volume, velocità, area, temperatura).
// Il calcolo lo fa il nucleo in modo sicuro (niente eval).
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: app
    color: "#0B0E18"
    // Vetro: colori dei tasti sopra lo sfondo
    readonly property color vetroCifra: Qt.rgba(1, 1, 1, tel.chiaro ? 0.45 : 0.10)
    readonly property color vetroFunzione: Qt.rgba(1, 1, 1, tel.chiaro ? 0.70 : 0.22)
    readonly property color vetroOperatore: Qt.rgba(0.47, 0.59, 1, tel.chiaro ? 0.55 : 0.35)
    readonly property color bordoVetro: Qt.rgba(1, 1, 1, tel.chiaro ? 0.55 : 0.13)
    readonly property color testo: tel.chiaro ? "#1D1D1F" : "#FFFFFF"
    readonly property color testo2: tel.chiaro ? "#4A4A55" : "#B8BCCB"
    Sfondo { anchors.fill: parent }
    Rectangle { anchors.fill: parent; color: tel.chiaro ? "#33FFFFFF" : "#59060816" }
    property string modo: "base"          // base | scientifica | converti
    property string espressione: ""
    property string risultato: ""         // anteprima mentre scrivi
    property string fatta: ""             // operazione appena calcolata (dopo «=»)
    property bool errore: false
    property bool radianti: false
    property bool mostraStoria: false
    property var storia: []
    // Converti
    property string categoria: "valuta"
    property var unita: []
    property string da: "EUR"
    property string a: "USD"
    property var conversione: ({ valore: "", nota: "" })
    readonly property var categorie: [{ k: "valuta", t: I18n.t("Valuta") }, { k: "lunghezza", t: I18n.t("Lunghezza") }, { k: "peso", t: I18n.t("Peso") },
                                      { k: "temperatura", t: I18n.t("Temperatura") }, { k: "volume", t: I18n.t("Volume") }, { k: "velocita", t: I18n.t("Velocità") }, { k: "area", t: I18n.t("Area") }]
    readonly property var predefinite: ({ valuta: ["EUR", "USD"], lunghezza: ["km", "mi"], peso: ["kg", "lb"], temperatura: ["°C", "°F"], volume: ["l", "gal"], velocita: ["km/h", "mph"], area: ["m²", "ft²"] })

    function aggiorna() {
        if (modo === "converti") { converti(); return }
        if (!espressione) { risultato = ""; errore = false; return }
        var r = ponte.chiama("calcola", [espressione, radianti])
        errore = !r.ok
        risultato = r.ok ? r.valore : (/[+−×÷^(]$/.test(espressione) ? "" : r.valore)
    }
    // Spazi intorno agli operatori, solo per leggere meglio
    function bello(x) { return x.replace(/([+×÷])/g, " $1 ").replace(/(\S)−/g, "$1 − ") }
    function converti() { conversione = ponte.chiama("calcConverti", [categoria, da, a, espressione || "0"]) }
    function scegliCategoria(k) {
        categoria = k
        unita = ponte.chiama("calcUnita", [k])
        da = predefinite[k][0]; a = predefinite[k][1]
        converti()
    }
    // «±» cambia il segno dell'ultimo numero
    function cambiaSegno() {
        var m = espressione.match(/(−?)([0-9.,]+)$/)
        if (!m) { espressione += "−"; return }
        var inizio = espressione.length - m[0].length
        espressione = espressione.slice(0, inizio) + (m[1] ? m[2] : "−" + m[2])
    }
    function tasto(t) {
        // dopo «=» un numero nuovo ricomincia, un operatore continua dal risultato
        if (fatta && "+−×÷%".indexOf(t) < 0 && ["=", "⌫", "±", "x²", "xʸ", "x!"].indexOf(t) < 0) espressione = ""
        if (t !== "=") fatta = ""
        if (t === "AC") { espressione = ""; aggiorna(); return }
        if (t === "⌫") { espressione = espressione.slice(0, -1); aggiorna(); return }
        if (t === "±") { cambiaSegno(); aggiorna(); return }
        if (t === "=") {
            if (modo === "converti" || !espressione || fatta) return
            var r = ponte.chiama("calcola", [espressione, radianti])
            if (!r.ok) { errore = true; risultato = r.valore; return }
            ponte.chiama("calcAggiungi", [espressione, r.valore])
            fatta = espressione
            espressione = r.valore.replace(/\./g, "")
            risultato = ""; errore = false
            return
        }
        if (t === "()") {
            var aperte = (espressione.match(/\(/g) || []).length - (espressione.match(/\)/g) || []).length
            t = (aperte > 0 && /[0-9)%π!e]$/.test(espressione)) ? ")" : "("
        }
        var funzioni = { "√": "√(", "sin": "sin(", "cos": "cos(", "tan": "tan(", "ln": "ln(", "log": "log(", "x²": "^2", "xʸ": "^", "x!": "!", "1/x": "1÷(" }
        if (funzioni[t] !== undefined) t = funzioni[t]
        espressione += t
        aggiorna()
    }
    onModoChanged: { if (modo === "converti" && unita.length === 0) scegliCategoria(categoria); else aggiorna() }
    onVisibleChanged: if (visible) storia = ponte.chiama0("calcStoria")
    Component.onCompleted: {
        // Foto della prova automatica
        var s = ponte.chiama0("avvio").schermata
        if (s === "calcolatrice") { espressione = "1.250×12%"; tasto("=") }
        else if (s === "calc-scientifica") { modo = "scientifica"; espressione = "√(2)×sin(45)"; tasto("=") }
        else if (s === "calc-cronologia") { ponte.chiama("calcAggiungi", ["24×7", "168"]); ponte.chiama("calcAggiungi", ["89,90−15%", "76,415"]); ponte.chiama("calcAggiungi", ["1.250×12%", "150"]); storia = ponte.chiama0("calcStoria"); mostraStoria = true }
        else if (s === "calc-converti") { espressione = "150"; modo = "converti" }
    }

    // ── In alto: Cronologia (tondo di vetro) e i modi in una pillola ─────
    Rectangle {
        x: 20; y: 54; width: 40; height: 40; radius: 20
        color: app.vetroCifra; border.width: 1; border.color: app.bordoVetro
        Icona { anchors.centerIn: parent; nome: "linea-cronologia"; lato: 20; colore: app.testo }
        MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: { app.storia = ponte.chiama0("calcStoria"); app.mostraStoria = true } }
    }
    Rectangle {
        anchors.right: parent.right; anchors.rightMargin: 20; y: 56
        width: rigaModi.width + 6; height: 36; radius: 18
        color: app.vetroCifra; border.width: 1; border.color: app.bordoVetro
        Row {
            id: rigaModi
            x: 3; anchors.verticalCenter: parent.verticalCenter; spacing: 2
            Repeater {
                model: [{ k: "base", t: I18n.t("Base") }, { k: "scientifica", t: I18n.t("Scientifica") }, { k: "converti", t: I18n.t("Converti") }]
                Rectangle {
                    required property var modelData
                    readonly property bool scelto: app.modo === modelData.k
                    width: etModo.implicitWidth + 24; height: 30; radius: 15
                    color: scelto ? (tel.chiaro ? "#1D1D1F" : "#F2FFFFFF") : "transparent"
                    Behavior on color { ColorAnimation { duration: tel.tVeloce } }
                    Text { id: etModo; anchors.centerIn: parent; text: parent.modelData.t; color: parent.scelto ? (tel.chiaro ? "#FFFFFF" : "#1D1D1F") : app.testo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; onClicked: app.modo = parent.modelData.k }
                }
            }
        }
    }

    // ── Operazione e risultato ───────────────────────────────────────────
    Rectangle {
        id: schedaRisultato
        visible: app.modo !== "converti"
        x: 16; width: parent.width - 32
        y: 112
        height: (app.modo === "scientifica" ? scientifica.y : tastiera.y) - y - 18
        radius: 28
        color: app.vetroCifra; border.width: 1; border.color: app.bordoVetro
    }
    Column {
        visible: app.modo !== "converti"
        anchors.right: schedaRisultato.right; anchors.rightMargin: 22
        anchors.bottom: schedaRisultato.bottom; anchors.bottomMargin: 16
        width: schedaRisultato.width - 44
        spacing: 2
        Text {
            width: parent.width; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft
            text: app.fatta ? app.bello(app.fatta) : (app.risultato ? (app.errore ? app.risultato : "= " + app.risultato) : "")
            color: app.errore && !app.fatta ? tel.rosso : app.testo2
            font.family: Tema.font; font.pixelSize: tel.px(20)
            MouseArea { anchors.fill: parent; onClicked: if (!app.fatta) app.tasto("=") }
        }
        Text {
            id: grande
            width: parent.width; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft
            // il risultato si mostra con i punti delle migliaia
            readonly property string mostra: app.fatta ? app.espressione.replace(/^(−?\d+)/, function (m) { return m.replace(/\B(?=(\d{3})+(?!\d))/g, ".") }) : (app.bello(app.espressione) || "0")
            text: mostra
            color: app.testo
            font.family: Tema.font; font.weight: Font.Light; font.letterSpacing: -3
            font.pixelSize: Math.min(app.modo === "scientifica" ? 64 : 82, schedaRisultato.height - 50) * (mostra.length > 8 ? Math.max(0.45, 8 / mostra.length) : 1)
            MouseArea { anchors.fill: parent; onPressAndHold: { tel.copia(grande.text); tel.avviso(I18n.t("Copiato")) } }
        }
    }

    // ── Converti ───────────────────────────────────────────────────────
    Column {
        visible: app.modo === "converti"
        x: 16; y: 104; width: parent.width - 32; spacing: 12
        Flickable {
            width: parent.width; height: 30; contentWidth: chip.width; clip: true
            flickableDirection: Flickable.HorizontalFlick; boundsBehavior: Flickable.StopAtBounds
            Row {
                id: chip
                spacing: 8
                Repeater {
                    model: app.categorie
                    Rectangle {
                        required property var modelData
                        height: 30; width: etc.implicitWidth + 26; radius: 15
                        color: app.categoria === modelData.k ? (tel.chiaro ? "#1D1D1F" : "#F2FFFFFF") : app.vetroCifra
                        border.width: 1; border.color: app.bordoVetro
                        Text { id: etc; anchors.centerIn: parent; text: parent.modelData.t; color: app.categoria === parent.modelData.k ? (tel.chiaro ? "#FFFFFF" : "#1D1D1F") : app.testo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                        MouseArea { anchors.fill: parent; onClicked: app.scegliCategoria(parent.modelData.k) }
                    }
                }
            }
        }
        Rectangle {
            width: parent.width; height: 150; radius: 28; color: app.vetroCifra; border.width: 1; border.color: app.bordoVetro
            Repeater {
                model: 2
                Item {
                    id: rigaC
                    required property int index
                    readonly property string codice: index === 0 ? app.da : app.a
                    y: index * 75; width: parent.width; height: 75
                    Rectangle { visible: rigaC.index > 0; x: 16; width: parent.width - 16; height: 1; color: app.bordoVetro }
                    Column {
                        x: 16; anchors.verticalCenter: parent.verticalCenter
                        Row {
                            spacing: 6
                            Text { id: cod; text: rigaC.codice; color: app.testo; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.Bold }
                            Text { anchors.baseline: cod.baseline; text: "▾"; color: tel.accento; font.pixelSize: 12 }
                        }
                        Text {
                            readonly property string nome: (app.unita.find(function (u) { return u.id === rigaC.codice }) || { nome: "" }).nome
                            visible: nome !== "" && nome !== rigaC.codice; text: nome
                            color: app.testo2; font.family: Tema.font; font.pixelSize: tel.px(12)
                        }
                    }
                    MouseArea { width: 150; height: parent.height; onClicked: { sceltaUnita.lato = rigaC.index; sceltaUnita.open() } }
                    Text {
                        anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 190; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft
                        text: rigaC.index === 0 ? (app.espressione || "0") : (app.conversione.valore || "—")
                        color: rigaC.index === 0 ? app.testo : app.testo2
                        font.family: Tema.font; font.weight: Font.Light; font.pixelSize: rigaC.index === 0 ? 40 : 34
                    }
                }
            }
            // Scambia le due unità
            Rectangle {
                x: 150; anchors.verticalCenter: parent.verticalCenter
                width: 32; height: 32; radius: 16; color: app.vetroFunzione; border.width: 1; border.color: app.bordoVetro
                Text { anchors.centerIn: parent; text: "⇅"; color: tel.accento; font.pixelSize: 17 }
                MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: { var t = app.da; app.da = app.a; app.a = t; app.converti() } }
            }
        }
        Text {
            width: parent.width; wrapMode: Text.Wrap; visible: text !== ""
            text: app.conversione.nota ? app.conversione.nota + ". " + I18n.t("Senza rete usa l'ultimo scaricato.") : ""
            color: app.testo2; font.family: Tema.font; font.pixelSize: tel.px(12.5)
        }
    }
    Popup {
        id: sceltaUnita
        property int lato: 0
        anchors.centerIn: parent
        width: parent.width - 40; height: Math.min(parent.height - 160, elencoU.contentHeight + 24); modal: true; padding: 12
        background: Rectangle { radius: 20; color: tel.pal.superficie }
        ListView {
            id: elencoU
            anchors.fill: parent; clip: true
            model: app.unita
            delegate: Item {
                required property var modelData
                width: elencoU.width; height: 46
                Text { x: 8; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.id; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.Bold }
                Text { x: 76; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.nome !== parent.modelData.id ? parent.modelData.nome : ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(14) }
                Text { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; visible: (sceltaUnita.lato === 0 ? app.da : app.a) === parent.modelData.id; text: "✓"; color: tel.accento; font.pixelSize: 16 }
                MouseArea { anchors.fill: parent; onClicked: { if (sceltaUnita.lato === 0) app.da = parent.modelData.id; else app.a = parent.modelData.id; sceltaUnita.close(); app.converti() } }
            }
        }
    }

    // ── Funzioni scientifiche ──────────────────────────────────────────
    Grid {
        id: scientifica
        visible: app.modo === "scientifica"
        x: 16; anchors.bottom: tastiera.top; anchors.bottomMargin: 14
        columns: 5; spacing: 8
        Repeater {
            model: ["(", ")", "x²", "xʸ", "√", "sin", "cos", "tan", "ln", "log", "π", "e", "x!", "1/x", "Rad"]
            Rectangle {
                id: fs
                required property string modelData
                readonly property bool rad: modelData === "Rad"
                width: (app.width - 32 - 32) / 5; height: 42; radius: 14
                color: rad && app.radianti ? app.vetroOperatore : app.vetroCifra
                border.width: 1; border.color: app.bordoVetro
                Text { anchors.centerIn: parent; text: fs.modelData; color: app.testo; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.Medium }
                MouseArea {
                    id: ps
                    anchors.fill: parent
                    onClicked: { if (fs.rad) { app.radianti = !app.radianti; app.aggiorna() } else app.tasto(fs.modelData) }
                }
                scale: ps.pressed ? 0.94 : 1
                Behavior on scale { NumberAnimation { duration: 80 } }
            }
        }
    }

    // ── Tasti ──────────────────────────────────────────────────────────
    Gradient { id: sfumatura; GradientStop { position: 0; color: Qt.lighter(tel.accento, 1.3) } GradientStop { position: 1; color: tel.accento } }
    Grid {
        id: tastiera
        x: 16; anchors.bottom: parent.bottom; anchors.bottomMargin: 34
        columns: 4; spacing: 11
        readonly property real largo: (app.width - 32 - 33) / 4
        readonly property real alto: app.modo === "base" ? Math.min(74, largo) : 64
        Repeater {
            model: ["AC", "⌫", "%", "÷", "7", "8", "9", "×", "4", "5", "6", "−", "1", "2", "3", "+", "±", "0", ",", "="]
            Rectangle {
                id: k
                required property string modelData
                readonly property bool operatore: ["÷", "×", "−", "+", "="].indexOf(modelData) >= 0
                readonly property bool funzione: ["AC", "⌫", "%"].indexOf(modelData) >= 0
                width: tastiera.largo; height: tastiera.alto; radius: 24
                color: k.modelData === "=" ? tel.accento : (operatore ? app.vetroOperatore : (funzione ? app.vetroFunzione : app.vetroCifra))
                gradient: k.modelData === "=" ? sfumatura : null
                border.width: 1; border.color: operatore ? Qt.rgba(1, 1, 1, 0.25) : app.bordoVetro
                // luce in alto, come il vetro
                Rectangle { anchors.fill: parent; anchors.margins: 1; radius: parent.radius - 1; color: "transparent"
                            gradient: Gradient { GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.10) } GradientStop { position: 0.35; color: "transparent" } } }
                Text {
                    visible: k.modelData !== "⌫"
                    anchors.centerIn: parent
                    text: k.modelData === "AC" && app.espressione && !app.fatta ? "C" : k.modelData
                    color: k.modelData === "=" ? "#FFFFFF" : app.testo
                    font.family: Tema.font; font.pixelSize: k.funzione ? 25 : 32; font.weight: k.funzione ? Font.Medium : Font.Normal
                }
                Icona { visible: k.modelData === "⌫"; anchors.centerIn: parent; nome: "linea-tasto-cancella"; lato: 26; colore: app.testo }
                MouseArea {
                    id: pk
                    anchors.fill: parent
                    onClicked: app.tasto(k.modelData)
                    onPressAndHold: if (k.modelData === "⌫") app.tasto("AC")
                }
                scale: pk.pressed ? 0.95 : 1
                opacity: pk.pressed ? 0.85 : 1
                Behavior on scale { NumberAnimation { duration: 80 } }
            }
        }
    }

    // ── Cronologia ─────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent; color: "#80000000"
        opacity: app.mostraStoria ? 1 : 0; visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: tel.tNormale } }
        MouseArea { anchors.fill: parent; onClicked: app.mostraStoria = false }
    }
    Rectangle {
        width: parent.width; height: parent.height - 70
        y: app.mostraStoria ? 70 : parent.height
        visible: y < parent.height
        Behavior on y { Movimento { apre: app.mostraStoria } }
        radius: 26; color: tel.pal.superficie
        MouseArea { anchors.fill: parent }
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 10; width: 40; height: 5; radius: 3; color: tel.pal.bordo }
        Text { x: 18; y: 32; text: I18n.t("Cronologia"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(22); font.weight: Font.Bold }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 18; y: 37
            visible: app.storia.length > 0
            text: I18n.t("Cancella"); color: tel.rosso; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.Medium
            MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: { ponte.chiama0("calcCancellaStoria"); app.storia = [] } }
        }
        Text {
            visible: app.storia.length === 0
            x: 18; y: 90; width: parent.width - 36; wrapMode: Text.Wrap
            text: I18n.t("Qui trovi i calcoli fatti con «=».")
            color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(14)
        }
        Flickable {
            x: 18; y: 74; width: parent.width - 36; height: parent.height - 74 - 30
            contentHeight: colStoria.height + 20; clip: true
            Column {
                id: colStoria
                width: parent.width; spacing: 8
                Repeater {
                    model: app.storia
                    Column {
                        id: gruppoS
                        required property var modelData
                        width: colStoria.width; spacing: 8
                        Text { topPadding: 12; text: gruppoS.modelData.giorno.toUpperCase(); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.Bold; font.letterSpacing: 0.4 }
                        Rectangle {
                            width: parent.width; height: colC.height; radius: 14; color: tel.pal.superficie2
                            Column {
                                id: colC
                                width: parent.width
                                Repeater {
                                    model: gruppoS.modelData.calcoli
                                    Item {
                                        id: calcolo
                                        required property var modelData
                                        required property int index
                                        width: colC.width; height: 46
                                        Rectangle { visible: calcolo.index > 0; x: 14; width: parent.width - 14; height: 1; color: tel.pal.bordo }
                                        Text { x: 14; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 140; elide: Text.ElideRight; text: app.bello(calcolo.modelData.espressione); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(15) }
                                        Text { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: calcolo.modelData.risultato; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(18); font.weight: Font.DemiBold }
                                        MouseArea { anchors.fill: parent; onClicked: { app.fatta = ""; app.espressione += calcolo.modelData.risultato.replace(/\./g, ""); app.aggiorna(); app.mostraStoria = false } }
                                    }
                                }
                            }
                        }
                    }
                }
                Text { visible: app.storia.length > 0; width: parent.width; wrapMode: Text.Wrap; topPadding: 8; text: I18n.t("Tocca un risultato per riusarlo. Tieni premuto il risultato in alto per copiarlo."); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13) }
            }
        }
    }
}
