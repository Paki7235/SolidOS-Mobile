"""Mail: account con configurazione automatica, caselle (Entrata, Bozze, Inviata, Archivio,
Indesiderata, Cestino e le altre cartelle), Entrata unificata, ricerca, lettura sicura,
scrivi / rispondi / rispondi a tutti / inoltra con allegati, firma. Il lavoro sta in nucleo/mail."""

from __future__ import annotations

import os
import secrets
import shutil
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse

from .. import mail
from ..i18n import T
from ..mail import conti
from ..mail import messaggio as M
from ..ponte import Backend, crea_ponte
from ..sistema import avvia, cartella_utente


def _percorso(indirizzo: str) -> str:
    return unquote(urlparse(indirizzo).path) if "://" in str(indirizzo) else str(indirizzo)


def _temporanea() -> Path:
    c = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "solidos-mail"
    c.mkdir(mode=0o700, parents=True, exist_ok=True)
    return c


class BackendMail(Backend):
    def __init__(self, mailto: str = "") -> None:
        self._mailto = mailto

    def inizio(self) -> dict:
        """Aperta da un collegamento «mailto:»: i campi del messaggio da scrivere."""
        if not self._mailto:
            return {}
        from urllib.parse import parse_qs

        u = urlparse(self._mailto)
        q = {k.lower(): v[0] for k, v in parse_qs(u.query).items()}
        self._mailto = ""
        return {"a": unquote(u.path), "cc": q.get("cc", ""), "oggetto": q.get("subject", ""), "testo": q.get("body", "")}

    # ── account ──
    def conti(self) -> list:
        out = []
        for a in conti.elenco():
            try:
                c = mail.casella(a["id"])
                entrata = next((x for x in c.cartelle() if x["ruolo"] == "entrata"), None)
                non_lette = entrata["nonlette"] if entrata else 0
            except Exception:  # noqa: BLE001
                non_lette = 0
            out.append({**a, "nonlette": non_lette})
        return out

    def configura(self, email: str) -> dict:
        return conti.configurazione(str(email))

    def aggiungiConto(self, dati: dict) -> dict:
        dati = dict(dati)
        email = str(dati.get("email", "")).strip()
        pw = str(dati.pop("password", ""))
        if "@" not in email or not pw:
            return {"ok": False, "messaggio": T("Scrivi l'email e la password")}
        conf = {"email": email, "nome": str(dati.get("nome") or "").strip(), "utente": str(dati.get("utente") or email).strip(),
                "imap": str(dati.get("imap", "")).strip(), "portaImap": int(dati.get("portaImap") or 993),
                "smtp": str(dati.get("smtp", "")).strip(), "portaSmtp": int(dati.get("portaSmtp") or 465),
                "sicurezzaSmtp": "starttls" if str(dati.get("sicurezzaSmtp")) == "starttls" else "ssl"}
        r = mail.prova(conf, pw)
        if not r["ok"]:
            return r
        if any(a["email"].lower() == email.lower() for a in conti.elenco() if a.get("id") != dati.get("id")):
            return {"ok": False, "messaggio": T("Questo account c'è già")}
        voce = conti.salva({**conf, **({"id": dati["id"]} if dati.get("id") else {})}, pw)
        try:
            c = mail.casella(voce["id"])
            c.sincronizza_cartelle()
            c.sincronizza("INBOX")
        except mail.Errore as e:
            return {"ok": True, "id": voce["id"], "messaggio": str(e)}
        return {"ok": True, "id": voce["id"]}

    def togliConto(self, ident: str) -> None:
        mail.dimentica(str(ident))
        conti.togli(str(ident))

    def salvaFirma(self, ident: str, firma: str) -> None:
        a = conti.conto(str(ident))
        if a:
            conti.salva({**a, "firma": str(firma)[:2000]})

    # ── caselle ──
    def cartelle(self, ident: str) -> list:
        try:
            return mail.casella(str(ident)).cartelle()
        except mail.Errore:
            return []

    def aggiorna(self, ident: str, cartella: str) -> dict:
        """Sincronizza (ident vuoto = tutte le Entrate)."""
        errori, nuovi = [], 0
        for a in ([conti.conto(str(ident))] if ident else conti.elenco()):
            if not a:
                continue
            try:
                c = mail.casella(a["id"])
                if not c.cartelle():
                    c.sincronizza_cartelle()
                nuovi += c.sincronizza(str(cartella) if ident else "INBOX")
            except mail.Errore as e:
                errori.append(f"{a['email']}: {e}")
            except Exception as e:  # noqa: BLE001
                errori.append(f"{a['email']}: {e}")
        return {"ok": not errori, "messaggio": "\n".join(errori), "nuovi": nuovi}

    def aggiornaCartelle(self, ident: str) -> list:
        try:
            return mail.casella(str(ident)).sincronizza_cartelle()
        except mail.Errore:
            return self.cartelle(ident)

    def messaggi(self, ident: str, cartella: str, testo: str = "", non_letti: bool = False) -> list:
        if ident:
            return mail.casella(str(ident)).elenco(str(cartella), str(testo), bool(non_letti))
        tutti = []
        for a in conti.elenco():
            try:
                tutti += mail.casella(a["id"]).elenco("INBOX", str(testo), bool(non_letti))
            except Exception:  # noqa: BLE001
                pass
        return sorted(tutti, key=lambda m: -m["data"])[:500]

    # ── lettura ──
    def apri(self, ident: str, cartella: str, uid: int, immagini: bool = False, scuro: bool = True) -> dict:
        try:
            c = mail.casella(str(ident))
            grezzo = c.grezzo(str(cartella), int(uid))
        except mail.Errore as e:
            return {"ok": False, "messaggio": str(e)}
        msg = M.analizza(grezzo)
        cont = M.contenuto(msg)
        pagina, bloccate = M.html_sicuro(cont, bool(immagini), bool(scuro))
        da = (M.indirizzi(str(msg.get("From", ""))) or [{"nome": "", "email": ""}])[0]
        letto = next((m for m in c.elenco(str(cartella)) if m["uid"] == int(uid)), {}).get("letto", True)
        if not letto:
            try:
                c.segna(str(cartella), int(uid), "\\Seen", True)
            except Exception:  # noqa: BLE001
                pass
        return {"ok": True, "conto": ident, "cartella": cartella, "uid": int(uid),
                "oggetto": M.testo_intestazione(msg.get("Subject")) or T("(senza oggetto)"),
                "daNome": da["nome"] or da["email"], "daEmail": da["email"],
                "a": ", ".join(x["nome"] or x["email"] for x in M.indirizzi(str(msg.get("To", "")))),
                "cc": ", ".join(x["nome"] or x["email"] for x in M.indirizzi(str(msg.get("Cc", "")))),
                "quando": M.data_lunga(M.data_di(msg)), "html": pagina, "bloccate": bloccate,
                "allegati": [{**x, "testoDimensione": _dimensione(x["dimensione"])} for x in cont["allegati"]]}

    def allegato(self, ident: str, cartella: str, uid: int, indice: int, apri: bool = True) -> dict:
        msg = M.analizza(mail.casella(str(ident)).grezzo(str(cartella), int(uid)))
        parte = M.parte_numero(msg, int(indice))
        if parte is None:
            return {"ok": False}
        nome = Path(M.testo_intestazione(parte.get_filename() or "allegato")).name or "allegato"
        cartella_dest = cartella_utente("DOWNLOAD", "Scaricati")
        cartella_dest.mkdir(parents=True, exist_ok=True)
        dest = cartella_dest / nome
        n = 1
        while dest.exists():
            dest = cartella_dest / f"{Path(nome).stem} ({n}){Path(nome).suffix}"
            n += 1
        dest.write_bytes(parte.get_payload(decode=True) or b"")
        if apri:
            avvia(["xdg-open", str(dest)])
        return {"ok": True, "percorso": str(dest), "messaggio": T("Salvato in Scaricati: {n}", n=dest.name)}

    def apriLink(self, url: str) -> None:
        url = str(url)
        if url.startswith(("http://", "https://", "mailto:")):
            avvia(["xdg-open", url])

    # ── azioni ──
    def segna(self, ident: str, cartella: str, uid: int, campo: str, si: bool) -> dict:
        try:
            mail.casella(str(ident)).segna(str(cartella), int(uid), "\\Seen" if campo == "letto" else "\\Flagged", bool(si))
            return {"ok": True}
        except mail.Errore as e:
            return {"ok": False, "messaggio": str(e)}

    def elimina(self, ident: str, cartella: str, uid: int) -> dict:
        try:
            dove = mail.casella(str(ident)).elimina(str(cartella), int(uid))
            return {"ok": True, "messaggio": T("Spostato nel Cestino") if dove == "cestino" else T("Eliminato")}
        except mail.Errore as e:
            return {"ok": False, "messaggio": str(e)}

    def sposta(self, ident: str, cartella: str, uid: int, verso: str) -> dict:
        try:
            c = mail.casella(str(ident))
            dest = c.cartella_di(str(verso)) if verso in mail.RUOLI else str(verso)
            if not dest:
                if verso == "archivio":
                    c.imap().create(mail._q("Archivio"))
                    c.sincronizza_cartelle()
                    dest = c.cartella_di("archivio") or "Archivio"
                else:
                    return {"ok": False, "messaggio": T("Cartella non trovata")}
            c.sposta(str(cartella), int(uid), dest)
            nomi = {"archivio": T("Archiviato"), "indesiderata": T("Spostato in Indesiderata"), "entrata": T("Spostato in Entrata")}
            return {"ok": True, "messaggio": nomi.get(str(verso), T("Spostato"))}
        except mail.Errore as e:
            return {"ok": False, "messaggio": str(e)}

    # ── scrittura ──
    def bozza(self, ident: str, cartella: str, uid: int, tipo: str) -> dict:
        """tipo: rispondi | tutti | inoltra."""
        c = mail.casella(str(ident))
        msg = M.analizza(c.grezzo(str(cartella), int(uid)))
        if tipo == "inoltra":
            b = M.bozza_inoltro(msg)
            allegati = []
            for x in M.contenuto(msg)["allegati"]:
                parte = M.parte_numero(msg, x["indice"])
                cartella_tmp = _temporanea() / secrets.token_hex(4)
                cartella_tmp.mkdir(mode=0o700)
                f = cartella_tmp / Path(x["nome"]).name
                f.write_bytes(parte.get_payload(decode=True) or b"")
                allegati.append(str(f))
            b["allegati"] = allegati
        else:
            b = M.bozza_risposta(msg, c.c["email"], tipo == "tutti")
            b["allegati"] = []
        b["conto"] = ident
        firma = c.c.get("firma", "")
        if firma:
            b["testo"] = "\n\n-- \n" + firma + b["testo"]
        return b

    def firma(self, ident: str) -> str:
        a = conti.conto(str(ident))
        return a.get("firma", "") if a else ""

    def _componi(self, d: dict):
        a = conti.conto(str(d.get("conto")))
        if not a:
            raise mail.Errore(T("Scegli l'account da cui inviare"))
        allegati = [_percorso(x) for x in d.get("allegati", [])]
        return mail.casella(a["id"]), M.nuovo(a["email"], a.get("nome", ""), str(d.get("a", "")), str(d.get("cc", "")),
                                              str(d.get("ccn", "")), str(d.get("oggetto", "")), str(d.get("testo", "")), allegati,
                                              str(d.get("inRisposta", "")), str(d.get("riferimenti", "")))

    def invia(self, d: dict) -> dict:
        d = dict(d)
        try:
            c, msg = self._componi(d)
            c.invia(msg)
        except (mail.Errore, OSError) as e:
            return {"ok": False, "messaggio": str(e)}
        return {"ok": True, "messaggio": T("Messaggio inviato")}

    def salvaBozza(self, d: dict) -> dict:
        try:
            c, msg = self._componi(dict(d))
            bozze = c.cartella_di("bozze")
            if not bozze:
                return {"ok": False, "messaggio": T("Questo account non ha la cartella Bozze")}
            c.aggiungi(bozze, msg.as_bytes(), "(\\Draft \\Seen)")
        except (mail.Errore, OSError) as e:
            return {"ok": False, "messaggio": str(e)}
        return {"ok": True, "messaggio": T("Bozza salvata")}

    def suggerimenti(self, testo: str) -> list:
        return mail.suggerimenti(str(testo).split(",")[-1])

    def infoFile(self, indirizzi: list) -> list:
        out = []
        for x in indirizzi:
            p = Path(_percorso(str(x)))
            if p.is_file():
                out.append({"percorso": str(p), "nome": p.name, "testoDimensione": _dimensione(p.stat().st_size)})
        return out


