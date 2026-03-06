import re

file = r"c:\Users\jkika\SQL\převod komentářů\zadání 2"
with open(file, 'r', encoding='utf-8') as f:
    text = f.read()

# Replace all @level*name values with lowercase
pattern = r"(@level[0-2]name\s*=\s*N')([^']+)(')"
result = re.sub(pattern, lambda m: m.group(1) + m.group(2).lower() + m.group(3), text)

with open(file, 'w', encoding='utf-8') as f:
    f.write(result)

print("All @level*name values converted to lowercase")
