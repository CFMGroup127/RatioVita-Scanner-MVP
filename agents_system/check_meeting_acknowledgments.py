"""
Check Meeting Acknowledgments
This script checks if agents have acknowledged the meeting per P8 protocol.
"""
import os
import sys
from datetime import datetime
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from main import load_agents_from_yaml, get_agent_metadata

def check_memory_for_acknowledgment(creds, memory_doc_id, agent_name):
    """Check if agent has logged meeting acceptance in memory."""
    try:
        from tools import google_docs_memory_tool
        
        # Read memory document
        result = google_docs_memory_tool(memory_doc_id, "", action='read')
        
        if 'MEETING ACCEPTED' in result.upper() or 'MEETING ACCEPTANCE' in result.upper():
            # Check for the specific meeting
            if 'Executive Strategy Group Meeting' in result or 'V1 Legacy Review' in result:
                return True, result
        return False, result
    except Exception as e:
        return False, f"Error reading memory: {e}"

def check_email_for_confirmation(creds, agent_email, dana_email, david_email):
    """Check if agent has sent confirmation email."""
    try:
        service = build('gmail', 'v1', credentials=creds)
        
        # Search for confirmation emails from this agent
        query = f'from:{agent_email} (to:{dana_email} OR to:{david_email}) "Meeting Acceptance Confirmation" newer_than:1d'
        
        results = service.users().messages().list(
            userId='me',
            q=query,
            maxResults=5
        ).execute()
        
        messages = results.get('messages', [])
        return len(messages) > 0, messages
    except Exception as e:
        return False, []

def check_meeting_acknowledgments():
    """
    Check if agents have acknowledged the meeting per P8 protocol.
    """
    print("\n" + "="*80)
    print("📋 CHECKING MEETING ACKNOWLEDGMENTS")
    print("="*80)
    print(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}")
    print("="*80)
    
    # Get credentials
    creds = None
    SCOPES = [
        'https://www.googleapis.com/auth/documents',
        'https://www.googleapis.com/auth/drive',
        'https://www.googleapis.com/auth/gmail.readonly'
    ]
    
    if os.path.exists('token.json'):
        creds = Credentials.from_authorized_user_file('token.json', SCOPES)
        if not creds.valid:
            if creds.expired and creds.refresh_token:
                try:
                    creds.refresh(Request())
                except Exception as e:
                    print(f"⚠️  Could not refresh credentials: {e}")
                    print("   Using existing credentials anyway...")
    
    if not creds:
        print("❌ Could not get credentials")
        return False
    
    # Load agents
    agents = load_agents_from_yaml('agents.yaml')
    
    # Get Dana and David emails
    dana_meta = get_agent_metadata('Dana Flores')
    david_meta = get_agent_metadata('David Chen')
    dana_email = dana_meta.get('email_address', 'dana.flores@ratiovita.com')
    david_email = david_meta.get('email_address', 'david.chen@ratiovita.com')
    
    print(f"\n📧 Checking acknowledgments...")
    print(f"   Confirmation emails should be sent to:")
    print(f"   - {dana_email}")
    print(f"   - {david_email}")
    print(f"   - CC: collin.m@ratiovita.com")
    print("="*80)
    
    acknowledgment_status = []
    
    for agent in agents:
        agent_name = agent.role
        agent_meta = get_agent_metadata(agent_name)
        agent_email = agent_meta.get('email_address', '')
        memory_doc_id = agent_meta.get('memory_doc_id', '')
        
        if not agent_email or not memory_doc_id:
            print(f"\n⚠️  {agent_name}: Missing email or memory doc ID")
            acknowledgment_status.append({
                'agent': agent_name,
                'memory_logged': False,
                'email_sent': False,
                'status': 'INCOMPLETE - Missing credentials'
            })
            continue
        
        print(f"\n🔍 Checking {agent_name}...")
        
        # Check memory
        memory_acknowledged, memory_content = check_memory_for_acknowledgment(creds, memory_doc_id, agent_name)
        
        # Check email
        email_sent, email_messages = check_email_for_confirmation(creds, agent_email, dana_email, david_email)
        
        status = 'COMPLETE' if (memory_acknowledged and email_sent) else 'INCOMPLETE'
        
        acknowledgment_status.append({
            'agent': agent_name,
            'memory_logged': memory_acknowledged,
            'email_sent': email_sent,
            'status': status
        })
        
        if memory_acknowledged:
            print(f"   ✅ Memory: Meeting acceptance logged")
        else:
            print(f"   ❌ Memory: Meeting acceptance NOT logged")
        
        if email_sent:
            print(f"   ✅ Email: Confirmation email sent ({len(email_messages)} found)")
        else:
            print(f"   ❌ Email: Confirmation email NOT sent")
        
        if status == 'COMPLETE':
            print(f"   ✅ Status: P8 Protocol COMPLETE")
        else:
            print(f"   ⚠️  Status: P8 Protocol INCOMPLETE")
    
    # Summary
    print("\n" + "="*80)
    print("📊 ACKNOWLEDGMENT SUMMARY")
    print("="*80)
    
    complete = sum(1 for s in acknowledgment_status if s['status'] == 'COMPLETE')
    incomplete = sum(1 for s in acknowledgment_status if s['status'] == 'INCOMPLETE')
    
    print(f"\n✅ Complete: {complete} / {len(acknowledgment_status)}")
    print(f"❌ Incomplete: {incomplete} / {len(acknowledgment_status)}")
    
    if incomplete > 0:
        print(f"\n⚠️  Agents with incomplete acknowledgments:")
        for status in acknowledgment_status:
            if status['status'] == 'INCOMPLETE':
                missing = []
                if not status['memory_logged']:
                    missing.append('Memory log')
                if not status['email_sent']:
                    missing.append('Email confirmation')
                print(f"   - {status['agent']}: Missing {', '.join(missing)}")
    
    print("\n" + "="*80)
    
    return complete == len(acknowledgment_status)

if __name__ == "__main__":
    all_acknowledged = check_meeting_acknowledgments()
    if all_acknowledged:
        print("\n✅ All agents have acknowledged the meeting!")
    else:
        print("\n⚠️  Some agents have not acknowledged the meeting.")
        print("   Run force_meeting_acknowledgment.py to force acknowledgments.")

