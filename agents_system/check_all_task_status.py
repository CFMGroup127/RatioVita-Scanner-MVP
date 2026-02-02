"""
Comprehensive Task Status Check
Checks all tasks across agents' memory documents and Google Tasks.
"""
import os
import sys
import yaml
from pathlib import Path
from datetime import datetime
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

def get_credentials():
    """Get Google API credentials"""
    SCOPES = [
        'https://www.googleapis.com/auth/documents',
        'https://www.googleapis.com/auth/drive.readonly',
        'https://www.googleapis.com/auth/gmail.readonly',
        'https://www.googleapis.com/auth/calendar.readonly',
        'https://www.googleapis.com/auth/tasks',
        'https://www.googleapis.com/auth/tasks.readonly'
    ]
    
    creds = None
    if os.path.exists('token.json'):
        try:
            creds = Credentials.from_authorized_user_file('token.json', SCOPES)
        except:
            pass
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            try:
                creds.refresh(Request())
            except:
                pass
        else:
            if os.path.exists('credentials.json'):
                flow = InstalledAppFlow.from_client_secrets_file('credentials.json', SCOPES)
                creds = flow.run_local_server(port=0, access_type='offline', prompt='consent')
            else:
                return None
        
        if creds:
            with open('token.json', 'w') as token:
                token.write(creds.to_json())
    
    return creds

def get_agent_metadata():
    """Get metadata for all agents"""
    yaml_path = Path(__file__).parent / 'agents.yaml'
    with open(yaml_path, 'r') as f:
        data = yaml.safe_load(f)
    return data.get('agents', [])

def check_google_tasks(creds):
    """Check all tasks in Google Tasks"""
    print("📋 CHECKING GOOGLE TASKS...")
    print("="*80)
    
    tasks_by_date = {}
    all_tasks = []
    
    try:
        tasks_service = build('tasks', 'v1', credentials=creds)
        
        # Get all task lists
        tasklists = tasks_service.tasklists().list().execute()
        
        for tasklist in tasklists.get('items', []):
            list_id = tasklist.get('id')
            list_title = tasklist.get('title', 'Unknown')
            
            try:
                # Get all tasks (including completed)
                tasks = tasks_service.tasks().list(
                    tasklist=list_id,
                    showCompleted=True,
                    showHidden=True
                ).execute()
                
                for task in tasks.get('items', []):
                    task_title = task.get('title', '')
                    task_status = task.get('status', 'needsAction')
                    due_date = task.get('due', '')
                    notes = task.get('notes', '')
                    
                    task_info = {
                        'title': task_title,
                        'status': task_status,
                        'due_date': due_date,
                        'list': list_title,
                        'notes': notes,
                        'id': task.get('id')
                    }
                    
                    all_tasks.append(task_info)
                    
                    # Group by due date
                    if due_date:
                        date_key = due_date[:10]  # YYYY-MM-DD
                        if date_key not in tasks_by_date:
                            tasks_by_date[date_key] = []
                        tasks_by_date[date_key].append(task_info)
                    else:
                        if 'no_date' not in tasks_by_date:
                            tasks_by_date['no_date'] = []
                        tasks_by_date['no_date'].append(task_info)
            
            except Exception as e:
                print(f"   ⚠️  Error reading tasks from {list_title}: {e}")
                continue
        
        print(f"   ✅ Found {len(all_tasks)} total tasks")
        print(f"   📅 Tasks with dates: {sum(len(v) for k, v in tasks_by_date.items() if k != 'no_date')}")
        print(f"   📅 Tasks without dates: {len(tasks_by_date.get('no_date', []))}")
        print()
        
    except HttpError as e:
        if e.resp.status == 403:
            print("   ⚠️  Google Tasks API access denied (OAuth scope issue)")
            print("   Continuing with memory document check only...")
            print()
        else:
            print(f"   ⚠️  Error accessing Google Tasks: {e}")
            print()
    except Exception as e:
        print(f"   ⚠️  Error: {e}")
        print()
    
    return all_tasks, tasks_by_date

