"""
Fix Meeting Attendees
This script updates the current meeting event to add all 15 agents as attendees.
"""
import os
from datetime import datetime
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from main import load_agents_from_yaml, get_agent_metadata

def fix_meeting_attendees():
    """
    Update the current meeting event to add all 15 agents as attendees.
    """
    print("\n" + "="*80)
    print("🔧 FIXING MEETING ATTENDEES")
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
    
    # Load agents
    agents = load_agents_from_yaml('agents.yaml')
    
    # Get all agent emails
    agent_emails = []
    for agent in agents:
        agent_meta = get_agent_metadata(agent.role)
        email = agent_meta.get('email_address', '')
        if email:
            agent_emails.append(email)
    
    print(f"\n📧 Adding {len(agent_emails)} agents as attendees:")
    for email in agent_emails:
        print(f"   - {email}")
    
    # Project Schedule Calendar ID
    project_calendar_id = "c_4e1c24ca3fdea15ff6de1ee2e0d025f75a1f8ff58ef58e2119e5273e51a5e7dc@group.calendar.google.com"
    
    # Find the meeting event
    calendar_service = build('calendar', 'v3', credentials=creds)
    
    print(f"\n🔍 Finding current meeting event...")
    
    try:
        # Find the event for today at 11:00 PM EST
        # Search for events starting from now
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
            print("❌ No upcoming events found")
            return False
        
        # Find the event for today (November 17, 2025) at 11:00 PM EST
        target_event = None
        for event in events:
            start = event.get('start', {}).get('dateTime', '')
            # Check if it's the 11:00 PM EST event (23:00 in ISO format)
            if '2025-11-17T23:00:00' in start or '2025-11-18T04:00:00' in start:
                target_event = event
                break
        
        if not target_event:
            print("❌ Could not find the 11:00 PM EST meeting event")
            print("\nAvailable events:")
            for event in events:
                print(f"   - {event.get('summary')} ({event.get('start', {}).get('dateTime', 'No Date')})")
            return False
        
        event_id = target_event.get('id')
        event_title = target_event.get('summary', 'No Title')
        
        print(f"\n✅ Found event: {event_title}")
        print(f"   Event ID: {event_id}")
        
        # Create attendee list (all 15 agents)
        all_attendees = [{'email': email} for email in agent_emails]
        
        # Update event with all attendees
        target_event['attendees'] = all_attendees
        
        print(f"\n➕ Updating event with {len(all_attendees)} attendees...")
        
        updated_event = calendar_service.events().update(
            calendarId=project_calendar_id,
            eventId=event_id,
            body=target_event,
            sendUpdates='all'  # This sends email invitations to all attendees
        ).execute()
        
        print(f"✅ Successfully updated event with all {len(all_attendees)} attendees")
        print(f"   Email invitations sent to all attendees")
        
        # Verify attendees were added
        final_attendees = updated_event.get('attendees', [])
        print(f"\n📋 Final attendee count: {len(final_attendees)}")
        print("\n   Attendees:")
        for attendee in final_attendees:
            email = attendee.get('email', '')
            response = attendee.get('responseStatus', 'needsAction')
            print(f"      - {email} ({response})")
        
        return True
        
    except Exception as e:
        print(f"❌ Error updating event: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = fix_meeting_attendees()
    if success:
        print("\n✅ Meeting attendees fixed successfully!")
    else:
        print("\n❌ Failed to fix meeting attendees")


