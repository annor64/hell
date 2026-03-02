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
