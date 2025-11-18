"""
Reschedule Executive Strategy Group Meeting to 3:30 PM Today
This script creates/updates the meeting for November 17, 2025 at 3:30 PM.
"""
import os
from datetime import datetime, timedelta
from crewai import Agent, Task, Crew, Process
from config import Config
from main import load_agents_from_yaml, get_agent_metadata

def reschedule_meeting_330pm():
    """
    Reschedule Executive Strategy Group Meeting to 3:30 PM today (November 17, 2025).
    """
    print("\n" + "="*80)
    print("📅 RESCHEDULING MEETING TO 3:30 PM TODAY")
    print("="*80)
    print("Meeting: Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning")
    print("Date: Monday, November 17, 2025")
    print("Time: 3:30 PM - 5:30 PM")
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
    
    # Get all agent emails
    agent_emails = []
    for agent in agents:
        agent_meta = get_agent_metadata(agent.role)
        email = agent_meta.get('email_address', '')
        if email:
            agent_emails.append(email)
    
    print(f"📧 Agent email list: {len(agent_emails)} recipients")
    
    # Meeting details
    meeting_date = "2025-11-17"
    start_time = "15:30:00"  # 3:30 PM
    end_time = "17:30:00"    # 5:30 PM
    
    task_description = f"""
**TASK: Reschedule Executive Strategy Group Meeting to 3:30 PM Today**

You MUST use the **Google Calendar Tool** to create or update the Executive Strategy Group Meeting:

**Meeting Details:**
- Title: "Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning"
- Date: Monday, November 17, 2025
- Start Time: 3:30 PM (15:30)
- End Time: 5:30 PM (17:30)
- Duration: 2 hours
- Calendar: Use 'primary' calendar (or project_schedule_calendar_id if available)
- Description: "Executive Strategy Group meeting to review V1 legacy assets, market analysis, design system, branding, and V2 technical baseline. Includes pre-read materials from Alice Kim, Samuel Reed, Arthur Jensen, Megan Parker, and Ash Roy."

**Calendar Tool Parameters:**
- calendar_id: 'primary' (or use project schedule calendar if accessible)
- action: 'create' (or 'update' if event exists)
- event_title: "Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning"
- start_time: "2025-11-17T15:30:00"
- end_time: "2025-11-17T17:30:00"
- event_description: "Executive Strategy Group meeting to review V1 legacy assets, market analysis, design system, branding, and V2 technical baseline."

**CRITICAL:** You MUST see a SUCCESS message confirming the calendar event was created/updated.

**After Calendar Creation:**
Once the calendar event is successfully created, you MUST:
1. Use the **GMailTool** to send a notification email to all 15 team members:
   - Recipients: {', '.join(agent_emails[:5])} and 10 others (all 15 agents)
   - CC: collin.m@ratiovita.com (MANDATORY)
   - Subject: "Meeting Rescheduled: Executive Strategy Group Meeting - TODAY 3:30 PM"
   - Body: "The Executive Strategy Group Meeting has been rescheduled to TODAY, Monday, November 17, 2025, from 3:30 PM to 5:30 PM. All pre-read materials remain valid. Please confirm attendance."
   
2. Update your memory document with:
   - "Meeting Rescheduled: Executive Strategy Group Meeting - November 17, 2025, 3:30 PM - 5:30 PM"
   - "Notification sent to all 15 team members"
   - Timestamp

**VERIFY:** You must see SUCCESS messages for both calendar creation and email notification.
"""
    
    task = Task(
        description=task_description,
        agent=dana_agent,
        expected_output="Calendar event created/updated for 3:30 PM today, notification email sent to all team members, memory updated with confirmation."
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
    print("Starting meeting reschedule...")
    print("="*80)
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ MEETING RESCHEDULE COMPLETE")
        print("="*80)
        print(f"\n📊 Results:\n{result}")
        return result
    except Exception as e:
        print(f"\n❌ Error during execution: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    reschedule_meeting_330pm()



