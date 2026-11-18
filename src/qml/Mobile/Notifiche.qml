// Notifiche (dall'angolo in alto a sinistra), stile «Essenziale»: data in piccolo e ora a
// puntini, poi «Notifiche» con il numero, «Non disturbare» e «Cancella», e le schede.
// Le notifiche arrivano dalle app, dagli SMS e dalle chiamate perse.
import QtQuick
import SolidUI

Item {
    id: nt
    MouseArea { anchors.fill: parent; onClicked: tel.notifiche = false }

    // ── Data e ora ───────────────────────────────────────────────────────
    Column {
        id: orologio
        x: tel.margine + 4
        y: 58
        spacing: 4
        Mono { text: tel.adesso.toLocaleDateString(Qt.locale("it_IT"), "dddd · d MMM"); font.pixelSize: tel.px(12) }
        Punti { text: tel.ora(); font.family: tel.fontOra; font.pixelSize: 64; font.letterSpacing: -2 }
    }

    // ── Titolo e comandi ─────────────────────────────────────────────────
    Item {
        id: testata
        x: tel.margine; anchors.top: orologio.bottom; anchors.topMargin: 22
        width: parent.width - 2 * tel.margine; height: 34
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Rectangle { visible: tel.elencoNotifiche.length > 0; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: tel.rosso }
            Mono { anchors.verticalCenter: parent.verticalCenter; color: tel.pal.testo; font.pixelSize: tel.px(13)
                   text: I18n.t("Notifiche") + (tel.elencoNotifiche.length ? " · " + tel.elencoNotifiche.length : "") }
        }
        Row {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Rectangle {
                height: 34; width: dnd.implicitWidth + 44; radius: 17
                color: tel.imp.non_disturbare ? tel.pal.pieno : "transparent"
                border.width: 1; border.color: tel.imp.non_disturbare ? tel.pal.pieno : tel.pal.bordo
                Behavior on color { ColorAnimation { duration: tel.tVeloce } }
                Row {
                    anchors.centerIn: parent; spacing: 6
                    Icona { nome: "weather-clear-night-symbolic"; lato: 14; anchors.verticalCenter: parent.verticalCenter; tema: tel.imp.non_disturbare ? (tel.chiaro ? "scuro" : "chiaro") : "" }
                    Text { id: dnd; anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Non disturbare"); color: tel.imp.non_disturbare ? tel.pal.suPieno : tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold }
                }
                MouseArea { anchors.fill: parent; onClicked: tel.nonDisturbare(!tel.imp.non_disturbare) }
            }
            Rectangle {
                visible: tel.elencoNotifiche.length > 0
                height: 34; width: 34; radius: 17
                color: "transparent"; border.width: 1; border.color: tel.pal.bordo
                Text { anchors.centerIn: parent; text: "×"; color: tel.pal.testo; font.pixelSize: 19 }
                MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: { ponte.chiama0("svuotaNotifiche"); tel.aggiornaNotifiche() } }
            }
        }
    }

    // ── Notifiche ────────────────────────────────────────────────────────
    Flickable {
        anchors.top: testata.bottom; anchors.topMargin: 12
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
            Text {
                visible: tel.elencoNotifiche.length === 0
                width: parent.width; topPadding: 40
                horizontalAlignment: Text.AlignHCenter
                text: (tel.imp.non_disturbare ? I18n.t("Non disturbare attivo") : I18n.t("Nessuna notifica")).toUpperCase()
                color: tel.pal.testo2; font.family: tel.fontMono; font.pixelSize: tel.px(12); font.letterSpacing: 0.6
            }
        }
    }
}
