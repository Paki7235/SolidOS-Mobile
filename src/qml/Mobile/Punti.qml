// Titolo grande: titoli delle app, ora e numeri grandi. Nelle vesti Prisma è più pieno e stretto.
import QtQuick
import SolidUI

Text {
    color: tel.pal.testo
    font.family: Tema.font
    font.weight: tel.solido ? Font.Black : Font.Bold
    font.pixelSize: 32
    font.letterSpacing: tel.solido ? -1.2 : -0.6
}
