# Installare SolidOS Mobile sul Huawei P10 Lite

SolidOS Mobile si basa su postmarketOS (dispositivo `huawei-warsaw`). Il sistema
**parte dalla scheda microSD**. Sul telefono si sostituiscono solo due piccole
partizioni (`kernel` e `ramdisk`): Android e i tuoi dati restano nella memoria
interna. Lo sblocco del bootloader, però, cancella tutto.

> **Cosa funziona:** schermo, tocco, Wi-Fi, Solid ID e Dov'è (con la posizione dal Wi-Fi).
> Funzionano anche le app di SolidOS: Note, File, Foto, Calcolatrice, Contatti,
> Impostazioni e Vicina (manda e ricevi file con il PC).
> **Cosa non funziona ancora:** chiamate, SMS, dati mobili, audio (quindi Musica resta muta),
> Bluetooth, GPS e fotocamera. Le app dello Store (Flathub) si installano, ma non si aprono:
> il P10 Lite non ha un driver grafico moderno, quindi gira solo l'interfaccia di SolidOS.
> Il kernel di postmarketOS per questo telefono è vecchio (4.4) e non più mantenuto.
> Per ora il P10 Lite è un telefono di prova, non da usare tutti i giorni.

## Cosa serve

- Il telefono **WAS-LX1, WAS-LX1A o WAS-LX2**: controlla in Impostazioni › Info sul telefono.
- Una scheda **microSD** da almeno 4 GB. Verrà cancellata.
- Un cavo USB.
- Un **PC Windows** per lo sblocco (PotatoNV funziona solo su Windows).
- `fastboot`, che fa parte degli Android Platform Tools di Google. Su Mac: `brew install android-platform-tools`.
- Un cacciavite piccolo, una ventosa e un plettro per aprire il retro, più una pinzetta di metallo.

## 1. Fai una copia dei tuoi dati

Lo sblocco del bootloader **cancella tutto il telefono**.

## 2. Sblocca il bootloader (una volta sola)

Huawei non dà più i codici di sblocco. Per il chip Kirin 658 c'è
[PotatoNV](https://github.com/mashed-potatoes/PotatoNV), gratuito, che scrive un codice di sblocco tuo.

1. Sul PC Windows installa i driver «Huawei testpoint» e PotatoNV (link nella pagina del progetto).
2. Spegni il telefono e apri il retro. Stacca il connettore della batteria.
3. Trova il **testpoint** del P10 Lite: cerca «WAS-LX1 testpoint» e guarda la foto della scheda.
   Tocca il testpoint con la pinzetta e, sempre tenendolo, collega il cavo USB al PC.
   In Gestione dispositivi compare «USB SER».
4. In PotatoNV scegli **Kirin 65x (A)**, scrivi un codice di 16 caratteri a tua scelta e premi *Start*.
   **Segnati il codice.**
5. Ricollega la batteria e chiudi il telefono. Poi entra in modalità fastboot: telefono spento,
   cavo collegato, tieni premuti **Volume giù + Accensione**.
6. Dal computer:
   ```
   fastboot oem unlock IL-TUO-CODICE
   ```
   Conferma sul telefono. Il telefono si cancella e si riavvia.

## 3. Scarica SolidOS Mobile

Dalla pagina [Releases](https://github.com/Paki7235/SolidOS-Mobile/releases) scarica
**SolidOS-Mobile-P10-Lite.zip** ed estrailo. Contiene `kernel.img`, `ramdisk.img`,
`solidos-mobile-sd.img` e `LEGGIMI.txt`.

## 4. Prepara la microSD

Scrivi `solidos-mobile-sd.img` sulla microSD con **balenaEtcher**, oppure da Mac:
```
diskutil list                                   # trova la microSD, per esempio /dev/disk4
diskutil unmountDisk /dev/disk4
sudo dd if=solidos-mobile-sd.img of=/dev/rdisk4 bs=4m status=progress
```
Controlla bene il numero del disco: `dd` cancella il disco che gli indichi.
Poi inserisci la microSD nel telefono.

## 5. Scrivi kernel e ramdisk

Metti il telefono in modalità fastboot (Volume giù + Accensione con il cavo collegato) e scrivi:
```
fastboot flash kernel kernel.img
fastboot flash ramdisk ramdisk.img
fastboot reboot
```
Dopo il logo compare la schermata di blocco di SolidOS. Il primo avvio è più lento.

- Utente `solid`, password `solidos`. Ti servono solo per il terminale.
  Cambiala con `passwd`.
- Il codice di sblocco del telefono si imposta in Impostazioni › Codice di sblocco.

## Tornare ad Android

Scarica il firmware originale del tuo modello (file `UPDATE.APP`). Estrai
`KERNEL.img` e `RAMDISK.img` con *Huawei Update Extractor* e scrivili di nuovo:
```
fastboot flash kernel KERNEL.img
fastboot flash ramdisk RAMDISK.img
fastboot reboot
```

## Se qualcosa non va

- **Schermo nero ma il telefono è acceso:** è la luminosità a zero. SolidOS la alza
  all'avvio. Se non basta, collega il telefono al PC: compare una rete USB, e il
  telefono risponde all'indirizzo 172.16.42.1.
- **Riparte sempre da Android o resta sul logo:** controlla che la microSD sia
  inserita bene e che l'immagine sia stata scritta per intero.
