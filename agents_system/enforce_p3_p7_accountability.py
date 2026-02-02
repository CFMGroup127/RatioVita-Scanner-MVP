"""
Enforce P3/P7 Accountability
Forces Dana Flores and Alice Kim to complete P3 (Task Sign-Off) and P7 (Collaboration Checkpoint) protocols
for their assigned tasks from the meeting.
"""
import os
import sys
from datetime import datetime
from crewai import Agent, Task, Crew
from main import load_agents_from_yaml, get_agent_metadata
from force_meeting_retroactive_logging import parse_meeting_outcomes_file

def enforce_p3_p7_accountability():
    """Force Dana and Alice to complete P3/P7 protocols for their assigned tasks"""
    print("📋 ENFORCING P3/P7 ACCOUNTABILITY")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    # Parse meeting outcomes to get action items
    meeting_data = parse_meeting_outcomes_file('MEETING_OUTCOMES_V1.txt')
    action_items = meeting_data['action_items']
    
    # Find Dana Flores and Alice Kim
    agents = load_agents_from_yaml('agents.yaml')
    dana_agent = None
    alice_agent = None
    
    for agent in agents:
        role = agent.role
        if role == "Admin Assistant & Workflow Funnel":
            dana_agent = agent
        elif role == "Documentation and Knowledge Archivist":
            alice_agent = agent
    
    if not dana_agent:
        print("❌ Error: Dana Flores agent not found")
        return False
    
    if not alice_agent:
        print("❌ Error: Alice Kim agent not found")
        return False
    
    # Get their metadata
    dana_meta = get_agent_metadata(dana_agent.role)
    alice_meta = get_agent_metadata(alice_agent.role)
    
    dana_name = dana_meta.get('email_address', '').split('@')[0].replace('.', ' ').title()
    alice_name = alice_meta.get('email_address', '').split('@')[0].replace('.', ' ').title()
    
    dana_memory_doc_id = dana_meta.get('memory_doc_id', '')
    alice_memory_doc_id = alice_meta.get('memory_doc_id', '')
    
    dana_email = dana_meta.get('email_address', '')
    alice_email = alice_meta.get('email_address', '')
    
    today = datetime.now().strftime('%B %d, %Y')
    
    # Find their assigned tasks
    dana_tasks = [ai for ai in action_items if 'Dana' in ai['owner'] or 'Admin Assistant' in ai['owner']]
    alice_tasks = [ai for ai in action_items if 'Alice' in ai['owner'] or 'Documentation' in ai['owner']]
    
    print(f"📋 Dana Flores Tasks: {len(dana_tasks)}")
    for task in dana_tasks:
        print(f"   - {task['task']} (Deadline: {task['deadline']})")
    
    print(f"\n📋 Alice Kim Tasks: {len(alice_tasks)}")
    for task in alice_tasks:
        print(f"   - {task['task']} (Deadline: {task['deadline']})")
    
    print()
    
    # Create tasks for Dana
    dana_tasks_list = []
    if dana_tasks:
        for task_item in dana_tasks:
            task_description = f"""
**MANDATORY P3/P7 PROTOCOL ENFORCEMENT**

You have been assigned a task from the Executive Strategy Group Meeting that requires P3 (Task Sign-Off) and P7 (Collaboration Checkpoint) protocols.

**ASSIGNED TASK:**
- Task: {task_item['task']}
- Deadline: {task_item['deadline']}
- Assigned: Executive Strategy Group Meeting, November 20, 2025

**YOU MUST COMPLETE THE FOLLOWING PROTOCOLS:**

**STEP 1: P3 TASK SIGN-OFF (Hybrid System - Memory + Google Tasks)**
- **PART A: Memory Document (AI-Auditable)**
  - Use the **Google Docs Memory Tool** to update your TASKS section:
    - doc_id: {dana_memory_doc_id}
    - section: "TASKS"
    - subsection: "{today}"
    - content: "- [x] {task_item['task']} (P3 Signed Off: {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')})"
    - template: "Task Tracker"

- **PART B: Google Tasks (Human-Interactive Sidebar)**
  - Use the **Google Tasks Tool** to create/update the task in Google Tasks:
    - Task Title: {task_item['task']}
    - Task Notes: "P3 Signed Off: {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}. Assigned: Executive Strategy Group Meeting, November 20, 2025"
    - Due Date: {task_item['deadline']}
    - This makes the task visible in the Google Tasks Sidebar

**STEP 2: P3 ARTIFACT LOG (WORKFLOW MANAGEMENT Section)**
- Use the **Google Docs Memory Tool** to log the completion artifact:
  - doc_id: {dana_memory_doc_id}
  - section: "WORKFLOW MANAGEMENT"
  - content: "### {task_item['task']} (P3 Completion)\n\n**Status:** COMPLETED {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}\n**Artifact:** [Google Sheets URL or document reference]\n**Protocol:** P3 Sign-Off Confirmed.\n\n**Details:**\n[Describe what was completed and provide the artifact URL]"
  - template: "Admin"

**STEP 3: P7 DELEGATION LOG (If You Delegated Any Part)**
- If you delegated any part of this task, use the **Google Docs Memory Tool**:
  - doc_id: {dana_memory_doc_id}
  - section: "DELEGATION LOG"
  - content: "### Delegation Entry: [Recipient Name]\n\n**Task:** [Delegated portion]\n**Recipient:** [Agent name and email]\n**Time Sent:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}\n**Status:** Sent. Awaiting P0 Acknowledgment from recipient."
  - template: "Admin"

**CRITICAL:** You must provide the artifact URL (Google Sheets, document, etc.) as proof of completion. This is required for closed-loop accountability.
"""
            
            task = Task(
                description=task_description,
                agent=dana_agent,
                expected_output=f"P3/P7 protocols completed: Task marked complete in TASKS section, artifact logged in WORKFLOW MANAGEMENT section, and delegation logged (if applicable) for: {task_item['task']}"
            )
            dana_tasks_list.append(task)
    
    # Create tasks for Alice
    alice_tasks_list = []
    if alice_tasks:
        for task_item in alice_tasks:
            task_description = f"""
**MANDATORY P3/P7 PROTOCOL ENFORCEMENT**

You have been assigned a task from the Executive Strategy Group Meeting that requires P3 (Task Sign-Off) protocol.

**ASSIGNED TASK:**
- Task: {task_item['task']}
- Deadline: {task_item['deadline']}
- Assigned: Executive Strategy Group Meeting, November 20, 2025

**YOU MUST COMPLETE THE FOLLOWING PROTOCOLS:**

**STEP 1: P3 TASK SIGN-OFF (Hybrid System - Memory + Google Tasks)**
- **PART A: Memory Document (AI-Auditable)**
  - Use the **Google Docs Memory Tool** to update your TASKS section:
    - doc_id: {alice_memory_doc_id}
    - section: "TASKS"
    - subsection: "{today}"
    - content: "- [x] {task_item['task']} (P3 Signed Off: {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')})"
    - template: "Task Tracker"

- **PART B: Google Tasks (Human-Interactive Sidebar)**
  - Use the **Google Tasks Tool** to create/update the task in Google Tasks:
    - Task Title: {task_item['task']}
    - Task Notes: "P3 Signed Off: {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}. Assigned: Executive Strategy Group Meeting, November 20, 2025"
    - Due Date: {task_item['deadline']}
    - This makes the task visible in the Google Tasks Sidebar

**STEP 2: P3 ARTIFACT LOG (REPORTS Section)**
- Use the **Google Docs Memory Tool** to log the completion artifact:
  - doc_id: {alice_memory_doc_id}
  - section: "REPORTS"
  - subsection: "{today}"
  - content: "### {task_item['task']} - P3 Completion Report\n\n**Status:** COMPLETED {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}\n**Artifact:** [Documentation URL, archive location, or reference]\n**Protocol:** P3 Sign-Off Confirmed.\n\n**Details:**\n[Describe what was completed and provide the artifact URL or reference]"
  - template: "Report Archive"

**CRITICAL:** You must provide the artifact URL or reference (documentation location, archive path, etc.) as proof of completion. This is required for closed-loop accountability.
"""
            
            task = Task(
                description=task_description,
                agent=alice_agent,
                expected_output=f"P3 protocol completed: Task marked complete in TASKS section and artifact logged in REPORTS section for: {task_item['task']}"
            )
            alice_tasks_list.append(task)
    
    # Execute tasks
    all_tasks = dana_tasks_list + alice_tasks_list
    
    if not all_tasks:
        print("⚠️  No tasks found for Dana or Alice")
        return False
    
    print(f"📋 Created {len(all_tasks)} P3/P7 enforcement tasks\n")
    
    # Process sequentially
    success_count = 0
    error_count = 0
    
    for i, task in enumerate(all_tasks, 1):
        agent = task.agent
        agent_name = agent.role
        print(f"[{i}/{len(all_tasks)}] Processing: {agent_name}")
        print("-" * 80)
        
        try:
            crew = Crew(
                agents=[agent],
                tasks=[task],
                verbose=True
            )
            
            result = crew.kickoff()
            print(f"\n[{agent_name}]: ✅ P3/P7 protocol complete")
            success_count += 1
        except Exception as e:
            print(f"\n[{agent_name}]: ❌ Error: {e}")
            import traceback
            traceback.print_exc()
            error_count += 1
        
        print("-" * 80)
    
    print("\n" + "="*80)
    print("✅ P3/P7 ENFORCEMENT COMPLETE")
    print("="*80)
    print(f"Total Tasks: {len(all_tasks)}")
    print(f"✅ Successful: {success_count}")
    print(f"❌ Errors: {error_count}")
    
    return success_count > 0

if __name__ == "__main__":
    success = enforce_p3_p7_accountability()
    sys.exit(0 if success else 1)

