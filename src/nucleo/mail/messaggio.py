"""Messaggi: lettura (intestazioni, testo, HTML ripulito, allegati) e composizione (risposte,
inoltri, allegati).

L'HTML che arriva viene ripulito prima di mostrarlo: niente script, moduli, iframe, oggetti,
gestori di eventi; le immagini e gli stili esterni restano bloccati finché non si sceglie
«Carica immagini» (così chi scrive non sa quando e dove si apre il messaggio). Le immagini
incluse nel messaggio (cid:) diventano data: e si vedono subito.
"""

from __future__ import annotations

import base64
import email
import email.policy
import html
import mimetypes
import re
from datetime import datetime, timezone
from email.header import decode_header, make_header
from email.message import EmailMessage
from email.utils import format_datetime, getaddresses, make_msgid, parseaddr, parsedate_to_datetime
from pathlib import Path

from ..i18n import T

MESI = ["gen", "feb", "mar", "apr", "mag", "giu", "lug", "ago", "set", "ott", "nov", "dic"]


def testo_intestazione(valore) -> str:
    if valore is None:
        return ""
    try:
        return str(make_header(decode_header(str(valore)))).replace("\r", "").replace("\n", " ").strip()
    except Exception:  # noqa: BLE001
        return str(valore)


def indirizzi(valore: str) -> list[dict]:
    out = []
    for nome, ind in getaddresses([testo_intestazione(valore)]):
        if ind:
            out.append({"nome": nome or "", "email": ind})
    return out


def data_breve(d: datetime | None) -> str:
    if not d:
        return ""
    d = d.astimezone()
    oggi = datetime.now().astimezone().date()
    if d.date() == oggi:
        return d.strftime("%H:%M")
    if (oggi - d.date()).days == 1:
        return T("Ieri")
    if (oggi - d.date()).days < 7:
        return T(["lunedì", "martedì", "mercoledì", "giovedì", "venerdì", "sabato", "domenica"][d.weekday()])
    if d.year == oggi.year:
        return f"{d.day} {T(MESI[d.month - 1])}"
    return d.strftime("%d/%m/%y")


def data_lunga(d: datetime | None) -> str:
    if not d:
        return ""
    d = d.astimezone()
    return f"{d.day} {T(MESI[d.month - 1])} {d.year}, {d.strftime('%H:%M')}"


def data_di(msg) -> datetime | None:
    try:
        d = parsedate_to_datetime(msg.get("Date"))
        return d if d.tzinfo else d.replace(tzinfo=timezone.utc)
    except (TypeError, ValueError, IndexError):
        return None


def analizza(grezzo: bytes) -> EmailMessage:
    return email.message_from_bytes(grezzo, policy=email.policy.default)


def _testo_parte(parte) -> str:
    try:
        return parte.get_content()
    except Exception:  # noqa: BLE001
        dati = parte.get_payload(decode=True) or b""
        return dati.decode(parte.get_content_charset() or "utf-8", "replace")


def contenuto(msg: EmailMessage) -> dict:
    """{"testo", "html", "allegati": [{nome, tipo, dimensione, indice}], "cid": {id: data-uri}}."""
    testo, htm = "", ""
    allegati, cid = [], {}
    for i, parte in enumerate(msg.walk()):
        if parte.is_multipart():
            continue
        tipo = parte.get_content_type()
        disposizione = (parte.get_content_disposition() or "").lower()
        nome = testo_intestazione(parte.get_filename() or "")
        if tipo == "text/plain" and disposizione != "attachment" and not testo:
            testo = _testo_parte(parte)
        elif tipo == "text/html" and disposizione != "attachment" and not htm:
            htm = _testo_parte(parte)
        else:
            dati = parte.get_payload(decode=True) or b""
            ident = (parte.get("Content-ID") or "").strip("<> ")
            if ident and tipo.startswith("image/") and disposizione != "attachment":
                cid[ident] = f"data:{tipo};base64,{base64.b64encode(dati).decode()}"
                continue
            if disposizione == "attachment" or nome:
                allegati.append({"nome": nome or T("allegato") + (mimetypes.guess_extension(tipo) or ""), "tipo": tipo,
                                 "dimensione": len(dati), "indice": i})
    return {"testo": testo, "html": htm, "allegati": allegati, "cid": cid}


