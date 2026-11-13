import QtQuick
import QtQuick.Controls

Label {
    property int livello: 1
    color: Tema.testo
    font.family: Tema.font
    font.pointSize: livello === 1 ? Tema.fontDimensione + 9 : (livello === 2 ? Tema.fontDimensione + 4 : Tema.fontDimensione + 1)
    font.weight: Font.DemiBold
    wrapMode: Text.Wrap
    textFormat: Text.PlainText
}
