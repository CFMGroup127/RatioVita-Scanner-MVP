"""
Retry the 2 failed tasks from the previous execution
"""
import os
import sys
import yaml
from pathlib import Path
from datetime import datetime, timedelta
from crewai import Agent, Task, Crew
from config import Config
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

# Only the failed tasks
FAILED_TASKS = {
    "Draft legal risk assessment for V2 feature set, focusing on data privacy and compliance requirements": {
        "agent_role": "Legal Compliance and Risk Assessor",
        "priority": "P1 (High)",
        "due_date": (datetime.now() + timedelta(days=1)).strftime('%Y-%m-%d'),
        "execution_instructions": """
1. **REVIEW V2 FEATURES:** Use FileReadTool to review all V2 feature specifications and documentation.
2. **IDENTIFY DATA PRIVACY RISKS:** Analyze each feature for data privacy implications (CCPA, GDPR, etc.).
3. **ASSESS COMPLIANCE GAPS:** Compare current implementation against legal requirements.
4. **DRAFT ASSESSMENT:** Use FileWriteTool to create a comprehensive legal risk assessment document.
5. **PRIORITIZE RISKS:** Categorize risks by severity and urgency.
6. **SUBMIT REPORT:** Log the assessment to memory (REPORTS section) and email to project.reports@ratiovita.com.
        """,
        "expected_artifacts": [
            "Legal risk assessment document",
            "Risk prioritization matrix",
            "Compliance gap analysis"
        ]
    },
    "TEST: P3 Hybrid System Validation": {
        "agent_role": "Lead Code Execution and V2 Development",
        "priority": "P2 (Medium)",
        "due_date": datetime.now().strftime('%Y-%m-%d'),
        "execution_instructions": """
1. **CREATE TEST TASK:** Create a simple test task (e.g., "Test P3 Hybrid System - Validate logging").
2. **EXECUTE P3 PROTOCOL:** Log the task to memory document (TASKS section) AND create it in Google Tasks.
3. **VERIFY BOTH SYSTEMS:** Confirm task appears in both memory document and Google Tasks sidebar.
4. **EXECUTE TASK:** Complete the test task (e.g., write a simple test document).
5. **MARK COMPLETE:** Update memory document and mark Google Task as COMPLETE.
6. **VALIDATE:** Verify completion appears in both systems.
7. **DOCUMENT RESULTS:** Log validation results to memory (REPORTS section).
        """,
        "expected_artifacts": [
            "Test task in memory document",
            "Test task in Google Tasks (marked complete)",
            "Validation report in REPORTS section"
        ]
    }
}

from datetime import datetime, timedelta

# Copy necessary functions (to avoid circular imports)
def get_agent_metadata_local(role):
    """Get agent metadata by role"""
    yaml_path = Path(__file__).parent / 'agents.yaml'
    with open(yaml_path, 'r') as f:
        data = yaml.safe_load(f)
    
    for agent_data in data.get('agents', []):
        if agent_data.get('role') == role:
            return agent_data
    return {}

