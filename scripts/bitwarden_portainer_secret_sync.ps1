param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('pull','push')]
    [string]$Mode,

    [Parameter(Mandatory = $false)]
    [string]$EnvFile = '.\gitops\secrets\portainer.env',

    [Parameter(Mandatory = $false)]
    [string]$ItemId = '',

    [Parameter(Mandatory = $false)]
    [string]$ItemName = 'portainer-deploy-secrets'
)

$ErrorActionPreference = 'Stop'

function Resolve-BwExePath {
    $cmd = Get-Command bw -ErrorAction SilentlyContinue
    if($null -ne $cmd -and -not [string]::IsNullOrWhiteSpace([string]$cmd.Source)) {
        return [string]$cmd.Source
    }

    $envPath = [Environment]::GetEnvironmentVariable('BW_EXE_PATH', 'Process')
    if(-not [string]::IsNullOrWhiteSpace($envPath) -and (Test-Path -LiteralPath $envPath)) {
        return $envPath
    }

    $candidate = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\Bitwarden.CLI_Microsoft.Winget.Source_8wekyb3d8bbwe\bw.exe'
    if(Test-Path -LiteralPath $candidate) {
        return $candidate
    }

    return ''
}

$script:BwExe = ''

function Require-Bw {
    $script:BwExe = Resolve-BwExePath
    if([string]::IsNullOrWhiteSpace($script:BwExe)) {
        throw 'Bitwarden CLI not found. Install Bitwarden.CLI or set BW_EXE_PATH to bw.exe.'
    }
}

function Invoke-Bw {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Args
    )

    return (& $script:BwExe @Args)
}

