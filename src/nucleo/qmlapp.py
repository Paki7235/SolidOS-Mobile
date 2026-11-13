"""Avvio comune delle app QML: tema, traduzioni, ponte Python ↔ QML."""

from __future__ import annotations

import os
import signal
import sys
from pathlib import Path

from . import branding
from .i18n import T

CARTELLA_QML = Path(os.environ.get("NUCLEO_QML", "/usr/share/nucleo/qml"))
if not CARTELLA_QML.is_dir():
    CARTELLA_QML = Path(__file__).resolve().parents[1] / "qml"


SCALE_TESTO = {"9": 0.9, "10": 1.0, "11": 1.1, "12": 1.2, "14": 1.35}


def _scala_testo() -> float:
    """Impostazioni › Aspetto › Dimensione del testo (e Accessibilità › Testo grande)."""
    try:
        from .sistema import config_utente, leggi_json

        return SCALE_TESTO.get(str(leggi_json(config_utente("aspetto.json"), {}).get("font_dimensione", "10")), 1.0)
    except OSError:
        return 1.0


def prepara_ambiente(layer_shell: bool = False, software: bool | None = None) -> None:
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")
    if not layer_shell:
        scala = _scala_testo()
        if abs(scala - 1.0) > 0.01:
            os.environ["QT_SCALE_FACTOR"] = f"{scala:g}"
        else:
            os.environ.pop("QT_SCALE_FACTOR", None)
    if layer_shell:
        os.environ["QT_WAYLAND_SHELL_INTEGRATION"] = "layer-shell"
    if software is None:
        software = os.environ.get("GRAFICA_SICURA") == "1" or _profilo_leggero()
    if software:
        os.environ["QT_QUICK_BACKEND"] = "software"


def _profilo_leggero() -> bool:
    return Path(f"/etc/{branding.id_os()}/profilo-leggero").exists()


def crea_app(nome_app: str, argv: list[str] | None = None):
    from PyQt6.QtGui import QFont, QGuiApplication, QIcon

    app = QGuiApplication(argv if argv is not None else sys.argv)
    # Qt ha già letto l'integrazione Wayland: la variabile non deve passare ai programmi
    # avviati da qui (dock, Start, Barra Unica), altrimenti si aprirebbero come pannelli
    # di sistema senza barra del titolo, a tutto schermo e impossibili da chiudere.
    os.environ.pop("QT_WAYLAND_SHELL_INTEGRATION", None)
    app.setApplicationName(nome_app)
    app.setOrganizationName(branding.nome())
    app.setDesktopFileName(branding.comando(nome_app))
    font = QFont(branding.get("FONT_UI", "Inter"))
    font.setPointSize(int(branding.get("FONT_UI_DIMENSIONE", "10") or 10))
    app.setFont(font)
    # Percorsi standard dei temi di icone: senza sessione grafica (o con alcune piattaforme)
    # Qt cerca solo al proprio interno e ogni icona diventerebbe un quadrato bianco
    percorsi = list(QIcon.themeSearchPaths())
    dati = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
    for p in [str(Path.home() / ".local/share/icons"), str(Path.home() / ".icons")] + [d.rstrip("/") + "/icons" for d in dati if d]:
        if p not in percorsi and Path(p).is_dir():
            percorsi.append(p)
    QIcon.setThemeSearchPaths(percorsi)
    app.setWindowIcon(QIcon.fromTheme(f"{branding.id_os()}-logo-chiaro"))
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    return app


class Traduttore:
    """Oggetto «I18n» esposto al QML: I18n.t("testo")."""

    def __new__(cls):
        from PyQt6.QtCore import QObject, pyqtSlot

        class _I18n(QObject):
            @pyqtSlot(str, result=str)
            def t(self, testo: str) -> str:
                return T(testo)

        return _I18n()


def tema_effettivo() -> dict:
    """Tema del branding con le preferenze dell'utente (chiaro/scuro, accento)."""
    from .sistema import config_utente, leggi_json

    base = branding.tema()
    try:
        pref = leggi_json(config_utente("aspetto.json"), {})
    except OSError:   # es. schermata di accesso: utente di sistema senza home scrivibile
        pref = {}
    if pref.get("accento"):
        base["accento"] = pref["accento"]
    chiaro = pref.get("tema") == "chiaro"
    if chiaro:
        base.update({
            "sfondo": base["sfondoChiaro"], "superficie": "#FFFFFF",
            "superficieAlta": "#E9E9EE", "testo": base["testoScuro"],
            "testoSecondario": "#6E6E73", "bordo": "#E5E5EA",
        })
        if not pref.get("accento"):
            base["accento"] = base["accentoScuro"]   # più contrasto su fondo chiaro
    else:
        base.update({"superficieAlta": "#2F3037", "testoSecondario": "#A1A1AA", "bordo": "#3A3B42"})
    # Colori della shell (barra, dock, menu, Start, centro di controllo): seguono il tema
    if chiaro:
        base.update({
            "vetro": "#F2F6F6F8", "vetroBordo": "#1F000000", "barra": "#E0F4F4F6", "dock": "#D9F4F4F6",
            "sopra": "#12000000", "premuto": "#24000000", "separatore": "#1A000000",
            "testoVetro": "#1D1D1F", "testoVetroSecondario": "#6E6E73", "nuvola": "#F2FFFFFF",
        })
    else:
        base.update({
            "vetro": "#F21C1D22", "vetroBordo": "#24FFFFFF", "barra": "#C70C0E14", "dock": "#B8282A32",
            "sopra": "#1FFFFFFF", "premuto": "#33FFFFFF", "separatore": "#1FFFFFFF",
            "testoVetro": "#F5F5F7", "testoVetroSecondario": "#A1A1AA", "nuvola": "#E6202126",
        })
    # Disposizione: «mac» (barra in alto + dock) o «windows» (una sola barra in basso)
    base["stileBarra"] = "windows" if pref.get("barra") == "windows" else "mac"
    base["dockLato"] = int(pref.get("dockLato", 48)) if str(pref.get("dockLato", 48)).isdigit() else 48
    base["barraPrestazioni"] = pref.get("barraPrestazioni", True) is not False
    base["chiaro"] = chiaro
    base["logo"] = base["idSistema"] + ("-logo" if chiaro else "-logo-chiaro")
    base["pericolo"] = "#E5484D"
    base["successo"] = "#30A46C"
    base["avviso"] = "#F5A524"
    base["raggio"] = 10
    base["animazioni"] = not _profilo_leggero()
    return base


