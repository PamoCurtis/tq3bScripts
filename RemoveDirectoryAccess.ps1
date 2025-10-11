param (
    [Parameter(Mandatory = $true)]
    [string]$Directory
)

# Hole aktuellen Benutzer
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

# Hole die bestehenden ACLs
$acl = Get-Acl $Directory

# Erstelle neue Access Rule (Deny: FullControl für aktuellen Benutzer)
$denyRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $currentUser,
    "FullControl",
    "ContainerInherit,ObjectInherit",
    "None",
    "Deny"
)

# Füge die Regel hinzu
$acl.SetAccessRule($denyRule)

# Schreibe die neue ACL zurück
Set-Acl $Directory $acl

Write-Host "Zugriff für $currentUser auf $Directory wurde verweigert!"
