# Sistema di design di SolidOS Mobile · «Essenziale»

Regole uniche per tutta l'interfaccia del telefono. I valori stanno in `src/qml/Mobile/Main.qml`
(`tel.pal`, misure, caratteri e movimento): nei componenti si usano quei nomi, mai colori o durate
scritti a mano.

## Stile
**Essenziale**: nero puro e bianco, numeri e titoli a puntini, icone a linea tutte uguali e un
solo colore, il **rosso**, per ciò che è nuovo o importante (notifiche, chiamate perse, «=»,
riaggancia). Superfici piene con un bordo di un pixel: sotto non si vede niente, così ogni
schermata resta ordinata su qualsiasi sfondo. Il tema chiaro è progettato insieme a quello scuro
(grigio chiarissimo, bianco e nero), non ricavato invertendo i colori.

## Colori (`tel.pal`)
| Ruolo | Scuro | Chiaro | Uso |
|---|---|---|---|
| `sfondo` | `#000000` | `#F2F2F2` | fondo delle app e del telefono |
| `superficie` / `vetro` | `#111111` | `#FFFFFF` | schede, pannelli, righe |
| `superficie2` | `#1C1C1C` | `#EBEBEB` | tondi, campi, tasti spenti |
| `bordo` / `vetroBordo` | `#262626` | `#DCDCDC` | bordo di 1 px, separatori |
| `testo` | `#FFFFFF` | `#000000` | testo principale |
| `testo2` | `#A3A3A3` | `#5C5C5C` | testo secondario (≥ 7:1) |
| `testo3` | `#6B6B6B` | `#949494` | suggerimenti |
| `pieno` / `suPieno` | bianco / nero | nero / bianco | tasti accesi, scelte attive, Dock |
| `tel.rosso` | `#FF3B30` | uguale | novità, errori, azioni che chiudono |
| `successo` | `#30D158` | uguale | solo «rispondi» e chiamata in corso |

Acceso = **pieno** (bianco nel tema scuro, nero nel chiaro), mai un colore. Le icone sopra un
fondo pieno si ricolorano con `tema: tel.chiaro ? "scuro" : "chiaro"`.

## Caratteri
In `src/dati/font`, tutti con licenza SIL OFL:
- **Doto** (`tel.fontPunti`, componente `Punti`): ora, numeri grandi, titoli delle app in maiuscolo.
- **Space Grotesk** (`Tema.font`): tutti i testi. Grandezze 12–14 secondario, 15–16 corpo, 17–19 titoli.
- **Space Mono** (`tel.fontMono`, componente `Mono`): etichette piccole in maiuscolo e spaziate
  («BATTERIA», «12 MIN FA»), orari, numeri di telefono.
Tutte le grandezze del testo passano da `tel.px()`, che segue «Grandezza del testo».

## Componenti
`Vetro` (scheda piena con bordo) · `Punti` · `Mono` · `TitoloApp` (titolo a puntini con i tasti a
destra) · `TastoTondo` (tondo grigio o pieno con icona) · `Avatar` (iniziali, puntino rosso) ·
`CampoCerca` (pillola con bordo) · `BarraPunti` (batteria, luminosità, volume fatti di puntini) ·
`IconaApp` (tondo con disegno a linea; nel Dock tondo pieno) · `SchedaNotifica`.

## Misure
Margine dello schermo `tel.margine` (20), raggi `tel.r1` 12 · `tel.r2` 20 · `tel.r3` 24 (schede 22–24,
pillole metà dell'altezza), spaziature a passi di 4/8. Zone da toccare almeno 44×44. Le posizioni
dipendono dall'altezza dello schermo: sui telefoni più bassi si mostra meno, senza sovrapporre.
La scala dello schermo la decide la sessione del telefono (`SOLIDOS_SCALA_SCHERMO`, circa 420
punti di larghezza) e si moltiplica per la dimensione del testo.

## Icone
Icone a linea (tratto 1,75, angoli tondi) generate da `scripts/genera-icone-linea.py` in
`src/dati/icone/linea`, con i nomi che l'interfaccia chiede (`network-wireless-symbolic`…) e
`linea-<app>` per le app di SolidOS. Il fornitore di icone le cerca per prime e le ricolora in
bianco o in nero. Le app dello Store mostrano la loro icona dentro il tondo.

## Movimento
| Token | Valore | Uso |
|---|---|---|
| `tel.tVeloce` | 140 ms | pressione, piccoli cambi di stato |
| `tel.tNormale` | 220 ms | chiusure, dissolvenze |
| `tel.tEntrata` | 340 ms | aperture di app e tendine |

- Entrare: curva «quint» (`Easing.OutQuint`), parte veloce e si posa morbida; uscire più in fretta
  (`Easing.InQuad`, ~65%). Componente comune: `Movimento { apre: … }`. Niente rimbalzi.
- App: si aprono ingrandendosi dal 94% e comparendo, mentre la Home arretra e si spegne.
- Tendine (notifiche, centro di controllo): scendono di 60 px comparendo.
- Pressione: scala al 92–94%, in ≤ 140 ms; i tasti si riempiono di bianco.
- Home: le icone salgono di 12 px una dopo l'altra (30 ms a icona).
- Gesti: il contenuto segue il dito (sblocco, notifiche da scartare) e torna al posto se si lascia prima.
- **Riduci animazioni** (Impostazioni › Schermo): tutte le durate diventano 0.
