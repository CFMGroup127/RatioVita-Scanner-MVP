"""
David Chen Updates Meeting to 11:00 PM EST
This script has David Chen update the existing meeting on the Project Schedule Calendar to 11:00 PM EST
and ensure all 15 agents are attendees.
"""
import os
from datetime import datetime
from crewai import Agent, Task, Crew, Process
from config import Config
from main import load_agents_from_yaml, get_agent_metadata

def david_update_meeting_11pm():
    """
    Have David Chen update the meeting to 11:00 PM EST on Project Schedule Calendar.
    """
    print("\n" + "="*80)
    print("📅 DAVID CHEN: UPDATING MEETING TO 11:00 PM EST")
    print("="*80)
    print("Meeting: Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning")
    print("Date: Monday, November 17, 2025")
    print("Time: 11:00 PM EST - 1:00 AM EST (November 18)")
    print("Calendar: RatioVitaAi Project Schedule")
    print("Reason: Power outage delay - current time is 10:13 PM EST")
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
    
    # Get David Chen (COO)
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
    
    # Get all agent emails
    try:
        from email_filter_helper import get_all_valid_agent_emails
        agent_emails = get_all_valid_agent_emails()
        print(f"✅ Using email filter - {len(agent_emails)} valid emails")
    except ImportError:
        agent_emails = []
        for agent in agents:
            agent_meta = get_agent_metadata(agent.role)
            email = agent_meta.get('email_address', '')
            if email:
                agent_emails.append(email)
        print(f"⚠️  Using fallback - {len(agent_emails)} emails")
    
    individual_email_list = ', '.join(agent_emails)
    print(f"📧 Agent email list: {len(agent_emails)} recipients")
    
    # Project Schedule Calendar ID
    project_calendar_id = "c_4e1c24ca3fdea15ff6de1ee2e0d025f75a1f8ff58ef58e2119e5273e51a5e7dc@group.calendar.google.com"
    
    task_description = f"""
**TASK: Update Executive Strategy Group Meeting to 11:00 PM EST on Project Schedule Calendar**

**CRITICAL:** The current time is 10:13 PM EST. The meeting must be updated to 11:00 PM EST today (November 17, 2025) 
on the Project Schedule Calendar. You MUST ensure all 15 agents are attendees and will receive calendar invitations.

**Meeting Details:**
- Title: "Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning"
- Date: Monday, November 17, 2025
- Start Time: 11:00 PM EST (23:00)
- End Time: 1:00 AM EST (01:00) - November 18, 2025
- Duration: 2 hours
- Time Zone: Eastern Standard Time (EST) - MANDATORY
- Calendar: RatioVitaAi Project Schedule Calendar (MANDATORY)
- Calendar ID: {project_calendar_id}
- Description: "Executive Strategy Group meeting to review V1 legacy assets, market analysis, design system, branding, and V2 technical baseline. RESCHEDULED to 11:00 PM EST due to power outage. All times are in Eastern Standard Time (EST)."

**ACTION REQUIRED:**
1. **Find Existing Event:** First, use the Google Calendar Tool with action='list' to find the existing meeting event on the Project Schedule Calendar.

2. **Update Event:** Since the Google Calendar Tool may not support direct updates, you have two options:
   - **Option A (Preferred):** Delete the existing event and create a new one at 11:00 PM EST with all attendees
   - **Option B:** If the tool supports updates, update the existing event's start_time and end_time

3. **Create/Update Event with All Attendees:**
   - Use the Google Calendar Tool to create/update the event with:
     - calendar_id: '{project_calendar_id}' (MANDATORY - Project Schedule Calendar)
     - action: 'create' (or 'update' if supported)
     - event_title: "Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning"
     - start_time: "2025-11-17T23:00:00" (11:00 PM EST)
     - end_time: "2025-11-18T01:00:00" (1:00 AM EST - next day)
     - event_description: "Executive Strategy Group meeting to review V1 legacy assets, market analysis, design system, branding, and V2 technical baseline. RESCHEDULED to 11:00 PM EST due to power outage. All times are in Eastern Standard Time (EST)."
     - location: "Virtual Meeting" (required parameter)
   
   **IMPORTANT:** The Google Calendar Tool automatically adds all 15 agents as attendees when creating events on the Project Schedule Calendar. This will trigger email invitations to all attendees automatically.

4. **Send Email Notification:**
   After successfully updating the calendar event, use the **GMailTool** to send a meeting update notification to ALL 15 team members:
   - Recipients: {individual_email_list}
   - **STRICT EMAIL PROTOCOL:** Use ONLY individual email addresses listed above. Group aliases are FORBIDDEN.
   - CC: collin.m@ratiovita.com (MANDATORY)
   - Subject: "Meeting Updated: Executive Strategy Group Meeting - NOW 11:00 PM EST"
   - Body: "The Executive Strategy Group Meeting has been updated to TODAY, Monday, November 17, 2025, from 11:00 PM EST to 1:00 AM EST (midnight). The meeting is on the RatioVitaAi Project Schedule Calendar. All agents have been added as attendees and should receive calendar invitations. Please accept the calendar invitation and log 'MEETING ACCEPTED: Executive Strategy Group Meeting - November 17, 2025, 11:00 PM EST' in your memory document per P8 protocol. Per P9 protocol, all times are in Eastern Standard Time (EST)."

5. **Update Memory Document:**
   Update your memory document with:
   - "Meeting Updated: Executive Strategy Group Meeting - November 17, 2025, 11:00 PM EST - 1:00 AM EST"
   - "Reason: Power outage delay - rescheduled from 10:00 PM EST"
   - "All 15 agents added as attendees on Project Schedule Calendar"
   - "Calendar invitations sent automatically via Google Calendar"
   - "Email notification sent to all team members"
   - Timestamp (in EST per P9 protocol)

**VERIFY:** You must see SUCCESS messages for:
1. Calendar event updated/created on project schedule calendar for 11:00 PM EST
2. All 15 agents added as attendees (automatic via calendar tool)
3. Email notification sent to all 15 agents (individual addresses only)
4. Memory document updated with EST timestamps
"""
    
    task = Task(
        description=task_description,
        agent=david_agent,
        expected_output="Calendar event updated to 11:00 PM EST on project schedule calendar, all 15 agents added as attendees with invitations sent, email notification sent to all team members, memory updated with confirmation (all times in EST)."
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
    print("Starting meeting update to 11:00 PM EST...")
    print("="*80)
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ MEETING UPDATE TO 11:00 PM EST COMPLETE")
        print("="*80)
        print(f"\n📊 Results:\n{result}")
        return result
    except Exception as e:
        print(f"\n❌ Error during execution: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    david_update_meeting_11pm()


