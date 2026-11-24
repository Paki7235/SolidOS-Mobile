"""Vela: il browser di SolidOS (motore Chromium di Qt WebEngine).

Schede, barra degli indirizzi che cerca o apre, pagina «Nuova scheda» con i siti
più visitati, preferiti, cronologia, download in «Scaricati», finestra privata
(nulla viene salvato), zoom e ricerca nella pagina.

Dati in ~/.local/share/<os>/web/: preferiti.json, cronologia.json, impostazioni.json.
"""

from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path
from urllib.parse import quote_plus, urlparse

from .. import branding
from ..ponte import Backend, crea_ponte

MOTORI = {
    "google": ("Google", "https://www.google.com/search?q={}"),
    "duckduckgo": ("DuckDuckGo", "https://duckduckgo.com/?q={}"),
    "bing": ("Bing", "https://www.bing.com/search?q={}"),
    "ecosia": ("Ecosia", "https://www.ecosia.org/search?q={}"),
    "startpage": ("Startpage", "https://www.startpage.com/do/search?q={}"),
}
MAX_CRONOLOGIA = 5000


def _cartella() -> Path:
    c = Path.home() / ".local/share" / branding.id_os() / "web"
    c.mkdir(parents=True, exist_ok=True)
    return c


def _leggi(nome: str, predefinito):
    try:
        return json.loads((_cartella() / nome).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return predefinito


def _scrivi(nome: str, dati) -> None:
    f = _cartella() / nome
    tmp = f.with_suffix(".tmp")
    tmp.write_text(json.dumps(dati, ensure_ascii=False), encoding="utf-8")
    tmp.replace(f)


class BackendWeb(Backend):
    def __init__(self):
        self._cronologia: list[dict] = _leggi("cronologia.json", [])
        self._sporca = False

    # ── Avvio ──────────────────────────────────────────────────────────────
    def indirizziIniziali(self) -> list:
        """Indirizzi passati da riga di comando (clic su un link in un'altra app)."""
        risultato = []
        for a in sys.argv[1:]:
            if a.startswith("-"):
                continue
            if "://" in a or a.startswith("about:"):
                risultato.append(a)
            elif Path(a).exists():
                risultato.append(Path(a).resolve().as_uri())
            else:
                risultato.append(self.indirizzo(a))
        return risultato

    def privata(self) -> bool:
        return "--privata" in sys.argv

    def cartellaDownload(self) -> str:
        from ..sistema import cartella_utente

        c = cartella_utente("DOWNLOAD", "Scaricati")
        c.mkdir(parents=True, exist_ok=True)
        return str(c)

    # ── Impostazioni ───────────────────────────────────────────────────────
    def impostazioni(self) -> dict:
        conf = {"motore": "google", "paginaIniziale": "", "barraPreferiti": True}
        conf.update(_leggi("impostazioni.json", {}))
        conf["motori"] = [{"testo": n, "valore": k} for k, (n, _u) in MOTORI.items()]
        return conf

    def imposta(self, chiave: str, valore) -> dict:
        conf = _leggi("impostazioni.json", {})
        conf[chiave] = valore
        _scrivi("impostazioni.json", conf)
        return self.impostazioni()

    # ── Barra degli indirizzi: sito o ricerca? ─────────────────────────────
    def indirizzo(self, testo: str) -> str:
        t = testo.strip()
        if not t:
            return ""
        if t.startswith(("http://", "https://", "file://", "about:", "view-source:", "data:")):
            return t
        if " " not in t and ("." in t or t.startswith("localhost")) and not t.endswith("."):
            dominio = t.split("/")[0].split(":")[0]
            if dominio == "localhost" or dominio.replace(".", "").isdigit() or len(dominio.rsplit(".", 1)[-1]) >= 2:
                return ("http://" if dominio == "localhost" or dominio.replace(".", "").isdigit() else "https://") + t
        motore = self.impostazioni().get("motore", "google")
        return MOTORI.get(motore, MOTORI["google"])[1].format(quote_plus(t))

    def suggerimenti(self, testo: str) -> list:
        """Dalla cronologia e dai preferiti, mentre si scrive nella barra degli indirizzi."""
        t = testo.strip().lower()
        if not t:
            return []
        visti, risultato = set(), []
        for p in self.preferiti():
            if t in p["titolo"].lower() or t in p["url"].lower():
                risultato.append({**p, "tipo": "preferito"})
                visti.add(p["url"])
        for v in sorted(self._cronologia, key=lambda x: -x.get("visite", 1)):
            if v["url"] in visti:
                continue
            if t in v.get("titolo", "").lower() or t in v["url"].lower():
                risultato.append({"url": v["url"], "titolo": v.get("titolo") or v["url"], "tipo": "cronologia"})
                visti.add(v["url"])
            if len(risultato) >= 6:
                break
        return risultato[:6]

    # ── Cronologia ─────────────────────────────────────────────────────────
    def visita(self, url: str, titolo: str) -> None:
        if not url or url.startswith(("about:", "data:", "view-source:")):
            return
        adesso = time.time()
        for v in self._cronologia:
            if v["url"] == url:
                v["titolo"] = titolo or v.get("titolo", "")
                v["ultima"] = adesso
                v["visite"] = v.get("visite", 1) + (1 if adesso - v.get("ultima", 0) > 30 else 0)
                break
        else:
            self._cronologia.append({"url": url, "titolo": titolo, "ultima": adesso, "visite": 1})
        if len(self._cronologia) > MAX_CRONOLOGIA:
            self._cronologia.sort(key=lambda x: -x["ultima"])
            del self._cronologia[MAX_CRONOLOGIA:]
        _scrivi("cronologia.json", self._cronologia)

    def cronologia(self, cerca: str = "") -> list:
        t = cerca.strip().lower()
        voci = [v for v in self._cronologia if not t or t in v.get("titolo", "").lower() or t in v["url"].lower()]
        voci.sort(key=lambda x: -x["ultima"])
        risultato = []
        for v in voci[:300]:
            d = time.localtime(v["ultima"])
            risultato.append({"url": v["url"], "titolo": v.get("titolo") or v["url"],
                              "quando": time.strftime("%d/%m/%Y %H:%M", d)})
        return risultato

    def cancellaCronologia(self) -> None:
        self._cronologia = []
        _scrivi("cronologia.json", [])

    def piuVisitati(self) -> list:
        """Riquadri della pagina «Nuova scheda»: un sito per dominio, i più visitati."""
        per_dominio: dict[str, dict] = {}
        for v in self._cronologia:
            dominio = urlparse(v["url"]).netloc
            if not dominio:
                continue
            p = per_dominio.get(dominio)
            if not p or v.get("visite", 1) > p["visite"]:
                per_dominio[dominio] = {"url": f"{urlparse(v['url']).scheme}://{dominio}/", "dominio": dominio.removeprefix("www."),
                                        "titolo": v.get("titolo") or dominio, "visite": v.get("visite", 1)}
            else:
                p["visite"] += v.get("visite", 1)
        siti = sorted(per_dominio.values(), key=lambda x: -x["visite"])[:8]
        if len(siti) < 4:
            for url, nome in (("https://it.wikipedia.org/", "wikipedia.org"), ("https://www.youtube.com/", "youtube.com"),
                              ("https://www.openstreetmap.org/", "openstreetmap.org"), ("https://www.google.com/", "google.com")):
                if all(s["dominio"] != nome for s in siti):
                    siti.append({"url": url, "dominio": nome, "titolo": nome, "visite": 0})
        return siti[:8]

    # ── Preferiti ──────────────────────────────────────────────────────────
    def preferiti(self) -> list:
        return _leggi("preferiti.json", [])

    def ePreferito(self, url: str) -> bool:
        return any(p["url"] == url for p in self.preferiti())

    def preferito(self, url: str, titolo: str, si: bool) -> list:
        elenco = [p for p in self.preferiti() if p["url"] != url]
        if si and url:
            elenco.append({"url": url, "titolo": titolo or url})
        _scrivi("preferiti.json", elenco)
        return elenco

    def importaPreferiti(self) -> int:
        """Preferiti esportati in HTML (da «Trasferisci file» o da altri browser) in Documenti."""
        import re
        from html import unescape

        from ..sistema import cartella_utente

        nuovi = 0
        elenco = self.preferiti()
        visti = {p["url"] for p in elenco}
        for f in cartella_utente("DOCUMENTS", "Documenti").glob("*.html"):
            try:
                testo = f.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            if "NETSCAPE-Bookmark" not in testo[:200]:
                continue
            for url, titolo in re.findall(r'<A HREF="([^"]+)"[^>]*>([^<]*)</A>', testo, re.I):
                url = unescape(url)
                if url.startswith("http") and url not in visti:
                    elenco.append({"url": url, "titolo": unescape(titolo) or url})
                    visti.add(url)
                    nuovi += 1
        _scrivi("preferiti.json", elenco)
        return nuovi

    # ── Download ───────────────────────────────────────────────────────────
    def apriFile(self, percorso: str) -> None:
        from ..sistema import avvia

        avvia(["xdg-open", percorso])

    def mostraNellaCartella(self, percorso: str) -> None:
        from ..sistema import avvia

        avvia([branding.comando("file"), percorso])

    def cancellaDatiSiti(self) -> None:
        """Cookie e dati dei siti si cancellano al prossimo avvio (il motore li tiene aperti)."""
        (_cartella() / "cancella-dati").touch()

    def nuovaFinestra(self, privata: bool = False, url: str = "") -> None:
        from ..sistema import avvia

        avvia([branding.comando("web")] + (["--privata"] if privata else []) + ([url] if url else []))


def main() -> int:
    from ..qmlapp import carica, crea_app, prepara_ambiente

    prepara_ambiente()
    # Il motore web disegna da solo: con la grafica software di Qt Quick si disattiva la GPU di Chromium
    if os.environ.get("QT_QUICK_BACKEND") == "software":
        os.environ.setdefault("QTWEBENGINE_CHROMIUM_FLAGS", "--disable-gpu")
    from PyQt6.QtCore import Qt
    from PyQt6.QtGui import QGuiApplication
    from PyQt6.QtWebEngineQuick import QtWebEngineQuick

    QGuiApplication.setAttribute(Qt.ApplicationAttribute.AA_ShareOpenGLContexts)
    QtWebEngineQuick.initialize()
    app = crea_app("web")
    if (_cartella() / "cancella-dati").exists():
        import shutil

        from PyQt6.QtCore import QStandardPaths

        base = Path(QStandardPaths.writableLocation(QStandardPaths.StandardLocation.AppDataLocation)) / "QtWebEngine" / "Web"
        for nome in ("Cookies", "Cookies-journal", "Local Storage", "Session Storage", "IndexedDB", "Service Worker", "databases"):
            p = base / nome
            shutil.rmtree(p, ignore_errors=True) if p.is_dir() else p.unlink(missing_ok=True)
        (_cartella() / "cancella-dati").unlink(missing_ok=True)
    motore = carica(app, "Web/Main.qml", {"ponte": crea_ponte(BackendWeb())})
    codice = app.exec()
    del motore
    return codice


if __name__ == "__main__":
    sys.exit(main())