def parte_numero(msg: EmailMessage, indice: int):
    for i, parte in enumerate(msg.walk()):
        if i == indice:
            return parte
    return None


def anteprima(c: dict, n: int = 180) -> str:
    t = c["testo"] or re.sub(r"<[^>]+>", " ", re.sub(r"(?is)<(style|script|head)[^>]*>.*?</\1>", " ", c["html"]))
    t = html.unescape(t)
    t = re.sub(r"(?m)^>.*$", "", t)                  # senza le citazioni
    return re.sub(r"\s+", " ", t).strip()[:n]


# ── HTML sicuro ──────────────────────────────────────────────────────────────
_VIETATI = r"script|iframe|frame|frameset|object|embed|applet|form|input|button|textarea|select|meta|base|link|audio|video|source|svg|math"


def html_sicuro(c: dict, immagini: bool, scuro: bool) -> tuple[str, int]:
    """(pagina HTML, quante risorse esterne sono state bloccate)."""
    if c["html"]:
        h = c["html"]
        h = re.sub(rf"(?is)<({_VIETATI})\b[^>]*>.*?</\1\s*>", "", h)
        h = re.sub(rf"(?is)<\/?({_VIETATI})\b[^>]*>", "", h)
        h = re.sub(r"(?is)\son[a-z]+\s*=\s*(\"[^\"]*\"|'[^']*'|[^\s>]+)", "", h)
        h = re.sub(r"(?is)(href|src)\s*=\s*([\"'])\s*(javascript|vbscript|data:text)[^\"']*\2", r"\1=\2#\2", h)
        for ident, uri in c["cid"].items():
            h = h.replace(f"cid:{ident}", uri)
        bloccate = 0
        if not immagini:
            def blocca(m):
                nonlocal bloccate
                bloccate += 1
                return f'{m.group(1)}data-bloccato={m.group(2)}'
            h = re.sub(r"(?is)(<img\b[^>]*?\s)(?:src|srcset)\s*=\s*([\"']\s*https?:)", blocca, h)
            h = re.sub(r"(?is)(\s)background\s*=\s*([\"']\s*https?:)", blocca, h)
            n = len(re.findall(r"(?i)url\(\s*['\"]?\s*https?:", h))
            bloccate += n
            h = re.sub(r"(?i)url\(\s*['\"]?\s*https?:[^)]*\)", "none", h)
            h = re.sub(r"(?i)@import[^;]+;", "", h)
        corpo = h
    else:
        bloccate = 0
        t = html.escape(c["testo"] or "")
        t = re.sub(r"(https?://[^\s<]+)", r'<a href="\1">\1</a>', t)
        righe = []
        for riga in t.split("\n"):
            livello = len(re.match(r"^((?:&gt;\s?)*)", riga).group(1).replace(" ", "")) // 4
            riga = re.sub(r"^(?:&gt;\s?)+", "", riga)
            righe.append(f'<div class="cit{min(livello, 3)}">{riga or "&nbsp;"}</div>')
        corpo = '<div class="testo">' + "".join(righe) + "</div>"
    colore, sfondo = ("#E5E5EA", "#1E1F24") if scuro else ("#1C1C1E", "#FFFFFF")
    pagina = f"""<!doctype html><html><head><meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data: {'https: http:' if immagini else ''}; style-src 'unsafe-inline' {'https:' if immagini else ''}; font-src data: {'https:' if immagini else ''}">
<style>
html{{background:{sfondo};}}
body{{margin:0;padding:4px 2px 24px;font-family:Inter,'Noto Sans',sans-serif;font-size:14px;line-height:1.5;color:{colore};word-wrap:break-word;}}
a{{color:#3B82F6;}} img{{max-width:100%;height:auto;}} table{{max-width:100%;}}
.testo{{white-space:pre-wrap;}} .cit1,.cit2,.cit3{{border-left:3px solid #3B82F6;padding-left:10px;color:#8E8E93;}}
.cit2{{border-color:#22C55E;margin-left:12px}} .cit3{{border-color:#F59E0B;margin-left:24px}}
</style></head><body>{corpo}</body></html>"""
    return pagina, bloccate