def _dimensione(n: int) -> str:
    if n < 1024:
        return f"{n} B"
    if n < 1024 * 1024:
        return f"{n / 1024:.0f} KB"
    return f"{n / 1024 / 1024:.1f} MB".replace(".", ",")


def main() -> int:
    from ..qmlapp import carica, crea_app, prepara_ambiente

    prepara_ambiente()
    try:
        from PyQt6.QtCore import Qt
        from PyQt6.QtGui import QGuiApplication
        from PyQt6.QtWebEngineQuick import QtWebEngineQuick

        if os.environ.get("QT_QUICK_BACKEND") == "software":
            os.environ.setdefault("QTWEBENGINE_CHROMIUM_FLAGS", "--disable-gpu")
        QGuiApplication.setAttribute(Qt.ApplicationAttribute.AA_ShareOpenGLContexts)
        QtWebEngineQuick.initialize()
    except ImportError:
        pass
    app = crea_app("mail")
    mailto = next((a for a in sys.argv[1:] if a.lower().startswith("mailto:")), "")
    motore = carica(app, "Mail/Main.qml", {"ponte": crea_ponte(BackendMail(mailto))})
    codice = app.exec()
    del motore
    shutil.rmtree(_temporanea(), ignore_errors=True)
    return codice


if __name__ == "__main__":
    sys.exit(main())
