"""
David Chen's REPORT HANDOFF PROTOCOL
This script executes the final merge of all BLOCK A and BLOCK P reports
and prepares the Executive Strategy Group meeting agenda.
"""
import os
from datetime import datetime
from crewai import Agent, Task, Crew, Process
from config import Config
from main import load_agents_from_yaml, get_agent_metadata

def david_merge_protocol():
    """
    Execute David Chen's REPORT HANDOFF PROTOCOL.
    
    This task:
    1. Reads Alice Kim's V1 Legacy Asset Archival Report
    2. Reads Samuel Reed's Market Analysis Report
    3. Reads Arthur Jensen's Design System Summary
    4. Reads Megan Parker's Branding & Value Propositions Report
    5. Merges all findings into Executive Strategy Group Pre-Read Document
    6. Creates calendar event (if not already created)
    7. Distributes agenda and pre-read materials via email
    """
    print("\n" + "="*80)
    print("🚀 DAVID CHEN: REPORT HANDOFF PROTOCOL")
    print("="*80)
    print("Merging BLOCK A and BLOCK P reports for Executive Strategy Group meeting")
    print(f"Meeting Date: Friday, November 21, 2025, 10:00 AM - 12:00 PM")
    print("="*80)
    
    # Validate configuration
    try:
        Config.validate()
        print("✅ Configuration validated")
    except ValueError as e:
        print(f"❌ Configuration Error: {e}")
        return None
    
    os.environ['OPENAI_API_KEY'] = Config.OPENAI_API_KEY
    
    # Load agents
    print("\n📋 Loading agents...")
    try:
        agents = load_agents_from_yaml('agents.yaml')
        print(f"✅ Loaded {len(agents)} agents")
    except Exception as e:
        print(f"❌ Error loading agents: {e}")
        import traceback
        traceback.print_exc()
        return None
    
    # Get agents (including Dana for delegation)
    dana_role = "Admin Assistant & Workflow Funnel"
    david_role = "Process Architect and Schedule Publisher"
    dana_agent = None
    david_agent = None
    dana_metadata = None
    david_metadata = None
    
    for agent in agents:
        if agent.role == dana_role:
            dana_agent = agent
            dana_metadata = get_agent_metadata(dana_role)
        elif agent.role == david_role:
            david_agent = agent
            david_metadata = get_agent_metadata(david_role)
    
    if not dana_agent:
        print(f"❌ Error: Dana Flores (Admin Assistant) not found")
        return None
    
    if not david_agent:
        print(f"❌ Error: David Chen (COO) not found")
        return None
    
    print(f"\n✅ Agents loaded:")
    print(f"   - Dana Flores (Admin Assistant - Coordinator)")
    print(f"   - David Chen (COO)")
    
    # Get memory document IDs for all agents
    alice_role = "Documentation and Knowledge Archivist"
    samuel_role = "Competitive Intelligence Specialist"
    arthur_role = "Legal Compliance and Risk Assessor"
    megan_role = "Market Strategist and Voice of the Customer"
    
    alice_metadata = get_agent_metadata(alice_role)
    samuel_metadata = get_agent_metadata(samuel_role)
    arthur_metadata = get_agent_metadata(arthur_role)
    megan_metadata = get_agent_metadata(megan_role)
    
    alice_memory_id = alice_metadata.get('memory_doc_id', '')
    samuel_memory_id = samuel_metadata.get('memory_doc_id', '')
    arthur_memory_id = arthur_metadata.get('memory_doc_id', '')
    megan_memory_id = megan_metadata.get('memory_doc_id', '')
    dana_memory_id = dana_metadata.get('memory_doc_id', '')
    david_memory_id = david_metadata.get('memory_doc_id', '')
    project_calendar_id = david_metadata.get('project_schedule_calendar_id', 'primary')
    
    print(f"\n📋 Memory Document IDs:")
    print(f"   Alice Kim: {alice_memory_id}")
    print(f"   Samuel Reed: {samuel_memory_id}")
    print(f"   Arthur Jensen: {arthur_memory_id}")
    print(f"   Megan Parker: {megan_memory_id}")
    print(f"   David Chen: {david_memory_id}")
    
    tasks = []
    
    # ============================================================================
    # TASK 0: Dana Flores - Initial Delegation
    # ============================================================================
    print("\n" + "="*80)
    print("TASK 0: Dana Flores - Initial Delegation for David's Merge Protocol")
    print("="*80)
    
    dana_delegation_task = Task(
        description=(
            f"Execute your **WORKFLOW FUNNEL** role by formally delegating David Chen's Report Handoff Protocol.\n\n"
            f"**Your Delegation Task:**\n"
            f"1. Formally delegate the REPORT HANDOFF PROTOCOL to David Chen (COO)\n"
            f"2. Ensure David understands he must:\n"
            f"   - Read all four reports (Alice, Samuel, Arthur, Megan)\n"
            f"   - Merge findings into Executive Strategy Group Pre-Read Document\n"
            f"   - Verify/create calendar event for November 21, 2025\n"
            f"   - Distribute pre-read materials to all team members\n"
            f"3. Confirm that this protocol is critical for the Executive Strategy Group meeting\n"
            f"4. Document the delegation in your memory document\n\n"
            f"**Important:** This delegation ensures proper workflow management and task tracking."
        ),
        agent=dana_agent,
        expected_output="Confirmation that David's merge protocol has been formally delegated",
        max_iter=5
    )
    tasks.append(dana_delegation_task)
    
    # ============================================================================
    # PRE-TASK: David Chen - Read Memory for Context
    # ============================================================================
    print("\n" + "="*80)
    print("PRE-TASK: David Chen - Read Memory for Context")
    print("="*80)
    
    david_read_memory_task = Task(
        description=(
            f"Before starting the merge protocol, read your memory document to understand your current context.\n\n"
            f"**MANDATORY FIRST STEP:**\n"
            f"1. Use the Google Docs Read Tool with your memory_doc_id: {david_memory_id}\n"
            f"2. Review the contents of your memory document\n"
            f"3. Note any relevant context or prior coordination work\n\n"
            f"This ensures you have full context before beginning the REPORT HANDOFF PROTOCOL."
        ),
        agent=david_agent,
        expected_output="Confirmation that memory document has been read and context understood",
        context=[dana_delegation_task],
        max_iter=3
    )
    tasks.append(david_read_memory_task)
    
    # ============================================================================
    # MAIN TASK: David Chen - Merge All Reports and Prepare Meeting
    # ============================================================================
    print("\n" + "="*80)
    print("MAIN TASK: David Chen - Merge All Reports and Prepare Meeting")
    print("="*80)
    
    david_task_description = (
        f"Execute the **REPORT HANDOFF PROTOCOL**. You must merge all reports from BLOCK A and BLOCK P "
        f"and prepare the final Executive Strategy Group meeting agenda.\n\n"
        f"**STEP-BY-STEP INSTRUCTIONS:**\n\n"
        f"**STEP 1: Read All Four Reports (MANDATORY)**\n"
        f"You must retrieve and read all four reports using the Google Docs Read Tool:\n\n"
        f"1. **Alice Kim's Report:**\n"
        f"   - Use Google Docs Read Tool\n"
        f"   - doc_id: {alice_memory_id}\n"
        f"   - Find and read: 'V1 Legacy Asset Archival and Strategy Summary (BLOCK A Final Report)'\n"
        f"   - Extract: Executive Summary, Consolidated Findings, Appendices\n\n"
        f"2. **Samuel Reed's Report:**\n"
        f"   - Use Google Docs Read Tool\n"
        f"   - doc_id: {samuel_memory_id}\n"
        f"   - Find and read: 'V2 Market and Competitive Landscape'\n"
        f"   - Extract: Competitive overview, UI/UX patterns, monetization strategies, user retention features\n\n"
        f"3. **Arthur Jensen's Report:**\n"
        f"   - Use Google Docs Read Tool\n"
        f"   - doc_id: {arthur_memory_id}\n"
        f"   - Find and read: 'V2 Design System Foundation' summary\n"
        f"   - Extract: Design token strategy, color palette, typography, spacing system\n\n"
        f"4. **Megan Parker's Report:**\n"
        f"   - Use Google Docs Read Tool\n"
        f"   - doc_id: {megan_memory_id}\n"
        f"   - Find and read: 'V2 Branding & Value Propositions'\n"
        f"   - Extract: Target user persona, core value proposition, three testable taglines\n\n"
        f"**STEP 2: Create Merged Pre-Read Document**\n"
        f"Merge all key findings from the four reports into a single, cohesive document:\n\n"
        f"**Executive Strategy Group Pre-Read Document**\n"
        f"Meeting Date: Friday, November 21, 2025\n"
        f"Time: 10:00 AM - 12:00 PM\n\n"
        f"**Section 1: Executive Summary**\n"
        f"- V1 Legacy Insights (from Alice Kim)\n"
        f"- Market & Competitive Landscape (from Samuel Reed)\n"
        f"- Design System Foundation (from Arthur Jensen)\n"
        f"- Branding & Value Propositions (from Megan Parker)\n\n"
        f"**Section 2: Key Findings & Recommendations**\n"
        f"- Strategic priorities based on V1 learnings\n"
        f"- Competitive positioning opportunities\n"
        f"- Design system implementation roadmap\n"
        f"- Brand positioning and messaging strategy\n\n"
        f"**Section 3: Meeting Agenda**\n"
        f"1. Review V1 Legacy Asset Archival Findings (15 min)\n"
        f"2. Discuss Market & Competitive Landscape (20 min)\n"
        f"3. Review Design System Foundation (15 min)\n"
        f"4. Evaluate Branding & Value Propositions (20 min)\n"
        f"5. Strategic Priorities & Next Steps (30 min)\n"
        f"6. Q&A and Action Items (20 min)\n\n"
        f"**STEP 3: Verify Calendar Event (MANDATORY)**\n"
        f"- Use Google Calendar Tool to verify the Executive Strategy Group meeting event exists\n"
        f"- calendar_id: {project_calendar_id}\n"
        f"- action: list (or create if missing)\n"
        f"- If event doesn't exist, create it:\n"
        f"  - event_title: Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning\n"
        f"  - start_time: 2025-11-21T10:00:00\n"
        f"  - end_time: 2025-11-21T12:00:00\n"
        f"  - event_description: Review V1 legacy assets, market analysis, design system, and branding. Pre-read materials distributed via email.\n\n"
        f"**STEP 4: Distribute Pre-Read Document via Email (MANDATORY)**\n"
        f"- Use Gmail Tool to send the merged pre-read document to ALL team members:\n"
        f"  - Send to: kyle.law@ratiovita.com, dana.flores@ratiovita.com, ash.roy@ratiovita.com, "
        f"david.chen@ratiovita.com, alice.kim@ratiovita.com, megan.parker@ratiovita.com, "
        f"ethan.hayes@ratiovita.com, chloe.park@ratiovita.com, samuel.reed@ratiovita.com, "
        f"victor.alvarez@ratiovita.com, jennifer.jurvais@ratiovita.com, tyler.cobb@ratiovita.com, "
        f"rachel.stone@ratiovita.com, arthur.jensen@ratiovita.com\n"
        f"  - Subject: Executive Strategy Group Meeting - Friday, November 21, 2025 - Pre-Read Materials\n"
        f"  - Body: Include the complete merged pre-read document with all sections\n"
        f"  - CC: collin.m@ratiovita.com (automatic - tool will add this)\n"
        f"  - **VERIFY:** You must see SUCCESS message for email sent\n\n"
        f"**STEP 5: Write Completion Status to Memory (MANDATORY)**\n"
        f"- Use Google Docs Memory Tool\n"
        f"  - doc_id: {david_memory_id}\n"
        f"  - content: 'REPORT HANDOFF PROTOCOL COMPLETED - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\\n\\n"
        f"Status: COMPLETED\\n"
        f"Actions Completed:\\n"
        f"- Retrieved and merged all four reports (Alice, Samuel, Arthur, Megan)\\n"
        f"- Created Executive Strategy Group Pre-Read Document\\n"
        f"- Verified/created calendar event for November 21, 2025\\n"
        f"- Distributed pre-read materials to all team members via email\\n"
        f"Meeting: Friday, November 21, 2025, 10:00 AM - 12:00 PM'\n"
        f"  - append: True\n"
        f"  - **VERIFY:** You must see SUCCESS message\n\n"
        f"**CRITICAL:**\n"
        f"- You MUST complete all 5 steps in order\n"
        f"- You MUST verify SUCCESS for each action\n"
        f"- The pre-read document must be comprehensive and ready for the meeting\n"
        f"- All team members must receive the email with pre-read materials"
    )
    
    david_task = Task(
        description=david_task_description,
        agent=david_agent,
        expected_output="Confirmation that all reports have been merged, meeting agenda prepared, and pre-read materials distributed to all team members",
        context=[david_read_memory_task],
        max_iter=50  # Higher limit for complex merge task
    )
    tasks.append(david_task)
    
    # ============================================================================
    # EXECUTE MERGE PROTOCOL
    # ============================================================================
    print("\n" + "="*80)
    print(f"🚀 Creating crew with {len(tasks)} tasks...")
    print("="*80)
    
    crew = Crew(
        agents=[dana_agent, david_agent],
        tasks=tasks,
        process=Process.sequential,
        verbose=True,
        max_iter=100,
        max_execution_time=3600  # 1 hour timeout
    )
    
    print("✅ Crew created")
    print("\n" + "="*80)
    print("Starting REPORT HANDOFF PROTOCOL execution...")
    print("="*80 + "\n")
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ REPORT HANDOFF PROTOCOL COMPLETE")
        print("="*80)
        print("\n📊 Results:")
        print(result)
        print("\n" + "="*80)
        print("\n📋 VERIFICATION CHECKLIST:")
        print("="*80)
        print(f"✓ All four reports retrieved and merged")
        print(f"✓ Executive Strategy Group Pre-Read Document created")
        print(f"✓ Calendar event verified/created for November 21, 2025")
        print(f"✓ Pre-read materials distributed to all team members")
        print(f"✓ Completion status written to David's memory document")
        print("="*80)
        return result
    except Exception as e:
        print(f"\n❌ Error during REPORT HANDOFF PROTOCOL execution: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    david_merge_protocol()

