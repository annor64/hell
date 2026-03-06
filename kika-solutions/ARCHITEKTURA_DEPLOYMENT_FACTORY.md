# Architektura Deployment Factory (Proxmox + Portainer + HELL)

Datum: 2026-03-03

## 1) Cíl
- Nasazovat Docker stacky opakovaně, auditovatelně a bez ručního klikání.
- Umožnit rychlé create/update/rollback pro více služeb (MVP: Home Assistant).

## 2) Role prostředí
- Node HELL: Docker/Portainer runtime (ověřený deploy target přes endpoint `local`).
- CT100: Cloudflare tunnel runtime (ne deploy target pro stacky).
- CT105: uživatelská pracovní stanice (Citrix/RDP/noVNC), není deploy target.
- Proxmox host: infrastruktura a SSH vstupní bod.

## 3) Řídicí vrstvy
- Portainer API (primární orchestrace):
  - login přes service API key,
  - create/update stack,
  - runtime verifikace kontejnerů.
- SSH na node HELL (fallback):
  - deploy přes docker compose,
  - nouzové zásahy při API problému.

## 4) Deployment Factory workflow
1. Načti stack manifest (compose + env).
2. Validuj syntaxi a povinné proměnné.
3. Proveď create-or-update v Portainer API.
4. Polling health-check (container state, restart count, service endpoint).
5. Zapiš audit log (čas, stack, verze, endpoint, výsledek).
6. Při chybě proveď rollback na poslední známou stabilní verzi.

## 5) Doménový tunel (CT100 -> veřejná doména)
### Doporučený model
- CT100 běží jako Cloudflare tunnel ingress vrstva.
- Reverzní proxy na node HELL (např. Traefik/Nginx) + TLS terminace.
- DNS záznam domény směruje na veřejný vstupní bod.
- Tunel/edge vrstva dle dostupnosti sítě:
  - varianta A: veřejná IP + NAT/port-forward + firewall allow-list,
  - varianta B: managed tunnel (bez otevření inbound portů).

### Princip routingu
- domena.tld -> Cloudflare tunnel (CT100) -> reverse proxy -> service na HELL.
- Interní služby zůstávají v Docker network, veřejně vystavovat jen potřebné endpointy.

## 6) Bezpečnostní zásady
- Nepoužívat osobní account pro automatizaci; používat service account/API key.
- Secrets držet mimo repo (secret store, env injection při deployi).
- Pro SSH používat klíče, zakázat password login kde je možné.
- Auditovat deploy akce a uchovávat poslední známý stabilní release.

## 7) Observability minimum
- Status: running/degraded/failed per stack.
- Základní metriky: počet restartů, poslední deploy čas, poslední chyba.
- Log bundle pro incident: Portainer API response + container logs + runner log.

## 8) MVP implementace (doporučení)
- Katalog stacků:
  - gitops/stacks/homeassistant/compose.yml
  - gitops/secrets/portainer.env.template
- Runner skript:
  - scripts/deploy_portainer_stack.ps1 (create/update/verify/rollback)
  - scripts/bitwarden_portainer_secret_sync.ps1 (volitelný pull/push secrets)
- Audit:
  - gitops/deploy-result.json
  - portainer_disk_monitor.jsonl
- Runbook:
  - incident playbook (API down / endpoint offline / rollback)

## 9) Otevřené body
- Potvrdit stabilní SSH identity na node HELL pro fallback deploy.
- Potvrdit finální variantu doménového tunelu (A/B).
- Potvrdit místo pro centralizovaný secret store.

## 10) Mapování architektura -> repozitář
- Orchestrace a CI:
  - `.github/workflows/gitops-portainer.yml`
  - `scripts/deploy_portainer_stack.ps1`
- Katalog stacků:
  - `gitops/stacks/`
- Secrets šablony a dokumentace:
  - `gitops/secrets/portainer.env.template`
  - `gitops/secrets/README.md`
- Stav a výsledky běhů:
  - `gitops/deploy-result.json`
  - `ha_deploy_result.json`
  - `portainer_update_result.json`
