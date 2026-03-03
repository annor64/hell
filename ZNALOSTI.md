# Znalosti projektu

Tento soubor slouží jako centrální místo pro průběžné poznatky, rozhodnutí a kontext.

## Jak zapisovat
- Piš stručně a věcně.
- Ke každému záznamu uveď datum.
- Pokud je to relevantní, přidej cestu k souboru nebo složce.

## Šablona záznamu
### YYYY-MM-DD — Název tématu
- Oblast:
- Kontext:
- Zjištění:
- Rozhodnutí:
- Dopad:
- Další kroky:

---

## Záznamy
### 2026-03-03 — Synchronizace KB s architekturou a strukturou repozitáře
- Oblast: Repo údržba / znalostní báze / architektura
- Kontext: Potřeba doplnit, co chybělo ve znalostech, a sjednotit architekturu s reálnými cestami v repozitáři.
- Zjištění:
	- V `CEZ_ZNALOSTI_A_SKRIPTOVANI.md` chyběly detailní runtime poznatky k launcheru `TEST_REDAT_A` (resolve verze, multi-attempt launch, post-check v `SNP_SESSION`).
	- Architektonický dokument používal obecné cesty `stacks/...`, ale reálná implementace je v `gitops/...` a `scripts/...`.
	- Repo už obsahuje oddělené vrstvy: `CEZ/` (data+ODI), `gitops/`+`scripts/` (deploy), `ct105_tools/` (workstation tooling).
- Rozhodnutí:
	- Doplnit CEZ KB o explicitní sekci „co chybělo ve znalostech“.
	- Upravit `ARCHITEKTURA_DEPLOYMENT_FACTORY.md` na aktuální paths + přidat mapování architektura -> repozitář.
- Dopad:
	- Menší riziko nesouladu mezi dokumentací a implementací.
	- Rychlejší orientace v tom, kde je datová automatizace vs deploy automatizace.
- Další kroky:
	- Dopsat runbook pro rollback přes SSH fallback na node HELL.
	- Přidat pravidelný „KB sync“ checkpoint po každé významnější změně skriptů.

### 2026-03-03 — ODI mapping: UD1/UD2 nelze spolehlivě nastavit přes Groovy
- Oblast: ČEZ / ODI Groovy / ATACAMA_ONE
- Kontext: Automatická tvorba `INT_OT*_SD` mappingů v souboru `CEZ/SQL/ATACAMA_ONE/INT_ODS_mapp`.
- Zjištění:
	- `Insert/Update` flagy jdou nastavovat skriptem (`setInsertIndicator`, `setUpdateIndicator`).
	- `UD1/UD2` checkboxy na atributu (`MapAttribute`) v ODI 12.2.1 nejsou přes dostupné Groovy API spolehlivě nastavitelné.
	- Diagnostika vrací varování typu `UD1/UD2-WARN` a nelze načíst použitelné property pro zápis.
- Rozhodnutí:
	- `UD1/UD2` nastavovat ručně v ODI Studio (Attributes).
	- Ve skriptu mít `applyUdFlags = false` jako default a UD pokusy pouštět jen při experimentu.
- Dopad:
	- Odpadnou falešné očekávání i chybové WARNy při běžném generování mappingů.
	- Stabilní provoz: skript řeší strukturu + Insert/Update, UD zůstává manuální krok.
- Další kroky:
	- Pokud bude potřeba plná automatizace UD, řešit export/import XML nebo jiný mimo-API postup.

### 2026-03-02 — Inicializace znalostní báze
- Oblast: Repo údržba
- Kontext: Založen centrální soubor pro znalosti.
- Zjištění: Chybělo jednotné místo pro poznámky a rozhodnutí.
- Rozhodnutí: Používat tento soubor pro průběžný knowledge log.
- Dopad: Snazší předávání kontextu a historie rozhodnutí.
- Další kroky: Doplňovat po každé významné změně.

### 2026-03-02 — Konfigurace virtuálního PC (LXC 105)
- Oblast: Infrastruktura / vzdálený přístup / Citrix
- Kontext: Nastavení vzdálené plochy v LXC kontejneru na Proxmoxu s webovým přístupem a provozem 24/7.
- Zjištění:
	- Cíl je běh GUI prostředí (Debian 13, XFCE/KDE) v privileged LXC s podporou TUN/TAP kvůli VPN.
	- Pro noVNC je nutná kombinace x11vnc (5900) + websockify/launch.sh (6080).
	- Častá chyba `XOpenDisplay failed` znamená, že není spuštěný X server/display `:0`.
	- Citrix vyžaduje správně nainstalované certifikáty v systému i v ICAClient store.
