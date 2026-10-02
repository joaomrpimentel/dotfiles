import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

// One notification: icon or image, app, summary, body, action buttons.
// Used by the toasts and by the control center list. Transparent on purpose —
// whoever holds it provides the glass.
Item {
    id: root

    required property Notification notif
    // Toasts close the toast; the center dismisses the notification.
    signal closeClicked
    signal bodyClicked

    readonly property bool critical: notif?.urgency === NotificationUrgency.Critical

    // Chromium-based browsers (Vivaldi here) prefix web notifications with the
    // site as a link — `<a href="https://web.whatsapp.com/">web.whatsapp.com</a>`
    // then a blank line, then the actual message. Rendered as-is, the link is
    // what you see first, in link blue. The site moves up next to the app name
    // and the body keeps only the message.
    readonly property var parsed: {
        const raw = notif?.body ?? "";
        const m = raw.match(/^\s*<a\s+href="[^"]*"\s*>([^<]*)<\/a>\s*/i);
        const rest = (m ? raw.slice(m[0].length) : raw).trim();
        return {
            origin: m ? m[1].trim() : "",
            // StyledText collapses newlines like HTML does; keep the sender's.
            body: rest.replace(/\r?\n/g, "<br>")
        };
    }
    readonly property int pad: 12

    implicitWidth: 380
    implicitHeight: content.implicitHeight + pad * 2

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.bodyClicked()
    }

    RowLayout {
        id: content
        x: root.pad
        y: root.pad
        width: parent.width - root.pad * 2
        spacing: 12

        // An inline image (album art, screenshot) beats the app icon.
        Item {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 40
            implicitHeight: 40
            visible: image.status === Image.Ready || icon.status === Image.Ready

            ClippingRectangle {
                anchors.fill: parent
                radius: 10
                color: "transparent"
                visible: image.status === Image.Ready
                Image {
                    id: image
                    anchors.fill: parent
                    source: root.notif?.image ?? ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(80, 80)
                    asynchronous: true
                }
            }
            IconImage {
                id: icon
                anchors.fill: parent
                implicitSize: 40
                visible: image.status !== Image.Ready
                source: {
                    const i = root.notif?.appIcon ?? "";
                    if (!i)
                        return "";
                    // Absolute paths need the scheme, or they resolve against qrc:.
                    if (i.startsWith("/"))
                        return `file://${i}`;
                    return i.includes("://") ? i : Quickshell.iconPath(i, true);
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Txt {
                    Layout.fillWidth: true
                    text: [root.notif?.appName ?? "", root.parsed.origin].filter(t => t).join("  ·  ")
                    color: Theme.faint
                    font.pixelSize: Theme.fontSize - 2
                    elide: Text.ElideRight
                }
                Txt {
                    text: "󰅖"
                    color: closeArea.containsMouse ? Theme.fg : Theme.faint
                    opacity: hover.containsMouse || closeArea.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        onClicked: root.closeClicked()
                    }
                }
            }

            Txt {
                Layout.fillWidth: true
                text: root.notif?.summary ?? ""
                color: root.critical ? Theme.urgent : Theme.fg
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Txt {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.parsed.body
                textFormat: Text.StyledText
                color: Theme.dim
                font.pixelSize: Theme.fontSize - 1
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                linkColor: Theme.fg
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 6
                visible: actions.count > 0

                Repeater {
                    id: actions
                    // "default" is what clicking the card does; it gets no button.
                    model: (root.notif?.actions ?? []).filter(a => a.identifier !== "default")

                    Rectangle {
                        required property NotificationAction modelData
                        width: label.implicitWidth + 20
                        height: 26
                        radius: 13
                        color: actionArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Theme.hover
                        border.width: 1
                        border.color: Theme.border
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Txt {
                            id: label
                            anchors.centerIn: parent
                            text: modelData.text
                            color: Theme.fg
                            font.pixelSize: Theme.fontSize - 1
                        }
                        MouseArea {
                            id: actionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: modelData.invoke()
                        }
                    }
                }
            }
        }
    }
}
