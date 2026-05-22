#!/bin/bash
APP="/Applications/Scavodio.app"

if [ ! -d "$APP" ]; then
    osascript -e 'display alert "Scavodio not found" message "Drag Scavodio to the Applications folder first, then run this." as warning'
    exit 1
fi

xattr -cr "$APP"
open "$APP"
