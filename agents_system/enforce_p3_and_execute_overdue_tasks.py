"""
Enforce P3 Protocol and Execute Overdue Tasks
This script assigns overdue tasks to appropriate agents, enforces P3 protocol (memory + Google Tasks),
and triggers P4 autonomous execution.
"""
import os
import sys
import yaml
import json
from pathlib import Path
from datetime import datetime, timedelta
from crewai import Agent, Task, Crew
from config import Config
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

# Task assignments based on agent roles
TASK_ASSIGNMENTS = {
    "URGENT FIX: Implement authenticated logging hook for Python user data handling module": {
        "agent_role": "Lead Code Execution and V2 Development",
        "priority": "P0 (Critical/Blocker)",
        "due_date": datetime.now().strftime('%Y-%m-%d'),  # Today
        "execution_instructions": """
1. **LOCATE THE FILE:** Use FileReadTool to find and read `data_processor.py` (or similar user data handling module) in the RatioVita_v2 codebase.
2. **RESEARCH LIBRARY:** Use SearchTool or WebBrowserTool to identify the latest version of the data processing library that includes authenticated logging hooks.
3. **UPDATE LIBRARY:** Use CodeInterpreterTool to update the library dependency (requirements.txt or similar).
4. **IMPLEMENT HOOK:** Use FileWriteTool to modify `data_processor.py` to integrate the authenticated logging hook.
5. **VERIFY COMPLIANCE:** Use CodeInterpreterTool to run tests/verification to confirm CCPA compliance restoration.
6. **DOCUMENT CHANGES:** Log all changes, file paths, and verification results to memory document.
        """,
        "expected_artifacts": [
            "Modified data_processor.py (or equivalent file)",
            "Updated requirements.txt or package.json",
            "Test results confirming CCPA compliance",
            "Commit hash or file version reference"
        ]
    },
    "Draft compliance strategy for Feature 7 (CCPA risk)": {
        "agent_role": "Legal Compliance and Risk Assessor",
        "priority": "P1 (High)",
        "due_date": (datetime.now() + timedelta(days=1)).strftime('%Y-%m-%d'),  # Tomorrow
        "execution_instructions": """
1. **REVIEW FEATURE 7:** Use FileReadTool to review Feature 7 specifications and implementation details.
2. **ANALYZE CCPA RISKS:** Review CCPA requirements and identify specific risks for Feature 7.
3. **RESEARCH COMPLIANCE:** Use SearchTool to research CCPA compliance strategies for similar features.
4. **DRAFT STRATEGY:** Use FileWriteTool to create a comprehensive compliance strategy document.
5. **REVIEW WITH ARTHUR:** Ensure strategy addresses all identified risks and includes mitigation steps.
6. **SUBMIT REPORT:** Log the strategy document to memory (REPORTS section) and email to project.reports@ratiovita.com.
        """,
        "expected_artifacts": [
            "Compliance strategy document (PDF or DOCX)",
            "Risk assessment matrix",
            "Mitigation plan with timelines"
        ]
    },
    "Draft legal risk assessment for V2 feature set, focusing on data privacy and compliance requirements": {
        "agent_role": "Legal Compliance and Risk Assessor",
        "priority": "P1 (High)",
        "due_date": (datetime.now() + timedelta(days=2)).strftime('%Y-%m-%d'),  # Day after tomorrow
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
        "agent_role": "Lead Code Execution and V2 Development",  # Or Admin Assistant
        "priority": "P2 (Medium)",
        "due_date": datetime.now().strftime('%Y-%m-%d'),  # Today
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

def get_agent_metadata_local(role):
    """Get agent metadata by role"""
    yaml_path = Path(__file__).parent / 'agents.yaml'
    with open(yaml_path, 'r') as f:
        data = yaml.safe_load(f)
    
    for agent_data in data.get('agents', []):
        if agent_data.get('role') == role:
            return agent_data
    return {}

def clean_duplicate_tasks(creds):
    """Clean up duplicate tasks in Google Tasks"""
    print("\n🧹 CLEANING UP DUPLICATE TASKS")
    print("="*80)
    
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
            return
        
        # Get all tasks
        all_tasks = tasks_service.tasks().list(tasklist=default_list_id, showCompleted=False).execute()
        
        # Find duplicates
        task_titles = {}
        duplicates = []
        
        for task in all_tasks.get('items', []):
            title = task.get('title', '').strip()
            if title:
                if title not in task_titles:
                    task_titles[title] = []
                task_titles[title].append(task)
        
        # Identify duplicates
        for title, tasks in task_titles.items():
            if len(tasks) > 1:
                # Keep the first one, mark others as duplicates
                duplicates.extend(tasks[1:])
                print(f"   Found {len(tasks)} duplicates for: {title[:60]}...")
        
        # Delete duplicates
        deleted_count = 0
        for task in duplicates:
            try:
                tasks_service.tasks().delete(tasklist=default_list_id, task=task['id']).execute()
                deleted_count += 1
            except:
                pass
        
        print(f"✅ Deleted {deleted_count} duplicate tasks")
        
    except Exception as e:
        print(f"⚠️  Error cleaning duplicates: {e}")

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
    
    # Execution tools
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
    """Main function to enforce P3 and execute all overdue tasks"""
    import sys
    import traceback
    
    # Enhanced logging setup
    log_file = Path(__file__).parent / f"p3_p4_execution_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
    
    class TeeOutput:
        def __init__(self, *files):
            self.files = files
        def write(self, obj):
            for f in self.files:
                f.write(obj)
                f.flush()
        def flush(self):
            for f in self.files:
                f.flush()
    
    log_f = open(log_file, 'w', encoding='utf-8')
    sys.stdout = TeeOutput(sys.stdout, log_f)
    sys.stderr = TeeOutput(sys.stderr, log_f)
    
    print("\n" + "="*80)
    print("🚨 ENFORCE P3 PROTOCOL & EXECUTE OVERDUE TASKS")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}")
    print(f"Log File: {log_file}")
    print()
    
    try:
        # Validate configuration
        print("🔍 Step 1: Validating configuration...")
        try:
            Config.validate()
            print("✅ Configuration validated")
        except ValueError as e:
            print(f"❌ Configuration Error: {e}")
            traceback.print_exc()
            return
        
        os.environ['OPENAI_API_KEY'] = Config.OPENAI_API_KEY
        print("✅ OpenAI API key set")
        
        # Get credentials
        print("\n🔍 Step 2: Getting Google API credentials...")
        try:
            creds = get_credentials()
            if not creds:
                print("❌ Error: Could not get credentials")
                traceback.print_exc()
                return
            print("✅ Credentials obtained successfully")
        except Exception as e:
            print(f"❌ Error getting credentials: {e}")
            traceback.print_exc()
            return
    
        # Clean up duplicates
        print("\n🔍 Step 3: Cleaning up duplicate tasks...")
        try:
            clean_duplicate_tasks(creds)
            print("✅ Duplicate cleanup complete")
        except Exception as e:
            print(f"⚠️  Warning during duplicate cleanup: {e}")
            traceback.print_exc()
        
        # Process each task
        print("\n🔍 Step 4: Processing tasks...")
        results = {}
        task_num = 1
        
        for task_name, task_config in TASK_ASSIGNMENTS.items():
            print(f"\n{'='*80}")
            print(f"📋 PROCESSING TASK {task_num}/{len(TASK_ASSIGNMENTS)}: {task_name}")
            print("="*80)
            print(f"Started at: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}")
            
            try:
                result = assign_and_execute_task(task_name, task_config, creds)
                results[task_name] = {
                    'status': 'success' if result else 'failed',
                    'result': result
                }
                print(f"\n✅ Task {task_num} processing complete: {task_name}")
            except Exception as e:
                print(f"\n❌ Task {task_num} failed with error: {e}")
                traceback.print_exc()
                results[task_name] = {
                    'status': 'error',
                    'error': str(e)
                }
            
            print(f"Completed at: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}")
            task_num += 1
            print()
    
        # Summary
        print("\n" + "="*80)
        print("📊 EXECUTION SUMMARY")
        print("="*80)
        print()
        
        success_count = sum(1 for r in results.values() if r['status'] == 'success')
        failed_count = sum(1 for r in results.values() if r['status'] == 'failed')
        error_count = sum(1 for r in results.values() if r['status'] == 'error')
        
        print(f"✅ Successfully processed: {success_count}/{len(results)} tasks")
        print(f"❌ Failed: {failed_count}/{len(results)} tasks")
        if error_count > 0:
            print(f"⚠️  Errors: {error_count}/{len(results)} tasks")
        print()
        
        for task_name, result_data in results.items():
            if result_data['status'] == 'success':
                status_icon = "✅"
            elif result_data['status'] == 'error':
                status_icon = "⚠️"
            else:
                status_icon = "❌"
            print(f"{status_icon} {task_name[:60]}...")
        
        print()
        print("="*80)
        print("✅ ALL TASKS PROCESSED")
        print("="*80)
        print()
        
        # Save summary
        summary_file = Path(__file__).parent / f"P3_P4_EXECUTION_SUMMARY_{datetime.now().strftime('%Y%m%d_%H%M%S')}.md"
        with open(summary_file, 'w', encoding='utf-8') as f:
            f.write(f"# P3/P4 Protocol Execution Summary\n\n")
            f.write(f"**Date:** {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n\n")
            f.write(f"## Results\n\n")
            f.write(f"- Successfully processed: {success_count}/{len(results)} tasks\n")
            f.write(f"- Failed: {failed_count}/{len(results)} tasks\n")
            if error_count > 0:
                f.write(f"- Errors: {error_count}/{len(results)} tasks\n")
            f.write(f"\n## Task Details\n\n")
            for task_name, result_data in results.items():
                f.write(f"### {task_name}\n")
                f.write(f"- Status: {result_data['status'].upper()}\n")
                if 'error' in result_data:
                    f.write(f"- Error: {result_data['error']}\n")
                if result_data.get('result'):
                    f.write(f"- Result: {str(result_data['result'])[:200]}...\n")
                f.write("\n")
        
        print(f"📄 Summary saved to: {summary_file.name}")
        print(f"📄 Full log saved to: {log_file.name}")
        print()
        
    except Exception as e:
        print(f"\n❌ FATAL ERROR: {e}")
        traceback.print_exc()
    finally:
        log_f.close()
        sys.stdout = sys.__stdout__
        sys.stderr = sys.__stderr__

if __name__ == "__main__":
    main()

