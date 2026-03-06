$ErrorActionPreference = 'Stop'
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

. "$PSScriptRoot\_invoke_webrequest_compat.ps1"

$base = 'https://192.168.0.135:9443'
$endpointId = 3
$username = 'annor'
$password = 'artanox2912@'
$stackName = 'smart-workspace'

$outFile = 'C:\Users\jkika\SQL\portainer_update_result.json'
$historyFile = 'C:\Users\jkika\SQL\portainer_disk_monitor.jsonl'
$historyMaxLines = 2000
$minLocalFreeGB = 5

function Get-LocalDiskInfo {
    param(
        [string]$DriveLetter = 'C'
    )

    $drive = Get-PSDrive -Name $DriveLetter -ErrorAction SilentlyContinue
    if($null -eq $drive) {
        return [ordered]@{
            drive = "${DriveLetter}:"
            freeGB = $null
            usedGB = $null
            totalGB = $null
            freePct = $null
            warning = 'Drive not found'
        }
    }

    $free = [double]$drive.Free
    $used = [double]$drive.Used
    $total = $free + $used
    $freePct = if($total -gt 0) { [math]::Round(($free / $total) * 100, 2) } else { $null }

    return [ordered]@{
        drive = "${DriveLetter}:"
        freeGB = [math]::Round($free / 1GB, 2)
        usedGB = [math]::Round($used / 1GB, 2)
        totalGB = [math]::Round($total / 1GB, 2)
        freePct = $freePct
        warning = $null
    }
}

function Get-DockerDfSummary {
    param(
        [string]$BaseUrl,
        [int]$Endpoint,
        [hashtable]$Headers
    )

    $dfUri = "$BaseUrl/api/endpoints/$Endpoint/docker/system/df"
    $df = Invoke-RestMethod -Method Get -Uri $dfUri -Headers $Headers -TimeoutSec 30

    $images = @($df.Images)
    $containers = @($df.Containers)
    $volumes = @($df.Volumes)

    $imagesSize = (($images | Measure-Object -Property Size -Sum).Sum)
    $containersSize = (($containers | Measure-Object -Property SizeRw -Sum).Sum)
    $volumesSize = (($volumes | Measure-Object -Property UsageData.Size -Sum).Sum)

    if($null -eq $imagesSize) { $imagesSize = 0 }
    if($null -eq $containersSize) { $containersSize = 0 }
    if($null -eq $volumesSize) { $volumesSize = 0 }

    return [ordered]@{
        layersSizeGB = [math]::Round(([double]$df.LayersSize) / 1GB, 2)
        imagesCount = $images.Count
        containersCount = $containers.Count
        volumesCount = $volumes.Count
        imagesSizeGB = [math]::Round(([double]$imagesSize) / 1GB, 2)
        containersWritableGB = [math]::Round(([double]$containersSize) / 1GB, 2)
        volumesSizeGB = [math]::Round(([double]$volumesSize) / 1GB, 2)
        dockerApproxTotalGB = [math]::Round((([double]$imagesSize + [double]$containersSize + [double]$volumesSize) / 1GB), 2)
    }
}

function Write-JsonAtomic {
    param(
        [string]$Path,
        [object]$Data,
        [int]$Depth = 10
    )

    $tmp = "$Path.tmp"
    $json = $Data | ConvertTo-Json -Depth $Depth
    Set-Content -Path $tmp -Value $json -Encoding UTF8
    Move-Item -Path $tmp -Destination $Path -Force
}

function Add-MonitorSample {
    param(
        [string]$Path,
        [object]$Sample,
        [int]$MaxLines = 2000
    )

    $line = $Sample | ConvertTo-Json -Compress -Depth 6
    Add-Content -Path $Path -Value $line -Encoding UTF8

    $lineCount = (Get-Content -Path $Path -ErrorAction SilentlyContinue | Measure-Object -Line).Lines
    if($lineCount -gt $MaxLines) {
        Get-Content -Path $Path -Tail $MaxLines | Set-Content -Path $Path -Encoding UTF8
    }
}

$result = [ordered]@{
    timestamp = (Get-Date).ToString('s')
    updateSuccess = $false
    updateError = ''
    stackId = $null
    stackName = $stackName
    stackStatus = 'unknown'
    stackContainers = @()
    localDisk = Get-LocalDiskInfo -DriveLetter 'C'
    remoteDocker = $null
}

try {
    $authBody = @{ username = $username; password = $password } | ConvertTo-Json
    $auth = Invoke-RestMethod -Method Post -Uri "$base/api/auth" -ContentType 'application/json' -Body $authBody -TimeoutSec 30
    $headers = @{ Authorization = "Bearer $($auth.jwt)" }

    $stacks = Invoke-RestMethod -Method Get -Uri "$base/api/stacks" -Headers $headers -TimeoutSec 30
    $stack = @($stacks | Where-Object { $_.Name -eq $stackName } | Select-Object -First 1)

    if($stack.Count -eq 0) {
        throw "Stack '$stackName' not found"
    }

    $stackObj = $stack[0]
    $result.stackId = [int]$stackObj.Id

    $containers = Invoke-RestMethod -Method Get -Uri "$base/api/endpoints/$endpointId/docker/containers/json?all=1&size=1" -Headers $headers -TimeoutSec 30

    $stackContainers = @(
        $containers |
            Where-Object { $_.Labels.'com.docker.compose.project' -eq $stackName } |
            ForEach-Object {
                [ordered]@{
                    id = [string]$_.Id
                    name = [string](($_.Names | Select-Object -First 1) -replace '^/', '')
                    state = [string]$_.State
                    status = [string]$_.Status
                    writableGB = [math]::Round(([double]$_.SizeRw) / 1GB, 3)
                    rootFsGB = [math]::Round(([double]$_.SizeRootFs) / 1GB, 3)
                }
            }
    )

    $result.stackContainers = $stackContainers
    if($stackContainers.Count -gt 0 -and ($stackContainers | Where-Object { $_.state -eq 'running' }).Count -eq $stackContainers.Count) {
        $result.stackStatus = 'running'
    } elseif($stackContainers.Count -gt 0) {
        $result.stackStatus = 'degraded'
    } else {
        $result.stackStatus = 'empty-or-not-detected'
    }

    $result.remoteDocker = Get-DockerDfSummary -BaseUrl $base -Endpoint $endpointId -Headers $headers

    if($result.localDisk.freeGB -lt $minLocalFreeGB) {
        $result.updateError = "Low local disk space on C: ($($result.localDisk.freeGB) GB free)"
    }

    $result.updateSuccess = [string]::IsNullOrWhiteSpace($result.updateError)
}
catch {
    $result.updateSuccess = $false
    $result.updateError = [string]$_.Exception.Message
}

Write-JsonAtomic -Path $outFile -Data $result -Depth 12

$monitorSample = [ordered]@{
    timestamp = $result.timestamp
    localFreeGB = $result.localDisk.freeGB
    localFreePct = $result.localDisk.freePct
    stackStatus = $result.stackStatus
    stackContainerCount = @($result.stackContainers).Count
    runningContainerCount = @($result.stackContainers | Where-Object { $_.state -eq 'running' }).Count
    dockerApproxTotalGB = if($null -ne $result.remoteDocker) { $result.remoteDocker.dockerApproxTotalGB } else { $null }
}
Add-MonitorSample -Path $historyFile -Sample $monitorSample -MaxLines $historyMaxLines

Write-Output ($result | ConvertTo-Json -Depth 8)
