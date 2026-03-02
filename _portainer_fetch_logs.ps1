$ErrorActionPreference='Stop'
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
. "$PSScriptRoot\_invoke_webrequest_compat.ps1"

$base='https://192.168.0.135:9443'
$endpointId=3
$username='annor'
$password='artanox2912@'
$outFile='C:\Users\jkika\SQL\portainer_container_logs.json'
$tailLines=120
$maxLogCharsPerContainer=12000

function Convert-BytesToDockerLogsText {
    param([byte[]]$Bytes)

    if(-not $Bytes -or $Bytes.Length -eq 0){ return '' }

    $utf8 = [System.Text.Encoding]::UTF8
    $sb = New-Object System.Text.StringBuilder
    $i = 0

    while(($i + 8) -le $Bytes.Length) {
        $streamType = $Bytes[$i]
        $size = ([int]$Bytes[$i+4] -shl 24) -bor ([int]$Bytes[$i+5] -shl 16) -bor ([int]$Bytes[$i+6] -shl 8) -bor [int]$Bytes[$i+7]

        if($size -lt 0){ break }

        $payloadStart = $i + 8
        $payloadEnd = $payloadStart + $size
        if($payloadEnd -gt $Bytes.Length){ break }

        if($streamType -in 1,2,3) {
            $chunk = $utf8.GetString($Bytes, $payloadStart, $size)
            [void]$sb.Append($chunk)
        } else {
            $fallback = $utf8.GetString($Bytes)
            return $fallback
        }

        $i = $payloadEnd
    }

    if($sb.Length -eq 0){
        return $utf8.GetString($Bytes)
    }

    return $sb.ToString()
}

function Normalize-LogText {
    param(
        [string]$Text,
        [int]$MaxChars
    )

    if([string]::IsNullOrEmpty($Text)){ return '' }

    $clean = $Text -replace "`0", ''
    $clean = $clean -replace "\x1B\[[0-9;]*[A-Za-z]", ''
    $clean = $clean -replace "[\x00-\x08\x0B\x0C\x0E-\x1F]", ''

    if($clean.Length -gt $MaxChars) {
        $clean = $clean.Substring($clean.Length - $MaxChars)
    }

    return $clean
}

$result=[ordered]@{}

try {
    $auth=Invoke-RestMethod -Method Post -Uri "$base/api/auth" -ContentType 'application/json' -Body (@{username=$username;password=$password}|ConvertTo-Json) -TimeoutSec 30
    $headers=@{ Authorization = "Bearer $($auth.jwt)" }
    $iwrExtraParams = Get-InvokeWebRequestCompatibilityParameters

    $containers=Invoke-RestMethod -Method Get -Uri "$base/api/endpoints/$endpointId/docker/containers/json?all=1" -Headers $headers -TimeoutSec 30
    foreach($name in @('code-server','smart-db','wiki')) {
        $c=$containers | Where-Object { $_.Names -contains "/$name" } | Select-Object -First 1
        if($c){
            try {
                $logUrl = "$base/api/endpoints/$endpointId/docker/containers/$($c.Id)/logs?stdout=1&stderr=1&tail=$tailLines"
                $response = Invoke-WebRequest -Method Get -Uri $logUrl -Headers $headers -TimeoutSec 30 @iwrExtraParams

                $stream = $response.RawContentStream
                $memoryStream = New-Object System.IO.MemoryStream
                $stream.CopyTo($memoryStream)
                $bytes = $memoryStream.ToArray()

                $decodedLogs = Convert-BytesToDockerLogsText -Bytes $bytes
                $safeLogs = Normalize-LogText -Text $decodedLogs -MaxChars $maxLogCharsPerContainer

                $result[$name] = [ordered]@{ id=$c.Id; state=$c.State; status=$c.Status; logs=$safeLogs; truncated=($decodedLogs.Length -gt $safeLogs.Length) }
            } catch {
                $result[$name] = [ordered]@{ id=$c.Id; state=$c.State; status=$c.Status; logs="ERROR: $($_.Exception.Message)" }
            }
        } else {
            $result[$name] = [ordered]@{ id=''; state='not-found'; status='not-found'; logs='' }
        }
    }
}
catch {
    $result['error'] = $_.Exception.Message
}

$json = $result | ConvertTo-Json -Depth 10
Set-Content -Path $outFile -Value $json -Encoding UTF8
$summary = [ordered]@{
    ok = (-not $result.Contains('error'))
    outputFile = $outFile
    containers = @('code-server','smart-db','wiki')
    maxCharsPerContainer = $maxLogCharsPerContainer
    tailLines = $tailLines
}
Write-Output ($summary | ConvertTo-Json -Depth 4)
