<#
BlockUserOnShare_Server.ps1

- Lädt ein ZIP (Repo) herunter und entpackt es nach $TargetDirectory (Server)
- Fügt eine NTFS-Deny-FullControl ACE für $User auf $TargetDirectory hinzu
- Entfernt ggf. vorhandene Share-Allow-Einträge für $User an Shares, deren Path == $TargetDirectory
- Annahme: Skript läuft auf dem Server, der die Freigabe hostet.

Usage:
  .\BlockUserOnShare_Server.ps1 -User "BETATRADE\alice" -TargetDirectory "D:\Shares\ProjectX" -RepoZipUrl "https://github.com/..." 

#>

param (
    [Parameter(Mandatory = $true)]
    [string]$User,  # z.B. BETATRADE\alice

    [Parameter(Mandatory = $true)]
    [string]$TargetDirectory,  # z.B. D:\Shares\ProjectX

    [Parameter(Mandatory = $true)]
    [string]$RepoZipUrl        # z.B. https://github.com/user/repo/archive/refs/heads/main.zip
)

function Write-Info($msg){ Write-Host "[*] $msg" -ForegroundColor Cyan }
function Write-Warn($msg){ Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Err($msg){ Write-Host "[X] $msg" -ForegroundColor Red }

# -------------------------
# Admin-Check
# -------------------------
function Test-IsAdmin {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($current)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Err "Bitte PowerShell **als Administrator** ausführen."
    exit 1
}

# -------------------------
# Benutzervalidierung (AD oder lokal)
# -------------------------
try {
    $sid = (New-Object System.Security.Principal.NTAccount($User)).Translate([System.Security.Principal.SecurityIdentifier])
    Write-Info "Benutzer existiert: $User (SID: $sid)"
} catch {
    Write-Err "FEHLER: Der Benutzer '$User' existiert nicht oder der Name ist falsch!"
    Write-Err "Skript wird abgebrochen."
    exit 2
}

# -------------------------
# Zielordner prüfen / erstellen
# -------------------------
if (!(Test-Path $TargetDirectory)) {
    Write-Info "Zielordner existiert nicht - wird erstellt: $TargetDirectory"
    try {
        New-Item -ItemType Directory -Path $TargetDirectory -Force | Out-Null
    } catch {
        Write-Err "FEHLER: Zielordner konnte nicht erstellt werden: $_"
        exit 3
    }
} else {
    Write-Info "Zielordner existiert: $TargetDirectory"
}

# -------------------------
# ZIP herunterladen und entpacken
# -------------------------
$tempZip = Join-Path -Path $env:TEMP -ChildPath ("repo_{0}.zip" -f ([guid]::NewGuid().ToString()))
try {
    Write-Info "Lade Repository herunter: $RepoZipUrl"
    Invoke-WebRequest -Uri $RepoZipUrl -OutFile $tempZip -UseBasicParsing -ErrorAction Stop
    Write-Info "Entpacke nach: $TargetDirectory"
    Expand-Archive -Path $tempZip -DestinationPath $TargetDirectory -Force -ErrorAction Stop
    Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
} catch {
    Write-Warn "Hinweis: Download/Entpacken schlug fehl oder war fehlerhaft: $_"
    if (Test-Path $tempZip) { Remove-Item $tempZip -Force -ErrorAction SilentlyContinue }
    Write-Warn "Fahre mit Berechtigungsänderungen fort."
}

# -------------------------
# NTFS: Deny ACE für den Benutzer setzen (FullControl)
# -------------------------
try {
    Write-Info "Hole bestehende NTFS-ACL für $TargetDirectory"
    $acl = Get-Acl -LiteralPath $TargetDirectory

    Write-Info "Erzeuge Deny-ACE für Benutzer $User (FullControl, vererbt)"
    $denyRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $User,
        "FullControl",
        [System.Security.AccessControl.InheritanceFlags]::ContainerInherit + [System.Security.AccessControl.InheritanceFlags]::ObjectInherit,
        [System.Security.AccessControl.PropagationFlags]::None,
        [System.Security.AccessControl.AccessControlType]::Deny
    )

    # Füge die Regel hinzu (SetAccessRule kann vorhandene Regeln updaten)
    $acl.AddAccessRule($denyRule)
    Set-Acl -LiteralPath $TargetDirectory -AclObject $acl

    Write-Info "NTFS-Deny für $User auf $TargetDirectory gesetzt."
} catch {
    Write-Err "FEHLER beim Setzen der NTFS-ACL: $_"
    # Nicht abbrechen — Share-Entzug trotzdem versuchen
}

# -------------------------
# SHARE: Entferne explizite Share-Allow-Einträge für $User
# -------------------------
try {
    # Hole alle SMB-Shares, die genau auf diesen Pfad zeigen
    $matchingShares = Get-SmbShare | Where-Object {
        # Normalize paths for comparison
        try {
            $sharePath = (Get-SmbShare -Name $_.Name).Path
            $sharePath.TrimEnd('\') -eq (Resolve-Path -LiteralPath $TargetDirectory).Path.TrimEnd('\')
        } catch {
            $false
        }
    }

    if ($matchingShares.Count -eq 0) {
        Write-Warn "Keine SMB-Share gefunden, die genau auf $TargetDirectory zeigt. Prüfe manuell."
    } else {
        foreach ($s in $matchingShares) {
            Write-Info "Gefundene Share: $($s.Name) -> $($s.Path)"
            # Hole Zugangseinträge
            $accessList = Get-SmbShareAccess -Name $s.Name -ErrorAction Stop

            # Suche explizite Allow-Einträge für den Benutzer (AccountName kann z.B. 'BETATRADE\User' sein)
            $userEntries = $accessList | Where-Object {
                $_.AccountName -ieq $User -and $_.AccessRight -ne 'None'
            }

            if ($userEntries.Count -gt 0) {
                foreach ($entry in $userEntries) {
                    Write-Info "Revoke Share-Access: Share='$($s.Name)', Account='$($entry.AccountName)', AccessRight='$($entry.AccessRight)'"
                    # Revoke (entfernt Allow für den Account)
                    Revoke-SmbShareAccess -Name $s.Name -AccountName $entry.AccountName -Force -ErrorAction Stop
                }
                Write-Info "Explizite Share-Allow-Einträge für $User wurden entfernt auf Share $($s.Name)."
            } else {
                Write-Info "Keine expliziten Share-Allow-Einträge für $User auf Share $($s.Name) gefunden."
            }

            # Optional: zur Sicherheit Share-Acl nachweisen
            Write-Info "Aktuelle Share-ACL für $($s.Name):"
            Get-SmbShareAccess -Name $s.Name | ForEach-Object { Write-Host "  - $($_.AccountName) : $($_.AccessRight)" }
        }
    }

} catch {
    Write-Err "FEHLER beim Bearbeiten von Share-Berechtigungen: $_"
}

Write-Info "Vorgang abgeschlossen. Hinweis: NTFS-Deny überschreibt Allow-Rechte; die Gruppe B behält ihre Einträge (sofern nicht geändert)."

# Ende Skript
