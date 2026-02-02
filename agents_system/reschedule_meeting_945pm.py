"""
Reschedule Executive Strategy Group Meeting to 9:45 PM EST Today
This script creates/updates the meeting for November 17, 2025 at 9:45 PM EST on the Project Schedule Calendar.
"""
import os
from datetime import datetime
from crewai import Agent, Task, Crew, Process
from config import Config
from main import load_agents_from_yaml, get_agent_metadata

def reschedule_meeting_945pm():
    """
    Reschedule Executive Strategy Group Meeting to 9:45 PM EST today (November 17, 2025) on Project Schedule Calendar.
    """
    print("\n" + "="*80)
    print("📅 RESCHEDULING MEETING TO 9:45 PM EST TODAY")
    print("="*80)
    print("Meeting: Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning")
    print("Date: Monday, November 17, 2025")
    print("Time: 9:45 PM EST - 11:45 PM EST")
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
    # Use email filter to exclude invalid emails
    try:
        from email_filter_helper import get_all_valid_agent_emails
        agent_emails = get_all_valid_agent_emails()
        print(f"✅ Using email filter - {len(agent_emails)} valid emails")
    except ImportError:
        # Fallback: manually filter invalid emails
        agent_emails = []
        INVALID_EMAILS = []  # victor.alvarez@ratiovita.com removed - tested and working
        for agent in agents:
            agent_meta = get_agent_metadata(agent.role)
            email = agent_meta.get('email_address', '')
            if email and email.lower() not in [e.lower() for e in INVALID_EMAILS]:
                agent_emails.append(email)
        print(f"⚠️  Using fallback filter - {len(agent_emails)} valid emails (excluded invalid)")
    
    # Create explicit comma-separated list of all individual emails
    individual_email_list = ', '.join(agent_emails)
    
    print(f"📧 Agent email list: {len(agent_emails)} recipients (individual addresses only)")
    
    # Project Schedule Calendar ID
    project_calendar_id = "c_4e1c24ca3fdea15ff6de1ee2e0d025f75a1f8ff58ef58e2119e5273e51a5e7dc@group.calendar.google.com"
    
    # Meeting details - 9:45 PM EST
    meeting_date = "2025-11-17"
    start_time = "21:45:00"  # 9:45 PM EST
    end_time = "23:45:00"    # 11:45 PM EST
    
    task_description = f"""
**TASK: Reschedule Executive Strategy Group Meeting to 9:45 PM EST Today on Project Schedule Calendar**

You MUST use the **Google Calendar Tool** to create or update the Executive Strategy Group Meeting on the OFFICIAL Project Schedule Calendar.

**Meeting Details:**
- Title: "Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning"
- Date: Monday, November 17, 2025
- Start Time: 9:45 PM EST (21:45)
- End Time: 11:45 PM EST (23:45)
- Duration: 2 hours
- Time Zone: Eastern Standard Time (EST) - MANDATORY
- Calendar: RatioVitaAi Project Schedule Calendar (MANDATORY - NOT primary calendar)
- Calendar ID: {project_calendar_id}
- Description: "Executive Strategy Group meeting to review V1 legacy assets, market analysis, design system, branding, and V2 technical baseline. Includes pre-read materials from Alice Kim, Samuel Reed, Arthur Jensen, Megan Parker, and Ash Roy. All times are in Eastern Standard Time (EST)."

**Calendar Tool Parameters:**
- calendar_id: '{project_calendar_id}' (MANDATORY - use this exact ID, NOT 'primary')
- action: 'create' (or 'update' if event exists)
- event_title: "Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning"
- start_time: "2025-11-17T21:45:00" (9:45 PM EST)
- end_time: "2025-11-17T23:45:00" (11:45 PM EST)
- event_description: "Executive Strategy Group meeting to review V1 legacy assets, market analysis, design system, branding, and V2 technical baseline. All times are in Eastern Standard Time (EST)."
- location: "Virtual Meeting" (required parameter)

**CRITICAL:** 
- You MUST use the project schedule calendar ID, NOT the primary calendar.
- All times must be specified in EST (Eastern Standard Time).
- You MUST see a SUCCESS message confirming the calendar event was created/updated on the project schedule calendar.

**After Calendar Creation:**
Once the calendar event is successfully created on the project schedule calendar, you MUST:
1. Use the **GMailTool** to send meeting invitations to ALL 15 team members:
   - Recipients: {individual_email_list}
   - **STRICT EMAIL PROTOCOL:** Use ONLY individual email addresses listed above. Group aliases are FORBIDDEN.
   - CC: collin.m@ratiovita.com (MANDATORY)
   - Subject: "Meeting Invitation: Executive Strategy Group Meeting - TODAY 9:45 PM EST"
   - Body: "You are invited to the Executive Strategy Group Meeting scheduled for TODAY, Monday, November 17, 2025, from 9:45 PM EST to 11:45 PM EST. The meeting will be held on the RatioVitaAi Project Schedule Calendar. All pre-read materials remain valid. Please acknowledge receipt of this invitation per P8 protocol by logging 'MEETING ACCEPTED: Executive Strategy Group Meeting - November 17, 2025, 9:45 PM EST' in your memory document. Per P9 protocol, all times are in Eastern Standard Time (EST)."
   
   **MANDATORY:** This email invitation enforces the P8 Meeting Acceptance Acknowledgment protocol. All 15 agents must receive this invitation via individual email addresses only.
   
2. Update your memory document with:
   - "Meeting Rescheduled: Executive Strategy Group Meeting - November 17, 2025, 9:45 PM EST - 11:45 PM EST"
   - "Meeting created on RatioVitaAi Project Schedule Calendar"
   - "Time Zone: Eastern Standard Time (EST)"
   - "Invitations sent to all 15 team members (individual addresses only)"
   - Timestamp (in EST per P9 protocol)

**VERIFY:** You must see SUCCESS messages for:
1. Calendar event creation on project schedule calendar
2. Email invitations sent to all 15 agents (individual addresses only)
3. Memory document updated with EST timestamps
"""
    
    task = Task(
        description=task_description,
        agent=dana_agent,
        expected_output="Calendar event created/updated on project schedule calendar for 9:45 PM EST today, meeting invitations sent to all 15 team members, memory updated with confirmation (all times in EST)."
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
    print("Starting meeting reschedule to 9:45 PM EST...")
    print("="*80)
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ MEETING RESCHEDULE TO 9:45 PM EST COMPLETE")
        print("="*80)
        print(f"\n📊 Results:\n{result}")
        return result
    except Exception as e:
        print(f"\n❌ Error during execution: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    reschedule_meeting_945pm()


