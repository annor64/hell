# Secrets (lokální)

Tato složka je určená pro lokální runtime secrets a environment hodnoty.

## Pravidla
- Do Gitu commituj pouze `*.template` soubory.
- Reálné `*.env` soubory jsou ignorované v `.gitignore`.
- Preferuj service API key před user/password.

## Minimum pro Portainer deploy
- `PORTAINER_BASE_URL`
- `PORTAINER_ENDPOINT_ID`
- `PORTAINER_API_KEY`

## Guard cílového node (doporučeno)
- `PORTAINER_EXPECTED_ENDPOINT_ID` (default `3`)
- `PORTAINER_EXPECTED_ENDPOINT_NAME` (default `local`)
- `PORTAINER_EXPECTED_DOCKER_NAME` (default `hell`)

## Bitwarden integrace
- Pro práci s Bitwarden CLI nastav `BW_SESSION` (`bw unlock --raw`).
- Načtení z Bitwardenu do `.env`:
	- `powershell -ExecutionPolicy Bypass -File .\scripts\bitwarden_portainer_secret_sync.ps1 -Mode pull -ItemName portainer-deploy-secrets`
- Zápis `.env` do Bitwardenu:
	- `powershell -ExecutionPolicy Bypass -File .\scripts\bitwarden_portainer_secret_sync.ps1 -Mode push -ItemName portainer-deploy-secrets`
