"""Posta di SolidOS (IMAP e SMTP, sempre con connessioni cifrate).

- Le caselle e le intestazioni degli ultimi messaggi stanno in una copia locale (SQLite in
  ~/.cache/<os>/mail/, cartella leggibile solo dall'utente): l'elenco si apre subito e si legge
  anche senza rete; i messaggi interi si scaricano quando si aprono (i più recenti e piccoli
  subito, per l'anteprima).
- Elimina = sposta nel Cestino (dal Cestino si elimina davvero). Archivia, Indesiderata, sposta.
- Invio con SMTP; una copia va in «Inviata» (Gmail e Outlook la salvano da soli).
- Il servizio degli avvisi chiede ogni 5 minuti se sono arrivati messaggi nuovi in Entrata.
"""

from __future__ import annotations

import base64
import imaplib
import os
import re
import smtplib
import sqlite3
import ssl
import threading
import time
from datetime import datetime, timezone
from pathlib import Path

from .. import branding
from ..i18n import T
from . import conti
from . import messaggio as M

QUANTI = 300                  # messaggi tenuti nella copia locale per cartella
SCARICA_SUBITO = 40           # messaggi recenti scaricati interi (per l'anteprima)
MAX_SUBITO = 300_000          # … se più piccoli di così

RUOLI = ["entrata", "bozze", "inviata", "archivio", "indesiderata", "cestino"]
NOMI_RUOLI = {"entrata": "Entrata", "bozze": "Bozze", "inviata": "Inviata", "archivio": "Archivio",
              "indesiderata": "Indesiderata", "cestino": "Cestino"}
_FLAG_RUOLI = {"\\sent": "inviata", "\\drafts": "bozze", "\\trash": "cestino", "\\junk": "indesiderata", "\\archive": "archivio"}
_NOMI_NOTI = {
    "inviata": ["sent", "sent items", "sent messages", "inviata", "inviati", "posta inviata", "elementi inviati", "[gmail]/sent mail", "[gmail]/posta inviata"],
    "bozze": ["drafts", "draft", "bozze", "[gmail]/drafts", "[gmail]/bozze"],
    "cestino": ["trash", "deleted", "deleted items", "deleted messages", "cestino", "posta eliminata", "elementi eliminati", "[gmail]/trash", "[gmail]/cestino"],
    "indesiderata": ["junk", "spam", "junk e-mail", "posta indesiderata", "indesiderata", "[gmail]/spam"],
    "archivio": ["archive", "archivio", "archives"],
}


# ── nomi delle cartelle (UTF-7 modificato, RFC 3501) ────────────────────────
def da_utf7(s: str) -> str:
    def sost(m):
        t = m.group(1)
        if not t:
            return "&"
        b = t.replace(",", "/")
        b += "=" * (-len(b) % 4)
        return base64.b64decode(b).decode("utf-16-be", "replace")
    return re.sub(r"&([A-Za-z0-9+,]*)-", sost, s)


def a_utf7(s: str) -> str:
    out, buf = [], ""

    def chiudi():
        nonlocal buf
        if buf:
            out.append("&" + base64.b64encode(buf.encode("utf-16-be")).decode().rstrip("=").replace("/", ",") + "-")
            buf = ""
    for c in s:
        if 0x20 <= ord(c) <= 0x7E:
            chiudi()
            out.append("&-" if c == "&" else c)
        else:
            buf += c
    chiudi()
    return "".join(out)


def _q(nome: str) -> str:
    return '"' + a_utf7(nome).replace("\\", "\\\\").replace('"', '\\"') + '"'


# ── copia locale ─────────────────────────────────────────────────────────────
def _cartella_cache() -> Path:
    c = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / branding.id_os() / "mail"
    c.mkdir(parents=True, exist_ok=True)
    os.chmod(c, 0o700)
    return c


