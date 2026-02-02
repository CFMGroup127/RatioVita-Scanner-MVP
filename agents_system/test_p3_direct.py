"""
Direct P3 Hybrid System Test - Arthur Jensen
Tests P3 protocol directly without circular import issues.
"""
import os
import sys
import yaml
from datetime import datetime
from crewai import Agent, Task, Crew
from langchain_openai import ChatOpenAI
from config import Config
from tools import get_google_docs_memory_tool, get_google_tasks_tool

def test_p3_direct():
    """Test P3 hybrid system directly on Arthur Jensen"""
    print("🧪 DIRECT P3 HYBRID SYSTEM TEST - ARTHUR JENSEN")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    # Load agents.yaml directly
    with open('agents.yaml', 'r') as f:
        data = yaml.safe_load(f)
    
    # Find Arthur Jensen
    arthur_data = None
    for agent_data in data.get('agents', []):
        if "Legal Compliance" in agent_data.get('role', '') or "Risk Assessor" in agent_data.get('role', ''):
            arthur_data = agent_data
            break
    
    if not arthur_data:
        print("❌ Error: Arthur Jensen not found in agents.yaml")
        return False
    
    # Extract metadata
    arthur_name = arthur_data.get('email_address', '').split('@')[0].replace('.', ' ').title()
    arthur_memory_doc_id = arthur_data.get('memory_doc_id', '')
    role = arthur_data.get('role', '')
    backstory = arthur_data.get('backstory', '')
    goal = arthur_data.get('goal', '')
    
    if not arthur_memory_doc_id:
        print("❌ Error: Arthur Jensen memory_doc_id not found")
        return False
    
    # Arthur's assigned task
    assigned_task = {
        'task': 'Draft legal risk assessment for V2 feature set, focusing on data privacy and compliance requirements',
        'deadline': 'EOD Friday, November 21, 2025',
        'assigned_date': 'November 21, 2025',
        'meeting': 'Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning'
    }
    
    today = datetime.now().strftime('%B %d, %Y')
    
    print(f"📋 Agent: {arthur_name} ({role})")
    print(f"📄 Memory Doc ID: {arthur_memory_doc_id}")
    print(f"📝 Assigned Task: {assigned_task['task']}")
    print(f"⏰ Deadline: {assigned_task['deadline']}\n")
    
    # Get tools
    memory_tool = get_google_docs_memory_tool()
    tasks_tool = get_google_tasks_tool()
    
    # Create agent
    agent_llm = ChatOpenAI(
        model=arthur_data.get('model', Config.OPENAI_MODEL),
        openai_api_key=arthur_data.get('api_key', Config.OPENAI_API_KEY),
        temperature=0.7
    )
    
    agent = Agent(
        role=role,
        goal=goal,
        backstory=backstory,
        verbose=True,
        allow_delegation=False,
        tools=[memory_tool, tasks_tool],
        llm=agent_llm
    )
    
    # Create P3 hybrid task
    task_description = f"""
**P3 HYBRID SYSTEM TEST - TASK LOGGING**

You have been assigned a task that requires P3 protocol compliance using the NEW Hybrid System.

**ASSIGNED TASK:**
- Task: {assigned_task['task']}
- Deadline: {assigned_task['deadline']}
- Assigned: {assigned_task['meeting']} on {assigned_task['assigned_date']}

**YOU MUST COMPLETE P3 PROTOCOL USING THE HYBRID SYSTEM:**

**STEP 1: P3 TASK LOGGING - PART A (Memory Document - AI-Auditable)**
- Use the **Google Docs Memory Tool** to update your TASKS section:
  - doc_id: {arthur_memory_doc_id}
  - section: "TASKS"
  - subsection: "{today}"
  - content: "- [ ] {assigned_task['task']} (Deadline: {assigned_task['deadline']}) - Assigned: {assigned_task['assigned_date']}"
  - template: "Task Tracker"

**STEP 2: P3 TASK LOGGING - PART B (Google Tasks - Human-Interactive)**
- Use the **Google Tasks Tool** to create the task in Google Tasks:
  - Task Title: "{assigned_task['task']}"
  - Task Notes: "Assigned during {assigned_task['meeting']} on {assigned_task['assigned_date']}. Deadline: {assigned_task['deadline']}"
  - Due Date: "2025-11-21"
  - Task List ID: "@default"
  
**CRITICAL:** 
- You must complete BOTH parts (Memory Document AND Google Tasks)
- The Memory Document provides AI-auditable trail
- The Google Tasks entry makes the task visible in the Google Tasks Sidebar for human interaction
- This is the Hybrid System: tasks exist in both systems simultaneously
"""
    
    expected_output = f"P3 Hybrid System test complete: Task '{assigned_task['task']}' logged to both memory document (TASKS section) AND Google Tasks (visible in sidebar)"
    
    task = Task(
        description=task_description,
        agent=agent,
        expected_output=expected_output
    )
    
    print("🚀 Executing P3 Hybrid System test...")
    print("="*80)
    print()
    
    try:
        crew = Crew(
            agents=[agent],
            tasks=[task],
            verbose=True
        )
        
        result = crew.kickoff()
        
        print("\n" + "="*80)
        print("✅ P3 HYBRID SYSTEM TEST COMPLETE")
        print("="*80)
        print(f"Agent: {arthur_name}")
        print(f"Task: {assigned_task['task']}")
        print(f"\nResult:")
        print(result)
        print("\n📋 Validation Checklist:")
        print("   1. ✅ Check Arthur's memory document TASKS section")
        print("   2. ✅ Check Google Tasks Sidebar for new task")
        print("   3. ✅ Verify task appears in both locations")
        
        return True
        
    except Exception as e:
        print(f"\n❌ Error during test: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = test_p3_direct()
    sys.exit(0 if success else 1)

