"""
Status Check: Agent Activity Today
This script checks all agents' activity for today, including:
- Memory document updates
- Email activity
- Calendar event acknowledgments
- Protocol compliance
"""
import os
import sys
from datetime import datetime, timedelta
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
import yaml
import re

# Scopes required
SCOPES = [
    'https://www.googleapis.com/auth/documents.readonly',
    'https://www.googleapis.com/auth/drive.readonly',
    'https://www.googleapis.com/auth/gmail.readonly',
    'https://www.googleapis.com/auth/calendar.readonly'
]

def get_credentials():
    """Get valid user credentials from storage."""
    creds = None
    token_path = 'token.json'
    
    if os.path.exists(token_path):
        try:
            # Try to load with the requested scopes
            creds = Credentials.from_authorized_user_file(token_path, SCOPES)
        except Exception as e:
            print(f"⚠️  Could not load token with requested scopes: {e}")
            # Try to load without scope restriction first
            try:
                creds = Credentials.from_authorized_user_file(token_path, None)
                # Check if it has the scopes we need
                if creds.scopes:
                    # Check if all required scopes are present (or compatible)
                    has_docs = any('documents' in s for s in creds.scopes)
                    has_drive = any('drive' in s for s in creds.scopes)
                    has_gmail = any('gmail' in s for s in creds.scopes)
                    has_calendar = any('calendar' in s for s in creds.scopes)
                    
                    if has_docs and has_drive and has_gmail and has_calendar:
                        # Token has compatible scopes, use it
                        print("✅ Using existing token with compatible scopes")
                    else:
                        raise Exception("Token missing required scopes")
            except Exception as e2:
                print(f"⚠️  Could not use existing token: {e2}")
                creds = None
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            try:
                creds.refresh(Request())
            except Exception as e:
                print(f"⚠️  Token refresh failed: {e}")
                print("   Will request new authentication...")
                creds = None
        
        if not creds:
            print("🔐 Requesting new authentication...")
            flow = InstalledAppFlow.from_client_secrets_file(
                'credentials.json', SCOPES)
            creds = flow.run_local_server(port=0, access_type='offline', prompt='consent')
            
            with open(token_path, 'w') as token:
                token.write(creds.to_json())
    
    return creds

def load_agents():
    """Load agent configurations from agents.yaml"""
    with open('agents.yaml', 'r') as f:
        return yaml.safe_load(f)

def get_today_date_strings():
    """Get various date string formats for today"""
    today = datetime.now()
    formats = [
        today.strftime('%B %d, %Y'),  # November 18, 2025
        today.strftime('%Y-%m-%d'),   # 2025-11-18
        today.strftime('%m/%d/%Y'),   # 11/18/2025
        today.strftime('%B %d'),      # November 18
    ]
    return formats

def check_memory_document(service, doc_id, agent_name):
    """Check agent's memory document for today's activity"""
    try:
        doc = service.documents().get(documentId=doc_id).execute()
        content = doc.get('body', {}).get('content', [])
        
        # Extract text from document
        text_content = []
        def extract_text(element):
            if 'paragraph' in element:
                for para_elem in element['paragraph'].get('elements', []):
                    if 'textRun' in para_elem:
                        text_content.append(para_elem['textRun'].get('content', ''))
            elif 'table' in element:
                for row in element['table'].get('tableRows', []):
                    for cell in row.get('tableCells', []):
                        for cell_elem in cell.get('content', []):
                            extract_text(cell_elem)
        
        for element in content:
            extract_text(element)
        
        full_text = ''.join(text_content)
        
        # Check for today's date
        today_strings = get_today_date_strings()
        # Also check for "today", "November 18", etc.
        today_keywords = ['today', 'november 18', 'nov 18', '11/18', '2025-11-18']
        has_today_activity = (
            any(date_str in full_text for date_str in today_strings) or
            any(keyword in full_text.lower() for keyword in today_keywords)
        )
        
        # Get recent lines (those containing today's date)
        lines = [line.strip() for line in full_text.split('\n') if line.strip()]
        recent_lines = []
        for line in lines:
            if any(date_str in line for date_str in today_strings) or any(keyword in line.lower() for keyword in today_keywords):
                recent_lines.append(line)
        
        # Check for protocol markers
        protocols = {
            'P0': 'Assignment Acknowledgment' in full_text or 'P0' in full_text or 'task receipt' in full_text.lower(),
            'P1': 'Memory Audit' in full_text or 'P1' in full_text,
            'P3': 'Report Submission' in full_text or 'P3' in full_text or 'project.reports@ratiovita.com' in full_text,
            'P8': 'MEETING ACCEPTED' in full_text or 'Meeting Accepted' in full_text or 'P8' in full_text,
            'P12': 'P12' in full_text or 'Corrective Acknowledgment' in full_text or 'audit mandate' in full_text.lower(),
        }
        
        # Lines already extracted above
        
        return {
            'has_activity': has_today_activity,
            'total_lines': len(lines),
            'recent_lines': len(recent_lines),
            'protocols': protocols,
            'sample_recent': recent_lines[-5:] if recent_lines else [],
            'full_text_length': len(full_text)
        }
    except Exception as e:
        return {
            'error': str(e),
            'has_activity': False
        }

