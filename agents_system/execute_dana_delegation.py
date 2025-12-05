"""
Execute Dana Flores Delegation - Assigns all V2 tasks to primary agents
This script simulates Dana Flores delegating tasks to primary agents
"""
import os
import sys
import yaml
from pathlib import Path
from datetime import datetime, timedelta
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
import base64
from email.mime.text import MIMEText

# Task assignments (from Kimi K2's initiation)
TASKS = {
    "V2-001": {
        "name": "Connect CameraCaptureView to RealScannerService",
        "priority": "P0",
        "due_date": (datetime.now() + timedelta(days=3)).strftime('%Y-%m-%d'),
        "primary_agent": "Ethan Hayes",
        "primary_agent_role": "Lead Code Execution and V2 Development",
        "supporting_agents": [
            {"name": "Tyler Cobb", "role": "Process and Factual Integrity Auditor"},
            {"name": "Chloe Park", "role": "UI/UX Designer"},
            {"name": "Ash Roy", "role": "Technical and Product Visionary"},
            {"name": "Alice Kim", "role": "Documentation and Knowledge Archivist"}
        ]
    },
    "V2-002": {
        "name": "Enhance RealScannerService & Add Review Screen",
        "priority": "P1",
        "due_date": (datetime.now() + timedelta(days=5)).strftime('%Y-%m-%d'),
        "primary_agent": "Ethan Hayes",
        "primary_agent_role": "Lead Code Execution and V2 Development",
        "supporting_agents": [
            {"name": "Tyler Cobb", "role": "Process and Factual Integrity Auditor"},
            {"name": "Alice Kim", "role": "Documentation and Knowledge Archivist"}
        ]
    },
    "V2-003": {
        "name": "Data Layer Enhancements",
        "priority": "P2",
        "due_date": (datetime.now() + timedelta(days=7)).strftime('%Y-%m-%d'),
        "primary_agent": "Ethan Hayes",
        "primary_agent_role": "Lead Code Execution and V2 Development",
        "supporting_agents": [
            {"name": "Tyler Cobb", "role": "Process and Factual Integrity Auditor"},
            {"name": "Alice Kim", "role": "Documentation and Knowledge Archivist"}
        ]
    },
    "V2-004": {
        "name": "Cross-Platform Consistency",
        "priority": "P2",
        "due_date": (datetime.now() + timedelta(days=8)).strftime('%Y-%m-%d'),
        "primary_agent": "Ethan Hayes",
        "primary_agent_role": "Lead Code Execution and V2 Development",
        "supporting_agents": [
            {"name": "Alice Kim", "role": "Documentation and Knowledge Archivist"}
        ]
    },
    "V2-005": {
        "name": "Testing Suite Expansion",
        "priority": "P2",
        "due_date": (datetime.now() + timedelta(days=10)).strftime('%Y-%m-%d'),
        "primary_agent": "Tyler Cobb",
        "primary_agent_role": "Process and Factual Integrity Auditor",
        "supporting_agents": [
            {"name": "Ethan Hayes", "role": "Lead Code Execution and V2 Development"},
            {"name": "Alice Kim", "role": "Documentation and Knowledge Archivist"}
        ]
    }
}

def get_credentials():
    """Get Google API credentials"""
    SCOPES = [
        'https://www.googleapis.com/auth/documents',
        'https://www.googleapis.com/auth/gmail.send',
        'https://www.googleapis.com/auth/drive.readonly',
        'https://www.googleapis.com/auth/tasks'
    ]
    
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
        if credentials_path.exists():
            flow = InstalledAppFlow.from_client_secrets_file(str(credentials_path), SCOPES)
            creds = flow.run_local_server(port=0, access_type='offline', prompt='consent')
            with open(token_path, 'w') as token:
                token.write(creds.to_json())
        else:
            print("❌ credentials.json not found")
            return None
    
    return creds

def load_agents():
    """Load agent definitions from YAML"""
    agents_yaml = Path(__file__).parent / 'agents.yaml'
    with open(agents_yaml, 'r') as f:
        data = yaml.safe_load(f)
    return data.get('agents', [])

def find_agent_by_name(agents, name):
    """Find agent by name"""
    for agent in agents:
        if name.lower() in agent.get('designation', '').lower():
            return agent
        email = agent.get('email_address', '')
        if name.lower().replace(' ', '.') in email.lower():
            return agent
    return None

