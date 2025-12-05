"""
Update Meeting to 8 PM with Direct Agent Emails
This script updates the meeting to 8 PM EST and adds all 15 agents directly
as attendees (bypassing the group email issue).
"""
import os
import sys
from datetime import datetime, timedelta
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
import yaml

SCOPES = [
    'https://www.googleapis.com/auth/calendar'
]

PROJECT_CALENDAR_ID = "c_4e1c24ca3fdea15ff6de1ee2e0d025f75a1f8ff58ef58e2119e5273e51a5e7dc@group.calendar.google.com"

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

def main():
    """Update meeting with direct agent emails"""
    print("\n" + "="*80)
    print("📅 UPDATING MEETING TO 8 PM WITH DIRECT AGENT EMAILS")
    print("="*80)
    
    creds = get_credentials()
    calendar_service = build('calendar', 'v3', credentials=creds)
    
    # Load agents
    agents_data = load_agents()
    agents = agents_data.get('agents', [])
    
    agent_emails = []
    for agent in agents:
        email = agent.get('email_address', '')
        if email:
            agent_emails.append(email)
    
    print(f"✅ Found {len(agent_emails)} agent emails")
    
    # Calculate meeting time (8:00 PM - 10:00 PM EST today)
    today = datetime.now()
    start_time = today.replace(hour=20, minute=0, second=0, microsecond=0)
    end_time = start_time + timedelta(hours=2)
    
    start_time_iso = start_time.strftime('%Y-%m-%dT%H:%M:00')
    end_time_iso = end_time.strftime('%Y-%m-%dT%H:%M:00')
    
    # Find meeting
    start_of_day = today.replace(hour=0, minute=0, second=0, microsecond=0)
    end_of_day = today.replace(hour=23, minute=59, second=59, microsecond=0)
    
    events_result = calendar_service.events().list(
        calendarId=PROJECT_CALENDAR_ID,
        timeMin=start_of_day.isoformat() + 'Z',
        timeMax=end_of_day.isoformat() + 'Z',
        maxResults=20
    ).execute()
    
    events = events_result.get('items', [])
    meeting_event = None
    
    for event in events:
        if 'Executive Strategy Group' in event.get('summary', ''):
            meeting_event = event
            break
    
    if not meeting_event:
        print("❌ Meeting not found")
        return False
    
    # Update meeting
    meeting_event['start'] = {
        'dateTime': start_time_iso,
        'timeZone': 'America/New_York'
    }
    meeting_event['end'] = {
        'dateTime': end_time_iso,
        'timeZone': 'America/New_York'
    }
    
    # Add all agents directly as attendees
    meeting_event['attendees'] = [{'email': email} for email in agent_emails]
    meeting_event['sendUpdates'] = 'all'
    
    print(f"\n📝 Updating meeting...")
    print(f"   Time: 8:00 PM - 10:00 PM EST")
    print(f"   Attendees: {len(agent_emails)} agents (direct)")
    
    updated = calendar_service.events().update(
        calendarId=PROJECT_CALENDAR_ID,
        eventId=meeting_event.get('id'),
        body=meeting_event
    ).execute()
    
    print(f"✅ Meeting updated!")
    print(f"   Link: {updated.get('htmlLink')}")
    
    # Verify
    final = calendar_service.events().get(
        calendarId=PROJECT_CALENDAR_ID,
        eventId=meeting_event.get('id')
    ).execute()
    
    attendees = final.get('attendees', [])
    print(f"\n📊 Final attendees: {len(attendees)}")
    
    print("\n" + "="*80)
    print("✅ Complete!")
    print("="*80)
    
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)


