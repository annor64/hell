# Smart Workspace Setup - Deník dnešního dne 📝

**Datum:** 2026-03-02 14:39:22  
**Uživatel:** annor64

---

## 🎯 Cíl

Vytvořit Docker setup s:
- **Code Server** (VS Code v prohlížeči)
- **PostgreSQL 15** (Database)
- **Wiki.js** (Dokumentace)
- **GitHub Copilot** (AI asistent)

---

## 📋 Kroky a Problémy

### 1️⃣ První pokus - docker-compose.yml s PostgreSQL

**Problém:**
```
Failure
Failed to deploy a stack:
failed to create compose project: failed to load the compose file : 
service "smart-workspace" refers to undefined volume workspace_new_data: 
invalid compose project
```

**Řešení:**
- Změnil jsem `workspace_new_data` → `workspace_data`
- Změnil jsem `db-data` → `db_data`
- Změnil jsem `wiki-data` → `wiki_data`

✅ **Výsledek:** Stack běží!

---

### 2️⃣ PostgreSQL Socket Error

**Problém:**
```
FATAL: could not create any Unix-domain sockets
could not create Unix socket for address "/var/run/postgresql/.s.PGSQL.5432": Permission denied
```

**Řešení:**
- Změnil jsem `postgres:15-alpine` → `postgres:15`
- Alpine image měl problémy s permissions
- Plný Debian-based image PostgreSQL funguje lépe

✅ **Výsledek:** PostgreSQL běží!

---

### 3️⃣ Hesla aktualizace

**Problém:**
- V YAML bylo `tvoje_tajne_heslo_123` - nejednotné

**Řešení:**
- Všechna hesla změněna na: `artanox2912`
- Version aktualizován: `3.8` → `3.9`

✅ **Výsledek:** Jednotné heslo všude

---

### 4️⃣ Výběr IDE - Diskuse

**Otázka:** Jaké IDE je nejlepší?

**Varianty:**
1. **Code Server** (VS Code v prohlížeči) - ✅ VYBRÁN
   - Lightweight (~500MB)
   - Perfektní pro web
   - GitHub Copilot support
   
2. **JetBrains IntelliJ Community** 
   - Placené vs Community Edition
   - Community = zdarma s omezeními
   - PROBLÉM: Image neexistuje na Docker Hubu
   
3. **Gitpod** (VS Code + Docker + Tools)
   - Těžký (~3-4GB)
   - Mocný pro backend
   - Zbytečný pro web-only

4. **Apache Guacamole** (Desktop v prohlížeči)
   - Linux desktop v prohlížeči
   - Zbytečný pro coding

---

### 5️⃣ JetBrains vysvětlení

**Placené IDE:**
- Vyžadují licenci (~$100-200/rok)
- Plné funkčnosti

**Community Edition:**
- ✅ ZDARMA
- ❌ Omezené funkčnosti
- Ideální pro osobní projekt

---

### 6️⃣ Gitpod vs Desktop vysvětlení

**Gitpod:**
```
= VS Code + Docker + Nástroje
- VS Code v prohlížeči
- Docker zabudovaný
- Node.js, Python, Java - vše tam
- Ideální pro full-stack
- Těžký: 3-4GB
```

**Desktop (Guacamole):**
```
= Linux Desktop v prohlížeči
- Grafické prostředí (Ubuntu)
- Můžeš instalovat GUI aplikace
- Jako vzdálená plocha
- Zbytečný pro coding
```

---

### 7️⃣ Chyba - GitHub Copilot Chat extension

**Problém:**
```
An error occurred while setting up chat. Would you like to try again?

The extension 'GitHub.copilot-chat' cannot be installed because it was not found.
```

**Řešení:**
- Odebral jsem `GitHub.copilot-chat` z EXTENSIONS
- Ponechal jsem `GitHub.copilot` (funguje)
- Odstranil jsem: `ms-vscode.vscode-typescript-next`

```yaml
EXTENSIONS=GitHub.copilot,esbenp.prettier-vscode,dbaeumer.vscode-eslint,bradlc.vscode-tailwindcss,ritwickdey.liveserver
```

✅ **Výsledek:** Copilot funguje!

---

### 8️⃣ Chyba - JetBrains image neexistuje v Portainer

**Problém:**
```
Failure
Failed to deploy a stack:
compose up operation failed:
Error response from daemon: pull access denied for 
jetbrains/intellij-idea-community, repository does not exist
```

