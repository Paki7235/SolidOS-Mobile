// Notifiche (dall'angolo in alto a sinistra): ora e data, «Non disturbare», le notifiche
// arrivate (dalle app, dagli SMS, dalle chiamate perse) e «Cancella tutto».
import QtQuick
import SolidUI

Item {
    id: nt
    MouseArea { anchors.fill: parent; onClicked: tel.notifiche = false }

    // ── Intestazione ─────────────────────────────────────────────────────
    Item {
        id: testata
        x: tel.margine; y: 52
        width: parent.width - 2 * tel.margine; height: 56
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text { text: tel.ora(); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 34; font.weight: Font.Light }
            Text { text: tel.giorno(); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13); font.capitalization: Font.Capitalize }
        }
    }

    Item {
        id: comandi
        x: tel.margine; anchors.top: testata.bottom; anchors.topMargin: 18
        width: parent.width - 2 * tel.margine; height: 32
        Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Notifiche"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(20); font.weight: Font.DemiBold }
        Row {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Rectangle {
                height: 32; width: dnd.implicitWidth + 42; radius: 16
                color: tel.imp.non_disturbare ? tel.accento : tel.pal.superficie2
                Row {
                    anchors.centerIn: parent; spacing: 6
                    Icona { nome: "weather-clear-night-symbolic"; lato: 14; anchors.verticalCenter: parent.verticalCenter }
                    Text { id: dnd; text: I18n.t("Non disturbare"); color: tel.imp.non_disturbare ? "#ffffff" : tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(12); font.weight: Font.DemiBold }
                }
                MouseArea { anchors.fill: parent; onClicked: tel.nonDisturbare(!tel.imp.non_disturbare) }
            }
            Rectangle {
                visible: tel.elencoNotifiche.length > 0
                height: 32; width: cancella.implicitWidth + 26; radius: 16
                color: tel.pal.superficie2
                Text { id: cancella; anchors.centerIn: parent; text: I18n.t("Cancella"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(12); font.weight: Font.DemiBold }
                MouseArea { anchors.fill: parent; onClicked: { ponte.chiama0("svuotaNotifiche"); tel.aggiornaNotifiche() } }
            }
        }
    }

    Flickable {
        anchors.top: comandi.bottom; anchors.topMargin: 14
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.leftMargin: tel.margine; anchors.rightMargin: tel.margine; anchors.bottomMargin: 30
        contentHeight: colonna.height
        clip: true
        Column {
            id: colonna
            width: parent.width
            spacing: 8
            Repeater {
                model: tel.elencoNotifiche
                SchedaNotifica { required property var modelData; n: modelData; color: tel.pal.superficie }
            }
            Rectangle {
                visible: tel.elencoNotifiche.length === 0
                width: parent.width; height: vuoto.implicitHeight + 40
                radius: tel.r3; color: tel.pal.superficie; border.color: tel.pal.bordo
                Column {
                    id: vuoto
                    anchors.centerIn: parent
                    width: parent.width - 40
                    spacing: 6
                    Icona { anchors.horizontalCenter: parent.horizontalCenter; nome: "preferences-system-notifications-symbolic"; lato: 26; opacity: 0.7 }
                    Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: I18n.t("Nessuna notifica"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(15); font.weight: Font.DemiBold }
                    Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: I18n.t("Qui compaiono messaggi, chiamate perse e avvisi delle app."); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13) }
                }
            }
        }
    }
}
