"""
Check Calendar Event Attendees
This script checks the current meeting event to see if it has all attendees.
"""
import os
from datetime import datetime
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from main import load_agents_from_yaml, get_agent_metadata

def check_calendar_event_attendees():
    """
    Check the current meeting event for attendees.
    """
    print("\n" + "="*80)
    print("📅 CHECKING CALENDAR EVENT ATTENDEES")
    print("="*80)
    print(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}")
    print("="*80)
    
    # Get credentials
    creds = None
    if os.path.exists('token.json'):
        creds = Credentials.from_authorized_user_file('token.json', [
            'https://www.googleapis.com/auth/calendar'
        ])
        if not creds.valid:
            if creds.expired and creds.refresh_token:
                creds.refresh(Request())
    
    if not creds:
        print("❌ Could not get credentials")
        return None
    
    # Load agents
    agents = load_agents_from_yaml('agents.yaml')
    
    # Get all agent emails
    agent_emails = []
    for agent in agents:
        agent_meta = get_agent_metadata(agent.role)
        email = agent_meta.get('email_address', '')
        if email:
            agent_emails.append(email)
    
    print(f"\n📧 Expected agent emails: {len(agent_emails)}")
    
    # Project Schedule Calendar ID
    project_calendar_id = "c_4e1c24ca3fdea15ff6de1ee2e0d025f75a1f8ff58ef58e2119e5273e51a5e7dc@group.calendar.google.com"
    
    # Find the meeting event
    calendar_service = build('calendar', 'v3', credentials=creds)
    
    print(f"\n🔍 Searching for meeting event on Project Schedule Calendar...")
    print(f"   Calendar ID: {project_calendar_id}")
    
    try:
        # List events from today
        now = datetime.now().isoformat() + 'Z'
        events_result = calendar_service.events().list(
            calendarId=project_calendar_id,
            timeMin=now,
            maxResults=10,
            singleEvents=True,
            orderBy='startTime'
        ).execute()
        
        events = events_result.get('items', [])
        
        if not events:
            print("❌ No upcoming events found on Project Schedule Calendar")
            return None
        
        print(f"\n📋 Found {len(events)} upcoming event(s):")
        print("-" * 80)
        
        for event in events:
            title = event.get('summary', 'No Title')
            start = event.get('start', {}).get('dateTime', event.get('start', {}).get('date', 'No Date'))
            event_id = event.get('id', 'No ID')
            attendees = event.get('attendees', [])
            
            print(f"\n📅 Event: {title}")
            print(f"   Start: {start}")
            print(f"   Event ID: {event_id}")
            print(f"   Attendees: {len(attendees)}")
            
            if attendees:
                print("\n   Current Attendees:")
                for attendee in attendees:
                    email = attendee.get('email', 'Unknown')
                    response = attendee.get('responseStatus', 'needsAction')
                    print(f"      - {email} ({response})")
            else:
                print("\n   ⚠️  NO ATTENDEES FOUND - Event needs to be updated!")
            
            # Check which agents are missing
            if attendees:
                current_attendee_emails = [a.get('email', '') for a in attendees]
                missing_attendees = [e for e in agent_emails if e not in current_attendee_emails]
                
                if missing_attendees:
                    print(f"\n   ⚠️  Missing {len(missing_attendees)} attendees:")
                    for email in missing_attendees:
                        print(f"      - {email}")
                else:
                    print(f"\n   ✅ All {len(agent_emails)} agents are listed as attendees")
            else:
                print(f"\n   ⚠️  All {len(agent_emails)} agents are missing!")
        
        return events
        
    except Exception as e:
        print(f"❌ Error accessing calendar: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    check_calendar_event_attendees()


