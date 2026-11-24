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
    "foglia": '<path d="M11 20A7 7 0 0 1 9.8 6.1C15.5 5 17 4.5 19 2c1 2 2 4.2 2 8 0 5.5-4.8 10-10 10Z"/><path d="M2 21c0-3 1.9-5.4 5.2-6.1A15 15 0 0 0 13 12"/>',
    "parz-nuvoloso": '<path d="M12 2v2M4.9 4.9l1.4 1.4M20 12h2M19.1 4.9l-1.4 1.4M15.9 13.1A4 4 0 1 0 8 11.5"/><path d="M13 22H7a5 5 0 1 1 4.9-6H13a3 3 0 0 1 0 6Z"/>',
    "nebbia": '<path d="M4 14.9A7 7 0 1 1 15.7 8h1.8a4.5 4.5 0 0 1 2.5 8.2"/><path d="M16 17H7M17 21H9"/>',
    "vento": '<path d="M17.7 7.7a2.5 2.5 0 1 1 1.8 4.3H2M9.6 4.6A2 2 0 1 1 11 8H2M12.6 19.4A2 2 0 1 0 14 16H2"/>',
    "goccia": '<path d="M12 22a7 7 0 0 0 7-7c0-2-1-3.9-3-5.5s-3.5-4-4-6.5c-.5 2.5-2 4.9-4 6.5C6 11.1 5 13 5 15a7 7 0 0 0 7 7z"/>',
    "alba": '<path d="M12 2v8M4.9 10.9l1.4 1.4M2 18h2M20 18h2M19.1 10.9l-1.4 1.4M22 22H2M8 6l4-4 4 4M16 18a4 4 0 0 0-8 0"/>',
    "tramonto": '<path d="M12 10V2M4.9 10.9l1.4 1.4M2 18h2M20 18h2M19.1 10.9l-1.4 1.4M22 22H2M16 6l-4 4-4-4M16 18a4 4 0 0 0-8 0"/>',
    "termometro": '<path d="M14 4v10.5a4 4 0 1 1-4 0V4a2 2 0 0 1 4 0Z"/>',
    "occhio": '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/>',
    "bandiera": '<path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z"/><path d="M4 22v-7"/>',
    "onda": '<path d="M2 12h2M6 8v8M10 4v16M14 7v10M18 9v6M22 12h-2"/>',
    "chiave": '<path d="M2.586 17.414A2 2 0 0 0 2 18.828V21a1 1 0 0 0 1 1h3a1 1 0 0 0 1-1v-1a1 1 0 0 1 1-1h1a1 1 0 0 0 1-1v-1a1 1 0 0 1 1-1h.172a2 2 0 0 0 1.414-.586l.814-.814a6.5 6.5 0 1 0-4-4z"/><circle cx="16.5" cy="7.5" r="1"/>',
    "scudo": '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/>',
    "occhio-chiuso": '<path d="M10.733 5.076a10.744 10.744 0 0 1 11.205 6.575 1 1 0 0 1 0 .696 10.747 10.747 0 0 1-1.444 2.49"/><path d="M14.084 14.158a3 3 0 0 1-4.242-4.242"/><path d="M17.479 17.499a10.75 10.75 0 0 1-15.417-5.151 1 1 0 0 1 0-.696 10.75 10.75 0 0 1 4.446-5.143"/><path d="m2 2 20 20"/>',
    "copia": '<rect width="14" height="14" x="8" y="8" rx="2" ry="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/>',
    "archivio": '<rect width="20" height="5" x="2" y="3" rx="1"/><path d="M4 8v11a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8"/><path d="M10 12h4"/>',
    "cartella": '<path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/>',
    "rispondi": '<polyline points="9 17 4 12 9 7"/><path d="M20 18v-2a4 4 0 0 0-4-4H4"/>',
    "rispondi-tutti": '<polyline points="7 17 2 12 7 7"/><polyline points="12 17 7 12 12 7"/><path d="M22 18v-2a4 4 0 0 0-4-4H7"/>',
    "inoltra": '<polyline points="15 17 20 12 15 7"/><path d="M4 18v-2a4 4 0 0 1 4-4h12"/>',
    "graffetta": '<path d="m21.44 11.05-9.19 9.19a6 6 0 0 1-8.49-8.49l8.57-8.57A4 4 0 1 1 18 8.84l-8.59 8.57a2 2 0 0 1-2.83-2.83l8.49-8.48"/>',
    "entrata": '<polyline points="22 12 16 12 14 15 10 15 8 12 2 12"/><path d="M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"/>',
    "sveglia": '<circle cx="12" cy="13" r="8"/><path d="M12 9v4l2 2M5 3 2 6M22 6l-3-3M6.4 19.6 4 22M17.6 19.6 20 22"/>',
    "clessidra": '<path d="M5 22h14M5 2h14M17 22v-4.2a2 2 0 0 0-.6-1.4L12 12l-4.4 4.4a2 2 0 0 0-.6 1.4V22M7 2v4.2a2 2 0 0 0 .6 1.4L12 12l4.4-4.4a2 2 0 0 0 .6-1.4V2"/>',
    "cronometro": '<circle cx="12" cy="14" r="8"/><path d="M10 2h4M12 14l3-3M12 2v4"/>',
    "microfono": '<rect width="6" height="12" x="9" y="2" rx="3"/><path d="M19 10v1a7 7 0 0 1-14 0v-1M12 18v4M8 22h8"/>',
    "registra": '<circle cx="12" cy="12" r="7"/>',
    "stop": '<rect width="12" height="12" x="6" y="6" rx="2"/>',
    "ripeti": '<path d="m17 2 4 4-4 4"/><path d="M3 11v-1a4 4 0 0 1 4-4h14M7 22l-4-4 4-4"/><path d="M21 13v1a4 4 0 0 1-4 4H3"/>',
    "cerchio-spunta": '<circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/>',
    "freccia-giro": '<path d="M3 12a9 9 0 1 0 9-9 9.8 9.8 0 0 0-6.7 2.7L3 8"/><path d="M3 3v5h5"/>',

    "posate": '<path d="M5 2v6a3 3 0 0 0 6 0V2M8 2v20"/><path d="M19 22V2c-2.8 1.2-4 4-4 7v5h4"/>',
    "tazza": '<path d="M17 8h1a4 4 0 1 1 0 8h-1"/><path d="M3 8h14v9a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4Z"/><path d="M7 2v2M11 2v2M15 2v2"/>',
    "carburante": '<path d="M3 22h12M4 9h10M14 22V4a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v18"/><path d="M14 13h2a2 2 0 0 1 2 2v2a2 2 0 0 0 4 0V9.8a2 2 0 0 0-.6-1.4L18 5"/>',
    "fulmine": '<path d="M13 2 4 14h7l-1 8 9-12h-7z"/>',
    "croce": '<path d="M9 3h6v6h6v6h-6v6H9v-6H3V9h6z"/>',
    "carrello": '<circle cx="8" cy="21" r="1"/><circle cx="19" cy="21" r="1"/><path d="M2 2h3l2.7 12.4a2 2 0 0 0 2 1.6h9.7a2 2 0 0 0 1.9-1.5L23 6H6"/>',
    "parcheggio": '<rect width="18" height="18" x="3" y="3" rx="2"/><path d="M9 17V7h4a3 3 0 0 1 0 6H9"/>',
    "letto": '<path d="M2 4v16M2 8h18a2 2 0 0 1 2 2v10M2 17h20M6 8v9"/>',
    "ospedale": '<rect width="16" height="20" x="4" y="2" rx="2"/><path d="M12 6v6M9 9h6M10 22v-4h4v4"/>',
    "banconota": '<rect width="20" height="12" x="2" y="6" rx="2"/><circle cx="12" cy="12" r="2"/><path d="M6 12h.01M18 12h.01"/>',
    "monumento": '<path d="M3 22h18M6 18v-7M10 18v-7M14 18v-7M18 18v-7M12 2l8 5H4z"/><path d="M4 11h16"/>',
    "treno": '<rect width="16" height="16" x="4" y="3" rx="2"/><path d="M4 11h16M12 3v8M8 19l-2 3M18 22l-2-3M8 15h.01M16 15h.01"/>',
    "autobus": '<path d="M8 6v6M15 6v6M2 12h19.6"/><path d="M18 18h3s.5-1.7.8-2.8c.1-.4.2-.8.2-1.2 0-.4-.1-.8-.2-1.2l-1.4-5C20.1 6.8 19.1 6 18 6H4a2 2 0 0 0-2 2v10h3"/><circle cx="7" cy="18" r="2"/><path d="M9 18h5"/><circle cx="16" cy="18" r="2"/>',
    "tram": '<rect width="14" height="15" x="5" y="5" rx="2"/><path d="M5 12h14M9 2h6M12 2v3M9 20l-2 2M17 22l-2-2"/>',
    "metro": '<rect width="16" height="16" x="4" y="3" rx="3"/><path d="M4 11h16M9 7h6M8 15h.01M16 15h.01M9 19l-2 3M17 22l-2-3"/>',
    "nave": '<path d="M2 21c.6.5 1.2 1 2.5 1 2.5 0 2.5-2 5-2 1.3 0 1.9.5 2.5 1s1.2 1 2.5 1c2.5 0 2.5-2 5-2 1.3 0 1.9.5 2.5 1"/><path d="M19.4 20A11.6 11.6 0 0 0 21 14l-9-4-9 4c0 2.9.9 5.3 2.8 7.8"/><path d="M19 13V7a2 2 0 0 0-2-2H7a2 2 0 0 0-2 2v6M12 10v4M12 2v3"/>',
    "bici": '<circle cx="5.5" cy="17.5" r="3.5"/><circle cx="18.5" cy="17.5" r="3.5"/><circle cx="15" cy="5" r="1"/><path d="M12 17.5V14l-3-3 4-3 2 3h2"/>',
    "pedone": '<circle cx="13" cy="4" r="2"/><path d="M13 7.5 11 13l3 3v5.5M11 13l-3 8.5M7.5 11.5 10.5 8l4.5 2.5 2.5 3"/>',
    "funivia": '<path d="M2 5 22 2M12 3.5V7"/><rect width="14" height="12" x="5" y="7" rx="2"/><path d="M5 13h14M10 7v6M14 7v6"/>',
    "naviga": '<path d="M3 11 22 2l-9 19-2-8z"/>',
    "bussola": '<circle cx="12" cy="12" r="10"/><path d="m16.2 7.8-2.1 6.3-6.3 2.1 2.1-6.3z"/>',
    "nord": '<path d="M12 2 5 21l7-4 7 4z"/>',
    "mirino": '<circle cx="12" cy="12" r="3"/><circle cx="12" cy="12" r="8"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2"/>',
    "globo": '<circle cx="12" cy="12" r="10"/><path d="M2 12h20M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/>',
    "chiudi": '<path d="M18 6 6 18M6 6l12 12"/>',
    "cuore": '<path d="M19 14c1.5-1.5 3-3.2 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.8 0-3 .5-4.5 2-1.5-1.5-2.7-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.1 3 5.5l7 7Z"/>',
    "dritto": '<path d="M12 21V3M5 10l7-7 7 7"/>',
    "svolta-destra": '<path d="M6 21v-8a5 5 0 0 1 5-5h9M15 3l5 5-5 5"/>',
    "svolta-sinistra": '<path d="M18 21v-8a5 5 0 0 0-5-5H4M9 3 4 8l5 5"/>',
    "leggera-destra": '<path d="M8 21v-8.5L17 4M11 4h6v6"/>',
    "leggera-sinistra": '<path d="M16 21v-8.5L7 4M13 4H7v6"/>',
    "brusca-destra": '<path d="M7 3v9l10 8M17 13v7h-7"/>',
    "brusca-sinistra": '<path d="M17 3v9L7 20M7 13v7h7"/>',
    "inversione": '<path d="M7 21V9a5 5 0 0 1 10 0v6M13 12l4 4 4-4"/>',
    "rotonda": '<circle cx="12" cy="13" r="4"/><path d="M12 22v-5M12 9V2M8.5 5.5 12 2l3.5 3.5"/>',
    "arrivo": '<path d="M4 22V4a1 1 0 0 1 .4-.8A6 6 0 0 1 8 2c3 0 5 2 7.3 2q2 0 3.7-1.3a1 1 0 0 1 1.6.8v9.4a1 1 0 0 1-.4.8A6 6 0 0 1 16 14c-3 0-5-2-8-2a6 6 0 0 0-4 1.3"/>',
    "busta": '<rect width="20" height="16" x="2" y="4" rx="2"/><path d="m22 7-9 5.7a2 2 0 0 1-2 0L2 7"/>',
    "spunta": '<path d="M20 6 9 17l-5-5"/>',
    "scambia": '<path d="m21 16-4 4-4-4M17 20V4M3 8l4-4 4 4M7 4v16"/>',
    "puntina": '<path d="M12 17v5M9 10.8a2 2 0 0 1-1.1 1.8l-1.8.9A2 2 0 0 0 5 15.2V16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-.8a2 2 0 0 0-1.1-1.8l-1.8-.9A2 2 0 0 1 15 10.8V7a1 1 0 0 1 1-1 2 2 0 0 0 0-4H8a2 2 0 0 0 0 4 1 1 0 0 1 1 1z"/>',
    "schermo": '<rect width="20" height="14" x="2" y="3" rx="2"/><path d="M8 21h8M12 17v4"/>',
    "freccia-giu": '<path d="M12 5v14M19 12l-7 7-7-7"/>',
    "freccia-su": '<path d="M12 19V5M5 12l7-7 7 7"/>',
    "freccia-sinistra": '<path d="M19 12H5M12 19l-7-7 7-7"/>',
    "freccia-destra": '<path d="M5 12h14M12 5l7 7-7 7"/>',

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
    "mappe": '<path d="M3.5 6.6 9 4l6 2.6L20.5 4v13.4L15 20l-6-2.6-5.5 2.6Z"/><path d="M9 4v13.4"/><path d="M15 6.6V20"/>',
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
    "segreteria": '<circle cx="6" cy="12" r="4"/><circle cx="18" cy="12" r="4"/><path d="M6 16h12"/>',
    "esporta": '<path d="M12 2v13M8 6l4-4 4 4"/><path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8"/>',
    "nuvola": '<path d="M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z"/>',
    "tasto-cancella": '<path d="M10 5a2 2 0 0 0-1.34.52l-6.33 5.74a1 1 0 0 0 0 1.48l6.33 5.74A2 2 0 0 0 10 19h10a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2z"/><path d="m12 9 6 6M18 9l-6 6"/>',
    "tasto-maiuscole": '<path d="M9 18v-6H5l7-7 7 7h-4v6H9z"/>',
    "cronologia": '<path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5M12 7v5l4 2"/>',
    "elenco": '<path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"/>',
    "tag": '<path d="M12.59 2.59A2 2 0 0 0 11.17 2H4a2 2 0 0 0-2 2v7.17a2 2 0 0 0 .59 1.41l8.7 8.7a2.43 2.43 0 0 0 3.42 0l6.58-6.58a2.43 2.43 0 0 0 0-3.42z"/><circle cx="7.5" cy="7.5" r=".5"/>',
    "pioggia": '<path d="M4 14.9A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 2.5 8.24"/><path d="M16 14v6M8 14v6M12 16v6"/>',
    "neve": '<path d="M4 14.9A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 2.5 8.24"/><path d="M8 15h.01M8 19h.01M12 17h.01M12 21h.01M16 15h.01M16 19h.01"/>',
    "temporale": '<path d="M6 16.33A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 1.5 8.74"/><path d="m13 12-3 5h4l-3 5"/>',
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
    "phone-voicemail-symbolic": "segreteria",
    "media-playback-start-symbolic": "play", "media-playback-pause-symbolic": "pausa",
    "media-skip-forward-symbolic": "avanti", "media-skip-backward-symbolic": "indietro",
}
APP = ["archivio", "cartella", "rispondi", "rispondi-tutti", "inoltra", "graffetta", "entrata", "invia", "chiave", "wifi", "scudo", "occhio-chiuso", "copia", "campana", "bandiera", "onda", "foglia", "parz-nuvoloso", "nebbia", "vento", "goccia", "alba", "tramonto", "termometro", "occhio", "sveglia", "clessidra", "cronometro", "microfono", "registra", "stop", "ripeti", "cerchio-spunta", "freccia-giro", "sole", "nuvola", "pioggia", "neve", "temporale", "luna", "calendario", "orologio", "play", "pausa", "elenco", "piu", "cestino", "matita", "cerca", "auto", "posate", "tazza", "carburante", "fulmine", "croce", "carrello", "parcheggio", "letto", "ospedale", "banconota", "monumento", "treno", "autobus", "tram", "metro", "nave", "bici", "pedone", "funivia", "naviga", "bussola", "nord", "mirino", "globo", "chiudi", "cuore", "dritto", "svolta-destra", "svolta-sinistra", "leggera-destra", "leggera-sinistra", "brusca-destra", "brusca-sinistra", "inversione", "rotonda", "arrivo", "busta", "spunta", "scambia", "puntina", "schermo", "freccia-giu", "freccia-su", "freccia-sinistra", "freccia-destra", "stella", "casa", "valigetta", "volume", "silenzioso", "cronologia", "impostazioni", "nuvola", "griglia", "scarica", "lucchetto", "attenzione", "condividi", "telefono", "messaggi", "contatti", "fotocamera", "foto", "musica", "note", "file", "dove", "mappe",
       "calcolatrice", "store", "vicina", "impostazioni", "esporta", "nuvola", "tasto-cancella", "tasto-maiuscole", "cronologia", "smartphone", "chiavetta", "casa", "portatile", "documento", "scarica", "video", "griglia", "elenco", "tag", "piu", "cerca", "condividi", "matita", "cestino", "info", "orologio", "sole", "luna", "pioggia", "neve", "temporale", "play", "pausa", "avanti", "indietro", "calendario", "batteria"]


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
    for pieno in ("stella", "cuore", "registra", "stop", "bandiera"):
        (DEST / f"linea-{pieno}-piena.svg").write_text(svg(G[pieno]).replace('fill="none"', 'fill="#000"', 1))
    # la tastiera è fatta di punti pieni
    (DEST / "input-dialpad-symbolic.svg").write_text(svg(G["tastiera"]).replace('fill="none"', 'fill="#000"', 1))
    print(f"{len(NOMI) + len(APP)} icone in {DEST}")


if __name__ == "__main__":
    main()
