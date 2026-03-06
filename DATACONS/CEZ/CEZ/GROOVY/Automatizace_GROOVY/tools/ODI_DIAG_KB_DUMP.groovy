// ODI Groovy diagnostika: dump prostředí pro tvorbu znalostní báze
// Spusť v ODI Studio Groovy Script editoru.
// Výstup jde do konzole + do souboru v temp adresáři.

import java.text.SimpleDateFormat

// ===== KONFIGURACE =====
def MAX_METHODS_PER_OBJECT = 200
boolean INCLUDE_SYSTEM_PROPERTIES = true
boolean INCLUDE_ENV_VARS = false
boolean INCLUDE_STACKTRACE_ON_ERRORS = false
// ========================

def now = new Date()
def ts = new SimpleDateFormat("yyyyMMdd_HHmmss").format(now)
def outFile = new File(System.getProperty("java.io.tmpdir"), "odi_diag_kb_${ts}.txt")

def sb = new StringBuilder()

def maskIfSensitive = { String key, String value ->
    if (key == null) return value
    def k = key.toLowerCase()
    if (k.contains("password") || k.contains("passwd") || k.contains("pwd") || k.contains("secret") || k.contains("token") || k.contains("key")) {
        return "***MASKED***"
    }
    return value
}

def line = { String text ->
    sb.append(text).append("\n")
    println text
}

def section = { String title ->
    line("\n" + ("=" * 100))
    line(title)
    line(("=" * 100))
}

def listMethods = { Object obj, String label ->
    try {
        def methods = obj.getClass().methods
            .collect { m ->
                def params = m.parameterTypes.collect { it.simpleName }.join(", ")
                "${m.returnType.simpleName} ${m.name}(${params})"
            }
            .unique()
            .sort()

        line("  ${label} -> methods: ${methods.size()}")
        methods.take(MAX_METHODS_PER_OBJECT).each { m -> line("    - ${m}") }
        if (methods.size() > MAX_METHODS_PER_OBJECT) {
            line("    ... ${methods.size() - MAX_METHODS_PER_OBJECT} dalších metod zkráceno")
        }
    } catch (Exception e) {
        line("  ${label} -> ERROR při čtení metod: ${e.class.name}: ${e.message}")
        if (INCLUDE_STACKTRACE_ON_ERRORS) {
            e.stackTrace.take(10).each { st -> line("    at ${st}") }
        }
    }
}

def listProperties = { Object obj, String label ->
    try {
        def props = obj.properties?.keySet()?.collect { it.toString() }?.sort() ?: []
        line("  ${label} -> properties: ${props.size()}")
        props.each { p -> line("    - ${p}") }
    } catch (Exception e) {
        line("  ${label} -> ERROR při čtení properties: ${e.class.name}: ${e.message}")
    }
}

section("ODI DIAG KB DUMP")
line("Timestamp: ${now}")
line("User: ${System.getProperty('user.name')}")
line("Host: ${java.net.InetAddress.localHost.hostName}")
line("Java: ${System.getProperty('java.version')} (${System.getProperty('java.vendor')})")
line("OS: ${System.getProperty('os.name')} ${System.getProperty('os.version')} ${System.getProperty('os.arch')}")
line("Working dir: ${new File('.').absolutePath}")
line("Temp file: ${outFile.absolutePath}")

section("BINDING VARIABLES")
def bindingVars = []
try {
    bindingVars = binding?.variables?.keySet()?.collect { it.toString() }?.sort() ?: []
} catch (Exception e) {
    line("Nelze načíst binding.variables: ${e.class.name}: ${e.message}")
}
line("Počet binding proměnných: ${bindingVars.size()}")
bindingVars.each { v -> line(" - ${v}") }

section("BINDING OBJECT DETAILS")
bindingVars.each { name ->
    def obj = null
    try {
        obj = binding.variables[name]
    } catch (Exception e) {
        line("\n[${name}] ERROR při načtení hodnoty: ${e.class.name}: ${e.message}")
        return
    }

    if (obj == null) {
        line("\n[${name}] = null")
        return
    }

    line("\n[${name}]")
    line("  class: ${obj.getClass().name}")
    line("  toString: ${String.valueOf(obj)}")
    listProperties(obj, name)
    listMethods(obj, name)
}

section("ODI IMPORTANT OBJECTS")
def important = ["odiInstance", "odiRef", "transactionManager", "entityManager", "odiHome", "odiUser", "odiProject"]
important.each { k ->
    try {
        def v = binding?.variables?.containsKey(k) ? binding.variables[k] : null
        if (v == null) {
            line(" - ${k}: NOT PRESENT")
        } else {
            line(" - ${k}: ${v.getClass().name}")
        }
    } catch (Exception e) {
        line(" - ${k}: ERROR ${e.class.name}: ${e.message}")
    }
}

