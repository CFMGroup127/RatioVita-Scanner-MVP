"""
Activate Meeting Notes: Have Dana start taking notes and remind all agents to log notes per P5
"""
import os
from datetime import datetime
from crewai import Agent, Task, Crew, Process
from config import Config
from main import load_agents_from_yaml, get_agent_metadata

def activate_meeting_notes():
    """
    Activate Dana's note-taking and remind all agents to log notes per P5 protocol.
    """
    print("\n" + "="*80)
    print("📝 ACTIVATING MEETING NOTES")
    print("="*80)
    print("Meeting: Executive Strategy Group Meeting")
    print("Time: 5:00 PM EST - 7:00 PM EST (Currently in progress)")
    print("Action: Activate Dana's note-taking and remind agents of P5 protocol")
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
    
    # Get meeting transcript doc ID
    meeting_transcript_doc_id = dana_metadata.get('meeting_transcript_doc_id', '197N8eEQh8mW_oB7zS1idfgGLm0ZtZFazVrUx47nlla0')
    
    # Get all agent emails
    agent_emails = []
    for agent in agents:
        agent_meta = get_agent_metadata(agent.role)
        email = agent_meta.get('email_address', '')
        if email:
            agent_emails.append(email)
    
    individual_email_list = ', '.join(agent_emails)
    
    current_time = datetime.now()
    
    task_description = f"""
**URGENT TASK: Activate Meeting Notes and Remind Agents of P5 Protocol**

The Executive Strategy Group Meeting is currently in progress (5:00 PM EST - 7:00 PM EST). 
Verification shows that:
- Meeting transcript is BLANK (Dana has not started taking notes)
- Only 5 agents have logged P8 acceptance
- ZERO agents have logged P5 notes during the meeting

You MUST complete the following actions IMMEDIATELY:

**STEP 1: START TAKING MEETING NOTES**
You MUST use the **MeetingTranscriptTool** to start writing meeting notes to the transcript document:
- Document ID: {meeting_transcript_doc_id}
- Content: Begin documenting the meeting with:
  "Executive Strategy Group Meeting - November 17, 2025, 5:00 PM EST - 7:00 PM EST
  Meeting Status: IN PROGRESS
  Current Time: {current_time.strftime('%I:%M %p EST')}
  
  MEETING NOTES:
  [Start documenting key points, decisions, assignments, and action items as they occur]
  
  ATTENDEES:
  - All 15 agents invited and expected to participate
  
  AGENDA ITEMS:
  1. V1 Legacy Asset Review (Alice Kim)
  2. V2 Market Analysis (Samuel Reed)
  3. V2 Design System Foundation (Arthur Jensen)
  4. V2 Branding & Value Propositions (Megan Parker)
  5. V2 Technical Baseline (Ash Roy)
  6. Strategic Planning and Next Steps"
  
- You MUST continue adding notes throughout the meeting per P5 protocol
- Update the transcript in real-time as decisions are made and action items are assigned

**STEP 2: REMIND ALL AGENTS TO LOG P5 NOTES**
You MUST use the **GMailTool** to send an URGENT reminder to all 15 agents:
- Recipients: {individual_email_list}
- **CRITICAL:** Use individual email addresses only. NO GROUP ALIASES.
- CC: collin.m@ratiovita.com (MANDATORY)
- Subject: "URGENT: Meeting In Progress - Please Log Your Notes (P5 Protocol)"
- Body: "The Executive Strategy Group Meeting is currently in progress (5:00 PM EST - 7:00 PM EST). 

Per P5: ACTIVE NOTE-TAKING & LOGGING protocol, you MUST immediately:
1. Log all decisions, assignments, and key points that affect your role into your memory document
2. Include timestamps with each entry
3. Document any action items assigned to you
4. Continue logging throughout the meeting

This is MANDATORY per protocol P5. Your memory document should show active note-taking entries with timestamps.

Current meeting time: {current_time.strftime('%I:%M %p EST')}
Meeting ends at: 7:00 PM EST

Please log your notes NOW."

**STEP 3: UPDATE YOUR MEMORY**
After sending the reminder, update your memory document with:
- "Meeting notes activation: {current_time.strftime('%I:%M %p EST')}"
- "Reminder sent to all 15 agents regarding P5 note-taking protocol"
- "Meeting transcript writing initiated"

**CRITICAL:** 
- You must start writing to the transcript IMMEDIATELY
- You must send the reminder email to all agents using individual addresses
- You must continue taking notes throughout the meeting
"""
    
    task = Task(
        description=task_description,
        agent=dana_agent,
        expected_output="Meeting transcript writing initiated, reminder email sent to all 15 agents regarding P5 protocol, memory updated with activation status."
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
    print("Activating meeting notes and sending reminders...")
    print("="*80)
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ MEETING NOTES ACTIVATION COMPLETE")
        print("="*80)
        print(f"\n📊 Results:\n{result}")
        return result
    except Exception as e:
        print(f"\n❌ Error during execution: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    activate_meeting_notes()



