param(
    [string] $Adapter
)

function Write-Info($msg){ Write-Host "[*] $msg" -ForegroundColor Cyan }
function Write-Warn($msg){ Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Err($msg){ Write-Host "[X] $msg" -ForegroundColor Red }

# -----------------------------
# Admin-Check
# -----------------------------
function Test-IsAdmin {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($current)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Err "Bitte PowerShell **als Administrator** ausführen."
    exit 1
}

# -----------------------------
# Adapter auslesen
# -----------------------------
function Get-Adapters {
    Get-DnsClientServerAddress -AddressFamily IPv4 |
        Select-Object InterfaceAlias, ServerAddresses
}

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
        return $adapters[0].InterfaceAlias
    }

    $idx = [int]$choice - 1
    if ($idx -lt 0 -or $idx -ge $adapters.Count) {
        Write-Err "Ungültige Auswahl."
        exit 2
    }

    return $adapters[$idx].InterfaceAlias
}

if ([string]::IsNullOrWhiteSpace($Adapter)) {
    $Adapter = Choose-Adapter
}

Write-Info "Adapter ausgewählt: $Adapter"

# -----------------------------
# Aktuelle DNS-Adressen ziehen
# -----------------------------
$dnsInfo = Get-DnsClientServerAddress -InterfaceAlias $Adapter -AddressFamily IPv4
$currentDNS = $dnsInfo.ServerAddresses

if (-not $currentDNS -or $currentDNS.Count -eq 0) {
    Write-Err "Keine DNS-Adressen gefunden."
    exit 3
}

Write-Info "Aktuelle DNS-Adressen:"
$currentDNS | ForEach-Object { Write-Host "  - $_" }

# -----------------------------
# Zahlendreher-Funktion
# Vertauscht die ersten beiden Ziffern der letzten Oktette
# Beispiel: 8.8.8.8 → 8.8.8.8 (keine Änderung möglich)
# Beispiel: 192.168.1.10 → 192.186.1.10
# -----------------------------
function Add-ZahlendreherToIP($ip) {
    $parts = $ip.Split('.')
    if ($parts.Count -ne 4) { return $ip }

    $second = $parts[1]

    # Oktett muss mindestens 2 Stellen haben
    if ($second.Length -lt 2) {
        return $ip
    }

    $chars = $second.ToCharArray()

    # Letzte zwei Ziffern tauschen
    $lastIndex = $chars.Length - 1
    $tmp = $chars[$lastIndex]
    $chars[$lastIndex] = $chars[$lastIndex - 1]
    $chars[$lastIndex - 1] = $tmp

    # Zurücksetzen ins zweite Oktett
    $parts[1] = -join $chars

    return ($parts -join '.')
}

# -----------------------------
# DNS manipulieren
# -----------------------------
$newDNS = @()

foreach ($dns in $currentDNS) {
    $manipulated = Add-ZahlendreherToIP $dns
    Write-Warn "Manipuliert: $dns  zu  $manipulated"
    $newDNS += $manipulated
}

# -----------------------------
# Neue DNS setzen
# -----------------------------
try {
    Set-DnsClientServerAddress `
        -InterfaceAlias $Adapter `
        -ServerAddresses $newDNS[0] `
        -AddressFamily IPv4

    Write-Info "Neue (manipulierte) DNS-Adressen gesetzt:"
    $newDNS | ForEach-Object { Write-Host "  - $_" }

} catch {
    Write-Err "Fehler beim Setzen der DNS-Server: $_"
    exit 4
}

Write-Info "DNS-Manipulation abgeschlossen."


# -----------------------------
# FIREWALL-REGEL: DNS SPERREN (UDP + TCP 53)
# -----------------------------
Write-Warn "Erstelle Firewall-Regel, die ausgehende DNS-Anfragen blockiert..."

try {
    # UDP 53 blockieren
    New-NetFirewallRule `
        -DisplayName "BLOCK_DNS_UDP_53" `
        -Direction Outbound `
        -Protocol UDP `
        -RemotePort 53 `
        -Action Block `
        -Profile Any | Out-Null

    # TCP 53 blockieren (Backup-Fall für DNS over TCP)
    New-NetFirewallRule `
        -DisplayName "BLOCK_DNS_TCP_53" `
        -Direction Outbound `
        -Protocol TCP `
        -RemotePort 53 `
        -Action Block `
        -Profile Any | Out-Null

    Write-Info "Firewall-Regeln erfolgreich erstellt:"
    Write-Host "  - BLOCK_DNS_UDP_53"
    Write-Host "  - BLOCK_DNS_TCP_53"

} catch {
    Write-Err "Fehler beim Erstellen der Firewall-Regel: $_"
    exit 5
}

Write-Warn "DNS ist nun doppelt sabotiert: falsche Server + Firewall-Blockade."
