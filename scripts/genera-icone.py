# Icone delle app di SolidOS Mobile (stile approvato il 23/11/2026).
# Uso: python3 scripts/genera-icone.py src/dati/icone
# Ogni app ha un disegno pieno e a strati (non un simbolo a linea), in tre finiture:
#   Gemme  hicolor/scalable/apps/nucleo-<app>.svg     tessera sfumata, luce in alto, simbolo bianco
#   Piene  finiture/piene-nucleo-<app>.svg            colore pieno, simbolo scuro (veste Prisma)
#   Vetro  finiture/vetro-nucleo-<app>.svg            solo il simbolo: la lastra di vetro la
#                                                     disegna l'interfaccia sopra lo sfondo
# Le Gemme sono anche le icone predefinite (notifiche, Libreria, Store).
import os
import re
import sys

BASE = sys.argv[1] if len(sys.argv) > 1 else "src/dati/icone"
if BASE.rstrip("/").endswith("apps"):
    sys.exit("Ora si passa la cartella delle icone: python3 scripts/genera-icone.py src/dati/icone")
GEMME = os.path.join(BASE, "hicolor", "scalable", "apps")
FINITURE = os.path.join(BASE, "finiture")

# Tessera «squircle» in un riquadro 100×100
SQ = "M50 0C90 0 100 10 100 50S90 100 50 100 0 90 0 50 10 0 50 0Z"


def ombra(svg, dy=2.2, op=0.18):
    """Ombra leggera del simbolo: una copia nera spostata in basso (QtSvg non ha i filtri)."""
    nero = re.sub(r'(fill|stroke)="(?!none)[^"]*"', r'\1="#000000"', svg)
    return f'<g transform="translate(0 {dy})" opacity="{op}">{nero}</g>'


# Disegni (riquadro 100): p = principale, s = secondario, a = accento, c = colore del fondo
def telefono(p, s, a, c):
    return (f'<g transform="translate(19.5 19.5) scale(2.6)"><path fill="{p}" d="M22 16.92v3a2 2 0 0 1-2.18 2 '
            '19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 '
            '2 1.72c.13.96.36 1.9.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.91.34 '
            '1.85.57 2.81.7A2 2 0 0 1 22 16.92z"/></g>')


def messaggi(p, s, a, c):
    return (f'<rect x="40" y="18" width="44" height="34" rx="12" fill="{s}"/>'
            f'<path fill="{p}" d="M28 32h34a12 12 0 0 1 12 12v16a12 12 0 0 1-12 12H44L30 82V72h-2a12 12 0 0 1-12-12V44a12 12 0 0 1 12-12Z"/>')


def contatti(p, s, a, c):
    return (f'<circle cx="50" cy="50" r="33" fill="{s}"/>'
            f'<circle cx="50" cy="42" r="12" fill="{p}"/>'
            f'<path fill="{p}" d="M27 74c3-11 12-17 23-17s20 6 23 17a33 33 0 0 1-46 0Z"/>')


def foto(p, s, a, c):
    return (f'<circle cx="50" cy="38" r="18" fill="{p}" opacity=".88"/>'
            f'<circle cx="38" cy="58" r="18" fill="{s}" opacity=".88"/>'
            f'<circle cx="62" cy="58" r="18" fill="{a}" opacity=".88"/>')


def fotocamera(p, s, a, c):
    return (f'<rect x="34" y="22" width="32" height="14" rx="6" fill="{p}"/>'
            f'<rect x="16" y="30" width="68" height="48" rx="14" fill="{p}"/>'
            f'<circle cx="50" cy="54" r="16" fill="{c}"/><circle cx="50" cy="54" r="9" fill="{s}"/>'
            f'<circle cx="72" cy="40" r="3.5" fill="{a}"/>')


def musica(p, s, a, c):
    return (f'<g fill="{p}"><circle cx="33" cy="70" r="11"/><circle cx="69" cy="64" r="11"/>'
            '<rect x="38" y="30" width="6" height="40" rx="2"/><rect x="74" y="24" width="6" height="40" rx="2"/>'
            '<path d="M38 30 80 20v12L38 42Z"/></g>')


def mappe(p, s, a, c):
    return (f'<path d="M18 28 39 21v52l-21 7Z" fill="{s}"/><path d="M39 21l22 7v52l-22-7Z" fill="{p}"/>'
            f'<path d="M61 28l21-7v52l-21 7Z" fill="{s}"/>'
            f'<path d="M61 30c-7 0-12 5-12 11 0 8 12 19 12 19s12-11 12-19c0-6-5-11-12-11Z" fill="{a}"/>'
            f'<circle cx="61" cy="41" r="4.5" fill="{p}"/>')


