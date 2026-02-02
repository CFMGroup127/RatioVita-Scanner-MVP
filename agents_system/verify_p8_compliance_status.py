"""
Verify P8 Compliance Status for All Agents
This script checks which agents have completed P8 protocol steps.
"""
import os
import sys
from datetime import datetime
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from main import load_agents_from_yaml, get_agent_metadata

# Meeting details
MEETING_TITLE = "Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning"
MEETING_DATE = datetime.now().strftime('%B %d, %Y')
MEETING_TIME = "2:30 PM - 4:30 PM EST"

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

def check_personal_calendar(calendar_service, personal_calendar_id):
    """Check if meeting exists in agent's personal calendar"""
    if not calendar_service or not personal_calendar_id:
        return {'found': False, 'error': 'No service or ID'}
    
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
        
        content = ''
        if 'body' in doc and 'content' in doc['body']:
            for element in doc['body']['content']:
                if 'paragraph' in element:
                    for para_element in element['paragraph'].get('elements', []):
                        if 'textRun' in para_element:
                            content += para_element['textRun'].get('content', '')
        
        has_acceptance = 'MEETING ACCEPTED' in content or 'MEETING ACCEPTANCE' in content
        has_email_log = 'EMAIL CONFIRMATION SENT' in content
        
        return {
            'found': has_acceptance or has_email_log,
            'has_acceptance': has_acceptance,
            'has_email_log': has_email_log,
            'content_preview': content[:300] if content else ''
        }
    except Exception as e:
        return {'found': False, 'error': str(e)}

def check_meeting_transcript():
    """Check if meeting transcript has any content (indicates meeting is active)"""
    try:
        dana_meta = get_agent_metadata("Admin Assistant & Workflow Funnel")
        transcript_doc_id = dana_meta.get('meeting_transcript_doc_id', '')
        
        if not transcript_doc_id:
            return {'found': False, 'error': 'No transcript doc ID'}
        
        creds = None
        if os.path.exists('token.json'):
            try:
                creds = Credentials.from_authorized_user_file('token.json', [
                    'https://www.googleapis.com/auth/documents.readonly'
                ])
            except:
                try:
                    creds = Credentials.from_authorized_user_file('token.json', None)
                except:
                    return {'found': False, 'error': 'Could not load credentials'}
            
            if not creds.valid:
                if creds.expired and creds.refresh_token:
                    try:
                        creds.refresh(Request())
                    except:
                        pass
        
        if creds:
            docs_service = build('docs', 'v1', credentials=creds)
            doc = docs_service.documents().get(documentId=transcript_doc_id).execute()
            
            content = ''
            if 'body' in doc and 'content' in doc['body']:
                for element in doc['body']['content']:
                    if 'paragraph' in element:
                        for para_element in element['paragraph'].get('elements', []):
                            if 'textRun' in para_element:
                                content += para_element['textRun'].get('content', '')
            
            has_content = len(content.strip()) > 0
            return {
                'found': has_content,
                'content_length': len(content),
                'preview': content[:200] if content else ''
            }
        
        return {'found': False, 'error': 'Could not get credentials'}
    except Exception as e:
        return {'found': False, 'error': str(e)}

