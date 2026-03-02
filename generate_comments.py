import csv
import os

INPUT = os.path.join(os.getcwd(), "ATACAMA ONE", "metadata.csv")
BACKUP = INPUT + ".bak"

TOKEN_MAP = {
    'id': 'Identifikátor',
    'name': 'Název',
    'last': 'Poslední',
    'change': 'Změna',
    'created': 'Datum/čas vytvoření',
    'datetime': 'Datum/čas',
    'author': 'Autor',
    'status': 'Stav',
    'description': 'Popis',
    'business': 'Obchodní',
    'definition': 'Definice',
    'abbreviation': 'Zkratka',
    'attachments': 'Přílohy',
    'owner': 'Vlastník',
    'note': 'Poznámka',
    'url': 'Odkaz (URL)',
    'parent': 'ID rodiče',
    'number': 'Počet',
    'count': 'Počet',
    'email': 'Email',
    'username': 'Uživatelské jméno',
    'user': 'Uživatel',
    'group': 'Skupina',
    'guid': 'Globálně unikátní identifikátor (GUID)',
    'type': 'Typ',
    'priority': 'Priorita',
    'duration': 'Doba trvání',
    'error': 'Chyba',
    'reason': 'Důvod',
    'author_num_id': 'Číselný identifikátor autora',
    'author_user_id': 'ID uživatele - autor',
    'stewardship': 'Správa (stewardship)',
}


def humanize_column(col):
    tokens = [t.strip() for t in col.replace('-', '_').split('_') if t.strip()]
    tokens_l = [t.lower() for t in tokens]

    # common special-cases
    if col.upper() == 'ID':
        return 'Identifikátor záznamu'
    if 'id' in tokens_l and len(tokens_l) == 1:
        return 'Identifikátor'
    if 'last' in tokens_l and 'change' in tokens_l:
        return 'Datum/čas poslední změny'
    if 'created' in tokens_l:
        return 'Datum/čas vytvoření'
    if 'datetime' in tokens_l:
        return 'Datum/čas'
    if 'name' in tokens_l:
        return 'Název'
    if 'description' in tokens_l or 'decsription' in tokens_l or 'desc' in tokens_l:
        return 'Popis'

    # token map lookup
    mapped = []
    for t in tokens_l:
        if t in TOKEN_MAP:
            mapped.append(TOKEN_MAP[t])
        else:
            # try to map combined tokens like 'business_definition'
            combined = '_'.join(tokens_l)
            if combined in TOKEN_MAP:
                mapped = [TOKEN_MAP[combined]]
                break
            # fallback: capitalize token (leave English words as-is)
            mapped.append(t.capitalize())
    return ' '.join(mapped)


def generate_comment(row):
    col = row.get('column_name', '')
    is_pk = row.get('is_primary_key', '').strip()
    col_lower = col.lower()

    if not col:
        return ''

    # exact matches first
    if col_upper := col.upper():
        if col_upper == 'ID':
            if is_pk in ('1', 'True', 'true'):
                return 'Primární identifikátor záznamu'
            return 'Identifikátor'

    # known full-name tokens
    if col_lower in ('last_change', 'lastchange'):
        return 'Datum/čas poslední změny'
    if 'business_definition' in col_lower:
        return 'Obchodní definice'
    if 'business_term' in col_lower:
        return 'Obchodní termín'

    # generic heuristics
    if 'url' in col_lower:
        return 'Odkaz (URL)'
    if 'email' in col_lower:
        return 'Email'
    if 'attachment' in col_lower or 'attachments' in col_lower:
        return 'Přílohy'
    if 'abbreviation' in col_lower:
        return 'Zkratka'
    if 'note' in col_lower:
        return 'Poznámka'
    if 'author_user_id' in col_lower:
        return 'ID uživatele - autor'
    if 'author_num_id' in col_lower:
        return 'Číselný identifikátor autora'
    if 'stewardship' in col_lower:
        return 'Správa (stewardship)'
    if 'status' in col_lower:
        return 'Stav'
    if 'parent_id' in col_lower or ("parent" in col_lower and "id" in col_lower):
        return 'ID rodiče'

    # fallback humanized
    return humanize_column(col)


def main():
    if not os.path.isfile(INPUT):
        print('Nenalezen soubor:', INPUT)
        return

    # make backup
    if not os.path.exists(BACKUP):
        os.replace(INPUT, BACKUP)
        src_path = BACKUP
    else:
        # if backup already exists, read from original and create another backup copy
        src_path = BACKUP

    rows = []
    with open(src_path, newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        for r in reader:
            rows.append(r)

    changed = 0
    for r in rows:
        comment = r.get('column_comment', '')
        if comment is None or comment.strip() == '':
            gen = generate_comment(r)
            r['column_comment'] = gen
            changed += 1

    # write output (overwrite original path)
    with open(INPUT, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, quoting=csv.QUOTE_ALL)
        writer.writeheader()
        for r in rows:
            writer.writerow(r)

    print(f'Hotovo. Upravených sloupců: {changed}. Záloha: {BACKUP}')


if __name__ == '__main__':
    main()
