# ČEZ — souhrn znalostí, projektů, nástrojů a skriptování

## 1) Co jsme se naučili

### Organizačně a datově
- Práce pro ČEZ je oddělená pod `CEZ/` do 5 hlavních oblastí: `SQL`, `GROOVY`, `CONVERTY`, `GENERATOR_DLL`, `PREVOD_KOMENTARU`.
- SQL domény, se kterými se pracuje: `ADAPTACE_01`, `ATACAMA_ONE`, `CX01`, `FA06`, `FLEXI`, `Obecne`, `SCALER`.
- U více domén je patrný standard ETL vrstvení (`EXT -> INT -> ODS`) a práce s efektivním datem (`VAR_EFFECTIVE_DATE`).

### Kvalita metadat a komentářů
- Umíme automaticky generovat/normalizovat komentáře sloupců z metadata CSV (heuristiky + mapování tokenů).
- Umíme hromadně převádět hodnoty `@level0/1/2name` na lowercase.
- Umíme převádět komentáře na konzistentní český popis (včetně záloh vstupních souborů).

### ODI/Groovy provozně
- Běh v ODI Studio je na verzi **12.2.1** (Build ODI_MAIN_GENERIC_180530.1901).
- Spolehlivé je mít přímou kontrolu výsledku v repository (`SNP_SESSION`), protože „odesláno/OK“ nemusí znamenat reálné vytvoření session cílového scénáře.
- Byla vytvořena diagnostická disciplína: ověřit binding objekty, dostupné metody a teprve pak volat runtime API.
- U mapping atributů (`MapAttribute`) je v této verzi ODI ověřeno, že `UD1/UD2` checkboxy nelze přes Groovy API spolehlivě nastavit; nastavují se ručně v ODI Studio.
- `Insert/Update` flagy jsou naopak skriptovatelné a v automatizaci zůstávají.

---

## 2) Jaké projekty jsi dělal (zachycené v repozitáři)

## ADAPTACE (hlavně ADAPTACE_25/ADAPTACE_01)
- Automatizace tvorby a úprav mappingů `EXT_*` a `INT_OT*_SD`.
- Automatizace nastavování IKM (`IKM Oracle Slowly Changing Dimension BICPR`, `IKM Oracle IncUpd Shortcut SEQ CEZ`) a IKM option hodnot.
- Generování sekvencí `OTA25_*_ID_SEQ` v projektu `BICPR_BT_DWH`.
- Úpravy SCD typů sloupců v ODS modelu (`SURROGATE_KEY`, `NATURAL_KEY`, `START/END_TIMESTAMP`, `CURRENT_RECORD_FLAG`, `ADD_ROW_ON_CHANGE`).

## ATACAMA_ONE
- Tvorba package kroků z mappingů s prefixy (`ATO_`, `EXT_`, `INT_...`).
- Vkládání `StepOdiCommand` kroků se spuštěním scénářů (`OdiStartScen`) a předáváním proměnných.
- Práce s metadaty (`metadata.csv`) a navazující skripty pro komentáře.

## REDAT
- Importní SQL postup pro `RDTT_TOPS_IMPORT_CSV` (external table + transformace datových typů + commit).
- Groovy nástroje pro spuštění scénářů (`TEST_REDAT_A`, `REDAT_SOUBORY_EXT_INT_VIA_EFF_DATE`) s konfigurovatelným effective day.
- Ověřování vytvoření session přímo přes `SNP_SESSION`.

## SCALER
- Generování ODS view vrstvy (soubor `ODT_SCA_views.sql`) nad základními tabulkami.
- Standardizace: `CURRENT_FLAG = 1`, explicitní sloupce, `COMMENT ON TABLE/COLUMN`.

## FLEXI
- DDL a komentáře pro `EXT_IMPORT`, `OWNBT_INT`, `OWNBT_ODS` tabulky (`FLEXI_tabulky_EXT/INT/ODS.sql`).
- Evidentní pattern: technická auditní pole, effective date partitioning v INT vrstvě.

---

## 3) Jaké máme nástroje

### Python
- `CEZ/GENERATOR_DLL/generate_comments.py` — generování českých komentářů do `metadata.csv` podle heuristik.
- `CEZ/SQL/ADAPTACE_01/update_metadata_comments.py` — doplnění chybějících komentářů + backup.
- `CEZ/PREVOD_KOMENTARU/prevod_komentaru/convert_all_levels.py` — hromadný lowercase `@level*name`.
- `CEZ/PREVOD_KOMENTARU/prevod_komentaru/fix_levels.py` — robustnější lowercase náhrada pro všechny level hodnoty.
- `CEZ/PREVOD_KOMENTARU/prevod_komentaru/lowercase_levels.py` — CLI varianta (`<file>` argument).
- `CEZ/CONVERTY/convert_descriptions.py` — lowercase prvního písmena v `@value = N'...'`.

### PowerShell
- `CEZ/CONVERTY/convert_descriptions.ps1` — stejné pravidlo jako Python varianta pro převod popisů.

### SQL
- `CEZ/GROOVY/Automatizace_GROOVY/tools/ReDat_import_oracle_developer.sql` — import ReDat CSV přes Oracle external table.
- `CEZ/GENERATOR_DLL/generator_dll/view_comments.sql` — komentáře view/sloupců (obsáhlý slovník komentářů).
- `CEZ/SQL/SCALER/ODT_SCA_views.sql` — generované ODS view.
- `CEZ/SQL/FLEXI/FLEXI_tabulky_EXT.sql`, `...INT.sql`, `...ODS.sql` — DDL a komentáře.

