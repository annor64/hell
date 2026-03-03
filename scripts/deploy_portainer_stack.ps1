param(
    [Parameter(Mandatory = $true)]
    [string]$StackName,

    [Parameter(Mandatory = $true)]
    [string]$StackFile,

    [Parameter(Mandatory = $false)]
    [string]$EnvFile = ".\gitops\secrets\portainer.env",

    [Parameter(Mandatory = $false)]
    [switch]$Prune,

    [Parameter(Mandatory = $false)]
    [switch]$PullImage
)

$ErrorActionPreference = 'Stop'
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

$requestTimeoutSec = 45

function To-PassFail {
    param([bool]$Value)
    if($Value) { return 'PASS' }
    return 'FAIL'
}

function Write-PreflightReport {
    param(
        [string]$Path,
        [hashtable]$Preflight,
        [hashtable]$Result
    )

    $dir = Split-Path -Path $Path -Parent
    if(-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $lines = @(
        '# Preflight Report',
        '',
        "Datum: $($Preflight.timestamp)",
        "Operator: $($Preflight.operator)",
        "Repo revision: $($Preflight.repoRevision)",
        '',
        '## 1) Kontext deploye',
        "- Stack name: $($Preflight.stackName)",
        "- Stack file: $($Preflight.stackFile)",
        "- Endpoint ID: $($Preflight.endpointId)",
        "- Expected endpoint name: $($Preflight.expectedEndpointName)",
        "- Expected docker host: $($Preflight.expectedDockerName)",
        '',
        '## 2) Guard checks',
        "- Endpoint ID match: $(To-PassFail -Value ([bool]$Preflight.endpointIdMatch))",
        "- Endpoint name match: $(To-PassFail -Value ([bool]$Preflight.endpointNameMatch))",
        "- Docker host match: $(To-PassFail -Value ([bool]$Preflight.dockerNameMatch))",
        "- Secrets loaded (`API_KEY`/fallback): $(To-PassFail -Value ([bool]$Preflight.secretsLoaded))",
        '',
        '## 3) Artefakty a validace',
        "- Compose syntactic check: $(To-PassFail -Value ([bool]$Preflight.composeLoaded))",
        "- Required files present: $(To-PassFail -Value ([bool]$Preflight.requiredFilesPresent))",
        "- Target paths from architecture mapping: $(To-PassFail -Value ([bool]$Preflight.archMappingPathsPresent))",
        '',
        '## 4) Rizika před nasazením',
        '- Open blockers:',
        ("  - " + ($(if([string]::IsNullOrWhiteSpace([string]$Result.error)) { 'none' } else { [string]$Result.error }))),
        '- Known warnings:',
        ("  - " + ($(if($Result.ok) { 'none' } else { 'deploy ended with error' }))),
        '',
        '## 5) Rozhodnutí',
        "- Deploy approved: $(if($Result.ok) { 'YES' } else { 'NO' })",
        "- Fallback prepared (SSH on HELL): $(if($Preflight.fallbackReady) { 'YES' } else { 'NO' })",
        "- Rollback plan reference: $($Preflight.rollbackReference)",
        '',
        '## 6) Post-run odkazy',
        '- Deploy result: `gitops/deploy-result.json`',
        '- Runtime status: `portainer_update_result.json`',
        '- Optional logs: `ha_deploy_result.json`',
        "- Containers detected for stack: $($Result.containers.Count)",
        ''
    )

    Set-Content -Path $Path -Value ($lines -join "`r`n") -Encoding UTF8
}

function Load-DotEnv {
    param([string]$Path)

    if(-not (Test-Path -Path $Path)) { return @{} }

    $map = @{}
    Get-Content -Path $Path | ForEach-Object {
        $line = $_.Trim()
        if([string]::IsNullOrWhiteSpace($line)) { return }
        if($line.StartsWith('#')) { return }
        $parts = $line -split '=', 2
        if($parts.Count -ne 2) { return }
        $key = $parts[0].Trim()
        $value = $parts[1].Trim().Trim('"').Trim("'")
        if(-not [string]::IsNullOrWhiteSpace($key)) {
            $map[$key] = $value
        }
    }

    return $map
}

function Resolve-Setting {
    param(
        [hashtable]$EnvMap,
        [string]$Name,
        [string]$Default = ''
    )

    $processValue = [Environment]::GetEnvironmentVariable($Name, 'Process')
    if(-not [string]::IsNullOrWhiteSpace($processValue)) { return $processValue }

    if($EnvMap.ContainsKey($Name) -and -not [string]::IsNullOrWhiteSpace([string]$EnvMap[$Name])) {
        return [string]$EnvMap[$Name]
    }

    return $Default
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
            Stop-Job -Job $job | Out-Null
            throw "Timeout while waiting for $Label (${TimeoutSec}s)."
        }

        $jobError = $job.ChildJobs | ForEach-Object { $_.JobStateInfo.Reason } | Where-Object { $null -ne $_ } | Select-Object -First 1
        if($null -ne $jobError) {
            throw [string]$jobError
        }

        return Receive-Job -Job $job -ErrorAction Stop
    }
    finally {
        Remove-Job -Job $job -ErrorAction SilentlyContinue
    }
}

