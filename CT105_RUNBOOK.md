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
