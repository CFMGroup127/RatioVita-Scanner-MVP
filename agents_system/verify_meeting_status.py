"""
Verify Meeting Status: Check if meeting is underway, agents are present, and Dana is taking notes
"""
import os
from datetime import datetime
from crewai import Agent, Task, Crew, Process
from config import Config
from main import load_agents_from_yaml, get_agent_metadata

def verify_meeting_status():
    """
    Verify meeting status, agent presence, and Dana's note-taking.
    """
    print("\n" + "="*80)
    print("🔍 VERIFYING MEETING STATUS")
    print("="*80)
    print("Meeting: Executive Strategy Group Meeting")
    print("Scheduled: 5:00 PM EST - 7:00 PM EST (November 17, 2025)")
    print("="*80)
    
    # Check current time (using system time - assume EST)
    current_time = datetime.now()
    # Meeting times in EST (17:00 = 5:00 PM, 19:00 = 7:00 PM)
    current_hour = current_time.hour
    current_minute = current_time.minute
    
    print(f"\n⏰ Current Time: {current_time.strftime('%I:%M %p')} (assuming EST)")
    
    # Simple time check (17:00 = 5:00 PM, 19:00 = 7:00 PM)
    if current_hour < 17:
        print("⏳ Meeting has not started yet (starts at 5:00 PM EST)")
        meeting_status = "NOT_STARTED"
    elif current_hour >= 17 and current_hour < 19:
        print("✅ Meeting is currently underway")
        elapsed_minutes = (current_hour - 17) * 60 + current_minute
        print(f"   Elapsed time: approximately {elapsed_minutes} minutes")
        meeting_status = "IN_PROGRESS"
    else:
        print("✅ Meeting time has passed (ended at 7:00 PM EST)")
        meeting_status = "ENDED"
    
    # Validate configuration
    try:
        Config.validate()
        print("\n✅ Configuration validated")
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
    
    # Get meeting transcript doc ID from Dana's metadata
    meeting_transcript_doc_id = dana_metadata.get('meeting_transcript_doc_id', '')
    if not meeting_transcript_doc_id:
        # Try environment variable
        meeting_transcript_doc_id = os.getenv('MEETING_TRANSCRIPT_DOC_ID', '197N8eEQh8mW_oB7zS1idfgGLm0ZtZFazVrUx47nlla0')
    
    print(f"\n📄 Meeting Transcript Doc ID: {meeting_transcript_doc_id or 'NOT CONFIGURED'}")
    
    # Get all agent memory doc IDs
    agent_memory_docs = {}
    for agent in agents:
        agent_meta = get_agent_metadata(agent.role)
        email = agent_meta.get('email_address', '')
        memory_doc_id = agent_meta.get('memory_doc_id', '')
        if email and memory_doc_id:
            agent_memory_docs[email] = {
                'name': agent.role,
                'memory_doc_id': memory_doc_id
            }
    
    print(f"\n📋 Found {len(agent_memory_docs)} agents with memory documents")
    
    task_description = f"""
**TASK: Verify Meeting Status and Agent Participation**

You MUST complete the following verification steps:

**STEP 1: VERIFY MEETING TIME**
Current time: {current_time.strftime('%I:%M %p')} (EST)
Meeting scheduled: 5:00 PM EST - 7:00 PM EST
Meeting status: {meeting_status}

**STEP 2: CHECK MEETING TRANSCRIPT**
You MUST use the **Google Docs Read Tool** to check the meeting transcript document.
- Document ID: {meeting_transcript_doc_id or 'CHECK CONFIG'}
- Verify if Dana has written any meeting notes or transcript content
- Report the current content status (blank, partial, complete)

**STEP 3: CHECK DANA'S MEMORY FOR MEETING NOTES**
You MUST use the **Google Docs Read Tool** to read Dana's memory document:
- Document ID: {dana_metadata.get('memory_doc_id', '')}
- Look for:
  - P8 Meeting Acceptance entry
  - P5 Active Note-Taking entries (meeting notes, decisions, assignments)
  - Any meeting-related logs

**STEP 4: CHECK SAMPLE AGENT MEMORY DOCUMENTS**
You MUST check at least 5 agent memory documents to verify:
- P8 Meeting Acceptance acknowledgments
- P5 Active Note-Taking entries (if meeting is in progress)
- Agent presence confirmation

Check these agents' memory documents:
1. Kyle Law (CEO): {agent_memory_docs.get('kyle.law@ratiovita.com', {}).get('memory_doc_id', 'NOT FOUND')}
2. David Chen (COO): {agent_memory_docs.get('david.chen@ratiovita.com', {}).get('memory_doc_id', 'NOT FOUND')}
3. Ash Roy (CTO): {agent_memory_docs.get('ash.roy@ratiovita.com', {}).get('memory_doc_id', 'NOT FOUND')}
4. Alice Kim: {agent_memory_docs.get('alice.kim@ratiovita.com', {}).get('memory_doc_id', 'NOT FOUND')}
5. Samuel Reed: {agent_memory_docs.get('samuel.reed@ratiovita.com', {}).get('memory_doc_id', 'NOT FOUND')}

**STEP 5: COMPILE VERIFICATION REPORT**
After checking all documents, provide a comprehensive report:
- Meeting status (in progress, not started, ended)
- Meeting transcript status (blank, partial, complete)
- Dana's note-taking status (active, not started, complete)
- Agent presence verification (how many agents have P8 acceptance logged)
- Agent participation verification (how many agents have P5 notes logged)
- Recommendations for ensuring active participation

**CRITICAL:** You must use the Google Docs Read Tool to actually read the documents, not just assume their status.
"""
    
    task = Task(
        description=task_description,
        agent=dana_agent,
        expected_output="Comprehensive verification report including meeting status, transcript status, Dana's note-taking status, agent presence verification, and recommendations."
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
    print("Starting meeting status verification...")
    print("="*80)
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ MEETING STATUS VERIFICATION COMPLETE")
        print("="*80)
        print(f"\n📊 Results:\n{result}")
        return result
    except Exception as e:
        print(f"\n❌ Error during execution: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    verify_meeting_status()