def extract_tasks_from_doc(doc_content):
    """Extract tasks from document content"""
    tasks = []
    lines = doc_content.split('\n')
    
    in_tasks_section = False
    for i, line in enumerate(lines):
        # Check if we're in TASKS section
        if 'TASKS' in line.upper() and ('#' in line or line.strip().upper() == 'TASKS'):
            in_tasks_section = True
            continue
        
        # Check if we've left TASKS section
        if in_tasks_section and line.strip().startswith('#') and 'TASKS' not in line.upper():
            if 'PROTOCOLS' in line.upper() or 'MEETINGS' in line.upper() or 'REPORTS' in line.upper():
                break
        
        if in_tasks_section:
            # Look for task markers
            if '- [ ]' in line or '- [x]' in line or '- [X]' in line:
                is_complete = '- [x]' in line.lower() or '- [X]' in line
                task_text = line.replace('- [ ]', '').replace('- [x]', '').replace('- [X]', '').strip()
                
                if task_text:
                    tasks.append({
                        'text': task_text,
                        'complete': is_complete,
                        'line': i + 1
                    })
    
    return tasks

def check_memory_documents(creds):
    """Check tasks in all agent memory documents"""
    print("📄 CHECKING MEMORY DOCUMENTS...")
    print("="*80)
    
    docs_service = build('docs', 'v1', credentials=creds)
    agents_data = get_agent_metadata()
    
    all_memory_tasks = {}
    
    for agent_data in agents_data:
        agent_name = agent_data.get('name', '')
        agent_role = agent_data.get('role', '')
        memory_doc_id = agent_data.get('memory_doc_id', '')
        
        if not memory_doc_id:
            continue
        
        try:
            doc = docs_service.documents().get(documentId=memory_doc_id).execute()
            
            # Extract text content
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
            tasks = extract_tasks_from_doc(doc_text)
            
            if tasks:
                all_memory_tasks[agent_name] = {
                    'role': agent_role,
                    'tasks': tasks,
                    'pending': [t for t in tasks if not t['complete']],
                    'completed': [t for t in tasks if t['complete']]
                }
                print(f"   {agent_name}: {len(tasks)} tasks ({len([t for t in tasks if not t['complete']])} pending)")
        
        except Exception as e:
            print(f"   ⚠️  {agent_name}: Error - {e}")
            continue
    
    print()
    return all_memory_tasks

def check_specific_tasks(target_tasks, google_tasks, memory_tasks):
    """Check status of specific tasks"""
    print("🎯 CHECKING SPECIFIC TASKS...")
    print("="*80)
    print()
    
    results = {}
    
    for target_task in target_tasks:
        task_name = target_task.get('name', '')
        due_date = target_task.get('due_date', '')
        
        result = {
            'task_name': task_name,
            'due_date': due_date,
            'google_tasks_status': None,
            'memory_document_status': None,
            'found_in': []
        }
        
        # Check Google Tasks
        for gt in google_tasks:
            if task_name.lower() in gt['title'].lower() or gt['title'].lower() in task_name.lower():
                result['google_tasks_status'] = {
                    'found': True,
                    'status': gt['status'],
                    'title': gt['title'],
                    'due_date': gt['due_date']
                }
                result['found_in'].append('Google Tasks')
                break
        
        # Check Memory Documents
        for agent_name, agent_tasks in memory_tasks.items():
            for task in agent_tasks['tasks']:
                if task_name.lower() in task['text'].lower() or task['text'].lower() in task_name.lower():
                    result['memory_document_status'] = {
                        'found': True,
                        'agent': agent_name,
                        'complete': task['complete'],
                        'text': task['text']
                    }
                    result['found_in'].append(f"Memory: {agent_name}")
                    break
        
        results[task_name] = result
    
    return results

