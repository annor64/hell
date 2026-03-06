# SQL Workspace

Centrální rozcestník pro aktuální strukturu repozitáře po reorganizaci.

## Struktura

### CEZ
- [CEZ/SQL](CEZ/SQL) — SQL domény pro ČEZ (ATACAMA, ADAPTACE, CX01, FA06, FLEXI, Obecne, SCALER)
- [CEZ/GROOVY](CEZ/GROOVY) — Groovy automatizace
- [CEZ/CONVERTY](CEZ/CONVERTY) — konverzní skripty
- [CEZ/GENERATOR_DLL](CEZ/GENERATOR_DLL) — generátor DLL a související skripty
- [CEZ/PREVOD_KOMENTARU](CEZ/PREVOD_KOMENTARU) — převody komentářů

## Dokumentace a znalosti
- [ZNALOSTI.md](ZNALOSTI.md) — centrální knowledge base a rozhodnutí
- [ARCHITEKTURA_DEPLOYMENT_FACTORY.md](ARCHITEKTURA_DEPLOYMENT_FACTORY.md) — cílová architektura automatizace deployů (Proxmox/Portainer/HELL)
- [gitops/README.md](gitops/README.md) — GitOps katalog stacků, secrets template a deploy workflow
- [SETUP-LOG.md](SETUP-LOG.md) — dnešní setup/chat log (Docker/Portainer)
- [RENAMES_2026-03-02.md](RENAMES_2026-03-02.md) — mapa přejmenování (old → new)
- [CT105_RUNBOOK.md](CT105_RUNBOOK.md) — finální provozní runbook (Citrix/RDP/noVNC)

## GitOps deploy (Portainer)
- Stack manifesty: [gitops/stacks](gitops/stacks)
- Lokální secrets template: [gitops/secrets/portainer.env.template](gitops/secrets/portainer.env.template)
- Deploy skript: [scripts/deploy_portainer_stack.ps1](scripts/deploy_portainer_stack.ps1)
- CI workflow: [.github/workflows/gitops-portainer.yml](.github/workflows/gitops-portainer.yml)

## CT105 nástroje
- [ct105_tools](ct105_tools) — kurátorovaný set skriptů pro správu a diagnostiku CT105


## Údržba a archivace

Pravidelně kontroluj složky podle README v kika-solutions a přesouvej staré nebo nepotřebné soubory do _archive. Každý přesun commmitni s popisem.

## Poznámka
- Nové materiály pro ČEZ ukládat primárně pod [CEZ](CEZ).
