function Get-InvokeWebRequestCompatibilityParameters {
    $params = @{}
    $command = Get-Command Invoke-WebRequest -ErrorAction SilentlyContinue
    if($null -ne $command -and $command.Parameters.ContainsKey('UseBasicParsing')) {
        $params['UseBasicParsing'] = $true
    }

    return $params
}