def _db(ident: str) -> sqlite3.Connection:
    db = sqlite3.connect(_cartella_cache() / f"{ident}.db", timeout=15)
    db.row_factory = sqlite3.Row
    db.executescript("""
        CREATE TABLE IF NOT EXISTS cartelle(nome TEXT PRIMARY KEY, ruolo TEXT, uidvalidity INTEGER, nonlette INTEGER DEFAULT 0, ordine INTEGER);
        CREATE TABLE IF NOT EXISTS messaggi(cartella TEXT, uid INTEGER, data REAL, da TEXT, a TEXT, oggetto TEXT, anteprima TEXT,
            letto INTEGER, bandiera INTEGER, allegati INTEGER, dimensione INTEGER, msgid TEXT, PRIMARY KEY(cartella, uid));
        CREATE TABLE IF NOT EXISTS corpi(cartella TEXT, uid INTEGER, grezzo BLOB, PRIMARY KEY(cartella, uid));
        CREATE TABLE IF NOT EXISTS indirizzi(email TEXT PRIMARY KEY, nome TEXT, volte INTEGER);
    """)
    return db


class Errore(Exception):
    pass


def _messaggio_errore(e: Exception) -> str:
    t = str(e)
    basso = t.lower()
    if isinstance(e, imaplib.IMAP4.error) and ("auth" in basso or "login" in basso or "credential" in basso or "password" in basso):
        return T("Email o password non accettate dal server")
    if isinstance(e, smtplib.SMTPAuthenticationError):
        return T("Email o password non accettate dal server di invio")
    if isinstance(e, (OSError, TimeoutError)) and not isinstance(e, ssl.SSLError):
        return T("Server non raggiungibile: controlla la connessione")
    if isinstance(e, ssl.SSLError):
        return T("Connessione sicura non riuscita con il server")
    return t[:200]


