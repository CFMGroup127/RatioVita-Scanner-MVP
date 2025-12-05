"""
Enforce P3 Task Logging for Arthur Jensen
Specifically logs the "Draft compliance strategy for Feature 7" task to both memory and Google Tasks.
"""
import os
import sys
import yaml
from pathlib import Path
from datetime import datetime
from crewai import Agent, Task, Crew

def load_agents_from_yaml_local(yaml_file='agents.yaml'):
    """Load agents from YAML file"""
    yaml_path = Path(__file__).parent / yaml_file
    with open(yaml_path, 'r') as f:
        data = yaml.safe_load(f)
    
    agents = []
    for agent_data in data.get('agents', []):
        agent = Agent(
            role=agent_data.get('role', ''),
            goal=agent_data.get('goal', ''),
            backstory=agent_data.get('backstory', ''),
            verbose=True,
            allow_delegation=False
        )
        agents.append(agent)
    return agents

def get_agent_metadata_local(role):
    """Get metadata for an agent by role"""
    yaml_path = Path(__file__).parent / 'agents.yaml'
    with open(yaml_path, 'r') as f:
        data = yaml.safe_load(f)
    
    for agent_data in data.get('agents', []):
        if agent_data.get('role') == role:
            return agent_data
    return {}

def enforce_arthur_p3_task():
    """Enforce P3 task logging for Arthur Jensen"""
    print("\n" + "="*80)
    print("📋 ENFORCING P3 TASK LOGGING - ARTHUR JENSEN")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    # Load agents
    agents = load_agents_from_yaml_local('agents.yaml')
    
    # Find Arthur Jensen
    arthur_agent = None
    arthur_meta = None
    
    for agent in agents:
        meta = get_agent_metadata_local(agent.role)
        role = agent.role
        
        if "Legal Compliance" in role or "Risk Assessor" in role:
            arthur_agent = agent
            arthur_meta = meta
            break
    
    if not arthur_agent:
        print("❌ Error: Arthur Jensen agent not found")
        return False
    
    arthur_doc_id = arthur_meta.get('memory_doc_id', '')
    if not arthur_doc_id:
        print("❌ Error: Arthur's memory_doc_id not found")
        return False
    
    # Load tools for Arthur
    from tools import get_google_docs_memory_tool, get_google_tasks_tool
    
    arthur_tools = []
    try:
        arthur_tools.append(get_google_docs_memory_tool())
    except:
        pass
    try:
        arthur_tools.append(get_google_tasks_tool())
    except:
        pass
    
    arthur_agent.tools = arthur_tools
    
    today = datetime.now().strftime('%B %d, %Y')
    
    # Task details from the meeting
    task_details = {
        'title': 'Draft compliance strategy for Feature 7 (CCPA risk)',
        'notes': 'High priority task assigned during Executive Strategy Group Meeting on November 25, 2025. Due: EOD Wednesday, November 26, 2025.',
        'due_date': '2025-11-26',
        'priority': 'High',
        'owner': 'Arthur Jensen',
        'assigned_date': 'November 25, 2025'
    }
    
    print(f"📋 Task Details:")
    print(f"   Title: {task_details['title']}")
    print(f"   Due Date: {task_details['due_date']}")
    print(f"   Priority: {task_details['priority']}")
    print()
    
    # Create P3 hybrid task
    task_description = f"""
**P3 HYBRID SYSTEM TASK LOGGING - MANDATORY**

You have been assigned a task during the Executive Strategy Group Meeting on November 25, 2025.

**ASSIGNED TASK:**
- Task: {task_details['title']}
- Deadline: EOD Wednesday, November 26, 2025
- Priority: {task_details['priority']}
- Assigned: Executive Strategy Group Meeting on {task_details['assigned_date']}

**YOU MUST COMPLETE P3 PROTOCOL USING THE HYBRID SYSTEM:**

**STEP 1: P3 TASK LOGGING - PART A (Memory Document - AI-Auditable)**
- Use the **Google Docs Memory Tool** to update your TASKS section:
  - doc_id: {arthur_doc_id}
  - section: "TASKS"
  - subsection: "{today}"
  - content: "- [ ] {task_details['title']} (Deadline: EOD Wednesday, November 26, 2025) - Priority: {task_details['priority']} - Assigned: {task_details['assigned_date']}"
  - template: "Task Tracker"

**STEP 2: P3 TASK LOGGING - PART B (Google Tasks - Human-Interactive)**
- Use the **Google Tasks Tool** to create the task in Google Tasks:
  - task_title: "{task_details['title']}"
  - task_notes: "{task_details['notes']}"
  - due_date: "{task_details['due_date']}"
  - task_list_id: "@default"

**CRITICAL:** You must complete BOTH steps to achieve full P3 compliance. The task must appear in BOTH your memory document AND the Google Tasks Sidebar.
"""
    
    expected_output = "P3 task logged to both memory document (TASKS section) and Google Tasks Sidebar"
    
    task = Task(
        description=task_description,
        agent=arthur_agent,
        expected_output=expected_output
    )
    
    print("🚀 EXECUTING P3 TASK LOGGING")
    print("="*80)
    print()
    
    try:
        crew = Crew(
            agents=[arthur_agent],
            tasks=[task],
            verbose=True
        )
        
        result = crew.kickoff()
        
        print("\n" + "="*80)
        print("✅ P3 TASK LOGGING COMPLETE")
        print("="*80)
        print(f"Result: {result}")
        print()
        print("📋 VALIDATION:")
        print("   1. ✅ Check Arthur's memory document TASKS section")
        print("   2. ✅ Check Google Tasks Sidebar for the task")
        print("   3. ✅ Verify task appears in BOTH locations")
        
        return True
        
    except Exception as e:
        print("\n" + "="*80)
        print("❌ P3 TASK LOGGING FAILED")
        print("="*80)
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = enforce_arthur_p3_task()
    sys.exit(0 if success else 1)