- Rozhodnutí:
	- Udržovat konfiguraci jako provozní runbook se sekcemi: instalace, služby, autostart, troubleshooting.
	- Preferovat start skript (`/usr/local/bin/start-vnc.sh`) a automatický start po rebootu.
	- Keep-alive řešit samostatným skriptem (`/usr/local/bin/keep_alive.sh`) s `xdotool` po 5 minutách.
- Dopad:
	- Zajištěný 24/7 webový přístup přes `http://<IP_KONTEJNERU>:6080/vnc.html`.
	- Reprodukovatelný postup instalace Citrix Workspace včetně oprav závislostí a certifikátů.
- Další kroky:
	- Ověřit persistenci služeb po rebootu a dostupnost portů 5900/6080.
	- Ověřit funkční VPN připojení přes Citrix bez SSL Error 61.
	- Dle potřeby převést cron start na systemd služby pro robustnější správu.

#### Provozní detaily (zachycený kontext)
- OS: Debian 13
- Režim kontejneru: privileged
- LXC config (`/etc/pve/lxc/ID_KONTEJNERU.conf`):
	- `lxc.cgroup2.devices.allow: c 10:200 rwm`
	- `lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file`
- Instalace balíčků:
	- GUI: `xfce4` nebo `kde-plasma-desktop`
	- Remote přístup: `x11vnc`, `novnc`
	- Nástroje: `firefox-esr`, `xdotool`
- Start příkazy:
	- `x11vnc -forever -usepw -display :0 -geometry 1920x1080 -bg`
	- `websockify 6080 localhost:5900` nebo `/usr/share/novnc/utils/launch.sh --vnc localhost:5900 --listen 6080`
- Diagnostika:
	- `netstat -tulpn | grep 5900`
	- `netstat -tulpn | grep 6080`
- Citrix instalace:
	- `dpkg -i citrix.deb`
	- `apt --fix-broken install -y`
	- Certifikáty do `/usr/local/share/ca-certificates/` + `update-ca-certificates`
	- ICAClient cert sync:
		- `ln -s /usr/share/ca-certificates/mozilla/* /opt/Citrix/ICAClient/keystore/cacerts/`
		- `/opt/Citrix/ICAClient/util/ctx_rehash`

### 2026-03-02 — Úklid repozitáře (bezpečný přesun)
- Oblast: Repo údržba
- Kontext: Potřeba udělat pořádek bez rizika ztráty dat.
- Zjištění:
	- V repozitáři byly dočasné a záložní artefakty (`*.bak`, `__pycache__`, složka `dočasné`).
	- Existuje dvojice názvů `ATACAMA ONE` a `ATACCAMA ONE` (zatím ponecháno bez slučování).
- Rozhodnutí:
	- Nemazat natrvalo; přesunout problematické položky do archivní složky s datem.
	- Přidat `.gitignore` pro prevenci opětovného zanášení repozitáře.
- Dopad:
	- Úložiště je čistší a auditovatelné, současně reverzibilní (vše je dohledatelné v archivu).
	- Nové cache/backup soubory se standardně nebudou trackovat.
- Další kroky:
	- Rozhodnout, zda sjednotit `ATACAMA ONE` vs `ATACCAMA ONE`.
	- Po potvrzení názvosloví případně provést cílené přejmenování/sjednocení struktur.

#### Přesunuté položky
- Archivní cesta: `_archive/2026-03-02`
- Přesunuto:
	- `ADAPTACE_01/metadata.bak`
	- `ATACCAMA ONE/metadata.csv.bak`
	- `převod komentářů/zadání 2.bak`
	- `převod komentářů/zadání 2.bak2`
	- `__pycache__/`
	- `FLEXI/číselníky/dočasné/`

#### Preventivní pravidla
- Soubor `.gitignore` nyní ignoruje:
	- `__pycache__/`
	- `*.py[cod]`
	- `.venv/`
	- `*.bak` a `*.bak*`
	- `_archive/`

### 2026-03-02 — Normalizace názvů souborů a složek
- Oblast: Repo údržba / konzistence názvosloví
- Kontext: Požadavek na sjednocení názvů pro lepší práci v automatizaci a cross-platform prostředí.
- Zjištění:
	- V repozitáři byla směs názvů s mezerami, diakritikou a speciálními znaky.
	- To zvyšovalo riziko chyb v scriptech a složitější práce s cestami.
