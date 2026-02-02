"""
Force Meeting Retroactive Logging
This script forces all agents to retroactively log the meeting that occurred,
including P8 acknowledgment, P5 notes, transcript creation, and P7 task delegation.

Enhanced to read from MEETING_OUTCOMES_V1.txt for structured meeting data.
"""
import os
import sys
import re
from datetime import datetime
from crewai import Agent, Task, Crew
from main import load_agents_from_yaml, get_agent_metadata
from concurrent.futures import ThreadPoolExecutor, as_completed

def parse_meeting_outcomes_file(filepath='MEETING_OUTCOMES_V1.txt'):
    """Parse the structured meeting outcomes file"""
    if not os.path.exists(filepath):
        print(f"⚠️  Warning: {filepath} not found. Using default meeting details.")
        return {
            'title': "Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning",
            'date': "November 20, 2025",
            'time': "2:30 PM - 4:30 PM EST",
            'transcript_summary': "Meeting focused on V1 legacy review and V2 planning.",
            'decisions': [],
            'action_items': [],
            'full_transcript': "",
            'attendees': {'present': [], 'absent': []},
            'next_meeting': {}
        }
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Parse meeting header
    title_match = re.search(r'# MEETING:\s*(.+)', content)
    date_match = re.search(r'# DATE:\s*(.+)', content)
    time_match = re.search(r'# TIME:\s*(.+)', content)
    summary_match = re.search(r'# TRANSCRIPT_SUMMARY:\s*(.+)', content)
    
    # Parse decisions
    decisions = []
    decisions_section = re.search(r'## DECISIONS MADE.*?##', content, re.DOTALL)
    if decisions_section:
        decision_lines = re.findall(r'# \d+\.\s*Decision:\s*(.+)', decisions_section.group(0))
        decisions = decision_lines
    
    # Parse action items
    action_items = []
    action_section = re.search(r'## ACTION ITEMS.*?##', content, re.DOTALL)
    if action_section:
        action_lines = re.findall(r'# \d+\.\s*Task:\s*(.+?)\s*Owner:\s*(.+?)\s*Deadline:\s*(.+)', action_section.group(0), re.DOTALL)
        for task, owner, deadline in action_lines:
            action_items.append({
                'task': task.strip(),
                'owner': owner.strip(),
                'deadline': deadline.strip()
            })
    
    # Parse full transcript
    transcript_section = re.search(r'## FULL TRANSCRIPT LOG.*?##', content, re.DOTALL)
    full_transcript = ""
    if transcript_section:
        full_transcript = transcript_section.group(0).replace('## FULL TRANSCRIPT LOG (For TRANSCRIPTS)', '').strip()
        # Remove the next section marker if present
        full_transcript = re.sub(r'^## .+$', '', full_transcript, flags=re.MULTILINE).strip()
    
    # Parse attendees
    attendees = {'present': [], 'absent': []}
    attendees_section = re.search(r'## ATTENDEES.*?##', content, re.DOTALL)
    if attendees_section:
        present_match = re.search(r'# Present:\s*(.+)', attendees_section.group(0))
        absent_match = re.search(r'# Absent:\s*(.+)', attendees_section.group(0))
        if present_match:
            attendees['present'] = [a.strip() for a in present_match.group(1).split(',')]
        if absent_match:
            attendees['absent'] = [a.strip() for a in absent_match.group(1).split(',')]
    
    # Parse next meeting
    next_meeting = {}
    next_section = re.search(r'## NEXT MEETING.*?$', content, re.DOTALL | re.MULTILINE)
    if next_section:
        date_match = re.search(r'# Date:\s*(.+)', next_section.group(0))
        time_match = re.search(r'# Time:\s*(.+)', next_section.group(0))
        type_match = re.search(r'# Type:\s*(.+)', next_section.group(0))
        if date_match:
            next_meeting['date'] = date_match.group(1).strip()
        if time_match:
            next_meeting['time'] = time_match.group(1).strip()
        if type_match:
            next_meeting['type'] = type_match.group(1).strip()
    
    return {
        'title': title_match.group(1).strip() if title_match else "Executive Strategy Group Meeting",
        'date': date_match.group(1).strip() if date_match else datetime.now().strftime('%B %d, %Y'),
        'time': time_match.group(1).strip() if time_match else "2:30 PM - 4:30 PM EST",
        'transcript_summary': summary_match.group(1).strip() if summary_match else "",
        'decisions': decisions,
        'action_items': action_items,
        'full_transcript': full_transcript,
        'attendees': attendees,
        'next_meeting': next_meeting
    }

