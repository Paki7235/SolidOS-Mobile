# Set di icone di SolidOS Mobile (stile approvato il 19/11/2026).
# Uso: python3 scripts/genera-icone.py src/dati/icone/hicolor/scalable/apps
# Tessera arrotondata con una sfumatura più profonda, una luce in alto come il vetro e un
# bordo interno sottile; simbolo a linea bianco (gli stessi disegni delle icone a linea,
# scripts/genera-icone-linea.py) con un'ombra leggera. Stesse forme e colori di prima.
import importlib.util
import os
import sys

OUT = sys.argv[1]
_spec = importlib.util.spec_from_file_location("linea", os.path.join(os.path.dirname(__file__), "genera-icone-linea.py"))
_linea = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_linea)
G = _linea.G

# app: (colore in alto, colore in basso, disegno, colore del simbolo)
APP = {
    "telefono": ("#4ADE80", "#16A34A", "telefono", "#FFFFFF"),
    "messaggi": ("#60A5FA", "#2563EB", "messaggi", "#FFFFFF"),
    "contatti": ("#FCD34D", "#F97316", "contatti", "#FFFFFF"),
    "fotocamera": ("#71717A", "#27272A", "fotocamera", "#FFFFFF"),
    "foto": ("#FDBA74", "#DB2777", "foto", "#FFFFFF"),
    "musica": ("#FB7185", "#E11D48", "musica", "#FFFFFF"),
    "note": ("#FDE68A", "#F59E0B", "note", "#FFFFFF"),
    "file": ("#7DD3FC", "#2563EB", "file", "#FFFFFF"),
    "dove": ("#5EEAD4", "#0D9488", "dove", "#FFFFFF"),
    "store": ("#C4B5FD", "#7C3AED", "store", "#FFFFFF"),
    "vicina": ("#67E8F9", "#0891B2", "vicina", "#FFFFFF"),
    "calcolatrice": ("#52525B", "#18181B", "calcolatrice", "#FB923C"),
    "impostazioni": ("#A1A1AA", "#3F3F46", "impostazioni", "#FFFFFF"),
}


def icona(nome, c1, c2, disegno, colore):
    simbolo = G[disegno]
    # 24×24 → 32×32 al centro della tessera da 64
    gruppo = ('<g transform="translate(16 16) scale(1.3333)" fill="none" stroke="{c}" stroke-width="1.9" '
              'stroke-linecap="round" stroke-linejoin="round">{s}</g>')
    corpo = f'''<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
 <!-- SolidOS Mobile: {nome} -->
 <defs>
  <linearGradient id="fondo" x1="0.3" y1="0" x2="0.7" y2="1">
   <stop offset="0" stop-color="{c1}"/>
   <stop offset="1" stop-color="{c2}"/>
  </linearGradient>
  <linearGradient id="luce" x1="0" y1="0" x2="0" y2="1">
   <stop offset="0" stop-color="#ffffff" stop-opacity="0.30"/>
   <stop offset="0.46" stop-color="#ffffff" stop-opacity="0"/>
  </linearGradient>
 </defs>
 <rect x="2" y="2" width="60" height="60" rx="14.5" fill="url(#fondo)"/>
 <rect x="2" y="2" width="60" height="60" rx="14.5" fill="url(#luce)"/>
 <rect x="2.5" y="2.5" width="59" height="59" rx="14" fill="none" stroke="#ffffff" stroke-opacity="0.16" stroke-width="1"/>
 <g transform="translate(0 1.4)" opacity="0.28">{gruppo.format(c="#000000", s=simbolo)}</g>
 {gruppo.format(c=colore, s=simbolo)}
</svg>
'''
    with open(os.path.join(OUT, f"nucleo-{nome}.svg"), "w") as f:
        f.write(corpo)


for nome, (c1, c2, disegno, colore) in APP.items():
    icona(nome, c1, c2, disegno, colore)
print(f"{len(APP)} icone")
