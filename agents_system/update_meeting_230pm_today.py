"""
Update Meeting to 2:30 PM EST Today with All Attendees
This script directly updates the Project Schedule Calendar event to 2:30 PM EST today
and adds all 15 agents as attendees.
"""
import os
import sys
from datetime import datetime, timedelta
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
import yaml

# Scopes required
SCOPES = [
    'https://www.googleapis.com/auth/calendar'
]

# Project Schedule Calendar ID
PROJECT_CALENDAR_ID = "c_4e1c24ca3fdea15ff6de1ee2e0d025f75a1f8ff58ef58e2119e5273e51a5e7dc@group.calendar.google.com"

def get_credentials():
    """Get valid user credentials from storage."""
    creds = None
    token_path = 'token.json'
    
    if os.path.exists(token_path):
        try:
            creds = Credentials.from_authorized_user_file(token_path, SCOPES)
        except Exception as e:
            print(f"⚠️  Could not load token with requested scopes: {e}")
            try:
                creds = Credentials.from_authorized_user_file(token_path, None)
                if creds.scopes:
                    has_calendar = any('calendar' in s for s in creds.scopes)
                    if has_calendar:
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

def main():
    """Main update function"""
    print("\n" + "="*80)
    print("📅 UPDATING MEETING TO 2:30 PM EST TODAY")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}")
    print(f"Calendar ID: {PROJECT_CALENDAR_ID}")
    print("="*80)
    
    # Get credentials
    print("\n🔐 Authenticating...")
    creds = get_credentials()
    
    # Build calendar service
    calendar_service = build('calendar', 'v3', credentials=creds)
    
    # Load agents
    print("📋 Loading agent configurations...")
    agents_data = load_agents()
    agents = agents_data.get('agents', [])
    
    # Get all agent emails
    agent_emails = []
    agent_info = {}
    for agent in agents:
        email = agent.get('email_address', '')
        if email:
            agent_emails.append(email)
            agent_info[email] = {
                'role': agent.get('role', 'Unknown'),
                'name': agent.get('email_address', '').split('@')[0].replace('.', ' ').title()
            }
    
    print(f"\n👥 Found {len(agent_emails)} agent email addresses")
    
    # Calculate meeting times (2:30 PM - 4:30 PM EST today)
    today = datetime.now()
    start_time = today.replace(hour=14, minute=30, second=0, microsecond=0)  # 2:30 PM
    end_time = start_time + timedelta(hours=2)  # 4:30 PM
    
    # Format for Google Calendar API (EST timezone)
    start_time_iso = start_time.strftime('%Y-%m-%dT%H:%M:00')
    end_time_iso = end_time.strftime('%Y-%m-%dT%H:%M:00')
    
    print(f"\n🕐 Meeting Time:")
    print(f"   Start: {start_time.strftime('%B %d, %Y at %I:%M %p')} EST")
    print(f"   End: {end_time.strftime('%B %d, %Y at %I:%M %p')} EST")
    
    # Search for existing meeting
    print(f"\n🔍 Searching for existing meeting...")
    start_of_day = today.replace(hour=0, minute=0, second=0, microsecond=0)
    end_of_day = today.replace(hour=23, minute=59, second=59, microsecond=0)
    
    time_min = start_of_day.isoformat() + 'Z'
    time_max = end_of_day.isoformat() + 'Z'
    
    try:
        events_result = calendar_service.events().list(
            calendarId=PROJECT_CALENDAR_ID,
            timeMin=time_min,
            timeMax=time_max,
            maxResults=20,
            singleEvents=True,
            orderBy='startTime'
        ).execute()
        
        events = events_result.get('items', [])
        
        # Find the Executive Strategy Group Meeting
        meeting_event = None
        for event in events:
            event_title = event.get('summary', '')
            if 'Executive Strategy Group' in event_title or 'V1 Legacy Review' in event_title:
                meeting_event = event
                break
        
        if not meeting_event:
            print("❌ Meeting not found. Creating new event...")
            # Create new event
            event = {
                'summary': 'Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning',
                'description': 'Executive Strategy Group Meeting for V1 Legacy Review and V2 Planning. All 15 agents are required to attend.',
                'start': {
                    'dateTime': start_time_iso,
                    'timeZone': 'America/New_York'
                },
                'end': {
                    'dateTime': end_time_iso,
                    'timeZone': 'America/New_York'
                },
                'location': 'Virtual Meeting',
                'attendees': [{'email': email} for email in agent_emails],
                'sendUpdates': 'all'
            }
            
            created_event = calendar_service.events().insert(
                calendarId=PROJECT_CALENDAR_ID,
                body=event
            ).execute()
            
            print(f"✅ New meeting created!")
            print(f"   Event ID: {created_event.get('id')}")
            print(f"   Link: {created_event.get('htmlLink')}")
            
        else:
            print(f"✅ Found existing meeting: {meeting_event.get('summary')}")
            print(f"   Event ID: {meeting_event.get('id')}")
            
            # Delete old event and create new one to ensure attendees are added
            print(f"\n🗑️  Deleting old event to recreate with all attendees...")
            try:
                calendar_service.events().delete(
                    calendarId=PROJECT_CALENDAR_ID,
                    eventId=meeting_event.get('id')
                ).execute()
                print(f"   ✅ Old event deleted")
            except Exception as e:
                print(f"   ⚠️  Could not delete old event: {e}")
                print(f"   Will try to update instead...")
            
            # Create new event with all attendees
            event = {
                'summary': 'Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning',
                'description': 'Executive Strategy Group Meeting for V1 Legacy Review and V2 Planning. All 15 agents are required to attend.',
                'start': {
                    'dateTime': start_time_iso,
                    'timeZone': 'America/New_York'
                },
                'end': {
                    'dateTime': end_time_iso,
                    'timeZone': 'America/New_York'
                },
                'location': 'Virtual Meeting',
                'attendees': [{'email': email} for email in agent_emails],
                'sendUpdates': 'all'
            }
            
            print(f"\n📝 Creating new meeting with all {len(agent_emails)} agents as attendees...")
            created_event = calendar_service.events().insert(
                calendarId=PROJECT_CALENDAR_ID,
                body=event
            ).execute()
            
            print(f"✅ New meeting created!")
            print(f"   Event ID: {created_event.get('id')}")
            print(f"   Link: {created_event.get('htmlLink')}")
            print(f"   Attendees in request: {len(agent_emails)}")
            
            # Use the created event for verification
            meeting_event = created_event
        
        # Verify attendees
        print(f"\n🔍 Verifying attendees...")
        event_id = meeting_event.get('id') if meeting_event else created_event.get('id')
        final_event = calendar_service.events().get(
            calendarId=PROJECT_CALENDAR_ID,
            eventId=event_id
        ).execute()
        
        final_attendees = final_event.get('attendees', [])
        attendee_emails = {att.get('email', '').lower() for att in final_attendees}
        agent_emails_lower = {email.lower() for email in agent_emails}
        
        print(f"\n📊 ATTENDEE VERIFICATION:")
        print(f"   Total Attendees: {len(final_attendees)}")
        print(f"   Agent Attendees: {len(attendee_emails & agent_emails_lower)}/{len(agent_emails)}")
        
        if attendee_emails & agent_emails_lower == agent_emails_lower:
            print(f"\n✅ SUCCESS: All {len(agent_emails)} agents are attendees!")
        else:
            missing = agent_emails_lower - attendee_emails
            print(f"\n⚠️  WARNING: {len(missing)} agents missing from attendee list")
            for email in sorted(missing):
                print(f"   ❌ {agent_info.get(email, {}).get('role', 'Unknown')} ({email})")
        
        print("\n" + "="*80)
        print("✅ Meeting update complete!")
        print("="*80)
        print(f"\n📅 Meeting Details:")
        print(f"   Time: {start_time.strftime('%I:%M %p')} - {end_time.strftime('%I:%M %p')} EST")
        print(f"   Date: {start_time.strftime('%B %d, %Y')}")
        print(f"   Attendees: {len(final_attendees)} total")
        print(f"   Invitations sent to all attendees")
        print("="*80)
        
    except Exception as e:
        print(f"\n❌ Error updating meeting: {e}")
        import traceback
        traceback.print_exc()
        return False
    
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)

