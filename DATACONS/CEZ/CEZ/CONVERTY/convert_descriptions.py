import re

# Načti soubor
with open(r'c:\Users\jkika\SQL\Obecné\převod 33', 'r', encoding='utf-8') as f:
    content = f.read()

# Regex pro nalezení @value = N'...' a převod prvního písmena na malé
def lowercase_first_letter(match):
    prefix = match.group(1)  # @value = N'
    text = match.group(2)    # text v cudzích
    suffix = match.group(3)  # '
    
    # Převeď první písmeno na malé
    if text and text[0].isupper():
        text = text[0].lower() + text[1:]
    
    return prefix + text + suffix

# Aplikuj regex - hledej @value = N'...'
pattern = r"(@value = N')([^']+)(')"
content = re.sub(pattern, lowercase_first_letter, content)

# Ulož soubor zpět
with open(r'c:\Users\jkika\SQL\Obecné\převod 33', 'w', encoding='utf-8') as f:
    f.write(content)

print('Hotovo! Všechny popisy mají teď malá písmena na začátku.')