section("ODI INSTANCE DEEP CHECK")
try {
    if (binding?.variables?.containsKey("odiInstance") && binding.variables["odiInstance"] != null) {
        def odi = binding.variables["odiInstance"]
        line("odiInstance class: ${odi.getClass().name}")
        listMethods(odi, "odiInstance")

        def invoker = null
        try {
            invoker = odi.getOdiCommandInvoker()
            if (invoker != null) {
                line("odiInstance.getOdiCommandInvoker() class: ${invoker.getClass().name}")
                listMethods(invoker, "odiCommandInvoker")
            } else {
                line("odiInstance.getOdiCommandInvoker(): null")
            }
        } catch (Exception e) {
            line("odiInstance.getOdiCommandInvoker() ERROR: ${e.class.name}: ${e.message}")
        }

        try {
            def tm = odi.getTransactionManager()
            line("odiInstance.getTransactionManager() class: ${tm?.getClass()?.name}")
        } catch (Exception e) {
            line("odiInstance.getTransactionManager() ERROR: ${e.class.name}: ${e.message}")
        }

        try {
            def em = odi.getTransactionalEntityManager()
            line("odiInstance.getTransactionalEntityManager() class: ${em?.getClass()?.name}")
            if (em != null) {
                listMethods(em, "transactionalEntityManager")
            }
        } catch (Exception e) {
            line("odiInstance.getTransactionalEntityManager() ERROR: ${e.class.name}: ${e.message}")
        }
    } else {
        line("odiInstance není v bindingu dostupná.")
    }
} catch (Exception e) {
    line("ODI INSTANCE DEEP CHECK ERROR: ${e.class.name}: ${e.message}")
}

section("KNOWN ODI CLASSES AVAILABILITY")
def classCandidates = [
    "oracle.odi.core.OdiInstance",
    "oracle.odi.runtime.agent.invocation.RemoteRuntimeAgentInvoker",
    "oracle.odi.runtime.agent.invocation.StartupParams",
    "oracle.odi.runtime.agent.invocation.StartupParams$StartupParamsBuilder",
    "oracle.odi.domain.runtime.scenario.OdiScenario",
    "oracle.odi.domain.runtime.scenario.finder.IOdiScenarioFinder",
    "oracle.odi.domain.topology.OdiContext",
    "oracle.odi.domain.topology.finder.IOdiContextFinder",
    "oracle.odi.domain.runtime.agent.OdiLogicalAgent",
    "oracle.odi.domain.runtime.agent.finder.IOdiLogicalAgentFinder"
]
classCandidates.each { cn ->
    try {
        def c = Class.forName(cn)
        line(" + ${cn} [OK]")
        def ctors = c.declaredConstructors.collect { it.toString() }.sort()
        ctors.take(20).each { cc -> line("    ctor: ${cc}") }
        if (ctors.size() > 20) {
            line("    ... ${ctors.size() - 20} dalších konstruktorů zkráceno")
        }
    } catch (ClassNotFoundException e) {
        line(" - ${cn} [NOT FOUND]")
    } catch (Exception e) {
        line(" - ${cn} [ERROR ${e.class.name}: ${e.message}]")
    }
}

if (INCLUDE_SYSTEM_PROPERTIES) {
    section("SYSTEM PROPERTIES")
    def keys = System.properties.keySet().collect { it.toString() }.sort()
    keys.each { k ->
        def v = String.valueOf(System.getProperty(k))
        line("${k}=${maskIfSensitive(k, v)}")
    }
}

if (INCLUDE_ENV_VARS) {
    section("ENV VARIABLES")
    def envKeys = System.getenv().keySet().collect { it.toString() }.sort()
    envKeys.each { k ->
        def v = String.valueOf(System.getenv(k))
        line("${k}=${maskIfSensitive(k, v)}")
    }
}

section("CLASSPATH")
def cp = System.getProperty("java.class.path") ?: ""
cp.split(File.pathSeparator).each { p -> line(p) }

section("END")
line("Report lines: ${sb.toString().readLines().size()}")

try {
    outFile.parentFile?.mkdirs()
    outFile.setText(sb.toString(), "UTF-8")
    println "\nReport uložen: ${outFile.absolutePath}"
} catch (Exception e) {
    println "\nChyba při ukládání reportu: ${e.class.name}: ${e.message}"
}

return sb.toString()
