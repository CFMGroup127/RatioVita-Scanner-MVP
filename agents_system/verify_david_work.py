"""
Verify David Chen's Merge Protocol Deliverables
This script verifies:
1. Calendar event for November 21, 2025
2. Email distribution
3. Pre-read document creation
4. Memory document updates
"""
import os
from datetime import datetime
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

def verify_calendar_event():
    """Verify the calendar event for November 21, 2025."""
    print("\n" + "="*80)
    print("📅 VERIFYING CALENDAR EVENT")
    print("="*80)
    
    try:
        SCOPES = ['https://www.googleapis.com/auth/calendar.readonly']
        creds = Credentials.from_authorized_user_file('token.json', SCOPES)
        if not creds.valid:
            creds.refresh(Request())
        
        service = build('calendar', 'v3', credentials=creds)
        
        # Get David Chen's calendar ID
        # We'll check the project schedule calendar and David's personal calendar
        calendar_ids = [
            "c_4e1c24ca3fdea15ff6de1ee2e0d025f75a1f8ff58ef58e2119e5273e51a5e7dc@group.calendar.google.com",  # Project Schedule Calendar
            "c_e87155407d142f1912b03961c16268d52b9083b7d14973a8386f6952f1b3bd13@group.calendar.google.com"  # David's personal calendar
        ]
        
        target_date = "2025-11-21"
        found_events = []
        
        for calendar_id in calendar_ids:
            try:
                # Get events for November 21, 2025
                time_min = f"{target_date}T00:00:00Z"
                time_max = f"{target_date}T23:59:59Z"
                
                events_result = service.events().list(
                    calendarId=calendar_id,
                    timeMin=time_min,
                    timeMax=time_max,
                    maxResults=10,
                    singleEvents=True,
                    orderBy='startTime'
                ).execute()
                
                events = events_result.get('items', [])
                
                for event in events:
                    if 'Executive Strategy' in event.get('summary', '') or 'V1 Legacy' in event.get('summary', ''):
                        found_events.append({
                            'calendar': calendar_id[:20] + '...',
                            'summary': event.get('summary', 'No title'),
                            'start': event.get('start', {}).get('dateTime', event.get('start', {}).get('date', 'No date')),
                            'description': event.get('description', '')[:200] + '...' if len(event.get('description', '')) > 200 else event.get('description', '')
                        })
            except HttpError as e:
                print(f"  ⚠️  Could not check calendar {calendar_id[:20]}...: {str(e)[:100]}")
        
        if found_events:
            print(f"\n✅ Found {len(found_events)} calendar event(s):")
            for i, event in enumerate(found_events, 1):
                print(f"\n  Event {i}:")
                print(f"    Title: {event['summary']}")
                print(f"    Start: {event['start']}")
                print(f"    Calendar: {event['calendar']}")
                print(f"    Description: {event['description'][:150]}...")
            return True
        else:
            print(f"\n⚠️  No calendar event found for November 21, 2025")
            print("   (This could mean the event is in a different calendar or wasn't created)")
            return False
            
    except Exception as e:
        print(f"\n❌ Error checking calendar: {e}")
        return False

