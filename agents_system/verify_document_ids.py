"""Verify all agent document IDs are present and correct"""
import yaml
from pathlib import Path

agents_yaml = Path(__file__).parent / 'agents.yaml'
with open(agents_yaml, 'r') as f:
    data = yaml.safe_load(f)

agents = data.get('agents', [])

print('📋 VERIFYING ALL AGENT DOCUMENT IDs')
print('='*80)
print()

missing = []
for agent in agents:
    name = agent.get('designation', 'Unknown')
    email = agent.get('email_address', 'Unknown')
    doc_id = agent.get('memory_doc_id', '')
    
    if not doc_id:
        missing.append(f'{name} ({email})')
    
    status = '✅' if doc_id else '❌'
    print(f'{status} {name:35} {email:40} {doc_id[:30] if doc_id else "MISSING"}...')

print()
if missing:
    print('❌ MISSING DOCUMENT IDs:')
    for m in missing:
        print(f'   - {m}')
    print()
    print(f'Total: {len(missing)}/{len(agents)} agents missing document IDs')
else:
    print(f'✅ All {len(agents)} agents have memory_doc_id')
    print()