- Rozhodnutí:
	- Projít projektová data (mimo `.git`, `.venv`, `_archive`) a převést názvy na ASCII.
	- Mezery a nekompatibilní znaky sjednotit na `_`.
	- Kolize při přejmenování řešit bezpečně přidáním číselného suffixu.
- Dopad:
	- Provedeno 42 přejmenování bez přepisu existujících položek.
	- Struktura je konzistentnější a vhodnější pro skriptování.
- Další kroky:
	- V případě externích návazností ověřit, že odkazy/cesty používají nové názvy.

### 2026-03-02 — Oddělení práce pro ČEZ
- Oblast: Repo organizace / struktura projektu
- Kontext: Požadavek oddělit práci pro ČEZ do samostatné kořenové oblasti.
- Zjištění:
	- Před změnou byly části SQL, Groovy, converty, generátor a převody komentářů rozprostřené v kořeni repozitáře.
	- Upřesněné domény ČEZ: `ATACAMA`, `ADAPTACE`, `CX01`, `FA06`, `FLEXI`.
- Rozhodnutí:
	- Založena kořenová složka `CEZ/` s podstrukturou `SQL`, `GROOVY`, `CONVERTY`, `GENERATOR_DLL`, `PREVOD_KOMENTARU`.
	- SQL domény přesunuty pod `CEZ/SQL` (včetně `ADAPTACE_01`, `ATACAMA_ONE`, `CX01`, `FA06`, `FLEXI`).
	- Potvrzeno: `Obecne` a `SCALER` jsou součást ČEZ a zůstávají v `CEZ/SQL`.
- Dopad:
	- Práce pro ČEZ je oddělená od ostatního obsahu repozitáře.
	- Srozumitelnější orientace podle typu práce i domény.
- Další kroky:
	- Průběžně udržovat nové materiály pro ČEZ výhradně pod `CEZ/`.

### 2026-03-02 — Sloučení dnešního SETUP logu do znalostí
- Oblast: Docker / Portainer / Workspace setup
- Kontext: Stažen a integrován dnešní chat log ze `SETUP-LOG.md` do centrální znalostní báze.
- Zjištění:
	- Cílový stack: `code-server` + `postgres:15` + `wiki.js` + Copilot extension.
	- Hlavní problémy byly ve volume názvech, PostgreSQL Alpine permissions a neexistujícím JetBrains image.
	- Finální verze `docker-compose` je `3.9` a používá sjednocené názvy volume (`workspace_data`, `db_data`, `wiki_data`).
- Rozhodnutí:
	- Preferovat `postgres:15` (non-alpine) kvůli stabilitě socket/permission chování.
	- IDE volba: `code-server`; IntelliJ image nepoužívat v tomto setupu.
	- V extension listu ponechat `GitHub.copilot`, nepoužívat `GitHub.copilot-chat` v daném prostředí.
- Dopad:
	- Reprodukovatelný setup přes Portainer stack s jasným troubleshooting postupem.
	- Finální postup a YAML jsou archivované v `SETUP-LOG.md` a shrnuté zde.
- Další kroky:
	- Ověřovat běh všech 3 služeb po restartu (`code-server`, `db`, `wiki`).
	- Průběžně aktualizovat `SETUP-LOG.md` i `ZNALOSTI.md` při změnách stacku.

### 2026-03-02 — Ověření Proxmox dostupnosti a konfigurace LXC 105
- Oblast: Proxmox / LXC provoz
- Kontext: Ověření dosažitelnosti Proxmox hostu a načtení aktuální konfigurace CT `105`.
- Zjištění:
	- Proxmox host `192.168.0.135` je dostupný na portech `8006` (API) i `22` (SSH).
	- API login proběhl úspěšně, node identifikován jako `hell`.
	- CT `105` (`work-station`) je ve stavu `running`.
	- Aktuální zdroje: `4` cores, `4064 MB` RAM, `4064 MB` swap, rootfs `32G`.
	- Síť: `eth0` na `vmbr0`, IP `192.168.0.137/27`, gateway `192.168.0.1`.
- Rozhodnutí:
	- Vytvořen samostatný dokument `PROXMOX_LXC105_KONFIGURACE.md` jako runbook/operativní snapshot.
- Dopad:
	- Konfigurace je dohledatelná v repozitáři a připravená pro další správu VM/LXC.
- Další kroky:
	- Zvážit zapnutí `onboot=1`, pokud má CT startovat automaticky po rebootu hostu.

