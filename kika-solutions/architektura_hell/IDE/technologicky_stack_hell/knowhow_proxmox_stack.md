# Know-how: Proxmox + CT100/CT105

## Síťová schéma
- Proxmox hostitel: 192.168.0.135/27
- CT100 (Cloudflare tunnel): 192.168.0.136/27
- CT105 (work-station): 192.168.0.137/27
- Gateway: 192.168.0.1

## Přihlašovací údaje
- Proxmox GUI: https://192.168.0.135:8006
- Uživatelské jméno: root
- Heslo: nimda (první start)

## Zálohování a obnova
- Zálohy ukládat do /var/lib/vz/dump/
- Obnova přes pct restore (viz návod)

## Stav k 2026-03-05
- Zálohy CT100 a CT105 staženy a připraveny
- Připraveno na čistou instalaci Proxmoxu

---
Všechny související soubory a dokumentaci ukládat do adresáře technologicky_stack_hell.
