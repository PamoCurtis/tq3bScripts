param (
    [Parameter(Mandatory = $true)]
    [string]$User,

    [Parameter(Mandatory = $true)]
    [string]$TargetDirectory,  # z.B. C:\TestRepo

    [Parameter(Mandatory = $true)]
    [string]$RepoZipUrl        # z.B. https://github.com/user/repo/archive/refs/heads/main.zip

)

try {
    $null = (New-Object System.Security.Principal.NTAccount($User)).Translate([System.Security.Principal.SecurityIdentifier])
    Write-Host "Benutzer existiert: $User"
}
catch {
    Write-Host "FEHLER: Der Benutzer '$User' existiert nicht!" -ForegroundColor Red
    Write-Host "Skript wird abgebrochen."
    exit 1
}

if (!(Test-Path $TargetDirectory)) {
    Write-Host "Zielordner existiert nicht - wird erstellt: $TargetDirectory "
    New-Item -ItemType Directory -Path $TargetDirectory -Force | Out-Null
}

$tempZip = "$env:TEMP\repo.zip"

try {
    Write-Host "Lade Repository herunter..."
    Invoke-WebRequest -Uri $RepoZipUrl -OutFile $tempZip
} catch {
    Write-Host "FEHLER: Download der Zip Fehlgeschlagen" -ForegroundColor Red
    exit 1
}

try {
    Write-Host "Entpacke Repository nach $TargetDirectory ..."
    Expand-Archive -Path $tempZip -DestinationPath $TargetDirectory -Force
} catch {
    Write-Host "FEHLER: Entpacken der Zip Datei Fehlgeschlagen... Fahre dennoch fort" -ForegroundColor Red
}

Remove-Item $tempZip -Force

Write-Host "Setze Zugriffsrechte für Benutzer: $User"

$acl = Get-Acl $TargetDirectory

$denyRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $User,
    "FullControl",
    "ContainerInherit,ObjectInherit",
    "None",
    "Deny"
)

$acl.SetAccessRule($denyRule)
Set-Acl $TargetDirectory $acl

Write-Host "Zugriff für $User auf $TargetDirectory wurde verweigert!"