### 2026-03-02 — CT105: TightVNC + noVNC stabilizace
- Oblast: Proxmox / LXC provoz / vzdálený přístup
- Kontext: Finální stabilizace přímého vzdáleného přístupu do CT105 bez závislosti na Portainer workflow.
- Zjištění:
	- Funkční cílový stav je `TightVNC` na `5901` a `noVNC` na `8080` (`/vnc.html`).
	- Samotný VNC server nestačí; pro GUI je nutné mít korektní `~/.vnc/xstartup` (spouštění `startxfce4`).
	- Chyba typu `failed waiting for client: timed out` u proxy je očekávaná, pokud se nepřipojí websocket klient.
	- Ověřený minimální set kontrol: aktivní systemd služby, otevřené porty `5901/8080`, HTTP 200 na `vnc.html`.
- Rozhodnutí:
	- Pro CT105 ponechat přístup přes TightVNC/noVNC (`5901` + `8080`) jako primární cestu.
	- Nepoužívat pro tento účel code-server instalaci uvnitř CT105.
	- Ponechat skript `_proxmox_ct105_check.ps1` na `curl.exe` auth flow (stabilnější než PS web cmdlets v tomto prostředí).
- Dopad:
	- Přímý browser přístup i RealVNC přístup jsou provozně funkční.
	- Zjednodušený troubleshooting a menší závislost na vedlejších integračních krocích.
- Další kroky:
	- Při reboot testu ověřit perzistenci služeb `tightvncserver@1` a `novnc`.
	- Volitelně doplnit samostatný runbook pro CT105 services + rollback postup.

### 2026-03-02 — Hardening PowerShell fetch skriptů
- Oblast: Automatizace / PowerShell kompatibilita
- Kontext: Opakované pády při stahování logů kvůli interaktivnímu chování `Invoke-WebRequest` v některých host prostředích.
- Zjištění:
	- V některých kontextech vyžaduje `Invoke-WebRequest` kompatibilní parametry (`UseBasicParsing`), jinak může dojít k interaktivnímu promptu.
- Rozhodnutí:
	- Přidán helper `_invoke_webrequest_compat.ps1` a napojení do `_portainer_fetch_logs.ps1`.
	- V fetch skriptu ponechána robustní dekódovací logika Docker log streamu + sanitizace výstupu.
- Dopad:
	- Stabilnější neinteraktivní běh při fetchi logů.
	- Menší riziko pádu tasku při dlouhém automatizovaném běhu.
- Další kroky:
	- Pokud budou přibývat další IWR skripty, používat stejný helper jako standard.

### 2026-03-03 — Cílová architektura „Deployment Factory“ (Proxmox + Portainer)
- Oblast: Infrastruktura / Docker orchestrace / automatizace nasazení
- Kontext: Požadavek automatizovat tvorbu a správu Docker stacků ve větším měřítku („na běžícím pásu“) s využitím existujícího Proxmox + Portainer prostředí.
- Zjištění:
	- Portainer se standardně neřídí přes SSH; SSH je na Docker host/VM, Portainer primárně přes REST API.
	- V aktuálním prostředí je API login funkční, ale volání `create stack` může v některých případech viset/padat bez stabilní odpovědi.
	- Dřívější stack (`code-server + db + wiki`) byl nasazen úspěšně, ale chybí sjednocený release workflow a service-account přístup.
- Rozhodnutí:
	- Zavést GitOps model: každý stack jako verzovaný manifest (`compose` + env šablona) v repozitáři.
	- Pro API automatizaci nepoužívat osobní účet, ale service účet/API key s minimálními oprávněními.
	- Nasazení realizovat přes „Deployment Runner“ (PowerShell/Python) běžící na stroji s jistou dostupností na Portainer i Docker host.
	- Přidat fallback cestu: pokud Portainer create API selže, provést deploy přes SSH přímo na Docker host (`docker compose up -d`) a stav zpětně auditovat.
	- Každé nasazení ukládat do audit logu (čas, stack, verze, endpoint, výsledek, rollback info).
- Dopad:
	- Reprodukovatelné, opakovatelné a auditovatelné nasazování stacků.
	- Menší závislost na ručním klikání v Portainer UI.
	- Rychlejší škálování na více stacků/služeb při nižším provozním riziku.
- Další kroky:
	- Vytvořit service API key v Portaineru a přesunout credentials mimo skripty (secret store / env).
	- Připravit katalog stack šablon (MVP: Home Assistant + stávající workspace stack).
	- Dopsat jednotný deploy skript (`create/update/verify/rollback`) s timeouty a pollingem stavu.
	- Zavést minimální health-check standard po deployi (container running, endpoint dostupnost, poslední log error).
	- Doplnit provozní runbook: „Portainer API down“, „endpoint offline“, „rollback poslední verze“.

