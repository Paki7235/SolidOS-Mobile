"""Telefonia di SolidOS Mobile: chiamate e SMS con ModemManager (mmcli), rubrica e registro.

ModemManager è lo standard di Linux per i modem dei telefoni (postmarketOS, Droidian,
Mobian…). Si usa il suo programma a riga di comando con l'uscita JSON (`mmcli -J`):
niente librerie in più, poca memoria.

Dati salvati in ~/.local/share/<os>/telefono/: contatti.json, registro.json, messaggi.json.

NUCLEO_DEMO=1 attiva un modem finto con dati di esempio (solo per le foto della prova).
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import threading
import time
import uuid
from pathlib import Path

from .. import branding
from ..i18n import T

DEMO = os.environ.get("NUCLEO_DEMO") == "1"
_blocco = threading.Lock()


# ── Archivio locale ──────────────────────────────────────────────────────────
def _cartella() -> Path:
    base = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / branding.id_os() / "telefono"
    base.mkdir(parents=True, exist_ok=True)
    return base


def _leggi(nome: str, predefinito):
    try:
        return json.loads((_cartella() / nome).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return predefinito


def _scrivi(nome: str, dati) -> None:
    f = _cartella() / nome
    tmp = f.with_suffix(".tmp")
    tmp.write_text(json.dumps(dati, ensure_ascii=False), encoding="utf-8")
    tmp.replace(f)


def normalizza(numero: str) -> str:
    """Numero confrontabile: solo cifre e «+»; i numeri italiani senza prefisso ricevono +39."""
    n = re.sub(r"[^\d+*#]", "", numero or "")
    if n.startswith("00"):
        n = "+" + n[2:]
    if n and not n.startswith("+") and len(n) >= 9 and n[0] in "03":
        n = "+39" + n
    return n


def _uguali(a: str, b: str) -> bool:
    a, b = normalizza(a), normalizza(b)
    return bool(a) and (a == b or a[-9:] == b[-9:])


# ── ModemManager ─────────────────────────────────────────────────────────────
def _mmcli(*argomenti: str, timeout: float = 15) -> dict:
    if not shutil.which("mmcli"):
        return {}
    try:
        r = subprocess.run(["mmcli", "-J", *argomenti], capture_output=True, text=True, timeout=timeout)
        return json.loads(r.stdout) if r.returncode == 0 and r.stdout.strip() else {}
    except (OSError, subprocess.SubprocessError, ValueError):
        return {}


def _modem() -> str:
    elenco = _mmcli("-L").get("modem-list", [])
    return elenco[0] if elenco else ""


def stato_modem() -> dict:
    if DEMO:
        return {"presente": True, "sim": True, "operatore": "TIM", "segnale": 72, "numero": "+39 333 000 0000",
                "tecnologia": "4G", "messaggio": ""}
    m = _modem()
    if not m:
        from . import voip

        v = voip.linea()
        if v.registrato:
            return {"presente": False, "sim": False, "operatore": T("Internet"), "segnale": 0, "numero": "", "tecnologia": "VoIP",
                    "internet": True, "messaggio": ""}
        return {"presente": False, "sim": False, "operatore": "", "segnale": 0, "numero": "", "tecnologia": "",
                "messaggio": T("Nessuna SIM: per chiamare attiva le chiamate via Internet in Impostazioni") if not voip.account().get("attivo")
                else (v.errore or T("Chiamate via Internet: mi collego…"))}
    info = _mmcli("-m", m).get("modem", {})
    g = info.get("generic", {})
    p3 = info.get("3gpp", {})
    sim = g.get("sim", "--") not in ("--", "")
    stato = g.get("state", "")
    tecnologie = g.get("access-technologies", [])
    tec = "5G" if "5gnr" in tecnologie else "4G" if "lte" in tecnologie else "3G" if any(x in tecnologie for x in ("umts", "hspa", "hsupa", "hsdpa")) else ("2G" if tecnologie else "")
    numeri = g.get("own-numbers", [])
    messaggio = "" if sim else T("Nessuna SIM")
    if stato == "locked":
        messaggio = T("SIM bloccata: inserisci il PIN in Impostazioni")
    return {"presente": True, "sim": sim, "operatore": p3.get("operator-name", ""), "tecnologia": tec,
            "segnale": int(str(g.get("signal-quality", {}).get("value", "0")) or 0),
            "numero": numeri[0] if numeri else "", "messaggio": messaggio}


# ── Rubrica ──────────────────────────────────────────────────────────────────
ESEMPIO_CONTATTI = [
    {"id": "1", "nome": "Mamma", "numero": "+39 333 111 2233", "preferito": True},
    {"id": "2", "nome": "Giulia Rossi", "numero": "+39 340 555 1212", "preferito": True},
    {"id": "3", "nome": "Marco Bianchi", "numero": "+39 328 777 4545", "preferito": False},
    {"id": "4", "nome": "Studio dentistico", "numero": "+39 081 555 0101", "preferito": False},
    {"id": "5", "nome": "Luca", "numero": "+39 347 222 9090", "preferito": True},
]


def contatti() -> list[dict]:
    elenco = _leggi("contatti.json", ESEMPIO_CONTATTI if DEMO else [])
    return sorted(elenco, key=lambda c: c.get("nome", "").lower())


def salva_contatto(nome: str, numero: str, ident: str = "", email: str = "", note: str = "") -> dict:
    nome, numero, email = nome.strip(), numero.strip(), email.strip()
    if not nome or not normalizza(numero):
        return {"ok": False, "messaggio": T("Scrivi nome e numero")}
    with _blocco:
        elenco = _leggi("contatti.json", ESEMPIO_CONTATTI if DEMO else [])
        voce = next((c for c in elenco if c["id"] == ident), None)
        if voce:
            voce.update(nome=nome, numero=numero, email=email, note=note.strip())
        else:
            voce = {"id": uuid.uuid4().hex[:10], "nome": nome, "numero": numero, "email": email,
                    "note": note.strip(), "preferito": False}
            elenco.append(voce)
        _scrivi("contatti.json", elenco)
    return {"ok": True, "messaggio": T("Contatto salvato"), "id": voce["id"]}


# Campi della scheda (come quella dell'iPhone). «nome» è nome e cognome insieme.
CAMPI = ("nome", "azienda", "numero", "numero2", "numero3", "email", "email2", "indirizzo",
         "compleanno", "sito", "social", "note")


def _pulisci(dati: dict) -> dict:
    return {k: str(dati.get(k) or "").strip() for k in CAMPI}


def mia_scheda() -> dict:
    """La scheda del proprietario del telefono (id «io»): il nome viene dal Solid ID se manca."""
    scheda = _leggi("mia-scheda.json", {})
    if not scheda.get("nome"):
        try:
            from .. import solidid

            u = solidid.utente() or {}
            scheda["nome"] = u.get("nome", "")
            scheda.setdefault("email", u.get("email", ""))
        except Exception:  # noqa: BLE001
            pass
    if DEMO and not scheda.get("numero"):
        scheda.update(nome=scheda.get("nome") or "Pasquale", numero="+39 333 000 0000", email="pasquale@esempio.it", compleanno="3 maggio")
    return {**{k: "" for k in CAMPI}, **scheda, "id": "io", "preferito": False}


def salva_scheda(dati: dict) -> dict:
    """Salva un contatto con tutti i campi (o «La mia scheda», id «io»)."""
    dati = dict(dati or {})
    ident = str(dati.get("id") or "")
    campi = _pulisci(dati)
    if ident == "io":
        if not campi["nome"]:
            return {"ok": False, "messaggio": T("Scrivi il tuo nome")}
        with _blocco:
            _scrivi("mia-scheda.json", campi)
        return {"ok": True, "messaggio": T("La tua scheda è salvata"), "id": "io"}
    if not campi["nome"] or not any(normalizza(campi[k]) for k in ("numero", "numero2", "numero3")):
        return {"ok": False, "messaggio": T("Scrivi il nome e almeno un numero")}
    if not normalizza(campi["numero"]):   # il primo numero scritto diventa il principale
        for k in ("numero2", "numero3"):
            if normalizza(campi[k]):
                campi["numero"], campi[k] = campi[k], ""
                break
    with _blocco:
        elenco = _leggi("contatti.json", ESEMPIO_CONTATTI if DEMO else [])
        voce = next((c for c in elenco if c["id"] == ident), None)
        if voce:
            voce.update(campi)
        else:
            voce = {"id": uuid.uuid4().hex[:10], **campi, "preferito": False}
            elenco.append(voce)
        _scrivi("contatti.json", elenco)
    return {"ok": True, "messaggio": T("Contatto salvato"), "id": voce["id"]}


# ── vCard (.vcf): il formato dei contatti di Android, iPhone, Gmail e Outlook ──
def _valore_vcard(riga: str) -> str:
    valore = riga.split(":", 1)[1] if ":" in riga else ""
    return valore.replace("\\,", ",").replace("\\;", ";").replace("\\n", " ").strip()


def importa_vcard(percorso: str) -> dict:
    """Importa tutti i contatti di un file .vcf (anche con molti contatti dentro)."""
    try:
        testo = Path(percorso.removeprefix("file://")).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return {"ok": False, "messaggio": T("Impossibile leggere il file")}
    # righe spezzate (continuano con uno spazio all'inizio) riunite
    testo = re.sub(r"\r?\n[ \t]", "", testo)
    nuovi = 0
    with _blocco:
        elenco = _leggi("contatti.json", ESEMPIO_CONTATTI if DEMO else [])
        for blocco in re.findall(r"BEGIN:VCARD(.*?)END:VCARD", testo, re.S | re.I):
            nome = numero = email = ""
            for riga in blocco.splitlines():
                chiave = riga.split(":", 1)[0].upper()
                if chiave.startswith("FN"):
                    nome = _valore_vcard(riga)
                elif chiave.startswith("N") and not nome and not chiave.startswith("NOTE") and not chiave.startswith("NICK"):
                    parti = _valore_vcard(riga).split(";")
                    nome = " ".join(x for x in (parti[1] if len(parti) > 1 else "", parti[0]) if x)
                elif chiave.startswith("TEL") and not numero:
                    numero = _valore_vcard(riga).removeprefix("tel:")
                elif chiave.startswith("EMAIL") and not email:
                    email = _valore_vcard(riga)
            if not nome or not normalizza(numero) or any(_uguali(c["numero"], numero) for c in elenco):
                continue
            elenco.append({"id": uuid.uuid4().hex[:10], "nome": nome, "numero": numero, "email": email,
                           "note": "", "preferito": False})
            nuovi += 1
        _scrivi("contatti.json", elenco)
    return {"ok": True, "messaggio": T("{n} contatti importati", n=nuovi) if nuovi != 1 else T("1 contatto importato")}


def cerca_vcard() -> list[dict]:
    """File .vcf in Scaricati, Documenti e nella cartella personale (per «Importa»)."""
    from ..sistema import cartella_utente

    trovati = []
    for cartella in (cartella_utente("DOWNLOAD", "Scaricati"), cartella_utente("DOCUMENTS", "Documenti"), Path.home()):
        try:
            for f in sorted(Path(cartella).glob("*.vcf")):
                trovati.append({"percorso": str(f), "nome": f.name, "cartella": Path(cartella).name})
        except OSError:
            continue
    return trovati[:30]


def esporta_vcard() -> dict:
    from ..sistema import cartella_utente

    cartella = cartella_utente("DOCUMENTS", "Documenti")
    cartella.mkdir(parents=True, exist_ok=True)
    f = cartella / "contatti.vcf"
    righe = []
    for c in contatti():
        sicuro = lambda x: (x or "").replace(",", "\\,").replace(";", "\\;")
        righe += ["BEGIN:VCARD", "VERSION:3.0", f"FN:{sicuro(c['nome'])}", f"N:;{sicuro(c['nome'])};;;",
                  f"TEL;TYPE=CELL:{c['numero']}"]
        for chiave, riga in (("numero2", "TEL;TYPE=HOME:"), ("numero3", "TEL;TYPE=WORK:"), ("email", "EMAIL:"),
                             ("email2", "EMAIL;TYPE=WORK:"), ("azienda", "ORG:"), ("indirizzo", "ADR;TYPE=HOME:;;"),
                             ("sito", "URL:"), ("note", "NOTE:")):
            if c.get(chiave):
                righe.append(riga + sicuro(c[chiave]))
        righe.append("END:VCARD")
    f.write_text("\r\n".join(righe) + "\r\n", encoding="utf-8")
    return {"ok": True, "messaggio": T("Contatti salvati in {f}", f=f"{cartella.name}/contatti.vcf")}


def preferito(ident: str, si: bool) -> None:
    with _blocco:
        elenco = _leggi("contatti.json", ESEMPIO_CONTATTI if DEMO else [])
        for c in elenco:
            if c["id"] == ident:
                c["preferito"] = bool(si)
        _scrivi("contatti.json", elenco)


def elimina_contatto(ident: str) -> None:
    with _blocco:
        elenco = [c for c in _leggi("contatti.json", ESEMPIO_CONTATTI if DEMO else []) if c["id"] != ident]
        _scrivi("contatti.json", elenco)


def nome_di(numero: str) -> str:
    return next((c["nome"] for c in contatti() if _uguali(c["numero"], numero)), "")


# ── Registro delle chiamate ──────────────────────────────────────────────────
def _esempio_registro() -> list[dict]:
    ora = time.time()
    return [
        {"numero": "+39 340 555 1212", "tipo": "persa", "quando": ora - 1800, "durata": 0},
        {"numero": "+39 333 111 2233", "tipo": "entrata", "quando": ora - 7200, "durata": 312},
        {"numero": "+39 081 555 0101", "tipo": "uscita", "quando": ora - 86400, "durata": 95},
        {"numero": "+39 328 777 4545", "tipo": "uscita", "quando": ora - 2 * 86400, "durata": 41},
    ]


def _quando(t: float) -> str:
    oggi = time.strftime("%Y-%m-%d")
    giorno = time.strftime("%Y-%m-%d", time.localtime(t))
    if giorno == oggi:
        return time.strftime("%H:%M", time.localtime(t))
    if time.strftime("%Y-%m-%d", time.localtime(time.time() - 86400)) == giorno:
        return T("ieri")
    return time.strftime("%d/%m", time.localtime(t))


def registro() -> list[dict]:
    voci = _leggi("registro.json", _esempio_registro() if DEMO else [])
    risultato = []
    for v in sorted(voci, key=lambda x: -x["quando"])[:200]:
        nome = nome_di(v["numero"])
        risultato.append({**v, "nome": nome or v["numero"], "conNome": bool(nome), "testoQuando": _quando(v["quando"])})
    return risultato


def _registra(numero: str, tipo: str, durata: int = 0) -> None:
    with _blocco:
        voci = _leggi("registro.json", _esempio_registro() if DEMO else [])
        voci.append({"numero": numero, "tipo": tipo, "quando": time.time(), "durata": int(durata)})
        _scrivi("registro.json", voci[-500:])


def cancella_registro() -> None:
    _scrivi("registro.json", [])


# ── Chiamate ─────────────────────────────────────────────────────────────────
class Chiamate:
    """Una chiamata alla volta (come la maggior parte dei telefoni Linux oggi).
    Passa dal modem con la SIM; se non c'è (o non ha campo) e c'è un account SIP, via Internet."""

    def __init__(self):
        self.percorso = ""
        self.numero = ""
        self.direzione = ""
        self.inizio = 0.0
        self.risposta = 0.0
        self.muto = False
        self.vivavoce = False
        self._demo_stato = ""
        self.via = ""                        # modem | internet
        self.persa = lambda numero: None     # avviso di chiamata persa (dato dall'interfaccia)

    def _voip(self):
        from . import voip

        return voip.linea()

    def stato(self) -> dict:
        if not self.percorso and not DEMO:
            entrata = self._in_arrivo()
            if entrata:
                return entrata
        if not self.percorso:
            return {"attiva": False}
        if self.via == "internet":
            c = self._voip().chiamata
            st = c.get("stato", "terminated")
            if st == "active" and not self.risposta:
                self.risposta = time.time()
        elif DEMO:
            st = self._demo_stato
            if st == "dialing" and time.time() - self.inizio > 3:
                st = self._demo_stato = "active"
                self.risposta = time.time()
        else:
            info = _mmcli("-o", self.percorso).get("call", {}).get("properties", {})
            st = info.get("state", "terminated")
            if st == "active" and not self.risposta:
                self.risposta = time.time()
        if st in ("terminated", "unknown", ""):
            self._fine()
            return {"attiva": False, "terminata": True}
        testo = {"dialing": T("Chiamata in corso…"), "ringing-out": T("Squilla…"), "ringing-in": T("Chiamata in arrivo"),
                 "active": "", "held": T("In attesa"), "waiting": T("In attesa")}.get(st, "")
        durata = int(time.time() - self.risposta) if self.risposta else 0
        nome = nome_di(self.numero)
        return {"attiva": True, "stato": st, "testo": testo or "%d:%02d" % divmod(durata, 60), "numero": self.numero,
                "nome": nome or self.numero, "inArrivo": st == "ringing-in", "muto": self.muto, "vivavoce": self.vivavoce,
                "internet": self.via == "internet"}

    def _in_arrivo(self) -> dict | None:
        c = self._voip().chiamata
        if c.get("stato") == "ringing-in":
            self.percorso, self.numero, self.direzione, self.via = "voip", c.get("numero", ""), "entrata", "internet"
            self.inizio = time.time()
            return self.stato()
        m = _modem()
        if not m:
            return None
        for percorso in _mmcli("-m", m, "--voice-list-calls").get("modem.voice.call", []):
            p = _mmcli("-o", percorso).get("call", {}).get("properties", {})
            if p.get("direction") == "incoming" and p.get("state") == "ringing-in":
                self.percorso, self.numero, self.direzione = percorso, p.get("number", ""), "entrata"
                self.inizio = time.time()
                return self.stato()
        return None

    def chiama(self, numero: str) -> dict:
        numero = numero.strip()
        if not normalizza(numero) and "@" not in numero:
            return {"ok": False, "messaggio": T("Numero non valido")}
        if self.percorso:
            return {"ok": False, "messaggio": T("C'è già una chiamata in corso")}
        self.numero, self.direzione, self.inizio, self.risposta = numero, "uscita", time.time(), 0.0
        self.muto = self.vivavoce = False
        if DEMO:
            self.percorso, self._demo_stato = "demo", "dialing"
            return {"ok": True}
        m = _modem()
        sim = m and stato_modem().get("sim")
        if not sim:
            # Senza SIM: via Internet, se c'è un account SIP collegato
            v = self._voip()
            if v.registrato or "@" in numero:
                r = v.chiama(numero)
                if r.get("ok"):
                    self.percorso, self.via = "voip", "internet"
                return r
            from . import voip

            if voip.account().get("attivo"):
                return {"ok": False, "messaggio": v.errore or T("Chiamate via Internet non collegate: controlla la rete")}
            return {"ok": False, "messaggio": T("Nessuna SIM: attiva le chiamate via Internet in Impostazioni")}
        self.via = "modem"
        r = subprocess.run(["mmcli", "-m", m, f"--voice-create-call=number={normalizza(numero)}"],
                           capture_output=True, text=True, timeout=20)
        trovato = re.search(r"(/org/freedesktop/ModemManager1/Call/\d+)", r.stdout)
        if r.returncode != 0 or not trovato:
            return {"ok": False, "messaggio": T("La chiamata non è partita")}
        self.percorso = trovato.group(1)
        subprocess.run(["mmcli", "-o", self.percorso, "--start"], capture_output=True, timeout=20)
        return {"ok": True}

    def rispondi(self) -> None:
        if self.via == "internet":
            self._voip().rispondi()
        elif self.percorso and not DEMO:
            subprocess.run(["mmcli", "-o", self.percorso, "--accept"], capture_output=True, timeout=20)

    def riaggancia(self) -> None:
        if self.via == "internet":
            self._voip().riaggancia()
        elif self.percorso and not DEMO:
            subprocess.run(["mmcli", "-o", self.percorso, "--hangup"], capture_output=True, timeout=20)
        self._fine()

    def tono(self, cifra: str) -> None:
        if self.via == "internet":
            self._voip().tono(cifra)
        elif self.percorso and not DEMO and re.fullmatch(r"[0-9*#]", cifra or ""):
            subprocess.run(["mmcli", "-o", self.percorso, f"--send-dtmf={cifra}"], capture_output=True, timeout=10)

    def imposta_muto(self, si: bool) -> None:
        self.muto = bool(si)
        if self.via == "internet":
            self._voip().muto(si)
        if not DEMO and shutil.which("wpctl"):
            subprocess.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "1" if si else "0"], capture_output=True)

    def imposta_vivavoce(self, si: bool) -> None:
        self.vivavoce = bool(si)
        # callaudiod sposta l'audio tra auricolare e altoparlante sui telefoni Linux
        if not DEMO and shutil.which("callaudiocli"):
            subprocess.run(["callaudiocli", "-s", "1" if si else "0"], capture_output=True)

    def _fine(self) -> None:
        if self.numero:
            durata = int(time.time() - self.risposta) if self.risposta else 0
            tipo = self.direzione if self.risposta or self.direzione == "uscita" else "persa"
            _registra(self.numero, tipo, durata)
            if tipo == "persa":
                self.persa(self.numero)
        if self.muto:
            self.imposta_muto(False)
        if self.via == "internet":
            self._voip().chiamata = {}
        self.percorso, self.numero, self.risposta, self._demo_stato, self.via = "", "", 0.0, "", ""


# ── Messaggi (SMS) ───────────────────────────────────────────────────────────
def _esempio_messaggi() -> dict:
    ora = time.time()
    return {
        "+39 333 111 2233": [
            {"testo": "Ciao! Stasera vieni a cena?", "mio": False, "quando": ora - 5400},
            {"testo": "Sì, arrivo verso le 20", "mio": True, "quando": ora - 5000},
            {"testo": "A che ora arrivi stasera? Ho preparato la cena", "mio": False, "quando": ora - 60},
        ],
        "+39 340 555 1212": [
            {"testo": "Ti ho mandato le foto sul PC con Condivisione Vicina", "mio": False, "quando": ora - 9000},
            {"testo": "Perfetto, grazie!", "mio": True, "quando": ora - 8800},
        ],
        "+39 328 777 4545": [
            {"testo": "La riunione è alle 10:30 nello studio", "mio": False, "quando": ora - 90000},
        ],
    }


def _archivio_sms() -> dict:
    return _leggi("messaggi.json", _esempio_messaggi() if DEMO else {})


def sincronizza_sms() -> list[tuple[str, str]]:
    """Copia nell'archivio gli SMS ricevuti dal modem e li toglie dal modem (che ha poco spazio).
    Restituisce i nuovi messaggi come (numero, testo)."""
    if DEMO:
        return []
    m = _modem()
    if not m:
        return []
    nuovi: list[tuple[str, str]] = []
    with _blocco:
        archivio = _archivio_sms()
        for percorso in _mmcli("-m", m, "--messaging-list-sms").get("modem.messaging.sms", []):
            sms = _mmcli("-s", percorso).get("sms", {})
            prop, cont = sms.get("properties", {}), sms.get("content", {})
            if prop.get("pdu-type") != "deliver" or prop.get("state") != "received":
                continue
            numero = cont.get("number", "")
            try:
                quando = time.mktime(time.strptime(prop.get("timestamp", "")[:19], "%Y-%m-%dT%H:%M:%S"))
            except ValueError:
                quando = time.time()
            chiave = next((k for k in archivio if _uguali(k, numero)), numero)
            archivio.setdefault(chiave, []).append({"testo": cont.get("text", ""), "mio": False, "quando": quando, "nuovo": True})
            subprocess.run(["mmcli", "-m", m, f"--messaging-delete-sms={percorso}"], capture_output=True, timeout=15)
            nuovi.append((numero, cont.get("text", "")))
        if nuovi:
            _scrivi("messaggi.json", archivio)
    return nuovi


def conversazioni() -> list[dict]:
    risultato = []
    for numero, messaggi in _archivio_sms().items():
        if not messaggi:
            continue
        ultimo = max(messaggi, key=lambda x: x["quando"])
        nome = nome_di(numero)
        risultato.append({"numero": numero, "nome": nome or numero, "conNome": bool(nome), "ultimo": ultimo["testo"],
                          "quando": ultimo["quando"], "testoQuando": _quando(ultimo["quando"]),
                          "nuovi": sum(1 for x in messaggi if x.get("nuovo"))})
    return sorted(risultato, key=lambda c: -c["quando"])


def conversazione(numero: str) -> dict:
    with _blocco:
        archivio = _archivio_sms()
        chiave = next((k for k in archivio if _uguali(k, numero)), numero)
        messaggi = archivio.get(chiave, [])
        if any(x.get("nuovo") for x in messaggi):
            for x in messaggi:
                x.pop("nuovo", None)
            _scrivi("messaggi.json", archivio)
    nome = nome_di(numero)
    elenco = [{**x, "testoQuando": time.strftime("%H:%M", time.localtime(x["quando"]))}
              for x in sorted(messaggi, key=lambda x: x["quando"])]
    return {"numero": chiave, "nome": nome or chiave, "messaggi": elenco}


def invia_sms(numero: str, testo: str) -> dict:
    testo = testo.strip()
    if not testo or not normalizza(numero):
        return {"ok": False, "messaggio": T("Scrivi il messaggio e il numero")}
    if not DEMO:
        m = _modem()
        if not m:
            return {"ok": False, "messaggio": T("Nessuna SIM: il messaggio non può partire")}
        sicuro = testo.replace("'", "’")
        r = subprocess.run(["mmcli", "-m", m, f"--messaging-create-sms=text='{sicuro}',number='{normalizza(numero)}'"],
                           capture_output=True, text=True, timeout=20)
        trovato = re.search(r"(/org/freedesktop/ModemManager1/SMS/\d+)", r.stdout)
        if r.returncode != 0 or not trovato:
            return {"ok": False, "messaggio": T("Il messaggio non è partito")}
        r = subprocess.run(["mmcli", "-s", trovato.group(1), "--send"], capture_output=True, text=True, timeout=60)
        if r.returncode != 0:
            return {"ok": False, "messaggio": T("Il messaggio non è partito: controlla il segnale")}
    with _blocco:
        archivio = _archivio_sms()
        chiave = next((k for k in archivio if _uguali(k, numero)), numero)
        archivio.setdefault(chiave, []).append({"testo": testo, "mio": True, "quando": time.time()})
        _scrivi("messaggi.json", archivio)
    return {"ok": True}
