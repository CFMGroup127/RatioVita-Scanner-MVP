"""
David Chen Reschedules Executive Strategy Group Meeting to 5:00 PM EST
This script has David Chen update the meeting on the Project Schedule Calendar and send invitations.
"""
import os
from datetime import datetime
from crewai import Agent, Task, Crew, Process
from config import Config
from main import load_agents_from_yaml, get_agent_metadata

def david_reschedule_500pm():
    """
    Have David Chen reschedule the Executive Strategy Group Meeting to 5:00 PM EST on Project Schedule Calendar.
    """
    print("\n" + "="*80)
    print("📅 DAVID CHEN: RESCHEDULING MEETING TO 5:00 PM EST")
    print("="*80)
    print("Meeting: Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning")
    print("Date: Monday, November 17, 2025")
    print("Time: 5:00 PM EST - 7:00 PM EST")
    print("Calendar: RatioVitaAi Project Schedule")
    print("Agent: David Chen (COO)")
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
    
    # Get David Chen
    david_role = "Process Architect and Schedule Publisher"
    david_agent = None
    
    for agent in agents:
        if agent.role == david_role:
            david_agent = agent
            break
    
    if not david_agent:
        print(f"❌ Error: Could not find agent with role '{david_role}'")
        return None
    
    print(f"\n✅ Agent loaded: {david_agent.role}")
    
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
    
    # Meeting details - 5:00 PM EST
    meeting_date = "2025-11-17"
    start_time = "17:00:00"  # 5:00 PM EST
    end_time = "19:00:00"    # 7:00 PM EST
    
    task_description = f"""
**TASK: Reschedule Executive Strategy Group Meeting to 5:00 PM EST on Project Schedule Calendar**

As the COO and Schedule Publisher, you are responsible for updating the official project schedule. You MUST complete this task in TWO MANDATORY STEPS.

**STEP 1: UPDATE CALENDAR EVENT**
You MUST use the **Google Calendar Tool** to update the Executive Strategy Group Meeting on the OFFICIAL Project Schedule Calendar.

**Meeting Details:**
- Title: "Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning"
- Date: Monday, November 17, 2025
- Start Time: 5:00 PM EST (17:00)
- End Time: 7:00 PM EST (19:00)
- Duration: 2 hours
- Time Zone: Eastern Standard Time (EST) - MANDATORY
- Calendar: RatioVitaAi Project Schedule Calendar (MANDATORY - NOT primary calendar)
- Calendar ID: {project_calendar_id}
- Description: "Executive Strategy Group meeting to review V1 legacy assets, market analysis, design system, branding, and V2 technical baseline. Includes pre-read materials from Alice Kim, Samuel Reed, Arthur Jensen, Megan Parker, and Ash Roy. All times are in Eastern Standard Time (EST)."

**Calendar Tool Parameters:**
- calendar_id: '{project_calendar_id}' (MANDATORY - use this exact ID, NOT 'primary')
- action: 'create' (or 'update' if event exists - try 'update' first if the meeting already exists)
- event_title: "Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning"
- start_time: "2025-11-17T17:00:00" (5:00 PM EST)
- end_time: "2025-11-17T19:00:00" (7:00 PM EST)
- event_description: "Executive Strategy Group meeting to review V1 legacy assets, market analysis, design system, branding, and V2 technical baseline. All times are in Eastern Standard Time (EST)."

**CRITICAL:** 
- You MUST use the project schedule calendar ID, NOT the primary calendar.
- All times must be specified in EST (Eastern Standard Time).
- You MUST see a SUCCESS message confirming the calendar event was created/updated on the project schedule calendar.

**STEP 2: SEND EMAIL INVITATIONS (MANDATORY)**
IMMEDIATELY after successfully updating the calendar event, you MUST use the **GMailTool** to send meeting invitations to ALL 15 team members using INDIVIDUAL EMAIL ADDRESSES ONLY:

- Recipients: {individual_email_list}
- **CRITICAL:** You MUST use these exact 15 individual email addresses. The use of any group alias (e.g., 'all.15.team.members@ratiovita.com') is **STRICTLY FORBIDDEN** and will cause email delivery failures.
- CC: collin.m@ratiovita.com (MANDATORY)
- Subject: "Meeting Rescheduled: Executive Strategy Group Meeting - TODAY 5:00 PM EST"
- Body: "The Executive Strategy Group Meeting has been rescheduled to TODAY, Monday, November 17, 2025, from 5:00 PM EST to 7:00 PM EST. The meeting will be held on the RatioVitaAi Project Schedule Calendar. All pre-read materials remain valid. Please acknowledge receipt of this invitation per P8 protocol by logging 'MEETING ACCEPTED: Executive Strategy Group Meeting - November 17, 2025, 5:00 PM EST' in your memory document. Per P9 protocol, all times are in Eastern Standard Time (EST)."

**MANDATORY PROTOCOL:** 
- This is a TWO-STEP process: Calendar update THEN email invitations.
- Calendar event creation/updates MUST trigger email invitations per your MANDATORY CALENDAR INVITATION PROTOCOL.
- All 15 agents must receive this invitation to acknowledge per P8 protocol.
- You MUST use the individual email addresses listed above. NEVER use group aliases or distribution lists.

**STEP 3: UPDATE MEMORY**
After completing both steps, update your memory document with:
- "Meeting Rescheduled: Executive Strategy Group Meeting - November 17, 2025, 5:00 PM EST - 7:00 PM EST"
- "Meeting updated on RatioVitaAi Project Schedule Calendar"
- "Time Zone: Eastern Standard Time (EST)"
- "Email invitations sent to all 15 team members using individual email addresses"
- Timestamp (in EST per P9 protocol)

**VERIFY:** You must see SUCCESS messages for:
1. Calendar event update on project schedule calendar
2. Email invitations sent to all 15 agents
3. Memory document updated with EST timestamps
"""
    
    task = Task(
        description=task_description,
        agent=david_agent,
        expected_output="Calendar event updated on project schedule calendar for 5:00 PM EST, email invitations sent to all 15 team members using individual email addresses, memory updated with confirmation (all times in EST)."
    )
    
    # Create crew
    print("\n" + "="*80)
    print("🚀 Creating crew...")
    print("="*80)
    
    crew = Crew(
        agents=[david_agent],
        tasks=[task],
        process=Process.sequential,
        verbose=True
    )
    
    print("✅ Crew created")
    
    # Execute
    print("\n" + "="*80)
    print("Starting meeting reschedule to 5:00 PM EST by David Chen...")
    print("="*80)
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ MEETING RESCHEDULE TO 5:00 PM EST COMPLETE")
        print("="*80)
        print(f"\n📊 Results:\n{result}")
        return result
    except Exception as e:
        print(f"\n❌ Error during execution: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    david_reschedule_500pm()


