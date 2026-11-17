# Set di icone di SolidOS Mobile (versione rifinita).
# Uso: python3 scripts/genera-icone.py src/dati/icone/hicolor/scalable/apps
#: tessera arrotondata con sfumatura
# sobria, riflesso morbido, bordo interno sottile; simboli tutti pieni e bianchi, della
# stessa grandezza ottica (circa 34 px su 64), con i dettagli scavati nel colore della
# tessera e un'ombra leggera. Disegni originali.
import os
import sys

OUT = sys.argv[1]
B = "#ffffff"


def icona(nome, c1, c2, simbolo, dettaglio=None):
    """c1/c2: sfumatura dall'alto al basso. «dettaglio»: colore dei particolari scavati."""
    d = dettaglio or c2
    corpo = f'''<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
 <!-- SolidOS Mobile: {nome} -->
 <defs>
  <linearGradient id="fondo" x1="0.2" y1="0" x2="0.8" y2="1">
   <stop offset="0" stop-color="{c1}"/>
   <stop offset="1" stop-color="{c2}"/>
  </linearGradient>
  <linearGradient id="luce" x1="0" y1="0" x2="0" y2="1">
   <stop offset="0" stop-color="#ffffff" stop-opacity="0.22"/>
   <stop offset="0.45" stop-color="#ffffff" stop-opacity="0.04"/>
   <stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
  </linearGradient>
 </defs>
 <rect x="2" y="2" width="60" height="60" rx="14.5" fill="url(#fondo)"/>
 <rect x="2" y="2" width="60" height="60" rx="14.5" fill="url(#luce)"/>
 <rect x="2.6" y="2.6" width="58.8" height="58.8" rx="13.9" fill="none" stroke="#ffffff" stroke-opacity="0.14" stroke-width="1.2"/>
{simbolo(d)}</svg>
'''
    with open(os.path.join(OUT, f"nucleo-{nome}.svg"), "w") as f:
        f.write(corpo)


def ombra(forme):
    """La stessa sagoma, scura e spostata di poco: dà profondità senza appesantire."""
    return f' <g transform="translate(0,1.2)" opacity="0.16">{forme.replace(B, "#000000")}</g>\n'


def disegno(forme_bianche, dettagli=""):
    return ombra(forme_bianche) + f" {forme_bianche}\n" + (f" {dettagli}\n" if dettagli else "")


# Telefono: cornetta
CORNETTA = (f'<path fill="{B}" d="M24.6 17.8c1.4-.8 3.1-.4 3.9 1l2.7 4.5c.7 1.2.5 2.8-.5 3.7l-2.4 2.2c1.8 3.7 4.6 6.6 8.3 8.4'
            f'l2.2-2.4c.9-1 2.5-1.2 3.7-.5l4.5 2.7c1.4.8 1.8 2.6 1 3.9l-1.7 2.7c-1.4 2.2-4 3.2-6.4 2.5C29 44.2 20.6 35.8'
            f' 18 25.6c-.6-2.5.3-5.1 2.5-6.4z"/>')
icona("telefono", "#3BCB82", "#17985A", lambda d: disegno(CORNETTA))

# Messaggi: un fumetto con tre puntini scavati
FUMETTO = (f'<path fill="{B}" d="M32 15c-10.2 0-18 6.6-18 15 0 4.6 2.4 8.7 6.3 11.4-.4 2.6-1.7 4.8-3.6 6.2 3.9.3 7.6-1'
           f' 10.3-3.4 1.6.4 3.3.6 5 .6 10.2 0 18-6.6 18-15s-7.8-14.8-18-14.8z"/>')
icona("messaggi", "#5B93FF", "#2E5BE0",
      lambda d: disegno(FUMETTO, "".join(f'<circle fill="{d}" cx="{x}" cy="30" r="2.6"/>' for x in (24, 32, 40))))

# Contatti: persona
PERSONA = (f'<circle fill="{B}" cx="32" cy="24.5" r="8.2"/>'
           f'<path fill="{B}" d="M16.5 47c1.4-7.6 7.6-12.4 15.5-12.4S46.1 39.4 47.5 47c.2 1.3-.8 2.4-2.1 2.4H18.6c-1.3 0-2.3-1.1-2.1-2.4z"/>')
icona("contatti", "#A2ADBE", "#68768C", lambda d: disegno(PERSONA))

# Fotocamera: corpo pieno, obiettivo scavato con il vetro
CORPO = (f'<path fill="{B}" d="M26.4 17h11.2c1 0 1.9.5 2.4 1.3l1.6 2.7H45c3.3 0 6 2.7 6 6v14c0 3.3-2.7 6-6 6H19c-3.3 0-6-2.7-6-6V27'
         f'c0-3.3 2.7-6 6-6h3.4l1.6-2.7c.5-.8 1.4-1.3 2.4-1.3z"/>')
icona("fotocamera", "#545B69", "#272B33",
      lambda d: disegno(CORPO, f'<circle fill="#2D323B" cx="32" cy="34" r="8.6"/><circle fill="#3E5BA8" cx="32" cy="34" r="5.4"/>'
                               f'<circle fill="#ffffff" fill-opacity="0.8" cx="30" cy="31.8" r="1.6"/>'))

