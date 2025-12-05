"""
Monitor P8 Enforcement Process
This script monitors the running P8 enforcement processes and provides status updates.
"""
import os
import sys
import time
import subprocess
from datetime import datetime
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from main import load_agents_from_yaml, get_agent_metadata

# Meeting details
MEETING_TITLE = "Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning"
MEETING_DATE = datetime.now().strftime('%B %d, %Y')
MEETING_TIME = "2:30 PM - 4:30 PM EST"

def check_processes():
    """Check if P8 enforcement processes are still running"""
    try:
        result = subprocess.run(
            ['ps', 'aux'],
            capture_output=True,
            text=True
        )
        
        processes = []
        for line in result.stdout.split('\n'):
            if 'force_meeting_acknowledgment.py' in line and 'grep' not in line:
                parts = line.split()
                if len(parts) > 1:
                    pid = parts[1]
                    cpu = parts[2]
                    mem = parts[3]
                    time_str = ' '.join(parts[8:11]) if len(parts) > 10 else 'N/A'
                    processes.append({
                        'pid': pid,
                        'cpu': cpu,
                        'mem': mem,
                        'time': time_str
                    })
        
        return processes
    except Exception as e:
        return []

def check_personal_calendar(calendar_service, personal_calendar_id):
    """Check if meeting exists in agent's personal calendar"""
    if not calendar_service or not personal_calendar_id:
        return False
    
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
                return True
        
        return False
    except Exception as e:
        return False

def check_memory_for_p8(memory_doc_id):
    """Check memory document for P8 acceptance log"""
    if not memory_doc_id:
        return False
    
    try:
        creds = None
        if os.path.exists('token.json'):
            try:
                creds = Credentials.from_authorized_user_file('token.json', [
                    'https://www.googleapis.com/auth/documents.readonly'
                ])
            except:
                try:
                    creds = Credentials.from_authorized_user_file('token.json', None)
                    if creds.scopes:
                        has_docs = any('documents' in s or 'drive' in s for s in creds.scopes)
                        if not has_docs:
                            return False
                except:
                    return False
            
            if not creds.valid:
                if creds.expired and creds.refresh_token:
                    try:
                        creds.refresh(Request())
                    except:
                        return False
        
        if not creds:
            return False
        
        docs_service = build('docs', 'v1', credentials=creds)
        doc = docs_service.documents().get(documentId=memory_doc_id).execute()
        
        content = ''
        if 'body' in doc and 'content' in doc['body']:
            for element in doc['body']['content']:
                if 'paragraph' in element:
                    for para_element in element['paragraph'].get('elements', []):
                        if 'textRun' in para_element:
                            content += para_element['textRun'].get('content', '')
        
        return 'MEETING ACCEPTED' in content or 'MEETING ACCEPTANCE' in content
    except Exception as e:
        return False

def get_calendar_service():
    """Get calendar service"""
    creds = None
    if os.path.exists('token.json'):
        try:
            creds = Credentials.from_authorized_user_file('token.json', [
                'https://www.googleapis.com/auth/calendar',
                'https://www.googleapis.com/auth/documents.readonly'
            ])
        except:
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
                    return None
    
    if creds:
        return build('calendar', 'v3', credentials=creds)
    return None

