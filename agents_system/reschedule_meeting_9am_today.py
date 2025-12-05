"""
Reschedule Meeting to 9 AM EST Today
This script has David Chen reschedule the meeting to 9:00 AM EST today (November 18, 2025).
"""
import os
import sys
from datetime import datetime, timedelta
from crewai import Agent, Task, Crew
from main import load_agents_from_yaml, get_agent_metadata

def reschedule_meeting_9am_today():
    """
    Reschedule the Executive Strategy Group Meeting to 9:00 AM EST today.
    """
    print("\n" + "="*80)
    print("📅 RESCHEDULING MEETING TO 9:00 AM EST TODAY")
    print("="*80)
    print(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}")
    print("="*80)
    
    # Load agents
    agents = load_agents_from_yaml('agents.yaml')
    
    # Find David Chen (Process Architect and Schedule Publisher)
    david = None
    for agent in agents:
        if agent.role == "Process Architect and Schedule Publisher":
            david = agent
            break
    
    if not david:
        print("❌ Could not find David Chen (Process Architect and Schedule Publisher)")
        return False
    
    # Get David's metadata
    david_meta = get_agent_metadata(david.role)
    project_calendar_id = "c_4e1c24ca3fdea15ff6de1ee2e0d025f75a1f8ff58ef58e2119e5273e51a5e7dc@group.calendar.google.com"
    
    # Calculate today's date and 9 AM EST
    today = datetime.now()
    # Set to 9:00 AM EST (assuming we're in EST timezone)
    start_time = today.replace(hour=9, minute=0, second=0, microsecond=0)
    end_time = start_time + timedelta(hours=2)  # 2-hour meeting
    
    # Format for ISO 8601
    start_time_iso = start_time.strftime('%Y-%m-%dT%H:%M:00')
    end_time_iso = end_time.strftime('%Y-%m-%dT%H:%M:00')
    
    print(f"\n📋 Meeting Details:")
    print(f"   Title: Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning")
    print(f"   Date: {start_time.strftime('%B %d, %Y')}")
    print(f"   Time: {start_time.strftime('%I:%M %p')} EST - {end_time.strftime('%I:%M %p')} EST")
    print(f"   Calendar: Project Schedule Calendar")
    print(f"   Calendar ID: {project_calendar_id}")
    
    task_description = f"""
**CRITICAL TASK: Reschedule Executive Strategy Group Meeting**

You MUST reschedule the Executive Strategy Group Meeting to **9:00 AM EST TODAY (November 18, 2025)**.

**MEETING DETAILS:**
- Title: Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning
- Date: November 18, 2025
- Start Time: 9:00 AM EST ({start_time_iso})
- End Time: 11:00 AM EST ({end_time_iso})
- Location: Virtual Meeting
- Calendar: RatioVitaAi Project Schedule Calendar
- Calendar ID: {project_calendar_id}

**CRITICAL INSTRUCTIONS:**

1. **FIND EXISTING EVENT:**
   - Use the **Google Calendar Tool** with action='list' to find the existing meeting event on the Project Schedule Calendar
   - Look for "Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning"

2. **UPDATE OR RECREATE EVENT:**
   - If you can update the existing event, use the Google Calendar Tool to update the start and end times
   - If update is not possible, delete the old event and create a new one with the new time
   - **IMPORTANT:** The Google Calendar Tool automatically adds all 15 agents as attendees when creating/updating events on the Project Schedule Calendar

3. **VERIFY ATTENDEES:**
   - After updating/creating, verify that all 15 agents are listed as attendees
   - The calendar tool should automatically include:
     - dana.flores@ratiovita.com
     - kyle.law@ratiovita.com
     - david.chen@ratiovita.com
     - ash.roy@ratiovita.com
     - sophia.vance@ratiovita.com
     - megan.parker@ratiovita.com
     - arthur.jensen@ratiovita.com
     - ethan.hayes@ratiovita.com
     - chloe.park@ratiovita.com
     - samuel.reed@ratiovita.com
     - alice.kim@ratiovita.com
     - victor.alvarez@ratiovita.com
     - jennifer.jurvais@ratiovita.com
     - tyler.cobb@ratiovita.com
     - rachel.stone@ratiovita.com

4. **SEND NOTIFICATION:**
   - After the calendar event is updated, use the **GMailTool** to send a notification email to all 15 agents
   - To: All 15 individual agent email addresses (use the STRICT EMAIL PROTOCOL - no group aliases)
   - CC: collin.m@ratiovita.com (MANDATORY - automatically added by Gmail Tool)
   - Subject: "Meeting Rescheduled: Executive Strategy Group Meeting - Now 9:00 AM EST Today"
   - Body: "The Executive Strategy Group Meeting has been rescheduled to 9:00 AM EST - 11:00 AM EST today (November 18, 2025). Please update your calendars and confirm attendance. All agents are automatically added as attendees to the calendar event."

5. **UPDATE MEMORY:**
   - Log this task completion in your memory document
   - Note: "Meeting rescheduled to 9:00 AM EST - 11:00 AM EST, November 18, 2025. All 15 agents notified via email and added to calendar event."

**This ensures all agents receive the updated meeting time and are properly added as attendees to the calendar event.**
"""
    
    task = Task(
        description=task_description,
        agent=david,
        expected_output="Meeting rescheduled to 9:00 AM EST today on Project Schedule Calendar with all 15 agents as attendees, and notification email sent to all agents."
    )
    
    crew = Crew(
        agents=[david],
        tasks=[task],
        verbose=True
    )
    
    print(f"\n🚀 Executing reschedule task...")
    print("="*80)
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ MEETING RESCHEDULE COMPLETE")
        print("="*80)
        return True
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = reschedule_meeting_9am_today()
    sys.exit(0 if success else 1)