# ── collegamento ─────────────────────────────────────────────────────────────
class Casella:
    """Un account: connessione IMAP (riusata) e copia locale."""

    def __init__(self, conto: dict) -> None:
        self.c = conto
        self.blocco = threading.RLock()
        self._imap: imaplib.IMAP4 | None = None
        self._capacita: set[str] = set()

    # connessione
    def imap(self) -> imaplib.IMAP4:
        if self._imap is not None:
            try:
                self._imap.noop()
                return self._imap
            except Exception:  # noqa: BLE001
                self._imap = None
        try:
            i = imaplib.IMAP4_SSL(self.c["imap"], int(self.c.get("portaImap", 993)), ssl_context=ssl.create_default_context(), timeout=30)
            i.login(self.c.get("utente") or self.c["email"], conti.password(self.c["id"]))
        except Exception as e:  # noqa: BLE001
            raise Errore(_messaggio_errore(e)) from e
        self._capacita = {x.upper() for x in i.capabilities}
        self._imap = i
        return i

    def chiudi(self) -> None:
        if self._imap is not None:
            try:
                self._imap.logout()
            except Exception:  # noqa: BLE001
                pass
            self._imap = None

    def _seleziona(self, i, cartella: str, sola_lettura: bool = False) -> int:
        tipo, dati = i.select(_q(cartella), readonly=sola_lettura)
        if tipo != "OK":
            raise Errore(T("Cartella non trovata: {c}", c=cartella))
        validita = i.untagged_responses.get("UIDVALIDITY", [b"0"])[-1]
        return int(validita)

    # cartelle
    def sincronizza_cartelle(self) -> list[dict]:
        with self.blocco:
            i = self.imap()
            tipo, righe = i.list()
            if tipo != "OK":
                raise Errore(T("Elenco delle cartelle non disponibile"))
            trovate = []
            for r in righe:
                if not r:
                    continue
                r = r.decode() if isinstance(r, bytes) else str(r)
                m = re.match(r'\((?P<flag>[^)]*)\)\s+(?:"(?P<sep>[^"]*)"|NIL)\s+(?P<nome>.+)$', r)
                if not m:
                    continue
                flag = m.group("flag").lower().split()
                if "\\noselect" in flag or "\\nonexistent" in flag:
                    continue
                nome = m.group("nome").strip()
                if nome.startswith('"'):
                    nome = nome[1:-1].replace('\\"', '"').replace("\\\\", "\\")
                nome = da_utf7(nome)
                ruolo = "entrata" if nome.upper() == "INBOX" else next((_FLAG_RUOLI[f] for f in flag if f in _FLAG_RUOLI), "")
                if "\\all" in flag:
                    ruolo = "tutta"
                trovate.append([nome, ruolo])
            # ruoli dai nomi, se il server non li dice
            presi = {r for _, r in trovate if r}
            for voce in trovate:
                if not voce[1]:
                    for ruolo, nomi in _NOMI_NOTI.items():
                        if ruolo not in presi and voce[0].lower() in nomi:
                            voce[1] = ruolo
                            presi.add(ruolo)
                            break
            db = _db(self.c["id"])
            with db:
                vecchie = {r["nome"]: r for r in db.execute("SELECT * FROM cartelle")}
                db.execute("DELETE FROM cartelle")
                for n, (nome, ruolo) in enumerate(trovate):
                    v = vecchie.get(nome)
                    db.execute("INSERT INTO cartelle VALUES (?,?,?,?,?)", (nome, ruolo, v["uidvalidity"] if v else 0, v["nonlette"] if v else 0, n))
                for nome in set(vecchie) - {t[0] for t in trovate}:
                    db.execute("DELETE FROM messaggi WHERE cartella=?", (nome,))
                    db.execute("DELETE FROM corpi WHERE cartella=?", (nome,))
            return self.cartelle()

    def cartelle(self) -> list[dict]:
        db = _db(self.c["id"])
        righe = [dict(r) for r in db.execute("SELECT * FROM cartelle ORDER BY ordine")]
        for r in righe:
            r["nomeVisibile"] = T(NOMI_RUOLI[r["ruolo"]]) if r["ruolo"] in NOMI_RUOLI else r["nome"].split("/")[-1].split(".")[-1]
            r["nonlette"] = db.execute("SELECT COUNT(*) FROM messaggi WHERE cartella=? AND letto=0", (r["nome"],)).fetchone()[0]
        righe.sort(key=lambda r: (RUOLI.index(r["ruolo"]) if r["ruolo"] in RUOLI else 99, r["ordine"]))
        return righe

    def cartella_di(self, ruolo: str) -> str:
        r = _db(self.c["id"]).execute("SELECT nome FROM cartelle WHERE ruolo=?", (ruolo,)).fetchone()
        return r["nome"] if r else ""

    # messaggi
    def sincronizza(self, cartella: str) -> int:
        """Aggiorna la copia locale di una cartella; risponde quanti messaggi nuovi."""
        with self.blocco:
            i = self.imap()
            validita = self._seleziona(i, cartella, sola_lettura=True)
            db = _db(self.c["id"])
            riga = db.execute("SELECT uidvalidity FROM cartelle WHERE nome=?", (cartella,)).fetchone()
            if riga and riga["uidvalidity"] != validita:
                with db:
                    db.execute("DELETE FROM messaggi WHERE cartella=?", (cartella,))
                    db.execute("DELETE FROM corpi WHERE cartella=?", (cartella,))
                    db.execute("UPDATE cartelle SET uidvalidity=? WHERE nome=?", (validita, cartella))
            tipo, dati = i.uid("SEARCH", None, "ALL")
            uid = [int(x) for x in (dati[0] or b"").split()] if tipo == "OK" else []
            uid = uid[-QUANTI:]
            noti = {r["uid"] for r in db.execute("SELECT uid FROM messaggi WHERE cartella=?", (cartella,))}
            nuovi = [u for u in uid if u not in noti]
            with db:
                spariti = noti - set(uid)
                for u in spariti:
                    db.execute("DELETE FROM messaggi WHERE cartella=? AND uid=?", (cartella, u))
                    db.execute("DELETE FROM corpi WHERE cartella=? AND uid=?", (cartella, u))
            # stato (letto, bandiera) di quelli già noti
            if uid and noti:
                for u, flag, _, _ in self._recupera(i, sorted(set(uid) & noti), "(UID FLAGS)"):
                    with db:
                        db.execute("UPDATE messaggi SET letto=?, bandiera=? WHERE cartella=? AND uid=?",
                                   ("\\seen" in flag, "\\flagged" in flag, cartella, u))
            # intestazioni dei nuovi
            campi = "(UID FLAGS RFC822.SIZE INTERNALDATE BODY.PEEK[HEADER.FIELDS (FROM TO CC SUBJECT DATE MESSAGE-ID CONTENT-TYPE)])"
            for u, flag, dim, testa in self._recupera(i, nuovi, campi):
                msg = M.analizza(testa or b"")
                d = M.data_di(msg)
                with db:
                    db.execute("INSERT OR REPLACE INTO messaggi VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
                               (cartella, u, d.timestamp() if d else 0, M.testo_intestazione(msg.get("From")), M.testo_intestazione(msg.get("To")),
                                M.testo_intestazione(msg.get("Subject")), "", "\\seen" in flag, "\\flagged" in flag,
                                str(msg.get("Content-Type", "")).lower().startswith("multipart/mixed"), dim,
                                str(msg.get("Message-ID", ""))))
                    for x in M.indirizzi(str(msg.get("From", ""))):
                        db.execute("INSERT INTO indirizzi VALUES (?,?,1) ON CONFLICT(email) DO UPDATE SET volte=volte+1, nome=excluded.nome",
                                   (x["email"].lower(), x["nome"]))
            # i più recenti e piccoli interi, per l'anteprima
            senza = [r["uid"] for r in db.execute(
                "SELECT m.uid FROM messaggi m LEFT JOIN corpi c ON c.cartella=m.cartella AND c.uid=m.uid "
                "WHERE m.cartella=? AND c.uid IS NULL AND m.dimensione<? ORDER BY m.uid DESC LIMIT ?", (cartella, MAX_SUBITO, SCARICA_SUBITO))]
            for u, _, _, grezzo in self._recupera(i, senza, "(UID BODY.PEEK[])"):
                self._salva_corpo(db, cartella, u, grezzo)
            return len(nuovi) if noti else 0

    def _recupera(self, i, uid: list[int], campi: str):
        """(uid, flag, dimensione, dati) per gruppi di 50."""
        for n in range(0, len(uid), 50):
            gruppo = ",".join(str(u) for u in uid[n:n + 50])
            tipo, dati = i.uid("FETCH", gruppo, campi)
            if tipo != "OK":
                continue
            # i server mettono FLAGS prima o dopo il blocco di dati: si raccoglie tutto per messaggio
            record: list[list] = []
            for parte in dati:
                if isinstance(parte, tuple):
                    record.append([parte[0].decode("utf-8", "replace"), parte[1]])
                elif isinstance(parte, (bytes, bytearray)):
                    t = parte.decode("utf-8", "replace")
                    if record and not re.match(r"^\d+ \(", t):
                        record[-1][0] += t
                    else:
                        record.append([t, None])
            for t, corpo in record:
                mu = re.search(r"UID (\d+)", t)
                if not mu:
                    continue
                mf = re.search(r"FLAGS \(([^)]*)\)", t)
                md = re.search(r"RFC822\.SIZE (\d+)", t)
                yield int(mu.group(1)), (mf.group(1).lower() if mf else ""), int(md.group(1)) if md else 0, corpo

    def _salva_corpo(self, db, cartella: str, uid: int, grezzo: bytes | None) -> None:
        if not grezzo:
            return
        msg = M.analizza(grezzo)
        c = M.contenuto(msg)
        with db:
            db.execute("INSERT OR REPLACE INTO corpi VALUES (?,?,?)", (cartella, uid, grezzo))
            db.execute("UPDATE messaggi SET anteprima=?, allegati=? WHERE cartella=? AND uid=?",
                       (M.anteprima(c), bool(c["allegati"]), cartella, uid))

    def grezzo(self, cartella: str, uid: int) -> bytes:
        db = _db(self.c["id"])
        r = db.execute("SELECT grezzo FROM corpi WHERE cartella=? AND uid=?", (cartella, uid)).fetchone()
        if r:
            return r["grezzo"]
        with self.blocco:
            i = self.imap()
            self._seleziona(i, cartella, sola_lettura=True)
            for u, _, _, dati in self._recupera(i, [uid], "(UID BODY.PEEK[])"):
                self._salva_corpo(db, cartella, u, dati)
                return dati or b""
        raise Errore(T("Messaggio non più sul server"))

    def elenco(self, cartella: str, testo: str = "", solo_non_letti: bool = False) -> list[dict]:
        db = _db(self.c["id"])
        sql = "SELECT * FROM messaggi WHERE cartella=?"
        arg: list = [cartella]
        if testo:
            sql += " AND (da LIKE ? OR oggetto LIKE ? OR anteprima LIKE ? OR a LIKE ?)"
            arg += [f"%{testo}%"] * 4
        if solo_non_letti:
            sql += " AND letto=0"
        sql += " ORDER BY data DESC LIMIT 500"
        out = []
        for r in db.execute(sql, arg):
            d = datetime.fromtimestamp(r["data"], timezone.utc) if r["data"] else None
            out.append({"conto": self.c["id"], "cartella": cartella, "uid": r["uid"], "da": M.mittente_breve(r["da"]),
                        "daCompleto": r["da"], "a": r["a"], "oggetto": r["oggetto"] or T("(senza oggetto)"), "anteprima": r["anteprima"],
                        "letto": bool(r["letto"]), "bandiera": bool(r["bandiera"]), "allegati": bool(r["allegati"]),
                        "quando": M.data_breve(d), "data": r["data"], "colore": self.c.get("colore", "#3B82F6")})
        return out

    # azioni
    def segna(self, cartella: str, uid: int, flag: str, si: bool) -> None:
        with self.blocco:
            i = self.imap()
            self._seleziona(i, cartella)
            i.uid("STORE", str(uid), "+FLAGS.SILENT" if si else "-FLAGS.SILENT", f"({flag})")
        campo = {"\\Seen": "letto", "\\Flagged": "bandiera"}.get(flag)
        if campo:
            db = _db(self.c["id"])
            with db:
                db.execute(f"UPDATE messaggi SET {campo}=? WHERE cartella=? AND uid=?", (bool(si), cartella, uid))

    def sposta(self, cartella: str, uid: int, destinazione: str) -> None:
        with self.blocco:
            i = self.imap()
            self._seleziona(i, cartella)
            if "MOVE" in self._capacita:
                tipo, _ = i.uid("MOVE", str(uid), _q(destinazione))
                if tipo != "OK":
                    raise Errore(T("Spostamento non riuscito"))
            else:
                tipo, _ = i.uid("COPY", str(uid), _q(destinazione))
                if tipo != "OK":
                    raise Errore(T("Spostamento non riuscito"))
                i.uid("STORE", str(uid), "+FLAGS.SILENT", "(\\Deleted)")
                self._cancella_segnati(i, uid)
        self._togli_locale(cartella, uid)

    def elimina(self, cartella: str, uid: int) -> str:
        cestino = self.cartella_di("cestino")
        if cestino and cartella != cestino:
            self.sposta(cartella, uid, cestino)
            return "cestino"
        with self.blocco:
            i = self.imap()
            self._seleziona(i, cartella)
            i.uid("STORE", str(uid), "+FLAGS.SILENT", "(\\Deleted)")
            self._cancella_segnati(i, uid)
        self._togli_locale(cartella, uid)
        return "eliminato"

    def _cancella_segnati(self, i, uid: int) -> None:
        if "UIDPLUS" in self._capacita:
            i.uid("EXPUNGE", str(uid))
        else:
            i.expunge()

    def _togli_locale(self, cartella: str, uid: int) -> None:
        db = _db(self.c["id"])
        with db:
            db.execute("DELETE FROM messaggi WHERE cartella=? AND uid=?", (cartella, uid))
            db.execute("DELETE FROM corpi WHERE cartella=? AND uid=?", (cartella, uid))

    def aggiungi(self, cartella: str, grezzo: bytes, flag: str = "(\\Seen)") -> None:
        with self.blocco:
            i = self.imap()
            i.append(_q(cartella), flag, imaplib.Time2Internaldate(time.time()), grezzo)

    # invio
    def invia(self, msg) -> None:
        destinatari = M.destinatari(msg)
        if not destinatari:
            raise Errore(T("Scrivi almeno un destinatario"))
        utente, pw = self.c.get("utente") or self.c["email"], conti.password(self.c["id"])
        try:
            if self.c.get("sicurezzaSmtp", "ssl") == "ssl":
                s = smtplib.SMTP_SSL(self.c["smtp"], int(self.c.get("portaSmtp", 465)), context=ssl.create_default_context(), timeout=60)
            else:
                s = smtplib.SMTP(self.c["smtp"], int(self.c.get("portaSmtp", 587)), timeout=60)
                s.starttls(context=ssl.create_default_context())
            with s:
                s.login(utente, pw)
                s.send_message(msg, to_addrs=destinatari)
        except Exception as e:  # noqa: BLE001
            raise Errore(_messaggio_errore(e)) from e
        # copia in Inviata (senza Ccn); Gmail e Outlook la salvano da soli
        if not re.search(r"gmail\.com|office365\.com|outlook\.com", self.c["smtp"]):
            inviata = self.cartella_di("inviata")
            if inviata:
                del msg["Bcc"]
                try:
                    self.aggiungi(inviata, msg.as_bytes())
                except Exception:  # noqa: BLE001
                    pass
        db = _db(self.c["id"])
        with db:
            for ind in destinatari:
                db.execute("INSERT INTO indirizzi VALUES (?,?,3) ON CONFLICT(email) DO UPDATE SET volte=volte+3", (ind.lower(), ""))

    def nuovi_in_entrata(self, dopo_uid: int) -> list[dict]:
        """Per gli avvisi: messaggi non letti in Entrata con UID più alto di dopo_uid."""
        with self.blocco:
            i = self.imap()
            validita = self._seleziona(i, "INBOX", sola_lettura=True)
            tipo, dati = i.uid("SEARCH", None, "UNSEEN")
            uid = [int(x) for x in (dati[0] or b"").split()] if tipo == "OK" else []
            nuovi = [u for u in uid if u > dopo_uid][-5:]
            out = []
            for u, _, _, testa in self._recupera(i, nuovi, "(UID BODY.PEEK[HEADER.FIELDS (FROM SUBJECT)])"):
                m = M.analizza(testa or b"")
                out.append({"uid": u, "da": M.mittente_breve(str(m.get("From", ""))), "oggetto": M.testo_intestazione(m.get("Subject"))})
            return [{"validita": validita, "massimo": max(uid) if uid else dopo_uid}] + out


