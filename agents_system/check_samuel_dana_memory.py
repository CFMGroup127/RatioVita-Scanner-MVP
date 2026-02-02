"""
Check Samuel Reed and Dana Flores Memory Documents
This script checks if the force acknowledgment had any effect on their memory logs.
"""
import os
import sys
from datetime import datetime
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from main import load_agents_from_yaml, get_agent_metadata

def check_agent_memory(agent_name):
    """Check an agent's memory document for meeting acknowledgment."""
    print(f"\n{'='*80}")
    print(f"📋 CHECKING {agent_name.upper()} MEMORY DOCUMENT")
    print(f"{'='*80}")
    
    # Get credentials
    creds = None
    SCOPES = [
        'https://www.googleapis.com/auth/documents',
        'https://www.googleapis.com/auth/drive'
    ]
    
    if os.path.exists('token.json'):
        creds = Credentials.from_authorized_user_file('token.json', SCOPES)
        if not creds.valid:
            if creds.expired and creds.refresh_token:
                try:
                    creds.refresh(Request())
                except:
                    pass
    
    if not creds:
        print("❌ Could not get credentials")
        return None
    
    # Get agent metadata
    agent_meta = get_agent_metadata(agent_name)
    memory_doc_id = agent_meta.get('memory_doc_id', '')
    agent_email = agent_meta.get('email_address', '')
    
    if not memory_doc_id:
        print(f"❌ No memory document ID found for {agent_name}")
        return None
    
    print(f"   Memory Doc ID: {memory_doc_id}")
    print(f"   Email: {agent_email}")
    
    try:
        # Read memory document
        from tools import google_docs_memory_tool
        result = google_docs_memory_tool(memory_doc_id, "", action='read')
        
        print(f"\n📄 Memory Document Content:")
        print(f"{'-'*80}")
        print(result)
        print(f"{'-'*80}")
        
        # Check for meeting acknowledgment
        if 'MEETING ACCEPTED' in result.upper() or 'MEETING ACCEPTANCE' in result.upper():
            print(f"\n✅ FOUND: Meeting acceptance logged in memory")
            if 'Executive Strategy Group Meeting' in result or 'V1 Legacy Review' in result:
                print(f"   ✅ Meeting title matches")
        else:
            print(f"\n❌ NOT FOUND: No meeting acceptance logged")
        
        # Check for email delegation or send attempts
        if 'EMAIL' in result.upper() and ('SENT' in result.upper() or 'DELEGATED' in result.upper() or 'CONFIRMATION' in result.upper()):
            print(f"   ⚠️  Found email-related entries in memory")
        
        return result
        
    except Exception as e:
        print(f"❌ Error reading memory: {e}")
        import traceback
        traceback.print_exc()
        return None

def check_confirmation_emails():
    """Check for confirmation emails from agents."""
    print(f"\n{'='*80}")
    print(f"📧 CHECKING FOR CONFIRMATION EMAILS")
    print(f"{'='*80}")
    
    # Get credentials
    creds = None
    SCOPES = ['https://www.googleapis.com/auth/gmail.readonly']
    
    if os.path.exists('token.json'):
        creds = Credentials.from_authorized_user_file('token.json', SCOPES)
        if not creds.valid:
            if creds.expired and creds.refresh_token:
                try:
                    creds.refresh(Request())
                except:
                    pass
    
    if not creds:
        print("❌ Could not get credentials")
        return False
    
    try:
        service = build('gmail', 'v1', credentials=creds)
        
        # Get Dana and David emails
        dana_meta = get_agent_metadata('Dana Flores')
        david_meta = get_agent_metadata('David Chen')
        dana_email = dana_meta.get('email_address', 'dana.flores@ratiovita.com')
        david_email = david_meta.get('email_address', 'david.chen@ratiovita.com')
        
        # Search for confirmation emails
        query = f'(to:{dana_email} OR to:{david_email}) "Meeting Acceptance Confirmation" newer_than:1d'
        
        results = service.users().messages().list(
            userId='me',
            q=query,
            maxResults=50
        ).execute()
        
        messages = results.get('messages', [])
        
        print(f"\n📧 Found {len(messages)} confirmation email(s)")
        
        if messages:
            print(f"\n   Confirmation Emails:")
            for i, msg in enumerate(messages[:15], 1):
                try:
                    message = service.users().messages().get(
                        userId='me',
                        id=msg['id'],
                        format='metadata',
                        metadataHeaders=['From', 'Subject', 'Date', 'To', 'Cc']
                    ).execute()
                    
                    headers = message.get('payload', {}).get('headers', [])
                    from_email = next((h['value'] for h in headers if h['name'] == 'From'), 'Unknown')
                    subject = next((h['value'] for h in headers if h['name'] == 'Subject'), 'No Subject')
                    date = next((h['value'] for h in headers if h['name'] == 'Date'), 'Unknown')
                    to_addr = next((h['value'] for h in headers if h['name'] == 'To'), 'Unknown')
                    cc_addr = next((h['value'] for h in headers if h['name'] == 'Cc'), 'None')
                    
                    print(f"\n   {i}. From: {from_email}")
                    print(f"      Subject: {subject}")
                    print(f"      To: {to_addr}")
                    print(f"      CC: {cc_addr}")
                    print(f"      Date: {date}")
                except Exception as e:
                    print(f"   {i}. Error reading message: {e}")
        else:
            print(f"\n   ❌ NO CONFIRMATION EMAILS FOUND")
            print(f"   This confirms the email sending step is failing.")
        
        return len(messages) > 0
        
    except Exception as e:
        print(f"❌ Error checking emails: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """Check memory and emails."""
    print("\n" + "="*80)
    print("🔍 FINAL VERIFICATION: MEMORY AND EMAIL STATUS")
    print("="*80)
    print(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}")
    print("="*80)
    
    # Check Samuel Reed memory (correct role name)
    samuel_memory = check_agent_memory('Competitive Intelligence Specialist')
    
    # Check Dana Flores memory (correct role name)
    dana_memory = check_agent_memory('Admin Assistant & Workflow Funnel')
    
    # Check for confirmation emails
    emails_found = check_confirmation_emails()
    
    # Summary
    print(f"\n{'='*80}")
    print(f"📊 VERIFICATION SUMMARY")
    print(f"{'='*80}")
    
    samuel_has_log = samuel_memory and ('MEETING ACCEPTED' in samuel_memory.upper() or 'MEETING ACCEPTANCE' in samuel_memory.upper())
    dana_has_log = dana_memory and ('MEETING ACCEPTED' in dana_memory.upper() or 'MEETING ACCEPTANCE' in dana_memory.upper())
    
    print(f"\n✅ Samuel Reed Memory: {'HAS LOG' if samuel_has_log else 'NO LOG'}")
    print(f"✅ Dana Flores Memory: {'HAS LOG' if dana_has_log else 'NO LOG'}")
    print(f"✅ Confirmation Emails: {'FOUND' if emails_found else 'NOT FOUND'}")
    
    if samuel_has_log and not emails_found:
        print(f"\n⚠️  DIAGNOSIS: Memory logging works, but email sending is failing")
        print(f"   This confirms the Gmail Tool execution is the failure point.")
    
    print(f"\n{'='*80}")

if __name__ == "__main__":
    main()

