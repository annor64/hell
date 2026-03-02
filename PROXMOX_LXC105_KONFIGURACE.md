# Proxmox LXC 105 — Konfigurace

Datum ověření: 2026-03-02  
Zdroj: Proxmox API (`https://192.168.0.135:8006`)

## Quick Start (aktuální provoz)
1. Z Windows otevřít `mstsc` a připojit se na `192.168.0.137`.
2. Po přihlášení v CT105 na ploše spustit `01_Citrix_Workspace`.
3. Pokud app login neprojde, použít `02_Citrix_Web`.

### Fallback přístupy
- noVNC: `http://192.168.0.137:8080/vnc.html?autoconnect=true&resize=scale&reconnect=true`
- RDP smart-sizing profil: `ct105_tools/CT105-smartsize.rdp`

## Dostupnost
- API port `8006`: dostupný
- SSH port `22`: dostupný
- Přihlášení přes API: úspěšné (`root@pam`)

## Identita uzlu a kontejneru
- Node: `hell`
- CT ID: `105`
- Hostname: `work-station`
- Stav: `running`
- Uptime (v době měření): `7642` s

## Přidělené zdroje
- CPU cores: `4`
- RAM: `4064 MB`
- SWAP: `4064 MB`
- RootFS: `local-lvm:vm-105-disk-0,size=32G`

## Síť
- `net0`: `name=eth0,bridge=vmbr0,firewall=1,gw=192.168.0.1,hwaddr=BC:24:11:90:29:64,ip=192.168.0.137/27,type=veth`

## Boot
- `onboot`: není explicitně nastaveno

## Rychlé API dotazy (ověřeno)
```bash
# Login
auth POST /api2/json/access/ticket

# Node list
GET /api2/json/nodes

# LXC config
GET /api2/json/nodes/hell/lxc/105/config

# LXC status
GET /api2/json/nodes/hell/lxc/105/status/current
```

## Doporučení
1. Zapnout `onboot=1`, pokud má kontejner běžet po restartu hostu automaticky.
2. Ověřit, že maska `/27` na IP `192.168.0.137` odpovídá síťovému designu.
3. Pokud je cílem VPN/Citrix workload, ponechat privileged režim a validovat TUN/TAP mount v CT konfiguraci.
