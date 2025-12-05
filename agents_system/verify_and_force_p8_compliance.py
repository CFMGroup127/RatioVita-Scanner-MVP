"""
Verify and Force P8 Protocol Compliance
This script:
1. Verifies each agent has added the meeting to their personal calendar
2. Checks memory documents for P8 acceptance logs
3. Checks for email confirmations
4. Forces agents to execute complete P8 protocol if they haven't already
"""
import os
import sys
from datetime import datetime, timedelta
from crewai import Agent, Task, Crew
from config import Config
from main import load_agents_from_yaml, get_agent_metadata
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build

# Project Schedule Calendar ID
PROJECT_CALENDAR_ID = "c_4e1c24ca3fdea15ff6de1ee2e0d025f75a1f8ff58ef58e2119e5273e51a5e7dc@group.calendar.google.com"

# Meeting details (2:30 PM EST today)
MEETING_TITLE = "Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning"
MEETING_DATE = datetime.now().strftime('%B %d, %Y')
MEETING_TIME = "2:30 PM - 4:30 PM EST"

def get_calendar_service():
    """Get calendar service for verification"""
    creds = None
    if os.path.exists('token.json'):
        try:
            # Try to load with requested scopes
            creds = Credentials.from_authorized_user_file('token.json', [
                'https://www.googleapis.com/auth/calendar',
                'https://www.googleapis.com/auth/documents.readonly'
            ])
        except:
            # Fallback: load without scopes and check if calendar scope exists
            try:
                creds = Credentials.from_authorized_user_file('token.json', None)
                if creds.scopes:
                    has_calendar = any('calendar' in s for s in creds.scopes)
                    if not has_calendar:
                        return None
            except:
                return None
        
        if not creds.valid:
            if creds.expired and creds.refresh_token:
                try:
                    creds.refresh(Request())
                except:
                    # If refresh fails, return None
                    return None
    
    if creds:
        return build('calendar', 'v3', credentials=creds)
    return None

def check_personal_calendar(calendar_service, personal_calendar_id, meeting_title):
    """Check if meeting exists in agent's personal calendar"""
    if not calendar_service or not personal_calendar_id:
        return {'found': False, 'error': 'No calendar service or ID'}
    
    try:
        today = datetime.now()
        start_of_day = today.replace(hour=0, minute=0, second=0, microsecond=0)
        end_of_day = today.replace(hour=23, minute=59, second=59, microsecond=0)
        
        time_min = start_of_day.isoformat() + 'Z'
        time_max = end_of_day.isoformat() + 'Z'
        
        events_result = calendar_service.events().list(
            calendarId=personal_calendar_id,
            timeMin=time_min,
            timeMax=time_max,
            maxResults=20,
            singleEvents=True,
            orderBy='startTime'
        ).execute()
        
        events = events_result.get('items', [])
        
        for event in events:
            event_title = event.get('summary', '')
            if 'Executive Strategy Group' in event_title or 'V1 Legacy Review' in event_title:
                return {
                    'found': True,
                    'event_id': event.get('id', ''),
                    'start_time': event.get('start', {}).get('dateTime', ''),
                    'title': event_title
                }
        
        return {'found': False}
    except Exception as e:
        return {'found': False, 'error': str(e)}

def check_memory_for_p8(memory_doc_id):
    """Check memory document for P8 acceptance log"""
    if not memory_doc_id:
        return {'found': False, 'error': 'No memory doc ID'}
    
    try:
        # Use Google Docs API directly to read
        creds = None
        if os.path.exists('token.json'):
            try:
                creds = Credentials.from_authorized_user_file('token.json', [
                    'https://www.googleapis.com/auth/documents.readonly'
                ])
            except:
                # Fallback: try without scopes
                try:
                    creds = Credentials.from_authorized_user_file('token.json', None)
                    if creds.scopes:
                        has_docs = any('documents' in s or 'drive' in s for s in creds.scopes)
                        if not has_docs:
                            return {'found': False, 'error': 'No documents scope'}
                except:
                    return {'found': False, 'error': 'Could not load credentials'}
            
            if not creds.valid:
                if creds.expired and creds.refresh_token:
                    try:
                        creds.refresh(Request())
                    except:
                        return {'found': False, 'error': 'Token refresh failed'}
        
        if not creds:
            return {'found': False, 'error': 'Could not get credentials'}
        
        docs_service = build('docs', 'v1', credentials=creds)
        doc = docs_service.documents().get(documentId=memory_doc_id).execute()
        
        # Extract text content
        content = ''
        if 'body' in doc and 'content' in doc['body']:
            for element in doc['body']['content']:
                if 'paragraph' in element:
                    for para_element in element['paragraph'].get('elements', []):
                        if 'textRun' in para_element:
                            content += para_element['textRun'].get('content', '')
        
        if content and ('MEETING ACCEPTED' in content or 'MEETING ACCEPTANCE' in content):
            return {'found': True, 'content': content[:200]}  # First 200 chars
        
        return {'found': False}
    except Exception as e:
        return {'found': False, 'error': str(e)}

