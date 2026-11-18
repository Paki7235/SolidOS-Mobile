// Animazione comune di pagine e tendine: si apre con una curva «quint» (parte veloce e si
// posa morbida) e si chiude più in fretta accelerando (uscita ≈ 65% dell'entrata).
// «apre» dice in che verso si sta andando.
import QtQuick

NumberAnimation {
    property bool apre: true
    duration: apre ? tel.tEntrata : tel.tNormale
    easing.type: apre ? Easing.OutQuint : Easing.InQuad
}
