import csv
from pathlib import Path

src = Path(r"c:\Users\jkika\SQL\ADAPTACE_01\metadata")
backup = src.with_suffix('.bak')
if not src.exists():
    raise SystemExit(f"File not found: {src}")

# Backup
backup.write_bytes(src.read_bytes())

rows = []
with src.open(newline='') as f:
    reader = csv.reader(f)
    for r in reader:
        # Expect at least 3 fields: table_name, column_id, column_name, ... , column_comment
        if len(r) >= 3:
            col_name = r[2]
            # If comment already present and non-empty, keep it
            existing = r[-1].strip()
            if existing == '':
                # Create a Czech comment based on column name
                # Basic transformations for readability
                comment = f"Atribut {col_name}"
                # Small common-name improvements
                mapping = {
                    'id': 'Primární identifikátor',
                    'created_at': 'Datum vytvoření záznamu',
                    'created_by': 'Uživatel, který záznam vytvořil',
                    'modified_at': 'Datum poslední úpravy záznamu',
                    'modified_by': 'Uživatel, který záznam upravil',
                    'name': 'Název',
                    'label': 'Značka / popisek',
                    'description': 'Popis',
                    'email': 'E-mail',
                    'first_name': 'Jméno',
                    'surname': 'Příjmení',
                    'full_name': 'Celé jméno',
                    'state_id': 'Stav (kód)',
                    'validity_start': 'Platnost - začátek',
                    'validity_end': 'Platnost - konec',
                    'deadline': 'Termín / Datum splnění',
                    'date': 'Datum',
                    'created_at': 'Datum vytvoření',
                    'modified_at': 'Datum úpravy',
                }
                key = col_name.lower()
                if key in mapping:
                    comment = mapping[key]
                else:
                    # Replace underscores with spaces for readability
                    comment = 'Atribut: ' + col_name.replace('_', ' ')
                r[-1] = comment
        rows.append(r)

# Write back CSV (preserve quoting minimal)
with src.open('w', newline='') as f:
    writer = csv.writer(f, quoting=csv.QUOTE_MINIMAL)
    writer.writerows(rows)

print(f"Backed up original to {backup} and updated {src}")
