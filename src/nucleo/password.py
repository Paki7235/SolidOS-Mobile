"""Password di SolidOS: una cassaforte cifrata per gli accessi ai siti e alle app, con i codici di
verifica (a due fattori), il generatore di password robuste, il controllo della sicurezza e le
password delle reti Wi-Fi salvate.

Come è protetta
- Le voci stanno in ~/.config/<os>/password/cassaforte.bin, cifrate con AES-256-GCM.
- La chiave della cassaforte è casuale (32 byte). Se l'account ha una password, la chiave è a sua
  volta cifrata con una chiave ricavata dalla password di accesso (scrypt): senza la password di
  accesso la cassaforte non si apre, nemmeno copiando i file. Se l'account non ha password, la
  chiave resta in un file leggibile solo dall'utente (e l'app lo dice).
- La password di accesso si controlla con unix_chkpwd (lo stesso controllo del sistema). Se è stata
  cambiata, l'app chiede una volta la vecchia per ricifrare la chiave.
- L'app si blocca da sola dopo qualche minuto senza usarla; ciò che si copia si cancella dagli
  appunti dopo 90 secondi.
- Il controllo delle password trapelate (facoltativo, su richiesta) manda al servizio Have I Been
  Pwned solo i primi 5 caratteri dell'impronta SHA-1 della password: la password non esce mai.
"""

from __future__ import annotations

import base64
import csv
import hashlib
import hmac
import io
import json
import os
import pwd
import re
import secrets
import shutil
import string
import struct
import subprocess
import time
import urllib.request
import uuid
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse

from .i18n import T
from .sistema import config_utente

ELIMINATE_GIORNI = 30
_AAD_CHIAVE = b"solidos-password-chiave-1"
_AAD_DATI = b"solidos-password-dati-1"

COMUNI = {"password", "123456", "12345678", "123456789", "qwerty", "abc123", "111111", "1234567890", "iloveyou",
          "admin", "welcome", "letmein", "000000", "password1", "qwerty123", "ciao", "ciao123", "napoli", "juventus",
          "forzanapoli", "milan", "inter", "roma", "amore", "tesoro", "francesco", "giuseppe", "antonio", "andrea"}


# ── Cifratura ────────────────────────────────────────────────────────────────
def _aes():
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM

    return AESGCM


def _cifra(chiave: bytes, dati: bytes, aad: bytes) -> bytes:
    nonce = secrets.token_bytes(12)
    return nonce + _aes()(chiave).encrypt(nonce, dati, aad)


def _decifra(chiave: bytes, blob: bytes, aad: bytes) -> bytes:
    return _aes()(chiave).decrypt(blob[:12], blob[12:], aad)


def _kdf(password: str, sale: bytes) -> bytes:
    return hashlib.scrypt(password.encode(), salt=sale, n=2 ** 15, r=8, p=1, maxmem=64 * 1024 * 1024, dklen=32)


def _cartella() -> Path:
    c = config_utente("password", "x").parent
    c.mkdir(parents=True, exist_ok=True)
    os.chmod(c, 0o700)
    return c


def _scrivi_privato(percorso: Path, dati: bytes) -> None:
    temporaneo = percorso.with_suffix(".tmp")
    fd = os.open(temporaneo, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "wb") as f:
        f.write(dati)
        f.flush()
        os.fsync(f.fileno())
    temporaneo.replace(percorso)


def _utente() -> str:
    return pwd.getpwuid(os.getuid()).pw_name


def account_senza_password() -> bool:
    try:
        from .blocco.__main__ import senza_password

        return senza_password(_utente())
    except Exception:  # noqa: BLE001
        return False


