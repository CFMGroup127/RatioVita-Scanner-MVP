"""
Comprehensive task verification script
Checks Google Tasks, agent memory documents, and completion logs
"""
import os
import yaml
from pathlib import Path
from datetime import datetime
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

def get_credentials():
    """Get Google API credentials"""
    SCOPES = [
        'https://www.googleapis.com/auth/documents.readonly',
        'https://www.googleapis.com/auth/tasks.readonly',
        'https://www.googleapis.com/auth/drive.readonly'
    ]
    
    creds = None
    token_path = Path(__file__).parent / 'token.json'
    
    # Try to find token.json in various locations
    possible_paths = [
        token_path,
        Path(__file__).parent.parent / 'token.json',
        Path.home() / '.config' / 'google' / 'token.json'
    ]
    
    for path in possible_paths:
        if path.exists():
            try:
                # Try with scopes first
                creds = Credentials.from_authorized_user_file(str(path), SCOPES)
                if creds and creds.expired and creds.refresh_token:
                    try:
                        creds.refresh(Request())
                    except:
                        pass
                if creds and creds.valid:
                    return creds
            except:
                try:
                    # Try without scope restriction (token may have all scopes)
                    creds = Credentials.from_authorized_user_file(str(path), None)
                    if creds and creds.expired and creds.refresh_token:
                        try:
                            creds.refresh(Request())
                        except:
                            pass
                    if creds and creds.valid:
                        return creds
                except:
                    pass
    
    return None

def check_google_tasks(creds):
    """Check Google Tasks for our tasks"""
    print("\n📋 CHECKING GOOGLE TASKS")
    print("="*80)
    
    target_tasks = [
        "URGENT FIX: Implement authenticated logging hook",
        "Draft compliance strategy for Feature 7",
        "Draft legal risk assessment",
        "TEST: P3 Hybrid System Validation"
    ]
    
    try:
        tasks_service = build('tasks', 'v1', credentials=creds)
        tasklists = tasks_service.tasklists().list().execute()
        
        default_list_id = None
        for tasklist in tasklists.get('items', []):
            if tasklist.get('id') == '@default' or 'default' in tasklist.get('title', '').lower():
                default_list_id = tasklist.get('id')
                break
        
        if not default_list_id and tasklists.get('items'):
            default_list_id = tasklists['items'][0]['id']
        
        if not default_list_id:
            print("⚠️  No default task list found")
            return {}
        
        all_tasks = tasks_service.tasks().list(tasklist=default_list_id, showCompleted=True).execute()
        
        found_tasks = {}
        for task in all_tasks.get('items', []):
            title = task.get('title', '')
            for target in target_tasks:
                if target.lower() in title.lower():
                    found_tasks[target] = {
                        'title': title,
                        'status': task.get('status', 'needsAction'),
                        'due': task.get('due', ''),
                        'notes': task.get('notes', ''),
                        'updated': task.get('updated', '')
                    }
                    break
        
        print(f"✅ Found {len(found_tasks)}/{len(target_tasks)} target tasks in Google Tasks")
        print()
        
        for target, task_info in found_tasks.items():
            status_icon = "✅" if task_info['status'] == 'completed' else "⏳"
            print(f"{status_icon} {target}")
            print(f"   Status: {task_info['status'].upper()}")
            if task_info['due']:
                print(f"   Due: {task_info['due'][:10]}")
            if task_info['updated']:
                print(f"   Updated: {task_info['updated'][:19]}")
            print()
        
        return found_tasks
        
    except HttpError as e:
        print(f"❌ Error accessing Google Tasks: {e}")
        return {}
    except Exception as e:
        print(f"❌ Error: {e}")
        return {}

