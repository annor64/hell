$ErrorActionPreference = 'Stop'
$env:BW_SESSION = '+ZlzpE2hKVgzv+nGXRJ2PvUWsvVqP9Aq9GpQ218VUFWEETuq4kdNV8jh5QdXsmYZHinBAKBNSWUKRgL/cV664A=='
& .\scripts\bitwarden_portainer_secret_sync.ps1 -Mode pull -ItemName portainer-deploy-secrets
