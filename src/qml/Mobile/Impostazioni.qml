// App Impostazioni del telefono: elenco a sezioni, ogni voce apre la sua pagina.
// Wi-Fi, Bluetooth, Rete mobile e SIM, Suoni, Schermo, Notifiche, Batteria,
// Personalizza, Solid ID, Info sul telefono.
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: imp
    color: tel.chiaro ? "#f2f3f8" : "#0e1118"
    property string pagina: ""          // "" = elenco principale
    readonly property color sezione: tel.chiaro ? "#ffffff" : "#1b1f2b"
    readonly property color linea: tel.chiaro ? Qt.rgba(0, 0, 0, 0.07) : Qt.rgba(1, 1, 1, 0.07)
    property var wifi: ({ acceso: false, reti: [] })
    property var bt: ({ disponibile: false, acceso: false, dispositivi: [] })
    property var trovatiBt: []
    property var mobile: ({})
    property var batteria: ({})
    property var info: ({})
    property var account: ({})
    property int volume: 50
    property int luce: 70

    function apri(p) {
        pagina = p
        if (p === "wifi") ponte.avvia("wifiStato", [true], "imp-wifi")
        else if (p === "bluetooth") bt = ponte.chiama0("btStato")
        else if (p === "rete") mobile = ponte.chiama0("reteMobile")
        else if (p === "suoni") volume = ponte.chiama0("volumeSuoni")
        else if (p === "schermo") luce = ponte.chiama0("luminosita")
        else if (p === "batteria") batteria = ponte.chiama0("batteriaInfo")
        else if (p === "info") info = ponte.chiama0("infoTelefono")
        else if (p === "solidid") account = ponte.chiama0("solidId")
    }
    function riepilogo() {
        wifi = ponte.chiama0("wifiStato")
        bt = ponte.chiama0("btStato")
        mobile = ponte.chiama0("reteMobile")
        batteria = ponte.chiama0("batteriaInfo")
        account = ponte.chiama0("solidId")
    }
    onVisibleChanged: if (visible) riepilogo()
    Component.onCompleted: riepilogo()
    Connections {
        target: ponte
        function onCompletato(id, r) {
            if (id === "imp-wifi") imp.wifi = r
            else if (id === "imp-bt-cerca") { imp.trovatiBt = r; cercaBt.attivo = false }
            else if (id === "imp-wifi-connetti") { attesa.visible = false; tel.avviso(r.messaggio); ponte.avvia("wifiStato", [false], "imp-wifi") }
        }
    }

    // ── Componenti ───────────────────────────────────────────────────────
    component Gruppo: Rectangle {
        default property alias righe: colonna.data
        width: imp.width - 32; x: 16
        height: colonna.implicitHeight
        radius: 16
        color: imp.sezione
        Column { id: colonna; width: parent.width }
    }
    component Riga: Item {
        id: r
        property string icona: ""
        property color coloreIcona: tel.accento
        property string titolo: ""
        property string valore: ""
        property bool freccia: true
        property bool ultima: false
        property bool interruttore: false
        property bool acceso: false
        signal scelta()
        signal cambiato(bool si)
        width: parent ? parent.width : 300; height: 54
        Rectangle {
            visible: r.icona !== ""
            x: 14; anchors.verticalCenter: parent.verticalCenter
            width: 30; height: 30; radius: 8; color: r.coloreIcona
            Icona { anchors.centerIn: parent; nome: r.icona; lato: 18 }
        }
        Text { x: r.icona !== "" ? 56 : 16; anchors.verticalCenter: parent.verticalCenter; text: r.titolo; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16) }
        Text {
            anchors.right: parent.right; anchors.rightMargin: r.freccia ? 34 : 16; anchors.verticalCenter: parent.verticalCenter
            visible: !r.interruttore
            width: Math.min(implicitWidth, parent.width * 0.45); elide: Text.ElideRight; horizontalAlignment: Text.AlignRight
            text: r.valore; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(15)
        }
        Text { visible: r.freccia && !r.interruttore; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: "›"; color: tel.pal.testo2; font.pixelSize: 24 }
        Rectangle {
            visible: r.interruttore
            anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
            width: 50; height: 30; radius: 15
            color: r.acceso ? "#22c55e" : (tel.chiaro ? "#d4d8e4" : "#3a4050")
            Rectangle { width: 26; height: 26; radius: 13; y: 2; x: r.acceso ? 22 : 2; color: "#ffffff"; Behavior on x { NumberAnimation { duration: 120 } } }
        }
        Rectangle { visible: !r.ultima; anchors.bottom: parent.bottom; x: r.icona !== "" ? 56 : 16; width: parent.width - x; height: 1; color: imp.linea }
        MouseArea { anchors.fill: parent; onClicked: r.interruttore ? r.cambiato(!r.acceso) : r.scelta() }
    }
    component Titoletto: Text {
        x: 32; topPadding: 18; bottomPadding: 6
        color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13); font.weight: Font.DemiBold
    }
    component Nota: Text {
        x: 32; width: imp.width - 64; topPadding: 6
        wrapMode: Text.Wrap
        color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12)
    }
    component Livello: Rectangle {
        id: cur
        property int valore: 50
        property string icona: ""
        signal mosso(int v)
        width: parent ? parent.width - 28 : 300; x: 14; height: 44; radius: 12
        color: tel.pal.traccia
        clip: true
        Rectangle { width: parent.width * cur.valore / 100; height: parent.height; radius: 12; color: tel.accento }
        Icona { x: 12; anchors.verticalCenter: parent.verticalCenter; nome: cur.icona; lato: 20 }
        MouseArea {
            anchors.fill: parent
            function muovi(x) { var v = Math.max(0, Math.min(100, Math.round(x / width * 100))); cur.valore = v; cur.mosso(v) }
            onPressed: function (e) { muovi(e.x) }
            onPositionChanged: function (e) { muovi(e.x) }
        }
    }

    // ── Intestazione ─────────────────────────────────────────────────────
    Text {
        visible: imp.pagina !== ""
        x: 18; y: 58
        text: "‹ " + I18n.t("Impostazioni"); color: tel.accento; font.family: Tema.font; font.pixelSize: tel.px(16)
        MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: { imp.pagina = ""; imp.riepilogo() } }
    }
    Text {
        x: 20; y: imp.pagina === "" ? 56 : 84
        text: ({ "": I18n.t("Impostazioni"), wifi: "Wi-Fi", bluetooth: "Bluetooth", rete: I18n.t("Rete mobile"), suoni: I18n.t("Suoni e vibrazione"),
                 schermo: I18n.t("Schermo"), notifiche: I18n.t("Notifiche"), batteria: I18n.t("Batteria"), solidid: "Solid ID", info: I18n.t("Info sul telefono") })[imp.pagina]
        color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(imp.pagina === "" ? 30 : 26); font.weight: Font.Bold
    }

    Flickable {
        id: scorri
        anchors.fill: parent
        anchors.topMargin: imp.pagina === "" ? 104 : 128
        anchors.bottomMargin: 26
        contentHeight: contenuto.height + 30
        clip: true
        Column {
            id: contenuto
            width: imp.width

            // ══ Elenco principale ════════════════════════════════════════
            Column {
                visible: imp.pagina === ""
                width: parent.width; spacing: 16
                Gruppo {
                    Riga {
                        icona: "avatar-default-symbolic"; coloreIcona: "#6b7385"; ultima: true
                        titolo: imp.account.collegato ? (imp.account.nome || imp.account.email) : I18n.t("Accedi al Solid ID")
                        valore: imp.account.collegato ? "Solid ID" : ""
                        onScelta: imp.apri("solidid")
                    }
                }
                Gruppo {
                    Riga { icona: "network-wireless-symbolic"; coloreIcona: "#3f7cf5"; titolo: "Wi-Fi"; valore: !imp.wifi.acceso ? I18n.t("No") : ((imp.wifi.reti || []).filter(function (x) { return x.connessa }).map(function (x) { return x.ssid })[0] || I18n.t("Non connesso")); onScelta: imp.apri("wifi") }
                    Riga { icona: "bluetooth-active-symbolic"; coloreIcona: "#3f7cf5"; titolo: "Bluetooth"; valore: !imp.bt.disponibile ? I18n.t("Assente") : (imp.bt.acceso ? I18n.t("Sì") : I18n.t("No")); onScelta: imp.apri("bluetooth") }
                    Riga { icona: "network-cellular-symbolic"; coloreIcona: "#22c55e"; titolo: I18n.t("Rete mobile"); valore: imp.mobile.sim ? (imp.mobile.operatore || "SIM") : I18n.t("Nessuna SIM"); ultima: true; onScelta: imp.apri("rete") }
                }
                Gruppo {
                    Riga { icona: "audio-volume-high-symbolic"; coloreIcona: "#ef4444"; titolo: I18n.t("Suoni e vibrazione"); onScelta: imp.apri("suoni") }
                    Riga { icona: "preferences-system-notifications-symbolic"; coloreIcona: "#ef4444"; titolo: I18n.t("Notifiche"); valore: tel.imp.non_disturbare ? I18n.t("Non disturbare") : ""; onScelta: imp.apri("notifiche") }
                    Riga { icona: "display-brightness-symbolic"; coloreIcona: "#3f7cf5"; titolo: I18n.t("Schermo"); onScelta: imp.apri("schermo") }
                    Riga { icona: "preferences-desktop-wallpaper-symbolic"; coloreIcona: "#8b5cf6"; titolo: I18n.t("Personalizza"); ultima: true; onScelta: tel.personalizza = true }
                }
                Gruppo {
                    Riga { icona: "battery-good-symbolic"; coloreIcona: "#22c55e"; titolo: I18n.t("Batteria"); valore: (imp.batteria.livello || 0) + "%"; onScelta: imp.apri("batteria") }
                    Riga { icona: "help-about-symbolic"; coloreIcona: "#6b7385"; titolo: I18n.t("Info sul telefono"); ultima: true; onScelta: imp.apri("info") }
                }
            }

            // ══ Wi-Fi ════════════════════════════════════════════════════
            Column {
                visible: imp.pagina === "wifi"
                width: parent.width
                Gruppo {
                    Riga { titolo: "Wi-Fi"; interruttore: true; acceso: imp.wifi.acceso === true; ultima: true; freccia: false
                        onCambiato: function (si) { ponte.chiama("wifiAcceso", [si]); imp.wifi = Object.assign({}, imp.wifi, { acceso: si, reti: si ? imp.wifi.reti : [] }); if (si) ponte.avvia("wifiStato", [true], "imp-wifi") } }
                }
                Titoletto { visible: imp.wifi.acceso === true; text: I18n.t("Reti") }
                Gruppo {
                    visible: imp.wifi.acceso === true
                    Repeater {
                        model: imp.wifi.reti || []
                        Riga {
                            required property var modelData
                            required property int index
                            titolo: (modelData.connessa ? "✓  " : "") + modelData.ssid
                            valore: (modelData.protetta ? "🔒 " : "") + (modelData.segnale >= 70 ? "▂▄▆█" : modelData.segnale >= 45 ? "▂▄▆" : modelData.segnale >= 25 ? "▂▄" : "▂")
                            freccia: false
                            ultima: index === (imp.wifi.reti || []).length - 1
                            onScelta: {
                                if (modelData.connessa) return
                                if (modelData.protetta) { password.ssid = modelData.ssid; password.open() }
                                else { attesa.visible = true; ponte.avvia("connettiWifi", [modelData.ssid, ""], "imp-wifi-connetti") }
                            }
                        }
                    }
                    Riga { visible: (imp.wifi.reti || []).length === 0; titolo: I18n.t("Ricerca delle reti…"); freccia: false; ultima: true }
                }
                Nota { text: I18n.t("Tocca una rete per collegarti. Il telefono si ricorda le reti e si ricollega da solo.") }
            }

            // ══ Bluetooth ════════════════════════════════════════════════
            Column {
                visible: imp.pagina === "bluetooth"
                width: parent.width
                Gruppo {
                    Riga { titolo: "Bluetooth"; interruttore: true; acceso: imp.bt.acceso === true; ultima: true; freccia: false
                        onCambiato: function (si) { ponte.chiama("btAcceso", [si]); imp.bt = ponte.chiama0("btStato") } }
                }
                Nota { visible: imp.bt.disponibile === false; text: I18n.t("Questo dispositivo non ha il Bluetooth.") }
                Titoletto { visible: imp.bt.acceso === true; text: I18n.t("I miei dispositivi") }
                Gruppo {
                    visible: imp.bt.acceso === true
                    Repeater {
                        model: imp.bt.dispositivi || []
                        Riga {
                            required property var modelData
                            required property int index
                            icona: modelData.tipo || "bluetooth-active-symbolic"; coloreIcona: "#6b7385"
                            titolo: modelData.nome; valore: modelData.connesso ? I18n.t("Connesso") : I18n.t("Non connesso")
                            ultima: index === (imp.bt.dispositivi || []).length - 1
                            onScelta: { var r = ponte.chiama("btAzione", [modelData.indirizzo, modelData.connesso ? "disconnetti" : "connetti"]); tel.avviso(r.messaggio); imp.bt = ponte.chiama0("btStato") }
                        }
                    }
                    Riga { visible: (imp.bt.dispositivi || []).length === 0; titolo: I18n.t("Nessun dispositivo associato"); freccia: false; ultima: true }
                }
                Titoletto { visible: imp.bt.acceso === true; text: I18n.t("Altri dispositivi") }
                Gruppo {
                    visible: imp.bt.acceso === true
                    Repeater {
                        model: imp.trovatiBt
                        Riga {
                            required property var modelData
                            icona: modelData.tipo || "bluetooth-active-symbolic"; coloreIcona: "#6b7385"
                            titolo: modelData.nome; valore: I18n.t("Associa")
                            onScelta: { var r = ponte.chiama("btAzione", [modelData.indirizzo, "associa"]); tel.avviso(r.messaggio); imp.bt = ponte.chiama0("btStato"); imp.trovatiBt = [] }
                        }
                    }
                    Riga {
                        id: cercaBt
                        property bool attivo: false
                        titolo: attivo ? I18n.t("Ricerca in corso…") : I18n.t("Cerca dispositivi")
                        freccia: false; ultima: true
                        onScelta: if (!attivo) { attivo = true; ponte.avvia("btCerca", [], "imp-bt-cerca") }
                    }
                }
            }

            // ══ Rete mobile ══════════════════════════════════════════════
            Column {
                visible: imp.pagina === "rete"
                width: parent.width
                Gruppo {
                    Riga { titolo: I18n.t("Operatore"); valore: imp.mobile.sim ? (imp.mobile.operatore || "—") + (imp.mobile.tecnologia ? " · " + imp.mobile.tecnologia : "") : I18n.t("Nessuna SIM"); freccia: false }
                    Riga { titolo: I18n.t("Segnale"); valore: imp.mobile.sim ? imp.mobile.segnale + "%" : "—"; freccia: false }
                    Riga { titolo: I18n.t("Numero"); valore: imp.mobile.numero || "—"; freccia: false; ultima: true }
                }
                Nota { visible: !!imp.mobile.messaggio; text: imp.mobile.messaggio || "" }
                Titoletto { text: I18n.t("Dati") }
                Gruppo {
                    Riga { titolo: I18n.t("Dati mobili"); interruttore: true; acceso: imp.mobile.dati === true; freccia: false
                        onCambiato: function (si) { var r = ponte.chiama("datiMobili", [si]); if (r.messaggio) tel.avviso(r.messaggio); imp.mobile = ponte.chiama0("reteMobile") } }
                    Riga { titolo: I18n.t("Roaming"); interruttore: true; acceso: imp.mobile.roaming === true; freccia: false; ultima: true
                        onCambiato: function (si) { tel.imposta("roaming", si); imp.mobile = ponte.chiama0("reteMobile") } }
                }
                Nota { text: I18n.t("Il roaming fuori dall'Unione Europea può costare molto: lascialo spento se non ti serve.") }
                Titoletto { text: I18n.t("Doppia SIM") }
                Gruppo {
                    Riga { titolo: I18n.t("SIM per i dati"); valore: "SIM " + (imp.mobile.simDati || "1"); freccia: false; ultima: true
                        onScelta: { tel.imposta("sim_dati", imp.mobile.simDati === "1" ? "2" : "1"); imp.mobile = ponte.chiama0("reteMobile") } }
                }
                Titoletto { text: "SIM" }
                Gruppo {
                    Riga { titolo: I18n.t("Sblocca con il PIN"); onScelta: pin.open() }
                    Riga { titolo: "IMEI"; valore: imp.mobile.imei || "—"; freccia: false; ultima: true }
                }
            }

            // ══ Suoni ════════════════════════════════════════════════════
            Column {
                visible: imp.pagina === "suoni"
                width: parent.width; spacing: 0
                Titoletto { text: I18n.t("Volume") }
                Gruppo {
                    Item { width: parent.width; height: 64; Livello { y: 10; icona: "audio-volume-high-symbolic"; valore: imp.volume; onMosso: function (v) { ponte.chiama("impostaVolumeSuoni", [v]) } } }
                }
                Titoletto { text: I18n.t("Modalità") }
                Gruppo {
                    Riga { titolo: I18n.t("Silenzioso"); interruttore: true; acceso: tel.imp.silenzioso === true; freccia: false; onCambiato: function (si) { tel.imposta("silenzioso", si) } }
                    Riga { titolo: I18n.t("Vibrazione"); interruttore: true; acceso: tel.imp.vibrazione !== false; freccia: false; onCambiato: function (si) { tel.imposta("vibrazione", si) } }
                    Riga { titolo: I18n.t("Suoneria"); valore: tel.imp.suoneria || "Alba"; ultima: true
                        onScelta: { var s = ["Alba", "Onda", "Cristallo", "Solido"]; tel.imposta("suoneria", s[(s.indexOf(tel.imp.suoneria) + 1) % s.length]) } }
                }
            }

            // ══ Schermo ══════════════════════════════════════════════════
            Column {
                visible: imp.pagina === "schermo"
                width: parent.width
                Titoletto { text: I18n.t("Luminosità") }
                Gruppo {
                    Item { width: parent.width; height: 64; Livello { y: 10; icona: "display-brightness-symbolic"; valore: imp.luce; onMosso: function (v) { ponte.chiama("impostaLuminosita", [Math.max(5, v)]) } } }
                }
                Titoletto { text: I18n.t("Aspetto") }
                Gruppo {
                    Riga { titolo: I18n.t("Tema scuro"); interruttore: true; acceso: !tel.chiaro; freccia: false; onCambiato: function (si) { tel.imposta("tema", si ? "scuro" : "chiaro") } }
                    Riga { titolo: I18n.t("Grandezza del testo"); valore: [I18n.t("Piccolo"), I18n.t("Normale"), I18n.t("Grande")][tel.imp.testo]; onScelta: tel.imposta("testo", (tel.imp.testo + 1) % 3) }
                    Riga { titolo: I18n.t("Personalizza"); ultima: true; onScelta: tel.personalizza = true }
                }
                Titoletto { text: I18n.t("Blocco") }
                Gruppo {
                    Riga { titolo: I18n.t("Blocco automatico"); valore: tel.imp.blocco_auto === 0 ? I18n.t("Mai") : tel.imp.blocco_auto + " min"
                        onScelta: { var v = [1, 2, 5, 10, 0]; tel.imposta("blocco_auto", v[(v.indexOf(tel.imp.blocco_auto) + 1) % v.length]) } }
                    Riga { titolo: I18n.t("Schermo sempre acceso"); interruttore: true; acceso: tel.imp.sempre_acceso === true; freccia: false; ultima: true; onCambiato: function (si) { tel.imposta("sempre_acceso", si) } }
                }
                Nota { text: I18n.t("Con lo schermo sempre acceso, a telefono bloccato restano visibili ora, data e notifiche con pochissimo consumo.") }
            }

            // ══ Notifiche ════════════════════════════════════════════════
            Column {
                visible: imp.pagina === "notifiche"
                width: parent.width
                Gruppo {
                    Riga { titolo: I18n.t("Non disturbare"); interruttore: true; acceso: tel.imp.non_disturbare === true; freccia: false; ultima: true; onCambiato: function (si) { tel.nonDisturbare(si) } }
                }
                Nota { text: I18n.t("Con «Non disturbare» le notifiche non suonano e non compaiono in alto: le trovi comunque nella tendina delle notifiche.") }
                Titoletto { text: I18n.t("Ricevute") }
                Gruppo {
                    Riga { titolo: I18n.t("Notifiche nella tendina"); valore: tel.elencoNotifiche.length; freccia: false }
                    Riga { titolo: I18n.t("Cancella tutte"); ultima: true; onScelta: { ponte.chiama0("svuotaNotifiche"); tel.aggiornaNotifiche(); tel.avviso(I18n.t("Notifiche cancellate")) } }
                }
            }

            // ══ Batteria ═════════════════════════════════════════════════
            Column {
                visible: imp.pagina === "batteria"
                width: parent.width
                Item {
                    width: parent.width; height: 120
                    Text { anchors.horizontalCenter: parent.horizontalCenter; y: 6; text: (imp.batteria.livello || 0) + "%"; color: tel.pal.testo; font.family: tel.fontOra; font.pixelSize: 56; font.weight: Font.Bold }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter; y: 76
                        width: imp.width - 64; height: 16; radius: 8; color: tel.pal.traccia
                        Rectangle { width: parent.width * (imp.batteria.livello || 0) / 100; height: parent.height; radius: 8; color: (imp.batteria.livello || 0) <= 20 ? "#ef4444" : "#22c55e" }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; y: 98; text: imp.batteria.stato || ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13) }
                }
                Gruppo {
                    Riga { titolo: I18n.t("Risparmio energetico"); interruttore: true; acceso: imp.batteria.risparmio === true; freccia: false
                        onCambiato: function (si) { ponte.chiama("risparmio", [si]); imp.batteria = ponte.chiama0("batteriaInfo") } }
                    Riga { titolo: I18n.t("Salute della batteria"); valore: imp.batteria.salute ? imp.batteria.salute + "%" : "—"; freccia: false; ultima: true }
                }
                Nota { text: I18n.t("Il risparmio energetico abbassa le prestazioni e le attività in background per far durare di più la batteria.") }
            }

            // ══ Solid ID ═════════════════════════════════════════════════
            Column {
                visible: imp.pagina === "solidid"
                width: parent.width
                Gruppo {
                    Riga { titolo: I18n.t("Account"); valore: imp.account.collegato ? (imp.account.email || "") : I18n.t("Non collegato"); freccia: false }
                    Riga { titolo: I18n.t("Dov'è"); valore: imp.account.collegato ? (imp.account.trova ? I18n.t("Attivo") : I18n.t("Spento")) : "—"; freccia: false; ultima: true }
                }
                Nota { text: imp.account.collegato
                             ? I18n.t("Con il Solid ID ritrovi il telefono con «Dov'è» e lo colleghi ai tuoi PC con SolidOS.")
                             : I18n.t("Accedi con lo stesso Solid ID del PC per ritrovare il telefono, vedere la batteria dei tuoi dispositivi e usare l'ecosistema. L'accesso dal telefono arriva nella prossima versione.") }
            }

            // ══ Info sul telefono ════════════════════════════════════════
            Column {
                visible: imp.pagina === "info"
                width: parent.width
                Gruppo {
                    Riga { titolo: I18n.t("Nome"); valore: imp.info.nome || ""; freccia: false }
                    Riga { titolo: I18n.t("Modello"); valore: imp.info.modello || ""; freccia: false }
                    Riga { titolo: I18n.t("Sistema"); valore: imp.info.sistema || ""; freccia: false }
                    Riga { titolo: "Kernel"; valore: imp.info.kernel || ""; freccia: false; ultima: true }
                }
                Titoletto { text: I18n.t("Memoria") }
                Gruppo {
                    Riga { titolo: "RAM"; valore: imp.info.ram || ""; freccia: false }
                    Riga { titolo: I18n.t("Spazio"); valore: imp.info.spazio || ""; freccia: false; ultima: true }
                }
                Titoletto { text: "SIM" }
                Gruppo {
                    Riga { titolo: I18n.t("Operatore"); valore: imp.info.operatore || "—"; freccia: false }
                    Riga { titolo: I18n.t("Numero"); valore: imp.info.numero || "—"; freccia: false; ultima: true }
                }
            }
        }
    }

    // ── Password del Wi-Fi ───────────────────────────────────────────────
    Popup {
        id: password
        property string ssid: ""
        anchors.centerIn: parent
        width: parent.width - 40; modal: true; padding: 18
        background: Rectangle { radius: 20; color: imp.sezione }
        onOpened: campoPw.text = ""
        Column {
            width: parent.width; spacing: 12
            Text { width: parent.width; wrapMode: Text.Wrap; text: I18n.t("Password per") + " «" + password.ssid + "»"; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(17); font.weight: Font.Bold }
            CampoTesto { id: campoPw; width: parent.width; echoMode: TextInput.Password; placeholderText: I18n.t("Password"); onAccepted: entra.clicked() }
            Row {
                spacing: 10; anchors.right: parent.right
                Pulsante { text: I18n.t("Annulla"); onClicked: password.close() }
                Pulsante { id: entra; text: I18n.t("Collegati"); principale: true; onClicked: { attesa.visible = true; ponte.avvia("connettiWifi", [password.ssid, campoPw.text], "imp-wifi-connetti"); password.close() } }
            }
        }
    }
    // ── PIN della SIM ────────────────────────────────────────────────────
    Popup {
        id: pin
        anchors.centerIn: parent
        width: parent.width - 40; modal: true; padding: 18
        background: Rectangle { radius: 20; color: imp.sezione }
        onOpened: campoPin.text = ""
        Column {
            width: parent.width; spacing: 12
            Text { text: I18n.t("PIN della SIM"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(17); font.weight: Font.Bold }
            CampoTesto { id: campoPin; width: parent.width; echoMode: TextInput.Password; inputMethodHints: Qt.ImhDigitsOnly; placeholderText: "PIN" }
            Row {
                spacing: 10; anchors.right: parent.right
                Pulsante { text: I18n.t("Annulla"); onClicked: pin.close() }
                Pulsante { text: I18n.t("Sblocca"); principale: true; onClicked: { var r = ponte.chiama("sbloccaSim", [campoPin.text]); tel.avviso(r.messaggio); if (r.ok) { pin.close(); imp.mobile = ponte.chiama0("reteMobile") } } }
            }
        }
    }
    // ── Attesa durante la connessione ────────────────────────────────────
    Rectangle {
        id: attesa
        visible: false
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 60
        width: testoAttesa.implicitWidth + 40; height: 44; radius: 22
        color: tel.chiaro ? "#0f1630" : "#f2f4f8"
        Text { id: testoAttesa; anchors.centerIn: parent; text: I18n.t("Connessione in corso…"); color: tel.chiaro ? "#ffffff" : "#0f1630"; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.DemiBold }
    }
}
