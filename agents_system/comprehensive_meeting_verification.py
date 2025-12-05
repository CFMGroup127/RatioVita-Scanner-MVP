"""
Comprehensive Meeting Verification
This script verifies all aspects of the meeting completion.
"""
import os
from datetime import datetime
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from main import load_agents_from_yaml, get_agent_metadata

def get_credentials():
    """Get credentials"""
    creds = None
    if os.path.exists('token.json'):
        try:
            creds = Credentials.from_authorized_user_file('token.json', [
                'https://www.googleapis.com/auth/documents.readonly',
                'https://www.googleapis.com/auth/calendar.readonly'
            ])
        except:
            try:
                creds = Credentials.from_authorized_user_file('token.json', None)
            except:
                pass
        
        if creds and not creds.valid and creds.expired and creds.refresh_token:
            try:
                creds.refresh(Request())
            except:
                pass
    
    return creds

def verify_meeting_transcript():
    """Verify meeting transcript"""
    print("\n" + "="*80)
    print("📝 VERIFYING MEETING TRANSCRIPT")
    print("="*80)
    
    dana_meta = get_agent_metadata('Admin Assistant & Workflow Funnel')
    transcript_id = dana_meta.get('meeting_transcript_doc_id', '')
    
    if not transcript_id:
        print("❌ No transcript document ID found")
        return {'found': False}
    
    creds = get_credentials()
    if not creds:
        print("❌ Could not get credentials")
        return {'found': False, 'error': 'No credentials'}
    
    try:
        docs_service = build('docs', 'v1', credentials=creds)
        doc = docs_service.documents().get(documentId=transcript_id).execute()
        
        content = ''
        if 'body' in doc and 'content' in doc['body']:
            for element in doc['body']['content']:
                if 'paragraph' in element:
                    for para in element['paragraph'].get('elements', []):
                        if 'textRun' in para:
                            content += para['textRun'].get('content', '')
        
        if content.strip():
            print(f"✅ Transcript exists and has content")
            print(f"   Length: {len(content)} characters")
            print(f"   Preview (first 300 chars): {content[:300]}")
            print(f"   Preview (last 300 chars): {content[-300:]}")
            return {'found': True, 'length': len(content), 'content': content}
        else:
            print(f"⚠️  Transcript exists but is empty")
            return {'found': False, 'empty': True}
    except Exception as e:
        print(f"❌ Error reading transcript: {e}")
        return {'found': False, 'error': str(e)}

def verify_agent_p8_compliance():
    """Verify P8 compliance for all agents"""
    print("\n" + "="*80)
    print("✅ VERIFYING P8 PROTOCOL COMPLIANCE")
    print("="*80)
    
    agents = load_agents_from_yaml('agents.yaml')
    creds = get_credentials()
    
    compliant = 0
    partial = 0
    non_compliant = 0
    
    results = []
    
    for agent in agents:
        agent_role = agent.role
        agent_meta = get_agent_metadata(agent_role)
        memory_doc_id = agent_meta.get('memory_doc_id', '')
        
        if not memory_doc_id:
            non_compliant += 1
            results.append({'agent': agent_role, 'status': 'non-compliant', 'reason': 'No memory doc ID'})
            continue
        
        try:
            docs_service = build('docs', 'v1', credentials=creds)
            doc = docs_service.documents().get(documentId=memory_doc_id).execute()
            
            content = ''
            if 'body' in doc and 'content' in doc['body']:
                for element in doc['body']['content']:
                    if 'paragraph' in element:
                        for para in element['paragraph'].get('elements', []):
                            if 'textRun' in para:
                                content += para['textRun'].get('content', '')
            
            has_acceptance = 'MEETING ACCEPTED' in content or 'MEETING ACCEPTANCE' in content
            has_email_log = 'EMAIL CONFIRMATION SENT' in content
            has_meeting_content = 'Executive Strategy Group Meeting' in content or 'V1 Legacy Review' in content
            
            if has_acceptance and has_email_log:
                compliant += 1
                results.append({'agent': agent_role, 'status': 'compliant', 'has_acceptance': True, 'has_email_log': True})
            elif has_acceptance or has_email_log or has_meeting_content:
                partial += 1
                results.append({'agent': agent_role, 'status': 'partial', 'has_acceptance': has_acceptance, 'has_email_log': has_email_log, 'has_meeting_content': has_meeting_content})
            else:
                non_compliant += 1
                results.append({'agent': agent_role, 'status': 'non-compliant', 'reason': 'No P8 indicators found'})
        except Exception as e:
            non_compliant += 1
            results.append({'agent': agent_role, 'status': 'error', 'error': str(e)})
    
    print(f"\n📊 P8 Compliance Summary:")
    print(f"   ✅ Fully Compliant: {compliant}/{len(agents)} ({compliant*100//len(agents) if len(agents) > 0 else 0}%)")
    print(f"   ⚠️  Partially Compliant: {partial}/{len(agents)} ({partial*100//len(agents) if len(agents) > 0 else 0}%)")
    print(f"   ❌ Non-Compliant: {non_compliant}/{len(agents)}")
    
    if compliant > 0:
        print(f"\n✅ Compliant Agents ({compliant}):")
        for r in results:
            if r['status'] == 'compliant':
                print(f"   - {r['agent']}")
    
    return {'compliant': compliant, 'partial': partial, 'non_compliant': non_compliant, 'results': results}