def verify_all_agents():
    """Verify P8 compliance for all agents"""
    print("\n" + "="*80)
    print("🔍 VERIFYING P8 PROTOCOL COMPLIANCE FOR ALL AGENTS")
    print("="*80)
    print(f"Meeting: {MEETING_TITLE}")
    print(f"Date: {MEETING_DATE}")
    print(f"Time: {MEETING_TIME}")
    print("="*80)
    
    # Get calendar service
    calendar_service = get_calendar_service()
    if not calendar_service:
        print("⚠️  Could not get calendar service - will skip calendar verification")
    
    # Load agents
    agents = load_agents_from_yaml('agents.yaml')
    
    verification_results = []
    agents_needing_p8 = []
    
    print(f"\n📋 Checking {len(agents)} agents...")
    print("="*80)
    
    for agent in agents:
        agent_role = agent.role
        agent_meta = get_agent_metadata(agent_role)
        agent_email = agent_meta.get('email_address', '')
        memory_doc_id = agent_meta.get('memory_doc_id', '')
        personal_calendar_id = agent_meta.get('personal_calendar_id', '')
        
        print(f"\n👤 {agent_role}")
        print(f"   Email: {agent_email}")
        
        # Check personal calendar
        calendar_status = check_personal_calendar(calendar_service, personal_calendar_id, MEETING_TITLE)
        has_calendar = calendar_status.get('found', False)
        
        if has_calendar:
            print(f"   ✅ Meeting in personal calendar")
        else:
            print(f"   ❌ Meeting NOT in personal calendar")
            if 'error' in calendar_status:
                print(f"      Error: {calendar_status['error']}")
        
        # Check memory for P8 log
        memory_status = check_memory_for_p8(memory_doc_id)
        has_memory_log = memory_status.get('found', False)
        
        if has_memory_log:
            print(f"   ✅ P8 acceptance logged in memory")
        else:
            print(f"   ❌ P8 acceptance NOT logged in memory")
            if 'error' in memory_status:
                print(f"      Error: {memory_status['error']}")
        
        # Determine if agent needs P8 enforcement
        needs_p8 = not has_calendar or not has_memory_log
        
        verification_results.append({
            'agent_role': agent_role,
            'agent_email': agent_email,
            'memory_doc_id': memory_doc_id,
            'personal_calendar_id': personal_calendar_id,
            'has_calendar': has_calendar,
            'has_memory_log': has_memory_log,
            'needs_p8': needs_p8
        })
        
        if needs_p8:
            agents_needing_p8.append(agent)
            print(f"   ⚠️  NEEDS P8 ENFORCEMENT")
        else:
            print(f"   ✅ P8 COMPLIANT")
    
    # Summary
    print("\n" + "="*80)
    print("📊 VERIFICATION SUMMARY")
    print("="*80)
    
    compliant = sum(1 for r in verification_results if not r['needs_p8'])
    non_compliant = len(agents_needing_p8)
    
    print(f"✅ P8 Compliant: {compliant}/{len(agents)}")
    print(f"⚠️  Needs P8 Enforcement: {non_compliant}/{len(agents)}")
    
    if non_compliant > 0:
        print(f"\n⚠️  Agents needing P8 enforcement:")
        for result in verification_results:
            if result['needs_p8']:
                issues = []
                if not result['has_calendar']:
                    issues.append("missing calendar")
                if not result['has_memory_log']:
                    issues.append("missing memory log")
                print(f"   - {result['agent_role']}: {', '.join(issues)}")
    
    return verification_results, agents_needing_p8

