# SolidOS Mobile

Il sistema operativo per telefoni della famiglia **SolidOS**: leggero (pensato per telefoni con **2 GB di RAM**),
in italiano, con lo stesso stile e le stesse icone di SolidOS per PC, e un ecosistema con il computer
(chiamate e messaggi sul PC, appunti condivisi, «Continua qui», Solid ID e «Dov'è»).

## Stato

Prima versione dell'**interfaccia del telefono**:

- **Blocco**: data, ora grande (carattere a scelta), batteria, rete e Bluetooth; si entra scorrendo in su.
- **Home**: widget (data, batterie dei dispositivi del Solid ID), app con le icone del tema di sistema, ricerca e Dock.
- **Libreria app**: scorrendo a sinistra, app raggruppate per tipo, con ricerca.
- **Notifiche** (dall'angolo in alto a sinistra) e **Centro di controllo** (in alto a destra): Wi-Fi e Bluetooth,
  luminosità e volume agiscono davvero sul sistema.
- **Personalizza**: tema scuro/chiaro, grandezza del testo, colore, sfondo, orologio, grandezza delle icone,
  navigazione a gesti o a tre tasti. Le scelte restano in `~/.config/solidos/mobile.json`.

Da fare: telefonia (chiamate, SMS, dati mobili con ModemManager), notifiche di sistema, fotocamera,
immagine installabile sui telefoni supportati. Il piano completo è in [docs/ECOSISTEMA.md](docs/ECOSISTEMA.md).

## Provarlo

Su Debian/Ubuntu con Qt 6:

```sh
sudo apt install python3-pyqt6 python3-pyqt6.qtquick qml6-module-qtquick-controls qml6-module-qtquick-layouts papirus-icon-theme fonts-inter
scripts/anteprima.sh                                  # si apre una finestra grande come un telefono
scripts/anteprima.sh --schermata=home --tema=chiaro   # direttamente una schermata
```

Ogni modifica pubblicata su GitHub fotografa da sola tutte le schermate, in tema scuro e chiaro
(scheda **Actions** › **Anteprima** › artefatto «foto-schermate»).

## Struttura

- `src/qml/Mobile/` — l'interfaccia del telefono (QML)
- `src/nucleo/mobile/` — la parte di sistema (impostazioni, app installate, batteria, rete, audio, schermo)
- `src/nucleo/`, `src/qml/SolidUI/` — il nucleo comune con SolidOS per PC
- `src/nucleo/solidid/` — Solid ID e «Dov'è»

## Licenza

GPL-3.0 (vedi [LICENSE](LICENSE)).
