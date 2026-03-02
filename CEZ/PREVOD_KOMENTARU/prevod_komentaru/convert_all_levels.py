#!/usr/bin/env python3
import re

file = r"c:\Users\jkika\SQL\převod komentářů\zadání 2"

with open(file, 'r', encoding='utf-8') as f:
    text = f.read()

# Replace all @level[0-2]name uppercase values with lowercase
pattern = r"(@level[0-2]name\s*=\s*N')([A-Z_0-9]+)(')"
result = re.sub(pattern, lambda m: m.group(1) + m.group(2).lower() + m.group(3), text)

# Count changes
orig_matches = len(re.findall(pattern, text))

with open(file, 'w', encoding='utf-8') as f:
    f.write(result)

print(f"Converted {orig_matches} @level*name values to lowercase")