def check_email_activity(gmail_service, agent_email, today_start):
    """Check agent's email activity for today"""
    try:
        # Search for emails sent today
        query = f'from:{agent_email} after:{today_start.strftime("%Y/%m/%d")}'
        results = gmail_service.users().messages().list(
            userId='me', q=query, maxResults=10
        ).execute()
        
        sent_count = len(results.get('messages', []))
        
        # Search for emails received today
        query = f'to:{agent_email} after:{today_start.strftime("%Y/%m/%d")}'
        results = gmail_service.users().messages().list(
            userId='me', q=query, maxResults=10
        ).execute()
        
        received_count = len(results.get('messages', []))
        
        # Check for meeting confirmation emails
        query = f'from:{agent_email} subject:"Meeting" after:{today_start.strftime("%Y/%m/%d")}'
        results = gmail_service.users().messages().list(
            userId='me', q=query, maxResults=5
        ).execute()
        
        confirmation_emails = len(results.get('messages', []))
        
        return {
            'sent_today': sent_count,
            'received_today': received_count,
            'confirmations_sent': confirmation_emails
        }
    except Exception as e:
        return {
            'error': str(e),
            'sent_today': 0,
            'received_today': 0,
            'confirmations_sent': 0
        }

def check_calendar_acceptance(calendar_service, agent_email, meeting_title):
    """Check if agent has accepted the meeting"""
    try:
        # Search for the meeting event
        time_min = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0).isoformat() + 'Z'
        time_max = (datetime.now() + timedelta(days=1)).isoformat() + 'Z'
        
        events_result = calendar_service.events().list(
            calendarId='primary',
            timeMin=time_min,
            timeMax=time_max,
            q=meeting_title,
            maxResults=10
        ).execute()
        
        events = events_result.get('items', [])
        
        for event in events:
            attendees = event.get('attendees', [])
            for attendee in attendees:
                if attendee.get('email') == agent_email:
                    return {
                        'found': True,
                        'response_status': attendee.get('responseStatus', 'needsAction'),
                        'event_title': event.get('summary', ''),
                        'event_time': event.get('start', {}).get('dateTime', event.get('start', {}).get('date', ''))
                    }
        
        return {'found': False, 'response_status': 'not_found'}
    except Exception as e:
        return {'error': str(e), 'found': False}