def get_credentials():
    """Get Google API credentials"""
    SCOPES = [
        'https://www.googleapis.com/auth/documents',
        'https://www.googleapis.com/auth/drive.readonly',
        'https://www.googleapis.com/auth/gmail.send',
        'https://www.googleapis.com/auth/calendar.readonly',
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
    
    return creds

def get_execution_tools_for_agent(agent_role: str):
    """Get execution tools for an agent"""
    from tools import (
        get_google_docs_memory_tool,
        get_google_tasks_tool,
        get_gmail_tool
    )
    from crewai_tools import (
        FileReadTool,
        FileWriterTool,
        CodeInterpreterTool
    )
    
    tools_list = []
    
    try:
        tools_list.append(get_google_docs_memory_tool())
    except:
        pass
    
    try:
        tools_list.append(get_google_tasks_tool())
    except:
        pass
    
    try:
        tools_list.append(get_gmail_tool(agent_role=agent_role))
    except:
        pass
    
    tools_list.append(FileReadTool())
    tools_list.append(FileWriterTool())
    tools_list.append(CodeInterpreterTool())
    
    return tools_list

def assign_and_execute_task(task_name: str, task_config: dict, creds):
    """Assign a task to an agent and trigger P3 + P4 execution"""
    print(f"\n📋 ASSIGNING TASK: {task_name}")
    print("="*80)
    
    agent_role = task_config['agent_role']
    agent_data = get_agent_metadata_local(agent_role)
    
    if not agent_data:
        print(f"❌ Error: Agent '{agent_role}' not found")
        return None
    
    agent_name = agent_data.get('name', agent_role)
    memory_doc_id = agent_data.get('memory_doc_id', '')
    
    print(f"   Agent: {agent_name} ({agent_role})")
    print(f"   Priority: {task_config['priority']}")
    print(f"   Due Date: {task_config['due_date']}")
    print()
    
    # Create agent
    agent = Agent(
        role=agent_data.get('role', ''),
        goal=agent_data.get('goal', ''),
        backstory=agent_data.get('backstory', ''),
        verbose=True,
        allow_delegation=False,
        max_iter=20,
        max_execution_time=1200
    )
    
    # Load tools
    execution_tools = get_execution_tools_for_agent(agent_role)
    agent.tools = execution_tools
    print(f"✅ Loaded {len(execution_tools)} tools for {agent_name}")
    
    # Create task description with P3 + P4 protocols
    task_description = f"""
**TASK ASSIGNMENT: {task_name}**

**TASK DETAILS:**
- **Priority:** {task_config['priority']}
- **Due Date:** {task_config['due_date']}
- **Assigned To:** {agent_name} ({agent_role})
- **Assigned Date:** {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}

**MANDATORY P3 PROTOCOL (Task Logging - Hybrid System):**

**STEP 1: P0 ACKNOWLEDGMENT**
- Immediately acknowledge receipt of this task
- Log the acknowledgment to your memory document with timestamp

**STEP 2: P3 HYBRID LOGGING - PART A (Memory Document)**
- Use the **Google Docs Memory Tool** to update your TASKS section:
  - doc_id: {memory_doc_id}
  - section: "TASKS"
  - subsection: "{datetime.now().strftime('%B %d, %Y')}"
  - content: "- [ ] {task_name}\\n  - Priority: {task_config['priority']}\\n  - Due Date: {task_config['due_date']}\\n  - Status: IN PROGRESS\\n  - Assigned: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}"
  - template: "Task Tracker"

**STEP 3: P3 HYBRID LOGGING - PART B (Google Tasks)**
- Use the **Google Tasks Tool** to create the task in Google Tasks:
  - task_title: "{task_name}"
  - task_notes: "Priority: {task_config['priority']}\\nDue Date: {task_config['due_date']}\\nAssigned: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}"
  - due_date: "{task_config['due_date']}"
  - task_list_id: "@default"

**CRITICAL:** You must complete BOTH steps (Memory Document AND Google Tasks) to achieve full P3 compliance.

**MANDATORY P4 PROTOCOL (Autonomous Execution):**

After completing P3 logging, you MUST immediately execute the task using your available tools:

{task_config['execution_instructions']}

**EXECUTION REQUIREMENTS:**
- Use your available execution tools (FileReadTool, FileWriteTool, CodeInterpreterTool) as appropriate
- Do not wait for manual triggers - execute immediately after P3 logging
- Log progress to your memory document (TASKS section) as you work
- Document any issues or blockers encountered

**COMPLETION REQUIREMENTS:**
- Verify task completion criteria are met
- Test/validate the work completed
- Update memory document with completion status and artifact references:
  {chr(10).join('  - ' + artifact for artifact in task_config['expected_artifacts'])}
- Mark Google Task as COMPLETE
- Log completion to memory document with sign-off: "TASK COMPLETE: {task_name} - VERIFIED BY AGENT {agent_name} {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}"

**CRITICAL:** You must EXECUTE the task, not just log it. Use your tools to actually complete the work.

**OUTPUT:**
After completing P3 + P4 protocols, provide:
1. P3 confirmation: Task logged to memory + Google Tasks
2. P4 execution: Task executed with details of work completed
3. Completion: Task marked COMPLETE with artifact references
"""
    
    task = Task(
        description=task_description,
        agent=agent,
        expected_output=f"Task '{task_name}' completed with P3 protocol (logged to memory + Google Tasks) and P4 protocol (executed), with all artifacts and completion logs."
    )
    
    # Create crew
    crew = Crew(
        agents=[agent],
        tasks=[task],
        verbose=True
    )
    
    print("🚀 EXECUTING TASK ASSIGNMENT AND EXECUTION")
    print("="*80)
    print()
    
    try:
        result = crew.kickoff()
        
        print("\n" + "="*80)
        print(f"✅ TASK ASSIGNMENT AND EXECUTION COMPLETE")
        print("="*80)
        print(f"\nResult:\n{result}")
        print()
        
        return result
    except Exception as e:
        print("\n" + "="*80)
        print(f"❌ TASK EXECUTION FAILED")
        print("="*80)
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return None

def main():
    """Retry the failed tasks"""
    print("\n" + "="*80)
    print("🔄 RETRYING FAILED TASKS")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    # Validate configuration
    try:
        Config.validate()
        print("✅ Configuration validated")
    except ValueError as e:
        print(f"❌ Configuration Error: {e}")
        return
    
    os.environ['OPENAI_API_KEY'] = Config.OPENAI_API_KEY
    
    # Get credentials
    print("🔐 Getting Google API credentials...")
    creds = get_credentials()
    if not creds:
        print("❌ Error: Could not get credentials")
        return
    print("✅ Credentials obtained")
    
    # Process failed tasks
    print(f"\n📋 Retrying {len(FAILED_TASKS)} failed tasks...")
    results = {}
    
    for task_name, task_config in FAILED_TASKS.items():
        print(f"\n{'='*80}")
        print(f"🔄 RETRYING: {task_name}")
        print("="*80)
        
        try:
            result = assign_and_execute_task(task_name, task_config, creds)
            results[task_name] = {
                'status': 'success' if result else 'failed',
                'result': result
            }
        except Exception as e:
            print(f"❌ Error: {e}")
            results[task_name] = {
                'status': 'error',
                'error': str(e)
            }
    
    # Summary
    print("\n" + "="*80)
    print("📊 RETRY SUMMARY")
    print("="*80)
    
    success = sum(1 for r in results.values() if r['status'] == 'success')
    print(f"✅ Successfully retried: {success}/{len(FAILED_TASKS)} tasks")
    
    for task_name, result_data in results.items():
        status = "✅" if result_data['status'] == 'success' else "❌"
        print(f"{status} {task_name[:60]}...")
    
    print()

if __name__ == "__main__":
    main()

