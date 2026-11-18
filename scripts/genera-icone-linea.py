#!/usr/bin/env python3
"""Icone a linea dello stile «Essenziale» (tratto 1,75, angoli tondi, 24×24).

Crea src/dati/icone/linea/<nome>.svg con i nomi delle icone che l'interfaccia chiede
(«network-wireless-symbolic», «call-start-symbolic»…) e quelli delle app («linea-telefono»…).
Il fornitore di icone (nucleo/qmlapp.py) le cerca qui per prime e le ricolora in bianco o in
nero secondo il tema. I tracciati vengono da Lucide (licenza ISC, testo in docs/LICENZE.md).
"""
from pathlib import Path

DEST = Path(__file__).resolve().parent.parent / "src" / "dati" / "icone" / "linea"

G = {
    "wifi": '<path d="M5 13a10 10 0 0 1 14 0"/><path d="M8.5 16.5a5 5 0 0 1 7 0"/><path d="M2 8.82a15 15 0 0 1 20 0"/><path d="M12 20h.01"/>',
    "bluetooth": '<path d="m7 7 10 10-5 5V2l5 5L7 17"/>',
    "aereo": '<path d="M17.8 19.2 16 11l3.5-3.5C21 6 21.5 4 21 3c-1-.5-3 0-4.5 1.5L13 8 4.8 6.2c-.5-.1-.9.1-1.1.5l-.3.5c-.2.5-.1 1 .3 1.3L9 12l-2 3H4l-1 1 3 2 2 3 1-1v-3l3-2 3.5 5.3c.3.4.8.5 1.3.3l.5-.2c.4-.3.6-.7.5-1.2z"/>',
    "luna": '<path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/>',
    "sole": '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41"/>',
    "volume": '<path d="M11 5 6 9H2v6h4l5 4V5z"/><path d="M15.54 8.46a5 5 0 0 1 0 7.07"/><path d="M19.07 4.93a10 10 0 0 1 0 14.14"/>',
    "silenzioso": '<path d="M11 5 6 9H2v6h4l5 4V5z"/><path d="m22 9-6 6M16 9l6 6"/>',
    "torcia": '<path d="M18 6c0 2-2 2-2 4v10a2 2 0 0 1-2 2h-4a2 2 0 0 1-2-2V10c0-2-2-2-2-4V2h12z"/><path d="M6 6h12"/><path d="M12 12v.01"/>',
    "fotocamera": '<path d="M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z"/><circle cx="12" cy="13" r="3"/>',
    "fotocamera-no": '<path d="M2 2l20 20M7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16M9.5 4h5L17 7h3a2 2 0 0 1 2 2v7.5M14.12 15.12A3 3 0 1 1 9.88 10.88"/>',
    "lucchetto": '<rect width="18" height="11" x="3" y="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
    "cerca": '<circle cx="11" cy="11" r="7.5"/><path d="m21 21-4.3-4.3"/>',
    "dati": '<path d="M2 20h.01M7 20v-4M12 20v-8M17 20V8M22 4v16"/>',
    "calcolatrice": '<rect width="16" height="20" x="4" y="2" rx="2"/><path d="M8 6h8M16 14v4M16 10h.01M12 10h.01M8 10h.01M12 14h.01M8 14h.01M12 18h.01M8 18h.01"/>',
    "batteria": '<rect width="16" height="10" x="2" y="7" rx="2"/><path d="M22 11v2"/><path d="M6 11v2"/>',
    "telefono": '<path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.13.96.36 1.9.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.91.34 1.85.57 2.81.7A2 2 0 0 1 22 16.92z"/>',
    "messaggi": '<path d="M7.9 20A9 9 0 1 0 4 16.1L2 22Z"/>',
    "contatti": '<circle cx="12" cy="8" r="5"/><path d="M20 21a8 8 0 0 0-16 0"/>',
    "foto": '<rect width="18" height="18" x="3" y="3" rx="2"/><circle cx="9" cy="9" r="2"/><path d="m21 15-3.09-3.09a2 2 0 0 0-2.82 0L6 21"/>',
    "musica": '<path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>',
    "file": '<path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/>',
    "dove": '<path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/>',
    "note": '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4M10 9H8M16 13H8M16 17H8"/>',
    "store": '<path d="M6 2 3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4Z"/><path d="M3 6h18"/><path d="M16 10a4 4 0 0 1-8 0"/>',
    "vicina": '<path d="M4.9 19.1C1 15.2 1 8.8 4.9 4.9M7.8 16.2c-2.3-2.3-2.3-6.1 0-8.5"/><circle cx="12" cy="12" r="2"/><path d="M16.2 7.8c2.3 2.3 2.3 6.1 0 8.5M19.1 4.9C23 8.8 23 15.1 19.1 19"/>',
    "impostazioni": '<path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/><circle cx="12" cy="12" r="3"/>',
    "stella": '<path d="M11.53 2.3a.53.53 0 0 1 .95 0l2.31 4.68a2.12 2.12 0 0 0 1.6 1.16l5.16.76a.53.53 0 0 1 .3.9l-3.74 3.64a2.12 2.12 0 0 0-.61 1.88l.88 5.14a.53.53 0 0 1-.77.56l-4.62-2.43a2.12 2.12 0 0 0-1.97 0L6.4 21.01a.53.53 0 0 1-.77-.56l.88-5.14a2.12 2.12 0 0 0-.61-1.88L2.16 9.8a.53.53 0 0 1 .3-.91l5.16-.75a2.12 2.12 0 0 0 1.6-1.16z"/>',
    "tastiera": ''.join(f'<circle cx="{x}" cy="{y}" r="1.4"/>' for y in (4, 9.5, 15) for x in (5.5, 12, 18.5)) + '<circle cx="12" cy="20.5" r="1.4"/>',
    "monitor": '<rect width="20" height="14" x="2" y="3" rx="2"/><path d="M8 21h8M12 17v4"/>',
    "portatile": '<path d="M20 16V7a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v9m16 0H4m16 0 1.28 2.55a1 1 0 0 1-.9 1.45H3.62a1 1 0 0 1-.9-1.45L4 16"/>',
    "griglia": '<rect width="7" height="7" x="3" y="3" rx="1.5"/><rect width="7" height="7" x="14" y="3" rx="1.5"/><rect width="7" height="7" x="14" y="14" rx="1.5"/><rect width="7" height="7" x="3" y="14" rx="1.5"/>',
    "cestino": '<path d="M3 6h18M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>',
    "valigetta": '<path d="M16 20V4a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/><rect width="20" height="14" x="2" y="6" rx="2"/>',
    "campana": '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/>',
    "microfono-no": '<path d="M2 2l20 20M18.89 13.23A7.12 7.12 0 0 0 19 12v-2M5 10v2a7 7 0 0 0 12 5M15 9.34V5a3 3 0 0 0-5.68-1.33M9 9v3a3 3 0 0 0 5.12 2.12M12 19v3"/>',
    "scrivi": '<path d="M12 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.4 2.6a2.1 2.1 0 1 1 3 3L12 15l-4 1 1-4Z"/>',
    "piu": '<path d="M12 5v14M5 12h14"/>',
    "info": '<circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01"/>',
    "su": '<path d="m18 15-6-6-6 6"/>',
    "sinistra": '<path d="m15 18-6-6 6-6"/>',
    "cerchio": '<circle cx="12" cy="12" r="8"/>',
    "condividi": '<circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><path d="m8.59 13.51 6.83 3.98M15.41 6.51l-6.82 3.98"/>',
    "invia": '<path d="M14.54 21.69a.5.5 0 0 0 .94-.03l6.5-19a.5.5 0 0 0-.64-.63l-19 6.5a.5.5 0 0 0-.02.93l7.93 3.18a2 2 0 0 1 1.11 1.11z"/><path d="m21.85 2.15-10.94 10.94"/>',
    "orologio": '<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>',
    "matita": '<path d="M21.17 6.81a1 1 0 0 0-3.99-3.99L3.84 16.17a2 2 0 0 0-.5.83l-1.32 4.35a.5.5 0 0 0 .62.62l4.35-1.32a2 2 0 0 0 .83-.5z"/>',
    "attenzione": '<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3"/><path d="M12 9v4M12 17h.01"/>',
    "cassa": '<rect width="16" height="20" x="4" y="2" rx="2"/><circle cx="12" cy="14" r="4"/><path d="M12 6h.01"/>',
    "tavolozza": '<circle cx="13.5" cy="6.5" r=".6"/><circle cx="17.5" cy="10.5" r=".6"/><circle cx="8.5" cy="7.5" r=".6"/><circle cx="6.5" cy="12.5" r=".6"/><path d="M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10c.93 0 1.65-.75 1.65-1.69 0-.44-.18-.84-.44-1.13-.29-.29-.44-.65-.44-1.13a1.64 1.64 0 0 1 1.67-1.67h2c3.05 0 5.55-2.5 5.55-5.55C21.97 6.01 17.46 2 12 2z"/>',
    "casa": '<path d="M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8"/><path d="M3 10a2 2 0 0 1 .71-1.53l7-6a2 2 0 0 1 2.58 0l7 6A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>',
    "chiavetta": '<path d="M10 2v4M14 2v4"/><rect width="12" height="16" x="6" y="6" rx="2"/>',
    "smartphone": '<rect width="14" height="20" x="5" y="2" rx="2.5"/><path d="M12 18h.01"/>',
    "play": '<path d="M7 4.5v15a1 1 0 0 0 1.5.86l12.5-7.5a1 1 0 0 0 0-1.72L8.5 3.64A1 1 0 0 0 7 4.5z"/>',
    "pausa": '<rect x="6" y="4" width="4" height="16" rx="1"/><rect x="14" y="4" width="4" height="16" rx="1"/>',
    "avanti": '<path d="M5 4.5v15l10-7.5z"/><path d="M19 5v14"/>',
    "indietro": '<path d="M19 19.5v-15L9 12z"/><path d="M5 19V5"/>',
    "calendario": '<rect width="18" height="18" x="3" y="4" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/>',
    "documento": '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/>',
    "scarica": '<path d="M12 15V3M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><path d="m7 10 5 5 5-5"/>',
    "video": '<path d="m16 13 5.22 3.48a.5.5 0 0 0 .78-.42V7.94a.5.5 0 0 0-.76-.43L16 10.5"/><rect x="2" y="6" width="14" height="12" rx="2"/>',
    "cuffie": '<path d="M3 14h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-7a9 9 0 0 1 18 0v7a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3"/>',
    "auto": '<path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2"/><circle cx="7" cy="17" r="2"/><path d="M9 17h6"/><circle cx="17" cy="17" r="2"/>',
    "rotazione": '<path d="M21 12a9 9 0 1 1-3-6.7L21 8"/><path d="M21 3v5h-5"/>',
}