function Require-BwSession {
    $session = [Environment]::GetEnvironmentVariable('BW_SESSION', 'Process')
    if([string]::IsNullOrWhiteSpace($session)) {
        throw 'Missing BW_SESSION. Run: bw unlock --raw and set BW_SESSION first.'
    }
    return $session
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

function Save-DotEnv {
    param(
        [string]$Path,
        [hashtable]$Map
    )

    $keys = @($Map.Keys | Sort-Object)
    $lines = @()
    foreach($k in $keys) {
        $v = [string]$Map[$k]
        $lines += "$k=$v"
    }

    $dir = Split-Path -Path $Path -Parent
    if(-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    Set-Content -Path $Path -Value ($lines -join "`r`n") -Encoding UTF8
}

function Get-BwItem {
    param(
        [string]$Session,
        [string]$ItemId,
        [string]$ItemName
    )

    if(-not [string]::IsNullOrWhiteSpace($ItemId)) {
        return (Invoke-Bw -Args @('get','item',$ItemId,'--session',$Session) | ConvertFrom-Json)
    }

    $items = (Invoke-Bw -Args @('list','items','--search',$ItemName,'--session',$Session) | ConvertFrom-Json)
    $exact = @($items | Where-Object { $_.name -eq $ItemName } | Select-Object -First 1)
    if($exact.Count -gt 0) {
        return (Invoke-Bw -Args @('get','item',[string]$exact[0].id,'--session',$Session) | ConvertFrom-Json)
    }

    $first = @($items | Select-Object -First 1)
    if($first.Count -gt 0) {
        return (Invoke-Bw -Args @('get','item',[string]$first[0].id,'--session',$Session) | ConvertFrom-Json)
    }

    return $null
}

function Get-FieldMap {
    param($Item)

    $map = @{}
    if($null -eq $Item) { return $map }
    if($Item.PSObject.Properties.Name -contains 'fields' -and $null -ne $Item.fields) {
        foreach($f in $Item.fields) {
            if($null -eq $f) { continue }
            $name = [string]$f.name
            $value = [string]$f.value
            if(-not [string]::IsNullOrWhiteSpace($name)) {
                $map[$name] = $value
            }
        }
    }
    return $map
}

function New-CustomField {
    param([string]$Name,[string]$Value)
    return [ordered]@{
        name = $Name
        value = $Value
        type = 0
    }
}

Require-Bw
$session = Require-BwSession

$allowedKeys = @(
    'PORTAINER_BASE_URL',
    'PORTAINER_ENDPOINT_ID',
    'PORTAINER_API_KEY',
    'PORTAINER_USERNAME',
    'PORTAINER_PASSWORD',
    'PORTAINER_EXPECTED_ENDPOINT_ID',
    'PORTAINER_EXPECTED_ENDPOINT_NAME',
    'PORTAINER_EXPECTED_DOCKER_NAME'
)

if($Mode -eq 'pull') {
    $item = Get-BwItem -Session $session -ItemId $ItemId -ItemName $ItemName
    if($null -eq $item) { throw "Bitwarden item not found: $ItemName" }

    $map = Load-DotEnv -Path $EnvFile
    $fields = Get-FieldMap -Item $item

    foreach($k in $allowedKeys) {
        if($fields.ContainsKey($k) -and -not [string]::IsNullOrWhiteSpace([string]$fields[$k])) {
            $map[$k] = [string]$fields[$k]
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
            $u = @($item.login.uris | Select-Object -First 1)
            if($u.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$u[0].uri) -and -not $map.ContainsKey('PORTAINER_BASE_URL')) {
                $map['PORTAINER_BASE_URL'] = [string]$u[0].uri
            }
        }
    }

    Save-DotEnv -Path $EnvFile -Map $map
    Write-Output "Pulled Bitwarden item '$($item.name)' into $EnvFile"
    exit 0
}

if($Mode -eq 'push') {
    $map = Load-DotEnv -Path $EnvFile
    if($map.Count -eq 0) { throw "Env file is empty or missing: $EnvFile" }

    $item = Get-BwItem -Session $session -ItemId $ItemId -ItemName $ItemName

    if($null -eq $item) {
        $fields = @()
        foreach($k in $allowedKeys) {
            if($map.ContainsKey($k) -and -not [string]::IsNullOrWhiteSpace([string]$map[$k])) {
                $fields += (New-CustomField -Name $k -Value ([string]$map[$k]))
            }
        }

        $newItem = [ordered]@{
            type = 1
            name = $ItemName
            login = [ordered]@{
                username = if($map.ContainsKey('PORTAINER_USERNAME')) { [string]$map['PORTAINER_USERNAME'] } else { '' }
                password = if($map.ContainsKey('PORTAINER_PASSWORD')) { [string]$map['PORTAINER_PASSWORD'] } elseif($map.ContainsKey('PORTAINER_API_KEY')) { [string]$map['PORTAINER_API_KEY'] } else { '' }
                uris = @(
                    [ordered]@{ uri = if($map.ContainsKey('PORTAINER_BASE_URL')) { [string]$map['PORTAINER_BASE_URL'] } else { '' } }
                )
            }
            fields = $fields
            notes = 'Managed by scripts/bitwarden_portainer_secret_sync.ps1'
        }

        $encoded = ($newItem | ConvertTo-Json -Depth 20 -Compress | Invoke-Bw -Args @('encode'))
        $created = (Invoke-Bw -Args @('create','item',$encoded,'--session',$session) | ConvertFrom-Json)
        Write-Output "Created Bitwarden item '$($created.name)' ($($created.id))"
        exit 0
    }

    $fieldMap = Get-FieldMap -Item $item
    foreach($k in $allowedKeys) {
        if($map.ContainsKey($k) -and -not [string]::IsNullOrWhiteSpace([string]$map[$k])) {
            $fieldMap[$k] = [string]$map[$k]
        }
    }

    $fieldsOut = @()
    foreach($k in ($fieldMap.Keys | Sort-Object)) {
        $fieldsOut += (New-CustomField -Name $k -Value ([string]$fieldMap[$k]))
    }

    if($null -eq $item.login) {
        $item | Add-Member -NotePropertyName login -NotePropertyValue ([ordered]@{})
    }

    $item.login.username = if($map.ContainsKey('PORTAINER_USERNAME')) { [string]$map['PORTAINER_USERNAME'] } else { [string]$item.login.username }
    $item.login.password = if($map.ContainsKey('PORTAINER_PASSWORD')) { [string]$map['PORTAINER_PASSWORD'] } elseif($map.ContainsKey('PORTAINER_API_KEY')) { [string]$map['PORTAINER_API_KEY'] } else { [string]$item.login.password }

    if($null -eq $item.login.uris -or @($item.login.uris).Count -eq 0) {
        $item.login.uris = @([ordered]@{ uri = '' })
    }
    if($map.ContainsKey('PORTAINER_BASE_URL')) {
        $item.login.uris[0].uri = [string]$map['PORTAINER_BASE_URL']
    }

    $item.fields = $fieldsOut

    $encoded = ($item | ConvertTo-Json -Depth 30 -Compress | Invoke-Bw -Args @('encode'))
    $updated = (Invoke-Bw -Args @('edit','item',[string]$item.id,$encoded,'--session',$session) | ConvertFrom-Json)
    Write-Output "Updated Bitwarden item '$($updated.name)' ($($updated.id))"
    exit 0
}
