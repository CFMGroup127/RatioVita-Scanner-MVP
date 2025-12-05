"""
Targeted P3 Hybrid System Test - Arthur Jensen
Tests the new universal P3 fix (Memory + Google Tasks) on a single agent.
"""
import os
import sys
from datetime import datetime
from crewai import Agent, Task, Crew
from main import load_agents_from_yaml, get_agent_metadata

def test_p3_hybrid_arthur():
    """Test P3 hybrid system (Memory + Google Tasks) on Arthur Jensen"""
    print("🧪 TESTING P3 HYBRID SYSTEM - ARTHUR JENSEN")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    # Find Arthur Jensen
    agents = load_agents_from_yaml('agents.yaml')
    arthur_agent = None
    
    for agent in agents:
        role = agent.role
        if "Legal Compliance" in role or "Risk Assessor" in role:
            arthur_agent = agent
            break
    
    if not arthur_agent:
        print("❌ Error: Arthur Jensen agent not found")
        return False
    
    # Get his metadata
    meta = get_agent_metadata(arthur_agent.role)
    arthur_name = meta.get('email_address', '').split('@')[0].replace('.', ' ').title()
    arthur_memory_doc_id = meta.get('memory_doc_id', '')
    
    if not arthur_memory_doc_id:
        print("❌ Error: Arthur Jensen memory_doc_id not found")
        return False
    
    # Arthur's assigned task from the meeting
    assigned_task = {
        'task': 'Draft legal risk assessment for V2 feature set, focusing on data privacy and compliance requirements',
        'deadline': 'EOD Friday, November 21, 2025',
        'assigned_date': 'November 21, 2025',
        'meeting': 'Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning'
    }
    
    today = datetime.now().strftime('%B %d, %Y')
    
    print(f"📋 Agent: {arthur_name} ({arthur_agent.role})")
    print(f"📄 Memory Doc ID: {arthur_memory_doc_id}")
    print(f"📝 Assigned Task: {assigned_task['task']}")
    print(f"⏰ Deadline: {assigned_task['deadline']}\n")
    
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
  - Due Date: "2025-11-21" (or parse from deadline if possible)
  - Task List ID: "@default" (default task list)
  
**CRITICAL:** 
- You must complete BOTH parts (Memory Document AND Google Tasks)
- The Memory Document provides AI-auditable trail
- The Google Tasks entry makes the task visible in the Google Tasks Sidebar for human interaction
- This is the Hybrid System: tasks exist in both systems simultaneously
"""
    
    expected_output = f"P3 Hybrid System test complete: Task '{assigned_task['task']}' logged to both memory document (TASKS section) AND Google Tasks (visible in sidebar)"
    
    task = Task(
        description=task_description,
        agent=arthur_agent,
        expected_output=expected_output
    )
    
    print("🚀 Executing P3 Hybrid System test...")
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
    success = test_p3_hybrid_arthur()
    sys.exit(0 if success else 1)

