$ErrorActionPreference = 'Stop'
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

$base = 'https://192.168.0.135:9443'
$endpointId = 3
$username = 'annor'
$password = 'artanox2912@'

$stackName = 'homeassistant'
$stackFile = 'C:\Users\jkika\SQL\homeassistant-stack.yml'
$resultFile = 'C:\Users\jkika\SQL\ha_deploy_result.json'
$debugLogFile = 'C:\Users\jkika\SQL\ha_deploy_debug.log'
$requestTimeoutSec = 45

function Write-DebugLog {
    param([string]$Message)
    $line = "$(Get-Date -Format s) $Message"
    Add-Content -Path $debugLogFile -Value $line -Encoding UTF8
    Write-Host $line
}

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

Set-Content -Path $debugLogFile -Value "$(Get-Date -Format s) START" -Encoding UTF8

$result = [ordered]@{
    timestamp = (Get-Date).ToString('s')
    ok = $false
    action = ''
    error = ''
    stackId = $null
    stackName = $stackName
    containers = @()
    url = 'http://<IP_SERVERU>:8123'
}

try {
    Write-DebugLog 'Validating stack file path'
    if(-not (Test-Path -Path $stackFile)) {
        throw "Stack file not found: $stackFile"
    }

    Write-DebugLog 'Authenticating to Portainer API'
    $authBody = @{ username = $username; password = $password } | ConvertTo-Json
    $auth = Invoke-RestMethod -Method Post -Uri "$base/api/auth" -ContentType 'application/json' -Body $authBody -TimeoutSec $requestTimeoutSec
    $headers = @{ Authorization = "Bearer $($auth.jwt)" }

    Write-DebugLog 'Reading stack YAML and listing stacks'
    $content = Get-Content -Path $stackFile -Raw -Encoding UTF8
    $stacks = Invoke-RestMethod -Method Get -Uri "$base/api/stacks" -Headers $headers -TimeoutSec $requestTimeoutSec
    $existing = @($stacks | Where-Object { $_.Name -eq $stackName } | Select-Object -First 1)

    if($existing.Count -gt 0) {
        Write-DebugLog 'Existing stack found, updating'
        $stackId = [int]$existing[0].Id
        $body = @{
            StackFileContent = $content
            Env = @()
            Prune = $true
            PullImage = $true
        } | ConvertTo-Json -Depth 10

        Invoke-RestMethod -Method Put -Uri "$base/api/stacks/$stackId?endpointId=$endpointId" -Headers $headers -ContentType 'application/json' -Body $body -TimeoutSec $requestTimeoutSec | Out-Null
        $result.action = 'updated'
        $result.stackId = $stackId
    }
    else {
        Write-DebugLog 'Stack not found, creating'
        $body = @{
            Name = $stackName
            StackFileContent = $content
            Env = @()
            FromAppTemplate = $false
        } | ConvertTo-Json -Depth 10

        $created = $null
        $createError = ''
        $createUris = @(
            "$base/api/stacks/create/standalone/string?endpointId=$endpointId",
            "$base/api/stacks?type=2&method=string&endpointId=$endpointId"
        )

        foreach($createUri in $createUris) {
            try {
                Write-DebugLog "Trying create endpoint: $createUri"
                $created = Invoke-RestMethodWithHardTimeout -Method 'Post' -Uri $createUri -Headers $headers -ContentType 'application/json' -Body $body -TimeoutSec $requestTimeoutSec -Label 'stack create'
                if($null -ne $created) {
                    break
                }
            }
            catch {
                $createError = [string]$_.Exception.Message
                Write-DebugLog "Create endpoint failed: $createError"
            }
        }

        if($null -ne $created -and $created.PSObject.Properties.Name -contains 'Id') {
            $result.action = 'created'
            $result.stackId = [int]$created.Id
        }
        else {
            Write-DebugLog 'Create response missing or timed out; polling stack list for eventual creation'
            $deadline = (Get-Date).AddSeconds(120)
            $pollStack = @()

            do {
                Start-Sleep -Seconds 5
                $stacksPoll = Invoke-RestMethod -Method Get -Uri "$base/api/stacks" -Headers $headers -TimeoutSec $requestTimeoutSec
                $pollStack = @($stacksPoll | Where-Object { $_.Name -eq $stackName } | Select-Object -First 1)
                if($pollStack.Count -gt 0) { break }
            } while((Get-Date) -lt $deadline)

            if($pollStack.Count -gt 0) {
                $result.action = 'created-poll-detected'
                $result.stackId = [int]$pollStack[0].Id
                Write-DebugLog "Stack detected by polling with id $($result.stackId)"
            }
            else {
                throw "Stack create did not complete. Last create error: $createError"
            }
        }
    }

    Write-DebugLog 'Fetching container status'
    Start-Sleep -Seconds 3

    $containers = Invoke-RestMethod -Method Get -Uri "$base/api/endpoints/$endpointId/docker/containers/json?all=1" -Headers $headers -TimeoutSec $requestTimeoutSec
    $result.containers = @(
        $containers |
            Where-Object { $_.Labels.'com.docker.compose.project' -eq $stackName } |
            ForEach-Object {
                [ordered]@{
                    id = [string]$_.Id
                    name = [string](($_.Names | Select-Object -First 1) -replace '^/', '')
                    state = [string]$_.State
                    status = [string]$_.Status
                    image = [string]$_.Image
                }
            }
    )

    $result.ok = $true
    Write-DebugLog 'Deployment flow completed successfully'
}
catch {
    $result.ok = $false
    $result.error = [string]$_.Exception.ToString()
    Write-DebugLog "Deployment failed: $($result.error)"
}

$json = $result | ConvertTo-Json -Depth 10
Set-Content -Path $resultFile -Value $json -Encoding UTF8
Write-DebugLog "Result written to $resultFile"
Write-Output $json