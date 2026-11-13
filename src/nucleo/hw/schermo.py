"""Schermo: luminosità (brightnessctl), uscite (wlr-randr), luce notturna (wlsunset)."""

from __future__ import annotations

import json

from ..sistema import avvia, config_utente, esegui, esiste, leggi_json, scrivi_json, uscita


def luminosita() -> int | None:
    if not esiste("brightnessctl"):
        return None
    campi = uscita(["brightnessctl", "-m", "-c", "backlight"], timeout=5).strip().split(",")
    if len(campi) >= 4:
        try:
            return int(campi[3].rstrip("%"))
        except ValueError:
            return None
    return None


def imposta_luminosita(percentuale: int) -> int | None:
    percentuale = max(5, min(100, int(percentuale)))
    esegui(["brightnessctl", "-q", "-c", "backlight", "set", f"{percentuale}%"], timeout=5)
    return luminosita()


def cambia_luminosita(passo: int) -> int | None:
    attuale = luminosita()
    if attuale is None:
        return None
    return imposta_luminosita(attuale + passo)


def uscite() -> list[dict]:
    """Monitor collegati con modalità disponibili."""
    try:
        dati = json.loads(uscita(["wlr-randr", "--json"], timeout=5) or "[]")
    except json.JSONDecodeError:
        return []
    risultato = []
    for u in dati:
        modi = [f'{m["width"]}x{m["height"]}@{m["refresh"]:.3f}' for m in u.get("modes", [])]
        attuale = next((f'{m["width"]}x{m["height"]}@{m["refresh"]:.3f}'
                        for m in u.get("modes", []) if m.get("current")), "")
        risultato.append({
            "nome": u.get("name", ""), "descrizione": u.get("description", u.get("name", "")),
            "attivo": u.get("enabled", True), "modo": attuale, "modi": sorted(set(modi), reverse=True),
            "scala": u.get("scale", 1.0), "x": u.get("position", {}).get("x", 0),
            "y": u.get("position", {}).get("y", 0), "rotazione": u.get("transform", "normal"),
        })
    return risultato


def applica_uscita(nome: str, modo: str = "", scala: float | None = None, attivo: bool = True,
                   posizione: str = "", rotazione: str = "") -> dict:
    cmd = ["wlr-randr", "--output", nome]
    if not attivo:
        cmd.append("--off")
    else:
        cmd.append("--on")
        if modo:
            cmd += ["--mode", modo + ("Hz" if "@" in modo else "")]
        if scala:
            cmd += ["--scale", str(scala)]
        if posizione:
            cmd += ["--pos", posizione]
        if rotazione:
            cmd += ["--transform", rotazione]
    r = esegui(cmd, timeout=10)
    if r.returncode == 0:
        salva_configurazione_schermi()
    return {"ok": r.returncode == 0, "messaggio": r.stderr.strip()}


def salva_configurazione_schermi() -> None:
    """Salva la disposizione per riapplicarla al prossimo accesso."""
    scrivi_json(config_utente("schermi.json"), uscite())


def ripristina_configurazione_schermi() -> None:
    for u in leggi_json(config_utente("schermi.json"), []):
        if any(x["nome"] == u["nome"] for x in uscite()):
            cmd = ["wlr-randr", "--output", u["nome"]]
            if not u.get("attivo", True):
                cmd.append("--off")
            else:
                if u.get("modo"):
                    cmd += ["--mode", u["modo"] + "Hz"]
                cmd += ["--scale", str(u.get("scala", 1.0)), "--pos", f'{u.get("x", 0)},{u.get("y", 0)}']
            esegui(cmd, timeout=10)


# ── Luce notturna ─────────────────────────────────────────────────────────────
def luce_notturna() -> dict:
    pref = leggi_json(config_utente("luce-notturna.json"), {"attiva": False, "temperatura": 4000})
    pref["in_esecuzione"] = esegui(["pgrep", "-x", "wlsunset"]).returncode == 0
    return pref


def imposta_luce_notturna(attiva: bool, temperatura: int = 4000) -> dict:
    scrivi_json(config_utente("luce-notturna.json"), {"attiva": attiva, "temperatura": temperatura})
    esegui(["pkill", "-x", "wlsunset"])
    if attiva:
        # Sempre attiva: alba alle 00:01 e tramonto alle 00:00 equivalgono a notte continua
        avvia(["wlsunset", "-t", str(temperatura), "-T", "6500", "-S", "00:01", "-s", "00:00"])
    return luce_notturna()
