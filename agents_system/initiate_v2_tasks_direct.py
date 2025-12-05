"""
Kimi K2 Task Initiation Script for RatioVita V2 (Direct API Version)
Initiates all v0.2.0 milestone tasks with proper agent assignments
Uses Google APIs directly instead of tool wrappers
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

# Task specifications
TASKS = {
    "V2-001": {
        "name": "Connect CameraCaptureView to RealScannerService",
        "priority": "P0",
        "due_date": (datetime.now() + timedelta(days=3)).strftime('%Y-%m-%d'),
        "primary_agent": "Ethan Hayes",
        "primary_agent_role": "Lead Code Execution and V2 Development",
        "supporting_agents": [
            {"name": "Tyler Cobb", "role": "Process and Factual Integrity Auditor", "responsibility": "Code review and testing"},
            {"name": "Chloe Park", "role": "UI/UX Designer", "responsibility": "UI/UX review"},
            {"name": "Ash Roy", "role": "Technical and Product Visionary", "responsibility": "Architecture review"},
            {"name": "Alice Kim", "role": "Documentation and Knowledge Archivist", "responsibility": "Documentation"}
        ],
        "estimated_time": "2-3 days",
        "spec_file": "AGENT_TASK_SPECIFICATIONS_V2.md"
    },
    "V2-002": {
        "name": "Enhance RealScannerService & Add Review Screen",
        "priority": "P1",
        "due_date": (datetime.now() + timedelta(days=5)).strftime('%Y-%m-%d'),
        "primary_agent": "Ethan Hayes",
        "primary_agent_role": "Lead Code Execution and V2 Development",
        "supporting_agents": [
            {"name": "Tyler Cobb", "role": "Process and Factual Integrity Auditor", "responsibility": "OCR testing"},
            {"name": "Alice Kim", "role": "Documentation and Knowledge Archivist", "responsibility": "Documentation"}
        ],
        "estimated_time": "2-3 days",
        "spec_file": "AGENT_TASK_SPECIFICATIONS_V2.md"
    },
    "V2-003": {
        "name": "Data Layer Enhancements",
        "priority": "P2",
        "due_date": (datetime.now() + timedelta(days=7)).strftime('%Y-%m-%d'),
        "primary_agent": "Ethan Hayes",
        "primary_agent_role": "Lead Code Execution and V2 Development",
        "supporting_agents": [
            {"name": "Tyler Cobb", "role": "Process and Factual Integrity Auditor", "responsibility": "Testing"},
            {"name": "Alice Kim", "role": "Documentation and Knowledge Archivist", "responsibility": "Documentation"}
        ],
        "estimated_time": "1-2 days",
        "spec_file": "AGENT_TASK_SPECIFICATIONS_V2.md"
    },
    "V2-004": {
        "name": "Cross-Platform Consistency",
        "priority": "P2",
        "due_date": (datetime.now() + timedelta(days=8)).strftime('%Y-%m-%d'),
        "primary_agent": "Ethan Hayes",
        "primary_agent_role": "Lead Code Execution and V2 Development",
        "supporting_agents": [
            {"name": "Alice Kim", "role": "Documentation and Knowledge Archivist", "responsibility": "Documentation"}
        ],
        "estimated_time": "1 day",
        "spec_file": "AGENT_TASK_SPECIFICATIONS_V2.md"
    },
    "V2-005": {
        "name": "Testing Suite Expansion",
        "priority": "P2",
        "due_date": (datetime.now() + timedelta(days=10)).strftime('%Y-%m-%d'),
        "primary_agent": "Tyler Cobb",
        "primary_agent_role": "Process and Factual Integrity Auditor",
        "supporting_agents": [
            {"name": "Ethan Hayes", "role": "Lead Code Execution and V2 Development", "responsibility": "Code review"},
            {"name": "Alice Kim", "role": "Documentation and Knowledge Archivist", "responsibility": "Documentation"}
        ],
        "estimated_time": "2-3 days",
        "spec_file": "AGENT_TASK_SPECIFICATIONS_V2.md"
    }
}

def get_credentials():
    """Get Google API credentials"""
    SCOPES = [
        'https://www.googleapis.com/auth/documents',
        'https://www.googleapis.com/auth/gmail.send',
        'https://www.googleapis.com/auth/drive.readonly'
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

def find_agent_by_role(agents, role):
    """Find agent by role"""
    for agent in agents:
        if agent.get('role') == role:
            return agent
    return None

def find_agent_by_name(agents, name):
    """Find agent by name (from designation or email)"""
    for agent in agents:
        if name.lower() in agent.get('designation', '').lower():
            return agent
        # Also check email for partial matches
        email = agent.get('email_address', '')
        if name.lower().replace(' ', '.') in email.lower():
            return agent
    return None

def write_to_memory_document(creds, doc_id, content, section="TASKS", subsection=None):
    """Write content to memory document using Google Docs API directly"""
    try:
        docs_service = build('docs', 'v1', credentials=creds)
        
        # Get current document
        doc = docs_service.documents().get(documentId=doc_id).execute()
        content_elements = doc.get('body', {}).get('content', [])
        
        # Find section or append at end
        insert_index = content_elements[-1].get('endIndex', 1) - 1 if content_elements else 1
        
        # Prepare content with section heading if needed
        if subsection:
            formatted_content = f"\n### {subsection}\n\n{content}\n\n"
        else:
            formatted_content = f"\n{content}\n\n"
        
        # Insert content
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

def send_email(creds, to, subject, body, cc=None):
    """Send email using Gmail API directly"""
    try:
        service = build('gmail', 'v1', credentials=creds)
        
        message = MIMEText(body)
        message['to'] = to
        message['subject'] = subject
        if cc:
            message['cc'] = cc
        message['from'] = 'kimi.k2@ratiovita.com'  # Or use authenticated user's email
        
        raw_message = base64.urlsafe_b64encode(message.as_bytes()).decode('utf-8')
        
        send_message = service.users().messages().send(
            userId='me',
            body={'raw': raw_message}
        ).execute()
        
        return True
    except Exception as e:
        print(f"   ⚠️  Error sending email: {e}")
        return False

def create_task_assignment(task_id, task_spec, agents, creds):
    """Create task assignment in Dana's memory and send email"""
    
    # Find Dana Flores
    dana = find_agent_by_role(agents, "Admin Assistant & Workflow Funnel")
    if not dana:
        print(f"❌ Could not find Dana Flores")
        return False
    
    # Find primary agent
    primary_agent = find_agent_by_name(agents, task_spec['primary_agent'])
    if not primary_agent:
        print(f"❌ Could not find primary agent: {task_spec['primary_agent']}")
        return False
    
    # Create task content
    supporting_agents_list = "\n".join([
        f"- {sa['name']} ({sa['role']}) - {sa['responsibility']}"
        for sa in task_spec['supporting_agents']
    ])
    
    task_content = f"""## {task_id}: {task_spec['name']}
- **Status:** Assigned by Kimi K2
- **Priority:** {task_spec['priority']}
- **Due Date:** {task_spec['due_date']}
- **Estimated Time:** {task_spec['estimated_time']}
- **Assigned:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}
- **Assigned By:** Kimi K2 (Architectural Assurance Layer)

**Primary Agent:**
- {task_spec['primary_agent']} ({task_spec['primary_agent_role']})

**Supporting Agents:**
{supporting_agents_list}

**Detailed Specification:** See {task_spec['spec_file']}, Section: {task_id}

**IMPORTANT - DTR REQUIREMENT:**
All agents assigned to this task MUST submit a Daily Task Report (DTR) in table format:
- Stored in their memory document (REPORTS section)
- Sent via email to you (dana.flores@ratiovita.com) and David Chen (david.chen@ratiovita.com)
- CC: collin.m@ratiovita.com
- Format: See DTR_TEMPLATE.md

**ACTION REQUIRED:** 
1. Delegate to {task_spec['primary_agent']} (Primary)
2. Assign supporting agents as listed above
3. Ensure all agents understand DTR requirements
"""
    
    # Log to Dana's memory
    subsection = datetime.now().strftime('%B %d, %Y')
    success_memory = write_to_memory_document(creds, dana['memory_doc_id'], task_content, section="TASKS", subsection=subsection)
    if success_memory:
        print(f"   ✅ Task logged to Dana's memory document")
    
    # Send email to Dana
    email_body = f"""Dear Dana Flores,

Kimi K2 has assigned a new task for RatioVita V2 development.

**Task ID:** {task_id}
**Task Name:** {task_spec['name']}
**Priority:** {task_spec['priority']}
**Due Date:** {task_spec['due_date']}
**Estimated Time:** {task_spec['estimated_time']}

**Primary Agent:**
{task_spec['primary_agent']} ({task_spec['primary_agent_role']})

**Supporting Agents:**
{supporting_agents_list}

**Detailed Specification:** See {task_spec['spec_file']}

**IMPORTANT - DTR REQUIREMENT:**
All agents assigned to this task MUST submit a Daily Task Report (DTR) in table format:
- Stored in their memory document (REPORTS section)
- Sent via email to you (dana.flores@ratiovita.com) and David Chen (david.chen@ratiovita.com)
- CC: collin.m@ratiovita.com
- Format: See DTR_TEMPLATE.md

Please acknowledge receipt and begin delegation process.

Best regards,
Kimi K2
Architectural Assurance Layer & Build Leader
"""
    
    success_email = send_email(creds, dana['email_address'], f"Task Assignment: {task_id} - {task_spec['name']}", email_body, cc="collin.m@ratiovita.com")
    if success_email:
        print(f"   ✅ Assignment email sent to Dana Flores")
    
    return success_memory or success_email

