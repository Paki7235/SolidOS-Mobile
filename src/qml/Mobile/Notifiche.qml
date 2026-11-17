// Notifiche (dall'angolo in alto a sinistra), in stile iPhone: data e ora grandi al
// centro come sul blocco, poi le notifiche in schede di vetro. In alto «Non disturbare»
// e «Cancella». Le notifiche arrivano dalle app, dagli SMS e dalle chiamate perse.
import QtQuick
import SolidUI

Item {
    id: nt
    MouseArea { anchors.fill: parent; onClicked: tel.notifiche = false }

    // ── Data e ora grandi ────────────────────────────────────────────────
    Column {
        id: orologio
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(Math.min(64, nt.height * 0.075))
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tel.giorno()
            color: tel.pal.testo2
            font.family: Tema.font; font.pixelSize: tel.px(18); font.weight: Font.DemiBold
            font.capitalization: Font.Capitalize
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tel.ora()
            color: tel.pal.testo
            font.family: tel.fontOra; font.pixelSize: Math.min(84, Math.round(nt.width * 0.21)); font.weight: Font.Bold
            font.letterSpacing: -2
        }
    }

    // ── Titolo e comandi ─────────────────────────────────────────────────
    Item {
        id: testata
        x: 16; anchors.top: orologio.bottom; anchors.topMargin: 18
        width: parent.width - 32; height: 32
        Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Centro notifiche"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(18); font.weight: Font.Bold }
        Row {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Vetro {
                height: 30; width: dnd.implicitWidth + 40; radius: 15
                color: tel.imp.non_disturbare ? Qt.rgba(0.39, 0.40, 0.95, 0.92) : tel.pal.vetro
                Row {
                    anchors.centerIn: parent; spacing: 6
                    Icona { nome: "weather-clear-night-symbolic"; lato: 14; anchors.verticalCenter: parent.verticalCenter; tema: tel.imp.non_disturbare ? "scuro" : "" }
                    Text { id: dnd; text: I18n.t("Non disturbare"); color: tel.imp.non_disturbare ? "#ffffff" : tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(12); font.weight: Font.DemiBold }
                }
                MouseArea { anchors.fill: parent; onClicked: tel.nonDisturbare(!tel.imp.non_disturbare) }
            }
            Vetro {
                visible: tel.elencoNotifiche.length > 0
                height: 30; width: 30; radius: 15
                Text { anchors.centerIn: parent; text: "×"; color: tel.pal.testo; font.pixelSize: 18 }
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
                color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(15)
            }
        }
    }
}