def _provider_icone():
    from PyQt6.QtCore import QSize
    from PyQt6.QtGui import QIcon, QPixmap
    from PyQt6.QtQuick import QQuickImageProvider

    class ProviderIcone(QQuickImageProvider):
        """image://icona/<nome-icona-del-tema> oppure image://icona/<percorso-assoluto>"""

        def __init__(self):
            super().__init__(QQuickImageProvider.ImageType.Pixmap)

        def requestPixmap(self, ident, richiesta, *_):
            lato = max(richiesta.width(), richiesta.height(), 0) or 48
            nome = ident.split("?")[0]
            icona = QIcon(nome) if nome.startswith("/") else QIcon.fromTheme(nome)
            if icona.isNull():
                icona = QIcon.fromTheme("application-x-executable")
            pixmap = icona.pixmap(QSize(lato, lato))
            if pixmap.isNull():
                pixmap = QPixmap(lato, lato)
                pixmap.fill()
            return pixmap, pixmap.size()

    return ProviderIcone()


def _segui_tema(motore, radice) -> None:
    """Quando cambia aspetto.json (tema chiaro/scuro, accento, stile della barra)
    il nuovo Tema arriva subito a tutte le finestre aperte, senza riavviarle."""
    from PyQt6.QtCore import QFileSystemWatcher, QTimer
    from PyQt6.QtGui import QIcon

    from .sistema import config_utente

    try:
        file = config_utente("aspetto.json")
        file.parent.mkdir(parents=True, exist_ok=True)
    except OSError:
        return
    osservatore = QFileSystemWatcher([str(file.parent)])
    ritardo = QTimer()
    ritardo.setSingleShot(True)
    ritardo.setInterval(150)
    ultimo = {"tema": tema_effettivo()}

    def applica():
        nuovo = tema_effettivo()
        if nuovo == ultimo["tema"]:
            return
        if nuovo["chiaro"] != ultimo["tema"]["chiaro"]:
            nome = QIcon.themeName()
            base = branding.id_os()
            if nome in (base, base + "-chiaro"):
                QIcon.setThemeName(base + "-chiaro" if nuovo["chiaro"] else base)
        ultimo["tema"] = nuovo
        radice.setContextProperty("Tema", nuovo)

    ritardo.timeout.connect(applica)
    osservatore.directoryChanged.connect(lambda _p: ritardo.start())
    motore._osservatore_tema = (osservatore, ritardo)


def carica(app, file_qml: str, contesto: dict | None = None):
    """Crea il motore QML, espone Tema, I18n e gli oggetti del contesto, carica il file."""
    from PyQt6.QtQml import QQmlApplicationEngine

    motore = QQmlApplicationEngine()
    motore.addImportPath(str(CARTELLA_QML))
    motore.addImageProvider("icona", _provider_icone())
    radice = motore.rootContext()
    radice.setContextProperty("Tema", tema_effettivo())
    _segui_tema(motore, radice)
    i18n = Traduttore()
    radice.setContextProperty("I18n", i18n)
    motore._trattieni = [i18n]  # evita la raccolta del garbage collector
    for nome, oggetto in (contesto or {}).items():
        radice.setContextProperty(nome, oggetto)
        motore._trattieni.append(oggetto)
    percorso = CARTELLA_QML / file_qml
    motore.load(str(percorso))
    if not motore.rootObjects():
        print(f"Impossibile caricare {percorso}", file=sys.stderr)
        sys.exit(1)
    return motore


def esegui_app(nome_app: str, file_qml: str, contesto_fn=None, layer_shell: bool = False) -> int:
    """Scorciatoia: prepara, crea l'app, costruisce il contesto e avvia il ciclo eventi."""
    prepara_ambiente(layer_shell=layer_shell)
    app = crea_app(nome_app)
    contesto = contesto_fn(app) if contesto_fn else {}
    motore = carica(app, file_qml, contesto)
    codice = app.exec()
    del motore
    return codice
