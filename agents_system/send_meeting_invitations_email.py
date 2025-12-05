"""
Send Meeting Invitations via Email
Since agent emails aren't Google accounts, send calendar invitations
directly via email to all 15 agents.
"""
import os
import sys
from datetime import datetime
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
import yaml
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import base64

SCOPES = [
    'https://www.googleapis.com/auth/gmail.send'
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
        
        if not creds:
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

def create_message(sender, to, subject, body):
    """Create a message for an email."""
    message = MIMEText(body, 'html')
    message['to'] = to
    message['from'] = sender
    message['subject'] = subject
    return {'raw': base64.urlsafe_b64encode(message.as_bytes()).decode()}

def main():
    """Send meeting invitations via email"""
    print("\n" + "="*80)
    print("📧 SENDING MEETING INVITATIONS VIA EMAIL")
    print("="*80)
    
    creds = get_credentials()
    gmail_service = build('gmail', 'v1', credentials=creds)
    
    # Load agents
    agents_data = load_agents()
    agents = agents_data.get('agents', [])
    
    agent_emails = []
    agent_info = {}
    for agent in agents:
        email = agent.get('email_address', '')
        if email:
            agent_emails.append(email)
            agent_info[email] = agent.get('role', 'Unknown')
    
    print(f"✅ Found {len(agent_emails)} agent emails")
    
    # Meeting details
    meeting_time = "8:00 PM - 10:00 PM EST"
    meeting_date = "November 18, 2025"
    meeting_title = "Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning"
    meeting_location = "Virtual Meeting"
    meeting_link = "https://www.google.com/calendar/event?eid=dWoyNnVrdmhwMzc2Mmw3a3A4cm9ucnRjNWsgY180ZTFjMjRjYTNmZGVhMTVmZjZkZTFlZTJlMGQwMjVmNzVhMWY4ZmY1OGVmNThlMjExOWU1MjczZTUxYTVlN2RjQGc"
    
    sender = "collin.m@ratiovita.com"
    
    # Create email body
    email_body = f"""
<html>
<body>
<h2>Meeting Invitation: {meeting_title}</h2>

<p>You are invited to attend the Executive Strategy Group Meeting.</p>

<p><strong>Meeting Details:</strong></p>
<ul>
<li><strong>Date:</strong> {meeting_date}</li>
<li><strong>Time:</strong> {meeting_time}</li>
<li><strong>Location:</strong> {meeting_location}</li>
<li><strong>Calendar Link:</strong> <a href="{meeting_link}">View in Google Calendar</a></li>
</ul>

<p><strong>Agenda:</strong></p>
<ul>
<li>V1 Legacy Review</li>
<li>V2 Planning Discussion</li>
<li>Strategic Objectives Review</li>
</ul>

<p>Please confirm your attendance by replying to this email.</p>

<p>Best regards,<br>
RatioVita Team</p>
</body>
</html>
"""
    
    print(f"\n📧 Sending invitations to {len(agent_emails)} agents...")
    print("="*80)
    
    results = []
    for i, email in enumerate(agent_emails, 1):
        role = agent_info.get(email, 'Unknown')
        print(f"\n[{i}/{len(agent_emails)}] Sending to: {email}")
        print(f"   Role: {role}")
        
        try:
            message = create_message(
                sender=sender,
                to=email,
                subject=f"Meeting Invitation: {meeting_title} - {meeting_date} at {meeting_time.split('-')[0].strip()}",
                body=email_body
            )
            
            sent_message = gmail_service.users().messages().send(
                userId='me',
                body=message
            ).execute()
            
            print(f"   ✅ Invitation sent (Message ID: {sent_message.get('id')})")
            results.append({'email': email, 'success': True})
        except Exception as e:
            print(f"   ❌ Failed: {e}")
            results.append({'email': email, 'success': False, 'error': str(e)})
    
    # Summary
    print("\n" + "="*80)
    print("📊 SUMMARY")
    print("="*80)
    
    successful = sum(1 for r in results if r.get('success', False))
    failed = len(results) - successful
    
    print(f"\n✅ Successfully sent: {successful}/{len(agent_emails)}")
    print(f"❌ Failed: {failed}/{len(agent_emails)}")
    
    if failed > 0:
        print(f"\n❌ Failed invitations:")
        for r in results:
            if not r.get('success', False):
                print(f"   • {r['email']}: {r.get('error', 'Unknown error')}")
    
    print("\n" + "="*80)
    print("✅ Process complete")
    print("="*80)
    print(f"\n📅 Meeting Details:")
    print(f"   Time: {meeting_time}")
    print(f"   Date: {meeting_date}")
    print(f"   All agents have been notified via email")
    print("="*80)
    
    return successful > 0

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)


