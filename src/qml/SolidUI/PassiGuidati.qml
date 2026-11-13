// Procedura guidata a passi: elenco di pagine con Indietro / Avanti.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: guida
    property var pagine: []          // elenco di Component
    property var titoli: []
    property int corrente: 0
    property bool avantiAbilitato: true
    property string testoFine: I18n.t("Fine")
    signal finito()
    signal cambioPagina(int indice)

    function avanti() {
        if (corrente < pagine.length - 1) { corrente++; cambioPagina(corrente) } else finito()
    }
    function indietro() { if (corrente > 0) { corrente--; cambioPagina(corrente) } }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Row {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 16
            spacing: 6
            Repeater {
                model: guida.pagine.length
                Rectangle {
                    width: index === guida.corrente ? 28 : 8
                    height: 8
                    radius: 4
                    color: index <= guida.corrente ? Tema.accento : Tema.bordo
                    Behavior on width { enabled: Tema.animazioni; NumberAnimation { duration: 150 } }
                }
            }
        }
        Loader {
            id: caricatore
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 24
            sourceComponent: guida.pagine[guida.corrente]
        }
        Separatore { Layout.fillWidth: true }
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 16
            Pulsante { text: I18n.t("Indietro"); visible: guida.corrente > 0; onClicked: guida.indietro() }
            Item { Layout.fillWidth: true }
            Pulsante {
                principale: true
                enabled: guida.avantiAbilitato
                text: guida.corrente === guida.pagine.length - 1 ? guida.testoFine : I18n.t("Avanti")
                onClicked: guida.avanti()
            }
        }
    }
}
