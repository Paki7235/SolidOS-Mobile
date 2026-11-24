# Icone «classiche» di SolidOS Mobile (stile approvato il 24/11/2026): come sui telefoni più
# diffusi, ogni app ha un disegno e un fondo tutto suo (sfumature vive, tessere bianche per
# Calendario, Note, Foto e Promemoria, nere per Orologio, Calcolatrice e Registratore).
# Le usa scripts/genera-icone.py per la finitura «Gemme» (quella predefinita).
# Solo forme e sfumature che QtSvg disegna uguali (niente filtri o sfocature).

SQ = "M50 0C90 0 100 10 100 50S90 100 50 100 0 90 0 50 10 0 50 0Z"
_n = [0]


def _id():
    _n[0] += 1
    return f"g{_n[0]}"


def tessera(alto, basso, x2="0", y2="1"):
    """Fondo della tessera: sfumatura dall'alto in basso, più un filo di luce in cima."""
    i = _id()
    return (f'<defs><linearGradient id="{i}" x1="0" y1="0" x2="{x2}" y2="{y2}"><stop offset="0" stop-color="{alto}"/>'
            f'<stop offset="1" stop-color="{basso}"/></linearGradient></defs><path d="{SQ}" fill="url(#{i})"/>')


def sfuma(alto, basso):
    i = _id()
    return i, (f'<defs><linearGradient id="{i}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{alto}"/>'
               f'<stop offset="1" stop-color="{basso}"/></linearGradient></defs>')


CORNETTA = ("M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67"
            "A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.13.96.36 1.9.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6"
            "l1.27-1.27a2 2 0 0 1 2.11-.45c.91.34 1.85.57 2.81.7A2 2 0 0 1 22 16.92z")


def telefono():
    return tessera("#6BF08A", "#1FB54A") + f'<g transform="translate(21 21) scale(2.45)"><path fill="#FFFFFF" d="{CORNETTA}"/></g>'


def messaggi():
    return (tessera("#6BF08A", "#1FB54A") +
            '<ellipse cx="50" cy="47" rx="30" ry="24" fill="#FFFFFF"/>'
            '<path d="M28 60c-1 8-5 13-9 16 9 0 16-3 21-8Z" fill="#FFFFFF"/>')


def videochiamate():
    return (tessera("#6BF08A", "#1FB54A") +
            '<rect x="16" y="32" width="48" height="36" rx="10" fill="#FFFFFF"/><path d="M66 46l18-11v30L66 54Z" fill="#FFFFFF"/>')


def contatti():
    i, d = sfuma("#B9BBC1", "#8C8F96")
    return (tessera("#F2F2F4", "#D9DADF") + d +
            f'<circle cx="50" cy="40" r="15" fill="url(#{i})"/>'
            f'<path d="M22 80c2-15 14-24 28-24s26 9 28 24Z" fill="url(#{i})"/>'
            '<rect x="84" y="24" width="6" height="14" rx="2" fill="#FF6B5E"/><rect x="84" y="42" width="6" height="14" rx="2" fill="#FFB340"/>'
            '<rect x="84" y="60" width="6" height="14" rx="2" fill="#4CB8FF"/>')


def foto():
    # quattro gocce di luce colorata che si sovrappongono, su bianco
    return (tessera("#FFFFFF", "#F2F2F4") +
            '<circle cx="40" cy="40" r="20" fill="#FF9F0A" fill-opacity="0.85"/>'
            '<circle cx="60" cy="40" r="20" fill="#FF375F" fill-opacity="0.8"/>'
            '<circle cx="40" cy="60" r="20" fill="#30B0C7" fill-opacity="0.8"/>'
            '<circle cx="60" cy="60" r="20" fill="#5E5CE6" fill-opacity="0.75"/>'
            '<circle cx="50" cy="50" r="7" fill="#FFFFFF"/>')


def fotocamera():
    i, d = sfuma("#4A4D55", "#1C1D21")
    return (tessera("#E9EAEE", "#B7B9C0") + d +
            '<rect x="16" y="30" width="68" height="46" rx="11" fill="#2A2B30"/><rect x="36" y="23" width="28" height="11" rx="4" fill="#2A2B30"/>'
            '<circle cx="50" cy="53" r="17" fill="#E9EAEE"/>'
            f'<circle cx="50" cy="53" r="13" fill="url(#{i})"/><circle cx="50" cy="53" r="6" fill="#3B5BDB"/><circle cx="46" cy="49" r="2.2" fill="#FFFFFF"/>'
            '<circle cx="72" cy="38" r="3" fill="#FFD60A"/>')