def verify_meeting_calendar_event():
    """Verify meeting calendar event"""
    print("\n" + "="*80)
    print("📅 VERIFYING MEETING CALENDAR EVENT")
    print("="*80)
    
    PROJECT_CALENDAR_ID = "c_4e1c24ca3fdea15ff6de1ee2e0d025f75a1f8ff58ef58e2119e5273e51a5e7dc@group.calendar.google.com"
    
    creds = get_credentials()
    if not creds:
        print("❌ Could not get credentials")
        return {'found': False}
    
    try:
        calendar_service = build('calendar', 'v3', credentials=creds)
        
        # Check for today's events
        from datetime import datetime, timedelta
        today = datetime.now()
        start_of_day = today.replace(hour=0, minute=0, second=0, microsecond=0)
        end_of_day = today.replace(hour=23, minute=59, second=59, microsecond=0)
        
        time_min = start_of_day.isoformat() + 'Z'
        time_max = end_of_day.isoformat() + 'Z'
        
        events_result = calendar_service.events().list(
            calendarId=PROJECT_CALENDAR_ID,
            timeMin=time_min,
            timeMax=time_max,
            maxResults=20,
            singleEvents=True,
            orderBy='startTime'
        ).execute()
        
        events = events_result.get('items', [])
        
        meeting_found = False
        for event in events:
            event_title = event.get('summary', '')
            if 'Executive Strategy Group' in event_title or 'V1 Legacy Review' in event_title:
                meeting_found = True
                start_time = event.get('start', {}).get('dateTime', '')
                end_time = event.get('end', {}).get('dateTime', '')
                attendees = event.get('attendees', [])
                
                print(f"✅ Meeting event found")
                print(f"   Title: {event_title}")
                print(f"   Start: {start_time}")
                print(f"   End: {end_time}")
                print(f"   Attendees: {len(attendees)}")
                return {'found': True, 'event': event}
        
        if not meeting_found:
            print(f"⚠️  No meeting event found for today")
            return {'found': False}
    except Exception as e:
        print(f"❌ Error checking calendar: {e}")
        return {'found': False, 'error': str(e)}

def main():
    """Main verification function"""
    print("\n" + "="*80)
    print("🔍 COMPREHENSIVE MEETING VERIFICATION")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y')}")
    print(f"Time: {datetime.now().strftime('%I:%M:%S %p EST')}")
    print("="*80)
    
    # Verify transcript
    transcript_status = verify_meeting_transcript()
    
    # Verify P8 compliance
    p8_status = verify_agent_p8_compliance()
    
    # Verify calendar event
    calendar_status = verify_meeting_calendar_event()
    
    # Final summary
    print("\n" + "="*80)
    print("📊 VERIFICATION SUMMARY")
    print("="*80)
    print(f"Meeting Transcript: {'✅ Found' if transcript_status.get('found') else '❌ Not Found'}")
    print(f"P8 Compliance: {p8_status['compliant']}/15 fully compliant ({p8_status['compliant']*100//15 if 15 > 0 else 0}%)")
    print(f"Calendar Event: {'✅ Found' if calendar_status.get('found') else '❌ Not Found'}")
    print("="*80)
    
    # Overall status
    all_good = (
        transcript_status.get('found', False) and
        p8_status['compliant'] >= 10 and
        calendar_status.get('found', False)
    )
    
    if all_good:
        print("\n✅ OVERALL STATUS: MEETING SUCCESSFULLY COMPLETED")
        print("   - Transcript maintained")
        print("   - High P8 compliance")
        print("   - Calendar event created")
    else:
        print("\n⚠️  OVERALL STATUS: SOME ISSUES DETECTED")
        if not transcript_status.get('found'):
            print("   - Transcript issue")
        if p8_status['compliant'] < 10:
            print("   - Low P8 compliance")
        if not calendar_status.get('found'):
            print("   - Calendar event issue")
    
    print("="*80)
    
    return {
        'transcript': transcript_status,
        'p8': p8_status,
        'calendar': calendar_status
    }

if __name__ == "__main__":
    main()