def note(p, s, a, c):
    return (f'<rect x="24" y="18" width="52" height="64" rx="10" fill="{p}"/>'
            f'<rect x="34" y="34" width="32" height="5" rx="2.5" fill="{a}"/>'
            f'<rect x="34" y="46" width="32" height="5" rx="2.5" fill="{s}"/>'
            f'<rect x="34" y="58" width="20" height="5" rx="2.5" fill="{s}"/>')


def file(p, s, a, c):
    return (f'<path d="M18 32a8 8 0 0 1 8-8h14l7 7h27a8 8 0 0 1 8 8v4H18Z" fill="{s}"/>'
            f'<rect x="18" y="38" width="64" height="40" rx="9" fill="{p}"/>')


def dove(p, s, a, c):
    return (f'<circle cx="50" cy="50" r="32" fill="{s}" opacity=".35"/>'
            f'<circle cx="50" cy="50" r="21" fill="{s}" opacity=".6"/>'
            f'<circle cx="50" cy="50" r="11" fill="{p}"/><circle cx="50" cy="50" r="4.5" fill="{a}"/>')


def impostazioni(p, s, a, c):
    denti = "".join(f'<rect x="43" y="16" width="14" height="18" rx="4" transform="rotate({r} 50 50)"/>'
                    for r in range(0, 360, 45))
    return f'<g fill="{p}">{denti}<circle cx="50" cy="50" r="25"/></g><circle cx="50" cy="50" r="10" fill="{c}"/>'


def store(p, s, a, c):
    return (f'<path d="M38 40v-6a12 12 0 0 1 24 0v6" fill="none" stroke="{s}" stroke-width="6" stroke-linecap="round"/>'
            f'<rect x="20" y="36" width="60" height="46" rx="12" fill="{p}"/>'
            f'<path d="M50 50v18M41 59h18" fill="none" stroke="{a}" stroke-width="6" stroke-linecap="round"/>')


def vicina(p, s, a, c):
    return (f'<path d="M30 30a28 28 0 0 0 0 40M70 30a28 28 0 0 1 0 40" fill="none" stroke="{s}" stroke-width="6" stroke-linecap="round"/>'
            f'<path d="M39 39a14 14 0 0 0 0 22M61 39a14 14 0 0 1 0 22" fill="none" stroke="{p}" stroke-width="6" stroke-linecap="round"/>'
            f'<circle cx="50" cy="50" r="7" fill="{a}"/>')


def videochiamate(p, s, a, c):
    return (f'<rect x="12" y="29" width="50" height="42" rx="12" fill="{p}"/>'
            f'<path d="M66 45 82.5 34.3c2.2-1.4 5 .2 5 2.8v25.8c0 2.6-2.8 4.2-5 2.8L66 55Z" fill="{p}"/>'
            f'<circle cx="37" cy="50" r="11" fill="{c}"/><circle cx="37" cy="50" r="4.6" fill="{s}"/>'
            f'<circle cx="21.5" cy="38" r="3.4" fill="#FF5A5F"/>')


def calcolatrice(p, s, a, c):
    return (f'<rect x="20" y="20" width="27" height="27" rx="8" fill="{p}"/>'
            f'<rect x="53" y="20" width="27" height="27" rx="8" fill="{s}"/>'
            f'<rect x="20" y="53" width="27" height="27" rx="8" fill="{s}"/>'
            f'<rect x="53" y="53" width="27" height="27" rx="8" fill="{a}"/>'
            f'<path d="M66.5 60v13M60 66.5h13" fill="none" stroke="{c}" stroke-width="4" stroke-linecap="round"/>')


DISEGNI = dict(telefono=telefono, messaggi=messaggi, contatti=contatti, foto=foto, fotocamera=fotocamera,
               musica=musica, mappe=mappe, note=note, file=file, dove=dove, impostazioni=impostazioni,
               store=store, vicina=vicina, calcolatrice=calcolatrice, videochiamate=videochiamate)

