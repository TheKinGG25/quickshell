// Right.qml - the row of pills on the right of the bar.
// Reorder or remove pills here; each pill is its own file.

import QtQuick

Row {
    property var root
    property var screen
    spacing: 6      // gap between pills

    YtmPill {       // music (hidden when nothing is playing)
        root: parent.root
        screen: parent.screen
    }
    VolumePill {    // volume / bluetooth
        root: parent.root
        screen: parent.screen
    }
    BatteryPill {   // battery / power profile
        root: parent.root
        screen: parent.screen
    }
}
