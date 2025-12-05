"""
Force Meeting Acknowledgment
This script forces all agents to acknowledge the meeting invite and send confirmation emails.
Enhanced with asynchronous execution for concurrent processing of all 15 agents.
"""
import os
import sys
from datetime import datetime, timedelta
from concurrent.futures import ThreadPoolExecutor, as_completed
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
    
    # Meeting details (2:30 PM EST today)
    from datetime import timedelta
    today = datetime.now()
    meeting_title = "Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning"
    meeting_date = today.strftime('%B %d, %Y')
    meeting_time = "2:30 PM - 4:30 PM EST"
    
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
        
        # Get personal calendar ID
        personal_calendar_id = agent_meta.get('personal_calendar_id', '')
        
        # Calculate meeting times (2:30 PM - 4:30 PM EST today)
        start_time = today.replace(hour=14, minute=30, second=0, microsecond=0)
        end_time = start_time + timedelta(hours=2)
        start_time_iso = start_time.strftime('%Y-%m-%dT%H:%M:00')
        end_time_iso = end_time.strftime('%Y-%m-%dT%H:%M:00')
        
        task_description = f"""
**MANDATORY P8 PROTOCOL EXECUTION**

You have received a calendar invitation for the Executive Strategy Group Meeting. You MUST complete ALL 4 steps of the P8 protocol immediately.

**MEETING DETAILS:**
- Title: {meeting_title}
- Date: {meeting_date}
- Time: {meeting_time} (14:30 - 16:30 EST)

**STEP 1: LOG TO MEMORY (P8 Protocol)**
- Use the **Google Docs Memory Tool** to append the following entry to your memory document:
  - doc_id: {memory_doc_id}
  - content: "MEETING ACCEPTED: {meeting_title} - {meeting_date} at {meeting_time} EST - {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}"
  - append: true
- This creates an auditable, timestamped record in your memory.

**STEP 2: ADD TO PERSONAL CALENDAR (P8 Protocol)**
- Use the **Google Calendar Tool** to add the meeting event to your personal calendar:
  - calendar_id: {personal_calendar_id}
  - action: 'create'
  - event_title: "{meeting_title}"
  - event_description: "Executive Strategy Group Meeting for V1 Legacy Review and V2 Planning. All 15 agents are required to attend."
  - start_time: "{start_time_iso}"
  - end_time: "{end_time_iso}"
  - location: "Virtual Meeting"
- This ensures the meeting appears on your calendar and you receive notifications.

**STEP 3: EMAIL CONFIRMATION (P8 Protocol)**
- Use the **GMailTool** to send a confirmation email:
  - To: {dana_email}, {david_email}
  - CC: collin.m@ratiovita.com (MANDATORY - automatically added by Gmail Tool)
  - Subject: "Meeting Acceptance Confirmation: {meeting_title}"
  - Body: "I have received and accepted the calendar invitation for {meeting_title} scheduled for {meeting_date} at {meeting_time}. I will attend the meeting as scheduled. {agent_name}"
- **CRITICAL:** You MUST see a SUCCESS message from the Gmail Tool before proceeding.

**STEP 4: LOG EMAIL CONFIRMATION TO MEMORY (P8 Protocol)**
- After sending the confirmation email, immediately use the **Google Docs Memory Tool** to append:
  - doc_id: {memory_doc_id}
  - content: "EMAIL CONFIRMATION SENT: Meeting Acceptance Confirmation for {meeting_title} sent to David Chen and Dana Flores on {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}"
  - append: true

**VERIFY COMPLETION:**
- Confirm that:
  1. Your memory document has been updated with both the meeting acceptance and email confirmation entries
  2. The meeting event has been added to your personal calendar
  3. The confirmation email was sent successfully to both Dana and David
  4. You see SUCCESS messages from all tools (Google Docs Memory Tool, Google Calendar Tool, and Gmail Tool)

**This is a MANDATORY protocol (P8) that ensures:**
- The meeting appears on your personal calendar with notifications
- Both David (meeting organizer) and Dana (coordination) receive formal confirmation
- An auditable email trail separate from memory logs
- Full compliance with the RatioVita meeting acknowledgment protocol
"""
        
        task = Task(
            description=task_description,
            agent=agent,
            expected_output=f"All 4 P8 steps completed: memory logged (meeting acceptance + email confirmation), calendar event created in personal calendar, and confirmation email sent to {dana_email} and {david_email} with CC to collin.m@ratiovita.com"
        )
        
        tasks.append(task)
    
    print(f"\n📋 Created {len(tasks)} acknowledgment tasks")
    
    # Process agents concurrently using ThreadPoolExecutor
    def process_single_agent(agent_task_pair):
        """Process a single agent's task"""
        agent, task = agent_task_pair
        agent_name = agent.role
        
        try:
            print(f"[{agent_name}]: Starting P8 protocol execution...")
            
            # Create crew for this single agent
            crew = Crew(
                agents=[agent],
                tasks=[task],
                verbose=False  # Reduce verbosity for concurrent execution
            )
            
            # Execute task
            result = crew.kickoff()
            
            print(f"[{agent_name}]: ✅ P8 protocol complete")
            return {'agent': agent_name, 'status': 'success', 'result': result}
            
        except Exception as e:
            print(f"[{agent_name}]: ❌ Error: {e}")
            return {'agent': agent_name, 'status': 'error', 'error': str(e)}
    
    # Prepare agent-task pairs
    agent_task_pairs = list(zip(agents, tasks))
    
    print(f"\n🚀 Executing meeting acknowledgment tasks CONCURRENTLY...")
    print(f"   Using ThreadPoolExecutor with max_workers=15")
    print("="*80)
    
    success_count = 0
    error_count = 0
    results = []
    
    try:
        # Execute all agents concurrently
        with ThreadPoolExecutor(max_workers=15) as executor:
            # Submit all tasks
            future_to_agent = {
                executor.submit(process_single_agent, pair): pair[0].role 
                for pair in agent_task_pairs
            }
            
            # Collect results as they complete
            for future in as_completed(future_to_agent):
                agent_name = future_to_agent[future]
                try:
                    result = future.result()
                    results.append(result)
                    if result['status'] == 'success':
                        success_count += 1
                    else:
                        error_count += 1
                except Exception as e:
                    print(f"[{agent_name}]: ❌ Exception: {e}")
                    error_count += 1
                    results.append({'agent': agent_name, 'status': 'error', 'error': str(e)})
        
        # Summary
        print("\n" + "="*80)
        print("✅ CONCURRENT EXECUTION COMPLETE")
        print("="*80)
        print(f"Total Agents: {len(agents)}")
        print(f"✅ Successful: {success_count}")
        print(f"❌ Errors: {error_count}")
        
        if error_count > 0:
            print(f"\n⚠️  Agents with errors:")
            for result in results:
                if result['status'] == 'error':
                    print(f"   - {result['agent']}: {result.get('error', 'Unknown error')}")
        
        return success_count > 0
        
    except Exception as e:
        print(f"\n❌ Error during concurrent execution: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = force_meeting_acknowledgment()
    sys.exit(0 if success else 1)