_caselle: dict[str, Casella] = {}
_blocco = threading.Lock()


def casella(ident: str) -> Casella:
    with _blocco:
        c = conti.conto(ident)
        if not c:
            raise Errore(T("Account non trovato"))
        if ident not in _caselle or _caselle[ident].c != c:
            if ident in _caselle:
                _caselle[ident].chiudi()
            _caselle[ident] = Casella(c)
        return _caselle[ident]


def prova(conf: dict, pw: str) -> dict:
    """Prova ricezione e invio con questi dati, senza salvare niente."""
    try:
        i = imaplib.IMAP4_SSL(conf["imap"], int(conf.get("portaImap", 993)), ssl_context=ssl.create_default_context(), timeout=20)
        i.login(conf.get("utente") or conf["email"], pw)
        i.logout()
    except Exception as e:  # noqa: BLE001
        return {"ok": False, "messaggio": T("Ricezione") + ": " + _messaggio_errore(e)}
    try:
        if conf.get("sicurezzaSmtp", "ssl") == "ssl":
            s = smtplib.SMTP_SSL(conf["smtp"], int(conf.get("portaSmtp", 465)), context=ssl.create_default_context(), timeout=20)
        else:
            s = smtplib.SMTP(conf["smtp"], int(conf.get("portaSmtp", 587)), timeout=20)
            s.starttls(context=ssl.create_default_context())
        with s:
            s.login(conf.get("utente") or conf["email"], pw)
    except Exception as e:  # noqa: BLE001
        return {"ok": False, "messaggio": T("Invio") + ": " + _messaggio_errore(e)}
    return {"ok": True}


