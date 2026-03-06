## Údržba a organizace složek

### Pravidla údržby
- Pravidelně kontroluj složky scripts, monitoring, ha, network a IDE – staré logy, testy, .bak a .tmp soubory přesouvej do _archive.
- Soubory s příponou .bak, .log, .tmp, .test, .old, .deprecated, .zaloha, .obsolete, nebo s rokem starším než aktuální rok, přesouvej do _archive.
- Každý projekt má svůj README s popisem účelu a struktury.
- Osobní soubory (CV, prezentace, rozpočet, Petrikov) udržuj v Osobni.
- Pracovní a firemní projekty (CEZ, DATACONS) udržuj v DATACONS/CEZ.
- Vše, co už není aktivně používané, přesunuj do _archive s datem přesunu.

### Doporučený postup archivace
1. Projdi složky a vyhledej soubory podle klíčových slov: bak, log, test, tmp, old, deprecated, obsolete, zaloha, rok < aktuální.
2. Přesuň je do _archive/ROK-MESIC-DEN/ nebo do tematického podadresáře.
3. Zapiš změnu do commit message a krátce popiš důvod.

### Automatizace
Pro větší projekty lze použít skript na automatické přesuny podle vzoru:
```powershell
Get-ChildItem -Recurse | Where-Object { $_.Name -match 'bak|log|test|tmp|old|deprecated|obsolete|zaloha|202[0-5]' } | Move-Item -Destination _archive\$(Get-Date -Format yyyy-MM-dd)
```

---
Každý přesun nebo větší úklid vždy commmitni s popisem změny.
