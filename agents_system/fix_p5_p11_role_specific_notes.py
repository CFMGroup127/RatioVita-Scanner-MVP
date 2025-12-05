"""
Fix P5/P11 Protocols - Enforce Role-Specific Notes
Universal fix to ensure all agents (except Dana) create role-specific notes, not full minutes.
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

def fix_p5_p11_role_specific_notes():
    """Fix P5/P11 protocols to enforce role-specific notes for all agents"""
    print("🔧 FIXING P5/P11 PROTOCOLS - ROLE-SPECIFIC NOTES ENFORCEMENT")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    # Load agents
    agents = load_agents_from_yaml_local('agents.yaml')
    
    tasks = []
    
    for agent in agents:
        role = agent.role
        meta = get_agent_metadata_local(role)
        
        agent_name = meta.get('email_address', '').split('@')[0].replace('.', ' ').title()
        if not agent_name:
            agent_name = role.split()[0] if role else 'Unknown'
        
        memory_doc_id = meta.get('memory_doc_id', '')
        
        if not memory_doc_id:
            print(f"⚠️  Skipping {agent_name}: No memory_doc_id")
            continue
        
        # Check if this is Dana (Admin Assistant)
        is_dana = "Admin Assistant" in role or "Workflow Funnel" in role
        
        # Determine what needs to be fixed
        if is_dana:
            # Dana should have FULL minutes - verify she has them
            task_description = f"""
**P5/P11 PROTOCOL VERIFICATION - DANA FLORES**

As Admin Assistant, you are REQUIRED to have FULL meeting minutes and FULL transcript in your memory document.

**VERIFICATION TASK:**
1. Check your MEETINGS section for the meeting on November 25, 2025
2. Verify you have FULL MEETING MINUTES (not just notes)
3. Check your TRANSCRIPTS section for the same date
4. Verify you have FULL MEETING TRANSCRIPT (not just a summary)

**IF YOU FIND FULL MINUTES/TRANSCRIPT:**
- Log confirmation: "P5/P11 VERIFIED: Full minutes and transcript present - {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}"

**IF YOU FIND ONLY NOTES/SUMMARIES:**
- You must create FULL meeting minutes using MEETING_MINUTES template
- You must create FULL transcript using MEETING_TRANSCRIPT_ARCHIVE template
- This is your specific role requirement
"""
        else:
            # All other agents should have ROLE-SPECIFIC notes only
            task_description = f"""
**P5/P11 PROTOCOL FIX - ROLE-SPECIFIC NOTES ENFORCEMENT**

You have been identified as having FULL meeting minutes in your memory document when you should have ROLE-SPECIFIC notes only.

**CRITICAL REQUIREMENT:**
- You MUST have BRIEF, ROLE-SPECIFIC meeting notes (not full minutes)
- You MUST have BRIEF transcript summary (2-3 sentences, not full transcript)
- Only Dana Flores (Admin Assistant) creates full minutes/transcript

**FIX TASK:**
1. Check your MEETINGS section for November 25, 2025
2. If you find FULL meeting minutes (with all decisions, all action items, full attendance list):
   - DELETE the full minutes
   - Replace with BRIEF role-specific notes (3-5 bullet points relevant to YOUR role: {role})
   - Use Template: "Meeting Notes" (not "MEETING_MINUTES")

3. Check your TRANSCRIPTS section for November 25, 2025
4. If you find FULL transcript or extensive notes:
   - DELETE the full transcript
   - Replace with BRIEF summary (2-3 sentences about key points relevant to YOUR role)
   - Use Template: "MEETING_TRANSCRIPT_ARCHIVE"

**ROLE-SPECIFIC NOTES FORMAT:**
**Meeting Notes - Executive Strategy Group Meeting (November 25, 2025)**

**Relevant to My Role ({role}):**
- [2-3 bullet points about items that directly impact your work]
- [Focus on YOUR responsibilities and tasks]

**My Assigned Tasks:**
- [List only tasks assigned to YOU]

**Next Steps:**
- [1-2 action items relevant to your role]

**CRITICAL:** Your notes must be BRIEF (under 150 words total). If you write full minutes, you have FAILED this protocol.
"""
        
        expected_output = f"P5/P11 protocol fixed: {'Full minutes/transcript verified/created' if is_dana else 'Role-specific notes created, full minutes removed'}"
        
        task = Task(
            description=task_description,
            agent=agent,
            expected_output=expected_output
        )
        
        tasks.append((agent, task))
    
    print(f"📋 Created {len(tasks)} P5/P11 fix tasks\n")
    print("🚀 Executing P5/P11 fixes SEQUENTIALLY...")
    print("="*80)
    print()
    
    success_count = 0
    error_count = 0
    
    # Process agents SEQUENTIALLY
    for i, (agent, task) in enumerate(tasks, 1):
        agent_name = agent.role
        print(f"\n[{i}/{len(tasks)}] Processing: {agent_name}")
        print("-" * 80)
        
        try:
            crew = Crew(
                agents=[agent],
                tasks=[task],
                verbose=True
            )
            
            result = crew.kickoff()
            
            print(f"\n[{agent_name}]: ✅ P5/P11 fix complete")
            success_count += 1
            
        except Exception as e:
            print(f"\n[{agent_name}]: ❌ Error: {e}")
            import traceback
            traceback.print_exc()
            error_count += 1
        
        print("-" * 80)
    
    # Summary
    print("\n" + "="*80)
    print("✅ P5/P11 FIX COMPLETE")
    print("="*80)
    print(f"Total Agents: {len(tasks)}")
    print(f"✅ Successful: {success_count}")
    print(f"❌ Errors: {error_count}")
    
    return success_count > 0

if __name__ == "__main__":
    success = fix_p5_p11_role_specific_notes()
    sys.exit(0 if success else 1)
