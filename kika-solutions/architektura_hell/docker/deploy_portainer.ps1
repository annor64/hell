# 6. Výpis stavu kontejnerů a logu Portaineru
Write-Host "\n--- docker ps -a ---"
$psa = Invoke-SSHCommand -SSHSession $sshSession -Command "docker ps -a"
$psa.Output | ForEach-Object { Write-Host $_ }

Write-Host "\n--- docker logs portainer ---"
$logs = Invoke-SSHCommand -SSHSession $sshSession -Command "docker logs portainer 2>&1"
$logs.Output | ForEach-Object { Write-Host $_ }
# Automatizovaná instalace Dockeru a Portaineru na Proxmox (Debian 13) přes SSH
# Vyžaduje modul Posh-SSH a heslo k root účtu

# 1. Nastavení přihlašovacích údajů
$HostIP = "192.168.0.135"
$PasswordPlain = "mX8zS-A-xVCsOdBe9t7ZdhfCGxquEEFF"  # Z Bitwardenu
$Password = ConvertTo-SecureString $PasswordPlain -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential ("root", $Password)

# 2. Navázání SSH session
$sshSession = New-SSHSession -ComputerName $HostIP -Credential $Cred

# 3. Kontrola a instalace Dockeru
$dockerCheck = Invoke-SSHCommand -SSHSession $sshSession -Command "which docker"
if (-not $dockerCheck.Output) {
    Write-Host "Docker není nainstalován, instaluji..."
    $installDockerScript = @'
set -e
apt-get update
apt-get install -y docker.io | tee /tmp/docker_install.log
cat /tmp/docker_install.log
'@
    $result = Invoke-SSHCommand -SSHSession $sshSession -Command $installDockerScript
    Write-Host "Výstup z instalace Dockeru:"
    $result.Output | ForEach-Object { Write-Host $_ }
} else {
    Write-Host "Docker je již nainstalován."
}



# 4. Automatizovaná diagnostika a spuštění Portaineru
$portainerCheck = Invoke-SSHCommand -SSHSession $sshSession -Command "docker ps --filter 'name=portainer' --format '{{.Names}}'"
if ($portainerCheck.Output) {
    Write-Host "Odstraňuji starý Portainer kontejner..."
    Invoke-SSHCommand -SSHSession $sshSession -Command "docker stop portainer || true"
    Invoke-SSHCommand -SSHSession $sshSession -Command "docker rm portainer || true"
}
Write-Host "Spouštím Portainer kontejner s --user root..."
Invoke-SSHCommand -SSHSession $sshSession -Command "docker volume create portainer_data"
$runResult = Invoke-SSHCommand -SSHSession $sshSession -Command "docker run -d --user root -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest"
if ($runResult.ExitStatus -ne 0) {
    Write-Host "Spuštění s --user root selhalo, zkouším bez --user..."
    Invoke-SSHCommand -SSHSession $sshSession -Command "docker rm portainer || true"
    $runResult2 = Invoke-SSHCommand -SSHSession $sshSession -Command "docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest"
    if ($runResult2.ExitStatus -ne 0) {
        Write-Host "Spuštění Portaineru selhalo i bez --user root."
    } else {
        Write-Host "Portainer úspěšně spuštěn bez --user root."
    }
} else {
    Write-Host "Portainer úspěšně spuštěn s --user root."
}

# 5. Ověření běhu Portaineru a výpis logu
Write-Host "\n--- docker ps -a ---"
$psa = Invoke-SSHCommand -SSHSession $sshSession -Command "docker ps -a"
$psa.Output | ForEach-Object { Write-Host $_ }

Write-Host "\n--- docker logs portainer ---"
$logs = Invoke-SSHCommand -SSHSession $sshSession -Command "docker logs portainer 2>&1"
$logs.Output | ForEach-Object { Write-Host $_ }

# 5. Ověření běhu Portaineru
Invoke-SSHCommand -SSHSession $sshSession -Command "docker ps | grep portainer"

# 6. Ukončení SSH session
Remove-SSHSession -SSHSession $sshSession