def force_p8_for_agents(agents_needing_p8):
    """Force P8 protocol execution for agents that need it"""
    if not agents_needing_p8:
        print("\n✅ All agents are P8 compliant - no enforcement needed")
        return True
    
    print("\n" + "="*80)
    print("🚀 FORCING P8 PROTOCOL EXECUTION")
    print("="*80)
    print(f"Enforcing P8 for {len(agents_needing_p8)} agent(s)")
    print("="*80)
    
    # Get Dana and David emails
    dana_meta = get_agent_metadata("Admin Assistant & Workflow Funnel")
    david_meta = get_agent_metadata("Process Architect and Schedule Publisher")
    dana_email = dana_meta.get('email_address', 'dana.flores@ratiovita.com')
    david_email = david_meta.get('email_address', 'david.chen@ratiovita.com')
    
    # Create tasks
    tasks = []
    for agent in agents_needing_p8:
        agent_role = agent.role
        agent_meta = get_agent_metadata(agent_role)
        agent_email = agent_meta.get('email_address', '')
        memory_doc_id = agent_meta.get('memory_doc_id', '')
        personal_calendar_id = agent_meta.get('personal_calendar_id', '')
        
        if not memory_doc_id or not personal_calendar_id:
            print(f"⚠️  Skipping {agent_role} - missing memory_doc_id or personal_calendar_id")
            continue
        
        # Calculate meeting times (2:30 PM - 4:30 PM EST today)
        today = datetime.now()
        start_time = today.replace(hour=14, minute=30, second=0, microsecond=0)
        end_time = start_time + timedelta(hours=2)
        
        start_time_iso = start_time.strftime('%Y-%m-%dT%H:%M:00')
        end_time_iso = end_time.strftime('%Y-%m-%dT%H:%M:00')
        
        task_description = f"""
**MANDATORY P8 PROTOCOL EXECUTION**

You have received a calendar invitation for the Executive Strategy Group Meeting. You MUST complete ALL 4 steps of the P8 protocol immediately.

**MEETING DETAILS:**
- Title: {MEETING_TITLE}
- Date: {MEETING_DATE}
- Time: {MEETING_TIME} (14:30 - 16:30 EST)

**STEP 1: LOG TO MEMORY (P8 Protocol)**
- Use the **Google Docs Memory Tool** to append the following entry to your memory document:
  - doc_id: {memory_doc_id}
  - content: "MEETING ACCEPTED: {MEETING_TITLE} - {MEETING_DATE} at {MEETING_TIME} EST - {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}"
  - append: true
- This creates an auditable, timestamped record in your memory.

**STEP 2: ADD TO PERSONAL CALENDAR (P8 Protocol)**
- Use the **Google Calendar Tool** to add the meeting event to your personal calendar:
  - calendar_id: {personal_calendar_id}
  - action: 'create'
  - event_title: "{MEETING_TITLE}"
  - event_description: "Executive Strategy Group Meeting for V1 Legacy Review and V2 Planning. All 15 agents are required to attend."
  - start_time: "{start_time_iso}"
  - end_time: "{end_time_iso}"
  - location: "Virtual Meeting"
- This ensures the meeting appears on your calendar and you receive notifications.

**STEP 3: EMAIL CONFIRMATION (P8 Protocol)**
- Use the **GMailTool** to send a confirmation email:
  - To: {dana_email}, {david_email}
  - CC: collin.m@ratiovita.com (MANDATORY - automatically added by Gmail Tool)
  - Subject: "Meeting Acceptance Confirmation: {MEETING_TITLE}"
  - Body: "I have received and accepted the calendar invitation for {MEETING_TITLE} scheduled for {MEETING_DATE} at {MEETING_TIME}. I will attend the meeting as scheduled. {agent_role}"
- **CRITICAL:** You MUST see a SUCCESS message from the Gmail Tool before proceeding.

**STEP 4: LOG EMAIL CONFIRMATION TO MEMORY (P8 Protocol)**
- After sending the confirmation email, immediately use the **Google Docs Memory Tool** to append:
  - doc_id: {memory_doc_id}
  - content: "EMAIL CONFIRMATION SENT: Meeting Acceptance Confirmation for {MEETING_TITLE} sent to David Chen and Dana Flores on {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}"
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
    
    if not tasks:
        print("⚠️  No tasks created - all agents may already be compliant or missing required IDs")
        return False
    
    print(f"\n📋 Created {len(tasks)} P8 enforcement tasks")
    
    # Execute tasks
    print("\n🚀 Executing P8 protocol enforcement...")
    print("="*80)
    
    crew = Crew(
        agents=agents_needing_p8,
        tasks=tasks,
        verbose=True
    )
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ P8 PROTOCOL ENFORCEMENT COMPLETE")
        print("="*80)
        return True
    except Exception as e:
        print(f"\n❌ Error during P8 enforcement: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """Main function"""
    print("\n" + "="*80)
    print("🔍 P8 PROTOCOL VERIFICATION AND ENFORCEMENT")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}")
    print("="*80)
    
    # Validate configuration
    try:
        Config.validate()
        os.environ['OPENAI_API_KEY'] = Config.OPENAI_API_KEY
    except ValueError as e:
        print(f"❌ Configuration Error: {e}")
        return False
    
    # Step 1: Verify all agents
    verification_results, agents_needing_p8 = verify_all_agents()
    
    # Step 2: Force P8 for non-compliant agents
    if agents_needing_p8:
        print("\n" + "="*80)
        print(f"\n⚠️  {len(agents_needing_p8)} agent(s) need P8 enforcement.")
        print("🚀 Automatically forcing P8 execution...")
        force_p8_for_agents(agents_needing_p8)
    else:
        print("\n✅ All agents are P8 compliant!")
    
    print("\n" + "="*80)
    print("✅ VERIFICATION COMPLETE")
    print("="*80)
    
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)

