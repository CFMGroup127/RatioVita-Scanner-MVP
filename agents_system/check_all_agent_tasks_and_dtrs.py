"""Check all agent tasks and DTRs from memory documents"""
import yaml
from pathlib import Path
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
import os
import re
from datetime import datetime

def get_credentials():
    """Get Google API credentials"""
    SCOPES = ['https://www.googleapis.com/auth/documents', 'https://www.googleapis.com/auth/drive.readonly']
    creds = None
    token_path = Path(__file__).parent / 'token.json'
    
    if token_path.exists():
        try:
            creds = Credentials.from_authorized_user_file(str(token_path), SCOPES)
            if creds and creds.expired and creds.refresh_token:
                creds.refresh(Request())
        except:
            creds = None
    
    return creds

def read_memory_document(creds, doc_id):
    """Read memory document content"""
    try:
        docs_service = build('docs', 'v1', credentials=creds)
        doc = docs_service.documents().get(documentId=doc_id).execute()
        
        content = doc.get('body', {}).get('content', [])
        text_content = []
        for element in content:
            if 'paragraph' in element:
                para = element['paragraph']
                if 'elements' in para:
                    for elem in para['elements']:
                        if 'textRun' in elem:
                            text_content.append(elem['textRun'].get('content', ''))
        
        return '\n'.join(text_content)
    except Exception as e:
        return f"Error: {str(e)}"

def extract_tasks(content, agent_name):
    """Extract task information from content"""
    tasks = []
    lines = content.split('\n')
    
    in_tasks_section = False
    current_task = None
    
    for i, line in enumerate(lines):
        # Check if we're in TASKS section
        if '##' in line and 'TASKS' in line.upper():
            in_tasks_section = True
            continue
        
        # Check if we've left TASKS section
        if in_tasks_section and line.startswith('##') and 'TASKS' not in line.upper():
            in_tasks_section = False
        
        if in_tasks_section:
            # Look for V2 tasks
            if 'V2-' in line:
                task_match = re.search(r'V2-(\d+)', line)
                if task_match:
                    task_id = f"V2-{task_match.group(1)}"
                    # Check next few lines for status
                    status = 'ASSIGNED'
                    for j in range(i, min(i+10, len(lines))):
                        if 'COMPLETED' in lines[j].upper() or '[x]' in lines[j].lower() or 'COMPLETE' in lines[j].upper():
                            status = 'COMPLETED'
                            break
                        elif 'IN PROGRESS' in lines[j].upper() or 'PROGRESS' in lines[j].upper():
                            status = 'IN PROGRESS'
                    
                    tasks.append({
                        'task_id': task_id,
                        'status': status,
                        'line': line.strip()[:100]
                    })
    
    return tasks

def extract_dtrs(content, agent_name):
    """Extract DTR information from content"""
    dtrs = []
    lines = content.split('\n')
    
    in_reports_section = False
    current_dtr = None
    
    for i, line in enumerate(lines):
        # Check if we're in REPORTS section
        if '##' in line and 'REPORTS' in line.upper():
            in_reports_section = True
            continue
        
        # Check if we've left REPORTS section
        if in_reports_section and line.startswith('##') and 'REPORTS' not in line.upper():
            in_reports_section = False
        
        if in_reports_section:
            # Look for DTR markers
            if 'DTR' in line.upper() or 'DAILY TASK REPORT' in line.upper():
                # Try to extract date
                date_match = re.search(r'(\d{4}-\d{2}-\d{2}|\w+ \d{1,2}, \d{4})', line)
                date = date_match.group(1) if date_match else 'Unknown'
                dtrs.append({
                    'date': date,
                    'line': line.strip()[:100]
                })
    
    return dtrs

