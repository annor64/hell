# CT105 Runbook (Citrix + RDP + noVNC)

Datum: 2026-03-02
Host: `192.168.0.137` (CT105)

## Cíl
- Primární přístup přes **RDP** (stabilnější než VNC).
- noVNC ponechat na `8080` jako fallback.
- Na ploše mít přímé spuštění Citrix Workspace + web fallback.

## Aktuální doporučený workflow
1. Ve Windows otevřít `mstsc` a připojit se na `192.168.0.137`.
2. Na ploše CT spustit `01_Citrix_Workspace`.
3. Pokud login app neprojde, použít `02_Citrix_Web`.

## Hlavní endpointy
- RDP: `192.168.0.137:3389`
- noVNC: `http://192.168.0.137:8080/vnc.html?autoconnect=true&resize=scale&reconnect=true`

## Složka skriptů
Finální skripty jsou v `ct105_tools/`:
- `_ct105_setup_xrdp.py` – instalace a základ xRDP.
- `_ct105_fix_xrdp_port_and_resize.py` – oprava listeneru + resize volby.
- `_ct105_set_rdp_citrix_default.py` – RDP-first desktop + Citrix launchery.
- `_ct105_set_vnc_8080_fullscreen.py` – noVNC 8080 FullHD fallback.
- `_ct105_recover_base_novnc.py` – recovery base VNC/noVNC stacku.
- `_ct105_diag_novnc_profiles.py` – diagnostika VNC/noVNC profilů.
- `_ct105_diag_browser_profile.py` – diagnostika browser profilu.
- `_ct105_diag_xrdp_resize.py` – diagnostika RDP resize.
- `CT105-smartsize.rdp` – klientský profil pro `mstsc` (smart sizing).

## Poznámky
- Dynamický live-resize v `mstsc` proti Linux `xRDP` může být omezený; `smart sizing` je praktický workaround.
- noVNC je fallback, ne primární pracovní cesta pro Citrix.

## Troubleshooting
| Symptom | Co zkusit (rychle) |
|---|---|
| RDP se nepřipojí | Ověřit port `3389` z Windows (`Test-NetConnection 192.168.0.137 -Port 3389`). |
| RDP se připojí, ale špatně škáluje | Použít `ct105_tools/CT105-smartsize.rdp`; v relaci přepínat full screen (`Ctrl+Alt+Break`). |
| noVNC na `8080` neodpovídá | Spustit recovery: `ct105_tools/_ct105_recover_base_novnc.py`. |
| noVNC se otevře, ale je černá obrazovka | Otevřít čistý URL s autoconnect: `http://192.168.0.137:8080/vnc.html?autoconnect=true&resize=scale&reconnect=true`. |
| Citrix Workspace neprojde login | Použít desktop launcher `02_Citrix_Web` jako fallback. |
| Citrix hlásí SSL/auth chybu | Zkontrolovat cert chain + endpoint policy; diagnostika skripty v `ct105_tools/`. |
| V RDP nejde „přilepit“ okno k pravému okraji + při posunu jsou černé artefakty | Re-apply: `C:/Users/jkika/SQL/.venv/Scripts/python.exe ct105_tools/_ct105_set_rdp_citrix_vpn_only.py`, odhlásit/přihlásit RDP. Fix zapíná `xfwm4` + `tile_on_move` a vypíná compositor. |

## Update 2026-03-03 — Known-good stav (ověřeno)

### Finální funkční profil
- Přístup: Windows `mstsc` -> CT105 (`192.168.0.137:3389`) jako primární cesta.
- Session režim: `RDP -> Cisco VPN -> Citrix Web`.
- Funkční StoreFront URL: `https://citrix.cezdata.corp/Citrix/CEZWeb/`.
- Browser fallback URL `https://apps.cez.cz/Citrix/CEZWeb/` může fungovat odlišně podle DNS/proxy.
- Na ploše zůstávají launchery `01_Citrix_Workspace` a `02_Citrix_Web`.

### Co bylo nutné pro stabilní provoz
- Synchronizace CA certifikátů do ICAClient trust store (`ctx_rehash`).
- Oprava MIME mapování pro `.ica` -> `wfica.desktop`.
- ICA autostart watcher pro spouštění stažených `.ica` souborů.
- Stabilní windowed režim Citrix appky s velkou plochou (`DesiredHRES=3200`, `DesiredVRES=1200`, `TWIMode=On`).
- Schránka obousměrně: xRDP `cliprdr` + Citrix `ClientClipboard=On` + `autocutsel` bridge.

### Konfigurace oken (snap + artefakty) — přesně co se nastavuje
- Script: `ct105_tools/_ct105_set_rdp_citrix_vpn_only.py`.
- Instalované balíčky pro WM část: `xfwm4`, `xfconf`, `wmctrl`, `xdotool`, `autocutsel`, `xclip`.
- V session startu (`/usr/local/bin/ct105-citrix-vpn-session.sh`) se vynutí `xfwm4 --replace`, aby byl aktivní window manager i v root RDP relaci.
- Runtime WM klíče přes `xfconf-query`:
	- `/general/tile_on_move=true` (přilepení okna na levou/pravou hranu při drag).
	- `/general/snap_to_border=true`, `/general/snap_to_windows=true`, `/general/snap_width=20`.
	- `/general/box_move=true`, `/general/box_resize=true`.
	- `/general/use_compositing=false` (potlačení černých artefaktů při přesunu oken v xRDP).
- Perzistence stejných hodnot je zapsaná i do `/root/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml`.

### Provozní režim (bez ručního spouštění)
- Operátor: konfiguraci na CT105 spouštím já vzdáleně (z workspace skriptem), nevyžaduje se ruční spouštění příkazů z tvé strany.
- Jediná interakce uživatele po aplikaci fixu je nové přihlášení do RDP relace (odhlásit/přihlásit), aby se načetly nové WM parametry.

### Ověřené výsledky
- Spuštění Citrix relace je funkční.
- Rozložení aplikace je použitelné/stabilní.
- Copy/paste funguje i směrem z Citrix app do lokálního desktopu.

### Jednokomandový re-apply
- `C:/Users/jkika/SQL/.venv/Scripts/python.exe ct105_tools/_ct105_set_rdp_citrix_vpn_only.py`

### Když se problém vrátí
1. Odhlásit a znovu přihlásit RDP relaci.
2. Spustit re-apply skript výše.
3. Ověřit VPN (`/opt/cisco/secureclient/bin/vpn state`) a StoreFront URL.
4. Pokud je problém jen s konkrétní publikovanou appkou a nejde resize, ověřit Citrix publish policy na serveru.
