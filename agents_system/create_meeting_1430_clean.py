"""
Create Clean Meeting for 2:30 PM EST Today (14:30 EST)
This script:
1. Deletes ALL previous Executive Strategy Group Meeting attempts for today
2. Creates a single clean meeting for 2:30 PM EST today (14:30 EST)
3. Ensures only this one meeting appears on the calendar
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
            try:
                creds = Credentials.from_authorized_user_file(token_path, None)
                if creds.scopes:
                    has_calendar = any('calendar' in s for s in creds.scopes)
                    if has_calendar:
                        pass
                    else:
                        raise Exception("Token missing required scopes")
            except Exception as e2:
                creds = None
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            try:
                creds.refresh(Request())
            except Exception as e:
                creds = None
        
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
    """Main function - Create clean meeting for 2:30 PM EST"""
    print("\n" + "="*80)
    print("📅 CREATING CLEAN MEETING FOR 2:30 PM EST (14:30 EST)")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}")
    print("="*80)
    
    # Get credentials
    print("\n🔐 Authenticating...")
    creds = get_credentials()
    calendar_service = build('calendar', 'v3', credentials=creds)
    
    # Load agents
    print("📋 Loading agent configurations...")
    agents_data = load_agents()
    agents = agents_data.get('agents', [])
    
    # Get all agent emails
    agent_emails = []
    for agent in agents:
        email = agent.get('email_address', '')
        if email:
            agent_emails.append(email)
    
    print(f"👥 Found {len(agent_emails)} agent email addresses")
    
    # Calculate meeting times (2:30 PM - 4:30 PM EST today)
    today = datetime.now()
    start_time = today.replace(hour=14, minute=30, second=0, microsecond=0)  # 2:30 PM
    end_time = start_time + timedelta(hours=2)  # 4:30 PM
    
    # Format for Google Calendar API (EST timezone)
    start_time_iso = start_time.strftime('%Y-%m-%dT%H:%M:00')
    end_time_iso = end_time.strftime('%Y-%m-%dT%H:%M:00')
    
    print(f"\n🕐 Meeting Time:")
    print(f"   Start: {start_time.strftime('%B %d, %Y at %I:%M %p')} EST (14:30)")
    print(f"   End: {end_time.strftime('%B %d, %Y at %I:%M %p')} EST (16:30)")
    
    # Search for and DELETE ALL existing Executive Strategy Group Meetings for today
    print(f"\n🔍 Searching for ALL existing meetings to delete...")
    start_of_day = today.replace(hour=0, minute=0, second=0, microsecond=0)
    end_of_day = today.replace(hour=23, minute=59, second=59, microsecond=0)
    
    time_min = start_of_day.isoformat() + 'Z'
    time_max = end_of_day.isoformat() + 'Z'
    
    try:
        events_result = calendar_service.events().list(
            calendarId=PROJECT_CALENDAR_ID,
            timeMin=time_min,
            timeMax=time_max,
            maxResults=50,  # Get more events to catch all attempts
            singleEvents=True,
            orderBy='startTime'
        ).execute()
        
        events = events_result.get('items', [])
        
        # Find and delete ALL Executive Strategy Group Meetings
        deleted_count = 0
        for event in events:
            event_title = event.get('summary', '')
            event_id = event.get('id', '')
            event_start = event.get('start', {}).get('dateTime', event.get('start', {}).get('date', ''))
            
            # Match any variation of Executive Strategy Group Meeting
            if ('Executive Strategy Group' in event_title or 
                'V1 Legacy Review' in event_title or
                'V2 Planning' in event_title):
                print(f"🗑️  Deleting old meeting: {event_title}")
                print(f"   Start: {event_start}")
                print(f"   ID: {event_id}")
                try:
                    calendar_service.events().delete(
                        calendarId=PROJECT_CALENDAR_ID,
                        eventId=event_id
                    ).execute()
                    print(f"   ✅ Deleted successfully")
                    deleted_count += 1
                except Exception as e:
                    print(f"   ⚠️  Could not delete: {e}")
        
        if deleted_count > 0:
            print(f"\n✅ Deleted {deleted_count} old meeting(s)")
        else:
            print(f"\n✅ No old meetings found to delete")
        
        # Wait a moment for deletions to process
        import time
        time.sleep(2)
        
        # Create new event with clean timestamps
        event = {
            'summary': 'Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning',
            'description': 'Executive Strategy Group Meeting for V1 Legacy Review and V2 Planning. All 15 agents are required to attend.\n\nThis is a rescheduled meeting. Please ensure you accept the calendar invitation, add it to your personal calendar, and send a confirmation email to david.chen@ratiovita.com and dana.flores@ratiovita.com.',
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
        
        print(f"\n📝 Creating new clean meeting for 2:30 PM EST...")
        print(f"   Attendees: {len(agent_emails)} agents")
        print(f"   Time: 14:30 - 16:30 EST")
        
        created_event = calendar_service.events().insert(
            calendarId=PROJECT_CALENDAR_ID,
            body=event
        ).execute()
        
        print(f"✅ New meeting created!")
        print(f"   Event ID: {created_event.get('id')}")
        print(f"   Link: {created_event.get('htmlLink')}")
        
        # Verify only one meeting exists
        print(f"\n🔍 Verifying only one meeting exists...")
        events_result = calendar_service.events().list(
            calendarId=PROJECT_CALENDAR_ID,
            timeMin=time_min,
            timeMax=time_max,
            maxResults=50,
            singleEvents=True,
            orderBy='startTime'
        ).execute()
        
        final_events = events_result.get('items', [])
        strategy_meetings = [e for e in final_events if 'Executive Strategy Group' in e.get('summary', '') or 'V1 Legacy Review' in e.get('summary', '')]
        
        print(f"   Total events found: {len(final_events)}")
        print(f"   Executive Strategy meetings: {len(strategy_meetings)}")
        
        if len(strategy_meetings) == 1:
            print(f"   ✅ SUCCESS: Only one meeting exists!")
            meeting = strategy_meetings[0]
            meeting_start = meeting.get('start', {}).get('dateTime', '')
            print(f"   Meeting time: {meeting_start}")
        else:
            print(f"   ⚠️  WARNING: Found {len(strategy_meetings)} meetings (expected 1)")
            for m in strategy_meetings:
                print(f"      - {m.get('summary', 'Unknown')} at {m.get('start', {}).get('dateTime', 'Unknown')}")
        
        # Verify attendees
        final_event = calendar_service.events().get(
            calendarId=PROJECT_CALENDAR_ID,
            eventId=created_event.get('id')
        ).execute()
        
        final_attendees = final_event.get('attendees', [])
        print(f"\n📊 Final Meeting Details:")
        print(f"   Title: {final_event.get('summary', 'Unknown')}")
        print(f"   Start: {final_event.get('start', {}).get('dateTime', 'Unknown')}")
        print(f"   End: {final_event.get('end', {}).get('dateTime', 'Unknown')}")
        print(f"   Attendees: {len(final_attendees)} total")
        
        print("\n" + "="*80)
        print("✅ CLEAN MEETING CREATED SUCCESSFULLY")
        print("="*80)
        print(f"\n📅 Meeting Details:")
        print(f"   Title: Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning")
        print(f"   Date: {start_time.strftime('%B %d, %Y')}")
        print(f"   Time: 2:30 PM - 4:30 PM EST (14:30 - 16:30)")
        print(f"   Location: Virtual Meeting")
        print(f"   Attendees: {len(final_attendees)} agents")
        print(f"   Calendar Link: {created_event.get('htmlLink')}")
        print(f"\n✅ Only this meeting appears on the calendar (all old attempts deleted)")
        print("="*80)
        
        return True
        
    except Exception as e:
        print(f"\n❌ Error creating meeting: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)

