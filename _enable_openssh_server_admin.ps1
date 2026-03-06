$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'

function Step {
    param([string]$Message)
    Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message) -ForegroundColor Cyan
}

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if(-not $isAdmin) {
    Step 'Není admin shell, vyvolávám UAC...'
    $scriptPath = $MyInvocation.MyCommand.Path
    $argList = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', ('"{0}"' -f $scriptPath)
    ) -join ' '

    Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs
    Write-Output 'Bylo vyvoláno UAC okno. Potvrď spuštění jako správce.'
    exit 0
}

Step 'Běžím jako správce.'

Step 'Zjišťuji OpenSSH.Server capability...'
$cap = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*' | Select-Object -First 1
if($null -eq $cap) {
    throw 'OpenSSH.Server capability nebyla nalezena v systému.'
}

Step ("OpenSSH.Server state: {0}" -f $cap.State)

if($cap.State -ne 'Installed') {
    Step 'Instaluji OpenSSH.Server (tohle může trvat několik minut)...'
    Add-WindowsCapability -Online -Name $cap.Name
    Step 'Instalace capability dokončena.'
}

Step 'Kontroluji existenci služby sshd...'
if(-not (Get-Service -Name sshd -ErrorAction SilentlyContinue)) {
    throw 'Služba sshd stále neexistuje po instalaci capability.'
}

Step 'Nastavuji službu sshd na Automatic...'
Set-Service -Name sshd -StartupType Automatic
if((Get-Service -Name sshd).Status -ne 'Running') {
    Step 'Spouštím službu sshd...'
    Start-Service -Name sshd
}

Step 'Kontroluji firewall pravidlo OpenSSH-Server-In-TCP...'
if(-not (Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
}

Step 'Testuji ssh localhost...'
$sshTest = & ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 localhost "echo SSH_LOCAL_OK" 2>&1

$result = [ordered]@{
    capability = (Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*' | Select-Object -First 1).State
    sshdStatus = (Get-Service -Name sshd).Status
    sshdStartup = (Get-Service -Name sshd).StartType
    firewallRule = [bool](Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue)
    sshLocalhostTest = ($sshTest -join "`n")
}

Step 'Hotovo. Výsledek:'
$result | ConvertTo-Json -Depth 4