def check_memory_documents(creds):
    """Check agent memory documents for task entries"""
    print("\n📄 CHECKING AGENT MEMORY DOCUMENTS")
    print("="*80)
    
    # Load agents
    yaml_path = Path(__file__).parent / 'agents.yaml'
    with open(yaml_path, 'r') as f:
        data = yaml.safe_load(f)
    
    target_tasks = [
        "URGENT FIX",
        "authenticated logging hook",
        "compliance strategy",
        "Feature 7",
        "legal risk assessment",
        "P3 Hybrid System Validation"
    ]
    
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
    
    results = {}
    
    try:
        docs_service = build('docs', 'v1', credentials=creds)
    except Exception as e:
        print(f"❌ Error building Docs service: {e}")
        return {}
    
    for agent_info in agents_to_check:
        if not agent_info['doc_id']:
            continue
        
        print(f"🔍 Checking {agent_info['name']} ({agent_info['role']})...")
        
        try:
            doc = docs_service.documents().get(documentId=agent_info['doc_id']).execute()
            
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
            
            # Check for task references
            found_tasks = []
            for target in target_tasks:
                if target.lower() in doc_text.lower():
                    # Find context around the match
                    lines = doc_text.split('\n')
                    for i, line in enumerate(lines):
                        if target.lower() in line.lower():
                            context = line.strip()[:80]
                            found_tasks.append((target, context))
                            break
            
            if found_tasks:
                print(f"   ✅ Found {len(found_tasks)} task reference(s):")
                for task_name, context in found_tasks:
                    print(f"      - {task_name}: {context}...")
            else:
                print(f"   ⚠️  No task references found")
            
            results[agent_info['name']] = {
                'tasks_found': len(found_tasks),
                'has_content': len(doc_text) > 0
            }
            
        except HttpError as e:
            print(f"   ❌ Error accessing document: {e}")
            results[agent_info['name']] = {'error': str(e)}
        except Exception as e:
            print(f"   ❌ Error: {e}")
            results[agent_info['name']] = {'error': str(e)}
        
        print()
    
    return results

def check_completion_logs():
    """Check completion logs from execution"""
    print("\n📊 CHECKING COMPLETION LOGS")
    print("="*80)
    
    log_files = [
        'p3_p4_execution_20251204_025829.log',
        'retry_failed_tasks.log',
        'p3_p4_execution_monitored.log'
    ]
    
    summary_files = [f for f in os.listdir('.') if f.startswith('P3_P4_EXECUTION_SUMMARY_')]
    
    print(f"📄 Found {len(summary_files)} summary file(s)")
    if summary_files:
        latest = sorted(summary_files)[-1]
        print(f"   Latest: {latest}")
        print()
        
        try:
            with open(latest, 'r') as f:
                content = f.read()
                if 'Successfully processed' in content:
                    for line in content.split('\n'):
                        if 'Successfully processed' in line or 'Failed:' in line:
                            print(f"   {line.strip()}")
        except:
            pass
    
    print()
    print(f"📄 Log files found: {len([f for f in log_files if os.path.exists(f)])}/{len(log_files)}")
    for log_file in log_files:
        if os.path.exists(log_file):
            size = os.path.getsize(log_file)
            print(f"   ✅ {log_file} ({size:,} bytes)")

def main():
    """Main verification function"""
    print("\n" + "="*80)
    print("🔍 COMPREHENSIVE TASK VERIFICATION")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}")
    print()
    
    # Get credentials
    print("🔐 Getting credentials...")
    creds = get_credentials()
    if not creds:
        print("❌ Error: Could not get credentials")
        print("   Please run: python3 fix_oauth_full_permissions.py")
        return
    
    print("✅ Credentials obtained")
    
    # Check Google Tasks
    google_tasks = check_google_tasks(creds)
    
    # Check memory documents
    memory_docs = check_memory_documents(creds)
    
    # Check completion logs
    check_completion_logs()
    
    # Summary
    print("\n" + "="*80)
    print("📊 VERIFICATION SUMMARY")
    print("="*80)
    print()
    print(f"✅ Google Tasks: {len(google_tasks)}/4 tasks found")
    print(f"✅ Memory Documents: {len([r for r in memory_docs.values() if r.get('tasks_found', 0) > 0])} agents with task references")
    print()
    print("="*80)

if __name__ == "__main__":
    main()

