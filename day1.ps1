<#
BlockUserOnShare_Server.ps1

- Lädt ein ZIP (Repo) herunter und entpackt es nach $Directory (Server)
- Fügt eine NTFS-Deny-FullControl ACE für $User auf $Directory hinzu
- Entfernt ggf. vorhandene Share-Allow-Einträge für $User an Shares, deren Path == $Directory
- Annahme: Skript läuft auf dem Server, der die Freigabe hostet.

Usage:
  .\BlockUserOnShare_Server.ps1 -User "d.klein" -Directory "C:\BetaTrade\IT\Security" -Repo "https://github.com/nmap/nmap/archive/refs/heads/master.zip" 

#>

param (
    [Parameter(Mandatory = $true)]
    [string]$User,

    [Parameter(Mandatory = $true)]
    [string]$SecurityGroup,

    [Parameter(Mandatory = $true)]
    [string]$Directory,

    [Parameter(Mandatory = $false)]
    [string]$Repo
)

###############################################################################
# 1. User prüfen
###############################################################################
try {
    $null = (New-Object System.Security.Principal.NTAccount($User)).Translate([System.Security.Principal.SecurityIdentifier])
    Write-Host "Benutzer existiert: $User"
}
catch {
    Write-Host "FEHLER: Der Benutzer '$User' existiert nicht!" -ForegroundColor Red
    exit 1
}

###############################################################################
# 2. Gruppe prüfen + User aus Gruppe werfen
###############################################################################
try {
    $groupObj = Get-ADGroup $SecurityGroup -ErrorAction Stop
}
catch {
    Write-Host "FEHLER: Die Sicherheitsgruppe '$SecurityGroup' existiert nicht!" -ForegroundColor Red
    exit 1
}

Write-Host "Prüfe, ob $User Mitglied der Gruppe $SecurityGroup ist..."

$member = Get-ADGroupMember $SecurityGroup -Recursive | Where-Object { $_.SamAccountName -eq $User }

if ($member) {
    Write-Host "Entferne $User aus der Gruppe $SecurityGroup..."
    try {
        Remove-ADGroupMember -Identity $SecurityGroup -Members $User -Confirm:$false
        Write-Host "Benutzer wurde aus der Gruppe entfernt."
    } catch {
        Write-Host "FEHLER: Konnte $User nicht aus $SecurityGroup entfernen!" -ForegroundColor Red
    }
} else {
    Write-Host "Benutzer war kein Mitglied der Gruppe – überspringe."
}

###############################################################################
# 3. Ordner erstellen falls nicht vorhanden
###############################################################################
if (!(Test-Path $Directory)) {
    Write-Host "Zielordner existiert nicht - wird erstellt: $Directory"
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
}

###############################################################################
# 4. Repo herunterladen
###############################################################################
if(![string]::IsNullOrWhiteSpace($Repo)) {
    $tempZip = "$env:TEMP\repo.zip"

    try {
        Write-Host "Lade Repository herunter..."
        Invoke-WebRequest -Uri $Repo -OutFile $tempZip
    } catch {
        Write-Host "FEHLER: Download der ZIP fehlgeschlagen!" -ForegroundColor Red
        exit 1
    }
}

###############################################################################
# 5. Repository entpacken
###############################################################################
try {
    Write-Host "Entpacke Repository nach $Directory ..."
    Expand-Archive -Path $tempZip -DestinationPath $Directory -Force
} catch {
    Write-Host "FEHLER: Entpacken fehlgeschlagen – fahre dennoch fort." -ForegroundColor Yellow
}

Remove-Item $tempZip -Force

###############################################################################
# 6. NTFS-Zugriff verweigern
###############################################################################
Write-Host "Setze NTFS-Zugriffsverweigerung für $User auf $Directory..."

$acl = Get-Acl $Directory

$inherit = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor `
           [System.Security.AccessControl.InheritanceFlags]::ObjectInherit

$propagate = [System.Security.AccessControl.PropagationFlags]::None

$denyRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $User,
    [System.Security.AccessControl.FileSystemRights]::FullControl,
    $inherit,
    $propagate,
    [System.Security.AccessControl.AccessControlType]::Deny
)

$acl.SetAccessRule($denyRule)
Set-Acl $Directory $acl

Write-Host "Zugriff NTFS-mäßig für $User auf $Directory verweigert!"
