// Animazione comune di pagine e tendine: si apre con una curva «expo» (veloce all'inizio,
// morbida alla fine) e si chiude più in fretta accelerando, come chiedono le regole del
// movimento (uscita ≈ 65% dell'entrata). «apre» dice in che verso si sta andando.
import QtQuick

NumberAnimation {
    property bool apre: true
    duration: apre ? tel.tEntrata : tel.tNormale
    easing.type: apre ? Easing.OutExpo : Easing.InCubic
}
