# Ecosistema SolidOS e SolidOS Mobile — piano

Obiettivo: ottenere tra telefono e computer quello che Apple chiama *Continuità*,
ma aperto, senza cloud obbligatorio, e con un sistema per il telefono leggero
(deve girare bene con **2 GB di RAM**).

## 1. Che cosa fa l'ecosistema Apple (da replicare)

| Funzione Apple | Che cosa fa | Equivalente SolidOS |
|---|---|---|
| Chiamate su Mac/iPad | Rispondere e chiamare dal computer con il numero del telefono | **Chiamate**: con il Bluetooth vivavoce (HFP) il PC fa da «auto»: suona, rispondi, parli col microfono del PC |
| Messaggi (SMS) | Leggere e rispondere agli SMS dal computer | **Messaggi**: conversazioni del telefono sul PC |
| Notifiche iPhone su Mac (Mirroring) | Le notifiche del telefono sul computer | Notifiche del telefono nel Centro notifiche, con risposta rapida |
| Appunti universali | Copi sul telefono, incolli sul PC e viceversa | **Appunti condivisi** (testo, immagini, link) |
| Handoff | Inizi una cosa su un dispositivo e la finisci sull'altro | **Continua qui**: la pagina di Vela, la nota, il documento aperto compaiono nel Dock dell'altro dispositivo |
| AirDrop | Inviare file vicino | **Condivisione Vicina** (già c'è: Quick Share, LocalSend, QR) |
| Hotspot istantaneo | Il Mac si collega alla rete del telefono con un clic | **Hotspot istantaneo** nel menu Wi-Fi |
| Sblocco con Apple Watch | Il computer si sblocca se hai il dispositivo vicino | **Sblocco col telefono vicino** (facoltativo, Bluetooth) |
| Fotocamera Continuità | Il telefono fa da webcam o scanner | Telefono come webcam e **scanner di documenti** verso il PC |
| Trova il mio | Far suonare / trovare il dispositivo | **Trova il telefono** (lo fa suonare anche in silenzioso) |
| Controllo universale | Un mouse e una tastiera per più dispositivi | Telefono come touchpad/telecomando; più avanti tastiera e mouse condivisi tra PC |
| iCloud (Note, Foto…) | Gli stessi dati su tutti i dispositivi | **Sincronizzazione diretta** tra i propri dispositivi (Note, Foto, preferiti di Vela), senza server, cifrata |

## 2. Come lo facciamo (le basi tecniche)

- **Protocollo di collegamento: KDE Connect.** È aperto, cifrato (TLS) e maturo, e fa già
  notifiche, SMS, appunti, chiamate in arrivo, batteria, file, telecomando e «trova telefono».
  Vantaggio enorme: **funziona subito con qualsiasi telefono Android** con l'app gratuita
  KDE Connect (Play Store / F-Droid), e lo useremo uguale su SolidOS Mobile.
  Su SolidOS lo scriviamo noi in Python (`nucleo/insieme/`), leggero e con la nostra grafica,
  invece di installare tutto KDE.
- **Chiamate con la voce sul PC: Bluetooth HFP** (BlueZ + PipeWire + oFono). Il PC diventa
  un vivavoce come quello dell'auto: funziona con **Android e anche con iPhone**.
- **iPhone:** Apple non permette il collegamento completo. Con il Bluetooth arrivano comunque
  chiamate (HFP) e, dove l'iPhone lo concede, notifiche (ANCS) e messaggi (MAP). Il resto
  (appunti, Handoff) solo tra dispositivi SolidOS e Android.
- **Nessun account obbligatorio:** i dispositivi si associano con un codice QR, come le cuffie.
  Ogni coppia ha le sue chiavi; i dati passano solo in rete locale o Bluetooth.

## 3. SolidOS Mobile (il sistema per il telefono)

Cosa va detto chiaro: **un sistema per telefoni non si installa su qualsiasi telefono.**
Ogni modello ha componenti diversi (modem, fotocamera, schermo) e serve che qualcuno ne
abbia scritto il supporto. Le strade sono due, entrambe compatibili con la nostra base Debian:

1. **Kernel «mainline» (postmarketOS/Mobian):** decine di telefoni già funzionanti
   (es. OnePlus 6/6T, Xiaomi Poco F1, Pixel 3a, Fairphone, PinePhone, Librem 5).
   Più pulito e longevo; non tutto funziona su ogni modello (fotocamera spesso no).
2. **Driver Android riusati (Droidian, Debian + Halium):** gira su telefoni Android
   più recenti (soprattutto Pixel e alcuni Xiaomi/Samsung), con chiamate, dati e spesso fotocamera.

Come lo rendiamo leggero (obiettivo: avvio sotto i **600 MB di RAM** usati, sistema sotto i **4 GB**):
- stessa base di SolidOS PC: **Debian + labwc/compositore Wayland leggero + interfaccia Qt/QML**,
  niente GNOME o KDE completi;
- una **shell per il tocco** nostra (schermata di blocco, Home con icone, centro di controllo
  a tendina, app recenti con gesti), riusando i componenti già fatti (Tema, SolidUI, Note, Vela, File, Foto…);
- telefonia con **ModemManager** (chiamate, SMS, dati) e app nostre: Telefono, Messaggi, Contatti;
- memoria compressa (zram, già usata nel profilo «PC vecchio»), servizi avviati solo quando servono,
  app Android solo su richiesta (Waydroid, che però pesa: facoltativo).

### Telefono di prova: Huawei P10 Lite (WAS-LX1, Kirin 658, 3–4 GB RAM)
- postmarketOS ha già un port (`huawei-warsaw`) con kernel Android 4.4: si avvia, ma di solito
  su questi port **chiamate, fotocamera e grafica accelerata non funzionano** o funzionano male.
  Va bene per sviluppare e provare l'interfaccia, non per un telefono di tutti i giorni.
- Prima va **sbloccato il bootloader**: Huawei non dà più i codici dal 2018; si può con PotatoNV,
  ma bisogna **aprire il telefono** e toccare un punto sulla scheda («testpoint»). Cancella tutti i dati.
- Per un SolidOS Mobile fluido e con chiamate sicure servirà un modello ben supportato
  (es. Google Pixel 3a o OnePlus 6/6T usati, circa 60–100 €).
- Il P10 Lite intanto serve benissimo **da subito** per l'ecosistema col PC (fasi E1–E3), con Android com'è.

### Scelte già fatte
- La schermata di avvio del telefono è **identica a quella del PC** (stesso logo e animazione Plymouth).
- Il sistema deve essere **fluido e affidabile** prima che ricco: ogni funzione entra solo se va bene.
- Il **design** del telefono si decide insieme, schermata per schermata.
- Funzioni: **il meglio di Android e di iPhone insieme**, cioè a ciascuno quello che manca dall'altro.
  Da iPhone: Isola dinamica/attività in corso, Handoff, AirDrop, privacy chiara, aggiornamenti per anni,
  schermata di blocco personalizzabile, Face/Touch ID ben integrati.
  Da Android: libertà di installare app e file, widget ovunque, launcher e gesti personalizzabili,
  doppia SIM e scheda SD, cartelle e File completi, registrazione chiamate dove è legale, app predefinite a scelta.

## 3b. Solid ID e «Dov'è» (come Apple ID e Dov'è)

Un account unico per tutti i dispositivi SolidOS (PC e telefono), su **Supabase**
(autenticazione + database Postgres + tempo reale), nel piano gratuito.

- **Creazione:** nella configurazione iniziale (e in Impostazioni › Solid ID): nome, email, password;
  conferma con il codice ricevuto per email. Facoltativo: si può usare SolidOS anche senza.
- **Dispositivi:** ogni PC/telefono collegato compare nell'elenco dell'account (nome, modello, ultima volta visto).
- **Dov'è** (app identica su PC e telefono): mappa con la posizione dei propri dispositivi;
  azioni **Fai suonare**, **Blocca e mostra un messaggio** (es. numero da chiamare), **Inizializza** (cancella i dati);
  notifica quando un dispositivo torna in linea. Posizione: GPS sul telefono, Wi-Fi/IP sul PC.
- **Sicurezza:** Row Level Security in Supabase (ogni utente vede solo i propri dispositivi);
  nell'app c'è solo la chiave pubblica (anon), mai quella segreta; i comandi pericolosi
  (inizializza) chiedono la password; la posizione si invia solo se l'utente attiva «Dov'è».
- **Blocco di attivazione:** un dispositivo inizializzato da remoto chiede il Solid ID del proprietario
  prima di poter essere riconfigurato (dove l'hardware lo permette).
- **Altro con lo stesso account (dopo):** sincronizzazione di Note, preferiti di Vela, impostazioni;
  associazione automatica dei propri dispositivi per l'ecosistema (niente QR tra dispositivi dello stesso ID).

Tabelle previste: `dispositivi` (id, proprietario, nome, tipo, modello, ultimo_visto),
`posizioni` (dispositivo, lat, lon, precisione, quando), `comandi` (dispositivo, tipo, messaggio, stato),
ricevuti in tempo reale dal dispositivo.

## 4. Ordine di lavoro proposto

| Fase | Cosa | Funziona con |
|---|---|---|
| ID | **Solid ID** (account su Supabase) e **Dov'è** su PC (poi sul telefono) | PC, telefono SolidOS; Android con app web |
| E1 | **Collegamento telefono** in SolidOS PC: associazione con QR, notifiche, SMS, appunti, batteria, trova telefono, file. Nuova app «Telefono» e voce in Impostazioni | Android (app KDE Connect) |
| E2 | **Chiamate sul PC** via Bluetooth vivavoce: suoneria, rispondi/rifiuta, audio su PC, rubrica | Android e iPhone |
| E3 | **Continua qui** (Handoff), appunti universali con immagini, hotspot istantaneo, sblocco col telefono vicino | Android/SolidOS |
| M1 | **SolidOS Mobile su un telefono di prova**: avvio, shell al tocco, Wi-Fi, impostazioni, app esistenti adattate | 1 modello scelto |
| M2 | Telefonia sul telefono: Telefono, Messaggi, Contatti, dati mobili | stesso modello |
| M3 | Ecosistema completo tra SolidOS PC e SolidOS Mobile (tutto quanto sopra, più sincronizzazione Note/Foto) | PC + telefono |

Le fasi E1–E3 servono subito anche a chi tiene il proprio telefono Android.

## Fonti studiate
- Continuità Apple: https://www.apple.com/macos/continuity/
- KDE Connect: https://userbase.kde.org/KDEConnect — https://f-droid.org/packages/org.kde.kdeconnect_tp/
- Chiamate da Linux col Bluetooth HFP: https://sipfront.com/blog/2025/03/automating-calls-on-real-mobile-devices-with-bluetooth-hfp-on-a-raspberry-pi/ — https://collabora.com/news-and-blog/news-and-events/pipewire-bluetooth-support-status-update.html
- postmarketOS 26.06: https://postmarketos.org/blog/2026/06/21/v26.06-release/
- Droidian: https://wiki.postmarketos.org/wiki/Droidian
- Port P10 Lite: https://pkgs.postmarketos.org/package/main/postmarketos/aarch64/device-huawei-warsaw
- PotatoNV (sblocco Kirin 65x): https://github.com/mashed-potatoes/PotatoNV
