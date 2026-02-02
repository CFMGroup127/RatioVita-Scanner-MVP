"""
Check agent memory documents for task completion status
"""
import os
import yaml
from pathlib import Path
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build

def get_credentials():
    """Get Google API credentials"""
    SCOPES = ['https://www.googleapis.com/auth/documents.readonly']
    
    creds = None
    token_path = Path(__file__).parent / 'token.json'
    credentials_path = Path(__file__).parent / 'credentials.json'
    
    if token_path.exists():
        try:
            creds = Credentials.from_authorized_user_file(str(token_path), SCOPES)
            if creds and creds.expired and creds.refresh_token:
                creds.refresh(Request())
        except:
            creds = None
    
    if not creds or not creds.valid:
        return None
    
    return creds

def check_memory_document(doc_id, agent_name):
    """Check memory document for task entries"""
    creds = get_credentials()
    if not creds:
        return None
    
    try:
        docs_service = build('docs', 'v1', credentials=creds)
        doc = docs_service.documents().get(documentId=doc_id).execute()
        
        # Extract text
        content = []
        if 'body' in doc and 'content' in doc['body']:
            for element in doc['body']['content']:
                if 'paragraph' in element:
                    para = element['paragraph']
                    if 'elements' in para:
                        for elem in para['elements']:
                            if 'textRun' in elem:
                                content.append(elem['textRun'].get('content', ''))
        
        doc_text = '\n'.join(content)
        
        # Check for task-related content
        tasks_found = []
        lines = doc_text.split('\n')
        in_tasks = False
        
        for i, line in enumerate(lines):
            if 'TASKS' in line.upper() and ('#' in line or line.strip().upper() == 'TASKS'):
                in_tasks = True
                continue
            
            if in_tasks and line.strip().startswith('#') and 'TASKS' not in line.upper():
                if any(x in line.upper() for x in ['PROTOCOLS', 'MEETINGS', 'REPORTS']):
                    break
            
            if in_tasks:
                # Look for our specific tasks
                if 'URGENT FIX' in line or 'authenticated logging hook' in line.lower():
                    tasks_found.append(('URGENT FIX', line.strip(), i))
                if 'compliance strategy' in line.lower() and 'Feature 7' in line:
                    tasks_found.append(('Compliance Strategy', line.strip(), i))
                if 'legal risk assessment' in line.lower():
                    tasks_found.append(('Legal Risk Assessment', line.strip(), i))
                if 'P3 Hybrid System Validation' in line or 'TEST: P3' in line:
                    tasks_found.append(('P3 Validation', line.strip(), i))
        
        return {
            'agent': agent_name,
            'doc_id': doc_id,
            'tasks_found': tasks_found,
            'has_tasks_section': in_tasks or 'TASKS' in doc_text.upper(),
            'text_length': len(doc_text)
        }
    except Exception as e:
        return {'agent': agent_name, 'error': str(e)}

def main():
    """Check all relevant agent memory documents"""
    print("\n" + "="*80)
    print("🔍 CHECKING AGENT MEMORY DOCUMENTS FOR TASK PROGRESS")
    print("="*80)
    print()
    
    # Load agents
    yaml_path = Path(__file__).parent / 'agents.yaml'
    with open(yaml_path, 'r') as f:
        data = yaml.safe_load(f)
    
    # Find relevant agents
    agents_to_check = []
    for agent in data.get('agents', []):
        role = agent.get('role', '')
        if 'Lead Code Execution' in role or 'Legal Compliance' in role:
            agents_to_check.append({
                'name': agent.get('name', role),
                'role': role,
                'doc_id': agent.get('memory_doc_id', ''),
                'email': agent.get('email_address', '')
            })
    
    print(f"📋 Checking {len(agents_to_check)} agents...")
    print()
    
    results = []
    for agent_info in agents_to_check:
        if not agent_info['doc_id']:
            print(f"⚠️  {agent_info['name']}: No memory doc ID")
            continue
        
        print(f"🔍 Checking {agent_info['name']} ({agent_info['role']})...")
        result = check_memory_document(agent_info['doc_id'], agent_info['name'])
        results.append(result)
        
        if result is None:
            print(f"   ❌ Error: Could not access document")
        elif 'error' in result:
            print(f"   ❌ Error: {result['error']}")
        else:
            print(f"   ✅ Document accessed ({result['text_length']:,} chars)")
            if result['tasks_found']:
                print(f"   📋 Found {len(result['tasks_found'])} task references:")
                for task_name, task_line, line_num in result['tasks_found']:
                    print(f"      - {task_name}: {task_line[:60]}...")
            else:
                print(f"   ⚠️  No task references found")
        print()
    
    # Summary
    print("="*80)
    print("📊 SUMMARY")
    print("="*80)
    print()
    
    total_tasks = sum(len(r.get('tasks_found', [])) for r in results if 'tasks_found' in r)
    print(f"Total task references found: {total_tasks}")
    print()
    
    for result in results:
        if 'tasks_found' in result:
            print(f"{result['agent']}: {len(result['tasks_found'])} task(s) found")
    
    print()
    print("="*80)

if __name__ == "__main__":
    main()

