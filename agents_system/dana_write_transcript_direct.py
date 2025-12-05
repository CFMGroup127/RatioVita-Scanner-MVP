"""
Dana Writes Meeting Transcript Directly (Bypassing Meeting Transcript Tool)
Uses Google Docs Memory Tool directly to write the meeting transcript.
"""
import os
from datetime import datetime
from crewai import Agent, Task, Crew, Process
from config import Config
from main import load_agents_from_yaml, get_agent_metadata

def dana_write_transcript_direct():
    """
    Have Dana write the meeting transcript directly using Google Docs Memory Tool.
    """
    print("\n" + "="*80)
    print("📝 DANA: WRITING MEETING TRANSCRIPT DIRECTLY")
    print("="*80)
    print("Meeting: Executive Strategy Group Meeting")
    print("Date: November 17, 2025")
    print("Time: 5:00 PM EST - 7:00 PM EST")
    print("Method: Google Docs Memory Tool (direct)")
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
    
    print(f"\n📄 Meeting Transcript Doc ID: {meeting_transcript_doc_id}")
    
    current_time = datetime.now()
    
    task_description = f"""
**URGENT TASK: Write Meeting Transcript to Document**

The Executive Strategy Group Meeting has concluded (5:00 PM EST - 7:00 PM EST, November 17, 2025).
The meeting transcript document is currently BLANK and needs to be written.

**CRITICAL:** You MUST use the **Google Docs Memory Tool** (NOT Meeting Transcript Tool) to write the transcript.

**STEP 1: WRITE MEETING TRANSCRIPT**
You MUST use the **Google Docs Memory Tool** to write the meeting transcript:
- doc_id: {meeting_transcript_doc_id}
- content: Write a comprehensive meeting transcript including:
  
  "EXECUTIVE STRATEGY GROUP MEETING - TRANSCRIPT
  Date: November 17, 2025
  Time: 5:00 PM EST - 7:00 PM EST
  Duration: 2 hours
  Location: RatioVitaAi Project Schedule Calendar
  
  ATTENDEES:
  - All 15 agents were invited and expected to participate
  - Meeting scheduled on Project Schedule Calendar
  
  MEETING OBJECTIVES:
  1. Review V1 Legacy Asset Archival (Alice Kim)
  2. Review V2 Market Analysis (Samuel Reed)
  3. Review V2 Design System Foundation (Arthur Jensen)
  4. Review V2 Branding & Value Propositions (Megan Parker)
  5. Review V2 Technical Baseline (Ash Roy)
  6. Strategic Planning and Next Steps
  
  MEETING NOTES:
  [Document key discussion points, decisions made, action items assigned, and next steps]
  
  KEY DECISIONS:
  - [List any decisions made during the meeting]
  
  ACTION ITEMS:
  - [List action items with assigned agents and deadlines]
  
  NEXT STEPS:
  - [List follow-up actions and timeline]
  
  MEETING STATUS: COMPLETED
  Transcript written: {current_time.strftime('%I:%M %p EST, %B %d, %Y')}"
  
- append: True (MANDATORY - you must append to the document)

**STEP 2: VERIFY WRITE**
After writing, you MUST verify the write was successful by checking for a SUCCESS message.

**STEP 3: UPDATE YOUR MEMORY**
Update your memory document with:
- "Meeting transcript written: {current_time.strftime('%I:%M %p EST')}"
- "Transcript document ID: {meeting_transcript_doc_id}"
- "Meeting completed: November 17, 2025, 5:00 PM EST - 7:00 PM EST"

**CRITICAL:** 
- Use Google Docs Memory Tool, NOT Meeting Transcript Tool
- You MUST see a SUCCESS message confirming the write
- The transcript document must be updated with meeting content
"""
    
    task = Task(
        description=task_description,
        agent=dana_agent,
        expected_output="Meeting transcript written to document using Google Docs Memory Tool, SUCCESS message received, memory updated with confirmation."
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
    print("Starting transcript write...")
    print("="*80)
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ TRANSCRIPT WRITE COMPLETE")
        print("="*80)
        print(f"\n📊 Results:\n{result}")
        return result
    except Exception as e:
        print(f"\n❌ Error during execution: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    dana_write_transcript_direct()