function Get-BitwardenItem {
    param(
        [string]$ItemId,
        [string]$ItemName,
        [string]$Session
    )

    $bw = Get-Command bw -ErrorAction SilentlyContinue
    if($null -eq $bw) { return $null }
    if([string]::IsNullOrWhiteSpace($Session)) { return $null }

    if(-not [string]::IsNullOrWhiteSpace($ItemId)) {
        try {
            return (& bw get item $ItemId --session $Session | ConvertFrom-Json)
        } catch {
            return $null
        }
    }

    if([string]::IsNullOrWhiteSpace($ItemName)) { return $null }

    try {
        $items = (& bw list items --search $ItemName --session $Session | ConvertFrom-Json)
        $exact = @($items | Where-Object { $_.name -eq $ItemName } | Select-Object -First 1)
        if($exact.Count -gt 0) { return $exact[0] }
        $first = @($items | Select-Object -First 1)
        if($first.Count -gt 0) { return $first[0] }
        return $null
    } catch {
        return $null
    }
}

function Load-BitwardenSecretMap {
    param(
        [string]$ItemId,
        [string]$ItemName,
        [string]$Session
    )

    $map = @{}
    $item = Get-BitwardenItem -ItemId $ItemId -ItemName $ItemName -Session $Session
    if($null -eq $item) { return $map }

    if($item.PSObject.Properties.Name -contains 'fields' -and $null -ne $item.fields) {
        foreach($f in $item.fields) {
            if($null -eq $f) { continue }
            $name = [string]$f.name
            $value = [string]$f.value
            if(-not [string]::IsNullOrWhiteSpace($name) -and -not [string]::IsNullOrWhiteSpace($value)) {
                $map[$name] = $value
            }
        }
    }

    if($item.PSObject.Properties.Name -contains 'login' -and $null -ne $item.login) {
        if(-not [string]::IsNullOrWhiteSpace([string]$item.login.username)) {
            $map['PORTAINER_USERNAME'] = [string]$item.login.username
        }
        if(-not [string]::IsNullOrWhiteSpace([string]$item.login.password)) {
            if(-not $map.ContainsKey('PORTAINER_API_KEY')) {
                $map['PORTAINER_API_KEY'] = [string]$item.login.password
            }
            $map['PORTAINER_PASSWORD'] = [string]$item.login.password
        }

        if($item.login.PSObject.Properties.Name -contains 'uris' -and $null -ne $item.login.uris) {
            $firstUri = @($item.login.uris | Select-Object -First 1)
            if($firstUri.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$firstUri[0].uri)) {
                if(-not $map.ContainsKey('PORTAINER_BASE_URL')) {
                    $map['PORTAINER_BASE_URL'] = [string]$firstUri[0].uri
                }
            }
        }
    }

    return $map
}

$envMap = Load-DotEnv -Path $EnvFile
$bwItemId = Resolve-Setting -EnvMap $envMap -Name 'BW_ITEM_ID'
$bwItemName = Resolve-Setting -EnvMap $envMap -Name 'BW_ITEM_NAME' -Default 'portainer-deploy-secrets'
$bwSession = Resolve-Setting -EnvMap $envMap -Name 'BW_SESSION'

$bwMap = Load-BitwardenSecretMap -ItemId $bwItemId -ItemName $bwItemName -Session $bwSession
foreach($key in $bwMap.Keys) {
    if(-not $envMap.ContainsKey($key) -or [string]::IsNullOrWhiteSpace([string]$envMap[$key])) {
        $envMap[$key] = [string]$bwMap[$key]
    }
}

