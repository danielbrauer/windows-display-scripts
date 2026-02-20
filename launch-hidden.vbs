' Launch a PowerShell script with no visible window.
' Usage: wscript.exe launch-hidden.vbs <script.ps1>
Set shell = CreateObject("WScript.Shell")
scriptPath = WScript.Arguments(0)
shell.Run "powershell.exe -ExecutionPolicy Bypass -File """ & scriptPath & """", 0, False
