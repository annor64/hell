$ErrorActionPreference = 'Stop'
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

$base = 'https://192.168.0.135:9443'
$endpointId = 3
$username = 'annor'
$password = 'artanox2912@'

$targets = @(
    [ordered]@{ Name = 'homeassistant'; StackFile = 'C:\Users\jkika\SQL\gitops\stacks\homeassistant\compose.yml' },
    [ordered]@{ Name = 'smart-workspace'; StackFile = 'C:\Users\jkika\SQL\gitops\stacks\smart-workspace\compose.yml' }
)

$authBody = @{ username = $username; password = $password } | ConvertTo-Json
$auth = Invoke-RestMethod -Method Post -Uri "$base/api/auth" -ContentType 'application/json' -Body $authBody -TimeoutSec 30
$headers = @{ Authorization = "Bearer $($auth.jwt)" }

$results = @()
foreach($target in $targets) {
    $name = [string]$target.Name
    $stackFile = [string]$target.StackFile

    if(-not (Test-Path -Path $stackFile)) {
        $results += [ordered]@{ stack = $name; ok = $false; action = ''; error = "Missing stack file: $stackFile" }
        continue
    }

    $content = Get-Content -Path $stackFile -Raw -Encoding UTF8
    $stacks = Invoke-RestMethod -Method Get -Uri "$base/api/stacks" -Headers $headers -TimeoutSec 30
    $existing = @($stacks | Where-Object { $_.Name -eq $name } | Select-Object -First 1)

    try {
        if($existing.Count -gt 0) {
            $stackId = [int]$existing[0].Id
            $updateBody = @{
                StackFileContent = $content
                Env = @()
                Prune = $true
                PullImage = $true
            } | ConvertTo-Json -Depth 10

            Invoke-RestMethod -Method Put -Uri "$base/api/stacks/$stackId?endpointId=$endpointId" -Headers $headers -ContentType 'application/json' -Body $updateBody -TimeoutSec 60 | Out-Null
            $results += [ordered]@{ stack = $name; ok = $true; action = 'updated'; stackId = $stackId; error = '' }
        }
        else {
            $createBody = @{
                Name = $name
                StackFileContent = $content
                Env = @()
                FromAppTemplate = $false
            } | ConvertTo-Json -Depth 10

            $created = Invoke-RestMethod -Method Post -Uri "$base/api/stacks/create/standalone/string?endpointId=$endpointId" -Headers $headers -ContentType 'application/json' -Body $createBody -TimeoutSec 60
            $results += [ordered]@{ stack = $name; ok = $true; action = 'created'; stackId = [int]$created.Id; error = '' }
        }
    }
    catch {
        $results += [ordered]@{ stack = $name; ok = $false; action = ''; error = [string]$_.Exception.Message }
    }
}

Start-Sleep -Seconds 5
$containers = Invoke-RestMethod -Method Get -Uri "$base/api/endpoints/$endpointId/docker/containers/json?all=1" -Headers $headers -TimeoutSec 30

$summary = [ordered]@{
    timestamp = (Get-Date).ToString('s')
    deploy = $results
    homeassistant = @(
        $containers |
            Where-Object { $_.Labels.'com.docker.compose.project' -eq 'homeassistant' } |
            ForEach-Object {
                [ordered]@{
                    name = [string](($_.Names | Select-Object -First 1) -replace '^/', '')
                    state = [string]$_.State
                    status = [string]$_.Status
                    image = [string]$_.Image
                }
            }
    )
    smartWorkspace = @(
        $containers |
            Where-Object { $_.Labels.'com.docker.compose.project' -eq 'smart-workspace' } |
            ForEach-Object {
                [ordered]@{
                    name = [string](($_.Names | Select-Object -First 1) -replace '^/', '')
                    state = [string]$_.State
                    status = [string]$_.Status
                    image = [string]$_.Image
                }
            }
    )
}

$outFile = 'C:\Users\jkika\SQL\_redeploy_result_now.json'
$summary | ConvertTo-Json -Depth 8 | Set-Content -Path $outFile -Encoding UTF8
$summary | ConvertTo-Json -Depth 8