def main():
    """Check all agent tasks and DTRs"""
    print("📊 COMPREHENSIVE AGENT TASK & DTR REVIEW")
    print("="*80)
    print()
    
    # Load agents
    agents_yaml = Path(__file__).parent / 'agents.yaml'
    with open(agents_yaml, 'r') as f:
        data = yaml.safe_load(f)
    
    agents = data.get('agents', [])
    
    # Get credentials
    creds = get_credentials()
    if not creds:
        print("❌ Could not get credentials")
        print("   Please ensure token.json exists and has proper scopes")
        return
    
    # V2 tasks assigned
    v2_tasks = {
        'V2-001': {'name': 'Connect CameraCaptureView to RealScannerService', 'agent': 'Ethan Hayes'},
        'V2-002': {'name': 'Enhance RealScannerService & Add Review Screen', 'agent': 'Ethan Hayes'},
        'V2-003': {'name': 'Data Layer Enhancements', 'agent': 'Ethan Hayes'},
        'V2-004': {'name': 'Cross-Platform Consistency', 'agent': 'Ethan Hayes'},
        'V2-005': {'name': 'Testing Suite Expansion', 'agent': 'Tyler Cobb'},
    }
    
    print("📋 V2 TASK ASSIGNMENTS:")
    for task_id, task_info in v2_tasks.items():
        print(f"   {task_id}: {task_info['name']} → {task_info['agent']}")
    print()
    print("="*80)
    print()
    
    # Check each agent
    all_tasks_status = {}
    all_dtrs = {}
    
    for agent in agents:
        name = agent.get('designation', 'Unknown')
        email = agent.get('email_address', '')
        doc_id = agent.get('memory_doc_id', '')
        
        if not doc_id:
            continue
        
        # Check if this agent has V2 tasks
        has_v2_tasks = any(task_info['agent'] in name for task_info in v2_tasks.values())
        
        if has_v2_tasks or 'Ethan' in name or 'Tyler' in name:
            print(f"📄 Agent: {name}")
            print(f"   Email: {email}")
            
            content = read_memory_document(creds, doc_id)
            
            if 'Error:' in content:
                print(f"   ❌ Error reading document: {content}")
                print()
                continue
            
            # Extract tasks
            tasks = extract_tasks(content, name)
            dtrs = extract_dtrs(content, name)
            
            print(f"   Tasks found: {len(tasks)}")
            for task in tasks:
                status_icon = '✅' if task['status'] == 'COMPLETED' else ('🔄' if task['status'] == 'IN PROGRESS' else '⏳')
                print(f"   {status_icon} {task['task_id']}: {task['status']}")
                all_tasks_status[task['task_id']] = task['status']
            
            print(f"   DTRs found: {len(dtrs)}")
            for dtr in dtrs:
                print(f"   📝 DTR: {dtr['date']}")
            
            all_dtrs[name] = dtrs
            print()
    
    # Summary
    print("="*80)
    print("📊 SUMMARY")
    print("="*80)
    print()
    
    print("TASK STATUS:")
    completed = sum(1 for status in all_tasks_status.values() if status == 'COMPLETED')
    in_progress = sum(1 for status in all_tasks_status.values() if status == 'IN PROGRESS')
    assigned = sum(1 for status in all_tasks_status.values() if status == 'ASSIGNED')
    
    print(f"   ✅ Completed: {completed}/{len(v2_tasks)}")
    print(f"   🔄 In Progress: {in_progress}/{len(v2_tasks)}")
    print(f"   ⏳ Assigned: {assigned}/{len(v2_tasks)}")
    print()
    
    print("DTR STATUS:")
    total_dtrs = sum(len(dtrs) for dtrs in all_dtrs.values())
    agents_with_dtrs = sum(1 for dtrs in all_dtrs.values() if len(dtrs) > 0)
    print(f"   📝 Total DTRs: {total_dtrs}")
    print(f"   👤 Agents with DTRs: {agents_with_dtrs}")
    print()
    
    if completed == len(v2_tasks):
        print("✅ ALL TASKS COMPLETED!")
    elif completed + in_progress == len(v2_tasks):
        print("🔄 ALL TASKS IN PROGRESS OR COMPLETED")
    else:
        print("⚠️  SOME TASKS NOT STARTED")
    
    print()

if __name__ == "__main__":
    main()

