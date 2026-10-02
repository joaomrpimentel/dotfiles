import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// What the clock pill opens into. Replaces gsimplecal.
//
// Scroll to change month, click the month title to jump back to today. Every
// open starts on the current month.
Item {
    id: root

    property bool shown: false

    readonly property var locale: Qt.locale("pt_BR")
    readonly property int cell: 34
    readonly property int pad: 16

    property int month: new Date().getMonth()
    property int year: new Date().getFullYear()

    function shift(delta) {
        const d = new Date(year, month + delta, 1);
        month = d.getMonth();
        year = d.getFullYear();
    }

    function today() {
        const d = new Date();
        month = d.getMonth();
        year = d.getFullYear();
    }

    onShownChanged: if (shown) today()

    implicitWidth: cell * 7 + pad * 2
    implicitHeight: column.implicitHeight + pad * 2

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.shift(event.angleDelta.y > 0 ? -1 : 1)
    }

    ColumnLayout {
        id: column
        x: root.pad
        y: root.pad
        width: root.cell * 7
        spacing: 6

        Reveal {
            shown: root.shown
            order: 0
            Layout.fillWidth: true
            Layout.preferredHeight: 26

            RowLayout {
                width: column.width
                height: 26

                Txt {
                    text: "󰅁"
                    Layout.preferredWidth: root.cell
                    horizontalAlignment: Text.AlignHCenter
                    color: prevArea.containsMouse ? Theme.fg : Theme.faint
                    MouseArea { id: prevArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.shift(-1) }
                }
                Txt {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.fg
                    font.pixelSize: Theme.fontSize + 1
                    text: {
                        const name = root.locale.standaloneMonthName(root.month, Locale.LongFormat);
                        return `${name.charAt(0).toUpperCase()}${name.slice(1)} ${root.year}`;
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.today() }
                }
                Txt {
                    text: "󰅂"
                    Layout.preferredWidth: root.cell
                    horizontalAlignment: Text.AlignHCenter
                    color: nextArea.containsMouse ? Theme.fg : Theme.faint
                    MouseArea { id: nextArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.shift(1) }
                }
            }
        }

        DayOfWeekRow {
            locale: root.locale
            Layout.fillWidth: true
            spacing: 0
            padding: 0
            delegate: Reveal {
                required property int index
                required property string narrowName
                shown: root.shown
                // Starts after the title and sweeps left to right.
                order: index + 1
                implicitWidth: root.cell
                implicitHeight: 20
                Txt {
                    width: root.cell
                    height: 20
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.faint
                    font.pixelSize: Theme.fontSize - 2
                    text: narrowName.toUpperCase()
                }
            }
        }

        MonthGrid {
            id: grid
            locale: root.locale
            month: root.month
            year: root.year
            Layout.fillWidth: true
            spacing: 0
            padding: 0

            delegate: Reveal {
                id: day
                required property int index
                required property var model

                shown: root.shown
                // A diagonal wave from the top-left corner: row + column, so the
                // whole month ripples in over ~12 steps instead of 42.
                order: Math.floor(index / 7) + index % 7 + 2

                implicitWidth: root.cell
                implicitHeight: root.cell - 4

                Rectangle {
                    anchors.centerIn: parent
                    width: root.cell - 6
                    height: root.cell - 8
                    radius: height / 2
                    color: day.model.today ? Theme.fg
                         : dayArea.containsMouse ? Theme.hover
                         : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Txt {
                        anchors.centerIn: parent
                        text: day.model.day
                        color: day.model.today ? "#121214"
                             : day.model.month === root.month ? Theme.fg
                             : Qt.rgba(1, 1, 1, 0.28)
                        font.weight: day.model.today ? Font.Bold : Theme.fontWeight
                    }

                    MouseArea { id: dayArea; anchors.fill: parent; hoverEnabled: true }
                }
            }
        }
    }
}
