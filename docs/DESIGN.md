# Sistema di design di SolidOS Mobile · «Vetro»

Il telefono parla la stessa lingua del PC: stesso sfondo con le colline, stessi colori grafite e
blu, stesso carattere (Inter), stesse icone a colori. In più ha la finitura di un telefono di
oggi: pannelli di vetro, angoli morbidi, titoli grandi. I valori stanno in
`src/qml/Mobile/Main.qml` (`tel.pal`, misure, movimento): nei componenti si usano quei nomi.

## Colori (`tel.pal`), uguali al PC
| Ruolo | Scuro | Chiaro | Uso |
|---|---|---|---|
| `sfondo` | `#1E1F24` | `#F2F2F7` | fondo delle app |
| `superficie` | `#26272D` | `#FFFFFF` | schede, gruppi di righe |
| `superficie2` | `#2F3037` | `#E9E9EE` | campi, tasti, tondi spenti |
| `bordo` | `#3A3B42` | `#E5E5EA` | separatori |
| `testo` / `testo2` | `#F5F5F7` / `#A1A1AA` | `#1D1D1F` / `#6E6E73` | testo e secondario |
| `vetro` | grafite 58% | bianco 62% | velatura dei pannelli sopra lo sfondo |
| `tel.accento` | `#4C7DFF` | `#2F5FD0` | acceso, selezionato, azione principale |
| `successo` / `pericolo` | `#30A46C` / `#E5484D` | uguali | chiamata, batteria / errori, riaggancia |

## Vetro
`Vetro` è il pannello sopra lo sfondo (blocco, Home, Libreria, tendine, notifiche). Il vero
sfocato richiede la scheda video, che molti telefoni (e il telefono virtuale) non usano: per
questo il sistema legge i colori dello sfondo dall'alto in basso (`coloriSfondo`, 48 fasce) e
ogni pannello prende la sfumatura della zona che copre, con sopra la velatura e un bordo
sottile. L'effetto è quello del vetro sfocato e funziona ovunque. Dentro le app i pannelli sono
pieni (`sfocato: false`). Sotto le tendine c'è lo sfondo «sfocato» intero, che copre la Home.

## Testo
Inter (licenza OFL, in `src/dati/font`). Titoli delle app 32 grassetto, ora del blocco ~100
semibold, corpo 15–16, secondario 12–14. Tutto passa da `tel.px()` (Grandezza del testo).

## Componenti
`Vetro` · `TitoloApp` (titolo grande con i tasti a destra) · `TastoTondo` (grigio o blu) ·
`Avatar` (iniziali su sfumatura colorata, sempre la stessa per lo stesso nome) · `CampoCerca` ·
`IconaApp` (tessera a colori con il nome) · `SchedaNotifica` · `Mono` (etichetta piccola) ·
`Punti` (titolo grande).

## Misure
Margine 18, raggi 12 · 18 · 24 (pannelli 22–30, tasti tondi a metà dell'altezza), spaziature a
passi di 4/8, zone da toccare almeno 44×44. Le posizioni dipendono dall'altezza dello schermo.

## Icone
App: tessere a colori `nucleo-*` (`scripts/genera-icone.py`), le stesse per tutte le schermate.
Comandi: icone a linea (`scripts/genera-icone-linea.py`), ricolorate in bianco o grafite;
sui fondi colorati si forza `tema: "scuro"` (bianche).

## Movimento
`tVeloce` 150 ms · `tNormale` 230 ms · `tEntrata` 360 ms. Aperture con curva «quint», chiusure
più brevi (`Movimento { apre: … }`). Le app si aprono ingrandendosi dal 94% mentre la Home
arretra; le tendine scendono comparendo; pressione al 92–94%; icone della Home che salgono una
dopo l'altra. **Riduci animazioni**: tutte le durate a 0.
