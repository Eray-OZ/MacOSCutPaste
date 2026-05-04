#!/bin/bash
ICON_SOURCE="/Users/erayoz/Codes/macos.cut/MacCutPaste/Icon.png"
DEST_DIR="/Users/erayoz/Codes/macos.cut/MacCutPaste/MacCutPaste/Assets.xcassets/AppIcon.appiconset"

# Function to resize
resize_icon() {
    local size=$1
    local name=$2
    sips -z $size $size "$ICON_SOURCE" --out "$DEST_DIR/$name"
}

resize_icon 16 "appicon-16.png"
resize_icon 32 "appicon-32.png"
resize_icon 64 "appicon-64.png"
resize_icon 128 "appicon-128.png"
resize_icon 256 "appicon-256.png"
resize_icon 512 "appicon-512.png"
resize_icon 1024 "appicon-1024.png"

echo "Icons generated successfully in $DEST_DIR"