### 2026-03-03 — Upřesnění rolí CT100 vs CT105 (Proxmox)
- Oblast: Infrastruktura / role kontejnerů
- Kontext: Upřesnění, že orchestrace stacků se týká „druhého CT“, tj. CT `100` (nikoli CT `105`).
- Zjištění:
	- CT `105` je dokumentovaný jako workstation/Citrix/noVNC runtime.
	- Pro Docker/Portainer automatizaci je cílový provozní kontejner CT `100`.
- Rozhodnutí:
	- V architektuře a automatizačních skriptech oddělit role:
		- CT `100` = container platform (Docker/Portainer, deploy target).
		- CT `105` = uživatelský pracovní runtime (Citrix/RDP/noVNC).
	- Nové deployment runbooky a skripty směrovat primárně na CT `100`.
- Dopad:
	- Menší riziko nasazování stacků na nesprávný CT.
	- Jasnější provozní odpovědnosti mezi „platform“ a „workspace“ vrstvou.
- Další kroky:
	- Doplnit samostatný runbook pro CT `100` (IP, síť, služby, onboot, backup).
	- Ověřit mapování Portainer endpointId -> CT `100` v API výstupu a zapsat do KB.

### 2026-03-03 — Operativní stav automatizace deploye (Home Assistant)
- Oblast: Portainer API / SSH provoz / troubleshooting
- Kontext: Pokus o plně automatický deploy stacku `homeassistant` bez ručního klikání v Portainer UI.
- Zjištění:
	- API login do Portaineru je funkční (`/api/auth`), problém vzniká při `create stack` volání (nestabilní/bez použitelné odpovědi v části běhů).
	- Přímý SSH test na Proxmox host selhal na autentizaci: `Permission denied (publickey,password)`.
	- Nástroj `plink` není na pracovní stanici dostupný, takže není k dispozici jednoduchý password-based non-interactive fallback.
	- Execution policy byla nastavena správně (`CurrentUser = RemoteSigned`), blokér není v PowerShell policy.
- Rozhodnutí:
	- Primární cesta zůstává Portainer API, ale s robustním timeout/polling patternem.
	- Pro emergency fallback použít deploy přes SSH na host (Docker Compose), až po potvrzení funkční SSH identity.
	- Credentials neukládat dlouhodobě v plaintext skriptech; přejít na service API key + secret store.
- Dopad:
	- Je jasně identifikovaný technický blokér: chybějící funkční SSH přihlašovací cesta a nespolehlivá create API odpověď.
	- Další automatizace je realizovatelná po doplnění identity managementu pro host/Portainer.
- Další kroky:
	- Ověřit a zprovoznit SSH přístup (preferovaně klíč) pro cílový provozní host/CT `100`.
	- Vytvořit Portainer service API key a přejít z user/password flow.
	- Zavést jednotný deploy job: `create-or-update` + `verify containers` + `rollback`.

### 2026-03-03 — Implementace: jednotné místo pro secrets + GitOps CI pipeline
- Oblast: Deployment Factory / CI/CD / bezpečnost tajných údajů
- Kontext: Požadavek vytvořit jedno místo pro secrets a připravit GitOps pipeline pro Portainer deploye.
- Zjištění:
	- V repozitáři dříve chyběla standardizovaná struktura pro stack katalog, secrets a CI workflow.
	- Potřebný je model, kde produkční secrets nejsou commitované do Gitu.
- Rozhodnutí:
	- Zavedena složka `gitops/` jako centrální vstup pro deployment:
		- `gitops/stacks/homeassistant/compose.yml`
		- `gitops/secrets/portainer.env.template`
		- `gitops/secrets/README.md`
		- `gitops/README.md`
	- Přidán univerzální deploy skript `scripts/deploy_portainer_stack.ps1` (create/update + verify kontejnerů).
	- Přidán GitHub Actions workflow `.github/workflows/gitops-portainer.yml` (validate + manual deploy přes `workflow_dispatch`).
	- `.gitignore` doplněn o ignorování lokálních secrets (`gitops/secrets/*.env`, `*.key`, `*.secret`).
- Dopad:
	- Secrets mají jedno vyhrazené místo a šablony jsou oddělené od reálných hodnot.
	- Pipeline je připravená pro řízený deploy bez ručního přepisování skriptů.
	- Architektura je sjednocená s cílem CT100 jako deploy target platformy.
