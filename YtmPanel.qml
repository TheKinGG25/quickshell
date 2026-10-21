// YtmPanel.qml - music player that grows out of YtmPill (left click on the pill toggles it).
// Opening morphs a copy of the pill (position, size, corners, color) into the player card
// (cover art / title / artist / seek bar + times / prev play next), centered on the pill, while the
// real pill hides (root.ytmPanelScreen). A separate side card of buttons floats to the right, below the bar.
// Data and commands: root.ytm* and root.ytmCommand() in shell.qml (YouTube Music Desktop 2 API).
// Closes when the mouse leaves the hover area, or on a click where the pill was.
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
    property int artSize: 240                   // cover art (square); the player card is this + 2 * cardPadding wide
    property int cardHeight: 448
    property int cardPadding: 20
    property int cardRadius: 16
    property int sideWidth: 56                  // floating side button card
    property int sidePadding: 6
    property int sideGap: 10                    // space between the player card and the side card
    property int artRadius: 10                  // cover art corners
    property int topGap: 0                      // space between the bar and the side card (0 = touching)
    property int hoverMargin: 80                // invisible area around the cards that still counts as "inside"
    property int openAnimMs: 350                // pill -> player morph length
    property int closeAnimMs: 250               // player -> pill morph length
    property int handoffMs: 32                  // overlap when swapping the real pill for its copy
    property real fadeStart: 0.15               // morph value where the pill copy starts turning into the content
    property real fadeSpan: 0.35                // and how much morph that crossfade takes
    property int seekWheelStep: 5               // seconds per scroll notch on the seek bar

    // ── Colors ── the player uses three: the red ground, a near-black ink drawn on it, and white
    // for a toggle that is on. The two shades below are derived, so changing `accent` or `ink`
    // recolors everything. Hover and press need no color: IconButton overlays its own icon color.
    property color accent: "#ff4444"        // background of both cards (the morph starts from the pill's
                                            // color), and the icon inside the play / pause button
    property color ink: "#1a0000"           // everything on the red: title, artist, times, icons,
                                            // the play / pause button and the filled seek bar
    property color active: "white"          // icon of a toggle that is on (liked, disliked, repeat)
    property real washAlpha: 0.22           // strength of the ink wash (small buttons, empty seek track)

    // Derived. Qt.alpha() does not exist in this Qt, hence Qt.rgba() with the ink's channels.
    readonly property color inkWash: Qt.rgba(ink.r, ink.g, ink.b, washAlpha)
    readonly property color accentDark: Qt.darker(accent, 1.25)   // behind the cover while it loads
    property int titleFontSize: 17
    property int artistFontSize: 13
    property int timeFontSize: 12

    // Nerd Font code points (https://www.nerdfonts.com/cheat-sheet)
    property string prevIcon: "\u{f04ae}"
    property string nextIcon: "\u{f04ad}"
    property string playIcon: "\u{f040a}"
    property string pauseIcon: "\u{f03e4}"
    property string noArtIcon: "\u{f075a}"

    // Side card, top to bottom. action: what the click does (see sideAction below).
    // activeIcon is shown while the state is on (liked, disliked, repeat).
    property var sideButtons: [
        { action: "like",    label: "Like",    icon: "\u{f0514}", activeIcon: "\u{f0513}" },
        { action: "dislike", label: "Dislike", icon: "\u{f0512}", activeIcon: "\u{f0511}" },
        { action: "shuffle", label: "Shuffle", icon: "\u{f049d}", activeIcon: "" },
        { action: "repeat",  label: "Repeat",  icon: "\u{f0457}", activeIcon: "\u{f0456}" },
        { action: "close",   label: "Close",   icon: "\u{f0156}", activeIcon: "" }
    ]

    // ── Geometry (screen coordinates; the window starts at the top of the screen, over the bar) ──
    // This screen's entry in root.ytmPillGeom (written by its own Bar); empty until that Bar reports
    readonly property var pillGeom: screen ? root.ytmPillGeom[screen.name] : undefined
    readonly property int pillX: pillGeom ? pillGeom.x : 0
    readonly property int pillY: pillGeom ? pillGeom.y : 0
    readonly property int pillW: root.ytmWidth
    readonly property int pillH: root.pillHeight
    readonly property int playerWidth: artSize + 2 * cardPadding
    readonly property int groupWidth: playerWidth + sideGap + sideWidth     // player card + gap + side card
    // Player card: centered on the pill, its top where the pill's top is,
    // shifted left if the side card would go past the right screen edge
    readonly property int cardScreenX: Math.max(0, Math.min(Math.round(pillX + pillW / 2 - playerWidth / 2),
                                                            screen.width - groupWidth - 8))
    readonly property int sideScreenX: cardScreenX + playerWidth + sideGap
    readonly property int sideTop: root.barHeight + topGap
    readonly property int cardBottom: pillY + cardHeight        // bottom edge of the player card
    // The side card starts below the bar but ends level with the player card, so it is shorter
    readonly property int sideHeight: Math.max(0, cardBottom - sideTop)
    // Window = pill + both cards + hoverMargin left, right and below (clamped to the screen)
    readonly property int groupLeft: Math.min(pillX, cardScreenX)
    readonly property int groupRight: Math.max(pillX + pillW, sideScreenX + sideWidth)
    readonly property int windowScreenX: Math.max(0, Math.min(groupLeft - hoverMargin, screen.width - implicitWidth))

    // 0 = looks exactly like the pill, 1 = full player
    property real morph: 0

    // Crossfade between the pill copy and the player content. ONE ramp drives both, so the two
    // opacities always add up to 1. With separate ramps there was a band (morph 0.33 to 0.40)
    // where neither was drawn and the card flashed empty for a frame on the way out.
    readonly property real contentFade: Math.max(0, Math.min(1, (morph - fadeStart) / fadeSpan))

    anchors { top: true; left: true }
    exclusionMode: ExclusionMode.Ignore         // start at the very top of the screen, over the bar
    margins.top: 0
    margins.left: windowScreenX
    implicitWidth: groupRight - groupLeft + 2 * hoverMargin
    implicitHeight: cardBottom + hoverMargin
    color: "transparent"

    // Only the pill's spot in the bar and everything below the bar take the mouse,
    // so the volume / battery pills next to it stay clickable
    mask: Region {
        item: belowBarZone
        Region { item: pillZone }
    }

    // `shown` lags behind `wantOpen` on close so the morph back into the pill can play
    readonly property bool wantOpen: root.activeYtmScreen === screen
    property bool shown: false
    visible: shown

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // The copy and the real pill are identical and sit in the same spot, so drawing BOTH for a
    // moment is invisible, while drawing NEITHER is a visible blink. They live in different
    // windows (the bar and this panel) and Wayland does not have to present two surfaces in the
    // same frame, so always overlap them instead of swapping at one instant: on the way in show
    // the panel first and hide the real pill a tick later, on the way out bring the real pill
    // back first and drop the panel a tick later.
    onWantOpenChanged: {
        if (wantOpen) {
            collapseAnim.stop()
            dropPanelTimer.stop()
            if (!shown) morph = 0
            shown = true                // panel up, the copy covers the real pill
            hidePillTimer.restart()     // only then hide the real pill underneath it
            expandAnim.restart()
        } else {
            expandAnim.stop()
            hidePillTimer.stop()
            collapseAnim.restart()      // the real pill comes back in collapseAnim.onFinished
        }
    }

    Timer {
        id: hidePillTimer
        interval: ytmPanel.handoffMs
        onTriggered: if (ytmPanel.shown) root.ytmPanelScreen = ytmPanel.screen
    }
    Timer {
        id: dropPanelTimer
        interval: ytmPanel.handoffMs
        onTriggered: if (!ytmPanel.wantOpen) ytmPanel.shown = false
    }

    NumberAnimation {
        id: expandAnim
        target: ytmPanel
        property: "morph"
        to: 1
        duration: ytmPanel.openAnimMs
        easing.type: Easing.OutCubic
    }
    NumberAnimation {
        id: collapseAnim
        target: ytmPanel
        property: "morph"
        to: 0
        duration: ytmPanel.closeAnimMs
        easing.type: Easing.InOutCubic
        onFinished: {
            if (ytmPanel.wantOpen) return
            // Real pill back first, panel dropped a tick later (see onWantOpenChanged)
            if (root.ytmPanelScreen === ytmPanel.screen) root.ytmPanelScreen = null
            dropPanelTimer.restart()
        }
    }

    function lerp(a, b, t) { return a + (b - a) * t }
    function mixColor(a, b, t) { return Qt.rgba(lerp(a.r, b.r, t), lerp(a.g, b.g, t), lerp(a.b, b.b, t), lerp(a.a, b.a, t)) }

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

    // Input areas used by `mask` (invisible)
    Item {
        id: belowBarZone
        y: root.barHeight
        width: ytmPanel.implicitWidth
        height: ytmPanel.implicitHeight - root.barHeight
    }
    Item {
        id: pillZone
        x: ytmPanel.pillX - ytmPanel.windowScreenX
        width: ytmPanel.pillW
        height: root.barHeight
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onExited: root.activeYtmScreen = null

        // Click where the pill was: close, like clicking the pill itself
        MouseArea {
            x: pillZone.x; y: pillZone.y; width: pillZone.width; height: pillZone.height
            onClicked: root.activeYtmScreen = null
        }

        // ── Player card: grows from the pill's rectangle to the full card ──
        Rectangle {
            id: card
            x: ytmPanel.lerp(ytmPanel.pillX, ytmPanel.cardScreenX, ytmPanel.morph) - ytmPanel.windowScreenX
            y: ytmPanel.pillY
            width: ytmPanel.lerp(ytmPanel.pillW, ytmPanel.playerWidth, ytmPanel.morph)
            height: ytmPanel.lerp(ytmPanel.pillH, ytmPanel.cardHeight, ytmPanel.morph)
            radius: ytmPanel.lerp(root.pillRadius, ytmPanel.cardRadius, ytmPanel.morph)
            color: ytmPanel.mixColor(pillCopy.pillColor, ytmPanel.accent, ytmPanel.morph)
            clip: true

            ColumnLayout {
                // Fixed size so the content does not squash while the card grows; fades in during the second half
                x: ytmPanel.cardPadding
                y: ytmPanel.cardPadding
                width: ytmPanel.artSize
                height: ytmPanel.cardHeight - 2 * ytmPanel.cardPadding
                spacing: 0
                opacity: ytmPanel.contentFade

                // Cover art. ClippingRectangle (not Rectangle + clip) so the image follows the rounded corners
                ClippingRectangle {
                    Layout.preferredWidth: ytmPanel.artSize
                    Layout.preferredHeight: ytmPanel.artSize
                    Layout.alignment: Qt.AlignHCenter
                    radius: ytmPanel.artRadius
                    color: ytmPanel.accentDark

                    Text {
                        anchors.centerIn: parent
                        visible: cover.status !== Image.Ready
                        text: ytmPanel.noArtIcon
                        color: ytmPanel.ink
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
                        color: ytmPanel.ink
                        font.pixelSize: ytmPanel.titleFontSize
                        font.family: root.fontFamily
                        font.bold: true
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.ytmArtist
                        color: ytmPanel.ink
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
                        fillColor: ytmPanel.ink
                        emptyColor: ytmPanel.inkWash

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
                            color: ytmPanel.ink
                            font.pixelSize: ytmPanel.timeFontSize
                            font.family: root.fontFamily
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: ytmPanel.formatTime(root.ytmDuration)
                            color: ytmPanel.ink
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
                        baseColor: ytmPanel.inkWash
                        iconColor: ytmPanel.ink
                        onClicked: root.ytmCommand("prev")
                    }
                    IconButton {
                        text: root.ytmPlaying ? "Pause" : "Play"
                        glyph: root.ytmPlaying ? ytmPanel.pauseIcon : ytmPanel.playIcon
                        size: 52
                        iconSize: 24
                        cornerRadius: 12
                        fontFamily: root.fontFamily
                        baseColor: ytmPanel.ink
                        iconColor: ytmPanel.accent
                        onClicked: {
                            root.ytmPlaying = !root.ytmPlaying     // flip right away, the poll confirms it
                            root.ytmCommand("toggle-play-state")
                        }
                    }
                    IconButton {
                        text: "Next"
                        glyph: ytmPanel.nextIcon
                        fontFamily: root.fontFamily
                        baseColor: ytmPanel.inkWash
                        iconColor: ytmPanel.ink
                        onClicked: root.ytmCommand("next")
                    }
                }
            }
        }

        // Copy of the pill on top of the growing card: fades out as the content fades in
        YtmPill {
            id: pillCopy
            root: ytmPanel.root
            screen: ytmPanel.screen
            x: ytmPanel.pillX - ytmPanel.windowScreenX
            y: ytmPanel.pillY
            enabled: false                          // clicks go to the panel, not to this copy
            opacity: 1 - ytmPanel.contentFade
            visible: opacity > 0
        }

        // ── Side card: below the bar, next to the player card, grows down with the morph ──
        Rectangle {
            id: sideCard
            x: ytmPanel.sideScreenX - ytmPanel.windowScreenX
            y: ytmPanel.sideTop
            width: ytmPanel.sideWidth
            height: ytmPanel.sideHeight * ytmPanel.morph
            visible: height > 0
            clip: true
            radius: ytmPanel.cardRadius
            color: ytmPanel.accent

            // Buttons spread evenly from top to bottom (fixed height so they do not move while animating)
            Column {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: ytmPanel.sidePadding
                height: ytmPanel.sideHeight - 2 * ytmPanel.sidePadding
                opacity: ytmPanel.contentFade   // fade with the player, not sliced off by the clip
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
                        baseColor: ytmPanel.inkWash
                        iconColor: ytmPanel.ink
                        activeColor: ytmPanel.active
                        onClicked: ytmPanel.sideAction(modelData.action)
                    }
                }
            }
        }
    }
}
