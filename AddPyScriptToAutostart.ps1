function Get-UserStartupFolder {
    $appdata = $env:APPDATA
    Join-Path $appdata "Microsoft\Windows\Start Menu\Programs\Startup"
}

function Add-StartupShortcut {
    param(
        [Parameter(Mandatory=$true)] [string] $TargetExe,    # z.B. C:\Windows\py.exe oder C:\Python39\python.exe
        [Parameter(Mandatory=$true)] [string] $ScriptPath,   # z.B. C:\Tools\meinskript.py
        [string] $Name = "TestPyAutostart"                     # Name der .lnk (ohne Endung)
    )

    $startup = Get-UserStartupFolder
    if (-not (Test-Path $startup)) { New-Item -ItemType Directory -Path $startup -Force | Out-Null }

    $WshShell = New-Object -ComObject WScript.Shell
    $shortcut = $WshShell.CreateShortcut((Join-Path $startup ("$Name.lnk")))
    $shortcut.TargetPath = $TargetExe
    $shortcut.Arguments = "`"$ScriptPath`""   # Script als Argument (in Anführungszeichen)
    $shortcut.WorkingDirectory = (Split-Path $ScriptPath -Parent)
    $shortcut.Save()
    Write-Host "Shortcut erstellt: $(Join-Path $startup ($Name + '.lnk'))"
}

# Beispiel:
# Add-StartupShortcut -TargetExe "C:\Python310\python.exe" -ScriptPath "C:\Test\sim_miner.py" -Name "SimMinerStarter"
