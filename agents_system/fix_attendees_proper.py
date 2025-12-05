"""
Fix Meeting Attendees - Proper Implementation
This script properly updates the current meeting event to add all 15 agents as attendees.
"""
import os
from datetime import datetime
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from main import load_agents_from_yaml, get_agent_metadata

def fix_attendees_proper():
    """
    Properly update the current meeting event to add all 15 agents as attendees.
    """
    print("\n" + "="*80)
    print("🔧 FIXING MEETING ATTENDEES (PROPER IMPLEMENTATION)")
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
    
    print(f"\n📧 Adding {len(agent_emails)} agents as attendees")
    
    # Project Schedule Calendar ID
    project_calendar_id = "c_4e1c24ca3fdea15ff6de1ee2e0d025f75a1f8ff58ef58e2119e5273e51a5e7dc@group.calendar.google.com"
    
    calendar_service = build('calendar', 'v3', credentials=creds)
    
    try:
        # Find the event for today at 11:00 PM EST
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
        target_event_id = None
        for event in events:
            start = event.get('start', {}).get('dateTime', '')
            # Check if it's the 11:00 PM EST event
            if '2025-11-17T23:00:00' in start or '2025-11-18T04:00:00' in start:
                target_event_id = event.get('id')
                break
        
        if not target_event_id:
            print("❌ Could not find the 11:00 PM EST meeting event")
            return False
        
        print(f"\n✅ Found event ID: {target_event_id}")
        
        # Get the FULL event (important - we need all fields)
        full_event = calendar_service.events().get(
            calendarId=project_calendar_id,
            eventId=target_event_id
        ).execute()
        
        print(f"   Event Title: {full_event.get('summary', 'No Title')}")
        
        # Create attendee list (all 15 agents)
        all_attendees = [{'email': email} for email in agent_emails]
        
        # Update the event with all attendees
        full_event['attendees'] = all_attendees
        
        print(f"\n➕ Updating event with {len(all_attendees)} attendees...")
        
        # Update the event
        updated_event = calendar_service.events().update(
            calendarId=project_calendar_id,
            eventId=target_event_id,
            body=full_event,
            sendUpdates='all'  # This sends email invitations to all attendees
        ).execute()
        
        # Verify attendees were added
        final_attendees = updated_event.get('attendees', [])
        print(f"\n✅ Successfully updated event!")
        print(f"   Final attendee count: {len(final_attendees)}")
        print(f"   Email invitations sent to all attendees")
        
        print("\n📋 Attendees:")
        for attendee in final_attendees:
            email = attendee.get('email', '')
            response = attendee.get('responseStatus', 'needsAction')
            print(f"   - {email} ({response})")
        
        return True
        
    except Exception as e:
        print(f"❌ Error updating event: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = fix_attendees_proper()
    if success:
        print("\n✅ Meeting attendees fixed successfully!")
    else:
        print("\n❌ Failed to fix meeting attendees")


