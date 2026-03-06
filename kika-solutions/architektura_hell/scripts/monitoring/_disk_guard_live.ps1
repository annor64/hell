param(
    [int]$IntervalSec = 60,
    [double]$AlertGrowthMBPerMin = 200,
    [double]$AlertFreeGB = 50,
    [int]$TopPathCount = 5,
    [int]$TopProcessCount = 5,
    [string]$AlertsPath = 'C:\Users\jkika\SQL\disk_alerts.jsonl',
    [string[]]$TargetPaths = @(
        'C:\Users\jkika\AppData\Local\Temp',
        'C:\Users\jkika\AppData\Roaming\Code\logs',
        'C:\Users\jkika\AppData\Roaming\Code\User\workspaceStorage',
        'C:\Users\jkika\AppData\Local\Packages',
        'C:\ProgramData\Docker',
        'C:\ProgramData\DockerDesktop',
        'C:\Users\jkika\SQL'
    )
)

$ErrorActionPreference = 'Stop'

function Get-DirectorySizeBytes {
    param([string]$Path)

    if(-not (Test-Path -LiteralPath $Path)) { return $null }

    $sum = (Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    if($null -eq $sum) { $sum = 0 }
    return [double]$sum
}

function Get-DriveInfo {
    $drive = Get-PSDrive -Name C -ErrorAction SilentlyContinue
    if($null -eq $drive) {
        return [ordered]@{ freeGB = $null; totalGB = $null; freePct = $null }
    }

    $free = [double]$drive.Free
    $used = [double]$drive.Used
    $total = $free + $used
    $pct = if($total -gt 0) { [math]::Round(($free / $total) * 100, 2) } else { $null }

    return [ordered]@{
        freeGB = [math]::Round($free / 1GB, 2)
        totalGB = [math]::Round($total / 1GB, 2)
        freePct = $pct
    }
}

function Get-ProcessCounterPaths {
    $counterSetName = if(Get-Counter -ListSet 'Proces V2' -ErrorAction SilentlyContinue) { 'Proces V2' } else { 'Proces' }
    $paths = (Get-Counter -ListSet $counterSetName -ErrorAction Stop).Paths

    $pidPath = $paths | Where-Object { $_ -like '*\ID procesu' } | Select-Object -First 1
    $dataPath = $paths | Where-Object { $_ -like '*Bajty vstup*' -and $_ -like '*dat*' -and $_ -like '*/s' } | Select-Object -First 1

    if([string]::IsNullOrWhiteSpace($pidPath) -or [string]::IsNullOrWhiteSpace($dataPath)) {
        throw 'Process I/O counters not found.'
    }

    return [ordered]@{
        counterSetName = $counterSetName
        pidPath = $pidPath
        dataPath = $dataPath
    }
}

function Get-ProcessIoTop {
    param(
        [hashtable]$CounterPaths,
        [int]$Top = 5
    )

    $samples = Get-Counter -Counter @($CounterPaths.pidPath, $CounterPaths.dataPath) -SampleInterval 1 -MaxSamples 1
    $rows = @{}

    foreach($sample in $samples.CounterSamples) {
        $instance = [string]$sample.InstanceName
        if(-not $rows.ContainsKey($instance)) {
            $rows[$instance] = [ordered]@{ pid = 0; instance = $instance; totalBps = 0.0 }
        }

        if($sample.Path -like '*\ID procesu') {
            $rows[$instance].pid = [int]$sample.CookedValue
        } elseif($sample.Path -like '*Bajty vstup*' -and $sample.Path -like '*dat*' -and $sample.Path -like '*/s') {
            $rows[$instance].totalBps = [double]$sample.CookedValue
        }
    }

    $procMap = @{}
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | ForEach-Object {
        $procMap[[int]$_.ProcessId] = [ordered]@{
            name = [string]$_.Name
            path = [string]$_.ExecutablePath
        }
    }

    $out = @(
        foreach($k in $rows.Keys) {
            $r = $rows[$k]
            if($r.pid -le 0 -or $r.totalBps -le 0) { continue }
            $meta = $procMap[$r.pid]
            [ordered]@{
                pid = $r.pid
                processName = if($null -ne $meta -and -not [string]::IsNullOrWhiteSpace($meta.name)) { $meta.name } else { $r.instance }
                totalMBps = [math]::Round(($r.totalBps / 1MB), 4)
                executablePath = if($null -ne $meta) { $meta.path } else { '' }
            }
        }
    ) | Sort-Object totalMBps -Descending | Select-Object -First $Top

    return $out
}

function Add-Alert {
    param(
        [string]$Type,
        [string]$Message,
        [object]$Data
    )

    $row = [ordered]@{
        timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        type = $Type
        message = $Message
        data = $Data
    }

    Add-Content -LiteralPath $AlertsPath -Value ($row | ConvertTo-Json -Compress -Depth 8) -Encoding UTF8
}

$prevSizes = @{}
foreach($p in $TargetPaths) {
    $prevSizes[$p] = Get-DirectorySizeBytes -Path $p
}

$counterPaths = $null
try {
    $counterPaths = Get-ProcessCounterPaths
} catch {
    $counterPaths = $null
}

Write-Host ''
Write-Host '=== DISK GUARD LIVE START ===' -ForegroundColor Cyan
Write-Host "Interval: $IntervalSec s | AlertGrowthMBPerMin: $AlertGrowthMBPerMin | AlertFreeGB: $AlertFreeGB" -ForegroundColor Cyan
Write-Host "Alerts file: $AlertsPath" -ForegroundColor Cyan
Write-Host ''

while($true) {
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $drive = Get-DriveInfo

    $growthRows = @()
    foreach($p in $TargetPaths) {
        $curr = Get-DirectorySizeBytes -Path $p
        $prev = $prevSizes[$p]

        $deltaBytes = $null
        if($null -ne $curr -and $null -ne $prev) {
            $deltaBytes = $curr - $prev
        }

        $deltaMBPerMin = $null
        if($null -ne $deltaBytes -and $IntervalSec -gt 0) {
            $deltaMBPerMin = [math]::Round((($deltaBytes / 1MB) * (60.0 / $IntervalSec)), 3)
        }

        $growthRows += [ordered]@{
            path = $p
            sizeGB = if($null -ne $curr) { [math]::Round($curr / 1GB, 3) } else { $null }
            deltaMBPerMin = $deltaMBPerMin
        }

        $prevSizes[$p] = $curr
    }

    $topGrowth = @($growthRows | Where-Object { $null -ne $_.deltaMBPerMin } | Sort-Object deltaMBPerMin -Descending | Select-Object -First $TopPathCount)

    $processTop = @()
    if($null -ne $counterPaths) {
        try {
            $processTop = @(Get-ProcessIoTop -CounterPaths $counterPaths -Top $TopProcessCount)
        } catch {
            $processTop = @()
        }
    }

    $alerts = @()

    if($null -ne $drive.freeGB -and $drive.freeGB -lt $AlertFreeGB) {
        $msg = "LOW FREE SPACE: C: free $($drive.freeGB) GB (< $AlertFreeGB GB)"
        $alerts += $msg
        Add-Alert -Type 'low_free_space' -Message $msg -Data $drive
    }

    foreach($g in $topGrowth) {
        if($null -ne $g.deltaMBPerMin -and $g.deltaMBPerMin -ge $AlertGrowthMBPerMin) {
            $msg = "UNUSUAL GROWTH: $($g.path) +$($g.deltaMBPerMin) MB/min"
            $alerts += $msg
            Add-Alert -Type 'unusual_growth' -Message $msg -Data $g
        }
    }

    Clear-Host
    Write-Host "=== DISK GUARD LIVE === $timestamp" -ForegroundColor Green
    Write-Host ("C: free {0} GB / {1} GB ({2}%)" -f $drive.freeGB, $drive.totalGB, $drive.freePct) -ForegroundColor Yellow
    Write-Host ''

    Write-Host 'Top folder growth (MB/min):' -ForegroundColor Cyan
    $topGrowth | Format-Table path,sizeGB,deltaMBPerMin -AutoSize

    Write-Host ''
    Write-Host 'Top process disk I/O (MB/s):' -ForegroundColor Cyan
    if($processTop.Count -gt 0) {
        $processTop | Format-Table processName,pid,totalMBps,executablePath -AutoSize
    } else {
        Write-Host 'No process I/O data available.'
    }

    Write-Host ''
    if($alerts.Count -gt 0) {
        Write-Host 'ALERTS:' -ForegroundColor Red
        foreach($a in $alerts) {
            Write-Host "- $a" -ForegroundColor Red
        }
    } else {
        Write-Host 'Alerts: none' -ForegroundColor DarkGreen
    }

    Start-Sleep -Seconds $IntervalSec
}