def verify_compliance():
    """Verify P8 compliance for all agents"""
    print("\n" + "="*80)
    print("🔍 VERIFYING P8 COMPLIANCE")
    print("="*80)
    
    calendar_service = get_calendar_service()
    if not calendar_service:
        print("⚠️  Could not get calendar service - skipping calendar verification")
    
    agents = load_agents_from_yaml('agents.yaml')
    
    compliant_calendar = 0
    compliant_memory = 0
    total_agents = 0
    
    print(f"\n📋 Checking {len(agents)} agents...")
    
    for agent in agents:
        agent_role = agent.role
        agent_meta = get_agent_metadata(agent_role)
        memory_doc_id = agent_meta.get('memory_doc_id', '')
        personal_calendar_id = agent_meta.get('personal_calendar_id', '')
        
        total_agents += 1
        
        # Check calendar
        has_calendar = False
        if calendar_service and personal_calendar_id:
            has_calendar = check_personal_calendar(calendar_service, personal_calendar_id)
            if has_calendar:
                compliant_calendar += 1
        
        # Check memory
        has_memory = False
        if memory_doc_id:
            has_memory = check_memory_for_p8(memory_doc_id)
            if has_memory:
                compliant_memory += 1
        
        status = "✅" if (has_calendar and has_memory) else "⚠️"
        print(f"{status} {agent_role[:50]}")
        if has_calendar:
            print(f"   ✅ Calendar")
        else:
            print(f"   ❌ Calendar")
        if has_memory:
            print(f"   ✅ Memory")
        else:
            print(f"   ❌ Memory")
    
    print("\n" + "="*80)
    print("📊 COMPLIANCE SUMMARY")
    print("="*80)
    print(f"Total Agents: {total_agents}")
    print(f"Calendar Compliance: {compliant_calendar}/{total_agents} ({compliant_calendar*100//total_agents if total_agents > 0 else 0}%)")
    print(f"Memory Compliance: {compliant_memory}/{total_agents} ({compliant_memory*100//total_agents if total_agents > 0 else 0}%)")
    print(f"Full Compliance: {min(compliant_calendar, compliant_memory)}/{total_agents} ({min(compliant_calendar, compliant_memory)*100//total_agents if total_agents > 0 else 0}%)")
    print("="*80)

def monitor_loop(update_interval=120):
    """Monitor processes and provide updates"""
    print("\n" + "="*80)
    print("📊 P8 ENFORCEMENT MONITOR")
    print("="*80)
    print(f"Meeting: {MEETING_TITLE}")
    print(f"Date: {MEETING_DATE}")
    print(f"Time: {MEETING_TIME}")
    print(f"Update Interval: {update_interval} seconds ({update_interval//60} minutes)")
    print("="*80)
    
    iteration = 0
    
    while True:
        iteration += 1
        current_time = datetime.now()
        meeting_start = current_time.replace(hour=14, minute=30, second=0)
        time_until_meeting = meeting_start - current_time
        
        print(f"\n{'='*80}")
        print(f"📅 UPDATE #{iteration} - {current_time.strftime('%B %d, %Y %I:%M:%S %p EST')}")
        print(f"{'='*80}")
        
        # Check processes
        processes = check_processes()
        
        if processes:
            print(f"\n🔄 RUNNING PROCESSES: {len(processes)}")
            for proc in processes:
                print(f"   PID: {proc['pid']} | CPU: {proc['cpu']}% | MEM: {proc['mem']}% | TIME: {proc['time']}")
            print(f"\n⏳ P8 enforcement still in progress...")
        else:
            print(f"\n✅ NO PROCESSES RUNNING")
            print(f"   P8 enforcement appears to have completed!")
            print(f"\n🔍 Running compliance verification...")
            verify_compliance()
            print(f"\n✅ Monitoring complete. All processes finished.")
            break
        
        # Time until meeting
        if time_until_meeting.total_seconds() > 0:
            minutes = int(time_until_meeting.total_seconds() // 60)
            seconds = int(time_until_meeting.total_seconds() % 60)
            print(f"\n⏰ Meeting starts in: {minutes} minutes {seconds} seconds")
        else:
            print(f"\n⏰ Meeting should have started!")
        
        # Wait for next update
        if processes:
            print(f"\n⏳ Waiting {update_interval} seconds for next update...")
            print(f"   (Press Ctrl+C to stop monitoring)")
            time.sleep(update_interval)
        else:
            break

def main():
    """Main function"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Monitor P8 enforcement processes')
    parser.add_argument('--interval', type=int, default=120, help='Update interval in seconds (default: 120)')
    parser.add_argument('--verify-only', action='store_true', help='Only verify compliance, do not monitor')
    
    args = parser.parse_args()
    
    if args.verify_only:
        verify_compliance()
    else:
        try:
            monitor_loop(args.interval)
        except KeyboardInterrupt:
            print(f"\n\n⚠️  Monitoring stopped by user")
            print(f"🔍 Running final compliance check...")
            verify_compliance()

if __name__ == "__main__":
    main()