### ODI Groovy
- Automatizace mappingů, package kroků, sekvencí, SCD nastavení i scénářového spouštění.
- Diagnostika runtime bindingu a metod (`ODI_DIAG_KB_DUMP.groovy`).

---

## 4) Kapitola o skriptování (co jsme se naučili)

### 4.1 Praktické lekce
- V ODI Studio je potřeba oddělit „odeslání příkazu“ od „reálně vzniklé session“.
- Ne každá dostupná metoda v bindingu je funkčně použitelná v konkrétním runtime; validace přes reálný výsledek v `SNP_SESSION` je nutnost.
- Při spouštění scénářů je zásadní konzistence: název scénáře, verze, context, agent, proměnné projektu.

### 4.2 Použitelné třídy / API (ověřené v repozitářových skriptech)
- Transakce a persistence:
  - `oracle.odi.core.persistence.transaction.support.DefaultTransactionDefinition`
  - `odiInstance.getTransactionManager()`
  - `odiInstance.getTransactionalEntityManager()`
- Projekt/folder/package:
  - `oracle.odi.domain.project.OdiProject`
  - `oracle.odi.domain.project.OdiPackage`
  - `oracle.odi.domain.project.finder.IOdiProjectFinder`
- Kroky v package:
  - `oracle.odi.domain.project.StepMapping`
  - `oracle.odi.domain.project.StepOdiCommand`
  - `oracle.odi.domain.project.StepVariable`
- Mapping/model:
  - `oracle.odi.domain.mapping.Mapping`
  - `oracle.odi.domain.model.OdiModel`
  - `oracle.odi.domain.model.OdiColumn`
- Sekvence:
  - `oracle.odi.domain.project.OdiSequence`
- Výrazy a odkazy:
  - `oracle.odi.domain.xrefs.expression.Expression`
  - `oracle.odi.domain.xrefs.expression.Expression.SqlGroupType`
  - `oracle.odi.domain.xrefs.CrossRef`

### 4.3 Co je potřeba brát jako rizikové / nestabilní
- Spouštění přes `jOdiBuilder.execute_session(...)` může vytvořit jiné session nebo session bez navázaného cílového scénáře (`SCEN=null`), pokud parametry nesedí runtime interpretaci.
- Úspěšný návrat metody bez chyby není dostatečný důkaz úspěšného startu požadovaného scénáře.
- Proto je správně mít v launcheru post-check do `SNP_SESSION` s baseline `SESS_NO`.

### 4.4 Jaké skripty už umíme (ODI/Groovy)
- Tvorba package z mappingů (`ATO_-_create_package.groovy`).
- Vkládání PK kontrolních kroků (`ATACCAMA_PK_package`, `vytvoreni_INT_mapingu`).
- Hromadné úpravy mapování + IKM option (`EX_IT_mapping`, `propojeni_ad`).
- Hromadné založení sekvencí (`vytvoreni_seq`).
- Úpravy SCD typů v modelu (`uprava_modelu_v_ODS_add_row_adn_SCD`).
- Diagnostika ODI runtime (`tools/ODI_DIAG_KB_DUMP.groovy`).
- REDAT launcher skripty (`tools/tools pro redat`, `tools/tools pro redat - TEST_REDAT_A - NEOTESTOVANO !!`).

---

## 5) Doporučený standard do dalších iterací
- U každého launcher skriptu mít 3 fáze: `pre-check` (existence scénáře), `run`, `post-check` (`SNP_SESSION`).
- Zachovat jednu „produkční“ a jednu „test“ variantu launcheru (jako u REDAT).
- U konverzních skriptů vždy vytvářet backup vstupu před zápisem.
- U nových Groovy automatizací zapisovat použité třídy a podpisy metod do KB, ať se neopakují slepé pokusy.

## 6) Odkazy na klíčové soubory
- `ZNALOSTI.md`
- `README.md`
- `CEZ/GROOVY/Automatizace_GROOVY/tools/tools pro redat`
- `CEZ/GROOVY/Automatizace_GROOVY/tools/ODI_DIAG_KB_DUMP.groovy`
- `CEZ/SQL/ATACAMA_ONE/ATO_-_create_package.groovy`
- `CEZ/GENERATOR_DLL/generate_comments.py`
- `CEZ/PREVOD_KOMENTARU/prevod_komentaru/lowercase_levels.py`

## 7) Co chybělo ve znalostech (doplněno 2026-03-03)
- `tools pro redat - TEST_REDAT_A - NEOTESTOVANO !!` má robustní launcher pattern, který v KB chyběl:
  - `SCEN_VERSION=-1` se nejdřív resolvuje přes `SNP_SCEN` na konkrétní nejvyšší verzi.
  - Start používá 3 launch pokusy (`A1/A2/A3`) přes různé kombinace argumentů `execute_session`.
  - Úspěch se nepotvrzuje návratem metody, ale vznikem nové session v `SNP_SESSION` nad baseline `SESS_NO`.
  - Při failu skript vypíše i „cizí“ nové sessions po baseline (rychlá forenzní stopa v ODI runtime).
- `ReDat tools` obsahuje praktické SQL kontroly INT/ODS/Pomocné tabulky a cílený posun `*_effective_date_minute` pro SCD časovou souslednost.
- Reálná deployment struktura v repozitáři je pod `gitops/` + `scripts/` (ne pod generickým `stacks/` v kořeni).
- Pro provoz je důležité držet oddělení domén:
  - `CEZ/` = datová a ODI/Groovy automatizace,
  - `gitops/` + `scripts/` = infra deploy vrstva (Portainer/HELL),
  - `ct105_tools/` = workstation runtime tooling.