def write_to_memory_document(creds, doc_id, content, section="TASKS", subsection=None):
    """Write content to memory document"""
    try:
        docs_service = build('docs', 'v1', credentials=creds)
        doc = docs_service.documents().get(documentId=doc_id).execute()
        content_elements = doc.get('body', {}).get('content', [])
        insert_index = content_elements[-1].get('endIndex', 1) - 1 if content_elements else 1
        
        if subsection:
            formatted_content = f"\n### {subsection}\n\n{content}\n\n"
        else:
            formatted_content = f"\n{content}\n\n"
        
        requests = [{
            'insertText': {
                'location': {'index': insert_index},
                'text': formatted_content
            }
        }]
        
        docs_service.documents().batchUpdate(
            documentId=doc_id,
            body={'requests': requests}
        ).execute()
        return True
    except Exception as e:
        print(f"   ⚠️  Error writing to memory: {e}")
        return False

def create_google_task(creds, task_title, task_notes, due_date, task_list_id="@default"):
    """Create task in Google Tasks"""
    try:
        service = build('tasks', 'v1', credentials=creds)
        
        task = {
            'title': task_title,
            'notes': task_notes,
            'due': due_date + 'T23:59:59Z' if due_date else None
        }
        
        result = service.tasks().insert(
            tasklist=task_list_id,
            body=task
        ).execute()
        
        return result.get('id')
    except Exception as e:
        print(f"   ⚠️  Error creating Google Task: {e}")
        return None

def send_email(creds, to, subject, body, cc=None):
    """Send email using Gmail API"""
    try:
        service = build('gmail', 'v1', credentials=creds)
        
        message = MIMEText(body)
        message['to'] = to
        message['subject'] = subject
        if cc:
            message['cc'] = cc
        message['from'] = 'dana.flores@ratiovita.com'
        
        raw_message = base64.urlsafe_b64encode(message.as_bytes()).decode('utf-8')
        
        send_message = service.users().messages().send(
            userId='me',
            body={'raw': raw_message}
        ).execute()
        
        return True
    except Exception as e:
        print(f"   ⚠️  Error sending email: {e}")
        return False

def delegate_task(task_id, task_spec, agents, creds):
    """Delegate task to primary agent and supporting agents"""
    
    # Find primary agent
    primary_agent = find_agent_by_name(agents, task_spec['primary_agent'])
    if not primary_agent:
        print(f"❌ Could not find primary agent: {task_spec['primary_agent']}")
        return False
    
    print(f"   📋 Delegating to: {task_spec['primary_agent']} ({primary_agent['email_address']})")
    
    # Create task content for primary agent
    supporting_agents_list = "\n".join([
        f"- {sa['name']} ({sa['role']})"
        for sa in task_spec['supporting_agents']
    ])
    
    task_content = f"""## {task_id}: {task_spec['name']}
- **Status:** Assigned by Dana Flores
- **Priority:** {task_spec['priority']}
- **Due Date:** {task_spec['due_date']}
- **Assigned:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}
- **Assigned By:** Dana Flores (Admin Assistant & Workflow Funnel)

**Your Role:** Primary Agent (Lead Implementation)

**Supporting Agents:**
{supporting_agents_list}

**Detailed Specification:** See AGENT_TASK_SPECIFICATIONS_V2.md, Section: {task_id}

**MANDATORY PROTOCOLS:**
1. **P0:** Acknowledge receipt immediately via email
2. **P2:** Log task to memory document (TASKS section)
3. **P3:** Create task in Google Tasks (P3 Hybrid System)
4. **P4:** Begin autonomous execution immediately
5. **DTR:** Submit Daily Task Report daily (see DTR_PROTOCOL.md)

**DTR REQUIREMENT:**
You MUST submit a Daily Task Report (DTR) in table format:
- Stored in your memory document (REPORTS section)
- Sent via email to dana.flores@ratiovita.com and david.chen@ratiovita.com
- CC: collin.m@ratiovita.com
- Format: See DTR_TEMPLATE.md
- Deadline: Daily before 6:00 PM EST

**ACTION REQUIRED:**
1. Acknowledge this assignment (P0)
2. Log task to memory (P2)
3. Create Google Task (P3)
4. Begin execution (P4)
5. Submit DTR daily
"""
    
    # Log to primary agent's memory
    subsection = datetime.now().strftime('%B %d, %Y')
    success_memory = write_to_memory_document(
        creds, 
        primary_agent['memory_doc_id'], 
        task_content, 
        section="TASKS", 
        subsection=subsection
    )
    if success_memory:
        print(f"      ✅ Task logged to {task_spec['primary_agent']}'s memory")
    
    # Create Google Task
    task_notes = f"""Assigned by Dana Flores on {datetime.now().strftime('%Y-%m-%d')}.
Priority: {task_spec['priority']}
Due Date: {task_spec['due_date']}
Supporting Agents: {', '.join([sa['name'] for sa in task_spec['supporting_agents']])}

See AGENT_TASK_SPECIFICATIONS_V2.md for detailed requirements.
DTR required daily. See DTR_PROTOCOL.md.
"""
    task_id_google = create_google_task(
        creds,
        f"{task_id}: {task_spec['name']}",
        task_notes,
        task_spec['due_date']
    )
    if task_id_google:
        print(f"      ✅ Google Task created")
    
    # Send delegation email
    email_body = f"""Dear {task_spec['primary_agent']},

I am delegating the following task to you as the primary agent:

**Task ID:** {task_id}
**Task Name:** {task_spec['name']}
**Priority:** {task_spec['priority']}
**Due Date:** {task_spec['due_date']}

**Your Role:** Primary Agent (Lead Implementation)

**Supporting Agents:**
{supporting_agents_list}

**Detailed Specification:** See AGENT_TASK_SPECIFICATIONS_V2.md, Section: {task_id}

**MANDATORY PROTOCOLS:**
1. **P0:** Acknowledge receipt immediately (reply to this email)
2. **P2:** Log task to your memory document (TASKS section)
3. **P3:** Create task in Google Tasks (P3 Hybrid System)
4. **P4:** Begin autonomous execution immediately
5. **DTR:** Submit Daily Task Report daily (see DTR_PROTOCOL.md)

**DTR REQUIREMENT:**
You MUST submit a Daily Task Report (DTR) in table format:
- Stored in your memory document (REPORTS section)
- Sent via email to me (dana.flores@ratiovita.com) and David Chen (david.chen@ratiovita.com)
- CC: collin.m@ratiovita.com
- Format: See DTR_TEMPLATE.md
- Deadline: Daily before 6:00 PM EST

Please acknowledge receipt and begin work immediately.

Best regards,
Dana Flores
Admin Assistant & Workflow Funnel
"""
    
    success_email = send_email(
        creds, 
        primary_agent['email_address'], 
        f"Task Delegation: {task_id} - {task_spec['name']}", 
        email_body, 
        cc="collin.m@ratiovita.com"
    )
    if success_email:
        print(f"      ✅ Delegation email sent")
    
    # Also assign to supporting agents
    for supporting_agent_spec in task_spec['supporting_agents']:
        supporting_agent = find_agent_by_name(agents, supporting_agent_spec['name'])
        if supporting_agent:
            supporting_content = f"""## Supporting Role: {task_id}
- **Task:** {task_spec['name']}
- **Your Role:** {supporting_agent_spec['role']} - {supporting_agent_spec.get('responsibility', 'Supporting')}
- **Primary Agent:** {task_spec['primary_agent']}
- **Assigned:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}

**Action Required:**
- Review primary agent's work
- Complete your assigned responsibilities
- Submit DTR daily
"""
            write_to_memory_document(
                creds,
                supporting_agent['memory_doc_id'],
                supporting_content,
                section="TASKS",
                subsection=subsection
            )
            print(f"      ✅ Supporting agent {supporting_agent_spec['name']} notified")
    
    return success_memory or success_email

