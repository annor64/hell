param(
    [string]$NasHost = '192.168.88.245',
    [string]$User = 'admin',
    [string]$Share = '',
    [string]$DriveLetter = 'J',
    [SecureString]$Password
)

$ErrorActionPreference = 'Stop'

function Test-Port {
    param([string]$ComputerName, [int]$Port, [int]$TimeoutMs = 3000)
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $iar = $client.BeginConnect($ComputerName, $Port, $null, $null)
        $ok = $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if (-not $ok) { $client.Close(); return $false }
        $client.EndConnect($iar) | Out-Null
        $client.Close()
        return $true
    } catch {
        return $false
    }
}

function Get-PlainPassword {
    param([SecureString]$Secure)
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

Write-Host "Probing $NasHost ..." -ForegroundColor Cyan
foreach ($p in @(5000, 445, 22)) {
    $up = Test-Port -ComputerName $NasHost -Port $p
    Write-Host ("  port {0}: {1}" -f $p, ($(if ($up) { 'open' } else { 'closed/timeout' })))
}

if (-not (Test-Port -ComputerName $NasHost -Port 445)) {
    throw @"
SMB (445) is not reachable on $NasHost.

In DSM (http://${NasHost}:5000/):
  Control Panel > File Services > SMB > Enable SMB service
Then retry.
"@
}

if ($null -eq $Password) {
    if (-not [string]::IsNullOrWhiteSpace($env:SYNOLOGY_PASSWORD)) {
        $Password = ConvertTo-SecureString $env:SYNOLOGY_PASSWORD -AsPlainText -Force
    } else {
        $Password = Read-Host -AsSecureString -Prompt "Synology password for $User@$NasHost"
    }
}

$plain = Get-PlainPassword -Secure $Password

# Authenticate session first (fixes net view error 5 on many Synology setups).
Write-Host "Authenticating IPC`$ session ..." -ForegroundColor Cyan
& net use "\\$NasHost\IPC$" /delete /y 2>$null | Out-Null
$ipc = & net use "\\$NasHost\IPC$" /user:$User $plain 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host ($ipc | Out-String) -ForegroundColor Red
    throw @"
Could not authenticate to \\$NasHost\IPC$ (often DSM blocks admin SMB, or SMB is off).

Check in DSM:
  1) Control Panel > File Services > SMB = ON
  2) Control Panel > Shared Folder — create e.g. 'data' and give $User read/write
  3) Prefer a normal user over 'admin' for file sharing (DSM 7 often restricts admin)
  4) Via SSH: synoshare --enum ALL
"@
}

Write-Host "Listing SMB shares on \\$NasHost ..." -ForegroundColor Cyan
$view = & net view "\\$NasHost" 2>&1
Write-Host ($view | Out-String)

$candidates = @(
    $view | ForEach-Object {
        if ($_ -match '^\s*(\S+)\s+Disk') { $Matches[1] }
    }
)

if ([string]::IsNullOrWhiteSpace($Share)) {
    if ($candidates.Count -eq 0) {
        throw @"
No SMB Disk shares found.

Error 67 / empty list usually means:
  - shared folder not created yet, or
  - 'homes' not enabled (Control Panel > User & Group > Advanced > Enable user home service)

Create a shared folder in DSM (e.g. data), then rerun with -Share data
"@
    }
    $preferred = @('data', 'backup', 'documents', 'media', 'homes', 'home', 'public')
    $Share = $preferred | Where-Object { $candidates -contains $_ } | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($Share)) { $Share = [string]$candidates[0] }
    Write-Host "Selected share: $Share" -ForegroundColor Green
} elseif ($candidates.Count -gt 0 -and ($candidates -notcontains $Share)) {
    Write-Host "Warning: share '$Share' not in net view list: $($candidates -join ', ')" -ForegroundColor Yellow
}

$unc = "\\$NasHost\$Share"
$drive = ($DriveLetter.TrimEnd(':') + ':')

$existing = Get-PSDrive -Name $DriveLetter.TrimEnd(':') -ErrorAction SilentlyContinue
if ($null -ne $existing) {
    Write-Host "Disconnecting existing $drive ..." -ForegroundColor Yellow
    & net use $drive /delete /y | Out-Null
}

Write-Host "Mapping $drive -> $unc (persistent) ..." -ForegroundColor Cyan
$mapOut = & net use $drive $unc /user:$User $plain /persistent:yes 2>&1
Write-Host ($mapOut | Out-String)
if ($LASTEXITCODE -ne 0) {
    throw "net use failed with exit code $LASTEXITCODE for $unc"
}

Write-Host "Contents of $drive :" -ForegroundColor Green
Get-ChildItem -LiteralPath $drive | Select-Object -First 20 | Format-Table Name, Length, LastWriteTime

Write-Host "OK: $drive is mapped to $unc" -ForegroundColor Green
Write-Host "DSM UI: http://${NasHost}:5000/"
