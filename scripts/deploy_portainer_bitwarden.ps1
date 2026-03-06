# Automatizované nasazení Portaineru na Proxmox s heslem z Bitwardenu
# Vyžaduje Bitwarden CLI (bw) a SSH klient

# Přihlášení do Bitwardenu (pokud není aktivní session)
$bwSession = bw unlock --raw

# Načtení hesla pro root@192.168.0.135
$bwItem = bw get item proxmox-root --session $bwSession | ConvertFrom-Json
$proxmoxPass = $bwItem.login.password

# SSH příkaz pro instalaci Dockeru
$installDocker = 'curl -fsSL https://get.docker.com | sh'

# SSH příkaz pro nasazení Portaineru
$runPortainer = 'docker volume create portainer_data && docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest'

# Spuštění instalace Dockeru
sshpass -p $proxmoxPass ssh -o StrictHostKeyChecking=no root@192.168.0.135 "$installDocker"

# Spuštění Portaineru
sshpass -p $proxmoxPass ssh -o StrictHostKeyChecking=no root@192.168.0.135 "$runPortainer"

# Ověření běhu Portaineru
sshpass -p $proxmoxPass ssh -o StrictHostKeyChecking=no root@192.168.0.135 "docker ps | grep portainer"

Write-Host "Hotovo! Portainer by měl běžet na https://192.168.0.135:9443"