- Další kroky:
	- Nastavit repository secrets: `PORTAINER_API_KEY`, `PORTAINER_BASE_URL`, `PORTAINER_ENDPOINT_ID`.
	- Otestovat `workflow_dispatch` deploy pro `homeassistant`.
	- Přidat druhý stack do katalogu jako validační test škálovatelnosti.

### 2026-03-03 — Ověření cílového deploy node (Portainer endpoint)
- Oblast: Infrastruktura / Portainer mapování
- Kontext: Potřeba potvrdit, zda je deploy target CT100, CT105, nebo node HELL.
- Zjištění:
	- Portainer API `/api/endpoints` vrací endpoint `Id=3`, `Name=local`, `URL=unix:///var/run/docker.sock`.
	- Portainer API `/api/endpoints/3/docker/info` vrací `DockerName=hell`.
	- CT100 je provozně určený pro Cloudflare tunnel; CT105 je workstation runtime.
- Rozhodnutí:
	- Oficiální deploy target pro stacky je node `HELL` (endpoint `3`), nikoli CT100/CT105.
	- CT100 držet jako tunnel vrstvu, CT105 jako user workspace vrstvu.
	- Deployment Factory dokumentaci a runbooky orientovat na HELL endpoint.
- Dopad:
	- Uzavřené mapování cílové platformy pro GitOps deploye.
	- Menší riziko nasazování stacků do nesprávného kontejneru/role.
- Další kroky:
	- Dopsat do deploy skriptů explicitní check `EndpointId=3` + `DockerName=hell` před deployem.
	- Připravit SSH fallback pouze vůči hostu/node HELL.

### 2026-03-03 — Bitwarden integrace pro secrets (čtení i zápis)
- Oblast: Secrets management / automatizace
- Kontext: Požadavek používat Bitwarden nejen pro čtení, ale i pro zapisování hodnot používaných deploy pipeline.
- Zjištění:
	- Lokální `.env` workflow je funkční, ale bez centrálního source-of-truth hrozí drift mezi stroji.
	- `bw` CLI + `BW_SESSION` umožňuje bezpečný pull/push bez commitování reálných secrets.
- Rozhodnutí:
	- Deploy skript `scripts/deploy_portainer_stack.ps1` rozšířen o fallback načítání secrets z Bitwardenu (`BW_ITEM_ID` / `BW_ITEM_NAME`).
	- Přidán sync skript `scripts/bitwarden_portainer_secret_sync.ps1`:
		- `-Mode pull` (Bitwarden -> `.env`)
		- `-Mode push` (`.env` -> Bitwarden create/update)
	- Dokumentace doplněna v `gitops/README.md`, `gitops/secrets/README.md`, `gitops/secrets/portainer.env.template`.
- Dopad:
	- Secrets lze centrálně spravovat v Bitwardenu a zároveň synchronizovat do lokálního runtime bez ukládání do Gitu.
	- Záloha proti výpadku lokálního `.env` a lepší reprodukovatelnost mezi prostředími.
- Další kroky:
	- Nastavit standardní název itemu `portainer-deploy-secrets` a ověřit první `pull`/`push` v produkčním trezoru.
	- Pro CI používat nadále GitHub repository secrets (neinteraktivní runtime), Bitwarden ponechat jako primární správu hodnot.

### 2026-03-03 — Provozní preference: exekuce přes terminál provádí agent
- Oblast: Spolupráce / operativní workflow
- Kontext: Uživatelská preference minimalizovat ruční spouštění příkazů a nechat terminálové kroky na agentovi.
- Zjištění:
	- Ruční přepisování příkazů vedlo opakovaně k chybám (vložení doprovodného textu místo čistého commandu).
	- Agent má v tomto workspace potřebná práva pro běžnou operativu a může příkazy spouštět přímo.
- Rozhodnutí:
	- Default režim: terminálové kroky (diagnostika, deploy, validace) provádí agent.
	- Uživatele zapojit pouze při interaktivních krocích, které nejdou bezpečně dokončit bez vstupu (např. OTP/login potvrzení).
	- Pokud bude potřeba další oprávnění, agent explicitně vyžádá rozšíření privilegií.
- Dopad:
	- Rychlejší a stabilnější exekuce bez ručního copy/paste.
	- Menší chybovost v provozních krocích.
- Další kroky:
	- V další práci preferovat přímé spuštění commandů agentem a uživateli předávat hlavně výsledky.