def generate_status_report(google_tasks, memory_tasks, specific_tasks_status):
    """Generate comprehensive status report"""
    report = f"""
# COMPREHENSIVE TASK STATUS REPORT
**Generated:** {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}
**Report Type:** Full Task Status Check

---

## 📋 SPECIFIC TASKS STATUS

"""
    
    for task_name, status in specific_tasks_status.items():
        report += f"""
### {task_name}
**Due Date:** {status.get('due_date', 'Not specified')}

**Status:**
"""
        if status['google_tasks_status']:
            gt_status = status['google_tasks_status']
            status_icon = "✅" if gt_status['status'] == 'completed' else "⏳"
            report += f"- {status_icon} **Google Tasks:** {gt_status['status'].upper()} - {gt_status['title']}\n"
        else:
            report += "- ❌ **Google Tasks:** Not found\n"
        
        if status['memory_document_status']:
            mem_status = status['memory_document_status']
            status_icon = "✅" if mem_status['complete'] else "⏳"
            report += f"- {status_icon} **Memory Document:** {mem_status['agent']} - {'COMPLETE' if mem_status['complete'] else 'PENDING'}\n"
        else:
            report += "- ❌ **Memory Document:** Not found\n"
        
        if status['found_in']:
            report += f"- 📍 **Found in:** {', '.join(status['found_in'])}\n"
        else:
            report += "- ⚠️  **NOT FOUND** in any system\n"
        
        report += "\n"
    
    # Google Tasks Summary
    pending_gt = [t for t in google_tasks if t['status'] != 'completed']
    completed_gt = [t for t in google_tasks if t['status'] == 'completed']
    
    report += f"""
---

## 📊 GOOGLE TASKS SUMMARY

- **Total Tasks:** {len(google_tasks)}
- **Pending:** {len(pending_gt)}
- **Completed:** {len(completed_gt)}

### Pending Tasks:
"""
    for task in pending_gt[:20]:  # Limit to 20
        due_str = task['due_date'][:10] if task['due_date'] else 'No due date'
        report += f"- ⏳ {task['title']} (Due: {due_str})\n"
    
    # Memory Documents Summary
    total_pending_mem = sum(len(agent['pending']) for agent in memory_tasks.values())
    total_completed_mem = sum(len(agent['completed']) for agent in memory_tasks.values())
    
    report += f"""
---

## 📄 MEMORY DOCUMENTS SUMMARY

- **Agents with Tasks:** {len(memory_tasks)}
- **Total Pending:** {total_pending_mem}
- **Total Completed:** {total_completed_mem}

### Agents with Pending Tasks:
"""
    for agent_name, agent_data in memory_tasks.items():
        if agent_data['pending']:
            report += f"\n**{agent_name}** ({agent_data['role']}):\n"
            for task in agent_data['pending'][:5]:  # Limit to 5 per agent
                report += f"- ⏳ {task['text'][:100]}...\n"
    
    return report

def main():
    """Main status check function"""
    print("\n" + "="*80)
    print("📊 COMPREHENSIVE TASK STATUS CHECK")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    # Get credentials
    creds = get_credentials()
    if not creds:
        print("❌ Error: Could not get credentials")
        return None
    
    # Check Google Tasks
    google_tasks, tasks_by_date = check_google_tasks(creds)
    
    # Check Memory Documents
    memory_tasks = check_memory_documents(creds)
    
    # Specific tasks to check
    specific_tasks = [
        {
            'name': 'Draft compliance strategy for Feature 7 (CCPA risk)',
            'due_date': '2025-11-26'
        },
        {
            'name': 'URGENT FIX: Implement authenticated logging hook for Python user data handling module',
            'due_date': '2025-11-24'
        },
        {
            'name': 'TEST: P3 Hybrid System Validation',
            'due_date': '2025-11-22'
        },
        {
            'name': 'Draft legal risk assessment for V2 feature set, focusing on data privacy and compliance requirements',
            'due_date': '2025-11-21'
        }
    ]
    
    # Check specific tasks
    specific_tasks_status = check_specific_tasks(specific_tasks, google_tasks, memory_tasks)
    
    # Generate report
    report = generate_status_report(google_tasks, memory_tasks, specific_tasks_status)
    
    print(report)
    
    # Save report
    report_file = Path(__file__).parent / f"TASK_STATUS_REPORT_{datetime.now().strftime('%Y%m%d_%H%M%S')}.md"
    with open(report_file, 'w', encoding='utf-8') as f:
        f.write(report)
    
    print("\n" + "="*80)
    print(f"✅ Status report saved to: {report_file.name}")
    print("="*80)
    print()
    
    return report

if __name__ == "__main__":
    main()