$baseUrl = Resolve-Setting -EnvMap $envMap -Name 'PORTAINER_BASE_URL'
$endpointId = Resolve-Setting -EnvMap $envMap -Name 'PORTAINER_ENDPOINT_ID'
$apiKey = Resolve-Setting -EnvMap $envMap -Name 'PORTAINER_API_KEY'
$username = Resolve-Setting -EnvMap $envMap -Name 'PORTAINER_USERNAME'
$password = Resolve-Setting -EnvMap $envMap -Name 'PORTAINER_PASSWORD'
$expectedEndpointId = Resolve-Setting -EnvMap $envMap -Name 'PORTAINER_EXPECTED_ENDPOINT_ID' -Default '3'
$expectedEndpointName = Resolve-Setting -EnvMap $envMap -Name 'PORTAINER_EXPECTED_ENDPOINT_NAME' -Default 'local'
$expectedDockerName = Resolve-Setting -EnvMap $envMap -Name 'PORTAINER_EXPECTED_DOCKER_NAME' -Default 'hell'

if([string]::IsNullOrWhiteSpace($baseUrl)) { throw 'Missing PORTAINER_BASE_URL' }
if([string]::IsNullOrWhiteSpace($endpointId)) { throw 'Missing PORTAINER_ENDPOINT_ID' }
if(-not (Test-Path -Path $StackFile)) { throw "Stack file not found: $StackFile" }

$headers = @{}
if(-not [string]::IsNullOrWhiteSpace($apiKey)) {
    $headers['X-API-Key'] = $apiKey
}
else {
    if([string]::IsNullOrWhiteSpace($username) -or [string]::IsNullOrWhiteSpace($password)) {
        throw 'Missing PORTAINER_API_KEY or fallback PORTAINER_USERNAME/PORTAINER_PASSWORD'
    }

    $authBody = @{ username = $username; password = $password } | ConvertTo-Json
    $auth = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/auth" -ContentType 'application/json' -Body $authBody -TimeoutSec $requestTimeoutSec
    $headers['Authorization'] = "Bearer $($auth.jwt)"
}

$stackContent = Get-Content -Path $StackFile -Raw -Encoding UTF8

$repoRevision = 'unknown'
try {
    $repoRevision = (git rev-parse --short HEAD 2>$null | Select-Object -First 1)
    if([string]::IsNullOrWhiteSpace($repoRevision)) { $repoRevision = 'unknown' }
} catch {
    $repoRevision = 'unknown'
}

$requiredPaths = @(
    'ARCHITEKTURA_DEPLOYMENT_FACTORY.md',
    'gitops/stacks',
    'scripts/deploy_portainer_stack.ps1'
)

$preflight = [ordered]@{
    timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    operator = $(if(-not [string]::IsNullOrWhiteSpace($env:GITHUB_ACTOR)) { $env:GITHUB_ACTOR } elseif(-not [string]::IsNullOrWhiteSpace($env:USERNAME)) { $env:USERNAME } else { 'unknown' })
    repoRevision = $repoRevision
    stackName = $StackName
    stackFile = $StackFile
    endpointId = [int]$endpointId
    expectedEndpointName = $expectedEndpointName
    expectedDockerName = $expectedDockerName
    endpointIdMatch = ([int]$endpointId -eq [int]$expectedEndpointId)
    endpointNameMatch = $false
    dockerNameMatch = $false
    secretsLoaded = ((-not [string]::IsNullOrWhiteSpace($apiKey)) -or ((-not [string]::IsNullOrWhiteSpace($username)) -and (-not [string]::IsNullOrWhiteSpace($password))))
    composeLoaded = (-not [string]::IsNullOrWhiteSpace($stackContent))
    requiredFilesPresent = ($requiredPaths | Where-Object { -not (Test-Path -Path $_) }).Count -eq 0
    archMappingPathsPresent = ($requiredPaths | Where-Object { -not (Test-Path -Path $_) }).Count -eq 0
    fallbackReady = ((Resolve-Setting -EnvMap $envMap -Name 'PORTAINER_SSH_FALLBACK_READY' -Default 'false').ToLowerInvariant() -eq 'true')
    rollbackReference = 'ARCHITEKTURA_DEPLOYMENT_FACTORY.md'
}

$result = [ordered]@{
    timestamp = (Get-Date).ToString('s')
    ok = $false
    action = ''
    stackName = $StackName
    stackId = $null
    endpointId = [int]$endpointId
    expectedEndpointId = [int]$expectedEndpointId
    expectedEndpointName = $expectedEndpointName
    expectedDockerName = $expectedDockerName
    error = ''
    containers = @()
}

