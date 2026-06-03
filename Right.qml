import QtQuick

Row {
    property var root
    spacing: 6
	
	
    VolumePill { root: parent.root }
    BatteryPill { root: parent.root }
}
