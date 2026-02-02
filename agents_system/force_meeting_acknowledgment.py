"""
Force Meeting Acknowledgment
This script forces all agents to acknowledge the meeting invite and send confirmation emails.
"""
import os
import sys
from datetime import datetime
from crewai import Agent, Task, Crew
from main import load_agents_from_yaml, get_agent_metadata

def force_meeting_acknowledgment():
    """
    Force all agents to acknowledge the meeting and send confirmation emails.
    """
    print("\n" + "="*80)
    print("📧 FORCING MEETING ACKNOWLEDGMENT")
    print("="*80)
    print(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}")
    print("="*80)
    
    # Load agents
    agents = load_agents_from_yaml('agents.yaml')
    
    # Meeting details
    meeting_title = "Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning"
    meeting_date = "November 17, 2025"
    meeting_time = "11:00 PM EST - 1:00 AM EST"
    
    # Get Dana and David emails for confirmation
    dana_meta = get_agent_metadata('Dana Flores')
    david_meta = get_agent_metadata('David Chen')
    dana_email = dana_meta.get('email_address', 'dana.flores@ratiovita.com')
    david_email = david_meta.get('email_address', 'david.chen@ratiovita.com')
    
    print(f"\n📋 Meeting Details:")
    print(f"   Title: {meeting_title}")
    print(f"   Date: {meeting_date}")
    print(f"   Time: {meeting_time}")
    print(f"\n📧 Confirmation emails to:")
    print(f"   - {dana_email}")
    print(f"   - {david_email}")
    print(f"   - CC: collin.m@ratiovita.com (automatic)")
    
    # Create tasks for all agents
    tasks = []
    for agent in agents:
        agent_name = agent.role
        agent_meta = get_agent_metadata(agent_name)
        agent_email = agent_meta.get('email_address', '')
        memory_doc_id = agent_meta.get('memory_doc_id', '')
        
        if not agent_email:
            print(f"⚠️  Skipping {agent_name} - no email address")
            continue
        
        task_description = f"""
**MANDATORY MEETING ACKNOWLEDGMENT TASK**

You have received a calendar invitation for the Executive Strategy Group Meeting.

**MEETING DETAILS:**
- Title: {meeting_title}
- Date: {meeting_date}
- Time: {meeting_time}

**YOU MUST COMPLETE THE FOLLOWING STEPS:**

**STEP 1: LOG TO MEMORY (P8 Protocol)**
- Use the **Google Docs Memory Tool** to read your memory document (doc_id: {memory_doc_id})
- Append the following entry to your memory document:
  "MEETING ACCEPTED: {meeting_title} - {meeting_date} at {meeting_time} EST - [Current Timestamp]"
- This fulfills the P8 Memory Logging requirement

**STEP 2: SEND EMAIL CONFIRMATION (P8 Protocol)**
- Use the **GMailTool** to send a confirmation email with the following details:
  - To: {dana_email}, {david_email}
  - CC: collin.m@ratiovita.com (MANDATORY - automatically added by Gmail Tool)
  - Subject: "Meeting Acceptance Confirmation: {meeting_title}"
  - Body: "I have received and accepted the calendar invitation for {meeting_title} scheduled for {meeting_date} at {meeting_time}. I will attend the meeting as scheduled. {agent_name}"
- **CRITICAL:** You MUST see a SUCCESS message from the Gmail Tool before proceeding

**STEP 3: VERIFY COMPLETION**
- Confirm that:
  1. Your memory document has been updated with the meeting acceptance entry
  2. The confirmation email was sent successfully to both Dana and David
  3. The email includes CC to collin.m@ratiovita.com (automatic)

**This is a MANDATORY protocol (P8) that ensures both David (meeting organizer) and Dana (coordination) receive formal confirmation of your attendance.**
"""
        
        task = Task(
            description=task_description,
            agent=agent,
            expected_output=f"Memory document updated with meeting acceptance entry, and confirmation email sent to {dana_email} and {david_email} with CC to collin.m@ratiovita.com"
        )
        
        tasks.append(task)
    
    print(f"\n📋 Created {len(tasks)} acknowledgment tasks")
    
    # Create crew and execute
    crew = Crew(
        agents=agents,
        tasks=tasks,
        verbose=True
    )
    
    print(f"\n🚀 Executing meeting acknowledgment tasks...")
    print("="*80)
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ MEETING ACKNOWLEDGMENT COMPLETE")
        print("="*80)
        return True
    except Exception as e:
        print(f"\n❌ Error executing tasks: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = force_meeting_acknowledgment()
    sys.exit(0 if success else 1)


