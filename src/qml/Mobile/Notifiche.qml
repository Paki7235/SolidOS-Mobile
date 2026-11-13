// Notifiche (dall'angolo in alto a sinistra): data e ora, poi l'elenco.
// Le notifiche vere arrivano quando il telefono fa da server delle notifiche (fase M2).
import QtQuick
import SolidUI

Item {
    id: nt
    MouseArea { anchors.fill: parent; onClicked: tel.notifiche = false }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 66
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: tel.giorno(); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(17); font.weight: Font.DemiBold }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: tel.ora(); color: tel.pal.testo; font.family: tel.fontOra; font.pixelSize: 64; font.weight: Font.Bold }
    }

    Column {
        x: 14; y: 200
        width: parent.width - 28
        spacing: 10
        Text { x: 6; text: I18n.t("Notifiche"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(20); font.weight: Font.Bold }
        Vetro {
            width: parent.width; height: vuoto.implicitHeight + 32
            Column {
                id: vuoto
                anchors.centerIn: parent
                width: parent.width - 32
                spacing: 6
                Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: "preferences-system-notifications-symbolic"; lato: 28 }
                Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: I18n.t("Nessuna notifica nuova"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.DemiBold }
                Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: I18n.t("Qui compariranno messaggi, chiamate perse e avvisi dal tuo PC."); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13) }
            }
        }
    }
}