# ── Composizione ─────────────────────────────────────────────────────────────
def nuovo(mittente: str, nome: str, a: str, cc: str, ccn: str, oggetto: str, testo: str, allegati: list[str],
          in_risposta: str = "", riferimenti: str = "") -> EmailMessage:
    m = EmailMessage()
    dominio = mittente.rpartition("@")[2] or None
    m["From"] = f"{nome} <{mittente}>" if nome else mittente
    if a:
        m["To"] = a
    if cc:
        m["Cc"] = cc
    if ccn:
        m["Bcc"] = ccn
    m["Subject"] = oggetto
    m["Date"] = format_datetime(datetime.now().astimezone())
    m["Message-ID"] = make_msgid(domain=dominio)
    if in_risposta:
        m["In-Reply-To"] = in_risposta
        m["References"] = (riferimenti + " " + in_risposta).strip()
    m["User-Agent"] = "SolidOS Mail"
    m.set_content(testo)
    for percorso in allegati:
        p = Path(percorso)
        tipo, _ = mimetypes.guess_type(p.name)
        principale, _, secondario = (tipo or "application/octet-stream").partition("/")
        m.add_attachment(p.read_bytes(), maintype=principale, subtype=secondario, filename=p.name)
    return m


def destinatari(m: EmailMessage) -> list[str]:
    out = []
    for h in ("To", "Cc", "Bcc"):
        valore = str(m.get(h, "") or "").strip()
        if valore:                 # getaddresses con valori vuoti nell'elenco non trova niente (Python 3.13)
            out += [ind for _, ind in getaddresses([valore]) if ind]
    return out


def citazione(msg: EmailMessage) -> str:
    c = contenuto(msg)
    testo = c["testo"] or anteprima({"testo": "", "html": c["html"]}, 100000)
    chi = testo_intestazione(msg.get("From"))
    quando = data_lunga(data_di(msg))
    return "\n\n" + T("Il {d}, {chi} ha scritto:", d=quando, chi=chi) + "\n" + "\n".join("> " + r for r in testo.strip().split("\n"))


def bozza_risposta(msg: EmailMessage, mio: str, tutti: bool) -> dict:
    oggetto = testo_intestazione(msg.get("Subject"))
    if not re.match(r"(?i)^(re|r):", oggetto):
        oggetto = "Re: " + oggetto
    rispondi = msg.get("Reply-To") or msg.get("From")
    a = [x["email"] for x in indirizzi(str(rispondi))]
    cc = []
    if tutti:
        for x in indirizzi(str(msg.get("To", ""))) + indirizzi(str(msg.get("Cc", ""))):
            if x["email"].lower() != mio.lower() and x["email"] not in a:
                cc.append(x["email"])
    return {"a": ", ".join(a), "cc": ", ".join(cc), "oggetto": oggetto, "testo": citazione(msg),
            "inRisposta": str(msg.get("Message-ID", "")), "riferimenti": str(msg.get("References", ""))}


def bozza_inoltro(msg: EmailMessage) -> dict:
    oggetto = testo_intestazione(msg.get("Subject"))
    if not re.match(r"(?i)^(fwd?|i):", oggetto):
        oggetto = "Fwd: " + oggetto
    c = contenuto(msg)
    testo = c["testo"] or anteprima({"testo": "", "html": c["html"]}, 100000)
    intest = "\n".join([
        "\n\n---------- " + T("Messaggio inoltrato") + " ----------",
        T("Da") + ": " + testo_intestazione(msg.get("From")),
        T("Data") + ": " + data_lunga(data_di(msg)),
        T("Oggetto") + ": " + testo_intestazione(msg.get("Subject")),
        T("A") + ": " + testo_intestazione(msg.get("To")), ""])
    return {"a": "", "cc": "", "oggetto": oggetto, "testo": intest + testo}


def mittente_breve(valore: str) -> str:
    nome, ind = parseaddr(testo_intestazione(valore))
    return nome or ind
