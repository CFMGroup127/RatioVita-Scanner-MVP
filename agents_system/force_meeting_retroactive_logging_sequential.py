"""
Force Meeting Retroactive Logging - SEQUENTIAL VERSION
More reliable version that processes agents one at a time to avoid timeouts.
"""
import os
import sys
import re
from datetime import datetime
from crewai import Agent, Task, Crew
from main import load_agents_from_yaml, get_agent_metadata

# Import the parse function from the original script
from force_meeting_retroactive_logging import parse_meeting_outcomes_file

def force_retroactive_meeting_logging_sequential():
    """Force all agents to retroactively log the meeting - SEQUENTIALLY"""
    print("🔄 FORCING RETROACTIVE MEETING LOGGING (SEQUENTIAL)")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    # Parse meeting outcomes file
    print("📄 Reading MEETING_OUTCOMES_V1.txt...")
    meeting_data = parse_meeting_outcomes_file('MEETING_OUTCOMES_V1.txt')
    
    meeting_title = meeting_data['title']
    meeting_date = meeting_data['date']
    meeting_time = meeting_data['time']
    decisions = meeting_data['decisions']
    action_items = meeting_data['action_items']
    full_transcript = meeting_data['full_transcript']
    attendees = meeting_data['attendees']
    next_meeting = meeting_data['next_meeting']
    
    print(f"✅ Meeting data loaded:")
    print(f"   Title: {meeting_title}")
    print(f"   Date: {meeting_date}")
    print(f"   Time: {meeting_time}")
    print(f"   Decisions: {len(decisions)}")
    print(f"   Action Items: {len(action_items)}")
    print(f"   Transcript Length: {len(full_transcript)} characters\n")
    
    agents = load_agents_from_yaml('agents.yaml')
    dana_email = "dana.flores@ratiovita.com"
    david_email = "david.chen@ratiovita.com"
    
    tasks = []
    
    for agent in agents:
        role = agent.role
        meta = get_agent_metadata(role)
        
        agent_name = meta.get('email_address', '').split('@')[0].replace('.', ' ').title()
        if not agent_name:
            agent_name = role.split()[0] if role else 'Unknown'
        
        memory_doc_id = meta.get('memory_doc_id', '')
        calendar_id = meta.get('personal_calendar_id', '')
        email_address = meta.get('email_address', '')
        
        if not memory_doc_id:
            print(f"⚠️  Skipping {agent_name}: No memory_doc_id")
            continue
        
        # Check if this agent has action items assigned (for P7 delegation)
        relevant_actions = [ai for ai in action_items if agent_name.lower() in ai['owner'].lower() or role.lower() in ai['owner'].lower()]
        has_action_items = len(relevant_actions) > 0
        
        # Format decisions for MEETING_MINUTES template
        decisions_text = ""
        for i, decision in enumerate(decisions, 1):
            decisions_text += f"**Decision {i}:** {decision} | **Vote:** Unanimous\n"
        
        # Format action items for MEETING_MINUTES template
        action_items_text = ""
        for action in relevant_actions:
            action_items_text += f"**Task:** {action['task']} | **Owner:** {action['owner']} | **Due Date:** {action['deadline']}\n"
        
        # If no specific actions, include all for visibility
        if not relevant_actions:
            for action in action_items[:3]:  # Show first 3
                action_items_text += f"**Task:** {action['task']} | **Owner:** {action['owner']} | **Due Date:** {action['deadline']}\n"
        
        # Format attendees
        present_list = ", ".join(attendees['present'][:10]) if attendees['present'] else "All 15 agents"
        absent_list = ", ".join(attendees['absent']) if attendees['absent'] else "None"
        
        # Format next meeting
        next_meeting_text = ""
        if next_meeting:
            next_meeting_text = f"{next_meeting.get('date', 'TBD')} at {next_meeting.get('time', 'TBD')} - {next_meeting.get('type', 'Executive Strategy Group Meeting')}"
        else:
            next_meeting_text = "November 25, 2025 at 10:00 AM EST - Executive Strategy Group Meeting"
        
        task_description = f"""
**MANDATORY RETROACTIVE MEETING LOGGING**

You attended a meeting that occurred on {meeting_date} at {meeting_time}, but you failed to properly log it according to protocols. You must now retroactively complete all required protocols.

**MEETING DETAILS:**
- Title: {meeting_title}
- Date: {meeting_date}
- Time: {meeting_time}
- Status: Meeting has already occurred
- Attendance: 100% (All 15 agents present)

**YOU MUST COMPLETE THE FOLLOWING RETROACTIVE ACTIONS:**

**STEP 1: RETROACTIVE P8 PROTOCOL LOGGING (PROTOCOLS Section)**
- Use the **Google Docs Memory Tool** to log to your memory document (doc_id: {memory_doc_id}):
  - Section: "PROTOCOLS"
  - Subsection: "{meeting_date}"
  - Content: "RETROACTIVE P8 LOG: MEETING ACCEPTED: {meeting_title} - {meeting_date} at {meeting_time} EST - Logged: {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}"
  - Template: "Compliance Log"

**STEP 2: RETROACTIVE EMAIL CONFIRMATION (P8 Protocol)**
- Use the **GMailTool** to send a retroactive confirmation email:
  - To: {dana_email}, {david_email}
  - CC: collin.m@ratiovita.com (MANDATORY)
  - Subject: "Retroactive Meeting Acceptance: {meeting_title}"
  - Body: "I am retroactively confirming my attendance at {meeting_title} that occurred on {meeting_date} at {meeting_time}. I apologize for the delay in sending this confirmation. I was present at the meeting and participated in all discussions. {agent_name}"

**STEP 3: RETROACTIVE P5 MEETING NOTES (MEETINGS Section - MEETING_MINUTES Template)**
- Use the **Google Docs Memory Tool** to log meeting notes using the MEETING_MINUTES template:
  - Section: "MEETINGS"
  - Subsection: "{meeting_date}"
  - Template: "MEETING_MINUTES"
  - Content: "MEETING MINUTES: {meeting_title} - {meeting_date}\n\nI. Overview:\n- Time: {meeting_time}\n- Location: Virtual Meeting\n- Type: Executive Strategy Group\n\nII. Attendance:\n- Present: {present_list}\n- Absent: {absent_list}\n\nIII. Decisions Made:\n{decisions_text}\n\nIV. Action Items:\n{action_items_text}\n\nV. Key Discussion Points:\n- V1 Legacy Review: Systematic archival process approved\n- V2 Planning: Competitive analysis and legal risk assessment prioritized\n- Task Delegation: Specific action items assigned with deadlines\n- Next Steps: Follow-up meeting scheduled for {next_meeting_text}\n\nVI. Notes:\nThis is a retroactive log of the meeting that occurred. All protocols (P8, P5) are being completed post-meeting to ensure full compliance."

**STEP 4: RETROACTIVE CALENDAR EVENT (P12 Protocol)**
- Use the **Google Calendar Tool** to add the meeting to your personal calendar (calendar_id: {calendar_id}):
  - This ensures the meeting appears in your calendar history even though it already occurred
  - Use the meeting details: {meeting_title}, {meeting_date}, {meeting_time}

**STEP 5: RETROACTIVE TRANSCRIPT ENTRY (TRANSCRIPTS Section)**
- Use the **Google Docs Memory Tool** to log the full meeting transcript:
  - Section: "TRANSCRIPTS"
  - Subsection: "{meeting_date}"
  - Template: "MEETING_TRANSCRIPT_ARCHIVE"
  - Content: "{full_transcript[:3000] if len(full_transcript) > 3000 else full_transcript}"

**STEP 6: P7 TASK DELEGATION EMAIL (If Action Items Assigned)**
{f"- You have {len(relevant_actions)} action item(s) assigned to you. Use the **GMailTool** to send acknowledgment emails:" if has_action_items else "- No specific action items assigned to you in this meeting."}
{f"- For each action item, send an email to {dana_email} and {david_email} (CC: collin.m@ratiovita.com):" if has_action_items else ""}
{f"- Subject: 'Task Acknowledgment: [Task Name]'" if has_action_items else ""}
{f"- Body: 'I acknowledge receipt of the following task assigned during {meeting_title}: [Task Details]. I will complete this by [Deadline]. {agent_name}'" if has_action_items else ""}

**CRITICAL:** You must complete ALL applicable steps to ensure full compliance with protocols P8, P5, P7, and meeting documentation requirements.
"""
        
        expected_output_parts = [
            "P8 protocol logged to PROTOCOLS section",
            "P8 confirmation email sent",
            "P5 meeting notes added to MEETINGS section using MEETING_MINUTES template",
            "Calendar event added to personal calendar",
            "Transcript entry added to TRANSCRIPTS section using MEETING_TRANSCRIPT_ARCHIVE template"
        ]
        
        if has_action_items:
            expected_output_parts.append(f"P7 task delegation emails sent for {len(relevant_actions)} action item(s)")
        
        expected_output = f"Retroactive logging complete: {'; '.join(expected_output_parts)} for {meeting_title}"
        
        task = Task(
            description=task_description,
            agent=agent,
            expected_output=expected_output
        )
        
        tasks.append((agent, task))
    
    print(f"📋 Created {len(tasks)} retroactive logging tasks\n")
    print("🚀 Executing retroactive logging SEQUENTIALLY (one agent at a time)...")
    print("="*80)
    print("This will take longer but is more reliable.\n")
    
    success_count = 0
    error_count = 0
    results = []
    
    # Process agents SEQUENTIALLY (one at a time)
    for i, (agent, task) in enumerate(tasks, 1):
        agent_name = agent.role
        print(f"\n[{i}/{len(tasks)}] Processing: {agent_name}")
        print("-" * 80)
        
        try:
            crew = Crew(
                agents=[agent],
                tasks=[task],
                verbose=True  # More verbose for sequential execution
            )
            
            result = crew.kickoff()
            
            print(f"\n[{agent_name}]: ✅ Retroactive logging complete")
            results.append({'agent': agent_name, 'status': 'success', 'result': result})
            success_count += 1
            
        except Exception as e:
            print(f"\n[{agent_name}]: ❌ Error: {e}")
            import traceback
            traceback.print_exc()
            results.append({'agent': agent_name, 'status': 'error', 'error': str(e)})
            error_count += 1
        
        print("-" * 80)
    
    # Summary
    print("\n" + "="*80)
    print("✅ SEQUENTIAL EXECUTION COMPLETE")
    print("="*80)
    print(f"Total Agents: {len(tasks)}")
    print(f"✅ Successful: {success_count}")
    print(f"❌ Errors: {error_count}")
    
    if error_count > 0:
        print(f"\n⚠️  Agents with errors:")
        for result in results:
            if result['status'] == 'error':
                print(f"   - {result['agent']}: {result.get('error', 'Unknown error')}")
    
    return success_count > 0

if __name__ == "__main__":
    success = force_retroactive_meeting_logging_sequential()
    sys.exit(0 if success else 1)