def musica():
    return (tessera("#FF6E8A", "#F0284A") +
            '<g fill="#FFFFFF"><ellipse cx="34" cy="70" rx="11" ry="9"/><ellipse cx="68" cy="64" rx="11" ry="9"/>'
            '<rect x="40" y="28" width="5.5" height="43" rx="2"/><rect x="74" y="22" width="5.5" height="43" rx="2"/>'
            '<path d="M40 28 79.5 19v11L40 39Z"/></g>')


def mappe():
    return (tessera("#E6F2D9", "#CFE5BD") +
            '<path d="M0 66 C30 56 60 70 100 54 V100 H0Z" fill="#BDE0F7"/>'     # acqua
            '<path d="M-5 40 L105 70" stroke="#FFFFFF" stroke-width="9"/>'      # strada
            '<path d="M58 -5 L40 105" stroke="#FFD54F" stroke-width="8"/>'      # superstrada
            '<path d="M58 -5 L40 105" stroke="#F5B400" stroke-width="2"/>'
            '<path d="M22 84 C30 70 44 66 50 52" fill="none" stroke="#2F7CF6" stroke-width="5" stroke-linecap="round"/>'
            '<path d="M62 18c-9 0-15 6-15 14 0 10 15 24 15 24s15-14 15-24c0-8-6-14-15-14Z" fill="#FF3B30"/>'
            '<circle cx="62" cy="32" r="5.5" fill="#FFFFFF"/>')


def meteo():
    i, d = sfuma("#FFE36B", "#FFB800")
    return (tessera("#4FB3FF", "#1F6FF0") + d +
            f'<circle cx="62" cy="38" r="17" fill="url(#{i})"/>'
            '<g fill="#FFFFFF"><circle cx="38" cy="62" r="13"/><circle cx="55" cy="56" r="17"/><circle cx="71" cy="65" r="11"/>'
            '<rect x="26" y="62" width="56" height="14" rx="7"/></g>')


def calendario():
    return (tessera("#FFFFFF", "#F2F2F4") +
            '<text x="50" y="34" text-anchor="middle" font-family="Inter" font-weight="600" font-size="15" fill="#FF3B30">LUN</text>'
            '<text x="50" y="80" text-anchor="middle" font-family="Inter" font-weight="300" font-size="50" fill="#1C1C1E">24</text>')


def note():
    return (tessera("#FFFFFF", "#F4F4F6") +
            '<path d="M0 50C0 10 10 0 50 0S100 10 100 50V30H0Z" fill="#FFD60A"/>'
            '<rect x="0" y="22" width="100" height="8" fill="#FFD60A"/>'
            + "".join(f'<rect x="14" y="{y}" width="72" height="2.5" fill="#D1D1D6"/>' for y in (46, 60, 74))
            + '<g fill="#B5B5BB">' + "".join(f'<circle cx="{x}" cy="38" r="1.6"/>' for x in range(14, 90, 6)) + '</g>')


def file():
    i, d = sfuma("#6CB8FF", "#1A7CF5")
    return (tessera("#FFFFFF", "#F2F2F4") + d +
            '<path d="M16 34a7 7 0 0 1 7-7h17l7 7h30a7 7 0 0 1 7 7v4H16Z" fill="#1565D8"/>'
            f'<rect x="16" y="38" width="68" height="40" rx="8" fill="url(#{i})"/>')


def dove():
    return (tessera("#4BE08A", "#14A85A") +
            '<circle cx="50" cy="50" r="32" fill="#FFFFFF" fill-opacity="0.25"/><circle cx="50" cy="50" r="22" fill="#FFFFFF" fill-opacity="0.45"/>'
            '<circle cx="50" cy="50" r="13" fill="#FFFFFF"/><circle cx="50" cy="50" r="6" fill="#14A85A"/>')


def impostazioni():
    i, d = sfuma("#A9ADB6", "#6D717B")
    denti = "".join(f'<rect x="45" y="12" width="10" height="16" rx="2.5" transform="rotate({r} 50 50)"/>' for r in range(0, 360, 30))
    return (tessera("#C7CAD1", "#8E929C") + d +
            f'<g fill="#3A3C42">{denti}<circle cx="50" cy="50" r="31"/></g>'
            f'<circle cx="50" cy="50" r="25" fill="url(#{i})"/><circle cx="50" cy="50" r="15" fill="#3A3C42"/>'
            '<circle cx="50" cy="50" r="8" fill="#C7CAD1"/>')


