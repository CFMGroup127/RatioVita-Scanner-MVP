"""
Check Meeting Confirmations
This script checks if all agents have confirmed receipt of the meeting invitation
by checking their memory documents and looking for confirmation emails.
"""
import os
import sys
from datetime import datetime
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
import yaml

SCOPES = [
    'https://www.googleapis.com/auth/documents.readonly',
    'https://www.googleapis.com/auth/gmail.readonly'
]

def get_credentials():
    """Get valid user credentials from storage."""
    creds = None
    token_path = 'token.json'
    
    if os.path.exists(token_path):
        try:
            creds = Credentials.from_authorized_user_file(token_path, SCOPES)
        except Exception as e:
            try:
                creds = Credentials.from_authorized_user_file(token_path, None)
            except:
                pass
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            try:
                creds.refresh(Request())
            except:
                pass
    
    return creds

def load_agents():
    """Load agent configurations from agents.yaml"""
    with open('agents.yaml', 'r') as f:
        return yaml.safe_load(f)

def check_memory_for_confirmation(docs_service, doc_id, agent_name):
    """Check agent's memory document for meeting confirmation"""
    try:
        doc = docs_service.documents().get(documentId=doc_id).execute()
        content = doc.get('body', {}).get('content', [])
        
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
        
        full_text = ''.join(text_content).lower()
        
        # Check for meeting confirmation markers
        has_confirmation = (
            'meeting accepted' in full_text or
            'meeting acceptance' in full_text or
            'p8' in full_text or
            '8:00 pm' in full_text or
            '8pm' in full_text or
            'november 18' in full_text
        )
        
        return has_confirmation, full_text
    except Exception as e:
        return False, f"Error: {str(e)}"

def check_confirmation_emails(gmail_service, agent_email):
    """Check if agent sent confirmation email"""
    try:
        # Search for confirmation emails from this agent
        query = f'from:{agent_email} subject:"Meeting Acceptance" after:2025/11/18'
        results = gmail_service.users().messages().list(
            userId='me', q=query, maxResults=5
        ).execute()
        
        return len(results.get('messages', [])) > 0
    except Exception as e:
        return False

def main():
    """Check meeting confirmations"""
    print("\n" + "="*80)
    print("🔍 CHECKING MEETING CONFIRMATIONS")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}")
    print("="*80)
    
    creds = get_credentials()
    docs_service = build('docs', 'v1', credentials=creds)
    gmail_service = build('gmail', 'v1', credentials=creds)
    
    agents_data = load_agents()
    agents = agents_data.get('agents', [])
    
    print(f"\n👥 Checking {len(agents)} agents...")
    print("="*80)
    
    confirmed_memory = []
    confirmed_email = []
    not_confirmed = []
    
    for agent in agents:
        agent_name = agent.get('role', 'Unknown')
        agent_email = agent.get('email_address', '')
        memory_doc_id = agent.get('memory_doc_id', '')
        
        print(f"\n👤 {agent_name}")
        print(f"   Email: {agent_email}")
        
        # Check memory
        has_memory_confirmation = False
        if memory_doc_id:
            has_memory_confirmation, memory_text = check_memory_for_confirmation(
                docs_service, memory_doc_id, agent_name
            )
            if has_memory_confirmation:
                print(f"   ✅ Memory: Confirmed")
                confirmed_memory.append(agent_name)
            else:
                print(f"   ❌ Memory: No confirmation found")
        else:
            print(f"   ⚠️  Memory: No memory document ID")
        
        # Check email
        has_email_confirmation = False
        if agent_email:
            has_email_confirmation = check_confirmation_emails(gmail_service, agent_email)
            if has_email_confirmation:
                print(f"   ✅ Email: Confirmation sent")
                confirmed_email.append(agent_name)
            else:
                print(f"   ❌ Email: No confirmation email found")
        
        # Overall status
        if has_memory_confirmation and has_email_confirmation:
            print(f"   ✅ FULLY CONFIRMED")
        elif has_memory_confirmation or has_email_confirmation:
            print(f"   ⚠️  PARTIALLY CONFIRMED")
        else:
            print(f"   ❌ NOT CONFIRMED")
            not_confirmed.append(agent_name)
    
    # Summary
    print("\n" + "="*80)
    print("📊 SUMMARY")
    print("="*80)
    
    print(f"\n✅ Memory Confirmations: {len(confirmed_memory)}/{len(agents)}")
    print(f"✅ Email Confirmations: {len(confirmed_email)}/{len(agents)}")
    print(f"❌ Not Confirmed: {len(not_confirmed)}/{len(agents)}")
    
    if not_confirmed:
        print(f"\n⚠️  Agents Not Confirmed ({len(not_confirmed)}):")
        for name in not_confirmed:
            print(f"   • {name}")
    
    print("\n" + "="*80)
    print("✅ Check complete")
    print("="*80)
    
    if len(not_confirmed) > 0:
        print(f"\n💡 Next Step: Run force_meeting_acknowledgment.py to trigger confirmations")
        print("="*80)

if __name__ == "__main__":
    main()


