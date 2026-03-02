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
