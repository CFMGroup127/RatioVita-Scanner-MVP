"""
Diagnose Meeting Failure
This script checks why agents failed to execute P8, P5, and transcript protocols.
"""
import os
import sys
from datetime import datetime
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from main import load_agents_from_yaml, get_agent_metadata

SCOPES = [
    'https://www.googleapis.com/auth/documents.readonly',
    'https://www.googleapis.com/auth/calendar.readonly',
    'https://www.googleapis.com/auth/gmail.readonly'
]

def get_credentials():
    """Get valid user credentials"""
    creds = None
    if os.path.exists('token.json'):
        try:
            creds = Credentials.from_authorized_user_file('token.json', SCOPES)
        except:
            try:
                creds = Credentials.from_authorized_user_file('token.json', None)
                if creds.scopes:
                    has_all = all(any(scope in s for scope in ['documents', 'calendar', 'gmail']) for s in creds.scopes)
                    if not has_all:
                        return None
            except:
                return None
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            try:
                creds.refresh(Request())
            except:
                return None
    
    return creds

def check_agent_p8_compliance(agent_role, agent_name, memory_doc_id, calendar_id, email_address):
    """Check if agent executed P8 protocol"""
    results = {
        'agent': agent_name,
        'role': agent_role,
        'p8_email_sent': False,
        'p8_calendar_added': False,
        'p8_memory_logged': False,
        'p5_meeting_notes': False,
        'transcript_exists': False,
        'issues': []
    }
    
    try:
        creds = get_credentials()
        if not creds:
            results['issues'].append("❌ No credentials available")
            return results
        
        docs_service = build('docs', 'v1', credentials=creds)
        calendar_service = build('calendar', 'v3', credentials=creds)
        gmail_service = build('gmail', 'v1', credentials=creds)
        
        # 1. Check P8 Memory Log
        try:
            doc = docs_service.documents().get(documentId=memory_doc_id).execute()
            content = ''
            if 'body' in doc and 'content' in doc['body']:
                for element in doc['body']['content']:
                    if 'paragraph' in element:
                        para = element['paragraph']
                        if 'elements' in para:
                            for elem in para['elements']:
                                if 'textRun' in elem:
                                    content += elem['textRun'].get('content', '')
            
            if 'MEETING ACCEPTED' in content.upper() or 'P8' in content.upper():
                results['p8_memory_logged'] = True
            else:
                results['issues'].append("❌ No P8 memory log found")
        except Exception as e:
            results['issues'].append(f"❌ Error reading memory doc: {str(e)}")
        
        # 2. Check Calendar Event
        try:
            # Check for events today
            now = datetime.now()
            time_min = now.replace(hour=0, minute=0, second=0, microsecond=0).isoformat() + 'Z'
            time_max = now.replace(hour=23, minute=59, second=59, microsecond=0).isoformat() + 'Z'
            
            events_result = calendar_service.events().list(
                calendarId=calendar_id,
                timeMin=time_min,
                timeMax=time_max,
                maxResults=10
            ).execute()
            
            events = events_result.get('items', [])
            if events:
                results['p8_calendar_added'] = True
            else:
                results['issues'].append("❌ No calendar events found for today")
        except Exception as e:
            results['issues'].append(f"❌ Error checking calendar: {str(e)}")
        
        # 3. Check Email Sent
        try:
            # Search for confirmation emails sent today
            query = f'from:{email_address} subject:"Meeting Acceptance Confirmation" after:{datetime.now().strftime("%Y/%m/%d")}'
            messages = gmail_service.users().messages().list(userId='me', q=query).execute()
            
            if messages.get('messages'):
                results['p8_email_sent'] = True
            else:
                results['issues'].append("❌ No confirmation email found")
        except Exception as e:
            results['issues'].append(f"❌ Error checking email: {str(e)}")
        
        # 4. Check P5 Meeting Notes
        try:
            if 'MEETING' in content.upper() and ('NOTES' in content.upper() or 'P5' in content.upper()):
                results['p5_meeting_notes'] = True
            else:
                results['issues'].append("❌ No P5 meeting notes found")
        except:
            pass
        
        # 5. Check Transcript
        try:
            if 'TRANSCRIPT' in content.upper() or 'MEETING TRANSCRIPT' in content.upper():
                results['transcript_exists'] = True
            else:
                results['issues'].append("❌ No meeting transcript found")
        except:
            pass
        
    except Exception as e:
        results['issues'].append(f"❌ Critical error: {str(e)}")
    
    return results