# Nomi chiesti dall'interfaccia → disegno
NOMI = {
    "network-wireless-symbolic": "wifi", "bluetooth-active-symbolic": "bluetooth", "airplane-mode-symbolic": "aereo",
    "weather-clear-night-symbolic": "luna", "display-brightness-symbolic": "sole", "audio-volume-high-symbolic": "volume",
    "audio-volume-muted-symbolic": "silenzioso", "torcia": "torcia", "camera-photo-symbolic": "fotocamera",
    "camera-disabled-symbolic": "fotocamera-no", "system-lock-screen-symbolic": "lucchetto", "system-search-symbolic": "cerca",
    "network-cellular-symbolic": "dati", "accessories-calculator-symbolic": "calcolatrice", "battery-good-symbolic": "batteria",
    "call-start-symbolic": "telefono", "phone-symbolic": "telefono", "phone": "smartphone", "avatar-default-symbolic": "contatti",
    "starred-symbolic": "stella", "input-dialpad-symbolic": "tastiera", "computer-symbolic": "monitor", "computer": "monitor",
    "computer-laptop-symbolic": "portatile", "computer-laptop": "portatile", "view-app-grid-symbolic": "griglia",
    "user-trash-symbolic": "cestino", "user-trash": "cestino", "user-busy-symbolic": "valigetta",
    "preferences-system-symbolic": "impostazioni", "preferences-system-notifications-symbolic": "campana",
    "microphone-sensitivity-muted-symbolic": "microfono-no", "mark-location-symbolic": "dove",
    "mail-message-new-symbolic": "scrivi", "list-add-symbolic": "piu", "help-about-symbolic": "info",
    "go-up-symbolic": "su", "go-previous-symbolic": "sinistra", "go-home-symbolic": "cerchio",
    "emblem-shared-symbolic": "condividi", "document-send-symbolic": "invia", "document-open-recent-symbolic": "orologio",
    "document-edit-symbolic": "matita", "dialog-warning-symbolic": "attenzione", "audio-speakers-symbolic": "cassa",
    "preferences-desktop-wallpaper-symbolic": "tavolozza", "user-home": "casa", "media-flash": "chiavetta",
    "object-rotate-right-symbolic": "rotazione",
    "folder": "file", "folder-documents": "documento", "folder-download": "scarica", "folder-music": "musica",
    "folder-pictures": "foto", "folder-videos": "video", "image-x-generic": "foto", "audio-x-generic": "musica",
    "video-x-generic": "video", "text-x-generic": "note", "application-pdf": "documento",
    "audio-headphones": "cuffie", "audio-car": "auto", "audio-speakers": "cassa",
    "x-office-calendar-symbolic": "calendario", "dialog-information": "info",
    "media-playback-start-symbolic": "play", "media-playback-pause-symbolic": "pausa",
    "media-skip-forward-symbolic": "avanti", "media-skip-backward-symbolic": "indietro",
}
APP = ["telefono", "messaggi", "contatti", "fotocamera", "foto", "musica", "note", "file", "dove",
       "calcolatrice", "store", "vicina", "impostazioni"]


def svg(disegno: str) -> str:
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" '
            'stroke="#000" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">' + disegno + "</svg>\n")


def main() -> None:
    DEST.mkdir(parents=True, exist_ok=True)
    for vecchio in DEST.glob("*.svg"):
        vecchio.unlink()
    for nome, g in NOMI.items():
        (DEST / f"{nome}.svg").write_text(svg(G[g]))
    for a in APP:
        (DEST / f"linea-{a}.svg").write_text(svg(G[a]))
    # la tastiera è fatta di punti pieni
    (DEST / "input-dialpad-symbolic.svg").write_text(svg(G["tastiera"]).replace('fill="none"', 'fill="#000"', 1))
    print(f"{len(NOMI) + len(APP)} icone in {DEST}")


if __name__ == "__main__":
    main()
