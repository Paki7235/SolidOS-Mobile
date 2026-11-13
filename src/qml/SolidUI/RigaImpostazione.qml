// Riga di un gruppo di impostazioni: titolo, descrizione e controllo a destra (slot «controllo»).
import QtQuick
import QtQuick.Layouts

Item {
    id: riga
    property string titolo: ""
    property string descrizione: ""
    property string icona: ""
    default property alias controllo: contenitore.data
    implicitHeight: Math.max(44, Math.max(testi.implicitHeight, contenitore.childrenRect.height) + 16)
    width: parent ? parent.width : 400
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 12
        Icona { nome: riga.icona; lato: 22; visible: riga.icona !== "" }
        ColumnLayout {
            id: testi
            Layout.fillWidth: true
            spacing: 2
            Text { text: riga.titolo; color: Tema.testo; font.family: Tema.font; font.pixelSize: 13; wrapMode: Text.Wrap; Layout.fillWidth: true }
            Text { text: riga.descrizione; color: Tema.testoSecondario; font.family: Tema.font; font.pixelSize: 11; wrapMode: Text.Wrap; visible: text !== ""; Layout.fillWidth: true; lineHeight: 1.1 }
        }
        Item {
            id: contenitore
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
