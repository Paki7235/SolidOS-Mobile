// App Impostazioni del telefono: elenco a sezioni, ogni voce apre la sua pagina.
// Wi-Fi, Bluetooth, Rete mobile e SIM, Suoni, Schermo, Notifiche, Batteria,
// Personalizza, Solid ID, Info sul telefono.
import QtQuick
import QtQuick.Controls
import SolidUI

Rectangle {
    id: imp
    color: tel.pal.sfondo
    property string pagina: ""          // "" = elenco principale
    readonly property color sezione: tel.pal.superficie
    readonly property color linea: tel.pal.bordo
    property var wifi: ({ acceso: false, reti: [] })
    property var bt: ({ disponibile: false, acceso: false, dispositivi: [] })
    property var trovatiBt: []
    property var mobile: ({})
    property var batteria: ({})
    property var info: ({})
    property var account: ({})
    property var voip: ({})
    property var campiSip: ({})
    property var furto: ({})
    // Le cose importanti (protezione in caso di furto): chiede il codice, poi prova l'azione
    function protetta(metodo, argomenti, dopo) {
        if (imp.codice) { chiediCodice.metodo = metodo; chiediCodice.argomenti = argomenti; chiediCodice.dopo = dopo; chiediCodice.open(); return }
        var r = ponte.chiama(metodo, argomenti.concat([""]))
        if (r.messaggio) tel.avviso(r.messaggio)
        if (dopo) dopo(r)
    }        // quello che si scrive nei campi dell'account SIP
    property int volume: 50
    property int luce: 70
    property bool codice: false         // c'è un codice di sblocco

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
        else if (p === "sicurezza") { codice = ponte.chiama0("haCodice"); furto = ponte.chiama0("protezioneFurto") }
        else if (p === "chiamate") { voip = ponte.chiama0("voipAccount"); campiSip = { nome: voip.nome || "", utente: voip.utente || "", dominio: voip.dominio || "", server: voip.server || "", password: "" } }
    }
    function riepilogo() {
        wifi = ponte.chiama0("wifiStato")
        bt = ponte.chiama0("btStato")
        mobile = ponte.chiama0("reteMobile")
        batteria = ponte.chiama0("batteriaInfo")
        account = ponte.chiama0("solidId")
        codice = ponte.chiama0("haCodice")
        voip = ponte.chiama0("voipAccount")
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
        // Colore del quadratino secondo l'argomento (come sul PC)
        // Colori dei quadratini: quelli di Aurora, oppure la tavolozza piena di Prisma
        readonly property var tavolozza: tel.solido
            ? ({ "network-wireless-symbolic": "#59C3FF", "bluetooth-active-symbolic": "#59C3FF", "network-cellular-symbolic": "#C6F432", "call-start-symbolic": "#C6F432",
                 "audio-volume-high-symbolic": "#FF6B4A", "preferences-system-notifications-symbolic": "#FF6B4A", "display-brightness-symbolic": "#FFD84A",
                 "preferences-desktop-wallpaper-symbolic": "#8B6CFF", "battery-good-symbolic": "#C6F432", "system-lock-screen-symbolic": "#FF6B4A",
                 "help-about-symbolic": "#D9D4CA", "avatar-default-symbolic": "#D9D4CA" })
            : ({ "network-wireless-symbolic": "#3B82F6", "bluetooth-active-symbolic": "#3B82F6", "network-cellular-symbolic": "#22C55E", "call-start-symbolic": "#22C55E",
                 "audio-volume-high-symbolic": "#F43F5E", "preferences-system-notifications-symbolic": "#F43F5E", "display-brightness-symbolic": "#3B82F6",
                 "preferences-desktop-wallpaper-symbolic": "#8B6CFF", "battery-good-symbolic": "#22C55E", "system-lock-screen-symbolic": "#F43F5E",
                 "help-about-symbolic": "#71717A", "avatar-default-symbolic": "#71717A" })
        property color coloreIcona: tavolozza[icona] || (tel.solido ? "#D9D4CA" : "#71717A")
        // Sui colori chiari di Prisma il simbolo è scuro
        readonly property bool iconaScura: tel.solido && ["#59C3FF", "#C6F432", "#FFD84A", "#D9D4CA"].indexOf(coloreIcona.toString().toUpperCase()) >= 0
        property string titolo: ""
        property color coloreTitolo: tel.pal.testo
        property string valore: ""
        property bool freccia: true
        property bool ultima: false
        property bool interruttore: false
        property bool acceso: false
        property int segnale: -1          // Wi-Fi: tacche disegnate (0-100), -1 = niente
        property bool lucchetto: false
        signal scelta()
        signal cambiato(bool si)
        width: parent ? parent.width : 300; height: 58
        // Icona bianca in un quadratino colorato, come nelle Impostazioni del PC
        Rectangle {
            visible: r.icona !== ""
            x: 14; anchors.verticalCenter: parent.verticalCenter
            width: 32; height: 32; radius: tel.solido ? 11 : 9; color: r.coloreIcona
            Icona { anchors.centerIn: parent; nome: r.icona; lato: 18; tema: r.iconaScura ? "chiaro" : "scuro" }
        }
        Text { x: r.icona !== "" ? 60 : 16; anchors.verticalCenter: parent.verticalCenter; text: r.titolo; color: r.coloreTitolo; font.family: Tema.font; font.pixelSize: tel.px(16) }
        Text {
            anchors.right: parent.right; anchors.rightMargin: r.freccia ? 34 : 16; anchors.verticalCenter: parent.verticalCenter
            visible: !r.interruttore
            width: Math.min(implicitWidth, parent.width * 0.45); elide: Text.ElideRight; horizontalAlignment: Text.AlignRight
            text: r.valore; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12)
        }
        Text { visible: r.freccia && !r.interruttore; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: "›"; color: tel.pal.testo2; font.pixelSize: 24 }
        Row {
            visible: r.segnale >= 0
            anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Item {
                visible: r.lucchetto
                width: 10; height: 13; anchors.verticalCenter: parent.verticalCenter
                Rectangle { x: 2; width: 6; height: 8; radius: 3; color: "transparent"; border.color: tel.pal.testo2; border.width: 1.6 }
                Rectangle { y: 5; width: 10; height: 8; radius: 2; color: tel.pal.testo2 }
            }
            Row {
                spacing: 2; anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        anchors.bottom: parent.bottom
                        width: 4; height: 5 + index * 3; radius: 1
                        color: r.segnale >= [1, 25, 45, 70][index] ? tel.pal.testo : tel.pal.traccia
                    }
                }
            }
        }
        Rectangle {
            visible: r.interruttore
            anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
            width: 50; height: 30; radius: 15
            color: r.acceso ? tel.pal.pieno : tel.pal.superficie2
            border.width: 1; border.color: r.acceso ? tel.pal.pieno : tel.pal.bordo
            Behavior on color { ColorAnimation { duration: tel.tVeloce } }
            Rectangle { width: 22; height: 22; radius: 11; y: 4; x: r.acceso ? 24 : 4; color: "#FFFFFF"
                        Behavior on x { NumberAnimation { duration: tel.tNormale; easing.type: Easing.OutQuint } } }
        }
        Rectangle { visible: !r.ultima; anchors.bottom: parent.bottom; x: r.icona !== "" ? 60 : 16; width: parent.width - x; height: 1; color: imp.linea }
        MouseArea { anchors.fill: parent; onClicked: r.interruttore ? r.cambiato(!r.acceso) : r.scelta() }
    }
    component Titoletto: Text {
        x: 32; topPadding: 18; bottomPadding: 8
        color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(11); font.letterSpacing: 0.6
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
        width: parent ? parent.width - 28 : 300; x: 14; height: 48; radius: 24
        color: tel.pal.superficie2
        clip: true
        Rectangle { width: Math.max(48, parent.width * cur.valore / 100); height: parent.height; radius: 24; color: tel.pal.pieno }
        Icona { x: 14; anchors.verticalCenter: parent.verticalCenter; nome: cur.icona; lato: 20; tema: tel.chiaro ? "scuro" : "chiaro" }
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
        text: "‹ " + I18n.t("Impostazioni"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16)
        MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: { imp.pagina = ""; imp.riepilogo() } }
    }
    Text {
        x: 20; y: imp.pagina === "" ? 60 : 86
        text: ({ "": I18n.t("Impostazioni"), wifi: "Wi-Fi", bluetooth: "Bluetooth", rete: I18n.t("Rete mobile"), suoni: I18n.t("Suoni e vibrazione"),
                 schermo: I18n.t("Schermo"), notifiche: I18n.t("Notifiche"), batteria: I18n.t("Batteria"), solidid: "Solid ID", chiamate: I18n.t("Chiamate via Internet"), sicurezza: I18n.t("Codice di sblocco"), info: I18n.t("Info sul telefono") })[imp.pagina]
        color: tel.pal.testo; font.family: Tema.font; font.pixelSize: imp.pagina === "" ? 32 : 28; font.weight: Font.Bold; font.letterSpacing: -0.6
        width: parent.width - 40; elide: Text.ElideRight
    }

    Flickable {
        id: scorri
        anchors.fill: parent
        anchors.topMargin: imp.pagina === "" ? 114 : 134
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
                        icona: "avatar-default-symbolic"; ultima: true
                        titolo: imp.account.collegato ? (imp.account.nome || imp.account.email) : I18n.t("Accedi al Solid ID")
                        valore: imp.account.collegato ? "Solid ID" : ""
                        onScelta: imp.apri("solidid")
                    }
                }
                Gruppo {
                    Riga { icona: "network-wireless-symbolic"; titolo: "Wi-Fi"; valore: !imp.wifi.acceso ? I18n.t("No") : ((imp.wifi.reti || []).filter(function (x) { return x.connessa }).map(function (x) { return x.ssid })[0] || I18n.t("Non connesso")); onScelta: imp.apri("wifi") }
                    Riga { icona: "bluetooth-active-symbolic"; titolo: "Bluetooth"; valore: !imp.bt.disponibile ? I18n.t("Assente") : (imp.bt.acceso ? I18n.t("Sì") : I18n.t("No")); onScelta: imp.apri("bluetooth") }
                    Riga { icona: "network-cellular-symbolic"; titolo: I18n.t("Rete mobile"); valore: imp.mobile.sim ? (imp.mobile.operatore || "SIM") : I18n.t("Nessuna SIM"); onScelta: imp.apri("rete") }
                    Riga { icona: "call-start-symbolic"; titolo: I18n.t("Chiamate via Internet"); ultima: true; onScelta: imp.apri("chiamate")
                           valore: !imp.voip.attivo ? I18n.t("No") : (imp.voip.registrato ? I18n.t("Collegate") : I18n.t("Non collegate")) }
                }
                Gruppo {
                    Riga { icona: "audio-volume-high-symbolic"; titolo: I18n.t("Suoni e vibrazione"); onScelta: imp.apri("suoni") }
                    Riga { icona: "preferences-system-notifications-symbolic"; titolo: I18n.t("Notifiche"); valore: tel.imp.non_disturbare ? I18n.t("Non disturbare") : ""; onScelta: imp.apri("notifiche") }
                    Riga { icona: "display-brightness-symbolic"; titolo: I18n.t("Schermo"); onScelta: imp.apri("schermo") }
                    Riga { icona: "preferences-desktop-wallpaper-symbolic"; titolo: I18n.t("Aspetto"); ultima: true; onScelta: tel.personalizza = true }
                }
                Gruppo {
                    Riga { icona: "battery-good-symbolic"; titolo: I18n.t("Batteria"); valore: (imp.batteria.livello || 0) + "%"; onScelta: imp.apri("batteria") }
                    Riga { icona: "system-lock-screen-symbolic"; titolo: I18n.t("Codice di sblocco"); valore: imp.codice ? I18n.t("Sì") : I18n.t("No"); onScelta: imp.apri("sicurezza") }
                    Riga { icona: "help-about-symbolic"; titolo: I18n.t("Info sul telefono"); ultima: true; onScelta: imp.apri("info") }
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
                            segnale: modelData.segnale; lucchetto: modelData.protetta
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
                            icona: modelData.tipo || "bluetooth-active-symbolic"
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
                            icona: modelData.tipo || "bluetooth-active-symbolic"
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

            // ══ Chiamate via Internet (SIP) ══════════════════════════════
            Column {
                visible: imp.pagina === "chiamate"
                width: parent.width
                Gruppo {
                    Riga { titolo: I18n.t("Chiamate via Internet"); interruttore: true; acceso: imp.voip.attivo === true; freccia: false
                           onCambiato: function (si) { var r = ponte.chiama("voipSalva", [imp.campiSip.utente || imp.voip.utente || "", imp.campiSip.password || "", imp.campiSip.dominio || imp.voip.dominio || "", imp.campiSip.server || "", imp.campiSip.nome || "", si]); tel.avviso(r.messaggio); imp.voip = ponte.chiama0("voipAccount") } }
                    Riga { titolo: I18n.t("Stato"); freccia: false; ultima: true
                           valore: !imp.voip.attivo ? I18n.t("Spente") : imp.voip.registrato ? "● " + I18n.t("Collegate") : (imp.voip.errore || I18n.t("Mi collego…")) }
                }
                Nota { text: I18n.t("Chiami e ricevi chiamate con Internet (Wi-Fi o dati), anche senza SIM. Ti serve un account SIP: te lo dà un operatore VoIP (con un numero di telefono vero, per chiamare fissi e cellulari) oppure il centralino di casa o dell'ufficio.") }
                Titoletto { text: I18n.t("ACCOUNT SIP") }
                Gruppo {
                    Repeater {
                        model: [{ id: "nome", e: I18n.t("Nome mostrato"), s: I18n.t("es. Pasquale") }, { id: "utente", e: I18n.t("Utente o numero"), s: "0812345678" },
                                { id: "password", e: I18n.t("Password"), s: imp.voip.haPassword ? I18n.t("(salvata, lascia vuoto)") : "" },
                                { id: "dominio", e: I18n.t("Dominio"), s: "sip.operatore.it" }, { id: "server", e: I18n.t("Server (se diverso)"), s: I18n.t("facoltativo") }]
                        Item {
                            id: campoSip
                            required property var modelData
                            required property int index
                            width: parent.width; height: 58
                            Text { x: 16; y: 8; text: campoSip.modelData.e; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(12) }
                            TextField {
                                x: 10; y: 22; width: parent.width - 20; height: 34
                                text: campoSip.modelData.id === "password" ? "" : (imp.voip[campoSip.modelData.id] || "")
                                onTextChanged: imp.campiSip[campoSip.modelData.id] = text
                                echoMode: campoSip.modelData.id === "password" ? TextInput.Password : TextInput.Normal
                                inputMethodHints: campoSip.modelData.id === "dominio" || campoSip.modelData.id === "server" ? Qt.ImhUrlCharactersOnly : Qt.ImhNoAutoUppercase
                                color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16)
                                placeholderText: campoSip.modelData.s; placeholderTextColor: tel.pal.testo3
                                background: Item {}
                            }
                            Rectangle { visible: campoSip.index < 4; anchors.bottom: parent.bottom; x: 16; width: parent.width - 16; height: 1; color: imp.linea }
                        }
                    }
                }
                Item { width: 1; height: 14 }
                Rectangle {
                    x: 16; width: imp.width - 32; height: 48; radius: 24; color: tel.accento
                    Text { anchors.centerIn: parent; text: I18n.t("Salva e collega"); color: "#FFFFFF"; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.DemiBold }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            var c = imp.campiSip
                            var r = ponte.chiama("voipSalva", [c.utente || "", c.password || "", c.dominio || "", c.server || "", c.nome || "", true])
                            tel.avviso(r.messaggio)
                            imp.voip = ponte.chiama0("voipAccount"); aggiornaVoip.start()
                        }
                    }
                }
                Timer { id: aggiornaVoip; interval: 2000; repeat: true; running: imp.pagina === "chiamate" && imp.voip.attivo === true && !imp.voip.registrato; onTriggered: imp.voip = ponte.chiama0("voipAccount") }
                Nota { text: I18n.t("Con la SIM le chiamate passano dalla SIM; senza SIM passano da Internet. Si possono chiamare anche indirizzi SIP (nome@dominio).") }
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
                    Riga { titolo: I18n.t("Veste"); valore: ({ aurora: "Aurora", prisma: "Prisma", notte: "Prisma Notte", auto: I18n.t("Automatica") })[tel.vesteScelta]; onScelta: tel.personalizza = true }
                    Riga { titolo: I18n.t("Grandezza del testo"); valore: [I18n.t("Piccolo"), I18n.t("Normale"), I18n.t("Grande")][tel.imp.testo]; onScelta: tel.imposta("testo", (tel.imp.testo + 1) % 3) }
                    Riga { titolo: I18n.t("Icone, colore e sfondo"); ultima: true; onScelta: tel.personalizza = true }
                }
                Titoletto { text: I18n.t("Blocco") }
                Gruppo {
                    Riga { titolo: I18n.t("Blocco automatico"); valore: tel.imp.blocco_auto === 0 ? I18n.t("Mai") : tel.imp.blocco_auto + " min"
                        onScelta: { var v = [1, 2, 5, 10, 0]; tel.imposta("blocco_auto", v[(v.indexOf(tel.imp.blocco_auto) + 1) % v.length]) } }
                    Riga { titolo: I18n.t("Schermo sempre acceso"); interruttore: true; acceso: tel.imp.sempre_acceso === true; freccia: false; onCambiato: function (si) { tel.imposta("sempre_acceso", si) } }
                    Riga { titolo: I18n.t("Riduci animazioni"); interruttore: true; acceso: tel.imp.riduci_movimento === true; freccia: false; ultima: true; onCambiato: function (si) { tel.imposta("riduci_movimento", si) } }
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
                    Text { anchors.horizontalCenter: parent.horizontalCenter; y: 6; text: (imp.batteria.livello || 0) + "%"; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: 56; font.weight: Font.DemiBold }
                    BarraPunti {
                        anchors.horizontalCenter: parent.horizontalCenter; y: 72
                        width: imp.width - 64; height: 24; righe: 3
                        valore: imp.batteria.livello || 0
                        acceso: (imp.batteria.livello || 0) <= 20 ? tel.rosso : tel.pal.testo
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
            // Senza accesso: Accedi / Crea account. Con l'accesso: account, Dov'è, dispositivi, Esci.
            Column {
                id: paginaSid
                visible: imp.pagina === "solidid"
                width: parent.width
                property string modo: "accedi"        // accedi | crea
                property bool inCorso: false
                property string esito: ""
                property bool errore: false
                property var dispositivi: []
                function fatto(r) {
                    inCorso = false; esito = r.messaggio || ""; errore = !r.ok
                    imp.account = ponte.chiama0("solidId")
                    if (imp.account.collegato) ponte.avvia("sidDispositivi", [], "imp-sid-disp")
                }
                Connections {
                    target: ponte
                    function onCompletato(id, r) {
                        if (id === "imp-sid") paginaSid.fatto(r)
                        else if (id === "imp-sid-disp") paginaSid.dispositivi = r.dispositivi || []
                    }
                }
                onVisibleChanged: if (visible && imp.account.collegato) ponte.avvia("sidDispositivi", [], "imp-sid-disp")

                // ── Accesso o nuovo account ──────────────────────────────
                Column {
                    visible: !imp.account.collegato
                    width: parent.width
                    spacing: 0
                    Item {
                        width: parent.width; height: 110
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter; y: 6
                            width: 70; height: 70; radius: 35; color: tel.pal.superficie2
                            Icona { anchors.centerIn: parent; nome: "avatar-default-symbolic"; lato: 32 }
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; y: 84; text: paginaSid.modo === "accedi" ? I18n.t("Accedi al Solid ID") : I18n.t("Crea il tuo Solid ID"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(18); font.weight: Font.Bold }
                    }
                    Gruppo {
                        Item {
                            visible: paginaSid.modo === "crea"
                            width: parent.width; height: visible ? 54 : 0
                            TextField { id: sidNome; x: 16; width: parent.width - 32; anchors.verticalCenter: parent.verticalCenter; placeholderText: I18n.t("Nome"); placeholderTextColor: tel.pal.testo2; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); background: Item {} }
                            Rectangle { anchors.bottom: parent.bottom; x: 16; width: parent.width - 16; height: 1; color: imp.linea }
                        }
                        Item {
                            width: parent.width; height: 54
                            TextField { id: sidEmail; x: 16; width: parent.width - 32; anchors.verticalCenter: parent.verticalCenter; placeholderText: I18n.t("Email"); placeholderTextColor: tel.pal.testo2; inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoAutoUppercase; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); background: Item {} }
                            Rectangle { anchors.bottom: parent.bottom; x: 16; width: parent.width - 16; height: 1; color: imp.linea }
                        }
                        Item {
                            width: parent.width; height: 54
                            TextField { id: sidPw; x: 16; width: parent.width - 32; anchors.verticalCenter: parent.verticalCenter; echoMode: TextInput.Password; placeholderText: paginaSid.modo === "crea" ? I18n.t("Password (almeno 8 caratteri)") : I18n.t("Password"); placeholderTextColor: tel.pal.testo2; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); onAccepted: vaiSid.premi(); background: Item {} }
                        }
                    }
                    Text { visible: paginaSid.esito !== ""; x: 32; width: imp.width - 64; topPadding: 10; wrapMode: Text.Wrap; text: paginaSid.esito; color: paginaSid.errore ? tel.rosso : tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(13) }
                    Item { width: 1; height: 14 }
                    Rectangle {
                        id: vaiSid
                        function premi() {
                            if (paginaSid.inCorso || !sidEmail.text || !sidPw.text) return
                            paginaSid.inCorso = true; paginaSid.esito = ""
                            if (paginaSid.modo === "accedi") ponte.avvia("sidAccedi", [sidEmail.text, sidPw.text], "imp-sid")
                            else ponte.avvia("sidCrea", [sidNome.text, sidEmail.text, sidPw.text], "imp-sid")
                        }
                        x: 16; width: imp.width - 32; height: 52; radius: 26
                        color: tel.pal.pieno; opacity: sidEmail.text && sidPw.text ? 1 : 0.4
                        Text { anchors.centerIn: parent; text: paginaSid.inCorso ? I18n.t("Attendi…") : (paginaSid.modo === "accedi" ? I18n.t("Accedi") : I18n.t("Crea Solid ID")); color: tel.pal.suPieno; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.DemiBold }
                        MouseArea { anchors.fill: parent; onClicked: vaiSid.premi() }
                    }
                    Item { width: 1; height: 10 }
                    Gruppo {
                        Riga { titolo: paginaSid.modo === "accedi" ? I18n.t("Non hai un Solid ID? Creane uno") : I18n.t("Hai già un Solid ID? Accedi"); onScelta: { paginaSid.modo = paginaSid.modo === "accedi" ? "crea" : "accedi"; paginaSid.esito = "" } }
                        Riga { visible: paginaSid.modo === "accedi"; titolo: I18n.t("Password dimenticata?")
                            onScelta: { if (!sidEmail.text) { paginaSid.esito = I18n.t("Scrivi prima la tua email"); paginaSid.errore = true } else { paginaSid.inCorso = true; ponte.avvia("sidPassword", [sidEmail.text], "imp-sid") } } }
                        Riga { titolo: I18n.t("Reinvia l'email di conferma"); ultima: true
                            onScelta: { if (!sidEmail.text) { paginaSid.esito = I18n.t("Scrivi prima la tua email"); paginaSid.errore = true } else { paginaSid.inCorso = true; ponte.avvia("sidReinvia", [sidEmail.text], "imp-sid") } } }
                    }
                    Nota { text: I18n.t("Usa lo stesso Solid ID del tuo PC con SolidOS: ritrovi il telefono con «Dov'è», vedi la batteria di tutti i tuoi dispositivi e li colleghi tra loro.") }
                }

                // ── Account collegato ────────────────────────────────────
                Column {
                    visible: imp.account.collegato === true
                    width: parent.width
                    Item {
                        width: parent.width; height: 130
                        Avatar { anchors.horizontalCenter: parent.horizontalCenter; y: 4; lato: 76; nome: imp.account.nome || imp.account.email || "?" }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; y: 88; text: imp.account.nome || ""; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(20); font.weight: Font.Bold }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; y: 112; text: imp.account.email || ""; color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13) }
                    }
                    Gruppo {
                        Riga { titolo: I18n.t("Dov'è"); interruttore: true; acceso: imp.account.trova === true; freccia: false; ultima: true
                            onCambiato: function (si) { imp.protetta("sidTrova", [si], function () { imp.account = ponte.chiama0("solidId") }) } }
                    }
                    Nota { text: I18n.t("Con «Dov'è» attivo ritrovi il telefono sulla mappa dal PC, lo fai suonare o lo blocchi con un messaggio. La posizione arriva dal GPS o dalle reti Wi-Fi vicine.") }
                    Titoletto { text: I18n.t("I tuoi dispositivi") }
                    Gruppo {
                        Repeater {
                            model: paginaSid.dispositivi
                            Riga {
                                required property var modelData
                                required property int index
                                icona: modelData.tipo === "telefono" ? "phone-symbolic" : (modelData.tipo === "portatile" ? "computer-laptop-symbolic" : "computer-symbolic")
                                coloreIcona: modelData.questo ? tel.accento : "#6b7385"
                                titolo: modelData.nome + (modelData.questo ? " (" + I18n.t("questo") + ")" : "")
                                valore: modelData.batteria !== null && modelData.batteria !== undefined ? modelData.batteria + "%" : ""
                                freccia: false
                                ultima: index === paginaSid.dispositivi.length - 1
                            }
                        }
                        Riga { visible: paginaSid.dispositivi.length === 0; titolo: I18n.t("Caricamento…"); freccia: false; ultima: true }
                    }
                    Item { width: 1; height: 20 }
                    Gruppo {
                        Riga { titolo: I18n.t("Esci dal Solid ID"); freccia: false; ultima: true; onScelta: esciSid.open() }
                    }
                }
            }

            // ══ Codice di sblocco ═══════════════════════════════════════
            Column {
                visible: imp.pagina === "sicurezza"
                width: parent.width
                Gruppo {
                    Riga { visible: !imp.codice; titolo: I18n.t("Imposta un codice"); ultima: true; onScelta: codiceDlg.apri("imposta") }
                    Riga { visible: imp.codice; titolo: I18n.t("Cambia il codice"); onScelta: codiceDlg.apri("cambia") }
                    Riga { visible: imp.codice; titolo: I18n.t("Togli il codice"); ultima: true; onScelta: codiceDlg.apri("togli") }
                }
                Nota { text: I18n.t("Il codice (da 4 a 8 cifre) serve per entrare nel telefono dalla schermata di blocco. Dopo 5 tentativi sbagliati bisogna aspettare sempre di più.") }
                Titoletto { text: I18n.t("PROTEZIONE IN CASO DI FURTO") }
                Gruppo {
                    Riga {
                        titolo: I18n.t("Protezione in caso di furto"); interruttore: true; freccia: false
                        acceso: tel.imp.protezione_furto !== false
                        onCambiato: function (si) {
                            if (si) tel.imposta("protezione_furto", true)
                            else imp.protetta("disattivaProtezioneFurto", [], function () { tel.imp = ponte.chiama0("impostazioni") })
                        }
                    }
                    Riga { titolo: I18n.t("Luoghi abituali"); freccia: false; ultima: true
                           valore: (imp.furto.luoghi || []).length ? imp.furto.luoghi.slice(0, 2).join(", ") : I18n.t("Li impara da solo") }
                }
                Nota { text: I18n.t("Se qualcuno ti vede mettere il codice e ruba il telefono, non può comunque prenderti tutto. Lontano dai luoghi abituali (le reti Wi-Fi dove stai spesso), per spegnere Dov'è, uscire dal Solid ID, cambiare il codice o cancellare il telefono servono il codice e un'ora di attesa.") }
                Titoletto { text: I18n.t("SMARRITO O RUBATO") }
                Nota { text: I18n.t("Da «Dov'è» (su un altro telefono o sul PC) puoi mettere questo telefono in modalità smarrito: si sblocca solo con la password del Solid ID. Puoi anche cancellarlo a distanza: dopo, il blocco di attivazione chiede ancora il tuo Solid ID, così a chi l'ha preso non serve a niente.") }
                Item { width: 1; height: 12 }
                Gruppo {
                    Riga { titolo: I18n.t("Inizializza il telefono"); coloreTitolo: tel.rosso; freccia: false; ultima: true; onScelta: confermaReset.open() }
                }
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
                Titoletto { text: I18n.t("Aggiornamenti") }
                Gruppo {
                    Riga { titolo: I18n.t("Versione di SolidOS"); valore: imp.info.aggiornamenti && imp.info.aggiornamenti.versione ? String(imp.info.aggiornamenti.versione) : I18n.t("di prova"); freccia: false }
                    Riga { titolo: I18n.t("Ultimo controllo"); valore: imp.info.aggiornamenti && imp.info.aggiornamenti.ultimo ? imp.info.aggiornamenti.ultimo : "—"; freccia: false; ultima: true }
                }
                Nota { text: (imp.info.aggiornamenti && imp.info.aggiornamenti.esito ? imp.info.aggiornamenti.esito + ". " : "") + I18n.t("Il telefono cerca gli aggiornamenti ogni giorno e installa solo quelli firmati da SolidOS, dopo averli provati.") }
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

    // ── Uscita dal Solid ID ──────────────────────────────────────────────
    Popup {
        id: esciSid
        anchors.centerIn: parent
        width: parent.width - 60; modal: true; padding: 20
        background: Rectangle { radius: 20; color: imp.sezione }
        Column {
            width: parent.width; spacing: 14
            Text { width: parent.width; wrapMode: Text.Wrap; text: I18n.t("Uscire dal Solid ID? Il telefono non comparirà più in «Dov'è»."); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(16); font.weight: Font.DemiBold }
            Row {
                spacing: 10; anchors.right: parent.right
                Pulsante { text: I18n.t("Annulla"); onClicked: esciSid.close() }
                Pulsante { text: I18n.t("Esci"); pericoloso: true; onClicked: { esciSid.close(); imp.protetta("sidEsci", [], function () { imp.account = ponte.chiama0("solidId") }) } }
            }
        }
    }
    // ── Codice di sblocco: imposta, cambia o togli ───────────────────────
    Popup {
        id: codiceDlg
        property string modo: "imposta"
        function apri(m) { modo = m; open() }
        anchors.centerIn: parent
        width: parent.width - 40; modal: true; padding: 18
        background: Rectangle { radius: 20; color: imp.sezione }
        onOpened: { cAttuale.text = ""; cNuovo.text = ""; cRipeti.text = ""; cEsito.text = "" }
        Column {
            width: parent.width; spacing: 12
            Text { text: ({ imposta: I18n.t("Nuovo codice"), cambia: I18n.t("Cambia il codice"), togli: I18n.t("Togli il codice") })[codiceDlg.modo]; color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(17); font.weight: Font.Bold }
            CampoTesto { id: cAttuale; visible: codiceDlg.modo !== "imposta"; width: parent.width; echoMode: TextInput.Password; inputMethodHints: Qt.ImhDigitsOnly; placeholderText: I18n.t("Codice attuale") }
            CampoTesto { id: cNuovo; visible: codiceDlg.modo !== "togli"; width: parent.width; echoMode: TextInput.Password; inputMethodHints: Qt.ImhDigitsOnly; placeholderText: I18n.t("Nuovo codice (4-8 cifre)") }
            CampoTesto { id: cRipeti; visible: codiceDlg.modo !== "togli"; width: parent.width; echoMode: TextInput.Password; inputMethodHints: Qt.ImhDigitsOnly; placeholderText: I18n.t("Ripeti il nuovo codice") }
            Text { id: cEsito; visible: text !== ""; width: parent.width; wrapMode: Text.Wrap; color: tel.rosso; font.family: Tema.font; font.pixelSize: tel.px(13) }
            Row {
                spacing: 10; anchors.right: parent.right
                Pulsante { text: I18n.t("Annulla"); onClicked: codiceDlg.close() }
                Pulsante {
                    text: codiceDlg.modo === "togli" ? I18n.t("Togli") : I18n.t("Salva")
                    principale: codiceDlg.modo !== "togli"; pericoloso: codiceDlg.modo === "togli"
                    onClicked: {
                        if (codiceDlg.modo !== "togli" && cNuovo.text !== cRipeti.text) { cEsito.text = I18n.t("I due codici non sono uguali"); return }
                        var r = ponte.chiama("impostaCodice", [cAttuale.text, codiceDlg.modo === "togli" ? "" : cNuovo.text])
                        if (!r.ok) { cEsito.text = r.messaggio; return }
                        tel.avviso(r.messaggio); codiceDlg.close(); imp.codice = ponte.chiama0("haCodice")
                    }
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
        color: tel.pal.pieno
        Text { id: testoAttesa; anchors.centerIn: parent; text: I18n.t("Connessione in corso…"); color: tel.pal.suPieno; font.family: Tema.font; font.pixelSize: tel.px(14); font.weight: Font.DemiBold }
    }

    // ── Codice per le cose importanti ────────────────────────────────────
    Popup {
        id: chiediCodice
        property string metodo: ""
        property var argomenti: []
        property var dopo: null
        anchors.centerIn: parent
        width: parent.width - 40; modal: true; padding: 18
        background: Rectangle { radius: 20; color: imp.sezione }
        onOpened: { campoProtetto.text = ""; erroreProtetto.text = ""; campoProtetto.forceActiveFocus() }
        Column {
            width: parent.width; spacing: 12
            Text { text: I18n.t("Inserisci il codice"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(17); font.weight: Font.Bold }
            CampoTesto { id: campoProtetto; width: parent.width; echoMode: TextInput.Password; inputMethodHints: Qt.ImhDigitsOnly; onAccepted: okProtetto.clicked() }
            Text { id: erroreProtetto; width: parent.width; wrapMode: Text.Wrap; visible: text !== ""; color: tel.rosso; font.family: Tema.font; font.pixelSize: tel.px(13) }
            Row {
                spacing: 10; anchors.right: parent.right
                Pulsante { text: I18n.t("Annulla"); onClicked: { chiediCodice.close(); if (chiediCodice.dopo) chiediCodice.dopo({ ok: false }) } }
                Pulsante {
                    id: okProtetto
                    text: I18n.t("Continua"); principale: true
                    onClicked: {
                        var r = ponte.chiama(chiediCodice.metodo, chiediCodice.argomenti.concat([campoProtetto.text]))
                        campoProtetto.text = ""
                        if (r.chiediCodice) { erroreProtetto.text = r.messaggio; return }
                        chiediCodice.close()
                        if (r.messaggio) tel.avviso(r.messaggio)
                        if (chiediCodice.dopo) chiediCodice.dopo(r)
                    }
                }
            }
        }
    }
    // ── Inizializza il telefono ──────────────────────────────────────────
    Popup {
        id: confermaReset
        anchors.centerIn: parent
        width: parent.width - 40; modal: true; padding: 18
        background: Rectangle { radius: 20; color: imp.sezione }
        Column {
            width: parent.width; spacing: 12
            Text { text: I18n.t("Inizializzare il telefono?"); color: tel.pal.testo; font.family: Tema.font; font.pixelSize: tel.px(17); font.weight: Font.Bold }
            Text { width: parent.width; wrapMode: Text.Wrap; text: I18n.t("Si cancellano foto, file, contatti, messaggi, app e impostazioni. Non si può tornare indietro. Il blocco di attivazione resta: per riusarlo servirà il tuo Solid ID."); color: tel.pal.testo2; font.family: Tema.font; font.pixelSize: tel.px(13) }
            Row {
                spacing: 10; anchors.right: parent.right
                Pulsante { text: I18n.t("Annulla"); onClicked: confermaReset.close() }
                Pulsante { text: I18n.t("Cancella tutto"); pericoloso: true; onClicked: { confermaReset.close(); imp.protetta("inizializzaDaImpostazioni", [], null) } }
            }
        }
    }
}
