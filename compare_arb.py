import json
import os

en_path = r'D:\R0V0.0.1\lib\l10n\app_en.arb'
fr_path = r'D:\R0V0.0.1\lib\l10n\app_fr.arb'

with open(en_path, 'r', encoding='utf-8') as f:
    en_data = json.load(f)

with open(fr_path, 'r', encoding='utf-8') as f:
    fr_data = json.load(f)

en_keys = set(en_data.keys())
fr_keys = set(fr_data.keys())

# Remove metadata keys starting with @
en_keys = {k for k in en_keys if not k.startswith('@') and k != '@@locale'}
fr_keys = {k for k in fr_keys if not k.startswith('@') and k != '@@locale'}

only_en = en_keys - fr_keys
only_fr = fr_keys - en_keys

print(f"Keys only in EN: {len(only_en)}")
for k in sorted(only_en):
    print(f"  - {k}")

print(f"\nKeys only in FR: {len(only_fr)}")
for k in sorted(only_fr):
    print(f"  - {k}")
