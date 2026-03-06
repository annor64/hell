# Návod: Nová instalace Proxmox + obnova CT100/CT105

## 1. Instalace Proxmox VE
- Stáhni ISO z https://www.proxmox.com/downloads
- Nainstaluj na fyzický server (nebo VM)
- Při instalaci nastav:
  - Hostname: hell
  - IP adresa: 192.168.0.135
  - Maska: 255.255.255.224 (/27)
  - Gateway: 192.168.0.1
  - DNS: 8.8.8.8
- Po instalaci přihlaš do web GUI: https://192.168.0.135:8006 (root/nimda)

## 2. Nahrání záloh
- Přihlaš se přes WinSCP/SFTP jako root
- Nahraj soubory vzdump-lxc-100-*.tar a vzdump-lxc-105-*.tar do /var/lib/vz/dump/

## 3. Obnova kontejnerů
- V Proxmox GUI nebo přes shell spusť:
  pct restore 100 /var/lib/vz/dump/vzdump-lxc-100-*.tar
  pct restore 105 /var/lib/vz/dump/vzdump-lxc-105-*.tar
- Po obnově zkontroluj konfiguraci sítě:
  - CT100: 192.168.0.136
  - CT105: 192.168.0.137
  - Gateway: 192.168.0.1
  - Maska: 255.255.255.224 (/27)

## 4. První start a kontrola
- Spusť oba kontejnery v Proxmox GUI
- Ověř ping na IP adresy z LAN
- Přihlaš se do kontejnerů přes SSH (root/heslo)
- Ověř služby (např. Docker, Portainer, Citrix, VPN)

## 5. Poznámky
- Pokud potřebuješ změnit IP adresu, uprav /etc/network/interfaces v kontejneru
- Po obnově může být potřeba restart kontejneru
- Všechny zálohy a dokumentaci ukládej do adresáře technologicky_stack_hell

---
Datum: 2026-03-05
Autor: GitHub Copilot
