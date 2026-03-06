# Preflight Report

Datum: 2026-03-03 20:52:15
Operator: jkika
Repo revision: f2bf5ca

## 1) Kontext deploye
- Stack name: homeassistant
- Stack file: .\gitops\stacks\homeassistant\compose.yml
- Endpoint ID: 3
- Expected endpoint name: local
- Expected docker host: hell

## 2) Guard checks
- Endpoint ID match: PASS
- Endpoint name match: FAIL
- Docker host match: FAIL
- Secrets loaded (API_KEY/fallback): PASS

## 3) Artefakty a validace
- Compose syntactic check: PASS
- Required files present: PASS
- Target paths from architecture mapping: PASS

## 4) Rizika pĹ™ed nasazenĂ­m
- Open blockers:
  - Nadřízené připojení bylo uzavřeno: Došlo k neočekávané chybě při odeslání.
- Known warnings:
  - deploy ended with error

## 5) RozhodnutĂ­
- Deploy approved: NO
- Fallback prepared (SSH on HELL): NO
- Rollback plan reference: ARCHITEKTURA_DEPLOYMENT_FACTORY.md

## 6) Post-run odkazy
- Deploy result: `gitops/deploy-result.json`
- Runtime status: `portainer_update_result.json`
- Optional logs: `ha_deploy_result.json`
- Containers detected for stack: 0