def main():
    """Main verification function"""
    print("\n" + "="*80)
    print("🔍 P8 COMPLIANCE VERIFICATION")
    print("="*80)
    print(f"Meeting: {MEETING_TITLE}")
    print(f"Date: {MEETING_DATE}")
    print(f"Time: {MEETING_TIME}")
    print(f"Current Time: {datetime.now().strftime('%B %d, %Y %I:%M:%S %p EST')}")
    print("="*80)
    
    # Get services
    calendar_service = get_calendar_service()
    if not calendar_service:
        print("⚠️  Could not get calendar service - calendar checks will be skipped")
    
    # Load agents
    agents = load_agents_from_yaml('agents.yaml')
    
    print(f"\n📋 Checking {len(agents)} agents...")
    print("="*80)
    
    results = []
    compliant_count = 0
    partial_count = 0
    
    for agent in agents:
        agent_role = agent.role
        agent_meta = get_agent_metadata(agent_role)
        agent_email = agent_meta.get('email_address', '')
        memory_doc_id = agent_meta.get('memory_doc_id', '')
        personal_calendar_id = agent_meta.get('personal_calendar_id', '')
        
        print(f"\n👤 {agent_role}")
        print(f"   Email: {agent_email}")
        
        # Check personal calendar
        calendar_status = check_personal_calendar(calendar_service, personal_calendar_id)
        has_calendar = calendar_status.get('found', False)
        
        if has_calendar:
            print(f"   ✅ Meeting in personal calendar")
        else:
            print(f"   ❌ Meeting NOT in personal calendar")
            if 'error' in calendar_status:
                print(f"      Error: {calendar_status['error']}")
        
        # Check memory
        memory_status = check_memory_for_p8(memory_doc_id)
        has_memory_acceptance = memory_status.get('has_acceptance', False)
        has_memory_email_log = memory_status.get('has_email_log', False)
        
        if has_memory_acceptance:
            print(f"   ✅ Meeting acceptance logged in memory")
        else:
            print(f"   ❌ Meeting acceptance NOT logged in memory")
        
        if has_memory_email_log:
            print(f"   ✅ Email confirmation logged in memory")
        else:
            print(f"   ❌ Email confirmation NOT logged in memory")
        
        if 'error' in memory_status:
            print(f"      Error: {memory_status['error']}")
        
        # Determine compliance
        is_compliant = has_calendar and has_memory_acceptance and has_memory_email_log
        is_partial = has_calendar or has_memory_acceptance or has_memory_email_log
        
        if is_compliant:
            compliant_count += 1
            print(f"   ✅ FULLY COMPLIANT")
        elif is_partial:
            partial_count += 1
            print(f"   ⚠️  PARTIALLY COMPLIANT")
        else:
            print(f"   ❌ NOT COMPLIANT")
        
        results.append({
            'agent_role': agent_role,
            'agent_email': agent_email,
            'has_calendar': has_calendar,
            'has_memory_acceptance': has_memory_acceptance,
            'has_memory_email_log': has_memory_email_log,
            'is_compliant': is_compliant,
            'is_partial': is_partial
        })
    
    # Check meeting transcript
    print(f"\n" + "="*80)
    print("📝 MEETING TRANSCRIPT STATUS")
    print("="*80)
    transcript_status = check_meeting_transcript()
    if transcript_status.get('found', False):
        print(f"✅ Meeting transcript has content ({transcript_status.get('content_length', 0)} characters)")
        print(f"   Preview: {transcript_status.get('preview', '')[:100]}...")
        print(f"   → Meeting appears to be ACTIVE")
    else:
        print(f"❌ Meeting transcript is empty or not accessible")
        if 'error' in transcript_status:
            print(f"   Error: {transcript_status['error']}")
        print(f"   → Meeting may not have started or Dana is not taking notes")
    
    # Summary
    print(f"\n" + "="*80)
    print("📊 COMPLIANCE SUMMARY")
    print("="*80)
    print(f"Total Agents: {len(agents)}")
    print(f"✅ Fully Compliant: {compliant_count}/{len(agents)} ({compliant_count*100//len(agents) if len(agents) > 0 else 0}%)")
    print(f"⚠️  Partially Compliant: {partial_count}/{len(agents)} ({partial_count*100//len(agents) if len(agents) > 0 else 0}%)")
    print(f"❌ Not Compliant: {len(agents) - compliant_count - partial_count}/{len(agents)}")
    print("="*80)
    
    # Non-compliant agents
    non_compliant = [r for r in results if not r['is_compliant'] and not r['is_partial']]
    if non_compliant:
        print(f"\n❌ NON-COMPLIANT AGENTS ({len(non_compliant)}):")
        for r in non_compliant:
            issues = []
            if not r['has_calendar']:
                issues.append("no calendar")
            if not r['has_memory_acceptance']:
                issues.append("no memory log")
            if not r['has_memory_email_log']:
                issues.append("no email log")
            print(f"   - {r['agent_role']}: {', '.join(issues)}")
    
    # Partially compliant agents
    partial = [r for r in results if r['is_partial'] and not r['is_compliant']]
    if partial:
        print(f"\n⚠️  PARTIALLY COMPLIANT AGENTS ({len(partial)}):")
        for r in partial:
            completed = []
            if r['has_calendar']:
                completed.append("calendar")
            if r['has_memory_acceptance']:
                completed.append("memory log")
            if r['has_memory_email_log']:
                completed.append("email log")
            missing = []
            if not r['has_calendar']:
                missing.append("calendar")
            if not r['has_memory_acceptance']:
                missing.append("memory log")
            if not r['has_memory_email_log']:
                missing.append("email log")
            print(f"   - {r['agent_role']}: ✅ {', '.join(completed)} | ❌ {', '.join(missing)}")
    
    print("\n" + "="*80)
    print("✅ VERIFICATION COMPLETE")
    print("="*80)
    
    return results

if __name__ == "__main__":
    main()

