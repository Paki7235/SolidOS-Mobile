import QtQuick
import QtQuick.Controls

Label {
    property bool secondario: false
    color: secondario ? Tema.testoSecondario : Tema.testo
    font.family: Tema.font
    font.pointSize: Tema.fontDimensione
    wrapMode: Text.Wrap
    textFormat: Text.PlainText
}