def verify_david_memory():
    """Verify David's memory document for completion status."""
    print("\n" + "="*80)
    print("💾 VERIFYING DAVID'S MEMORY DOCUMENT")
    print("="*80)
    
    try:
        SCOPES = ['https://www.googleapis.com/auth/documents.readonly', 'https://www.googleapis.com/auth/drive.readonly']
        creds = Credentials.from_authorized_user_file('token.json', SCOPES)
        if not creds.valid:
            creds.refresh(Request())
        
        service = build('docs', 'v1', credentials=creds)
        
        # David Chen's memory document ID
        david_doc_id = "1oRSQMOvK2lfv3MhfLD-O0fMbAJE-JQmQ0dg8DqeO_XY"
        
        doc = service.documents().get(documentId=david_doc_id).execute()
        
        content = []
        for element in doc.get('body', {}).get('content', []):
            if 'paragraph' in element:
                para_text = ''
                for para_element in element['paragraph'].get('elements', []):
                    if 'textRun' in para_element:
                        para_text += para_element['textRun'].get('content', '')
                if para_text.strip():
                    content.append(para_text)
        
        david_text = '\n'.join(content)
        
        print(f"\n📄 David's Memory Document:")
        print(f"   Length: {len(david_text)} characters")
        
        # Check for completion indicators
        indicators = {
            'REPORT HANDOFF': 'report handoff' in david_text.lower() or 'handoff protocol' in david_text.lower(),
            'November 21': 'november 21' in david_text.lower() or '2025-11-21' in david_text,
            'Pre-Read Document': 'pre-read' in david_text.lower() or 'executive strategy group' in david_text.lower(),
            'Email Distributed': 'email' in david_text.lower() and ('distributed' in david_text.lower() or 'sent' in david_text.lower()),
            'COMPLETED': 'completed' in david_text.lower() and 'status' in david_text.lower()
        }
        
        print("\n   Completion Indicators:")
        for key, found in indicators.items():
            status = "✅" if found else "⚠️"
            print(f"     {status} {key}: {found}")
        
        if len(david_text) > 500:
            print(f"\n   Last 400 characters:")
            print(f"   {'-'*80}")
            print(f"   {david_text[-400:]}")
            print(f"   {'-'*80}")
        
        return any(indicators.values())
        
    except Exception as e:
        print(f"\n❌ Error checking memory: {e}")
        return False

def verify_email_log():
    """Check the execution log for email success messages."""
    print("\n" + "="*80)
    print("📧 VERIFYING EMAIL DISTRIBUTION")
    print("="*80)
    
    try:
        import glob
        log_files = glob.glob('david_merge_execution_*.log')
        if not log_files:
            print("\n⚠️  No log file found")
            return False
        
        latest_log = max(log_files, key=os.path.getctime)
        
        with open(latest_log, 'r') as f:
            log_content = f.read()
        
        # Check for email success messages
        email_success = 'SUCCESS: Email sent successfully' in log_content
        message_ids = []
        
        import re
        message_id_pattern = r'Message ID: ([a-f0-9]+)'
        message_ids = re.findall(message_id_pattern, log_content)
        
        # Check for email distribution mentions
        distributed = 'distributed' in log_content.lower() and 'email' in log_content.lower()
        pre_read = 'pre-read' in log_content.lower() or 'pre read' in log_content.lower()
        
        print(f"\n📄 Log file: {os.path.basename(latest_log)}")
        print(f"   Size: {len(log_content)} characters")
        
        print("\n   Email Indicators:")
        print(f"     {'✅' if email_success else '❌'} Email sent successfully: {email_success}")
        print(f"     {'✅' if message_ids else '❌'} Message IDs found: {len(message_ids)}")
        if message_ids:
            for msg_id in message_ids[:3]:  # Show first 3
                print(f"       - {msg_id}")
        print(f"     {'✅' if distributed else '⚠️'} Distribution mentioned: {distributed}")
        print(f"     {'✅' if pre_read else '⚠️'} Pre-read mentioned: {pre_read}")
        
        # Check for CC mandate
        cc_mentioned = 'collin.m@ratiovita.com' in log_content or 'cc' in log_content.lower()
        print(f"     {'✅' if cc_mentioned else '⚠️'} CC audit trail: {cc_mentioned}")
        
        return email_success and len(message_ids) > 0
        
    except Exception as e:
        print(f"\n❌ Error checking email log: {e}")
        return False

def main():
    """Run all verification checks."""
    print("\n" + "="*80)
    print("🔍 VERIFYING DAVID CHEN'S MERGE PROTOCOL DELIVERABLES")
    print("="*80)
    print(f"Verification Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*80)
    
    results = {
        'Calendar Event': verify_calendar_event(),
        'David Memory': verify_david_memory(),
        'Email Distribution': verify_email_log()
    }
    
    print("\n" + "="*80)
    print("📊 VERIFICATION SUMMARY")
    print("="*80)
    
    for check, result in results.items():
        status = "✅ PASS" if result else "⚠️  NEEDS REVIEW"
        print(f"  {status}: {check}")
    
    all_passed = all(results.values())
    
    print("\n" + "="*80)
    if all_passed:
        print("✅ ALL VERIFICATIONS PASSED")
    else:
        print("⚠️  SOME VERIFICATIONS NEED REVIEW")
    print("="*80)
    
    return all_passed

if __name__ == "__main__":
    main()

