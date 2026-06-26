import QtQuick

Row {
    property var root
    property var screen
    spacing: 6
	
	
    YtmPill {
        root: parent.root
        screen: parent.screen
    }
    VolumePill {
        root: parent.root
        screen: parent.screen
    }
    BatteryPill { 
        root: parent.root; 
        screen: parent.screen 
    }
}
