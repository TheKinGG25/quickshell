// TodoPanel.qml - the to-do list viewer, a centered card on the focused monitor.
//
// Opened only from the app launcher: the vicinae script command "To-do list"
// (~/.local/share/vicinae/scripts/todo.sh) runs `qs ipc call todo toggle`, which sets
// root.todoScreen (shell.qml). Escape or a click outside the card closes it.
//
// Reads ~/Documents/claude-notes/todo.md directly and reloads when it changes. Each row shows
// category, score and name; click one to expand its details. "Mark done" (click twice) runs
// scripts/todo-done.py, which removes the task's row and details from todo.md.
//
// Keys: Up / Down select, Enter or Space expands / collapses, D marks done (press twice),
// S or Tab changes the sort, Escape closes.

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "components"

PanelWindow {
    id: todoPanel
    property var root

    // ── Tweakables ──
    property string todoFile: root.homeDir + "/Documents/claude-notes/todo.md"
    property int cardWidth: 760
    property real maxHeightRatio: 0.7       // card height at most this much of the screen
    property int cardPadding: 24
    property int cardRadius: 16
    property int rowHeight: 46
    property int rowRadius: 8
    property int fontSize: 16
    property int categoryWidth: 110        // category column, text centered in it
    property int scoreWidth: 26
    property int columnGap: 14             // between category and score
    property int nameGap: 24               // between score and name
    property int confirmMs: 3000            // how long "Click again to confirm" waits
    property color backdrop: "#66000000"
    // Short labels for the section headings in todo.md (anything missing shows as written)
    property var categoryLabels: ({
        "Quickshell bar": "Quickshell",
        "Hyprland": "Hyprland",
        "Fastfetch": "Fastfetch",
        "Other apps": "Apps",
        "Personal": "Personal"
    })
    property var categoryColors: [root.colBlue, root.colMauve, root.colGreen, root.colPeach, root.colYellow, root.colRed]
    // Sort orders, cycled by the button in the header
    property var sorts: ["Score", "Category", "Effort"]

    // ── State ──
    property var tasks: []
    property var sections: []
    property int sortIndex: 0
    property int selected: 0                // highlighted row (arrow keys / mouse hover)
    property string expandedId: ""
    property string confirmId: ""
    property string errorText: ""

    property string screenName: ""          // this window's monitor, set once by shell.qml (reading `screen` here loops)
    readonly property bool open: !!root && screenName !== "" && root.todoScreen === screenName
    visible: open
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"

    onOpenChanged: if (!open) { expandedId = ""; confirmId = ""; errorText = ""; selected = 0 }

    // ── Reading todo.md ──
    FileView {
        id: todoView
        path: todoPanel.todoFile
        watchChanges: true
        onFileChanged: reload()
        onLoaded: todoPanel.parse(text())
    }

    function parse(md) {
        const out = [], details = {}, order = []
        let section = "", inDetails = false, cur = null
        for (const line of md.split("\n")) {
            let m = line.match(/^## (.+)$/)
            if (m) {
                section = m[1].trim()
                inDetails = section === "Details"
                if (!inDetails) order.push(section)
                cur = null
                continue
            }
            if (inDetails) {
                m = line.match(/^### (\S+) · /)
                if (m) { cur = m[1]; details[cur] = []; continue }
                if (cur) details[cur].push(line)
                continue
            }
            m = line.match(/^\|\s*([A-Za-z]+\d+)\s*\|\s*(\d+)\s*\|\s*([^|]*?)\s*\|\s*([^|]*?)\s*\|\s*(.*?)\s*\|\s*$/)
            if (m) out.push({ id: m[1], score: Number(m[2]), effort: m[3], type: m[4],
                              name: m[5].replace(/`/g, ""), section: section, sectionIndex: order.length - 1 })
        }
        for (const t of out) t.details = (details[t.id] || []).join("\n").trim()
        sections = order
        tasks = out
    }

    readonly property var sorted: {
        const effortRank = { "S": 0, "M": 1, "L": 2 }
        const list = tasks.slice()
        const bySort = sorts[sortIndex]
        list.sort((a, b) => {
            if (bySort === "Category" && a.sectionIndex !== b.sectionIndex) return a.sectionIndex - b.sectionIndex
            if (bySort === "Effort" && a.effort !== b.effort) return (effortRank[a.effort] ?? 9) - (effortRank[b.effort] ?? 9)
            if (a.score !== b.score) return b.score - a.score
            return a.sectionIndex - b.sectionIndex
        })
        return list
    }

    function label(section) { return categoryLabels[section] || section }
    function categoryColor(index) { return categoryColors[Math.max(0, index) % categoryColors.length] }
    function close() { root.todoScreen = "" }

    function select(i) {
        if (sorted.length === 0) return
        selected = Math.max(0, Math.min(sorted.length - 1, i))
        if (confirmId && confirmId !== sorted[selected].id) confirmId = ""
        list.positionViewAtIndex(selected, ListView.Contain)
    }
    function toggleExpanded(i) {
        const t = sorted[i]
        if (t) expandedId = expandedId === t.id ? "" : t.id
    }

    function markDone(id) {
        if (confirmId !== id) { confirmId = id; confirmTimer.restart(); return }
        confirmId = ""
        errorText = ""
        doneProcess.command = ["python3", root.scriptsDir + "/todo-done.py", id]
        doneProcess.running = true
    }

    Timer { id: confirmTimer; interval: todoPanel.confirmMs; onTriggered: todoPanel.confirmId = "" }

    Process {
        id: doneProcess
        stdout: SplitParser {
            onRead: (line) => { if (line.trim() !== "ok") todoPanel.errorText = line.trim() }
        }
    }

    // ── Backdrop: click outside the card to close ──
    Rectangle {
        anchors.fill: parent
        color: todoPanel.backdrop
        MouseArea { anchors.fill: parent; onClicked: todoPanel.close() }
    }

    Item {
        anchors.fill: parent
        focus: todoPanel.open
        Keys.onPressed: (event) => {
            const k = event.key
            if (k === Qt.Key_Escape) todoPanel.close()
            else if (k === Qt.Key_Down || k === Qt.Key_J) todoPanel.select(todoPanel.selected + 1)
            else if (k === Qt.Key_Up || k === Qt.Key_K) todoPanel.select(todoPanel.selected - 1)
            else if (k === Qt.Key_Home) todoPanel.select(0)
            else if (k === Qt.Key_End) todoPanel.select(todoPanel.sorted.length - 1)
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) todoPanel.toggleExpanded(todoPanel.selected)
            else if (k === Qt.Key_D && todoPanel.sorted[todoPanel.selected]) todoPanel.markDone(todoPanel.sorted[todoPanel.selected].id)
            else if (k === Qt.Key_S || k === Qt.Key_Tab) todoPanel.sortIndex = (todoPanel.sortIndex + 1) % todoPanel.sorts.length
            else return
            event.accepted = true
        }
    }

    PopupCard {
        id: card
        root: todoPanel.root
        anchors.centerIn: parent
        width: todoPanel.cardWidth
        height: Math.min(header.height + list.contentHeight + todoPanel.cardPadding * 3,
                         todoPanel.height * todoPanel.maxHeightRatio)
        radius: todoPanel.cardRadius

        MouseArea { anchors.fill: parent }  // clicks on the card do not reach the backdrop

        Item {
            id: header
            x: todoPanel.cardPadding
            y: todoPanel.cardPadding
            width: parent.width - 2 * todoPanel.cardPadding
            height: 32

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "To-do  " + todoPanel.tasks.length
                color: todoPanel.root.colText
                font { family: todoPanel.root.fontFamily; pixelSize: todoPanel.fontSize + 2; bold: true }
            }
            Text {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: (todoPanel.errorText ? todoPanel.errorText + "   " : "") + "\u{f04ba}  " + todoPanel.sorts[todoPanel.sortIndex]
                color: todoPanel.errorText ? todoPanel.root.colRed : sortArea.containsMouse ? todoPanel.root.colText : todoPanel.root.colSubtext
                font { family: todoPanel.root.fontFamily; pixelSize: todoPanel.fontSize }
                MouseArea {
                    id: sortArea
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: todoPanel.sortIndex = (todoPanel.sortIndex + 1) % todoPanel.sorts.length
                }
            }
        }

        ListView {
            id: list
            x: todoPanel.cardPadding
            y: header.y + header.height + todoPanel.cardPadding
            width: parent.width - 2 * todoPanel.cardPadding
            height: parent.height - y - todoPanel.cardPadding
            clip: true
            spacing: 2
            model: todoPanel.sorted
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool expanded: todoPanel.expandedId === modelData.id
                width: list.width
                height: todoPanel.rowHeight + (expanded ? detailsBox.height + 12 : 0)
                radius: todoPanel.rowRadius
                color: expanded || todoPanel.selected === index ? todoPanel.root.colSurface : "transparent"
                border.width: todoPanel.selected === index ? 1 : 0
                border.color: todoPanel.root.colOverlay

                MouseArea {
                    id: rowArea
                    width: parent.width
                    height: todoPanel.rowHeight
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: if (containsMouse) todoPanel.selected = row.index
                    onClicked: { todoPanel.selected = row.index; todoPanel.toggleExpanded(row.index) }
                }

                Row {
                    x: 10
                    height: todoPanel.rowHeight
                    spacing: 0

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: todoPanel.categoryWidth
                        horizontalAlignment: Text.AlignHCenter
                        text: todoPanel.label(row.modelData.section)
                        color: todoPanel.categoryColor(row.modelData.sectionIndex)
                        font { family: todoPanel.root.fontFamily; pixelSize: todoPanel.fontSize - 2 }
                        elide: Text.ElideRight
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: todoPanel.columnGap + todoPanel.scoreWidth
                        horizontalAlignment: Text.AlignRight
                        text: row.modelData.score
                        color: todoPanel.root.colSubtext
                        font { family: todoPanel.root.fontFamily; pixelSize: todoPanel.fontSize; bold: true }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        leftPadding: todoPanel.nameGap
                        width: list.width - todoPanel.categoryWidth - todoPanel.columnGap - todoPanel.scoreWidth - 20
                        text: row.modelData.name
                        color: todoPanel.root.colText
                        font { family: todoPanel.root.fontFamily; pixelSize: todoPanel.fontSize }
                        elide: Text.ElideRight
                    }
                }

                // Details + mark done, only while expanded
                Column {
                    id: detailsBox
                    visible: row.expanded
                    x: 10 + todoPanel.categoryWidth + todoPanel.columnGap + todoPanel.scoreWidth + todoPanel.nameGap
                    y: todoPanel.rowHeight
                    width: parent.width - x - 12
                    spacing: 10

                    Text {
                        width: parent.width
                        text: row.modelData.details || "_No details._"
                        textFormat: Text.MarkdownText
                        wrapMode: Text.Wrap
                        color: todoPanel.root.colSubtext
                        linkColor: todoPanel.root.colBlue
                        font { family: todoPanel.root.fontFamily; pixelSize: todoPanel.fontSize - 1 }
                    }
                    Text {
                        readonly property bool confirming: todoPanel.confirmId === row.modelData.id
                        text: confirming ? "\u{f012c}  Click again to confirm" : "\u{f012c}  Mark done"
                        color: confirming ? todoPanel.root.colGreen : doneArea.containsMouse ? todoPanel.root.colText : todoPanel.root.colOverlay
                        font { family: todoPanel.root.fontFamily; pixelSize: todoPanel.fontSize - 1 }
                        MouseArea {
                            id: doneArea
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: todoPanel.markDone(row.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
