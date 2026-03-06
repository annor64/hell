param(
    [string[]]$TargetPaths = @(
        'C:\Users\jkika\AppData\Local\Temp',
        'C:\Users\jkika\AppData\Roaming\Code\logs',
        'C:\Users\jkika\AppData\Roaming\Code\User\workspaceStorage',
        'C:\Users\jkika\AppData\Local\Packages',
        'C:\ProgramData\Docker',
        'C:\ProgramData\DockerDesktop',
        'C:\Users\jkika\SQL'
    ),
    [int]$TopN = 10,
    [string]$StatePath = 'C:\Users\jkika\SQL\disk_growth_state.json',
    [string]$SnapshotPath = 'C:\Users\jkika\SQL\disk_growth_latest.json',
    [string]$HistoryPath = 'C:\Users\jkika\SQL\disk_growth_history.jsonl',
    [int]$MaxHistoryLines = 5000
)

$ErrorActionPreference = 'Stop'

function Get-DirectorySizeBytes {
    param([string]$Path)

    if(-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    try {
        $sum = (Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        if($null -eq $sum) { $sum = 0 }
        return [double]$sum
    } catch {
        return $null
    }
}

function Read-State {
    param([string]$Path)

    if(-not (Test-Path -LiteralPath $Path)) {
        return @{}
    }

    try {
        $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
        if([string]::IsNullOrWhiteSpace($raw)) { return @{} }
        $obj = $raw | ConvertFrom-Json -ErrorAction Stop
        $map = @{}
        foreach($p in $obj.PSObject.Properties) {
            $map[$p.Name] = [double]$p.Value
        }
        return $map
    } catch {
        return @{}
    }
}

function Write-JsonAtomic {
    param(
        [string]$Path,
        [object]$Data,
        [int]$Depth = 8
    )

    $tmp = "$Path.tmp"
    $json = $Data | ConvertTo-Json -Depth $Depth
    Set-Content -LiteralPath $tmp -Value $json -Encoding UTF8
    Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function Trim-History {
    param(
        [string]$Path,
        [int]$MaxLines
    )

    if(-not (Test-Path -LiteralPath $Path)) { return }

    $lineCount = (Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue | Measure-Object -Line).Lines
    if($lineCount -gt $MaxLines) {
        Get-Content -LiteralPath $Path -Tail $MaxLines | Set-Content -LiteralPath $Path -Encoding UTF8
    }
}

$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$prevState = Read-State -Path $StatePath
$currentState = @{}
$rows = New-Object System.Collections.Generic.List[object]

foreach($path in $TargetPaths) {
    $sizeBytes = Get-DirectorySizeBytes -Path $path
    if($null -eq $sizeBytes) {
        $rows.Add([ordered]@{
            path = $path
            exists = $false
            sizeGB = $null
            deltaMB = $null
            growthPerMinMB = $null
        }) | Out-Null
        continue
    }

    $currentState[$path] = $sizeBytes

    $prev = if($prevState.ContainsKey($path)) { [double]$prevState[$path] } else { $null }
    $deltaBytes = if($null -ne $prev) { $sizeBytes - $prev } else { $null }

    $rows.Add([ordered]@{
        path = $path
        exists = $true
        sizeGB = [math]::Round($sizeBytes / 1GB, 3)
        deltaMB = if($null -ne $deltaBytes) { [math]::Round($deltaBytes / 1MB, 3) } else { $null }
        growthPerMinMB = if($null -ne $deltaBytes) { [math]::Round($deltaBytes / 1MB, 3) } else { $null }
    }) | Out-Null
}

$drive = Get-PSDrive -Name C -ErrorAction SilentlyContinue
$freeGB = if($null -ne $drive) { [math]::Round(([double]$drive.Free) / 1GB, 2) } else { $null }
$totalGB = if($null -ne $drive) { [math]::Round((([double]$drive.Free + [double]$drive.Used) / 1GB), 2) } else { $null }
$freePct = if($null -ne $drive -and (($drive.Free + $drive.Used) -gt 0)) { [math]::Round((($drive.Free / ($drive.Free + $drive.Used)) * 100), 2) } else { $null }

$topGrowth = @(
    $rows |
        Where-Object { $_.exists -eq $true -and $null -ne $_.deltaMB } |
        Sort-Object deltaMB -Descending |
        Select-Object -First $TopN
)

$latest = [ordered]@{
    timestamp = $timestamp
    drive = [ordered]@{
        name = 'C:'
        freeGB = $freeGB
        totalGB = $totalGB
        freePct = $freePct
    }
    topGrowth = $topGrowth
    allTargets = $rows
}

Write-JsonAtomic -Path $SnapshotPath -Data $latest -Depth 10
Write-JsonAtomic -Path $StatePath -Data $currentState -Depth 6

foreach($item in $topGrowth) {
    $historyRow = [ordered]@{
        timestamp = $timestamp
        driveFreeGB = $freeGB
        driveFreePct = $freePct
        path = $item.path
        sizeGB = $item.sizeGB
        deltaMB = $item.deltaMB
    }
    Add-Content -LiteralPath $HistoryPath -Value ($historyRow | ConvertTo-Json -Compress) -Encoding UTF8
}

Trim-History -Path $HistoryPath -MaxLines $MaxHistoryLines

$summary = [ordered]@{
    timestamp = $timestamp
    driveFreeGB = $freeGB
    driveFreePct = $freePct
    topGrowth = $topGrowth
}

Write-Output ($summary | ConvertTo-Json -Depth 8)
