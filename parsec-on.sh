#!/bin/bash
# Enable Parsec remote access and the virtual display.
# Elevation is handled by the scheduled task, so no admin terminal needed.

TASK_NAME="ParsecEnable"

if schtasks.exe //Query //TN "$TASK_NAME" 2>/dev/null | grep -q "Running"; then
    echo "Parsec is already enabled."
    exit 1
fi

schtasks.exe //Run //TN "$TASK_NAME"
echo "Parsec enabled. Will auto-shutdown 5 minutes after disconnect."
