<#
prepare_lab.ps1

- Installiert Python 3.13 via winget (wenn nicht vorhanden).
- Lädt eine einzelne Datei von GitHub herunter (raw URL).
- Optional: überprüft SHA256 wenn --sha256 angegeben wird.
- Führt die Datei NICHT aus und richtet NICHTS im Autostart ein.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$GithubRawUrl,   
    [Parameter(Mandatory=$false)]
    [string]$DestFolder = "$env:USERPROFILE\Downloads\lab_files",
    [Parameter(Mandatory=$false)]
    [string]$FileName = "",   
    [Parameter(Mandatory=$false)]
    [string]$Sha256 = ""     
)

function Write-Info($msg){ Write-Host "[*] $msg" -ForegroundColor Cyan }
function Write-Warn($msg){ Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Err($msg){ Write-Host "[X] $msg" -ForegroundColor Red }

if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Warn "Du verwendest eine alte PowerShell-Version. Empfohlen: PowerShell 7+ oder Windows PowerShell 5.1."
}

# 1) Installiere Python 3.13 mit winget (best-effort)
try {
    Write-Info "Prüfe ob python installiert ist..."
    $python = Get-Command -Name python -ErrorAction SilentlyContinue
    if (-not $python) {
        Write-Info "Python nicht gefunden. Versuche Installation via winget (Python.Python.3.13)."
        # Hinweis: winget-Paketname kann je nach repo variieren; passe an falls notwendig.
        # /silent /accept-package-agreements sind nicht immer nötig; hier Best-Effort.
        $wingetExe = (Get-Command winget -ErrorAction SilentlyContinue).Source
        if (-not $wingetExe) {
            Write-Warn "winget nicht gefunden. Bitte winget installieren oder Python manuell bereitstellen."
        } else {
            Write-Info "starte: winget install --id Python.Python.3.13 -e --source winget"
            # Führt die Installation interaktiv aus; bei Bedarf als Admin starten.
            $installCmd = "winget install --id Python.Python.3.13 -e --source winget"
            $proc = Start-Process -FilePath "winget" -ArgumentList "install","--id","Python.Python.3.13","-e","--source","winget" -NoNewWindow -Wait -PassThru
            if ($proc.ExitCode -ne 0) {
                Write-Warn "winget-Installation hat mit ExitCode $($proc.ExitCode) geendet. Bitte manuell prüfen."
            } else {
                Write-Info "winget-Installation beendet (ExitCode 0)."
            }
        }
    } else {
        Write-Info "Python bereits vorhanden: $($python.Path)"
    }
} catch {
    Write-Warn "Fehler beim Versuch Python zu installieren: $_"
}

# 2) Zielordner erstellen
try {
    $dest = Join-Path -Path $DestFolder -ChildPath ""
    if (-not (Test-Path $dest)) {
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
        Write-Info "Erstellt Zielordner: $dest"
    } else {
        Write-Info "Zielordner existiert: $dest"
    }
} catch {
    Write-Err "Konnte Zielordner nicht erstellen: $_"
    exit 1
}

# 3) Dateinamen bestimmen
if ([string]::IsNullOrWhiteSpace($FileName)) {
    # Versuche letzten Pfadteil der URL zu verwenden
    try {
        $uri = [System.Uri]::new($GithubRawUrl)
        $FileName = [System.IO.Path]::GetFileName($uri.AbsolutePath)
        if ([string]::IsNullOrWhiteSpace($FileName)) {
            Write-Err "Konnte Dateinamen aus URL nicht bestimmen. Setze FileName-Parameter."
            exit 1
        }
    } catch {
        Write-Err "Ungültige URL: $_"
        exit 1
    }
}
$destPath = Join-Path $dest $FileName

# 4) Herunterladen (Invoke-WebRequest)
try {
    Write-Info "Lade Datei herunter: $GithubRawUrl"
    Invoke-WebRequest -Uri $GithubRawUrl -OutFile $destPath -UseBasicParsing -ErrorAction Stop
    Write-Info "Datei gespeichert nach: $destPath"
} catch {
    Write-Err "Fehler beim Herunterladen: $_"
    exit 1
}

# 5) Optional: SHA256 berechnen und vergleichen
if (-not [string]::IsNullOrWhiteSpace($Sha256)) {
    try {
        Write-Info "Berechne SHA256 für $destPath"
        $hasher = [System.Security.Cryptography.SHA256]::Create()
        $stream = [System.IO.File]::OpenRead($destPath)
        $hashBytes = $hasher.ComputeHash($stream)
        $stream.Close()
        $computed = ([System.BitConverter]::ToString($hashBytes)).Replace("-", "").ToLowerInvariant()
        $expected = $Sha256.Replace(" ", "").Replace("-","").ToLowerInvariant()
        Write-Info "Erwartet: $expected"
        Write-Info "Berechnet: $computed"
        if ($computed -ne $expected) {
            Write-Warn "SHA256 stimmt NICHT überein! Datei nicht ausführen. Prüfe Quelle."
        } else {
            Write-Info "SHA256 stimmt überein."
        }
    } catch {
        Write-Warn "Fehler bei SHA256-Prüfung: $_"
    }
} else {
    Write-Warn "Keine SHA256-Prüfsumme angegeben. Empfohlen: Prüfsumme überprüfen bevor Ausführung."
}

# 6) Hinweise für Lehrbetrieb (keine automatische Ausführung)
Write-Host ""
Write-Host "=== Wichtig: Datei wurde NICHT automatisch ausgeführt ===" -ForegroundColor Yellow
Write-Host "Datei befindet sich hier: $destPath"
Write-Host "Bitte: 1) Datei manuell inspizieren (z. B. Editor, Antivirus-Scan),"
Write-Host "       2) checkbox / Freigabe durch Lehrkraft, dann"
Write-Host "       3) manuell ausführen: python `"$destPath`""
Write-Host ""
Write-Host "Wenn du willst, kann ich dir die Befehle zeigen, um (a) die Datei manuell in den Startup-Ordner zu legen oder (b) wie Studenten die Datei sicher überprüfen und starten." -ForegroundColor Cyan
