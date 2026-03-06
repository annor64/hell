$ErrorActionPreference = 'Stop'
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

$base = 'https://192.168.0.135:9443'
$endpointId = 3
$username = 'annor'
$password = 'artanox2912@'
$outFile = 'C:\Users\jkika\SQL\_hard_redeploy_result.json'

function Invoke-RestMethodWithHardTimeout {
    param(
        [string]$Method,
        [string]$Uri,
        [hashtable]$Headers,
        [string]$ContentType,
        [string]$Body,
        [int]$TimeoutSec,
        [string]$Label
    )

    $job = Start-Job -ScriptBlock {
        param($Method, $Uri, $Headers, $ContentType, $Body)
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

        if([string]::IsNullOrWhiteSpace($Body)) {
            Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers -TimeoutSec 30
        }
        else {
            Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers -ContentType $ContentType -Body $Body -TimeoutSec 30
        }
    } -ArgumentList $Method, $Uri, $Headers, $ContentType, $Body

    try {
        $completed = Wait-Job -Job $job -Timeout $TimeoutSec
        if($null -eq $completed) {
            Stop-Job -Job $job -Force | Out-Null
            throw "Timeout while waiting for $Label (${TimeoutSec}s)."
        }

        $jobError = $job.ChildJobs | ForEach-Object { $_.JobStateInfo.Reason } | Where-Object { $null -ne $_ } | Select-Object -First 1
        if($null -ne $jobError) {
            throw [string]$jobError
        }

        return Receive-Job -Job $job -ErrorAction Stop
    }
    finally {
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
}

$targets = @(
    [ordered]@{ Name = 'homeassistant'; StackFile = 'C:\Users\jkika\SQL\gitops\stacks\homeassistant\compose.yml' },
    [ordered]@{ Name = 'smart-workspace'; StackFile = 'C:\Users\jkika\SQL\gitops\stacks\smart-workspace\compose.yml' }
)

$result = [ordered]@{
    timestamp = (Get-Date).ToString('s')
    ok = $true
    steps = @()
    errors = @()
    stacks = @()
}

try {
    $authBody = @{ username = $username; password = $password } | ConvertTo-Json
    $auth = Invoke-RestMethodWithHardTimeout -Method 'Post' -Uri "$base/api/auth" -Headers @{} -ContentType 'application/json' -Body $authBody -TimeoutSec 45 -Label 'auth'
    $headers = @{ Authorization = "Bearer $($auth.jwt)" }

    foreach($target in $targets) {
        $name = [string]$target.Name
        $stackFile = [string]$target.StackFile

        if(-not (Test-Path -Path $stackFile)) {
            $result.ok = $false
            $result.errors += "Missing stack file: $stackFile"
            continue
        }

        $content = Get-Content -Path $stackFile -Raw -Encoding UTF8

        $stacksNow = Invoke-RestMethodWithHardTimeout -Method 'Get' -Uri "$base/api/stacks" -Headers $headers -ContentType '' -Body '' -TimeoutSec 45 -Label "list stacks $name"
        $existing = @($stacksNow | Where-Object { $_.Name -eq $name } | Select-Object -First 1)

        if($existing.Count -gt 0) {
            $sid = [int]$existing[0].Id
            try {
                Invoke-RestMethodWithHardTimeout -Method 'Delete' -Uri "$base/api/stacks/$sid?endpointId=$endpointId" -Headers $headers -ContentType '' -Body '' -TimeoutSec 60 -Label "delete stack $name" | Out-Null
                $result.steps += "Deleted stack $name (id=$sid)"
            }
            catch {
                $result.ok = $false
                $result.errors += "Delete failed for $name: $($_.Exception.Message)"
                continue
            }
        }

        $createBody = @{
            Name = $name
            StackFileContent = $content
            Env = @()
            FromAppTemplate = $false
        } | ConvertTo-Json -Depth 10

        try {
            $created = Invoke-RestMethodWithHardTimeout -Method 'Post' -Uri "$base/api/stacks/create/standalone/string?endpointId=$endpointId" -Headers $headers -ContentType 'application/json' -Body $createBody -TimeoutSec 60 -Label "create stack $name"
            $result.steps += "Created stack $name (id=$($created.Id))"
            $result.stacks += [ordered]@{ name = $name; stackId = [int]$created.Id; action = 'created' }
        }
        catch {
            $result.ok = $false
            $result.errors += "Create failed for $name: $($_.Exception.Message)"
        }
    }

    Start-Sleep -Seconds 8
    $containers = Invoke-RestMethodWithHardTimeout -Method 'Get' -Uri "$base/api/endpoints/$endpointId/docker/containers/json?all=1" -Headers $headers -ContentType '' -Body '' -TimeoutSec 45 -Label 'list containers'
    $result['homeassistant'] = @(
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
    $result['smartWorkspace'] = @(
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
catch {
    $result.ok = $false
    $result.errors += [string]$_.Exception.Message
}

$result | ConvertTo-Json -Depth 10 | Set-Content -Path $outFile -Encoding UTF8
$result | ConvertTo-Json -Depth 10
