"""
Check project.reports@ratiovita.com Inbox
This script checks for report submissions from agents.
"""
import os
from datetime import datetime, timedelta
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from main import load_agents_from_yaml, get_agent_metadata

def check_reporting_inbox():
    """
    Check project.reports@ratiovita.com inbox for report submissions.
    """
    print("\n" + "="*80)
    print("📧 CHECKING UNIFIED REPORTING CENTER INBOX")
    print("="*80)
    print("Inbox: project.reports@ratiovita.com")
    print(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}")
    print("="*80)
    
    # Get credentials
    creds = None
    if os.path.exists('token.json'):
        creds = Credentials.from_authorized_user_file('token.json', [
            'https://www.googleapis.com/auth/gmail.readonly'
        ])
        if not creds.valid:
            if creds.expired and creds.refresh_token:
                creds.refresh(Request())
    
    if not creds:
        print("❌ Could not get credentials")
        return None
    
    # Load agents
    agents = load_agents_from_yaml('agents.yaml')
    
    # Reporting agents
    reporting_agents = {
        'Alice Kim': 'alice.kim@ratiovita.com',
        'Samuel Reed': 'samuel.reed@ratiovita.com',
        'Megan Parker': 'megan.parker@ratiovita.com',
        'Arthur Jensen': 'arthur.jensen@ratiovita.com',
        'Ash Roy': 'ash.roy@ratiovita.com'
    }
    
    gmail_service = build('gmail', 'v1', credentials=creds)
    
    print(f"\n🔍 Searching for reports from {len(reporting_agents)} reporting agents...")
    print("-" * 80)
    
    # Search for emails to project.reports@ratiovita.com
    # Note: We need to search in the sent mailbox or use a different approach
    # Since we can't directly access project.reports inbox, we'll search for emails
    # that mention project.reports in the subject or body
    
    try:
        # Search for recent emails (last 24 hours)
        query = 'to:project.reports@ratiovita.com newer_than:1d'
        
        results = gmail_service.users().messages().list(
            userId='me',
            q=query,
            maxResults=20
        ).execute()
        
        messages = results.get('messages', [])
        
        print(f"\n📧 Found {len(messages)} message(s) to project.reports@ratiovita.com")
        
        if messages:
            print("\n📋 Report Submissions:")
            print("-" * 80)
            
            for msg in messages:
                try:
                    message = gmail_service.users().messages().get(
                        userId='me',
                        id=msg['id'],
                        format='metadata',
                        metadataHeaders=['From', 'Subject', 'Date']
                    ).execute()
                    
                    headers = message.get('payload', {}).get('headers', [])
                    from_email = next((h['value'] for h in headers if h['name'] == 'From'), 'Unknown')
                    subject = next((h['value'] for h in headers if h['name'] == 'Subject'), 'No Subject')
                    date = next((h['value'] for h in headers if h['name'] == 'Date'), 'Unknown')
                    
                    # Check if from a reporting agent
                    agent_name = None
                    for name, email in reporting_agents.items():
                        if email in from_email:
                            agent_name = name
                            break
                    
                    if agent_name:
                        print(f"\n✅ {agent_name}:")
                        print(f"   From: {from_email}")
                        print(f"   Subject: {subject}")
                        print(f"   Date: {date}")
                        print(f"   Message ID: {msg['id']}")
                    else:
                        print(f"\n📧 Other email:")
                        print(f"   From: {from_email}")
                        print(f"   Subject: {subject}")
                        print(f"   Date: {date}")
                        
                except Exception as e:
                    print(f"⚠️  Error reading message {msg.get('id', 'unknown')}: {e}")
        else:
            print("\n⚠️  No reports found in inbox (last 24 hours)")
            print("   This could mean:")
            print("   - Reports haven't been submitted yet")
            print("   - Reports were sent to a different address")
            print("   - Need to check actual project.reports@ratiovita.com inbox")
        
        # Also check for emails FROM reporting agents
        print(f"\n" + "="*80)
        print("🔍 SEARCHING FOR REPORTS FROM AGENTS")
        print("="*80)
        
        for name, email in reporting_agents.items():
            query = f'from:{email} project.reports newer_than:1d'
            results = gmail_service.users().messages().list(
                userId='me',
                q=query,
                maxResults=5
            ).execute()
            
            agent_messages = results.get('messages', [])
            if agent_messages:
                print(f"\n✅ {name} ({email}):")
                print(f"   Found {len(agent_messages)} message(s)")
                for msg in agent_messages[:3]:
                    try:
                        message = gmail_service.users().messages().get(
                            userId='me',
                            id=msg['id'],
                            format='metadata',
                            metadataHeaders=['Subject', 'Date', 'To']
                        ).execute()
                        headers = message.get('payload', {}).get('headers', [])
                        subject = next((h['value'] for h in headers if h['name'] == 'Subject'), 'No Subject')
                        date = next((h['value'] for h in headers if h['name'] == 'Date'), 'Unknown')
                        to_addr = next((h['value'] for h in headers if h['name'] == 'To'), 'Unknown')
                        print(f"      - {subject}")
                        print(f"        To: {to_addr}")
                        print(f"        Date: {date}")
                    except:
                        pass
            else:
                print(f"❌ {name}: No reports found")
        
    except Exception as e:
        print(f"❌ Error accessing Gmail: {e}")
        import traceback
        traceback.print_exc()
        return None
    
    print("\n" + "="*80)
    print("✅ INBOX CHECK COMPLETE")
    print("="*80)
    print("\n💡 NOTE: To fully verify, you may need to:")
    print("   1. Check project.reports@ratiovita.com inbox directly")
    print("   2. Verify emails were received (not just sent)")
    print("   3. Check if Dana/David have executed MRAP protocols")
    
    return messages

if __name__ == "__main__":
    check_reporting_inbox()