def diagnose_all_agents():
    """Diagnose all agents' compliance"""
    print("🔍 DIAGNOSING MEETING PROTOCOL FAILURES")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    agents = load_agents_from_yaml('agents.yaml')
    all_results = []
    
    for agent in agents:
        role = agent.role
        meta = get_agent_metadata(role)
        
        agent_name = meta.get('email_address', '').split('@')[0].replace('.', ' ').title()
        if not agent_name:
            agent_name = role.split()[0] if role else 'Unknown'
        
        memory_doc_id = meta.get('memory_doc_id', '')
        calendar_id = meta.get('personal_calendar_id', '')
        email_address = meta.get('email_address', '')
        
        if not memory_doc_id or not calendar_id or not email_address:
            print(f"⚠️  {agent_name}: Missing required IDs")
            continue
        
        print(f"🔍 Checking: {agent_name} ({role})")
        results = check_agent_p8_compliance(role, agent_name, memory_doc_id, calendar_id, email_address)
        all_results.append(results)
        
        # Print summary
        status = "✅" if all([results['p8_email_sent'], results['p8_calendar_added'], results['p8_memory_logged']]) else "❌"
        print(f"   {status} P8 Email: {results['p8_email_sent']}")
        print(f"   {status} P8 Calendar: {results['p8_calendar_added']}")
        print(f"   {status} P8 Memory: {results['p8_memory_logged']}")
        print(f"   {'✅' if results['p5_meeting_notes'] else '❌'} P5 Notes: {results['p5_meeting_notes']}")
        print(f"   {'✅' if results['transcript_exists'] else '❌'} Transcript: {results['transcript_exists']}")
        if results['issues']:
            for issue in results['issues']:
                print(f"   {issue}")
        print()
    
    # Summary
    print("="*80)
    print("📊 DIAGNOSIS SUMMARY")
    print("="*80)
    
    total = len(all_results)
    p8_email_count = sum(1 for r in all_results if r['p8_email_sent'])
    p8_calendar_count = sum(1 for r in all_results if r['p8_calendar_added'])
    p8_memory_count = sum(1 for r in all_results if r['p8_memory_logged'])
    p5_notes_count = sum(1 for r in all_results if r['p5_meeting_notes'])
    transcript_count = sum(1 for r in all_results if r['transcript_exists'])
    
    print(f"Total Agents: {total}")
    print(f"P8 Email Sent: {p8_email_count}/{total} ({p8_email_count*100//total if total > 0 else 0}%)")
    print(f"P8 Calendar Added: {p8_calendar_count}/{total} ({p8_calendar_count*100//total if total > 0 else 0}%)")
    print(f"P8 Memory Logged: {p8_memory_count}/{total} ({p8_memory_count*100//total if total > 0 else 0}%)")
    print(f"P5 Meeting Notes: {p5_notes_count}/{total} ({p5_notes_count*100//total if total > 0 else 0}%)")
    print(f"Transcripts Created: {transcript_count}/{total} ({transcript_count*100//total if total > 0 else 0}%)")
    
    print("\n🛑 ROOT CAUSE ANALYSIS:")
    if p8_email_count == 0:
        print("   ❌ CRITICAL: No agents sent P8 confirmation emails")
        print("   → This indicates the meeting invite was never received/processed")
        print("   → Likely cause: Google Calendar alias identity conflict")
    if p8_calendar_count == 0:
        print("   ❌ CRITICAL: No agents added meeting to personal calendars")
        print("   → This indicates P8 protocol was never triggered")
    if p5_notes_count == 0:
        print("   ❌ CRITICAL: No agents took meeting notes (P5)")
        print("   → This indicates agents never entered active meeting mode")
    if transcript_count == 0:
        print("   ❌ CRITICAL: No meeting transcripts created")
        print("   → This indicates the meeting documentation workflow never activated")
    
    return all_results

if __name__ == "__main__":
    results = diagnose_all_agents()
    sys.exit(0 if all(r['p8_email_sent'] and r['p8_calendar_added'] and r['p8_memory_logged'] for r in results) else 1)

