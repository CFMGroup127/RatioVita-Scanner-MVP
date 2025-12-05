"""
Kimi K2 Time-Based Task Monitor
Monitors task progress, prompts for updates, detects loops, and adjusts schedules
"""
import os
import sys
import yaml
from pathlib import Path
from datetime import datetime, timedelta
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from typing import Dict, List, Optional

sys.path.insert(0, str(Path(__file__).parent))
from task_time_management import (
    get_task_time_constraint,
    is_task_overdue,
    get_time_remaining,
    should_prompt_for_update,
    detect_loop,
    generate_progress_prompt,
    generate_loop_recovery_prompt
)
from tools import get_gmail_tool

def get_credentials():
    """Get Google API credentials"""
    SCOPES = ['https://www.googleapis.com/auth/documents', 'https://www.googleapis.com/auth/drive.readonly', 'https://www.googleapis.com/auth/gmail.send']
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

def extract_task_start_time(content: str, task_id: str) -> Optional[datetime]:
    """Extract task start time from memory document"""
    lines = content.split('\n')
    for i, line in enumerate(lines):
        if task_id in line:
            # Look for timestamp in nearby lines
            for j in range(max(0, i-5), min(len(lines), i+10)):
                if '2025-' in lines[j] or 'EST' in lines[j] or 'PST' in lines[j]:
                    # Try to parse timestamp
                    try:
                        # Look for common timestamp formats
                        timestamp_str = lines[j]
                        # Extract date/time
                        for fmt in ['%Y-%m-%d %H:%M:%S', '%B %d, %Y %I:%M %p', '%Y-%m-%d']:
                            try:
                                return datetime.strptime(timestamp_str[:19], fmt)
                            except:
                                continue
                    except:
                        pass
    
    return None

def extract_recent_actions(content: str, task_id: str) -> List[str]:
    """Extract recent actions for loop detection"""
    actions = []
    lines = content.split('\n')
    in_task_section = False
    
    for line in lines:
        if task_id in line:
            in_task_section = True
        elif in_task_section and line.startswith('##'):
            break
        
        if in_task_section and line.strip():
            # Extract action keywords
            if any(keyword in line.lower() for keyword in ['read', 'write', 'execute', 'error', 'failed', 'complete']):
                actions.append(line.strip()[:100])
    
    return actions[-10:]  # Last 10 actions

def monitor_all_tasks():
    """Monitor all V2 tasks for time constraints and progress"""
    print("\n" + "="*80)
    print("⏰ KIMI K2: TIME-BASED TASK MONITOR")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    creds = get_credentials()
    if not creds:
        print("❌ Could not get credentials")
        return
    
    # Load agents
    agents_yaml = Path(__file__).parent / 'agents.yaml'
    with open(agents_yaml, 'r') as f:
        data = yaml.safe_load(f)
    
    agents = data.get('agents', [])
    
    # V2 task assignments
    task_assignments = {
        'V2-001': 'Ethan Hayes',
        'V2-002': 'Ethan Hayes',
        'V2-003': 'Ethan Hayes',
        'V2-004': 'Ethan Hayes',
        'V2-005': 'Tyler Cobb',
    }
    
    print("📊 MONITORING TASKS:")
    print()
    
    actions_required = []
    
    for task_id, agent_name in task_assignments.items():
        print(f"🔍 Checking: {task_id} - {agent_name}")
        
        # Find agent
        agent_data = None
        for agent in agents:
            designation = agent.get('designation', '')
            email = agent.get('email_address', '')
            # Check designation or email
            if agent_name.lower() in designation.lower() or agent_name.lower().replace(' ', '.') in email.lower():
                agent_data = agent
                break
        
        if not agent_data:
            print(f"   ❌ Agent not found")
            continue
        
        doc_id = agent_data.get('memory_doc_id', '')
        if not doc_id:
            print(f"   ❌ No memory document ID")
            continue
        
        # Read memory document
        content = read_memory_document(creds, doc_id)
        if 'Error:' in content:
            print(f"   ❌ Error reading document")
            continue
        
        # Check if task exists
        if task_id not in content:
            print(f"   ⚠️  Task not found in memory document")
            continue
        
        # Extract start time
        start_time = extract_task_start_time(content, task_id)
        if not start_time:
            # Assume started recently if no timestamp found
            start_time = datetime.now() - timedelta(hours=1)
            print(f"   ⚠️  Start time not found, assuming 1 hour ago")
        
        # Check time constraints
        constraint = get_task_time_constraint(task_id)
        if not constraint:
            print(f"   ⚠️  No time constraint defined")
            continue
        
        time_elapsed = datetime.now() - start_time
        time_remaining = get_time_remaining(task_id, start_time)
        is_overdue = is_task_overdue(task_id, start_time)
        
        print(f"   Time Elapsed: {time_elapsed.total_seconds() / 3600:.1f} hours")
        print(f"   Time Remaining: {time_remaining.total_seconds() / 3600:.1f} hours")
        print(f"   Estimated: {constraint['estimated_hours']} hours")
        print(f"   Max: {constraint['max_hours']} hours")
        
        # Check for loop
        recent_actions = extract_recent_actions(content, task_id)
        loop_detected = detect_loop(agent_name, task_id, recent_actions)
        
        if loop_detected:
            print(f"   🚨 LOOP DETECTED!")
            actions_required.append({
                'type': 'loop_recovery',
                'task_id': task_id,
                'agent_name': agent_name,
                'agent_email': agent_data.get('email_address', ''),
                'message': generate_loop_recovery_prompt(task_id, agent_name, "Repeated actions detected")
            })
        elif is_overdue:
            print(f"   ⚠️  TASK OVERDUE!")
            actions_required.append({
                'type': 'overdue_alert',
                'task_id': task_id,
                'agent_name': agent_name,
                'agent_email': agent_data.get('email_address', ''),
                'message': generate_progress_prompt(task_id, start_time, agent_name)
            })
        elif should_prompt_for_update(task_id, start_time):
            print(f"   📝 PROGRESS UPDATE NEEDED")
            actions_required.append({
                'type': 'progress_update',
                'task_id': task_id,
                'agent_name': agent_name,
                'agent_email': agent_data.get('email_address', ''),
                'message': generate_progress_prompt(task_id, start_time, agent_name)
            })
        else:
            print(f"   ✅ On track")
        
        print()
    
    # Take actions
    if actions_required:
        print("="*80)
        print("📧 SENDING PROMPTS TO AGENTS")
        print("="*80)
        print()
        
        gmail_tool = get_gmail_tool()
        
        for action in actions_required:
            subject = f"[KIMI K2 MONITOR] {action['type'].upper().replace('_', ' ')} - {action['task_id']}"
            
            try:
                result = gmail_tool(
                    to_list=action['agent_email'],
                    subject=subject,
                    body=action['message'],
                    cc_list="dana.flores@ratiovita.com,david.chen@ratiovita.com"
                )
                print(f"✅ Sent {action['type']} prompt to {action['agent_name']}")
            except Exception as e:
                print(f"❌ Failed to send prompt to {action['agent_name']}: {e}")
        
        print()
    
    print("="*80)
    print("✅ MONITORING COMPLETE")
    print("="*80)
    print()

if __name__ == "__main__":
    monitor_all_tasks()