# Foto: quadro pieno con montagne e sole scavati
QUADRO = f'<rect fill="{B}" x="14" y="17" width="36" height="30" rx="6"/>'
icona("foto", "#FFA45C", "#EE5A7C",
      lambda d: disegno(QUADRO, f'<path fill="{d}" d="M18 43l9.2-10.4c.8-.9 2.2-.9 3 0l5.3 6 3.6-3.9c.8-.9 2.2-.9 3 0L46 39.2V43z"/>'
                                f'<circle fill="#F7A23C" cx="39" cy="25.5" r="3.4"/>'))

# Musica: doppia nota
NOTA = (f'<path fill="{B}" d="M27 19.2l18-4.2c1.3-.3 2.5.7 2.5 2v20.5a5.3 5.3 0 1 1-3-4.8V22.6l-14.5 3.4V42a5.3 5.3 0 1 1-3-4.8'
        f'V21.2c0-.9.6-1.8 1.5-2z"/>')
icona("musica", "#FF6680", "#D62351", lambda d: disegno(NOTA))

# Note: foglio con righe scavate
FOGLIO = f'<rect fill="{B}" x="18" y="14" width="28" height="36" rx="5"/>'
icona("note", "#FFCF57", "#EEA20E",
      lambda d: disegno(FOGLIO, '<path d="M24 24h16M24 30.5h16M24 37h10" fill="none" stroke="#E9A21B" stroke-width="3.2" stroke-linecap="round"/>'))

# File: cartella
CARTELLA = (f'<path fill="{B}" d="M14 22.5c0-2.5 2-4.5 4.5-4.5h8.6c1.2 0 2.4.5 3.2 1.4l2.3 2.6h12.9c2.5 0 4.5 2 4.5 4.5v14'
            f'c0 2.5-2 4.5-4.5 4.5h-27c-2.5 0-4.5-2-4.5-4.5z"/>')
icona("file", "#56A0FF", "#2A68DE", lambda d: disegno(CARTELLA, '<path d="M14 28.5h36" stroke="#3B80EA" stroke-width="2.2"/>'))

# Dov'è: segnaposto con il foro scavato
SEGNAPOSTO = f'<path fill="{B}" d="M32 51s-14-12.3-14-23C18 20.2 24.3 14 32 14s14 6.2 14 14c0 10.7-14 23-14 23z"/>'
icona("dove", "#2DC3A7", "#1873DA", lambda d: disegno(SEGNAPOSTO, '<circle fill="#1D97C2" cx="32" cy="28" r="5.4"/>'))

# Calcolatrice: tastierino 2×2 pieno, segni scavati, uguale in arancione
TASTI = "".join(f'<rect fill="{B}" x="{x}" y="{y}" width="15" height="15" rx="4"/>' for x, y in ((15, 15), (34, 15), (15, 34)))
icona("calcolatrice", "#4B5261", "#20242C",
      lambda d: disegno(TASTI + '<rect fill="#FF9F2E" x="34" y="34" width="15" height="15" rx="4"/>',
                        '<path d="M22.5 18.6v7.8M18.6 22.5h7.8M37.6 22.5h7.8M19.4 37.4l6.2 6.2M25.6 37.4l-6.2 6.2" stroke="#2A2F38" stroke-width="2.4" stroke-linecap="round"/>'
                        '<path d="M37.6 39.8h7.8M37.6 43.4h7.8" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round"/>'))

# Store: borsa piena con il manico
BORSA = (f'<path fill="{B}" d="M19.6 25h24.8c1.1 0 2 .9 1.9 2l-1.5 18.4c-.2 2.3-2.1 4.1-4.4 4.1H23.6c-2.3 0-4.2-1.8-4.4-4.1L17.7 27'
         f'c-.1-1.1.8-2 1.9-2z"/>')
MANICO = '<path d="M25.5 28v-5a6.5 6.5 0 0 1 13 0v5" fill="none" stroke="#ffffff" stroke-width="3.4" stroke-linecap="round"/>'
icona("store", "#8481FF", "#4D47DE", lambda d: disegno(BORSA + MANICO.replace('stroke="#ffffff"', f'stroke="{B}"')))

# Vicina: punto con onde (onde spesse e piene, stessa grandezza degli altri simboli)
ONDE = (f'<circle fill="{B}" cx="32" cy="32" r="5"/>'
        f'<path d="M23.2 22.8a13 13 0 0 0 0 18.4M40.8 22.8a13 13 0 0 1 0 18.4" fill="none" stroke="{B}" stroke-width="4" stroke-linecap="round"/>'
        f'<path d="M17 16.8a21.6 21.6 0 0 0 0 30.4M47 16.8a21.6 21.6 0 0 1 0 30.4" fill="none" stroke="{B}" stroke-width="4" stroke-linecap="round" stroke-opacity="0.65"/>')
icona("vicina", "#2EC6E2", "#0C84AF", lambda d: disegno(ONDE))

# Impostazioni: ingranaggio con il foro scavato
INGRANAGGIO = ("".join(f'<rect fill="{B}" x="28.8" y="13" width="6.4" height="9.5" rx="2.2" transform="rotate({a} 32 32)"/>' for a in range(0, 360, 45))
               + f'<circle fill="{B}" cx="32" cy="32" r="12.8"/>')
icona("impostazioni", "#A0A9B9", "#5E697C", lambda d: disegno(INGRANAGGIO, '<circle fill="#7A8496" cx="32" cy="32" r="5.2"/>'))
print("13 icone")