def store():
    return (tessera("#B18CFF", "#6A3CF0") +
            '<path d="M37 40v-7a13 13 0 0 1 26 0v7" fill="none" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round"/>'
            '<rect x="22" y="38" width="56" height="44" rx="12" fill="#FFFFFF"/>'
            '<path d="M50 50v20M40 60h20" stroke="#6A3CF0" stroke-width="6" stroke-linecap="round"/>')


def vicina():
    return (tessera("#5EE6FF", "#0A8FD8") +
            '<g fill="none" stroke="#FFFFFF" stroke-linecap="round">'
            '<path d="M30 30a28 28 0 0 0 0 40M70 30a28 28 0 0 1 0 40" stroke-width="6" stroke-opacity="0.6"/>'
            '<path d="M39 39a14 14 0 0 0 0 22M61 39a14 14 0 0 1 0 22" stroke-width="6"/></g><circle cx="50" cy="50" r="7" fill="#FFFFFF"/>')


def calcolatrice():
    tasti = ""
    for r in range(4):
        for c in range(4):
            colore = "#FF9F0A" if c == 3 else ("#A5A5AA" if r == 0 else "#4A4A50")
            tasti += f'<circle cx="{23 + c * 18}" cy="{30 + r * 15}" r="6.5" fill="{colore}"/>'
    return tessera("#2C2C30", "#0E0E10") + '<rect x="16" y="13" width="68" height="9" rx="3" fill="#3A3A40"/>' + tasti


def promemoria():
    righe = ""
    for k, (y, c) in enumerate(((28, "#0A84FF"), (50, "#FF3B30"), (72, "#FF9F0A"))):
        righe += (f'<circle cx="27" cy="{y}" r="8" fill="none" stroke="{c}" stroke-width="3.5"/>'
                  f'<circle cx="27" cy="{y}" r="4" fill="{c}"/>'
                  f'<rect x="42" y="{y - 2}" width="{40 - k * 6}" height="4" rx="2" fill="#D1D1D6"/>')
    return tessera("#FFFFFF", "#F2F2F4") + righe


def orologio():
    tacche = "".join(f'<rect x="49" y="18" width="2" height="{6 if k % 3 == 0 else 3}" fill="#1C1C1E" transform="rotate({k * 30} 50 50)"/>'
                     for k in range(12))
    return (tessera("#2C2C30", "#0E0E10") + '<circle cx="50" cy="50" r="34" fill="#FFFFFF"/>' + tacche +
            '<path d="M50 50 50 28M50 50 64 58" stroke="#1C1C1E" stroke-width="4" stroke-linecap="round"/>'
            '<path d="M50 56 50 22" stroke="#FF9F0A" stroke-width="1.6" stroke-linecap="round" transform="rotate(130 50 50)"/>'
            '<circle cx="50" cy="50" r="3" fill="#FF9F0A"/>')


def mail():
    return (tessera("#5AB0FF", "#1A62F0") +
            '<rect x="16" y="28" width="68" height="46" rx="8" fill="#FFFFFF"/>'
            '<path d="M18 31l32 23 32-23" fill="none" stroke="#C9DBF7" stroke-width="4" stroke-linejoin="round"/>')


def web():
    i, d = sfuma("#7CD4FF", "#1E78F0")
    return (tessera("#FFFFFF", "#F2F2F4") + d +
            f'<circle cx="50" cy="50" r="34" fill="url(#{i})"/>'
            '<g fill="none" stroke="#FFFFFF" stroke-width="3.5" stroke-opacity="0.9">'
            '<ellipse cx="50" cy="50" rx="14" ry="34"/><path d="M16 50h68M22 33h56M22 67h56"/></g>')


def password():
    i, d = sfuma("#FFE07A", "#E8A400")
    return (tessera("#4A4D55", "#1C1D21") + d +
            f'<circle cx="36" cy="50" r="17" fill="url(#{i})"/><circle cx="31" cy="50" r="5.5" fill="#2B2D33"/>'
            f'<path d="M50 45h34v10h-7v9h-8v-9H50Z" fill="url(#{i})"/>')


def registratore():
    altezze = (14, 26, 40, 22, 52, 34, 18, 30, 12)
    barre = "".join(f'<rect x="{14 + k * 8.2}" y="{50 - h / 2}" width="4.6" height="{h}" rx="2.3" fill="{"#FF3B30" if k == 4 else "#FFFFFF"}"/>'
                    for k, h in enumerate(altezze))
    return tessera("#2C2C30", "#0E0E10") + barre


CLASSICHE = {n: f for n, f in globals().items() if callable(f) and n not in ("tessera", "sfuma", "_id")}
