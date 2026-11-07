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

Write-Host "Probing $NasHost ..." -ForegroundColor Cyan
foreach ($p in @(5000, 445, 22)) {
    $up = Test-Port -ComputerName $NasHost -Port $p
    Write-Host ("  port {0}: {1}" -f $p, ($(if ($up) { 'open' } else { 'closed/timeout' })))
}

if (-not (Test-Port -ComputerName $NasHost -Port 445)) {
    throw "SMB (445) is not reachable on $NasHost. Enable File Services > SMB in DSM, then retry."
}

if ($null -eq $Password) {
    if (-not [string]::IsNullOrWhiteSpace($env:SYNOLOGY_PASSWORD)) {
        $Password = ConvertTo-SecureString $env:SYNOLOGY_PASSWORD -AsPlainText -Force
    } else {
        $Password = Read-Host -AsSecureString -Prompt "Synology password for $User@$NasHost"
    }
}

$cred = New-Object System.Management.Automation.PSCredential ($User, $Password)
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
try {
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}

if ([string]::IsNullOrWhiteSpace($Share)) {
    Write-Host "Listing SMB shares on \\$NasHost ..." -ForegroundColor Cyan
    $view = & net view "\\$NasHost" 2>&1
    Write-Host ($view | Out-String)
    $candidates = @($view | ForEach-Object {
        if ($_ -match '^\s*(\S+)\s+Disk') { $Matches[1] }
    } | Where-Object { $_ -notin @('home', 'homes') -or $true })
    if ($candidates.Count -eq 0) {
        throw "No SMB shares found. Check DSM File Station / shared folder permissions for user '$User'."
    }
    $preferred = @('data', 'backup', 'homes', 'home', 'public')
    $Share = $preferred | Where-Object { $candidates -contains $_ } | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($Share)) { $Share = $candidates[0] }
    Write-Host "Selected share: $Share" -ForegroundColor Green
}

$unc = "\\$NasHost\$Share"
$drive = ($DriveLetter.TrimEnd(':') + ':')

$existing = Get-PSDrive -Name $DriveLetter.TrimEnd(':') -ErrorAction SilentlyContinue
if ($null -ne $existing) {
    Write-Host "Disconnecting existing $drive ..." -ForegroundColor Yellow
    & net use $drive /delete /y | Out-Null
}

Write-Host "Mapping $drive -> $unc (persistent) ..." -ForegroundColor Cyan
& net use $drive $unc /user:$User $plain /persistent:yes
if ($LASTEXITCODE -ne 0) {
    throw "net use failed with exit code $LASTEXITCODE"
}

Write-Host "Contents of $drive :" -ForegroundColor Green
Get-ChildItem -LiteralPath $drive | Select-Object -First 20 | Format-Table Name, Length, LastWriteTime

Write-Host "OK: $drive is mapped to $unc" -ForegroundColor Green
Write-Host "DSM UI: http://${NasHost}:5000/"
Write-Host "Tip: store credentials in Bitwarden item 'Synology' (do not commit passwords)."
