$ErrorActionPreference='Stop'
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback={ $true }

$base='https://192.168.0.135:8006/api2/json'
$user='root@pam'
$pass='artanox2912'

$loginRaw = curl.exe -k -s -X POST --data-urlencode "username=$user" --data-urlencode "password=$pass" "$base/access/ticket"
$auth = $loginRaw | ConvertFrom-Json
$ticket = $auth.data.ticket
$csrfToken = $auth.data.CSRFPreventionToken
$cookieHeader = "Cookie: PVEAuthCookie=$ticket"
$csrfHeader = "CSRFPreventionToken: $csrfToken"

$statusRaw = curl.exe -k -s -H $cookieHeader "$base/nodes/hell/lxc/105/status/current"
$status = $statusRaw | ConvertFrom-Json
if($status.data.status -ne 'running'){
  curl.exe -k -s -X POST -H $cookieHeader -H $csrfHeader "$base/nodes/hell/lxc/105/status/start" | Out-Null
  Start-Sleep -Seconds 2
  $statusRaw = curl.exe -k -s -H $cookieHeader "$base/nodes/hell/lxc/105/status/current"
  $status = $statusRaw | ConvertFrom-Json
}

$cfgRaw = curl.exe -k -s -H $cookieHeader "$base/nodes/hell/lxc/105/config"
$cfg = $cfgRaw | ConvertFrom-Json

[pscustomobject]@{
  status   = $status.data.status
  hostname = $cfg.data.hostname
  cores    = $cfg.data.cores
  memoryMB = $cfg.data.memory
  net0     = $cfg.data.net0
  features = $cfg.data.features
} | ConvertTo-Json -Depth 5
