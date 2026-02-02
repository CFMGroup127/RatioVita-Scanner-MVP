"""
P0 Task Assignment: CCPA Compliance Fix for Samuel Reed
Based on Kimi K2's Final Assurance Audit findings.

This script assigns a critical P0 task to Samuel Reed to fix the CCPA compliance
drift identified by Kimi K2's codebase cross-reference analysis.
"""
import os
import sys
import yaml
from pathlib import Path
from datetime import datetime
from crewai import Agent, Task, Crew
from config import Config

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

def assign_p0_ccpa_fix_to_samuel():
    """
    Assign P0 critical task to Samuel Reed based on Kimi K2 audit findings.
    Uses P3 Hybrid System (Memory + Google Tasks).
    """
    print("\n" + "="*80)
    print("🚨 P0 TASK ASSIGNMENT: CCPA COMPLIANCE FIX")
    print("="*80)
    print("Source: Kimi K2 Final Assurance Audit")
    print("Priority: P0 (Critical/Blocker)")
    print("Agent: Samuel Reed (System Architect)")
    print("="*80)
    print()
    
    # Validate configuration
    try:
        Config.validate()
        print("✅ Configuration validated")
    except ValueError as e:
        print(f"❌ Configuration Error: {e}")
        return None
    
    os.environ['OPENAI_API_KEY'] = Config.OPENAI_API_KEY
    
    # Load agents
    print("📋 Loading agents...")
    try:
        agents = load_agents_from_yaml_local('agents.yaml')
        print(f"✅ Loaded {len(agents)} agents")
    except Exception as e:
        print(f"❌ Error loading agents: {e}")
        import traceback
        traceback.print_exc()
        return None
    
    # Get Samuel Reed
    samuel_role = "Lead Code Execution and V2 Development"
    samuel_agent = None
    samuel_metadata = None
    
    for agent in agents:
        if agent.role == samuel_role:
            samuel_agent = agent
            samuel_metadata = get_agent_metadata_local(samuel_role)
            break
    
    if not samuel_agent:
        print(f"❌ Error: Could not find agent with role '{samuel_role}'")
        return None
    
    if not samuel_metadata:
        print(f"❌ Error: Could not find metadata for '{samuel_role}'")
        return None
    
    print(f"✅ Found Samuel Reed: {samuel_agent.role}")
    print()
    
    # Load tools for Samuel
    from tools import get_google_docs_memory_tool, get_google_tasks_tool
    
    samuel_tools = []
    try:
        samuel_tools.append(get_google_docs_memory_tool())
    except:
        pass
    try:
        samuel_tools.append(get_google_tasks_tool())
    except:
        pass
    
    samuel_agent.tools = samuel_tools
    
    samuel_doc_id = samuel_metadata.get('memory_doc_id', '')
    if not samuel_doc_id:
        print("❌ Error: Samuel's memory_doc_id not found")
        return None
    
    # Task details based on Kimi K2 findings
    task_details = {
        'task_name': 'URGENT FIX: Implement authenticated logging hook for Python user data handling module',
        'priority': 'P0 (Critical/Blocker)',
        'source': 'Kimi K2 Final Assurance Audit',
        'risk_level': 'HIGH',
        'assigned_date': datetime.now().strftime('%Y-%m-%d'),
        'due_date': 'EOD Today',
        'description': """Kimi K2's codebase cross-reference analysis identified a critical CCPA compliance drift:

ISSUE: The Python-based user data handling module (data_processor.py) implements data anonymization correctly but uses an older library version that is missing an authenticated logging hook required under the latest CCPA addendum.

REQUIRED ACTION:
1. Update the data processing library to the latest version that includes authenticated logging
2. Integrate the authenticated logging hook into the user data handling module
3. Verify CCPA compliance is restored
4. Test the logging hook to ensure it captures all required audit trail data

This is a P0 (Critical Priority) task as it affects legal compliance and must be completed immediately.""",
        'kimi_k2_finding': 'CCPA Compliance Drift (HIGH Risk) - Missing authenticated logging hook in data_processor.py',
        'mitigation_required': 'Update library and integrate logging hook immediately'
    }
    
    # Create P3 task assignment
    task_description = f"""
**P0 CRITICAL TASK ASSIGNMENT - CCPA COMPLIANCE FIX**

You have been assigned a CRITICAL PRIORITY (P0) task based on Kimi K2's Final Assurance Audit findings.

**TASK DETAILS:**
- **Task Name:** {task_details['task_name']}
- **Priority:** {task_details['priority']}
- **Source:** {task_details['source']}
- **Risk Level:** {task_details['risk_level']}
- **Assigned:** {task_details['assigned_date']}
- **Due Date:** {task_details['due_date']}

**TASK DESCRIPTION:**
{task_details['description']}

**KIMI K2 FINDING:**
{task_details['kimi_k2_finding']}

**REQUIRED MITIGATION:**
{task_details['mitigation_required']}

**MANDATORY P3 PROTOCOL EXECUTION:**

You MUST execute the P3 (Task Sign-Off) protocol, which requires:

**STEP 1: P0 ACKNOWLEDGMENT**
- Immediately acknowledge receipt of this P0 task
- Log the acknowledgment to your memory document with timestamp

**STEP 2: P3 HYBRID LOGGING - PART A (Memory Document)**
- Use the **Google Docs Memory Tool** to update your TASKS section:
  - doc_id: {samuel_doc_id}
  - section: "TASKS"
  - subsection: "{datetime.now().strftime('%B %d, %Y')}"
  - content: "- [ ] {task_details['task_name']}\n  - Priority: P0 (Critical)\n  - Source: Kimi K2 Final Assurance Audit\n  - Due: EOD Today\n  - Status: IN PROGRESS\n  - Assigned: {task_details['assigned_date']}\n  - Risk: {task_details['risk_level']}"
  - template: "Task Tracker"

**STEP 3: P3 HYBRID LOGGING - PART B (Google Tasks)**
- Use the **Google Tasks Tool** to create the task in Google Tasks:
  - task_title: "{task_details['task_name']}"
  - task_notes: "{task_details['description']}\n\nKimi K2 Finding: {task_details['kimi_k2_finding']}"
  - due_date: "{datetime.now().strftime('%Y-%m-%d')}"
  - task_list_id: "@default"

**STEP 3: TASK EXECUTION**
- Begin work immediately on updating the library
- Integrate the authenticated logging hook
- Verify CCPA compliance restoration

**CRITICAL:** This is a P0 blocker task. It must be completed by EOD today to address the HIGH risk identified by Kimi K2.

**CRITICAL:** You must complete BOTH steps (Memory Document AND Google Tasks) to achieve full P3 compliance. The task must appear in BOTH your memory document AND the Google Tasks Sidebar.

**OUTPUT:**
After completing P3 protocol, provide confirmation:
1. Task logged to memory document (TASKS section) - SUCCESS
2. Task created in Google Tasks - SUCCESS (provide task ID if available)
3. Work has begun on the fix - CONFIRMED
"""
    
    task = Task(
        description=task_description,
        agent=samuel_agent,
        expected_output=f"P3 protocol completed: P0 task '{task_details['task_name']}' logged to memory document (TASKS section) and created in Google Tasks. Task acknowledgment and work initiation confirmed."
    )
    
    # Create crew
    print("🚀 Creating crew for P0 task assignment...")
    crew = Crew(
        agents=[samuel_agent],
        tasks=[task],
        verbose=True
    )
    
    print("✅ Crew created")
    print()
    print("="*80)
    print("Starting P0 task assignment via P3 protocol...")
    print("="*80)
    print()
    
    try:
        result = crew.kickoff()
        
        print()
        print("="*80)
        print("✅ P0 TASK ASSIGNMENT COMPLETE")
        print("="*80)
        print()
        print("📊 Result:")
        print(result)
        print()
        print("="*80)
        print("🔍 VERIFICATION CHECKLIST:")
        print("="*80)
        print()
        print("✅ Internal Audit (Memory Document):")
        print("   - Check Samuel Reed's TASKS section")
        print("   - Verify task is logged with P0 priority")
        print()
        print("✅ External Audit (Google Tasks):")
        print("   - Check Google Tasks sidebar")
        print("   - Verify task appears with high priority")
        print("   - Verify due date is set to today")
        print()
        print("✅ Task Execution:")
        print("   - Samuel Reed should begin work immediately")
        print("   - Library update and logging hook integration in progress")
        print()
        
        return result
        
    except Exception as e:
        print()
        print("="*80)
        print("❌ P0 TASK ASSIGNMENT FAILED")
        print("="*80)
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    assign_p0_ccpa_fix_to_samuel()

