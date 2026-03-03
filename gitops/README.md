# GitOps deployment katalog

Tato složka obsahuje deklarativní stack manifesty a provozní šablony pro automatizovaný deploy.

## Struktura
- `stacks/<stack>/compose.yml` — stack compose manifest
- `secrets/` — lokální secrets šablony (reálné hodnoty necommitovat)

## Rychlé použití (lokálně)
1. Vytvoř lokální secrets soubor z template:
   - `Copy-Item .\gitops\secrets\portainer.env.template .\gitops\secrets\portainer.env`
2. Doplň hodnoty v `gitops/secrets/portainer.env`.
3. Spusť deploy:
   - `powershell -ExecutionPolicy Bypass -File .\scripts\deploy_portainer_stack.ps1 -StackName homeassistant -StackFile .\gitops\stacks\homeassistant\compose.yml -EnvFile .\gitops\secrets\portainer.env`

## Target guard (doporučeno)
- Deploy skript před nasazením kontroluje cílový endpoint i docker host.
- Výchozí očekávání je `endpointId=3`, `endpointName=local`, `dockerName=hell`.
- Hodnoty lze řídit přes:
   - `PORTAINER_EXPECTED_ENDPOINT_ID`
   - `PORTAINER_EXPECTED_ENDPOINT_NAME`
   - `PORTAINER_EXPECTED_DOCKER_NAME`

## CI/CD
- Workflow je v `.github/workflows/gitops-portainer.yml`.
- Dokumentační konzistence kontroluje `.github/workflows/docs-check.yml`.
- Pro deploy použij repository secrets:
  - `PORTAINER_API_KEY`
  - `PORTAINER_BASE_URL`
  - `PORTAINER_ENDPOINT_ID`

## Preflight report
- Před produkčním během vyplň šablonu: `gitops/preflight-report.template.md`.
- Minimální cíl: mít explicitně potvrzené guard checky (`endpointId/name/docker host`) a fallback/rollback připravenost.

## Bitwarden (čtení i zápis)
- Podporováno přes `bw` CLI a `BW_SESSION`.
- Sync skript:
   - `powershell -ExecutionPolicy Bypass -File .\scripts\bitwarden_portainer_secret_sync.ps1 -Mode pull -ItemName portainer-deploy-secrets`
   - `powershell -ExecutionPolicy Bypass -File .\scripts\bitwarden_portainer_secret_sync.ps1 -Mode push -ItemName portainer-deploy-secrets`
- Deploy skript umí načítat z Bitwardenu fallbackem přes:
   - `BW_ITEM_ID` nebo `BW_ITEM_NAME`
   - `BW_SESSION`