def main():
    """Main execution function"""
    print("\n" + "="*80)
    print("🚀 KIMI K2 TASK INITIATION - RATIOVITA V2")
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
    
    # Initiate each task
    print("📝 Initiating tasks...\n")
    results = {}
    
    for task_id, task_spec in TASKS.items():
        print(f"📋 {task_id}: {task_spec['name']}")
        print(f"   Priority: {task_spec['priority']}")
        print(f"   Primary Agent: {task_spec['primary_agent']}")
        
        success = create_task_assignment(task_id, task_spec, agents, creds)
        results[task_id] = success
        
        if success:
            print(f"   ✅ Task assignment initiated\n")
        else:
            print(f"   ❌ Failed to initiate task assignment\n")
    
    # Summary
    print("="*80)
    print("📊 INITIATION SUMMARY")
    print("="*80)
    print()
    
    success_count = sum(1 for v in results.values() if v)
    print(f"✅ Successfully initiated: {success_count}/{len(TASKS)} tasks")
    print()
    
    for task_id, success in results.items():
        status = "✅" if success else "❌"
        print(f"{status} {task_id}: {TASKS[task_id]['name']}")
    
    print()
    print("="*80)
    print("✅ TASK INITIATION COMPLETE")
    print("="*80)
    print()
    print("📋 NEXT STEPS:")
    print("1. Dana Flores will delegate tasks to primary agents")
    print("2. Primary agents will begin execution (P4 protocol)")
    print("3. All agents must submit DTR daily (see DTR_PROTOCOL.md)")
    print("4. Kimi K2 will monitor progress")
    print()
    print("📚 DTR DOCUMENTATION:")
    print("- DTR_TEMPLATE.md - Template for daily reports")
    print("- DTR_PROTOCOL.md - Complete protocol requirements")
    print()

if __name__ == "__main__":
    main()

