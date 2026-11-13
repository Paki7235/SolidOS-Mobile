// Notifiche (dall'angolo in alto a sinistra): data e ora, «Non disturbare», le notifiche
// arrivate (dalle app, dagli SMS, dalle chiamate perse) e «Cancella tutto».
import QtQuick
import SolidUI

Item {
    id: nt
    MouseArea { anchors.fill: parent; onClicked: tel.notifiche = false }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 62
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: tel.giorno(); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(17); font.weight: Font.DemiBold }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: tel.ora(); color: tel.pal.testo; font.family: tel.fontOra; font.pixelSize: 64; font.weight: Font.Bold }
    }

    Item {
        id: testata
        x: 20; y: 180; width: parent.width - 40; height: 34
        Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Notifiche"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(20); font.weight: Font.Bold }
        Row {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Rectangle {
                height: 30; width: dnd.implicitWidth + 40; radius: 15
                color: tel.imp.non_disturbare ? "#8b7cff" : tel.pal.vetro
                Row {
                    anchors.centerIn: parent; spacing: 6
                    Icona { nome: "weather-clear-night-symbolic"; lato: 14; anchors.verticalCenter: parent.verticalCenter }
                    Text { id: dnd; text: I18n.t("Non disturbare"); color: tel.imp.non_disturbare ? "#ffffff" : tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(12); font.weight: Font.DemiBold }
                }
                MouseArea { anchors.fill: parent; onClicked: tel.nonDisturbare(!tel.imp.non_disturbare) }
            }
            Rectangle {
                visible: tel.elencoNotifiche.length > 0
                height: 30; width: 30; radius: 15
                color: tel.pal.vetro
                Text { anchors.centerIn: parent; text: "×"; color: tel.pal.testo; font.pixelSize: 18 }
                MouseArea { anchors.fill: parent; onClicked: { ponte.chiama0("svuotaNotifiche"); tel.aggiornaNotifiche() } }
            }
        }
    }

    Flickable {
        anchors.top: testata.bottom; anchors.topMargin: 10
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.leftMargin: 14; anchors.rightMargin: 14; anchors.bottomMargin: 30
        contentHeight: colonna.height
        clip: true
        Column {
            id: colonna
            width: parent.width
            spacing: 8
            Repeater {
                model: tel.elencoNotifiche
                SchedaNotifica { required property var modelData; n: modelData }
            }
            Vetro {
                visible: tel.elencoNotifiche.length === 0
                width: parent.width; height: vuoto.implicitHeight + 32
                Column {
                    id: vuoto
                    anchors.centerIn: parent
                    width: parent.width - 32
                    spacing: 6
                    Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: "preferences-system-notifications-symbolic"; lato: 28 }
                    Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: I18n.t("Nessuna notifica"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.DemiBold }
                    Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: I18n.t("Qui compaiono messaggi, chiamate perse e avvisi delle app."); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13) }
                }
            }
        }
    }
}