**Řešení:**
- JetBrains nechce svůj image na Docker Hubu
- Zůstal jsem na Code Server (nejlepší volba)
- Jednodušší a lightweight

✅ **Výsledek:** Code Server + PostgreSQL + Wiki.js

---

### 9️⃣ Portainer konfigurace

**Postup:**
1. Portainer → Stacks → Add stack
2. Stack name: `smart-workspace`
3. Vlož YAML
4. Deploy the stack

**Přihlášení:**
- Code Server: https://localhost:8080 (heslo: `artanox2912`)
- Wiki.js: http://localhost:3000
- PostgreSQL: localhost:5432 (user: `smart_user`, heslo: `artanox2912`)

---

### 🔟 Finální reset Portainer

**Problém:**
- Kontejner nedával (stack corruption)
- Možná špatné smazání

**Řešení - Kompletní přeinstalace:**

```bash
# 1. Smaž Portainer
docker rm -f portainer 2>/dev/null || true
docker volume rm portainer_data 2>/dev/null || true

# 2. Spusť Portainer znovu
docker run -d \
  --name=portainer \
  --restart=always \
  -p 8000:8000 \
  -p 9443:9443 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

# 3. Smaž všechno staré
docker rm -f $(docker ps -aq) 2>/dev/null || true
docker volume rm $(docker volume ls -q) 2>/dev/null || true
docker network rm $(docker network ls -q | grep -v bridge | grep -v host | grep -v none) 2>/dev/null || true

# 4. Nový setup v Portainer
# https://localhost:9443
```

---

## ✅ Finální YAML

```yaml
version: "3.9"

services:
  code-server:
    image: lscr.io/linuxserver/code-server:latest
    container_name: code-server
    privileged: true
    user: 0:0
    environment:
      - PUID=0
      - PGID=0
      - TZ=Europe/Prague
      - PASSWORD=artanox2912
      - EXTENSIONS=GitHub.copilot,esbenp.prettier-vscode,dbaeumer.vscode-eslint,bradlc.vscode-tailwindcss,ritwickdey.liveserver
    volumes:
      - workspace_data:/config
    ports:
      - 8080:8443
    networks:
      - smart-net
    restart: always
    depends_on:
      - db

  db:
    image: postgres:15
    container_name: smart-db
    environment:
      POSTGRES_DB: smart_db
      POSTGRES_PASSWORD: artanox2912
      POSTGRES_USER: smart_user
    volumes:
      - db_data:/var/lib/postgresql/data
    networks:
      - smart-net
    restart: always

  wiki:
    image: ghcr.io/requarks/wiki:2
    container_name: wiki
    depends_on:
      - db
    environment:
      DB_TYPE: postgres
      DB_HOST: db
      DB_PORT: 5432
      DB_USER: smart_user
      DB_PASS: artanox2912
      DB_NAME: smart_db
    ports:
      - "3000:3000"
    restart: always
    volumes:
      - wiki_data:/wiki/storage
    networks:
      - smart-net

networks:
  smart-net:
    driver: bridge

volumes:
  workspace_data:
  db_data:
  wiki_data:
```

---

## 📊 Srovnění verzí

| Verze | Co se změnilo |
|--------|--------|
| v1 | `workspace_new_data` → `workspace_data` (volume issue) |
| v2 | `postgres:15-alpine` → `postgres:15` (socket permission) |
| v3 | Hesla: `tvoje_tajne_heslo_123` → `artanox2912` |
| v4 | Přidán IntelliJ (selhalo - image neexistuje) |
| v5 | Odstraněn IntelliJ, zůstal Code Server |
| v6 | Odstraněn `GitHub.copilot-chat` extension |
| **FINAL** | Kompletní reset + přeinstalace Portainer |

---

## 🎓 Naučil jsem se

✅ Docker volumes a jejich pojmenování  
✅ PostgreSQL Alpine vs Full image  
✅ Rozdíl mezi Placenými a Community IDE  
✅ JetBrains Community Edition - co je to  
✅ Gitpod vs Desktop vs Code Server  
✅ Extension problémy v Code Server  
✅ Portainer stack management  
✅ Docker cleanup a reset  

---

## 🚀 Příští kroky

1. ✅ Spustit nový Portainer
2. ✅ Deploy nového stacku
3. ✅ Ověřit všechny 3 služby běží
4. �� Vyzkoušet GitHub Copilot v Code Server
5. ✅ Připojit se k PostgreSQL

---

**Status:** 🔄 V PROCESU - Čekám na nový start  
**Poslední update:** 2026-03-02 14:39:22