try {
    if([int]$endpointId -ne [int]$expectedEndpointId) {
        throw "Endpoint guard failed: requested endpointId=$endpointId, expected=$expectedEndpointId"
    }

    $endpoint = Invoke-RestMethod -Method Get -Uri "$baseUrl/api/endpoints/$endpointId" -Headers $headers -TimeoutSec 30
    $dockerInfo = Invoke-RestMethod -Method Get -Uri "$baseUrl/api/endpoints/$endpointId/docker/info" -Headers $headers -TimeoutSec 30

    $actualEndpointName = [string]$endpoint.Name
    $actualDockerName = [string]$dockerInfo.Name

    $result['actualEndpointName'] = $actualEndpointName
    $result['actualDockerName'] = $actualDockerName
    $preflight.endpointNameMatch = ($actualEndpointName -eq $expectedEndpointName)
    $preflight.dockerNameMatch = ($actualDockerName -eq $expectedDockerName)

    if($actualEndpointName -ne $expectedEndpointName) {
        throw "Endpoint guard failed: endpoint name '$actualEndpointName' != expected '$expectedEndpointName'"
    }

    if($actualDockerName -ne $expectedDockerName) {
        throw "Endpoint guard failed: docker host '$actualDockerName' != expected '$expectedDockerName'"
    }

    $stacks = Invoke-RestMethod -Method Get -Uri "$baseUrl/api/stacks" -Headers $headers -TimeoutSec $requestTimeoutSec
    $existing = @($stacks | Where-Object { $_.Name -eq $StackName } | Select-Object -First 1)

    if($existing.Count -gt 0) {
        $stackId = [int]$existing[0].Id
        $updateBody = @{
            StackFileContent = $stackContent
            Env = @()
            Prune = [bool]$Prune
            PullImage = [bool]$PullImage
        } | ConvertTo-Json -Depth 10

        Invoke-RestMethodWithHardTimeout -Method 'Put' -Uri "$baseUrl/api/stacks/$stackId?endpointId=$endpointId" -Headers $headers -ContentType 'application/json' -Body $updateBody -TimeoutSec $requestTimeoutSec -Label 'stack update' | Out-Null
        $result.action = 'updated'
        $result.stackId = $stackId
    }
    else {
        $createBody = @{
            Name = $StackName
            StackFileContent = $stackContent
            Env = @()
            FromAppTemplate = $false
        } | ConvertTo-Json -Depth 10

        $created = $null
        $createError = ''
        $createUris = @(
            "$baseUrl/api/stacks/create/standalone/string?endpointId=$endpointId",
            "$baseUrl/api/stacks?type=2&method=string&endpointId=$endpointId"
        )

        foreach($createUri in $createUris) {
            try {
                $created = Invoke-RestMethodWithHardTimeout -Method 'Post' -Uri $createUri -Headers $headers -ContentType 'application/json' -Body $createBody -TimeoutSec $requestTimeoutSec -Label 'stack create'
                if($null -ne $created) { break }
            }
            catch {
                $createError = [string]$_.Exception.Message
            }
        }

        if($null -ne $created -and $created.PSObject.Properties.Name -contains 'Id') {
            $result.action = 'created'
            $result.stackId = [int]$created.Id
        }
        else {
            $deadline = (Get-Date).AddSeconds(120)
            $pollStack = @()

            do {
                Start-Sleep -Seconds 5
                $stacksPoll = Invoke-RestMethod -Method Get -Uri "$baseUrl/api/stacks" -Headers $headers -TimeoutSec $requestTimeoutSec
                $pollStack = @($stacksPoll | Where-Object { $_.Name -eq $StackName } | Select-Object -First 1)
                if($pollStack.Count -gt 0) { break }
            } while((Get-Date) -lt $deadline)

            if($pollStack.Count -gt 0) {
                $result.action = 'created-poll-detected'
                $result.stackId = [int]$pollStack[0].Id
            }
            else {
                throw "Stack create did not complete. Last create error: $createError"
            }
        }
    }

    Start-Sleep -Seconds 3

    $containers = Invoke-RestMethod -Method Get -Uri "$baseUrl/api/endpoints/$endpointId/docker/containers/json?all=1" -Headers $headers -TimeoutSec $requestTimeoutSec
    $result.containers = @(
        $containers |
            Where-Object { $_.Labels.'com.docker.compose.project' -eq $StackName } |
            ForEach-Object {
                [ordered]@{
                    name = [string](($_.Names | Select-Object -First 1) -replace '^/', '')
                    state = [string]$_.State
                    status = [string]$_.Status
                    image = [string]$_.Image
                }
            }
    )

    $result.ok = $true
}
catch {
    $result.ok = $false
    $result.error = [string]$_.Exception.Message
}

$resultPath = '.\gitops\deploy-result.json'
$preflightPath = '.\gitops\preflight-report.md'
$result['preflightReportPath'] = $preflightPath
$result | ConvertTo-Json -Depth 10 | Set-Content -Path $resultPath -Encoding UTF8
Write-PreflightReport -Path $preflightPath -Preflight $preflight -Result $result
Write-Output ($result | ConvertTo-Json -Depth 10)