def verifica_login(password: str) -> bool:
    """La password di accesso al computer è giusta? (unix_chkpwd, come fa il sistema)."""
    programma = next((p for p in ("/usr/sbin/unix_chkpwd", "/sbin/unix_chkpwd") if os.path.exists(p)), None)
    if not programma:
        return False
    try:
        r = subprocess.run([programma, _utente(), "nullok"], input=password.encode() + b"\0", capture_output=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return False
    if r.returncode != 0:
        time.sleep(1.0)      # rallenta chi prova a indovinare
    return r.returncode == 0


class Cassaforte:
    def __init__(self) -> None:
        self.chiave: bytes | None = None
        self.voci: list[dict] = []
        self.ultimo_uso = time.time()

    # ── apertura ──
    @property
    def _file_chiave(self) -> Path:
        return _cartella() / "chiave.json"

    @property
    def _file_dati(self) -> Path:
        return _cartella() / "cassaforte.bin"

    def aperta(self) -> bool:
        return self.chiave is not None

    def serve_password(self) -> bool:
        return not account_senza_password()

    def _salva_chiave(self, chiave: bytes, password: str | None) -> None:
        if password:
            sale = secrets.token_bytes(16)
            dati = {"modo": "password", "sale": base64.b64encode(sale).decode(),
                    "chiave": base64.b64encode(_cifra(_kdf(password, sale), chiave, _AAD_CHIAVE)).decode()}
        else:
            dati = {"modo": "libero", "chiave": base64.b64encode(chiave).decode()}
        _scrivi_privato(self._file_chiave, json.dumps(dati).encode())

    def apri(self, password: str = "", vecchia: str = "") -> dict:
        """{"ok"} oppure {"ok": False, "messaggio", "serveVecchia"?}."""
        serve = self.serve_password()
        if serve and not verifica_login(password):
            return {"ok": False, "messaggio": T("Password non corretta")}
        if not serve:
            password = ""
        if not self._file_chiave.exists():
            self.chiave = secrets.token_bytes(32)
            self._salva_chiave(self.chiave, password or None)
            self.voci = []
            self._salva()
            return {"ok": True}
        info = json.loads(self._file_chiave.read_text())
        if info["modo"] == "libero":
            chiave = base64.b64decode(info["chiave"])
            if password:                                  # ora l'account ha una password: la si usa
                self._salva_chiave(chiave, password)
        else:
            sale, blob = base64.b64decode(info["sale"]), base64.b64decode(info["chiave"])
            chiave = None
            for tentativo in ([password, vecchia] if vecchia else [password]):
                if not tentativo:
                    continue
                try:
                    chiave = _decifra(_kdf(tentativo, sale), blob, _AAD_CHIAVE)
                    break
                except Exception:  # noqa: BLE001
                    continue
            if chiave is None:
                if vecchia:
                    return {"ok": False, "serveVecchia": True, "messaggio": T("La vecchia password non è corretta")}
                if not password:
                    return {"ok": False, "serveVecchia": True,
                            "messaggio": T("L'account ora non ha una password: scrivi quella che avevi prima")}
                return {"ok": False, "serveVecchia": True,
                        "messaggio": T("La password di accesso è cambiata: scrivi una volta quella di prima")}
            if vecchia or not password:
                self._salva_chiave(chiave, password or None)
        self.chiave = chiave
        self._carica()
        self.tocca()
        return {"ok": True}

    def chiudi(self) -> None:
        self.chiave = None
        self.voci = []

    def tocca(self) -> None:
        self.ultimo_uso = time.time()

    def _carica(self) -> None:
        if not self._file_dati.exists():
            self.voci = []
            return
        self.voci = json.loads(_decifra(self.chiave, self._file_dati.read_bytes(), _AAD_DATI))
        # le voci eliminate da più di 30 giorni se ne vanno davvero
        limite = time.time() - ELIMINATE_GIORNI * 86400
        prima = len(self.voci)
        self.voci = [v for v in self.voci if not v.get("eliminata") or v["eliminata"] > limite]
        if len(self.voci) != prima:
            self._salva()

    def _salva(self) -> None:
        if self.chiave is None:
            raise PermissionError("cassaforte chiusa")
        dati = json.dumps(self.voci, ensure_ascii=False).encode()
        if self._file_dati.exists():
            shutil.copy2(self._file_dati, self._file_dati.with_suffix(".bin.prec"))   # copia della versione precedente
        _scrivi_privato(self._file_dati, _cifra(self.chiave, dati, _AAD_DATI))

    # ── voci ──
    def salva_voce(self, v: dict) -> dict:
        v = dict(v)
        titolo = str(v.get("titolo") or "").strip() or dominio(str(v.get("sito") or ""))
        if not titolo:
            return {"ok": False, "messaggio": T("Scrivi il nome o il sito")}
        codice = str(v.get("codice") or "").strip()
        if codice and not segreto_otp(codice):
            return {"ok": False, "messaggio": T("La chiave del codice di verifica non è valida")}
        vecchia = next((x for x in self.voci if x["id"] == v.get("id")), None)
        adesso = time.time()
        voce = {"id": v.get("id") or uuid.uuid4().hex, "titolo": titolo[:120], "sito": str(v.get("sito") or "").strip()[:500],
                "utente": str(v.get("utente") or "").strip()[:200], "password": str(v.get("password") or "")[:500],
                "codice": codice[:500], "note": str(v.get("note") or "")[:5000],
                "creata": (vecchia or {}).get("creata", adesso), "modificata": adesso, "eliminata": 0,
                "precedenti": (vecchia or {}).get("precedenti", []), "trapelata": (vecchia or {}).get("trapelata", False)}
        if vecchia and vecchia.get("password") and vecchia["password"] != voce["password"]:
            voce["precedenti"] = ([{"password": vecchia["password"], "fino": adesso}] + voce["precedenti"])[:10]
            voce["trapelata"] = False
        self.voci = [x for x in self.voci if x["id"] != voce["id"]] + [voce]
        self._salva()
        return {"ok": True, "id": voce["id"], "messaggio": T("Salvata")}

    def elimina(self, ident: str, per_sempre: bool = False) -> None:
        if per_sempre:
            self.voci = [x for x in self.voci if x["id"] != ident]
        else:
            for x in self.voci:
                if x["id"] == ident:
                    x["eliminata"] = time.time()
        self._salva()

    def ripristina(self, ident: str) -> None:
        for x in self.voci:
            if x["id"] == ident:
                x["eliminata"] = 0
        self._salva()

    def voce(self, ident: str) -> dict | None:
        return next((x for x in self.voci if x["id"] == ident), None)

    def elenco(self, filtro: str = "tutte", testo: str = "") -> list[dict]:
        problemi = self.problemi()
        testo = testo.strip().lower()
        out = []
        for v in self.voci:
            if filtro == "eliminate":
                if not v.get("eliminata"):
                    continue
            elif v.get("eliminata"):
                continue
            if filtro == "codici" and not v.get("codice"):
                continue
            if filtro == "sicurezza" and v["id"] not in problemi:
                continue
            if testo and testo not in (v["titolo"] + " " + v["sito"] + " " + v["utente"]).lower():
                continue
            out.append({"id": v["id"], "titolo": v["titolo"], "utente": v["utente"], "sito": v["sito"],
                        "dominio": dominio(v["sito"]), "codice": bool(v.get("codice")), "problemi": problemi.get(v["id"], []),
                        "eliminata": v.get("eliminata", 0),
                        "giorniRimasti": max(0, ELIMINATE_GIORNI - int((time.time() - v["eliminata"]) / 86400)) if v.get("eliminata") else 0})
        out.sort(key=lambda x: x["titolo"].lower())
        return out

    def dettagli(self, ident: str) -> dict:
        v = self.voce(ident)
        if not v:
            return {}
        d = dict(v)
        d["dominio"] = dominio(v["sito"])
        d["problemi"] = self.problemi().get(ident, [])
        d["forza"] = forza(v["password"])
        d["quando"] = time.strftime("%d/%m/%Y", time.localtime(v["modificata"]))
        return d

    def problemi(self) -> dict[str, list[str]]:
        attive = [v for v in self.voci if not v.get("eliminata") and v.get("password")]
        conta: dict[str, int] = {}
        for v in attive:
            conta[v["password"]] = conta.get(v["password"], 0) + 1
        out: dict[str, list[str]] = {}
        for v in attive:
            p = []
            if v.get("trapelata"):
                p.append("trapelata")
            if conta[v["password"]] > 1:
                p.append("riutilizzata")
            if forza(v["password"])["livello"] == 0:
                p.append("debole")
            if p:
                out[v["id"]] = p
        return out

    def conteggi(self) -> dict:
        attive = [v for v in self.voci if not v.get("eliminata")]
        return {"tutte": len(attive), "codici": sum(1 for v in attive if v.get("codice")),
                "sicurezza": len(self.problemi()), "eliminate": sum(1 for v in self.voci if v.get("eliminata"))}

    def controlla_trapelate(self) -> dict:
        """Confronta ogni password con l'archivio delle password trapelate (k-anonimato)."""
        cache: dict[str, bool] = {}
        trovate = 0
        try:
            for v in self.voci:
                if v.get("eliminata") or not v.get("password"):
                    continue
                impronta = hashlib.sha1(v["password"].encode()).hexdigest().upper()
                if impronta not in cache:
                    cache[impronta] = _trapelata(impronta)
                v["trapelata"] = cache[impronta]
                trovate += cache[impronta]
        except OSError:
            return {"ok": False, "messaggio": T("Controllo non riuscito: serve la connessione a Internet")}
        self._salva()
        if trovate:
            return {"ok": True, "messaggio": T("{n} password compaiono tra quelle trapelate: cambiale", n=trovate)}
        return {"ok": True, "messaggio": T("Nessuna password compare tra quelle trapelate")}

    # ── importa ed esporta ──
    def importa_csv(self, percorso: str) -> dict:
        try:
            testo = Path(percorso).read_text(encoding="utf-8-sig")
        except (OSError, UnicodeDecodeError):
            return {"ok": False, "messaggio": T("File non leggibile")}
        righe = list(csv.DictReader(io.StringIO(testo)))
        if not righe:
            return {"ok": False, "messaggio": T("Il file è vuoto")}

        def campo(r: dict, *nomi: str) -> str:
            basso = {(k or "").strip().lower(): (v or "") for k, v in r.items()}
            for n in nomi:
                if basso.get(n):
                    return basso[n].strip() if n not in ("password", "login_password") else basso[n]
            return ""

        esistenti = {(dominio(v["sito"]), v["utente"]) for v in self.voci if not v.get("eliminata")}
        aggiunte = 0
        for r in righe:
            sito = campo(r, "url", "website", "login_uri", "uri", "web site")
            utente = campo(r, "username", "login_username", "login", "user", "email", "nome utente")
            password = campo(r, "password", "login_password")
            if not (sito or utente or password) or (dominio(sito), utente) in esistenti:
                continue
            self.voci.append({"id": uuid.uuid4().hex, "titolo": (campo(r, "name", "title", "nome") or dominio(sito) or utente)[:120],
                              "sito": sito, "utente": utente, "password": password,
                              "codice": campo(r, "otpauth", "totp", "login_totp", "otp"), "note": campo(r, "note", "notes", "extra", "comments"),
                              "creata": time.time(), "modificata": time.time(), "eliminata": 0, "precedenti": [], "trapelata": False})
            esistenti.add((dominio(sito), utente))
            aggiunte += 1
        self._salva()
        return {"ok": True, "messaggio": T("{n} password importate", n=aggiunte)}

    def esporta_csv(self, percorso: str) -> dict:
        buf = io.StringIO()
        w = csv.writer(buf)
        w.writerow(["Title", "URL", "Username", "Password", "Notes", "OTPAuth"])
        for v in sorted(self.voci, key=lambda x: x["titolo"].lower()):
            if not v.get("eliminata"):
                w.writerow([v["titolo"], v["sito"], v["utente"], v["password"], v["note"], v.get("codice", "")])
        _scrivi_privato(Path(percorso), buf.getvalue().encode())
        return {"ok": True, "messaggio": T("Esportate in {f}: il file non è cifrato, cancellalo dopo l'uso", f=Path(percorso).name)}


def _trapelata(impronta: str) -> bool:
    richiesta = urllib.request.Request(f"https://api.pwnedpasswords.com/range/{impronta[:5]}",
                                       headers={"User-Agent": "SolidOS-Password", "Add-Padding": "true"})
    with urllib.request.urlopen(richiesta, timeout=15) as r:
        for riga in r.read().decode().splitlines():
            resto, _, quante = riga.partition(":")
            if resto.strip() == impronta[5:] and int(quante or 0) > 0:
                return True
    return False


# ── Utilità ──────────────────────────────────────────────────────────────────
def dominio(sito: str) -> str:
    sito = (sito or "").strip()
    if not sito:
        return ""
    if "://" not in sito:
        sito = "https://" + sito
    host = (urlparse(sito).hostname or "").lower()
    return host[4:] if host.startswith("www.") else host


def forza(p: str) -> dict:
    """livello 0 debole, 1 discreta, 2 robusta."""
    if not p:
        return {"livello": 0, "testo": ""}
    classi = sum(bool(re.search(r, p)) for r in (r"[a-z]", r"[A-Z]", r"[0-9]", r"[^A-Za-z0-9]"))
    if p.lower() in COMUNI or len(p) < 8 or (len(p) < 10 and classi < 3) or len(set(p)) <= 3:
        return {"livello": 0, "testo": T("Debole")}
    if len(p) >= 14 and classi >= 3 or len(p) >= 18:
        return {"livello": 2, "testo": T("Robusta")}
    return {"livello": 1, "testo": T("Discreta")}


def genera(tipo: str = "robusta", lunghezza: int = 20) -> str:
    """robusta: «abcdef-ghIjk2-mnopqr» (facile da scrivere); caratteri: anche i simboli; numeri: solo cifre (PIN)."""
    if tipo == "numeri":
        return "".join(secrets.choice(string.digits) for _ in range(max(4, min(12, lunghezza))))
    if tipo == "caratteri":
        n = max(8, min(64, lunghezza))
        alfabeto = string.ascii_letters + string.digits + "!@#$%&*-_=+?"
        while True:
            p = "".join(secrets.choice(alfabeto) for _ in range(n))
            if all(re.search(r, p) for r in (r"[a-z]", r"[A-Z]", r"[0-9]", r"[^A-Za-z0-9]")):
                return p
    consonanti, vocali = "bcdfghjkmnpqrstvwxz", "aeiouy"
    gruppi = []
    for _ in range(3):
        gruppi.append("".join(secrets.choice(consonanti if i % 2 == 0 else vocali) for i in range(6)))
    lettere = list("".join(gruppi))
    posti = secrets.SystemRandom().sample(range(len(lettere)), 2)
    lettere[posti[0]] = lettere[posti[0]].upper()
    lettere[posti[1]] = secrets.choice(string.digits)
    s = "".join(lettere)
    return f"{s[0:6]}-{s[6:12]}-{s[12:18]}"


# ── Codici di verifica (TOTP, RFC 6238) ─────────────────────────────────────
def segreto_otp(testo: str) -> dict | None:
    testo = (testo or "").strip()
    if testo.lower().startswith("otpauth://"):
        u = urlparse(testo)
        q = {k: v[0] for k, v in parse_qs(u.query).items()}
        segreto = q.get("secret", "")
        info = {"segreto": segreto, "cifre": int(q.get("digits", 6)), "periodo": int(q.get("period", 30)),
                "algoritmo": q.get("algorithm", "SHA1").upper(), "emittente": q.get("issuer", ""),
                "etichetta": unquote(u.path.lstrip("/"))}
    else:
        info = {"segreto": testo, "cifre": 6, "periodo": 30, "algoritmo": "SHA1", "emittente": "", "etichetta": ""}
    info["segreto"] = re.sub(r"[\s-]", "", info["segreto"]).upper()
    try:
        base64.b32decode(info["segreto"] + "=" * (-len(info["segreto"]) % 8))
    except (ValueError, base64.binascii.Error):
        return None
    if not info["segreto"] or info["algoritmo"] not in ("SHA1", "SHA256", "SHA512") or info["cifre"] not in (6, 7, 8):
        return None
    return info


def codice_otp(testo: str, adesso: float | None = None) -> dict:
    info = segreto_otp(testo)
    if not info:
        return {}
    adesso = time.time() if adesso is None else adesso
    chiave = base64.b32decode(info["segreto"] + "=" * (-len(info["segreto"]) % 8))
    passo = int(adesso // info["periodo"])
    h = hmac.new(chiave, struct.pack(">Q", passo), getattr(hashlib, info["algoritmo"].lower())).digest()
    o = h[-1] & 0x0F
    numero = (struct.unpack(">I", h[o:o + 4])[0] & 0x7FFFFFFF) % (10 ** info["cifre"])
    codice = str(numero).zfill(info["cifre"])
    return {"codice": codice, "resto": info["periodo"] - adesso % info["periodo"], "periodo": info["periodo"],
            "emittente": info["emittente"]}


# ── Wi-Fi salvate (NetworkManager) ──────────────────────────────────────────
def reti_wifi() -> list[dict]:
    if not shutil.which("nmcli"):
        return []
    try:
        r = subprocess.run(["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"], capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return []
    reti = []
    for riga in r.stdout.splitlines():
        nome, _, tipo = riga.replace("\\:", "\0").rpartition(":")
        if tipo == "802-11-wireless":
            reti.append({"nome": nome.replace("\0", ":")})
    return sorted(reti, key=lambda x: x["nome"].lower())


def password_wifi(nome: str) -> dict:
    try:
        r = subprocess.run(["nmcli", "-s", "-g", "802-11-wireless.ssid,802-11-wireless-security.key-mgmt,802-11-wireless-security.psk",
                            "connection", "show", "id", nome], capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.TimeoutExpired):
        return {"ok": False}
    righe = r.stdout.split("\n")
    if r.returncode != 0 or len(righe) < 3:
        return {"ok": False, "messaggio": T("Password non disponibile")}
    ssid, sicurezza, psk = righe[0], righe[1], righe[2]
    return {"ok": True, "ssid": ssid or nome, "password": psk, "sicurezza": sicurezza,
            "qr": f"WIFI:T:{'WPA' if psk else 'nopass'};S:{_esc_wifi(ssid or nome)};P:{_esc_wifi(psk)};;"}


def _esc_wifi(s: str) -> str:
    return re.sub(r'([\\;,:"])', r"\\\1", s)


def qr_svg(testo: str) -> str:
    """Codice QR come file SVG temporaneo (per condividere una rete Wi-Fi)."""
    import qrcode
    import qrcode.image.svg

    cartella = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "solidos-password"
    cartella.mkdir(mode=0o700, parents=True, exist_ok=True)
    for vecchio in cartella.glob("qr-*.svg"):
        vecchio.unlink(missing_ok=True)
    file = cartella / f"qr-{secrets.token_hex(6)}.svg"
    qrcode.make(testo, image_factory=qrcode.image.svg.SvgPathFillImage, box_size=10, border=2).save(str(file))
    os.chmod(file, 0o600)
    return file.as_uri()