def main():
    """Main execution function"""
    print("\n" + "="*80)
    print("🚀 DANA FLORES - TASK DELEGATION EXECUTION")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    # Get credentials
    print("🔐 Getting credentials...")
    creds = get_credentials()
    if not creds:
        print("❌ Could not get credentials")
        return
    
    print("✅ Credentials obtained\n")
    
    # Load agents
    print("📋 Loading agent definitions...")
    agents = load_agents()
    print(f"✅ Loaded {len(agents)} agents\n")
    
    # Delegate each task
    print("📝 Delegating tasks to primary agents...\n")
    results = {}
    
    for task_id, task_spec in TASKS.items():
        print(f"📋 {task_id}: {task_spec['name']}")
        print(f"   Priority: {task_spec['priority']}")
        
        success = delegate_task(task_id, task_spec, agents, creds)
        results[task_id] = success
        
        if success:
            print(f"   ✅ Task delegated successfully\n")
        else:
            print(f"   ❌ Failed to delegate task\n")
    
    # Summary
    print("="*80)
    print("📊 DELEGATION SUMMARY")
    print("="*80)
    print()
    
    success_count = sum(1 for v in results.values() if v)
    print(f"✅ Successfully delegated: {success_count}/{len(TASKS)} tasks")
    print()
    
    for task_id, success in results.items():
        status = "✅" if success else "❌"
        print(f"{status} {task_id}: {TASKS[task_id]['name']}")
        print(f"   → {TASKS[task_id]['primary_agent']}")
    
    print()
    print("="*80)
    print("✅ DELEGATION COMPLETE")
    print("="*80)
    print()
    print("📋 NEXT STEPS:")
    print("1. Primary agents acknowledge assignments (P0)")
    print("2. Primary agents log tasks to memory (P2)")
    print("3. Primary agents create Google Tasks (P3)")
    print("4. Primary agents begin execution (P4)")
    print("5. All agents submit DTR daily")
    print("6. Kimi K2 monitors progress")
    print()

if __name__ == "__main__":
    main()

