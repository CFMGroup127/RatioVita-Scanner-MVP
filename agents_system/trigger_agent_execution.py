"""
Trigger Agent Execution - Starts agents working on their assigned tasks
This script triggers primary agents to begin P4 autonomous execution
"""
import os
import sys
import yaml
from pathlib import Path
from datetime import datetime, timedelta
from crewai import Agent, Task, Crew
from langchain_openai import ChatOpenAI
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build

# Add agents_system to path
sys.path.insert(0, str(Path(__file__).parent))
os.chdir(Path(__file__).parent)

from config import Config
from tools import (
    get_google_docs_memory_tool,
    get_google_tasks_tool,
    get_file_read_tool,
    get_file_write_tool,
    get_code_execution_tool,
    get_cursor_llm_tool
)

# Task assignments
TASK_EXECUTIONS = {
    "Ethan Hayes": [
        {
            "task_id": "V2-001",
            "name": "Connect CameraCaptureView to RealScannerService",
            "priority": "P0",
            "due_date": (datetime.now() + timedelta(days=3)).strftime('%Y-%m-%d'),
            "execution_instructions": """
1. Read the current CameraCaptureView.swift file
2. Review RealScannerService API and implementation
3. Replace placeholder UI with live camera preview using AVCaptureVideoPreviewLayer
4. Implement capture button and controls
5. Wire up ScannerCoordinator properly
6. Connect to RealScannerService.scanReceipt() method
7. Handle all error states (permission denied, camera unavailable, etc.)
8. Test integration
9. Update memory document with progress
10. Submit DTR daily
            """,
            "expected_artifacts": [
                "CameraCaptureView.swift (updated)",
                "ScannerCoordinator.swift (if updated)",
                "ReceiptsViewModel.swift (if updated)"
            ]
        },
        {
            "task_id": "V2-002",
            "name": "Enhance RealScannerService & Add Review Screen",
            "priority": "P1",
            "due_date": (datetime.now() + timedelta(days=5)).strftime('%Y-%m-%d'),
            "execution_instructions": """
1. Review RealScannerService implementation
2. Enhance document detection (VNDetectRectanglesRequest)
3. Improve OCR parsing accuracy (OCRParsing.swift)
4. Create ReceiptReviewView.swift for review/retake screen
5. Implement image processing improvements
6. Test OCR accuracy
7. Update memory document with progress
8. Submit DTR daily
            """,
            "expected_artifacts": [
                "RealScannerService.swift (enhanced)",
                "OCRParsing.swift (improved)",
                "ImageProcessing.swift (tuned)",
                "ReceiptReviewView.swift (new)"
            ]
        },
        {
            "task_id": "V2-003",
            "name": "Data Layer Enhancements",
            "priority": "P2",
            "due_date": (datetime.now() + timedelta(days=7)).strftime('%Y-%m-%d'),
            "execution_instructions": """
1. Add originalSize property to ReceiptImage.swift (optional, non-breaking)
2. Create migration plan document
3. Write persistence tests (ReceiptImagePersistenceTests.swift)
4. Test SwiftData relationships
5. Update memory document with progress
6. Submit DTR daily
            """,
            "expected_artifacts": [
                "ReceiptImage.swift (updated)",
                "ReceiptImagePersistenceTests.swift (new)",
                "Migration plan document"
            ]
        },
        {
            "task_id": "V2-004",
            "name": "Cross-Platform Consistency",
            "priority": "P2",
            "due_date": (datetime.now() + timedelta(days=8)).strftime('%Y-%m-%d'),
            "execution_instructions": """
1. Verify ImageBridge used everywhere (search codebase)
2. Verify all iOS code under #if os(iOS)
3. Test macOS build compiles
4. Document platform-specific code locations
5. Update memory document with progress
6. Submit DTR daily
            """,
            "expected_artifacts": [
                "Cross-platform consistency report",
                "Updated documentation"
            ]
        }
    ],
    "Tyler Cobb": [
        {
            "task_id": "V2-005",
            "name": "Testing Suite Expansion",
            "priority": "P2",
            "due_date": (datetime.now() + timedelta(days=10)).strftime('%Y-%m-%d'),
            "execution_instructions": """
1. Create OCRParsingTests.swift with comprehensive tests
2. Create ImageProcessingTests.swift with comprehensive tests
3. Create ScannerServiceTests.swift with comprehensive tests
4. Update CI/CD configuration if needed
5. Ensure test coverage > 70%
6. Update memory document with progress
7. Submit DTR daily
            """,
            "expected_artifacts": [
                "OCRParsingTests.swift (new)",
                "ImageProcessingTests.swift (new)",
                "ScannerServiceTests.swift (new)",
                "CI/CD updates (if any)"
            ]
        }
    ]
}

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

def load_agents():
    """Load agent definitions"""
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

def read_memory_document(creds, doc_id):
    """Read memory document to check for assigned tasks"""
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

