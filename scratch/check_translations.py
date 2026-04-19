import json

def compare_arbs(en_path, fr_path):
    with open(en_path, 'r', encoding='utf-8') as f:
        en = json.load(f)
    with open(fr_path, 'r', encoding='utf-8') as f:
        fr = json.load(f)
    
    missing_in_fr = []
    missing_in_en = []
    same_value = []
    
    for key in en:
        if key.startswith('@'): continue
        if key not in fr:
            missing_in_fr.append(key)
        elif en[key] == fr[key] and en[key].strip() != "" and not en[key].isdigit():
            # Exclude some technical terms or names that might intentionally be the same
            if key not in ['appTitle', 'oibEe', 'pb30', 'park1', 'park2', 'park3', 'normal', 'oceane']:
                same_value.append((key, en[key]))
                
    for key in fr:
        if key.startswith('@'): continue
        if key not in en:
            missing_in_en.append(key)
            
    print(f"Missing in FR: {len(missing_in_fr)}")
    for k in missing_in_fr: print(f"  - {k}")
    
    print(f"\nMissing in EN: {len(missing_in_en)}")
    for k in missing_in_en: print(f"  - {k}")
    
    print(f"\nSame value in EN and FR (potentially untranslated): {len(same_value)}")
    for k, v in same_value: print(f"  - {k}: {v}")

compare_arbs('d:/R0V0.0.1/lib/l10n/app_en.arb', 'd:/R0V0.0.1/lib/l10n/app_fr.arb')
