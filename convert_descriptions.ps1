$filePath = "c:\Users\jkika\SQL\Obecné\převod 33"
$content = Get-Content $filePath -Raw -Encoding UTF8

# Nahrad všechny descriptions - konvertuj první písmeno na malé
$content = $content -replace "(@value = N')([A-ZČŘŠŽÝÁÍÉ])([^']*)'", {
    $prefix = $_.Groups[1].Value  # @value = N'
    $firstChar = $_.Groups[2].Value.ToLower()  # Převeď první písmeno na malé
    $rest = $_.Groups[3].Value
    $prefix + $firstChar + $rest + "'"
}

Set-Content $filePath $content -Encoding UTF8
Write-Host "Hotovo! Všechny popisy mají teď malá písmena na začátku."
