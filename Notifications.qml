// Notifications.qml - notification popups, top right under the bar, one window per monitor.
// Every screen shows the same popups (root.notifPopups, filled by the NotificationServer in
// shell.qml). Each card slides in from the right edge, stays root.notifTimeoutMs (paused while
// the mouse is on it), then slides out. No history.
// Left click: the app's default action (Discord jumps to the message) and close. Right click: close.
// Discord gets its own layout: avatar, user, server and #channel parsed from the summary.

import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import "components"

PanelWindow {
    id: notifWindow
    property var root

    // ── Tweakables ──
    property int cardWidth: 380
    property int cardRadius: 12
    property int cardPadding: 12
    property int cardGap: 8             // between stacked cards
    property int topGap: 6              // between the bar and the first card
    property int edgeGap: 8             // between the screen edge and the cards
    property int avatarSize: 44
    property int badgeSize: 18          // app icon on the avatar's corner (Discord)
    property int bodyLines: 4           // longer messages end in "..."
    property int summarySize: 14
    property int bodySize: 13
    property int headerSize: 11
    property color discordColor: "#5865F2"      // Discord blurple: badge + server name
    property string discordGlyph: "\u{f066f}"   // nf-md-discord
    property string dmLabel: "Direct Message"

    anchors { top: true; right: true }
    margins.top: topGap
    exclusionMode: ExclusionMode.Normal     // zone 0: sits below the bar instead of over it
    implicitWidth: cardWidth + edgeGap
    implicitHeight: Math.max(1, stack.height)
    color: "transparent"
    visible: root.notifPopups.length > 0
    mask: Region { item: stack }            // clicks between / beside cards reach the windows below

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Discord's summary: "user (#channel, Server)", "user (thread, #channel, Server)",
    // "user (Group name)" for a group DM, plain "user" for a DM
    function discordInfo(n) {
        if (!n) return null
        if ((n.appName + " " + n.desktopEntry).toLowerCase().indexOf("discord") < 0) return null
        var m = /^(.*) \((.*)\)$/.exec(n.summary)
        if (!m) return { user: n.summary, server: dmLabel, channel: "" }
        var k = m[2].lastIndexOf(", ")
        if (k < 0) return { user: m[1], server: m[2], channel: "" }
        return { user: m[1], server: m[2].slice(k + 2), channel: m[2].slice(0, k) }
    }

    // appIcon may be an icon name, a path or a URL
    function iconSource(name) {
        if (!name) return ""
        if (name.indexOf("://") > 0) return name
        if (name.startsWith("/")) return "file://" + name
        return Quickshell.iconPath(name, true)
    }

    Column {
        id: stack
        width: notifWindow.cardWidth
        spacing: 0

        Repeater {
            model: ScriptModel { values: notifWindow.root.notifPopups }

            Item {
                id: card
                required property var modelData
                readonly property var n: modelData.notif
                readonly property var discord: notifWindow.discordInfo(n)
                readonly property string appIconSrc: n ? notifWindow.iconSource(n.appIcon) || notifWindow.iconSource(n.desktopEntry) : ""
                readonly property string avatarSrc: n && n.image ? n.image : appIconSrc
                property bool shown: false
                readonly property bool out: !shown || modelData.leaving
                property bool collapsed: false

                width: notifWindow.cardWidth
                // Full height at once (the card only slides in sideways); after it has slid out,
                // the slot shrinks so the ones below move up
                height: collapsed ? 0 : face.height + notifWindow.cardGap
                Behavior on height {
                    enabled: card.collapsed
                    NumberAnimation { duration: notifWindow.root.notifAnimMs; easing.type: Easing.OutQuint }
                }
                Component.onCompleted: shown = true
                Timer {
                    running: card.modelData.leaving
                    interval: notifWindow.root.notifAnimMs
                    onTriggered: card.collapsed = true
                }

                PopupCard {
                    id: face
                    root: notifWindow.root
                    width: parent.width
                    height: content.height + notifWindow.cardPadding * 2
                    radius: notifWindow.cardRadius
                    x: card.out ? notifWindow.cardWidth + notifWindow.edgeGap : 0
                    Behavior on x { NumberAnimation { duration: notifWindow.root.notifAnimMs; easing.type: Easing.OutQuint } }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onEntered: card.modelData.hovered++
                        onExited: card.modelData.hovered = Math.max(0, card.modelData.hovered - 1)
                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton && card.n) {
                                var acts = card.n.actions
                                for (var i = 0; i < acts.length; i++)
                                    if (acts[i].identifier === "default") { acts[i].invoke(); break }
                            }
                            notifWindow.root.closeNotif(card.modelData, true)
                        }
                    }

                    Row {
                        id: content
                        x: notifWindow.cardPadding
                        y: notifWindow.cardPadding
                        width: parent.width - notifWindow.cardPadding * 2
                        spacing: 12

                        // Avatar (Discord: the sender's picture) or the app icon, round
                        Item {
                            width: notifWindow.avatarSize
                            height: notifWindow.avatarSize
                            visible: card.avatarSrc !== ""

                            ClippingRectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: notifWindow.root.colSurface
                                Image {
                                    anchors.fill: parent
                                    source: card.avatarSrc
                                    fillMode: Image.PreserveAspectCrop
                                    sourceSize: Qt.size(notifWindow.avatarSize * 2, notifWindow.avatarSize * 2)
                                    smooth: true; mipmap: true
                                }
                            }

                            // Discord badge on the corner of the avatar
                            Rectangle {
                                visible: card.discord !== null
                                width: notifWindow.badgeSize; height: width; radius: width / 2
                                anchors.right: parent.right; anchors.bottom: parent.bottom
                                anchors.margins: -3
                                color: notifWindow.discordColor
                                border.color: notifWindow.root.colBlack
                                border.width: 2
                                Text {
                                    anchors.centerIn: parent
                                    text: notifWindow.discordGlyph
                                    color: "white"
                                    font.family: notifWindow.root.fontFamily
                                    font.pixelSize: 10
                                }
                            }
                        }

                        Column {
                            width: content.width - (card.avatarSrc !== "" ? notifWindow.avatarSize + content.spacing : 0)
                            spacing: 2

                            // Header: "Server  #channel" for Discord, the app name otherwise
                            Row {
                                width: parent.width
                                spacing: 6
                                Text {
                                    id: headerMain
                                    text: card.discord ? card.discord.server : (card.n ? card.n.appName : "")
                                    color: card.discord ? notifWindow.discordColor : notifWindow.root.colSubtext
                                    font.family: notifWindow.root.fontFamily
                                    font.pixelSize: notifWindow.headerSize
                                    font.bold: card.discord !== null
                                    elide: Text.ElideRight
                                    width: Math.min(implicitWidth, parent.width - (headerChannel.visible ? headerChannel.implicitWidth + parent.spacing : 0))
                                }
                                Text {
                                    id: headerChannel
                                    visible: card.discord !== null && card.discord.channel !== ""
                                    text: card.discord ? card.discord.channel : ""
                                    color: notifWindow.root.colSubtext
                                    font.family: notifWindow.root.fontFamily
                                    font.pixelSize: notifWindow.headerSize
                                    elide: Text.ElideRight
                                    width: Math.min(implicitWidth, parent.width - headerMain.width - parent.spacing)
                                }
                            }

                            // Discord: the sender; otherwise the summary
                            Text {
                                width: parent.width
                                text: card.discord ? card.discord.user : (card.n ? card.n.summary : "")
                                visible: text !== ""
                                color: notifWindow.root.colText
                                font.family: notifWindow.root.fontFamily
                                font.pixelSize: notifWindow.summarySize
                                font.bold: true
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: card.n ? card.n.body : ""
                                visible: text !== ""
                                color: notifWindow.root.colText
                                opacity: 0.85
                                font.family: notifWindow.root.fontFamily
                                font.pixelSize: notifWindow.bodySize
                                textFormat: Text.StyledText
                                wrapMode: Text.Wrap
                                maximumLineCount: notifWindow.bodyLines
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
