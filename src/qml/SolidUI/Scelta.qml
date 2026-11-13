// Menu a tendina come su Windows 11: un clic apre l'elenco completo sotto il campo
// (o sopra, se sotto non c'è posto), la scelta attuale ha la barretta colorata,
// un clic su un'opzione la sceglie e chiude. La rotellina del mouse non cambia
// il valore per sbaglio mentre si scorre la pagina.
// Il modello è un elenco di stringhe o di oggetti {testo, valore}.
import QtQuick
import QtQuick.Controls

ComboBox {
    id: scelta
    font.family: Tema.font
    font.pixelSize: 13
    textRole: "testo"
    valueRole: "valore"
    implicitWidth: 220
    implicitHeight: 32
    hoverEnabled: true
    wheelEnabled: false
    readonly property int altezzaVoce: 34
    readonly property int quante: count

    background: Rectangle {
        implicitHeight: 32
        radius: 6
        color: scelta.pressed || scelta.popup.visible ? (Tema.chiaro ? "#F2F2F4" : "#2A2B31")
               : (scelta.hovered ? (Tema.chiaro ? "#F7F7F9" : "#34353C") : (Tema.chiaro ? "#FFFFFF" : Tema.superficieAlta))
        border.width: 1
        border.color: Tema.chiaro ? "#D9D9DE" : "#14FFFFFF"
        // linea inferiore come Windows 11 (accento quando è aperto)
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left; anchors.right: parent.right
            anchors.leftMargin: 1; anchors.rightMargin: 1
            height: scelta.popup.visible || scelta.activeFocus ? 2 : 1
            radius: 1
            color: scelta.popup.visible || scelta.activeFocus ? Tema.accento : (Tema.chiaro ? "#B8B8BF" : "#30FFFFFF")
        }
    }
    contentItem: Text {
        leftPadding: 11
        rightPadding: 30
        text: scelta.displayText
        font: scelta.font
        color: scelta.enabled ? Tema.testo : Tema.testoSecondario
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    // freccia verso il basso
    indicator: Canvas {
        x: scelta.width - width - 11
        y: (scelta.height - height) / 2 + (scelta.pressed ? 1 : 0)
        width: 10
        height: 6
        onPaint: {
            var c = getContext("2d"); c.reset()
            c.strokeStyle = Tema.testoSecondario; c.lineWidth = 1.5; c.lineCap = "round"; c.lineJoin = "round"
            c.beginPath(); c.moveTo(1, 1); c.lineTo(5, 5); c.lineTo(9, 1); c.stroke()
        }
        property bool chiaro: Tema.chiaro
        onChiaroChanged: requestPaint()
    }

    delegate: ItemDelegate {
        id: opzione
        required property var modelData
        required property int index
        width: ListView.view ? ListView.view.width : scelta.width
        height: scelta.altezzaVoce
        hoverEnabled: true
        padding: 0
        readonly property bool attuale: scelta.currentIndex === index
        contentItem: Text {
            text: opzione.modelData.testo !== undefined ? opzione.modelData.testo : opzione.modelData
            font: scelta.font
            color: Tema.testo
            verticalAlignment: Text.AlignVCenter
            leftPadding: 14
            rightPadding: 10
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: 5
            color: opzione.pressed ? (Tema.chiaro ? "#0F000000" : "#14FFFFFF")
                   : (opzione.hovered || opzione.attuale ? (Tema.chiaro ? "#0A000000" : "#0FFFFFFF") : "transparent")
            // barretta della scelta attuale
            Rectangle {
                visible: opzione.attuale
                x: 0; anchors.verticalCenter: parent.verticalCenter
                width: 3; height: 16; radius: 1.5
                color: Tema.accento
            }
        }
    }

    popup: Popup {
        // sotto il campo; se non c'è spazio, sopra
        readonly property real altezzaPiena: Math.min(scelta.quante * scelta.altezzaVoce + 10, 360)
        onAboutToShow: {
            var sotto = scelta.Window.height - scelta.mapToItem(null, 0, scelta.height).y - 8
            var sopra = scelta.mapToItem(null, 0, 0).y - 8
            y = (sotto >= altezzaPiena || sotto >= sopra) ? scelta.height + 4 : -altezzaPiena - 4
        }
        width: Math.max(scelta.width, 160)
        height: altezzaPiena
        padding: 5
        margins: 6
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Tema.animazioni ? 110 : 0 } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Tema.animazioni ? 80 : 0 } }
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: scelta.popup.visible ? scelta.delegateModel : null
            currentIndex: scelta.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
            ScrollIndicator.vertical: ScrollIndicator { }
        }
        background: Rectangle {
            radius: 8
            color: Tema.chiaro ? "#FCFCFD" : "#2C2D33"
            border.color: Tema.chiaro ? "#1F000000" : "#24FFFFFF"
            border.width: 1
        }
    }
}
