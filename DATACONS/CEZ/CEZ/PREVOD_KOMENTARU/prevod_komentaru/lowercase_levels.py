import sys
import re
from pathlib import Path

if len(sys.argv) < 2:
    print('Usage: lowercase_levels.py <file>')
    sys.exit(1)

p = Path(sys.argv[1])
text = p.read_text(encoding='utf-8')

# regex matches @level0name, @level1name, @level2name with values
pattern = re.compile(r"(@level[0-2]name\s*=\s*)(N?')(.*?)(')", re.IGNORECASE)

def repl(m):
    prefix = m.group(1)
    nquote = m.group(2)
    val = m.group(3)
    quote = m.group(4)
    return prefix + nquote + val.lower() + quote

new = pattern.sub(repl, text)

# write new
p.write_text(new, encoding='utf-8')
print('Processed', p)
print('All @level*name values converted to lowercase')
