# Installare SolidOS Mobile su un telefono

SolidOS Mobile si basa su postmarketOS: ogni telefono supportato ha la sua immagine,
un solo file zip nelle [Releases](https://github.com/Paki7235/SolidOS-Mobile/releases).
Dentro lo zip trovi `LEGGIMI.txt` con i comandi esatti per quel telefono.

## Quale telefono scegliere

| Telefono | Chiamate e SMS | Audio | Grafica (app dello Store) | Come si installa |
|---|---|---|---|---|
| **OnePlus 6 / 6T** | sì | sì | sì | fastboot, sblocco ufficiale |
| **Google Pixel 3a** | sì | sì | sì | fastboot, sblocco ufficiale |
| **Fairphone 4** | sì | sì | sì | fastboot, sblocco ufficiale |
| **SHIFT6mq** | sì | sì | sì | fastboot, sblocco ufficiale |
| **PinePhone Pro** | sì (in parte) | sì | sì | microSD, nessuno sblocco |
| **Huawei P10 Lite** | no | no | no (solo SolidOS) | sblocco con PotatoNV, vedi [la sua guida](installa-p10-lite.md) |

La tabella riassume lo stato di postmarketOS per ogni telefono: SolidOS usa i driver che
postmarketOS mette a disposizione. Se vuoi un telefono da usare tutti i giorni, il più
completo è il **OnePlus 6**, che si trova usato a poco prezzo.

## Passi (telefoni con fastboot)

1. **Fai una copia dei tuoi dati.** L'installazione cancella tutta la memoria del telefono.
2. **Sblocca il bootloader.** Sui telefoni della tabella lo sblocco è ufficiale:
   - attiva le *Opzioni sviluppatore* (tocca 7 volte «Numero build»), poi *Sblocco OEM*;
   - telefono in modalità fastboot e dal computer:
     ```
     fastboot flashing unlock
     ```
3. **Scarica lo zip del tuo telefono** dalle Releases ed estrailo.
4. **Esegui i comandi di `LEGGIMI.txt`**. Per un OnePlus 6, per esempio:
   ```
   fastboot erase dtbo
   fastboot flash boot boot.img
   fastboot flash userdata solidos-mobile.img
   fastboot reboot
   ```
5. Il primo avvio dura un po' di più, poi compare la schermata di blocco di SolidOS.

`fastboot` fa parte degli Android Platform Tools di Google. Su Mac si installa con
`brew install android-platform-tools`, su Windows si scarica dal sito di Android.

## PinePhone Pro

Scrivi `solidos-mobile.img` su una microSD con balenaEtcher, inseriscila e accendi.
La memoria interna non viene toccata.

## Dopo l'installazione

- Utente `solid`, password `solidos`. Ti servono solo per il terminale; cambiala con `passwd`.
- Il codice di sblocco del telefono si imposta in Impostazioni › Codice di sblocco.
- Accedi al Solid ID in Impostazioni per usare Dov'è e vedere i tuoi dispositivi.
