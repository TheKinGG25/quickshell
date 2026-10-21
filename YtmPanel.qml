// YtmPanel.qml - music player card that drops down under YtmPill (left click on the pill toggles it).
// Layout: [ cover art / title / artist / seek bar + times / prev play next ] [ side button column ]
// Data and commands: root.ytm* and root.ytmCommand() in shell.qml (YouTube Music Desktop 2 API).
// Closes when the mouse leaves the hover area (the card + hoverMargin around it).
// Side buttons are a list in Tweakables (`sideButtons`).

import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "components"

PanelWindow {
    id: ytmPanel
    property var root

    // ── Tweakables ──
    property int cardWidth: 340
    property int cardHeight: 448
    property int cardPadding: 20
    property int cardRadius: 16
    property int columnGap: 20                  // between the player column and the side column
    property int sideWidth: 56                  // side button column
    property int sidePadding: 6
    property int artRadius: 10                  // cover art corners
    property int topGap: 0                      // space between the bar and the card (0 = touching)
    property int hoverMargin: 40                // invisible area around the card that still counts as "inside"
    property int openAnimMs: 300                // drop-down animation length
    property int closeAnimMs: 200               // roll-up animation length
    property int seekWheelStep: 5               // seconds per scroll notch on the seek bar

    property color cardColor: "#ff4444"
    property color sideColor: "#22000000"       // side column background
    property color artPlaceholder: "#cc2222"    // behind the cover while it loads
    property color titleColor: "black"
    property color artistColor: "#1a0000"
    property color buttonColor: "#33000000"
    property color buttonHover: "#55000000"
    property color iconColor: "black"
    property color activeIconColor: "white"     // liked / disliked / repeat on
    property color playColor: "#1a0000"         // the big play / pause button
    property color playHover: "#000000"
    property color playIconColor: "#ff4444"
    property color seekFill: "#1a0000"
    property color seekEmpty: "#40000000"
    property int titleFontSize: 17
    property int artistFontSize: 13
    property int timeFontSize: 12

    // Nerd Font code points (https://www.nerdfonts.com/cheat-sheet)
    property string prevIcon: "\u{f04ae}"
    property string nextIcon: "\u{f04ad}"
    property string playIcon: "\u{f040a}"
    property string pauseIcon: "\u{f03e4}"
    property string noArtIcon: "\u{f075a}"

    // Side column, top to bottom. action: what the click does (see sideAction below).
    // activeIcon is shown while the state is on (liked, disliked, repeat).
    property var sideButtons: [
        { action: "like",    label: "Like",    icon: "\u{f0514}", activeIcon: "\u{f0513}" },
        { action: "dislike", label: "Dislike", icon: "\u{f0512}", activeIcon: "\u{f0511}" },
        { action: "shuffle", label: "Shuffle", icon: "\u{f049d}", activeIcon: "" },
        { action: "repeat",  label: "Repeat",  icon: "\u{f0457}", activeIcon: "\u{f0456}" },
        { action: "close",   label: "Close",   icon: "\u{f0156}", activeIcon: "" }
    ]

    // Width left for the cover art / player column
    readonly property int artSize: cardWidth - 2 * cardPadding - columnGap - sideWidth

    // Card's left edge on screen: under the pill, but never past the right screen edge
    readonly property int cardScreenX: Math.max(0, Math.min(root.ytmPillLeftX, screen.width - cardWidth - 8))
    // Window = card + hoverMargin left, right and below (clamped to the screen)
    readonly property int windowScreenX: Math.max(0, Math.min(cardScreenX - hoverMargin, screen.width - implicitWidth))

    anchors { top: true; left: true }
    margins.top: topGap
    margins.left: windowScreenX
    implicitWidth: cardWidth + 2 * hoverMargin
    implicitHeight: cardHeight + hoverMargin
    color: "transparent"

    // `shown` lags behind `wantOpen` on close so the roll-up animation can play
    readonly property bool wantOpen: root.activeYtmScreen === screen
    property bool shown: false
    visible: shown

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Drop down on open, roll up on close
    onWantOpenChanged: {
        if (wantOpen) {
            collapseAnim.stop()
            if (!shown) card.height = 0
            shown = true
            expandAnim.restart()
        } else {
            expandAnim.stop()
            collapseAnim.restart()
        }
    }

    function isActive(action) {
        if (action === "like") return root.ytmLiked
        if (action === "dislike") return root.ytmDisliked
        if (action === "repeat") return root.ytmLoop
        return false
    }

    function sideAction(action) {
        if (action === "like") { root.ytmLiked = !root.ytmLiked; root.ytmCommand("like", root.ytmLiked) }
        else if (action === "dislike") { root.ytmDisliked = !root.ytmDisliked; root.ytmCommand("dislike", root.ytmDisliked) }
        else if (action === "shuffle") root.ytmCommand("shuffle")
        else if (action === "repeat") root.ytmCommand("repeat")
        else if (action === "close") root.activeYtmScreen = null
    }

    // Seconds -> "m:ss"
    function formatTime(secs) {
        if (!secs || secs <= 0) return "0:00"
        var s = Math.floor(secs)
        var m = Math.floor(s / 60)
        var rem = s % 60
        return m + ":" + (rem < 10 ? "0" : "") + rem
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onExited: root.activeYtmScreen = null

        // Visible card (its height animates from 0 to cardHeight)
        Rectangle {
            id: card
            x: ytmPanel.cardScreenX - ytmPanel.windowScreenX
            y: 0
            width: ytmPanel.cardWidth
            height: 0
            clip: true
            radius: ytmPanel.cardRadius
            color: ytmPanel.cardColor

            NumberAnimation {
                id: expandAnim
                target: card
                property: "height"
                to: ytmPanel.cardHeight
                duration: ytmPanel.openAnimMs
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                id: collapseAnim
                target: card
                property: "height"
                to: 0
                duration: ytmPanel.closeAnimMs
                easing.type: Easing.InCubic
                onFinished: if (!ytmPanel.wantOpen) ytmPanel.shown = false
            }

            RowLayout {
                // Fixed height so the content does not squash while the card animates open
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: ytmPanel.cardPadding
                height: ytmPanel.cardHeight - 2 * ytmPanel.cardPadding
                spacing: ytmPanel.columnGap

                // ── Player column ──
                ColumnLayout {
                    Layout.preferredWidth: ytmPanel.artSize
                    Layout.fillHeight: true
                    spacing: 0

                    // Cover art. ClippingRectangle (not Rectangle + clip) so the image follows the rounded corners
                    ClippingRectangle {
                        Layout.preferredWidth: ytmPanel.artSize
                        Layout.preferredHeight: ytmPanel.artSize
                        radius: ytmPanel.artRadius
                        color: ytmPanel.artPlaceholder

                        Text {
                            anchors.centerIn: parent
                            visible: cover.status !== Image.Ready
                            text: ytmPanel.noArtIcon
                            color: ytmPanel.titleColor
                            font.family: root.fontFamily
                            font.pixelSize: 56
                        }
                        Image {
                            id: cover
                            anchors.fill: parent
                            source: root.ytmArt
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Title + artist
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            text: root.ytmTitle
                            color: ytmPanel.titleColor
                            font.pixelSize: ytmPanel.titleFontSize
                            font.family: root.fontFamily
                            font.bold: true
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.ytmArtist
                            color: ytmPanel.artistColor
                            font.pixelSize: ytmPanel.artistFontSize
                            font.family: root.fontFamily
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Seek bar + elapsed / total
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        VolumeBarSlider {
                            id: seekSlider
                            Layout.fillWidth: true
                            implicitHeight: 12
                            trackHeight: 6
                            from: 0
                            to: Math.max(1, root.ytmDuration)
                            wheelStep: ytmPanel.seekWheelStep
                            fillColor: ytmPanel.seekFill
                            emptyColor: ytmPanel.seekEmpty

                            // Follows playback except while dragging
                            Binding {
                                target: seekSlider
                                property: "value"
                                value: root.ytmProgressSeconds
                                when: !seekSlider.pressed
                            }

                            function seekHere() {
                                root.ytmProgressSeconds = value
                                root.ytmCommand("seek", { time: Math.round(value * 1000), type: "seek" })
                            }
                            onPressedChanged: if (!pressed) seekHere()     // drag released
                            onMoved: if (!pressed) seekHere()              // scroll wheel
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: ytmPanel.formatTime(seekSlider.value)
                                color: ytmPanel.artistColor
                                font.pixelSize: ytmPanel.timeFontSize
                                font.family: root.fontFamily
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: ytmPanel.formatTime(root.ytmDuration)
                                color: ytmPanel.artistColor
                                font.pixelSize: ytmPanel.timeFontSize
                                font.family: root.fontFamily
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Previous | play/pause | next
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 24

                        IconButton {
                            text: "Previous"
                            glyph: ytmPanel.prevIcon
                            fontFamily: root.fontFamily
                            baseColor: ytmPanel.buttonColor
                            hoverColor: ytmPanel.buttonHover
                            iconColor: ytmPanel.iconColor
                            onClicked: root.ytmCommand("prev")
                        }
                        IconButton {
                            text: root.ytmPlaying ? "Pause" : "Play"
                            glyph: root.ytmPlaying ? ytmPanel.pauseIcon : ytmPanel.playIcon
                            size: 52
                            iconSize: 24
                            cornerRadius: 12
                            fontFamily: root.fontFamily
                            baseColor: ytmPanel.playColor
                            hoverColor: ytmPanel.playHover
                            iconColor: ytmPanel.playIconColor
                            onClicked: {
                                root.ytmPlaying = !root.ytmPlaying     // flip right away, the poll confirms it
                                root.ytmCommand("toggle-play-state")
                            }
                        }
                        IconButton {
                            text: "Next"
                            glyph: ytmPanel.nextIcon
                            fontFamily: root.fontFamily
                            baseColor: ytmPanel.buttonColor
                            hoverColor: ytmPanel.buttonHover
                            iconColor: ytmPanel.iconColor
                            onClicked: root.ytmCommand("next")
                        }
                    }
                }

                // ── Side column ──
                Rectangle {
                    Layout.preferredWidth: ytmPanel.sideWidth
                    Layout.fillHeight: true
                    radius: 12
                    color: ytmPanel.sideColor

                    // Buttons spread evenly from top to bottom
                    Column {
                        id: sideCol
                        anchors.fill: parent
                        anchors.margins: ytmPanel.sidePadding
                        spacing: ytmPanel.sideButtons.length > 1
                            ? (height - ytmPanel.sideButtons.length * (ytmPanel.sideWidth - 2 * ytmPanel.sidePadding)) / (ytmPanel.sideButtons.length - 1)
                            : 0

                        Repeater {
                            model: ytmPanel.sideButtons
                            delegate: IconButton {
                                text: modelData.label
                                glyph: modelData.icon
                                activeGlyph: modelData.activeIcon
                                active: ytmPanel.isActive(modelData.action)
                                size: ytmPanel.sideWidth - 2 * ytmPanel.sidePadding
                                fontFamily: root.fontFamily
                                baseColor: ytmPanel.buttonColor
                                hoverColor: ytmPanel.buttonHover
                                iconColor: ytmPanel.iconColor
                                activeColor: ytmPanel.activeIconColor
                                onClicked: ytmPanel.sideAction(modelData.action)
                            }
                        }
                    }
                }
            }
        }
    }
}
