"""Check task completion status for all agents"""
import yaml
from pathlib import Path
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
import os

def get_credentials():
    """Get Google API credentials"""
    SCOPES = ['https://www.googleapis.com/auth/documents.readonly', 'https://www.googleapis.com/auth/drive.readonly']
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

def extract_tasks_from_content(content):
    """Extract task information from memory document content"""
    tasks = []
    lines = content.split('\n')
    
    in_tasks_section = False
    current_task = None
    
    for line in lines:
        # Check if we're in TASKS section
        if 'TASKS' in line.upper() and ('##' in line or '#' in line):
            in_tasks_section = True
            continue
        
        # Check if we've left TASKS section
        if in_tasks_section and line.startswith('##') and 'TASKS' not in line.upper():
            in_tasks_section = False
        
        if in_tasks_section:
            # Look for task markers
            if '- [' in line or '[x]' in line.lower() or 'COMPLETED' in line.upper():
                if current_task:
                    tasks.append(current_task)
                current_task = {'line': line.strip()}
            elif current_task and line.strip():
                if 'Status:' in line or 'COMPLETE' in line.upper():
                    current_task['status'] = line.strip()
                if 'V2-' in line:
                    current_task['task_id'] = line.strip()
    
    if current_task:
        tasks.append(current_task)
    
    return tasks

def main():
    """Check all agent task status"""
    print("📊 CHECKING ALL AGENT TASK STATUS")
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
    print()
    for task_id, task_info in v2_tasks.items():
        print(f"   {task_id}: {task_info['name']}")
        print(f"      Assigned to: {task_info['agent']}")
    print()
    print("="*80)
    print()
    
    # Check each agent's memory document
    task_status = {}
    
    for agent in agents:
        name = agent.get('designation', 'Unknown')
        email = agent.get('email_address', '')
        doc_id = agent.get('memory_doc_id', '')
        
        if not doc_id:
            continue
        
        # Check if this agent has V2 tasks
        has_v2_tasks = any(task_info['agent'] in name for task_info in v2_tasks.values())
        
        if has_v2_tasks:
            print(f"📄 Checking: {name}")
            print(f"   Email: {email}")
            print(f"   Document ID: {doc_id[:30]}...")
            
            content = read_memory_document(creds, doc_id)
            
            # Check for V2 tasks
            for task_id, task_info in v2_tasks.items():
                if task_info['agent'] in name:
                    if task_id in content:
                        # Check if completed
                        task_lines = [line for line in content.split('\n') if task_id in line]
                        completed = any('COMPLETED' in line.upper() or '[x]' in line.lower() or 'COMPLETE' in line.upper() for line in task_lines)
                        in_progress = any('IN PROGRESS' in line.upper() or 'PROGRESS' in line.upper() for line in task_lines)
                        
                        status = '✅ COMPLETED' if completed else ('🔄 IN PROGRESS' if in_progress else '⏳ ASSIGNED')
                        task_status[task_id] = status
                        
                        print(f"   {task_id}: {status}")
                    else:
                        task_status[task_id] = '❌ NOT FOUND'
                        print(f"   {task_id}: ❌ NOT FOUND in memory document")
            
            print()
    
    # Summary
    print("="*80)
    print("📊 TASK COMPLETION SUMMARY")
    print("="*80)
    print()
    
    completed = sum(1 for status in task_status.values() if 'COMPLETED' in status)
    in_progress = sum(1 for status in task_status.values() if 'IN PROGRESS' in status)
    assigned = sum(1 for status in task_status.values() if 'ASSIGNED' in status)
    not_found = sum(1 for status in task_status.values() if 'NOT FOUND' in status)
    
    print(f"Total V2 Tasks: {len(v2_tasks)}")
    print(f"✅ Completed: {completed}")
    print(f"🔄 In Progress: {in_progress}")
    print(f"⏳ Assigned: {assigned}")
    print(f"❌ Not Found: {not_found}")
    print()
    
    if completed == len(v2_tasks):
        print("✅ ALL TASKS COMPLETED!")
    elif completed + in_progress == len(v2_tasks):
        print("🔄 ALL TASKS IN PROGRESS OR COMPLETED")
    else:
        print("⚠️  SOME TASKS NOT STARTED OR NOT FOUND")
    
    print()

if __name__ == "__main__":
    main()