def main():
    """Main status check function"""
    print("\n" + "="*80)
    print("📊 AGENT ACTIVITY STATUS CHECK - TODAY")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}")
    print("="*80)
    
    # Get credentials
    print("\n🔐 Authenticating...")
    creds = get_credentials()
    
    # Build services
    docs_service = build('docs', 'v1', credentials=creds)
    gmail_service = build('gmail', 'v1', credentials=creds)
    calendar_service = build('calendar', 'v3', credentials=creds)
    
    # Load agents
    print("📋 Loading agent configurations...")
    agents_data = load_agents()
    agents = agents_data.get('agents', [])
    
    today_start = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    
    print(f"\n🔍 Checking activity for {len(agents)} agents...")
    print("="*80)
    
    status_summary = []
    
    for agent in agents:
        agent_name = agent.get('role', 'Unknown')
        agent_email = agent.get('email_address', '')
        memory_doc_id = agent.get('memory_doc_id', '')
        
        print(f"\n👤 {agent_name}")
        print(f"   Email: {agent_email}")
        print("-" * 80)
        
        # Check memory document
        if memory_doc_id:
            print("   📝 Memory Document:")
            memory_status = check_memory_document(docs_service, memory_doc_id, agent_name)
            if 'error' in memory_status:
                print(f"      ❌ Error: {memory_status['error']}")
            else:
                activity_icon = "✅" if memory_status['has_activity'] else "❌"
                print(f"      {activity_icon} Today's Activity: {'Yes' if memory_status['has_activity'] else 'No'}")
                print(f"      📊 Total Lines: {memory_status['total_lines']}")
                print(f"      📅 Recent Lines (Today): {memory_status['recent_lines']}")
                print(f"      🔐 Protocols:")
                for protocol, found in memory_status['protocols'].items():
                    icon = "✅" if found else "❌"
                    print(f"         {icon} {protocol}")
                
                if memory_status['sample_recent']:
                    print(f"      📄 Recent Activity Sample:")
                    for line in memory_status['sample_recent']:
                        if len(line) > 100:
                            line = line[:100] + "..."
                        print(f"         • {line}")
        else:
            print("   ❌ No memory document ID configured")
            memory_status = {'has_activity': False}
        
        # Check email activity
        if agent_email:
            print("   📧 Email Activity:")
            email_status = check_email_activity(gmail_service, agent_email, today_start)
            if 'error' in email_status:
                print(f"      ❌ Error: {email_status['error']}")
            else:
                print(f"      📤 Sent Today: {email_status['sent_today']}")
                print(f"      📥 Received Today: {email_status['received_today']}")
                print(f"      ✅ Meeting Confirmations: {email_status['confirmations_sent']}")
        else:
            print("   ❌ No email configured")
            email_status = {'sent_today': 0, 'confirmations_sent': 0}
        
        # Check calendar acceptance
        if agent_email:
            print("   📅 Calendar Status:")
            calendar_status = check_calendar_acceptance(
                calendar_service, agent_email, "Executive Strategy Group Meeting"
            )
            if 'error' in calendar_status:
                print(f"      ❌ Error: {calendar_status['error']}")
            elif calendar_status['found']:
                status_icon = "✅" if calendar_status['response_status'] == 'accepted' else "⏳"
                print(f"      {status_icon} Meeting Found: {calendar_status['event_title']}")
                print(f"      📊 Response Status: {calendar_status['response_status']}")
                print(f"      🕐 Event Time: {calendar_status['event_time']}")
            else:
                print(f"      ❌ Meeting not found in calendar")
        
        # Summary for this agent
        status_summary.append({
            'name': agent_name,
            'email': agent_email,
            'memory_activity': memory_status.get('has_activity', False),
            'emails_sent': email_status.get('sent_today', 0),
            'confirmations': email_status.get('confirmations_sent', 0),
            'protocols': memory_status.get('protocols', {})
        })
    
    # Overall summary
    print("\n" + "="*80)
    print("📊 OVERALL SUMMARY")
    print("="*80)
    
    active_agents = sum(1 for s in status_summary if s['memory_activity'] or s['emails_sent'] > 0)
    total_emails = sum(s['emails_sent'] for s in status_summary)
    total_confirmations = sum(s['confirmations'] for s in status_summary)
    
    print(f"\n✅ Agents with Activity Today: {active_agents}/{len(agents)}")
    print(f"📧 Total Emails Sent Today: {total_emails}")
    print(f"✅ Total Meeting Confirmations: {total_confirmations}")
    
    # Protocol compliance
    print(f"\n🔐 Protocol Compliance:")
    for protocol in ['P0', 'P1', 'P3', 'P8', 'P12']:
        compliant = sum(1 for s in status_summary if s['protocols'].get(protocol, False))
        print(f"   {protocol}: {compliant}/{len(agents)} agents")
    
    # Agents needing attention
    print(f"\n⚠️  Agents Needing Attention:")
    for s in status_summary:
        if not s['memory_activity'] and s['emails_sent'] == 0:
            print(f"   • {s['name']} - No activity detected")
    
    print("\n" + "="*80)
    print("✅ Status check complete")
    print("="*80)

if __name__ == "__main__":
    main()

