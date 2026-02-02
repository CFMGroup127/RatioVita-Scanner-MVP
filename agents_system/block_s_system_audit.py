"""
BLOCK S: System Audit & Control Refinement
High-priority security and workflow mandate executed by Dana Flores.

This block enforces:
1. System-wide audit and report resubmission
2. Meeting reschedule to today
3. Establishment of three mandatory protocols for all agents
"""
import os
from datetime import datetime
from crewai import Agent, Task, Crew, Process
from config import Config
from main import load_agents_from_yaml, get_agent_metadata

def block_s_system_audit():
    """
    Execute BLOCK S: System Audit & Control Refinement
    Assigned to Dana Flores (Admin Assistant) for immediate execution.
    """
    print("\n" + "="*80)
    print("🛑 BLOCK S: SYSTEM AUDIT & CONTROL REFINEMENT")
    print("="*80)
    print("High-priority security and workflow mandate")
    print("Executing: System-wide audit, report resubmission, and protocol enforcement")
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
    
    # Get Dana Flores
    dana_role = "Admin Assistant & Workflow Funnel"
    dana_agent = None
    dana_metadata = None
    
    for agent in agents:
        if agent.role == dana_role:
            dana_agent = agent
            dana_metadata = get_agent_metadata(dana_role)
            break
    
    if not dana_agent:
        print(f"❌ Error: Could not find agent with role '{dana_role}'")
        return None
    
    print(f"\n✅ Agent loaded: {dana_agent.role}")
    print(f"   Memory Doc ID: {dana_metadata.get('memory_doc_id', 'N/A')}")
    
    # Get agent email addresses for broadcast - INDIVIDUAL ADDRESSES ONLY (NO GROUP ALIASES)
    # Use email filter to exclude invalid emails (e.g., victor.alvarez@ratiovita.com)
    try:
        from email_filter_helper import get_all_valid_agent_emails
        all_valid_emails = get_all_valid_agent_emails()
        # Exclude Dana from the list
        agent_emails = [email for email in all_valid_emails if email != dana_metadata.get('email_address', '')]
        print(f"✅ Using email filter - {len(agent_emails)} valid emails (excluding Dana)")
    except ImportError:
        # Fallback: manually filter invalid emails
        agent_emails = []
        INVALID_EMAILS = ['victor.alvarez@ratiovita.com']  # Add other invalid emails here
        for agent in agents:
            agent_meta = get_agent_metadata(agent.role)
            email = agent_meta.get('email_address', '')
            if email and email != dana_metadata.get('email_address', '') and email.lower() not in [e.lower() for e in INVALID_EMAILS]:
                agent_emails.append(email)
        print(f"⚠️  Using fallback filter - {len(agent_emails)} valid emails (excluded invalid)")
    
    # Create explicit comma-separated list of all individual emails
    individual_email_list = ', '.join(agent_emails)
    
    # Verify we have the expected number of emails (14, excluding Dana)
    if len(agent_emails) != 14:
        print(f"⚠️  Warning: Expected 14 agent emails (excluding Dana), found {len(agent_emails)}")
    
    print(f"\n📧 Agent email list prepared: {len(agent_emails)} individual recipients")
    print(f"✅ Individual emails: {individual_email_list[:100]}...")
    
    # Get specific agent memory doc IDs
    alice_metadata = get_agent_metadata("Documentation and Knowledge Archivist")
    samuel_metadata = get_agent_metadata("Competitive Intelligence Specialist")
    megan_metadata = get_agent_metadata("Market Strategist and Voice of the Customer")
    arthur_metadata = get_agent_metadata("Legal Compliance and Risk Assessor")
    ash_metadata = get_agent_metadata("Technical and Product Visionary")
    david_metadata = get_agent_metadata("Process Architect and Schedule Publisher")
    
    alice_doc_id = alice_metadata.get('memory_doc_id', '')
    samuel_doc_id = samuel_metadata.get('memory_doc_id', '')
    megan_doc_id = megan_metadata.get('memory_doc_id', '')
    arthur_doc_id = arthur_metadata.get('memory_doc_id', '')
    ash_doc_id = ash_metadata.get('memory_doc_id', '')
    david_email = david_metadata.get('email_address', 'david.chen@ratiovita.com')
    
    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    current_date = datetime.now().strftime("%Y-%m-%d")
    
    print("\n" + "="*80)
    print("TASK: Dana Flores - System-Wide Audit and Meeting Reschedule")
    print("="*80)
    
    # PHASE 1: IMMEDIATE AUDIT & REPORT RESUBMISSION
    phase1_task_description = f"""
**PHASE 1: IMMEDIATE AUDIT & REPORT RESUBMISSION**

**STEP 1: MANDATORY MEMORY REVIEW & LOG**
You MUST first use the **Google Docs Read Tool** to read your own memory document (doc_id: {dana_metadata.get('memory_doc_id', '')}).
Then, you MUST immediately use the **Google Docs Memory Tool** to log this assigned audit task with:
- Current time and date: {current_time}
- Task name: "BLOCK S: System Audit & Control Refinement"
- Assignment source: Direct system mandate
- Status: IN PROGRESS

**STEP 2: AUDIT BROADCAST EMAIL**
You MUST use the **GMailTool** to send an immediate, high-priority email to ALL 14 other agents using INDIVIDUAL EMAIL ADDRESSES ONLY:
- Recipients: {individual_email_list}
- **CRITICAL:** You MUST use these exact 14 individual email addresses. The use of any group alias (e.g., 'all.15.team.members@ratiovita.com') is **STRICTLY FORBIDDEN** and will cause email delivery failures.
- CC: collin.m@ratiovita.com (MANDATORY)
- Subject: "URGENT: System Audit - Report Resubmission Required"
- Body must include:
  "Due to internal communication transfer breakdowns, a full verification and resubmission of all completed reports is required immediately. This is a high-priority security and workflow mandate."
  
**STEP 3: RESUBMISSION MANDATE EMAIL**
You MUST send a second, detailed email to the four specific agents (Alice Kim, Samuel Reed, Megan Parker, Arthur Jensen):
- Recipients: 
  - alice.kim@ratiovita.com
  - samuel.reed@ratiovita.com
  - megan.parker@ratiovita.com
  - arthur.jensen@ratiovita.com
- CC: collin.m@ratiovita.com (MANDATORY)
- Subject: "MANDATORY: Report Verification and Resubmission"
- Body must instruct them to:
  1. Immediately read their own memory documents using Google Docs Read Tool
  2. Verify their findings are complete and accurate
  3. Resubmit their final, full reports to their respective memory documents
  4. Add a clear, time-stamped 'VERIFIED' tag at the end of each report
  5. Format: "VERIFIED: [Agent Name] - [Current Date/Time]"
  
**STEP 4: ENGINEERING STATUS EMAIL**
You MUST send a third email to Ash Roy:
- Recipient: ash.roy@ratiovita.com
- CC: collin.m@ratiovita.com (MANDATORY)
- Subject: "URGENT: V1 Quarantine and V2 Baseline Confirmation Required"
- Body must instruct Ash Roy to:
  1. Immediately confirm V1 Quarantine is completed and checkpointed in his memory document
  2. Immediately confirm V2 Baseline Analysis is completed and checkpointed in his memory document
  3. Verify both statuses are clearly documented with timestamps in his memory document

**CRITICAL:** You MUST see SUCCESS messages for all three emails before proceeding to Phase 2.
"""
    
    # PHASE 2: PROJECT CONTROL REFINEMENT
    phase2_task_description = f"""
**PHASE 2: PROJECT CONTROL REFINEMENT (New Mandatory Protocols)**

**STEP 1: TASK FUNNEL ENFORCEMENT**
You MUST use the **Google Docs Memory Tool** to log a new protocol in your memory document stating:
"EFFECTIVE IMMEDIATELY: ALL future project prompts and assignments will be routed ONLY through Dana Flores (Admin Assistant). Direct assignment to other agents is FORBIDDEN. This is a mandatory workflow control protocol."

**STEP 2: RESCHEDULING PROPOSAL**
Once you have received and confirmed the resubmission of all four required reports (Alice, Samuel, Megan, Arthur) and the status from Ash, you MUST:
1. Read all four memory documents to verify resubmissions:
   - Alice Kim: {alice_doc_id}
   - Samuel Reed: {samuel_doc_id}
   - Megan Parker: {megan_doc_id}
   - Arthur Jensen: {arthur_doc_id}
2. Read Ash Roy's memory document to verify status: {ash_doc_id}
3. Once all verifications are complete, send an email proposal to David Chen (COO):
   - Recipient: {david_email}
   - CC: collin.m@ratiovita.com (MANDATORY)
   - Subject: "Proposal: Reschedule Executive Strategy Group Meeting to Today"
   - Body must state:
     "All preparatory work has been confirmed and verified. I propose rescheduling the Executive Strategy Group meeting from November 21, 2025 to TODAY ({current_date}) at the earliest confirmed time (12 PM, 1 PM, or 2 PM TBD based on when the last final confirmation and report is received). Please confirm your availability and preferred time."

**STEP 3: CALENDAR UPDATE**
Upon receiving approval from David Chen (you may need to check for a reply or proceed after a reasonable time), you MUST:
1. Use the **Google Calendar Tool** to:
   - Find the existing "Executive Strategy Group Meeting" event on November 21, 2025
   - Update the event to TODAY ({current_date}) at the confirmed time (12 PM, 1 PM, or 2 PM)
   - Update the event title if needed: "Executive Strategy Group Meeting - V1 Legacy Review & V2 Strategy"
2. Send a notification email to all 15 team members using INDIVIDUAL EMAIL ADDRESSES ONLY:
   - Recipients: {individual_email_list}, {dana_metadata.get('email_address', 'dana.flores@ratiovita.com')}
   - **CRITICAL:** You MUST use individual email addresses. The use of any group alias (e.g., 'all.15.team.members@ratiovita.com') is **STRICTLY FORBIDDEN** and will cause email delivery failures.
   - CC: collin.m@ratiovita.com (MANDATORY)
   - Subject: "Meeting Rescheduled: Executive Strategy Group Meeting - TODAY"
   - Body: "The Executive Strategy Group meeting has been rescheduled to TODAY ({current_date}) at [CONFIRMED TIME]. All pre-read materials remain valid. Please confirm attendance."

**STEP 4: FINAL SIGN-OFF**
After completing all steps, you MUST write to your memory document:
"BLOCK S: System Audit & Control Refinement - COMPLETED
TASK COMPLETE: System-Wide Audit and Meeting Reschedule - VERIFIED BY AGENT Dana Flores - {current_time}"
"""
    
    # Create tasks
    tasks = [
        Task(
            description=phase1_task_description,
            agent=dana_agent,
            expected_output="Phase 1 complete: Memory logged, audit broadcast sent, resubmission mandate sent, engineering status email sent. All SUCCESS messages confirmed."
        ),
        Task(
            description=phase2_task_description,
            agent=dana_agent,
            expected_output="Phase 2 complete: Task funnel protocol logged, rescheduling proposal sent to David Chen, calendar event updated, notification sent, final sign-off written to memory."
        )
    ]
    
    # Create crew
    print("\n" + "="*80)
    print("🚀 Creating crew with 2 sequential tasks...")
    print("="*80)
    
    crew = Crew(
        agents=[dana_agent],
        tasks=tasks,
        process=Process.sequential,
        verbose=True
    )
    
    print("✅ Crew created")
    
    # Execute
    print("\n" + "="*80)
    print("Starting BLOCK S execution...")
    print("="*80)
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ BLOCK S: SYSTEM AUDIT & CONTROL REFINEMENT COMPLETE")
        print("="*80)
        print(f"\n📊 Results:\n{result}")
        return result
    except Exception as e:
        print(f"\n❌ Error during execution: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    block_s_system_audit()

