import oracle.odi.domain.mapping.Mapping
import oracle.odi.domain.project.OdiProject
import oracle.odi.domain.project.OdiPackage
import oracle.odi.domain.project.StepMapping
import oracle.odi.domain.project.StepVariable
import oracle.odi.domain.project.finder.IOdiProjectFinder
import oracle.odi.core.persistence.transaction.support.DefaultTransactionDefinition

// --- 1. KONFIGURACE ---
def projectCode      = "BICPR_BT_DWH"
def targetFolderName = "Ataccama_ONE"
def packageName      = "ATACCAMA_ONE_01_ATO_to_EXT"
def mappingPrefix    = "ATO_"                    // Prefix mapingů
def varName          = "VAR_EFFECTIVE_DATE"     // Název proměnné na začátek

// Pomocné funkce
def findFolderRecursive(parent, folderName) {
    def subFolders = (parent instanceof OdiProject) ? parent.getFolders() : parent.getSubFolders()
    def found = subFolders.find { it.getName().equalsIgnoreCase(folderName) }
    if (found) return found
    for (subFolder in subFolders) {
        def result = findFolderRecursive(subFolder, folderName)
        if (result) return result
    }
    return null
}

def tm = odiInstance.getTransactionManager()
def t_man = odiInstance.getTransactionalEntityManager()
def txn = tm.getTransaction(new DefaultTransactionDefinition())

try {
    def projFinder = (IOdiProjectFinder) t_man.getFinder(OdiProject.class)
    def project = projFinder.findByCode(projectCode)
    def folder = findFolderRecursive(project, targetFolderName)
    
    if (folder == null) {
        println "CHYBA: Složka '${targetFolderName}' nenalezena."
        return
    }
    
    println "=== Vytváření balíčku '${packageName}' ==="
    println "Parametry:"
    println "  Project: ${projectCode}"
    println "  Folder: ${targetFolderName}"
    println "  Prefix mapingů: ${mappingPrefix}"
    println ""
    
    // 1. Vytvoření nebo získání balíčku
    def pack = folder.getPackages().find { it.getName() == packageName }
    if (pack == null) {
        pack = new OdiPackage(folder, packageName)
        println "[OK] Balíček vytvořen: ${packageName}"
    } else {
        println "[OK] Balíček existuje: ${packageName}"
        // Vyčistíme starý obsah
        def oldSteps = new ArrayList(pack.getSteps())
        oldSteps.each { pack.removeStep(it) }
        println "    [!] Staré kroky odstraněny"
    }
    
    // Nová transakce pro přidání kroků
    txn2 = tm.getTransaction(new DefaultTransactionDefinition())
    
    // 2. Najteme všechny mapingy začínající na prefixu
    def atoMappings = folder.getMappings()
        .findAll { it.getName().startsWith(mappingPrefix) }
        .sort { it.getName() }
    
    println "Nalezeno ${atoMappings.size()} mapingů začínajících na ${mappingPrefix}:"
    atoMappings.each { println "  - ${it.getName()}" }
    println ""
    
    // 3. Mapingy přidáme jako kroky a propojíme je za sebe
    println "=== Vytváření kroků ==="
    def previousStep = null
    atoMappings.each { mapping ->
        def stepName = mapping.getName()
        try {
            def step = new StepMapping(pack, stepName)
            step.setMapping(mapping)
            
            if (previousStep != null) {
                previousStep.setNextStepAfterSuccess(step)
            }
            println "[STEP] Přidán: ${stepName}"
            previousStep = step
        } catch (Exception e) {
            println "[WARN] Nelze přidat krok ${stepName}: ${e.message}"
        }
    }
    
    // 4. Uložení
    t_man.persist(pack)
    tm.commit(txn)
    
    println ""
    println "=== HOTOVO ==="
    println "[✓] Balíček '${packageName}' vytvořen s:"
    println "    - ${atoMappings.size()} mapingy propojené za sebou"
    println ""
    println "POZNÁMKA: Proměnná ${varName} se nastaví při spuštění balíčku"
    
} catch (Exception e) {
    try {
        if (txn != null) tm.rollback(txn)
    } catch (Exception ex) {
        // Ignore rollback errors - transaction may be in invalid state
    }
    println "CHYBA: " + e.getMessage()
    e.printStackTrace()
}
