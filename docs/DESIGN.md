# Sistema di design di SolidOS Mobile

Regole uniche per tutta l'interfaccia del telefono. I valori stanno in `src/qml/Mobile/Main.qml`
(`tel.pal`, misure e movimento): nei componenti si usano quei nomi, mai colori o durate scritti a mano.

## Stile
**Modern Dark**: ardesia profonda (mai nero puro: sugli OLED lascia scie), superfici a strati,
bordi sottili, sfondi disegnati dal sistema con due aloni di colore fermi (niente animazioni
continue decorative: distraggono e consumano batteria). Il tema chiaro è progettato insieme a
quello scuro, non ricavato invertendo i colori.

## Colori (`tel.pal`)
| Ruolo | Scuro | Chiaro | Uso |
|---|---|---|---|
| `sfondo` | `#0F172A` | `#F8FAFC` | fondo delle app |
| `superficie` | `#1E293B` | `#FFFFFF` | schede, righe |
| `superficie2` | `#272F42` | `#E9EDF1` | campi, pulsanti, tasti spenti |
| `bordo` | ardesia 16% | `#E2E8F0` | bordi e separatori |
| `testo` | `#F8FAFC` | `#0F172A` | testo principale (contrasto ≥ 7:1) |
| `testo2` | `#94A3B8` | `#64748B` | testo secondario (≥ 4,5:1) |
| `testo3` | `#64748B` | `#94A3B8` | suggerimenti |
| `vetro` | ardesia 78% | bianco 80% | pannelli sopra lo sfondo |
| `successo` / `pericolo` | `#22C55E` / `#EF4444` | uguali | stati (sempre con testo o icona) |
| `tel.accento` | scelto in Personalizza | | azione principale, interruttori accesi |

## Testo
Carattere **Plus Jakarta Sans** (licenza SIL OFL, in `src/dati/font`). Grandezze: 11–12 etichette,
13–14 secondario, 15–16 corpo, 20 titoli di sezione, 26–30 titoli di pagina, 34+ ore (peso leggero).
Tutte passano da `tel.px()`, che segue «Grandezza del testo».

## Misure
Margine dello schermo `tel.margine` (18), raggi `tel.r1` 12 · `tel.r2` 18 · `tel.r3` 24,
spaziature a passi di 4/8. Zone da toccare almeno 44×44. Le posizioni dipendono dall'altezza
dello schermo: sui telefoni più bassi si mostra meno, senza sovrapporre.

## Icone
App: le stesse di SolidOS per PC (tema Papirus); per le app solo del telefono (Telefono, Messaggi,
Contatti, Fotocamera, Musica, Dov'è) icone proprie in `src/dati/icone`. Icone dei comandi
(`-symbolic`): ricolorate dal sistema, scure sui fondi chiari e chiare sui fondi scuri; sui colori
pieni si forza `tema: "scuro"` (bianche).

## Movimento
| Token | Valore | Uso |
|---|---|---|
| `tel.tVeloce` | 150 ms | pressione, piccoli cambi di stato |
| `tel.tNormale` | 240 ms | chiusure, dissolvenze |
| `tel.tEntrata` | 380 ms | aperture di pagine e tendine |

- Entrare: curva «expo» (`Easing.OutExpo`); uscire più in fretta accelerando (`Easing.InCubic`, ~65%).
  Componente comune: `Movimento { apre: … }`.
- Pressione: scala al 97% e leggera opacità, in ≤ 150 ms.
- Griglia della Home: entrata scaglionata (35 ms a icona), sale di 16 px con un piccolo rimbalzo.
- Gesti: il contenuto segue il dito (sblocco); se si lascia prima della soglia torna al posto
  con una piccola molla.
- **Riduci animazioni** (Impostazioni › Schermo): tutte le durate diventano 0.
