#!/bin/bash
# Immediately disable Parsec remote access and the virtual display.
# Elevation is handled by the scheduled task, so no admin terminal needed.

schtasks.exe //Run //TN "ParsecDisable"
echo "Parsec disabled."