def force_retroactive_meeting_logging():
    """Force all agents to retroactively log the meeting"""
    print("🔄 FORCING RETROACTIVE MEETING LOGGING")
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
        
        task_description = f"""
**MANDATORY RETROACTIVE MEETING LOGGING**

You attended a meeting that occurred on {meeting_date} at {meeting_time}, but you failed to properly log it according to protocols.

**MEETING DETAILS:**
- Title: {meeting_title}
- Date: {meeting_date}
- Time: {meeting_time}
- Status: Meeting has already occurred

**YOU MUST COMPLETE THE FOLLOWING RETROACTIVE ACTIONS:**

**STEP 1: RETROACTIVE P8 PROTOCOL LOGGING**
- Use the **Google Docs Memory Tool** to log to your memory document (doc_id: {memory_doc_id}):
  - Section: "PROTOCOLS"
  - Subsection: "{meeting_date}"
  - Content: "RETROACTIVE P8 LOG: MEETING ACCEPTED: {meeting_title} - {meeting_date} at {meeting_time} EST - [Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}]"
  - Template: "Compliance Log"

**STEP 2: RETROACTIVE EMAIL CONFIRMATION**
- Use the **GMailTool** to send a retroactive confirmation email:
  - To: {dana_email}, {david_email}
  - CC: collin.m@ratiovita.com (MANDATORY)
  - Subject: "Retroactive Meeting Acceptance: {meeting_title}"
  - Body: "I am retroactively confirming my attendance at {meeting_title} that occurred on {meeting_date} at {meeting_time}. I apologize for the delay in sending this confirmation. {agent_name}"

**STEP 3: RETROACTIVE P5 MEETING NOTES**
- Use the **Google Docs Memory Tool** to log meeting notes:
  - Section: "MEETINGS"
  - Subsection: "{meeting_date}"
  - Content: "MEETING NOTES - {meeting_title} ({meeting_time}):\n\nKey Points Discussed:\n- V1 Legacy Review was discussed\n- V2 Planning initiatives were reviewed\n- Tasks and deadlines were assigned\n- Next steps were identified\n\nAction Items Assigned:\n- [List any action items relevant to your role]\n\nNext Meeting: [If discussed]\n\nNotes: This is a retroactive log of the meeting that occurred."
  - Template: "MEETING_MINUTES"

**STEP 4: RETROACTIVE CALENDAR EVENT**
- Use the **Google Calendar Tool** to add the meeting to your personal calendar (calendar_id: {calendar_id}):
  - This ensures the meeting appears in your calendar history even though it already occurred

**STEP 5: RETROACTIVE TRANSCRIPT ENTRY (If you have transcript data)**
- If you have access to meeting transcript data, use the **Google Docs Memory Tool**:
  - Section: "TRANSCRIPTS"
  - Subsection: "{meeting_date}"
  - Content: "[Full meeting transcript or summary]"
  - Template: "MEETING_TRANSCRIPT_ARCHIVE"

**CRITICAL:** You must complete ALL steps to ensure full compliance with protocols P8, P5, and meeting documentation requirements.
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
    
    # Process agents concurrently
    def process_single_agent(agent_task_pair):
        """Process a single agent's retroactive logging"""
        agent, task = agent_task_pair
        agent_name = agent.role
        
        try:
            print(f"[{agent_name}]: Starting retroactive logging...")
            
            crew = Crew(
                agents=[agent],
                tasks=[task],
                verbose=False
            )
            
            result = crew.kickoff()
            
            print(f"[{agent_name}]: ✅ Retroactive logging complete")
            return {'agent': agent_name, 'status': 'success', 'result': result}
            
        except Exception as e:
            print(f"[{agent_name}]: ❌ Error: {e}")
            return {'agent': agent_name, 'status': 'error', 'error': str(e)}
    
    print("🚀 Executing retroactive logging CONCURRENTLY...")
    print("="*80)
    
    success_count = 0
    error_count = 0
    results = []
    
    try:
        with ThreadPoolExecutor(max_workers=15) as executor:
            future_to_agent = {
                executor.submit(process_single_agent, pair): pair[0].role 
                for pair in tasks
            }
            
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
        
        print("\n" + "="*80)
        print("✅ RETROACTIVE LOGGING COMPLETE")
        print("="*80)
        print(f"Total Agents: {len(tasks)}")
        print(f"✅ Successful: {success_count}")
        print(f"❌ Errors: {error_count}")
        
        return success_count > 0
        
    except Exception as e:
        print(f"\n❌ Error during retroactive logging: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = force_retroactive_meeting_logging()
    sys.exit(0 if success else 1)

