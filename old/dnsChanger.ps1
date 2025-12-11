<#
dnsChanger.ps1

Setzt den IPv4-DNS-Server eines Netzwerkadapters auf das DNS Adresspaar (1.1.1.1, 8.8.8.8).

Usage:
  .\dnsChanger.ps1 [-Adapter "AdapterName"]

Wenn kein Adapter angegeben wird, wird der Benutzer interaktiv zur Auswahl aufgefordert.

Hinweis:
  Das Skript muss mit Administratorrechten ausgeführt werden.
#>

param(
    [string] $Adapter
)

function Write-Info($msg){ Write-Host "[*] $msg" -ForegroundColor Cyan }
function Write-Warn($msg){ Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Err($msg){ Write-Host "[X] $msg" -ForegroundColor Red }

# Prüfe, ob Administrator
function Test-IsAdmin {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($current)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Err "Bitte PowerShell **als Administrator** ausführen."
    exit 1
}

# Liste aller Adapter mit IPv4-DNS-Servern
function Get-Adapters {
    $ps = "Get-DnsClientServerAddress -AddressFamily IPv4 | Select-Object InterfaceAlias,ServerAddresses | ConvertTo-Json -Compress"
    $out = powershell -NoProfile -NonInteractive -Command $ps
    $data = ConvertFrom-Json $out
    if ($data -isnot [System.Array]) {
        $data = @($data)
    }
    return $data
}

# Wähle Adapter interaktiv
function Choose-Adapter {
    $adapters = Get-Adapters
    Write-Info "Gefundene Netzwerkadapter (IPv4-DNS):"
    for ($i = 0; $i -lt $adapters.Count; $i++) {
        $alias = $adapters[$i].InterfaceAlias
        $servers = $adapters[$i].ServerAddresses -join ", "
        Write-Host "  [$($i+1)] $alias  → DNS: $servers"
    }
    $choice = Read-Host "Gib die Nummer des Adapters ein (oder Enter für 1)"
    if ([string]::IsNullOrWhiteSpace($choice)) {
        $idx = 0
    } else {
        if (-not ([int]::TryParse($choice, [ref]$null))) {
            Write-Err "Ungültige Eingabe."
            exit 2
        }
        $idx = [int]$choice - 1
        if ($idx -lt 0 -or $idx -ge $adapters.Count) {
            Write-Err "Nummer außerhalb Bereich."
            exit 2
        }
    }
    return $adapters[$idx].InterfaceAlias
}

if ([string]::IsNullOrWhiteSpace($Adapter)) {
    $Adapter = Choose-Adapter
}

Write-Info "Adapter ausgewählt: $Adapter"
$dnsAddresses = @("1.1.1.1","8.8.8.8")
$serversLiteral = $dnsAddresses -join '","'
$serversLiteral = "@(""$serversLiteral"")"

$psCmd = "Set-DnsClientServerAddress -InterfaceAlias `"$Adapter`" -ServerAddresses $serversLiteral -AddressFamily IPv4"
Write-Info "Führe aus: $psCmd"

try {
    powershell -NoProfile -NonInteractive -Command $psCmd
    Write-Info "DNS-Server für Adapter '$Adapter' gesetzt auf: $($cloudflare -join ', ')"
} catch {
    Write-Err "Fehler beim Setzen des DNS-Servers: $_"
    exit 3
}

Write-Info "Fertig."
