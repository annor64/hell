param(
    [int]$IntervalSec = 5,
    [int]$TopN = 8,
    [int]$MaxSamples = 0,
    [string]$CsvPath = 'C:\Users\jkika\SQL\disk_io_top.csv',
    [string]$JsonlPath = 'C:\Users\jkika\SQL\disk_io_top.jsonl'
)

$ErrorActionPreference = 'Stop'

function Get-ProcessCounterPaths {
    $counterSetName = if(Get-Counter -ListSet 'Proces V2' -ErrorAction SilentlyContinue) { 'Proces V2' } else { 'Proces' }
    $paths = (Get-Counter -ListSet $counterSetName -ErrorAction Stop).Paths

    $pidPath = $paths | Where-Object { $_ -like '*\ID procesu' } | Select-Object -First 1
    $dataPath = $paths | Where-Object { $_ -like '*Bajty vstup*' -and $_ -like '*dat*' -and $_ -like '*/s' } | Select-Object -First 1

    if([string]::IsNullOrWhiteSpace($pidPath) -or [string]::IsNullOrWhiteSpace($dataPath)) {
        throw 'Required process I/O counters were not found.'
    }

    return [ordered]@{
        counterSetName = $counterSetName
        pidPath = $pidPath
        dataPath = $dataPath
    }
}

function Get-ProcessCommandLineMap {
    $map = @{}
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | ForEach-Object {
        $map[[int]$_.ProcessId] = [ordered]@{
            executablePath = [string]$_.ExecutablePath
            commandLine = [string]$_.CommandLine
            processName = [string]$_.Name
        }
    }
    return $map
}

function Get-ProcessIoRows {
    param(
        [string]$PidPath,
        [string]$DataPath,
        [hashtable]$CmdMap
    )

    $samples = Get-Counter -Counter @($PidPath, $DataPath) -SampleInterval $IntervalSec -MaxSamples 1
    $rows = @{}

    foreach($sample in $samples.CounterSamples) {
        $instance = [string]$sample.InstanceName
        if(-not $rows.ContainsKey($instance)) {
            $rows[$instance] = [ordered]@{
                instanceName = $instance
                pid = 0
                totalBps = 0.0
            }
        }

        if($sample.Path -like '*\ID procesu') {
            $rows[$instance].pid = [int]$sample.CookedValue
        } elseif($sample.Path -like '*Bajty vstup*' -and $sample.Path -like '*dat*' -and $sample.Path -like '*/s') {
            $rows[$instance].totalBps = [double]$sample.CookedValue
        }
    }

    $output = New-Object System.Collections.Generic.List[object]
    foreach($name in $rows.Keys) {
        $r = $rows[$name]
        if($r.pid -le 0) { continue }

        $totalBps = $r.totalBps
        if($totalBps -le 0) { continue }

        $meta = $CmdMap[$r.pid]
        $procName = if($null -ne $meta -and -not [string]::IsNullOrWhiteSpace($meta.processName)) { $meta.processName } else { $r.instanceName }
        $exe = if($null -ne $meta) { [string]$meta.executablePath } else { '' }
        $cmd = if($null -ne $meta) { [string]$meta.commandLine } else { '' }

        $output.Add([ordered]@{
            pid = $r.pid
            processName = $procName
            readMBps = 0
            writeMBps = 0
            totalMBps = [math]::Round($totalBps / 1MB, 4)
            executablePath = $exe
            commandLine = $cmd
        }) | Out-Null
    }

    return $output.ToArray()
}

if(-not (Test-Path -Path $CsvPath)) {
    'Timestamp,PID,ProcessName,ReadMBps,WriteMBps,TotalMBps,ExecutablePath,CommandLine' | Set-Content -Path $CsvPath -Encoding UTF8
}

$paths = Get-ProcessCounterPaths
$sampleIndex = 0

while($true) {
    $sampleIndex++
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

    $cmdMap = Get-ProcessCommandLineMap
    $rows = Get-ProcessIoRows -PidPath $paths.pidPath -DataPath $paths.dataPath -CmdMap $cmdMap |
        Sort-Object totalMBps -Descending |
        Select-Object -First $TopN

    foreach($p in $rows) {
        $csvLine = '"{0}",{1},"{2}",{3},{4},{5},"{6}","{7}"' -f $timestamp,
            $p.pid,
            ($p.processName -replace '"','""'),
            $p.readMBps,
            $p.writeMBps,
            $p.totalMBps,
            (($p.executablePath) -replace '"','""'),
            (($p.commandLine) -replace '"','""')

        Add-Content -Path $CsvPath -Value $csvLine -Encoding UTF8

        $obj = [ordered]@{
            timestamp = $timestamp
            pid = $p.pid
            processName = $p.processName
            readMBps = $p.readMBps
            writeMBps = $p.writeMBps
            totalMBps = $p.totalMBps
            executablePath = $p.executablePath
            commandLine = $p.commandLine
        }
        Add-Content -Path $JsonlPath -Value ($obj | ConvertTo-Json -Compress) -Encoding UTF8
    }

    Write-Output ("[{0}] sample {1}: counter set '{2}', captured {3} rows" -f $timestamp, $sampleIndex, $paths.counterSetName, @($rows).Count)

    if($MaxSamples -gt 0 -and $sampleIndex -ge $MaxSamples) {
        break
    }
}