def trigger_agent_execution(agent_data, task_config, creds):
    """Trigger an agent to execute a task"""
    
    agent_name = agent_data.get('designation', 'Unknown')
    agent_role = agent_data.get('role', '')
    agent_goal = agent_data.get('goal', '')
    agent_backstory = agent_data.get('backstory', '')
    
    print(f"\n🚀 TRIGGERING EXECUTION: {agent_name}")
    print(f"   Task: {task_config['task_id']} - {task_config['name']}")
    print(f"   Priority: {task_config['priority']}")
    print()
    
    # Get execution tools
    tools = []
    try:
        tools.append(get_google_docs_memory_tool())
        tools.append(get_google_tasks_tool())
    except:
        pass
    
    # Add execution tools for engineering roles
    if agent_role in ["Lead Code Execution and V2 Development", "Process and Factual Integrity Auditor"]:
        try:
            tools.append(get_file_read_tool())
            tools.append(get_file_write_tool())
            tools.append(get_code_execution_tool())
            tools.append(get_cursor_llm_tool())
        except:
            pass
    
    # Create agent
    agent_llm = ChatOpenAI(
        model=agent_data.get('model', Config.OPENAI_MODEL),
        openai_api_key=agent_data.get('api_key', Config.OPENAI_API_KEY),
        temperature=0.7
    )
    
    agent = Agent(
        role=agent_role,
        goal=agent_goal,
        backstory=agent_backstory,
        verbose=True,
        allow_delegation=False,
        tools=tools,
        llm=agent_llm,
        max_iter=20,
        max_execution_time=1800  # 30 minutes
    )
    
    # Create task description
    task_description = f"""
**TASK: {task_config['task_id']} - {task_config['name']}**

**Priority:** {task_config['priority']}
**Due Date:** {task_config['due_date']}
**Assigned By:** Dana Flores (Admin Assistant & Workflow Funnel)

**MANDATORY PROTOCOLS:**

**P0: Acknowledge Assignment**
- Immediately acknowledge receipt
- Log acknowledgment to memory document

**P2: Log Task**
- Log task to memory document (TASKS section)
- Include full task details, priority, due date

**P3: Create Google Task**
- Create task in Google Tasks
- Set due date and priority

**P4: AUTONOMOUS EXECUTION (IMMEDIATE)**
After P3 logging, you MUST immediately begin executing this task:

{task_config['execution_instructions']}

**EXECUTION REQUIREMENTS:**
- Use your available tools (FileReadTool, FileWriteTool, CodeInterpreterTool, CursorLLMTool) as appropriate
- Do not wait - execute immediately after P3 logging
- Log progress to memory document as you work
- Document any issues or blockers

**DTR REQUIREMENT:**
- Submit Daily Task Report (DTR) in table format daily
- Store in REPORTS section of memory document
- Email to dana.flores@ratiovita.com and david.chen@ratiovita.com
- CC: collin.m@ratiovita.com
- Format: See DTR_TEMPLATE.md

**COMPLETION REQUIREMENTS:**
- Verify all acceptance criteria met
- Test/validate work completed
- Update memory document with completion status
- Mark Google Task as COMPLETE
- Include artifact references: {', '.join(task_config['expected_artifacts'])}

**CRITICAL:** You must EXECUTE the task, not just log it. Use your tools to actually complete the work.

**OUTPUT:**
1. P0: Acknowledgment logged
2. P3: Task logged to memory + Google Tasks
3. P4: Task executed with work details
4. Completion: Task marked COMPLETE with artifacts
5. DTR: Daily Task Report submitted
"""
    
    task = Task(
        description=task_description,
        agent=agent,
        expected_output=f"Task '{task_config['name']}' completed: P3 logged, P4 executed, marked COMPLETE with artifacts: {', '.join(task_config['expected_artifacts'])}"
    )
    
    # Create crew
    crew = Crew(
        agents=[agent],
        tasks=[task],
        verbose=True,
        process="sequential"
    )
    
    print("🚀 Starting agent execution...")
    print()
    
    try:
        result = crew.kickoff()
        print()
        print("="*80)
        print(f"✅ EXECUTION COMPLETE: {task_config['task_id']}")
        print("="*80)
        print()
        return result
    except Exception as e:
        print()
        print("="*80)
        print(f"❌ EXECUTION FAILED: {task_config['task_id']}")
        print("="*80)
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return None

def main():
    """Main execution"""
    print("\n" + "="*80)
    print("🚀 TRIGGERING AGENT EXECUTION - RATIOVITA V2")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    # Get credentials
    creds = get_credentials()
    if not creds:
        print("❌ Could not get credentials")
        return
    
    # Load agents
    agents = load_agents()
    print(f"✅ Loaded {len(agents)} agents\n")
    
    # Execute tasks for each agent
    results = {}
    
    for agent_name, tasks in TASK_EXECUTIONS.items():
        agent_data = find_agent_by_name(agents, agent_name)
        if not agent_data:
            print(f"❌ Could not find agent: {agent_name}")
            continue
        
        print(f"📋 Agent: {agent_name}")
        print(f"   Tasks: {len(tasks)}")
        print()
        
        for task_config in tasks:
            result = trigger_agent_execution(agent_data, task_config, creds)
            results[f"{agent_name}-{task_config['task_id']}"] = result
            
            if result:
                print(f"   ✅ {task_config['task_id']} execution completed\n")
            else:
                print(f"   ❌ {task_config['task_id']} execution failed\n")
    
    # Summary
    print("="*80)
    print("📊 EXECUTION SUMMARY")
    print("="*80)
    print()
    
    success_count = sum(1 for v in results.values() if v)
    print(f"✅ Successfully executed: {success_count}/{len(results)} tasks")
    print()
    
    for key, result in results.items():
        status = "✅" if result else "❌"
        print(f"{status} {key}")
    
    print()
    print("="*80)
    print("✅ AGENT EXECUTION TRIGGERED")
    print("="*80)
    print()
    print("📋 NEXT STEPS:")
    print("1. Agents will execute tasks autonomously (P4 protocol)")
    print("2. Agents will submit DTR daily")
    print("3. Kimi K2 will monitor and review all work")
    print("4. Kimi K2 will ensure quality standards are met")
    print()

if __name__ == "__main__":
    main()

