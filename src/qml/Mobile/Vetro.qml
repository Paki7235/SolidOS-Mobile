// Superficie «vetro» del design: semitrasparente, bordo chiaro, angoli arrotondati.
// (Niente sfocatura vera: costa troppa memoria e batteria sui telefoni da 2 GB.)
import QtQuick

Rectangle {
    color: tel.pal.vetro
    border.color: tel.pal.vetroBordo
    border.width: 1
    radius: 22
}
