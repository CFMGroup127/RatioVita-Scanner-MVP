"""
Debug Calendar Update
This script debugs why attendees aren't being added to the calendar event.
"""
import os
from datetime import datetime
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from main import load_agents_from_yaml, get_agent_metadata
import json

def debug_calendar_update():
    """
    Debug the calendar update issue.
    """
    print("\n" + "="*80)
    print("🔍 DEBUGGING CALENDAR UPDATE")
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
    
    # Load agents
    agents = load_agents_from_yaml('agents.yaml')
    
    # Get all agent emails
    agent_emails = []
    for agent in agents:
        agent_meta = get_agent_metadata(agent.role)
        email = agent_meta.get('email_address', '')
        if email:
            agent_emails.append(email)
    
    # Project Schedule Calendar ID
    project_calendar_id = "c_4e1c24ca3fdea15ff6de1ee2e0d025f75a1f8ff58ef58e2119e5273e51a5e7dc@group.calendar.google.com"
    
    calendar_service = build('calendar', 'v3', credentials=creds)
    
    try:
        # Find the event
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
        target_event_id = None
        for event in events:
            start = event.get('start', {}).get('dateTime', '')
            if '2025-11-17T23:00:00' in start or '2025-11-18T04:00:00' in start:
                target_event_id = event.get('id')
                break
        
        if not target_event_id:
            print("❌ Could not find event")
            return False
        
        # Get the FULL event
        full_event = calendar_service.events().get(
            calendarId=project_calendar_id,
            eventId=target_event_id
        ).execute()
        
        print(f"\n📋 Current Event State:")
        print(f"   Event ID: {full_event.get('id')}")
        print(f"   Title: {full_event.get('summary')}")
        print(f"   Current Attendees: {len(full_event.get('attendees', []))}")
        
        if full_event.get('attendees'):
            print("\n   Current Attendee List:")
            for attendee in full_event.get('attendees', []):
                print(f"      - {attendee.get('email')} ({attendee.get('responseStatus')})")
        
        # Create new attendee list
        all_attendees = [{'email': email} for email in agent_emails]
        
        print(f"\n📧 New Attendee List ({len(all_attendees)} attendees):")
        for attendee in all_attendees[:5]:  # Show first 5
            print(f"      - {attendee['email']}")
        print(f"      ... and {len(all_attendees) - 5} more")
        
        # Update event
        full_event['attendees'] = all_attendees
        
        print(f"\n🔄 Attempting update...")
        print(f"   Event body keys: {list(full_event.keys())}")
        print(f"   Attendees in body: {len(full_event.get('attendees', []))}")
        
        # Try the update
        try:
            updated_event = calendar_service.events().update(
                calendarId=project_calendar_id,
                eventId=target_event_id,
                body=full_event,
                sendUpdates='all'
            ).execute()
            
            print(f"\n✅ Update API call succeeded")
            print(f"   Returned attendee count: {len(updated_event.get('attendees', []))}")
            
            if updated_event.get('attendees'):
                print("\n   Returned Attendees:")
                for attendee in updated_event.get('attendees', []):
                    print(f"      - {attendee.get('email')} ({attendee.get('responseStatus')})")
            else:
                print("\n   ⚠️  No attendees in returned event!")
                
                # Check if there's an error or if attendees were filtered
                print("\n   Full event response (first 1000 chars):")
                event_str = json.dumps(updated_event, indent=2)
                print(event_str[:1000])
            
        except Exception as e:
            print(f"\n❌ Update API call failed: {e}")
            import traceback
            traceback.print_exc()
        
        return True
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    debug_calendar_update()


