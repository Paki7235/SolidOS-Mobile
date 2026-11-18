// Notifiche (dall'angolo in alto a sinistra): data e ora grandi al centro, poi «Notifiche»
// con «Non disturbare» e «Cancella», e le schede di vetro. Le notifiche arrivano dalle app,
// dagli SMS e dalle chiamate perse.
import QtQuick
import SolidUI

Item {
    id: nt
    MouseArea { anchors.fill: parent; onClicked: tel.notifiche = false }

    // ── Data e ora ───────────────────────────────────────────────────────
    Column {
        id: orologio
        anchors.horizontalCenter: parent.horizontalCenter
        y: 56
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: tel.giorno(); color: tel.chiaro ? "#1D1D1F" : "#FFFFFF"; opacity: 0.9
               font.family: Tema.font; font.pixelSize: tel.px(17); font.weight: Font.DemiBold }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: tel.ora(); color: tel.chiaro ? "#1D1D1F" : "#FFFFFF"
               font.family: tel.fontOra; font.pixelSize: Math.min(80, Math.round(nt.width * 0.2)); font.weight: Font.DemiBold; font.letterSpacing: -3 }
    }

    // ── Titolo e comandi ─────────────────────────────────────────────────
    Item {
        id: testata
        x: 16; anchors.top: orologio.bottom; anchors.topMargin: 14
        width: parent.width - 32; height: 34
        Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Notifiche"); color: tel.chiaro ? "#1D1D1F" : "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(20); font.weight: Font.Bold }
        Row {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Vetro {
                height: 32; width: dnd.implicitWidth + 42; radius: 16
                Rectangle { anchors.fill: parent; radius: 16; color: tel.accento; visible: tel.imp.non_disturbare === true }
                Row {
                    anchors.centerIn: parent; spacing: 6
                    Icona { nome: "weather-clear-night-symbolic"; lato: 14; anchors.verticalCenter: parent.verticalCenter; tema: tel.imp.non_disturbare ? "scuro" : "" }
                    Text { id: dnd; anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Non disturbare"); color: tel.imp.non_disturbare ? "#FFFFFF" : tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                }
                MouseArea { anchors.fill: parent; onClicked: tel.nonDisturbare(!tel.imp.non_disturbare) }
            }
            Vetro {
                visible: tel.elencoNotifiche.length > 0
                height: 32; width: 32; radius: 16
                Text { anchors.centerIn: parent; text: "×"; color: tel.pal.testo; font.pixelSize: 19 }
                MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: { ponte.chiama0("svuotaNotifiche"); tel.aggiornaNotifiche() } }
            }
        }
    }

    // ── Notifiche ────────────────────────────────────────────────────────
    Flickable {
        anchors.top: testata.bottom; anchors.topMargin: 12
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.bottomMargin: 30
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
            Text {
                visible: tel.elencoNotifiche.length === 0
                width: parent.width; topPadding: 40
                horizontalAlignment: Text.AlignHCenter
                text: tel.imp.non_disturbare ? I18n.t("Non disturbare attivo") : I18n.t("Nessuna notifica")
                color: tel.chiaro ? "#1D1D1F" : "#FFFFFF"; opacity: 0.75; font.family: Tema.font; font.pixelSize: tel.px(15)
            }
        }
    }
}