W, W5 = "#FFFFFF", "#FFFFFF8C"
K, K4 = "#141414", "#14141459"
# Gemme: (sfumatura in alto, in basso, principale, secondario, accento)
GEMME_COL = {
    "telefono": ("#4BE38E", "#0E9B57", W, W5, W),
    "messaggi": ("#66A6FF", "#3443F5", W, W5, W),
    "contatti": ("#FFC46B", "#F27A1A", W, "#FFFFFF4D", W),
    "foto": ("#2B2456", "#100C26", "#FF5E8A", "#FFC24A", "#4FC6FF"),
    "fotocamera": ("#7A808E", "#2A2E38", W, "#1B1E26", "#4BE38E"),
    "musica": ("#FF74A6", "#DE1B67", W, W5, W),
    "mappe": ("#4FE6C4", "#168BB0", W, "#FFFFFF99", "#FF4F5E"),
    "note": ("#FFD86B", "#F29E00", W, "#F6B21F", "#F29E00"),
    "file": ("#7FDBFF", "#1A86DD", W, "#FFFFFF99", W),
    "dove": ("#33E7BA", "#0C9A82", W, W, "#0C9A82"),
    "impostazioni": ("#A9B0C0", "#4A5265", W, W5, W),
    "store": ("#B994FF", "#6232F5", W, W5, "#6232F5"),
    "vicina": ("#5EE6FF", "#0A8FC2", W, W5, W),
    "calcolatrice": ("#3A3A44", "#121216", W, "#FFFFFF40", "#FF8A2F"),
    "videochiamate": ("#5CF0A8", "#0F9F6E", W, W5, "#0F9F6E"),
}
# Piene: (fondo, principale, secondario, accento)
PIENE_COL = {
    "telefono": ("#C6F432", K, K4, K),
    "messaggi": ("#59C3FF", K, "#FFFFFFBF", K),
    "contatti": ("#FFB443", K, "#FFFFFF8C", K),
    "foto": ("#FFFFFF", "#FF6B4A", "#FFD84A", "#59C3FF"),
    "fotocamera": ("#E4DFD4", K, "#C6F432", "#59C3FF"),
    "musica": ("#A68CFF", K, K4, K),
    "mappe": ("#3EE0B0", K, "#FFFFFFB3", "#FF6B4A"),
    "note": ("#FFD84A", W, K4, "#FF6B4A"),
    "file": ("#FFFFFF", "#59C3FF", "#C6F432", K),
    "dove": ("#C6F432", K, K, "#C6F432"),
    "impostazioni": ("#D9D4CA", K, K4, K),
    "store": ("#A68CFF", W, K, "#A68CFF"),
    "vicina": ("#59C3FF", K, K4, W),
    "calcolatrice": ("#FFB443", K, K4, W),
    "videochiamate": ("#3EE0B0", K, K4, "#3EE0B0"),
}


def scrivi(percorso, corpo):
    # QtSvg non capisce i colori a 8 cifre (#RRGGBBAA): colore e opacità separati
    corpo = re.sub(r'(fill|stroke)="#([0-9A-Fa-f]{6})([0-9A-Fa-f]{2})"',
                   lambda m: f'{m[1]}="#{m[2]}" {m[1]}-opacity="{int(m[3], 16) / 255:.2f}"', corpo)
    with open(percorso, "w") as f:
        f.write(f'<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">\n{corpo}\n</svg>\n')


def gemma(nome):
    c1, c2, p, s, a = GEMME_COL[nome]
    d = DISEGNI[nome](p, s, a, c2)
    return f'''<defs>
 <linearGradient id="f" x1="0" y1="0" x2="0.3" y2="1"><stop offset="0" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/></linearGradient>
 <linearGradient id="l" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.38"/><stop offset="0.5" stop-color="#FFFFFF" stop-opacity="0"/></linearGradient>
</defs>
<g transform="translate(3 3) scale(0.94)">
 <path d="{SQ}" fill="url(#f)"/>
 {ombra(d)}
 {d}
 <path d="{SQ}" fill="url(#l)"/>
 <path d="{SQ}" fill="none" stroke="#FFFFFF" stroke-opacity="0.35" stroke-width="1.4"/>
</g>'''


def piena(nome):
    bg, p, s, a = PIENE_COL[nome]
    return f'<g transform="translate(3 3) scale(0.94)"><path d="{SQ}" fill="{bg}"/>{DISEGNI[nome](p, s, a, bg)}</g>'


def vetro(nome):
    """Solo il simbolo, bianco con l'accento della Gemma: la lastra la disegna l'interfaccia."""
    c1, c2, p, s, a = GEMME_COL[nome]
    if nome != "foto":
        p, s = W, W5
        a = W if a == W else c1
    fondo = "#28204F73"
    if nome == "note":            # righe colorate sul foglio bianco
        s, a = c2, c2
    elif nome == "calcolatrice":  # il tasto «+» resta arancione
        a, fondo = "#FF8A2F", W
    d = DISEGNI[nome](p, s, a, fondo)
    return f'<g transform="translate(3 3) scale(0.94)">{ombra(d, 2, 0.14)}{d}</g>'


os.makedirs(GEMME, exist_ok=True)
os.makedirs(FINITURE, exist_ok=True)
for nome in DISEGNI:
    scrivi(os.path.join(GEMME, f"nucleo-{nome}.svg"), gemma(nome))
    scrivi(os.path.join(FINITURE, f"piene-nucleo-{nome}.svg"), piena(nome))
    scrivi(os.path.join(FINITURE, f"vetro-nucleo-{nome}.svg"), vetro(nome))
print(f"{len(DISEGNI)} app × 3 finiture")
