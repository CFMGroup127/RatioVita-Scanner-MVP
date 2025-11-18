"""
Reschedule Executive Strategy Group Meeting to 4:00 PM Today
This script creates/updates the meeting for November 17, 2025 at 4:00 PM on the Project Schedule Calendar.
"""
import os
from datetime import datetime
from crewai import Agent, Task, Crew, Process
from config import Config
from main import load_agents_from_yaml, get_agent_metadata

def reschedule_meeting_400pm():
    """
    Reschedule Executive Strategy Group Meeting to 4:00 PM today (November 17, 2025) on Project Schedule Calendar.
    """
    print("\n" + "="*80)
    print("📅 RESCHEDULING MEETING TO 4:00 PM TODAY")
    print("="*80)
    print("Meeting: Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning")
    print("Date: Monday, November 17, 2025")
    print("Time: 4:00 PM - 6:00 PM")
    print("Calendar: RatioVitaAi Project Schedule")
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
    
    for agent in agents:
        if agent.role == dana_role:
            dana_agent = agent
            break
    
    if not dana_agent:
        print(f"❌ Error: Could not find agent with role '{dana_role}'")
        return None
    
    print(f"\n✅ Agent loaded: {dana_agent.role}")
    
    # Get all agent emails - INDIVIDUAL ADDRESSES ONLY (NO GROUP ALIASES)
    agent_emails = []
    for agent in agents:
        agent_meta = get_agent_metadata(agent.role)
        email = agent_meta.get('email_address', '')
        if email:
            agent_emails.append(email)
    
    # Verify we have all 15 individual emails
    if len(agent_emails) != 15:
        print(f"⚠️  Warning: Expected 15 agent emails, found {len(agent_emails)}")
    
    # Create explicit comma-separated list of all individual emails
    individual_email_list = ', '.join(agent_emails)
    
    print(f"📧 Agent email list: {len(agent_emails)} individual recipients")
    print(f"✅ Individual emails: {individual_email_list[:80]}...")
    
    # Project Schedule Calendar ID
    project_calendar_id = "c_4e1c24ca3fdea15ff6de1ee2e0d025f75a1f8ff58ef58e2119e5273e51a5e7dc@group.calendar.google.com"
    
    # Meeting details
    meeting_date = "2025-11-17"
    start_time = "16:00:00"  # 4:00 PM
    end_time = "18:00:00"    # 6:00 PM
    
    task_description = f"""
**TASK: Reschedule Executive Strategy Group Meeting to 4:00 PM Today on Project Schedule Calendar**

You MUST use the **Google Calendar Tool** to create or update the Executive Strategy Group Meeting on the OFFICIAL Project Schedule Calendar.

**Meeting Details:**
- Title: "Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning"
- Date: Monday, November 17, 2025
- Start Time: 4:00 PM (16:00)
- End Time: 6:00 PM (18:00)
- Duration: 2 hours
- Calendar: RatioVitaAi Project Schedule Calendar (MANDATORY - NOT primary calendar)
- Calendar ID: {project_calendar_id}
- Description: "Executive Strategy Group meeting to review V1 legacy assets, market analysis, design system, branding, and V2 technical baseline. Includes pre-read materials from Alice Kim, Samuel Reed, Arthur Jensen, Megan Parker, and Ash Roy."

**Calendar Tool Parameters:**
- calendar_id: '{project_calendar_id}' (MANDATORY - use this exact ID, NOT 'primary')
- action: 'create' (or 'update' if event exists)
- event_title: "Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning"
- start_time: "2025-11-17T16:00:00"
- end_time: "2025-11-17T18:00:00"
- event_description: "Executive Strategy Group meeting to review V1 legacy assets, market analysis, design system, branding, and V2 technical baseline."

**CRITICAL:** You MUST use the project schedule calendar ID, NOT the primary calendar. You MUST see a SUCCESS message confirming the calendar event was created/updated on the project schedule calendar.

**After Calendar Creation:**
Once the calendar event is successfully created on the project schedule calendar, you MUST:
1. Use the **GMailTool** to send meeting invitations to ALL 15 team members using INDIVIDUAL EMAIL ADDRESSES ONLY:
   - Recipients: {individual_email_list}
   - **CRITICAL:** You MUST use these exact 15 individual email addresses. The use of any group alias (e.g., 'all.15.team.members@ratiovita.com') is **STRICTLY FORBIDDEN** and will cause email delivery failures.
   - CC: collin.m@ratiovita.com (MANDATORY)
   - Subject: "Meeting Invitation: Executive Strategy Group Meeting - TODAY 4:00 PM EST"
   - Body: "You are invited to the Executive Strategy Group Meeting scheduled for TODAY, Monday, November 17, 2025, from 4:00 PM EST to 6:00 PM EST. The meeting will be held on the RatioVitaAi Project Schedule Calendar. All pre-read materials remain valid. Please acknowledge receipt of this invitation per P8 protocol by logging 'MEETING ACCEPTED: Executive Strategy Group Meeting - November 17, 2025, 4:00 PM EST' in your memory document. Per P9 protocol, all times are in Eastern Standard Time (EST)."
   
   **MANDATORY:** 
   - This email invitation enforces the P8 Meeting Acceptance Acknowledgment protocol. All 15 agents must receive this invitation.
   - You MUST use the individual email addresses listed above. NEVER use group aliases or distribution lists.
   
2. Update your memory document with:
   - "Meeting Rescheduled: Executive Strategy Group Meeting - November 17, 2025, 4:00 PM - 6:00 PM"
   - "Meeting created on RatioVitaAi Project Schedule Calendar"
   - "Invitations sent to all 15 team members"
   - Timestamp

**VERIFY:** You must see SUCCESS messages for:
1. Calendar event creation on project schedule calendar
2. Email invitations sent to all 15 agents
3. Memory document updated
"""
    
    task = Task(
        description=task_description,
        agent=dana_agent,
        expected_output="Calendar event created/updated on project schedule calendar for 4:00 PM today, meeting invitations sent to all 15 team members, memory updated with confirmation."
    )
    
    # Create crew
    print("\n" + "="*80)
    print("🚀 Creating crew...")
    print("="*80)
    
    crew = Crew(
        agents=[dana_agent],
        tasks=[task],
        process=Process.sequential,
        verbose=True
    )
    
    print("✅ Crew created")
    
    # Execute
    print("\n" + "="*80)
    print("Starting meeting reschedule to 4:00 PM...")
    print("="*80)
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ MEETING RESCHEDULE TO 4:00 PM COMPLETE")
        print("="*80)
        print(f"\n📊 Results:\n{result}")
        return result
    except Exception as e:
        print(f"\n❌ Error during execution: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    reschedule_meeting_400pm()

