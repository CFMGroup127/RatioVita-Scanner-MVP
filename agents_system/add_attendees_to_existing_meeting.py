"""
Add Attendees to Existing Meeting
This script updates the existing 9:45 PM meeting to include all 15 agents as attendees.
"""
import os
from datetime import datetime
from crewai import Agent, Task, Crew, Process
from config import Config
from main import load_agents_from_yaml, get_agent_metadata

def add_attendees_to_meeting():
    """
    Update the existing meeting to add all 15 agents as attendees.
    """
    print("\n" + "="*80)
    print("📅 ADDING ATTENDEES TO EXISTING MEETING")
    print("="*80)
    print("Meeting: Executive Strategy Group Meeting - 9:45 PM EST")
    print("Action: Add all 15 agents as attendees")
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
    
    # Get David Chen (COO) - responsible for calendar management
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
    agent_emails = []
    for agent in agents:
        agent_meta = get_agent_metadata(agent.role)
        email = agent_meta.get('email_address', '')
        if email:
            agent_emails.append(email)
    
    print(f"\n📧 Agent emails: {len(agent_emails)} agents")
    for email in agent_emails:
        print(f"   - {email}")
    
    # Project Schedule Calendar ID
    project_calendar_id = "c_4e1c24ca3fdea15ff6de1ee2e0d025f75a1f8ff58ef58e2119e5273e51a5e7dc@group.calendar.google.com"
    
    task_description = f"""
**TASK: Update Existing Meeting to Add All Attendees**

You MUST use the **Google Calendar Tool** to update the existing Executive Strategy Group Meeting 
on the Project Schedule Calendar to include all 15 agents as attendees.

**Meeting Details:**
- Calendar: RatioVitaAi Project Schedule Calendar
- Calendar ID: {project_calendar_id}
- Event Title: "Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning"
- Date: November 17, 2025
- Time: 9:45 PM EST - 11:45 PM EST

**CRITICAL INSTRUCTIONS:**
1. First, use the Google Calendar Tool with action='list' to find the meeting event on the Project Schedule Calendar.
2. Once you find the event, you need to update it to add all 15 agents as attendees.
3. The Google Calendar Tool should automatically add attendees when creating events on the Project Schedule Calendar.
4. However, since this event already exists, you may need to use a different approach.

**IMPORTANT:** The Google Calendar Tool has been updated to automatically add all 15 agents as attendees 
when creating events on the Project Schedule Calendar. However, for existing events, you may need to:
- Delete the existing event
- Recreate it with the same details (which will automatically add all attendees)

**Alternative Approach:**
If the Calendar Tool doesn't support updating attendees directly, you should:
1. Note the exact event details (title, start time, end time, description, location)
2. Delete the existing event
3. Recreate it with the same details - the tool will automatically add all 15 agents as attendees
4. This will trigger email invitations to all attendees automatically

**All 15 Agent Emails to Add:**
{', '.join(agent_emails)}

**After Updating:**
1. Verify the event has all 15 attendees
2. Confirm that email invitations were sent (the tool uses sendUpdates='all')
3. Update your memory document with:
   - "Meeting updated: All 15 agents added as attendees"
   - "Email invitations sent to all attendees"
   - Timestamp (in EST per P9 protocol)
"""
    
    task = Task(
        description=task_description,
        agent=david_agent,
        expected_output="Meeting updated with all 15 agents as attendees, email invitations sent to all attendees, memory updated with confirmation."
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
    print("Starting attendee update...")
    print("="*80)
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ ATTENDEE UPDATE COMPLETE")
        print("="*80)
        print(f"\n📊 Results:\n{result}")
        return result
    except Exception as e:
        print(f"\n❌ Error during execution: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    add_attendees_to_meeting()


