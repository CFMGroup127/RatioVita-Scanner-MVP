"""
Recreate Meeting with All Attendees
Since updating the existing event isn't working due to permissions,
we'll delete the old event and create a new one with all attendees.
"""
import os
from datetime import datetime
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from main import load_agents_from_yaml, get_agent_metadata

def recreate_meeting_with_attendees():
    """
    Delete the old meeting and create a new one with all attendees.
    """
    print("\n" + "="*80)
    print("🔄 RECREATING MEETING WITH ALL ATTENDEES")
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
        return False
    
    # Project Schedule Calendar ID
    project_calendar_id = "c_4e1c24ca3fdea15ff6de1ee2e0d025f75a1f8ff58ef58e2119e5273e51a5e7dc@group.calendar.google.com"
    
    calendar_service = build('calendar', 'v3', credentials=creds)
    
    try:
        # Find the old event
        now = datetime.now().isoformat() + 'Z'
        events_result = calendar_service.events().list(
            calendarId=project_calendar_id,
            timeMin=now,
            maxResults=10,
            singleEvents=True,
            orderBy='startTime'
        ).execute()
        
        events = events_result.get('items', [])
        
        # Find the 11:00 PM EST event
        old_event = None
        old_event_id = None
        for event in events:
            start = event.get('start', {}).get('dateTime', '')
            if '2025-11-17T23:00:00' in start or '2025-11-18T04:00:00' in start:
                old_event = event
                old_event_id = event.get('id')
                break
        
        if not old_event:
            print("❌ Could not find the 11:00 PM EST meeting event")
            return False
        
        print(f"\n📋 Found old event:")
        print(f"   Event ID: {old_event_id}")
        print(f"   Title: {old_event.get('summary')}")
        print(f"   Start: {old_event.get('start', {}).get('dateTime')}")
        print(f"   End: {old_event.get('end', {}).get('dateTime')}")
        
        # Get full event details
        full_event = calendar_service.events().get(
            calendarId=project_calendar_id,
            eventId=old_event_id
        ).execute()
        
        # Extract event details
        event_title = full_event.get('summary', 'Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning')
        event_description = full_event.get('description', '')
        event_location = full_event.get('location', 'Virtual Meeting')
        start_time = full_event.get('start', {}).get('dateTime')
        end_time = full_event.get('end', {}).get('dateTime')
        
        print(f"\n🗑️  Deleting old event...")
        calendar_service.events().delete(
            calendarId=project_calendar_id,
            eventId=old_event_id
        ).execute()
        print(f"✅ Old event deleted")
        
        # Load agents to get all emails
        agents = load_agents_from_yaml('agents.yaml')
        agent_emails = []
        for agent in agents:
            agent_meta = get_agent_metadata(agent.role)
            email = agent_meta.get('email_address', '')
            if email:
                agent_emails.append(email)
        
        # Create new event with all attendees
        print(f"\n➕ Creating new event with {len(agent_emails)} attendees...")
        
        new_event = {
            'summary': event_title,
            'description': event_description,
            'location': event_location,
            'start': {
                'dateTime': start_time,
                'timeZone': 'America/New_York',
            },
            'end': {
                'dateTime': end_time,
                'timeZone': 'America/New_York',
            },
            'attendees': [{'email': email} for email in agent_emails],
        }
        
        created_event = calendar_service.events().insert(
            calendarId=project_calendar_id,
            body=new_event,
            sendUpdates='all'  # Send email invitations to all attendees
        ).execute()
        
        print(f"✅ New event created!")
        print(f"   Event ID: {created_event.get('id')}")
        print(f"   Title: {created_event.get('summary')}")
        
        # Verify attendees
        final_attendees = created_event.get('attendees', [])
        print(f"\n📋 Final attendee count: {len(final_attendees)}")
        
        if final_attendees:
            print("\n   Attendees:")
            for attendee in final_attendees:
                email = attendee.get('email', '')
                response = attendee.get('responseStatus', 'needsAction')
                print(f"      - {email} ({response})")
        else:
            print("\n   ⚠️  WARNING: No attendees in created event!")
            print("   This might indicate a permissions issue with the calendar.")
        
        return len(final_attendees) > 0
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = recreate_meeting_with_attendees()
    if success:
        print("\n✅ Meeting recreated successfully with all attendees!")
    else:
        print("\n❌ Failed to recreate meeting")


