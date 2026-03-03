# Preflight Report Template

Datum: YYYY-MM-DD HH:MM:SS
Operator: <name>
Repo revision: <commit/branch>

## 1) Kontext deploye
- Stack name: <stack>
- Stack file: <path>
- Endpoint ID: <id>
- Expected endpoint name: <name>
- Expected docker host: <name>

## 2) Guard checks
- Endpoint ID match: PASS/FAIL
- Endpoint name match: PASS/FAIL
- Docker host match: PASS/FAIL
- Secrets loaded (`API_KEY`/fallback): PASS/FAIL

## 3) Artefakty a validace
- Compose syntactic check: PASS/FAIL
- Required files present: PASS/FAIL
- Target paths from architecture mapping: PASS/FAIL

## 4) Rizika před nasazením
- Open blockers:
  - <none | popis>
- Known warnings:
  - <none | popis>

## 5) Rozhodnutí
- Deploy approved: YES/NO
- Fallback prepared (SSH on HELL): YES/NO
- Rollback plan reference: <link/path>

## 6) Post-run odkazy
- Deploy result: `gitops/deploy-result.json`
- Runtime status: `portainer_update_result.json`
- Optional logs: `ha_deploy_result.json`