def suggerimenti(testo: str) -> list[dict]:
    """Indirizzi per «A:»: rubrica e persone con cui si è scritto."""
    testo = testo.strip().lower()
    if len(testo) < 1:
        return []
    out: dict[str, dict] = {}
    try:
        from .. import rubrica

        for c in rubrica.contatti():
            for e in [c.get("email")] if isinstance(c.get("email"), str) else (c.get("email") or []):
                if e and (testo in e.lower() or testo in (c.get("nome") or "").lower()):
                    out[e.lower()] = {"nome": c.get("nome", ""), "email": e, "peso": 100}
    except Exception:  # noqa: BLE001
        pass
    for a in conti.elenco():
        try:
            for r in _db(a["id"]).execute("SELECT * FROM indirizzi WHERE email LIKE ? OR nome LIKE ? ORDER BY volte DESC LIMIT 10",
                                          (f"%{testo}%", f"%{testo}%")):
                if r["email"] not in out:
                    out[r["email"]] = {"nome": r["nome"] or "", "email": r["email"], "peso": r["volte"]}
        except sqlite3.Error:
            pass
    return sorted(out.values(), key=lambda x: -x["peso"])[:8]


def dimentica(ident: str) -> None:
    with _blocco:
        if ident in _caselle:
            _caselle.pop(ident).chiudi()
    for f in _cartella_cache().glob(f"{ident}.db*"):
        f.unlink(missing_ok=True)
