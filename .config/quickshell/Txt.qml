import QtQuick

// Text with the shell's font defaults.
Text {
    color: Theme.dim
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    font.weight: Theme.fontWeight
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
}
